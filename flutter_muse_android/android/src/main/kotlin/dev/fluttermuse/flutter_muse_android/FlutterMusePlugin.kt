package dev.fluttermuse.flutter_muse_android

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import com.choosemuse.libmuse.AndroidLogListener
import com.choosemuse.libmuse.ComputingDeviceConfigurationFactory
import com.choosemuse.libmuse.ConnectionState
import com.choosemuse.libmuse.HandlerEventLoop
import com.choosemuse.libmuse.LibmuseVersion
import com.choosemuse.libmuse.LogListener
import com.choosemuse.libmuse.LogManager
import com.choosemuse.libmuse.LogPacket
import com.choosemuse.libmuse.Muse
import com.choosemuse.libmuse.MuseDataPacketType
import com.choosemuse.libmuse.MuseElementsAlgorithmSettings
import com.choosemuse.libmuse.MuseElementsVersion
import com.choosemuse.libmuse.MuseFileFactory
import com.choosemuse.libmuse.MuseListener
import com.choosemuse.libmuse.MuseLog
import com.choosemuse.libmuse.MuseManagerAndroid
import com.choosemuse.libmuse.MuseModel
import com.choosemuse.libmuse.MusePreset
import com.choosemuse.libmuse.MuseVersion
import com.choosemuse.libmuse.NotchFrequency
import com.choosemuse.libmuse.ReaderMuseBuilder
import com.choosemuse.libmuse.ReaderMusePlaybackSettings
import com.choosemuse.libmuse.Severity
import com.choosemuse.libmuse.Stringify
import com.choosemuse.libmuse.TimestampMode
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry
import java.io.File
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

/**
 * Flutter bridge for the Muse SDK (libmuse for Android).
 *
 * All SDK calls happen on the Android main thread (MuseManagerAndroid
 * requires it), except blocking ReaderMuse calls on a synchronous reader,
 * which run on a background thread.
 */
class FlutterMusePlugin :
    FlutterPlugin,
    MethodChannel.MethodCallHandler,
    ActivityAware,
    PluginRegistry.ActivityResultListener,
    PluginRegistry.RequestPermissionsResultListener {

    private companion object {
        const val METHOD_CHANNEL = "flutter_muse/methods"
        const val EVENT_CHANNEL = "flutter_muse/events"
        const val PERMISSION_REQUEST_CODE = 0x4D55
        const val READER_MUSE_PREFIX = "reader:"
    }

    private lateinit var methodChannel: MethodChannel
    private lateinit var eventChannel: EventChannel
    private lateinit var appContext: Context
    private val mainHandler = Handler(Looper.getMainLooper())
    private val emitter = EventEmitter(mainHandler)
    private var background: ExecutorService? = null

    private var activityBinding: ActivityPluginBinding? = null
    private val activity: Activity? get() = activityBinding?.activity

    private var manager: MuseManagerAndroid? = null
    private var companionMode = false
    private var logListener: LogListener? = null
    private var pendingPermissionResult: MethodChannel.Result? = null

    private val muses = HashMap<String, MuseHandle>()
    private val writers = HashMap<Int, WriterHandle>()
    private val readers = HashMap<Int, ReaderHandle>()
    private val readerMuses = HashMap<Int, ReaderMuseHandle>()
    private var nextHandle = 1

    private val museListener = object : MuseListener() {
        override fun museListChanged() {
            val list = try { syncMuses() } catch (t: Throwable) { emptyList() }
            emitter.emit(mapOf("event" to "museListChanged", "muses" to list))
        }
    }

    // ---------------------------------------------------------------- lifecycle

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        appContext = binding.applicationContext
        methodChannel = MethodChannel(binding.binaryMessenger, METHOD_CHANNEL)
        methodChannel.setMethodCallHandler(this)
        eventChannel = EventChannel(binding.binaryMessenger, EVENT_CHANNEL)
        eventChannel.setStreamHandler(emitter)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        methodChannel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
        resetState()
        manager?.let { tryQuietly { it.stopListening() } }
        manager = null
        background?.shutdown()
        background = null
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activityBinding = binding
        binding.addActivityResultListener(this)
        binding.addRequestPermissionsResultListener(this)
        manager?.setContext(sdkContext())
    }

    override fun onDetachedFromActivity() {
        activityBinding?.removeActivityResultListener(this)
        activityBinding?.removeRequestPermissionsResultListener(this)
        activityBinding = null
        pendingPermissionResult?.error("NO_ACTIVITY", "Activity detached during permission request", null)
        pendingPermissionResult = null
        manager?.let {
            // Companion-mode scanning is bound to the Activity context.
            if (companionMode) it.stopListening()
            it.setContext(appContext)
        }
    }

    override fun onDetachedFromActivityForConfigChanges() = onDetachedFromActivity()

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) =
        onAttachedToActivity(binding)

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != MuseManagerAndroid.SELECT_DEVICE_REQUEST_CODE) return false
        manager?.handleActivityResult(requestCode, resultCode, data)
        return true
    }

    override fun onRequestPermissionsResult(
        requestCode: Int, permissions: Array<out String>, grantResults: IntArray,
    ): Boolean {
        if (requestCode != PERMISSION_REQUEST_CODE) return false
        pendingPermissionResult?.success(permissionStatus())
        pendingPermissionResult = null
        return true
    }

    /** The SDK needs an Activity context only for companion-mode pairing. */
    private fun sdkContext(): Context = if (companionMode) activity ?: appContext else appContext

    /**
     * Lazily initialises the SDK. Loading MuseManagerAndroid loads the native
     * library; a missing .so surfaces here as UnsatisfiedLinkError.
     */
    private fun sdk(): MuseManagerAndroid {
        manager?.let { return it }
        val m = MuseManagerAndroid.getInstance()
        m.setContext(sdkContext())
        m.setMuseListener(museListener)
        manager = m
        return m
    }

    /** Forgets everything Dart knew about (used on hot restart and detach). */
    private fun resetState() {
        readerMuses.values.forEach { it.dispose() }
        readerMuses.clear()
        writers.values.forEach { it.dispose() }
        writers.clear()
        readers.values.forEach { tryQuietly { it.reader.close() } }
        readers.clear()
        muses.values.forEach { it.dispose() }
        muses.clear()
        if (logListener != null) {
            tryQuietly { LogManager.instance().setLogListener(AndroidLogListener()) }
            logListener = null
        }
    }

    // ------------------------------------------------------------------ dispatch

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        try {
            handle(call, result)
        } catch (e: UnsatisfiedLinkError) {
            result.error(
                "NATIVE_LIBRARY_MISSING",
                "The Muse SDK native library (libmuse_android.so) could not be loaded. " +
                    "Add it to android/src/main/jniLibs/<abi>/ of the plugin or to your app's jniLibs. " +
                    "(${e.message})",
                null,
            )
        } catch (e: IllegalArgumentException) {
            result.error("INVALID_ARGUMENT", e.message, null)
        } catch (t: Throwable) {
            result.error("MUSE_ERROR", t.message ?: t.toString(), t.stackTraceToString())
        }
    }

    private fun handle(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            // ---------------------------------------------------------- general
            "initialize" -> {
                resetState()
                call.argument<Number>("batchIntervalMs")?.let { emitter.batchIntervalMs = it.toLong() }
                val status = HashMap<String, Any?>()
                try {
                    sdk()
                    status["nativeLibraryLoaded"] = true
                    status["libmuseVersion"] = Codec.apiVersion(LibmuseVersion.instance())
                } catch (e: Throwable) {
                    status["nativeLibraryLoaded"] = false
                    status["error"] = e.toString()
                }
                result.success(status)
            }
            "setPacketBatchInterval" -> {
                emitter.batchIntervalMs = call.arg<Number>("ms").toLong()
                result.success(null)
            }
            "hasPermissions" -> result.success(permissionStatus().values.all { it })
            "requestPermissions" -> requestPermissions(result)
            "isBluetoothEnabled" -> result.success(sdk().defaultAdapter?.isEnabled == true)
            "getLibmuseVersion" -> { sdk(); result.success(Codec.apiVersion(LibmuseVersion.instance())) }
            "stringifyConnectionState" -> {
                sdk()
                result.success(Stringify.instance().connectionState(call.enumArg<ConnectionState>("state")))
            }
            "stringifyPacketType" -> {
                sdk()
                result.success(Stringify.instance().packetType(call.enumArg<MuseDataPacketType>("type")))
            }
            "getComputingDeviceConfiguration" -> {
                sdk()
                result.success(Codec.computingDevice(
                    ComputingDeviceConfigurationFactory.getInstance().computingDeviceConfiguration))
            }
            "makeDefaultVersion" -> { sdk(); result.success(Codec.version(MuseVersion.makeDefaultVersion())) }
            "makeVersion" -> { sdk(); result.success(Codec.version(MuseVersion.makeVersion(call.arg("json")))) }

            // -------------------------------------------- elements algorithm settings
            "elementsGetSettings" -> {
                sdk()
                val s = MuseElementsAlgorithmSettings.getInstance()
                result.success(mapOf(
                    "version" to s.elementsVersion?.ordinal,
                    "enableMultipleMuseElements" to s.enableMultipleMuseElements,
                ))
            }
            "elementsSetVersion" -> {
                sdk()
                MuseElementsAlgorithmSettings.getInstance().elementsVersion = call.enumArg<MuseElementsVersion>("version")
                result.success(null)
            }
            "elementsSetEnableMultiple" -> {
                sdk()
                MuseElementsAlgorithmSettings.getInstance().enableMultipleMuseElements = call.arg("enabled")
                result.success(null)
            }

            // ------------------------------------------------------------ logging
            "logSetMinimumSeverity" -> {
                sdk()
                LogManager.instance().setMinimumSeverity(call.enumArg<Severity>("severity"))
                result.success(null)
            }
            "logWrite" -> {
                sdk()
                LogManager.instance().writeLog(
                    call.enumArg<Severity>("severity"), call.arg("raw"), call.arg("tag"), call.arg("message"))
                result.success(null)
            }
            "logGetTimestamp" -> { sdk(); result.success(LogManager.instance().timestamp) }
            "logTimeSince" -> { sdk(); result.success(LogManager.instance().timeSince(call.arg<Number>("timestamp").toLong())) }
            "logSetListener" -> {
                sdk()
                setLogListener(call.arg("enabled"), call.argument<Boolean>("forwardToLogcat") ?: true)
                result.success(null)
            }
            "museLog" -> {
                sdk()
                MuseLog.log(call.enumArg<Severity>("severity"), call.arg<String>("message"), call.argument<Boolean>("raw") ?: false)
                result.success(null)
            }

            // ------------------------------------------------------------ manager
            "managerStartListening" -> {
                val m = sdk()
                if (companionMode && activity == null) {
                    throw IllegalStateException("Companion mode needs an attached Activity to start listening")
                }
                m.setContext(sdkContext())
                m.startListening()
                result.success(null)
            }
            "managerStopListening" -> { sdk().stopListening(); result.success(null) }
            "managerGetMuses" -> { sdk(); result.success(syncMuses()) }
            "managerRemoveFromListAfter" -> {
                sdk().removeFromListAfter(call.arg<Number>("seconds").toLong())
                result.success(null)
            }
            "managerResetAdvertisingStats" -> { sdk().resetAdvertisingStats(); result.success(null) }
            "managerGetAdvertisingStats" -> {
                val m = sdk()
                result.success(Codec.advertisingStats(m.getAdvertisingStats(museHandle(call).muse)))
            }
            "managerSetCompanionMode" -> {
                val m = sdk()
                val enabled = call.arg<Boolean>("enabled")
                if (enabled && Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
                    throw IllegalStateException("Companion mode requires Android 8.0 (API 26) or newer")
                }
                if (enabled && activity == null) {
                    throw IllegalStateException("Companion mode needs an attached Activity")
                }
                companionMode = enabled
                m.setContext(sdkContext())
                m.setCompanionMode(
                    enabled,
                    call.argument<String>("macAddress"),
                    call.argument<ByteArray>("manufacturerData"),
                    call.argument<Boolean>("removeOthers") ?: false,
                )
                result.success(null)
            }
            "managerMuseUuid" -> result.success(MuseManagerAndroid.museUuid().toString())

            // --------------------------------------------------------------- muse
            "museGetInfo" -> { val h = museHandle(call); result.success(Codec.museInfo(h.id, h.muse)) }
            "museConnect" -> { museHandle(call).muse.connect(); result.success(null) }
            "museDisconnect" -> { museHandle(call).muse.disconnect(); result.success(null) }
            "museRunAsynchronously" -> { museHandle(call).muse.runAsynchronously(); result.success(null) }
            "museExecute" -> { museHandle(call).muse.execute(); result.success(null) }
            "museEnableDataTransmission" -> {
                museHandle(call).muse.enableDataTransmission(call.arg("enabled"))
                result.success(null)
            }
            "museEnableException" -> { museHandle(call).muse.enableException(call.arg("enabled")); result.success(null) }
            "museEnableLedIndicator" -> { museHandle(call).muse.enableLedIndicator(call.arg("enabled")); result.success(null) }
            "museSetPreset" -> { museHandle(call).muse.setPreset(call.enumArg<MusePreset>("preset")); result.success(null) }
            "museSetNotchFrequency" -> {
                museHandle(call).muse.setNotchFrequency(call.enumArg<NotchFrequency>("frequency"))
                result.success(null)
            }
            "museSetNumConnectTries" -> { museHandle(call).muse.setNumConnectTries(call.arg("tries")); result.success(null) }
            "museSetLicenseData" -> { museHandle(call).muse.setLicenseData(call.arg("data")); result.success(null) }
            "museGetConfiguration" -> result.success(Codec.configuration(museHandle(call).muse.museConfiguration))
            "museGetVersion" -> result.success(Codec.version(museHandle(call).muse.museVersion))
            "museRegisterDataType" -> {
                museHandle(call).registerDataType(call.enumArg<MuseDataPacketType>("type"))
                result.success(null)
            }
            "museUnregisterDataType" -> {
                museHandle(call).unregisterDataType(call.enumArg<MuseDataPacketType>("type"))
                result.success(null)
            }
            "museUnregisterAllListeners" -> { museHandle(call).unregisterAllListeners(); result.success(null) }

            // -------------------------------------------------------- file writer
            "writerCreate" -> {
                sdk()
                val id = nextHandle++
                writers[id] = WriterHandle(MuseFileFactory.getMuseFileWriter(File(call.arg<String>("path"))))
                result.success(id)
            }
            "writerOpen" -> result.success(writer(call).writer.open())
            "writerClose" -> result.success(writer(call).writer.close())
            "writerFlush" -> result.success(writer(call).writer.flush())
            "writerAddDataPacket" -> {
                writer(call).writer.addDataPacket(call.arg("messageId"), Codec.decodeDataPacket(call.arg("packet")))
                result.success(null)
            }
            "writerAddArtifactPacket" -> {
                writer(call).writer.addArtifactPacket(call.arg("messageId"), Codec.decodeArtifact(call.arg("packet")))
                result.success(null)
            }
            "writerAddAnnotation" -> {
                writer(call).writer.addAnnotation(call.arg("messageId"), Codec.decodeAnnotation(call.arg("annotation")))
                result.success(null)
            }
            "writerAddAnnotationString" -> {
                writer(call).writer.addAnnotationString(call.arg("messageId"), call.arg("annotation"))
                result.success(null)
            }
            "writerAddConfiguration" -> {
                val w = writer(call)
                val config = when {
                    call.hasArgument("museId") -> museHandle(call).muse.museConfiguration
                    call.hasArgument("readerId") -> reader(call).reader.configuration
                    else -> throw IllegalArgumentException("museId or readerId is required")
                } ?: throw IllegalStateException("No configuration available")
                w.writer.addConfiguration(call.arg("messageId"), config)
                result.success(null)
            }
            "writerAddVersion" -> {
                val w = writer(call)
                val version = when {
                    call.hasArgument("museId") -> museHandle(call).muse.museVersion
                    call.hasArgument("readerId") -> reader(call).reader.version
                    call.hasArgument("json") -> MuseVersion.makeVersion(call.arg("json"))
                    else -> MuseVersion.makeDefaultVersion()
                } ?: throw IllegalStateException("No version available")
                w.writer.addVersion(call.arg("messageId"), version)
                result.success(null)
            }
            "writerAddComputingDeviceConfiguration" -> {
                val w = writer(call)
                val config = call.argument<Map<*, *>>("configuration")?.let { Codec.decodeComputingDevice(it) }
                    ?: ComputingDeviceConfigurationFactory.getInstance().computingDeviceConfiguration
                w.writer.addComputingDeviceConfiguration(call.arg("messageId"), config)
                result.success(null)
            }
            "writerAddDsp" -> {
                writer(call).writer.addDsp(call.arg("messageId"), Codec.decodeDsp(call.arg("dsp")))
                result.success(null)
            }
            "writerSetTimestamp" -> {
                writer(call).writer.setTimestamp(call.arg<Number>("timestamp").toLong())
                result.success(null)
            }
            "writerSetTimestampMode" -> {
                writer(call).writer.setTimestampMode(call.enumArg<TimestampMode>("mode"))
                result.success(null)
            }
            "writerDiscardBufferedPackets" -> { writer(call).writer.discardBufferedPackets(); result.success(null) }
            "writerGetStats" -> {
                val w = writer(call).writer
                result.success(mapOf(
                    "bufferedMessagesSize" to w.bufferedMessagesSize,
                    "bufferedMessagesCount" to w.bufferredMessagesCount,
                    "totalBytesWritten" to w.totalBytesWritten,
                ))
            }
            "writerStartRecording" -> {
                val h = museHandle(call)
                val types = call.arg<List<Int>>("types").map { Codec.enumAt<MuseDataPacketType>(it) }.toSet()
                writer(call).startRecording(h.id, h.muse, types, call.argument<Int>("messageId") ?: 0)
                result.success(null)
            }
            "writerStopRecording" -> {
                writer(call).stopRecording(call.argument<String>("museId"))
                result.success(null)
            }
            "writerDispose" -> {
                writers.remove(call.arg<Int>("id"))?.dispose()
                result.success(null)
            }

            // -------------------------------------------------------- file reader
            "readerCreate" -> {
                sdk()
                val id = nextHandle++
                readers[id] = ReaderHandle(MuseFileFactory.getMuseFileReader(File(call.arg<String>("path"))))
                result.success(id)
            }
            "readerOpen" -> result.success(reader(call).reader.open())
            "readerClose" -> result.success(reader(call).reader.close())
            "readerGotoNextMessage" -> result.success(Codec.result(reader(call).reader.gotoNextMessage()))
            "readerCurrentMessage" -> result.success(Codec.fileMessage(reader(call).reader))
            "readerReadMessages" -> {
                val r = reader(call).reader
                val max = call.arg<Int>("max")
                val messages = ArrayList<Map<String, Any?>>()
                var last: Map<String, Any?>? = null
                while (messages.size < max) {
                    val res = r.gotoNextMessage()
                    if (res.level != com.choosemuse.libmuse.ResultLevel.R_SUCCESS) {
                        last = Codec.result(res)
                        break
                    }
                    messages.add(Codec.fileMessage(r))
                }
                result.success(mapOf("messages" to messages, "result" to last))
            }
            "readerDispose" -> {
                readers.remove(call.arg<Int>("id"))?.let { tryQuietly { it.reader.close() } }
                result.success(null)
            }

            // -------------------------------------------------------- reader muse
            "readerMuseCreate" -> {
                val r = reader(call).reader
                var builder = ReaderMuseBuilder.get()
                call.argument<List<Int>>("packetTypes")?.let { types ->
                    builder = builder.withPacketTypes(HashSet(types.map { Codec.enumAt<MuseDataPacketType>(it) }))
                }
                call.argument<List<Int>>("skipPacketTypes")?.let { types ->
                    builder = builder.skipPacketTypes(HashSet(types.map { Codec.enumAt<MuseDataPacketType>(it) }))
                }
                call.argument<Int>("model")?.let { builder = builder.withModel(Codec.enumAt<MuseModel>(it)) }
                call.argument<Int>("playbackSettings")?.let {
                    builder = builder.withPlaybackSettings(Codec.enumAt<ReaderMusePlaybackSettings>(it))
                }
                val async = call.argument<Boolean>("async") ?: true
                val readerMuse = if (async) {
                    builder.buildWithAsync(r, HandlerEventLoop(mainHandler))
                } else {
                    builder.build(r)
                }
                val id = nextHandle++
                val museId = READER_MUSE_PREFIX + id
                val museHandle = MuseHandle(museId, readerMuse.asMuse(), emitter)
                muses[museId] = museHandle
                readerMuses[id] = ReaderMuseHandle(id, readerMuse, museHandle, async, emitter)
                result.success(mapOf("id" to id, "museId" to museId))
            }
            "readerMusePlayback" -> runReaderMuse(call, result) { it.playback() }
            "readerMuseRun" -> runReaderMuse(call, result) { it.run() }
            "readerMuseRunInRealTimespan" -> runReaderMuse(call, result) { it.runInRealTimespan() }
            "readerMuseStopPlayback" -> { readerMuse(call).readerMuse.stopPlayback(); result.success(null) }
            "readerMuseCurrentTime" -> result.success(readerMuse(call).readerMuse.currentTime())
            "readerMuseGetPlaybackSettings" -> result.success(readerMuse(call).readerMuse.playbackSettings?.ordinal)
            "readerMuseSetPlaybackSettings" -> {
                readerMuse(call).readerMuse.playbackSettings = call.enumArg<ReaderMusePlaybackSettings>("settings")
                result.success(null)
            }
            "readerMuseDispose" -> {
                readerMuses.remove(call.arg<Int>("id"))?.let {
                    it.dispose()
                    muses.remove(it.museHandle.id)
                }
                result.success(null)
            }

            else -> result.notImplemented()
        }
    }

    // ------------------------------------------------------------------ helpers

    /** Registers handles for the manager's current muses and describes them. */
    private fun syncMuses(): List<Map<String, Any?>> {
        val m = manager ?: return emptyList()
        return m.muses.map { muse ->
            val id = muse.macAddress
            val handle = muses[id]
            if (handle == null) muses[id] = MuseHandle(id, muse, emitter) else handle.replaceMuse(muse)
            Codec.museInfo(id, muse)
        }
    }

    private fun museHandle(call: MethodCall): MuseHandle {
        val id = call.arg<String>("museId")
        muses[id]?.let { return it }
        // Not seen yet (e.g. after a hot restart): look it up in the manager.
        val muse: Muse? = if (id.startsWith(READER_MUSE_PREFIX)) null
        else sdk().muses.firstOrNull { it.macAddress == id }
        muse ?: throw IllegalArgumentException("Unknown muse: $id")
        return MuseHandle(id, muse, emitter).also { muses[id] = it }
    }

    private fun writer(call: MethodCall) =
        writers[call.arg<Int>("id")] ?: throw IllegalArgumentException("Unknown or disposed file writer")

    private fun reader(call: MethodCall): ReaderHandle {
        val id = if (call.hasArgument("readerId")) call.arg<Int>("readerId") else call.arg<Int>("id")
        return readers[id] ?: throw IllegalArgumentException("Unknown or disposed file reader")
    }

    private fun readerMuse(call: MethodCall) =
        readerMuses[call.arg<Int>("id")] ?: throw IllegalArgumentException("Unknown or disposed reader muse")

    /**
     * Async reader muses are driven by the main-thread event loop, so their
     * calls return immediately. Synchronous ones block until the file is
     * consumed, so they run on a background thread.
     */
    private fun runReaderMuse(
        call: MethodCall,
        result: MethodChannel.Result,
        action: (com.choosemuse.libmuse.ReaderMuse) -> Unit,
    ) {
        val h = readerMuse(call)
        if (h.async) {
            action(h.readerMuse)
            result.success(null)
            return
        }
        val executor = background ?: Executors.newSingleThreadExecutor().also { background = it }
        executor.execute {
            try {
                action(h.readerMuse)
                mainHandler.post { result.success(null) }
            } catch (t: Throwable) {
                mainHandler.post { result.error("MUSE_ERROR", t.message ?: t.toString(), null) }
            }
        }
    }

    private fun setLogListener(enabled: Boolean, forwardToLogcat: Boolean) {
        val logManager = LogManager.instance()
        if (!enabled) {
            logManager.setLogListener(AndroidLogListener())
            logListener = null
            return
        }
        val logcat = if (forwardToLogcat) AndroidLogListener() else null
        val listener = object : LogListener() {
            override fun receiveLog(p: LogPacket) {
                logcat?.receiveLog(p)
                emitter.emit(mapOf("event" to "log", "log" to Codec.logPacket(p)))
            }
        }
        logListener = listener
        logManager.setLogListener(listener)
    }

    private fun requiredPermissions(): Array<String> =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            arrayOf(Manifest.permission.BLUETOOTH_SCAN, Manifest.permission.BLUETOOTH_CONNECT)
        } else {
            arrayOf(Manifest.permission.ACCESS_FINE_LOCATION)
        }

    private fun permissionStatus(): Map<String, Boolean> = requiredPermissions().associateWith {
        appContext.checkSelfPermission(it) == PackageManager.PERMISSION_GRANTED
    }

    private fun requestPermissions(result: MethodChannel.Result) {
        val status = permissionStatus()
        val missing = status.filterValues { !it }.keys
        if (missing.isEmpty()) {
            result.success(status)
            return
        }
        val act = activity
        if (act == null) {
            result.error("NO_ACTIVITY", "Requesting permissions needs an attached Activity", null)
            return
        }
        if (pendingPermissionResult != null) {
            result.error("ALREADY_REQUESTING", "A permission request is already in progress", null)
            return
        }
        pendingPermissionResult = result
        act.requestPermissions(missing.toTypedArray(), PERMISSION_REQUEST_CODE)
    }

    private inline fun tryQuietly(f: () -> Unit) {
        try { f() } catch (_: Throwable) { }
    }
}

private fun <T> MethodCall.arg(key: String): T =
    argument<T>(key) ?: throw IllegalArgumentException("Missing argument '$key' for $method")

private inline fun <reified T : Enum<T>> MethodCall.enumArg(key: String): T =
    Codec.enumAt(arg<Int>(key))
