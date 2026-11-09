package dev.fluttermuse.flutter_muse_android

import com.choosemuse.libmuse.AnnotationData
import com.choosemuse.libmuse.ComputingDeviceConfiguration
import com.choosemuse.libmuse.Error
import com.choosemuse.libmuse.Muse
import com.choosemuse.libmuse.MuseArtifactPacket
import com.choosemuse.libmuse.MuseConfiguration
import com.choosemuse.libmuse.MuseConnectionListener
import com.choosemuse.libmuse.MuseConnectionPacket
import com.choosemuse.libmuse.MuseDataListener
import com.choosemuse.libmuse.MuseDataPacket
import com.choosemuse.libmuse.MuseDataPacketType
import com.choosemuse.libmuse.MuseErrorListener
import com.choosemuse.libmuse.MuseFileReader
import com.choosemuse.libmuse.MuseFileWriter
import com.choosemuse.libmuse.MuseVersion
import com.choosemuse.libmuse.ReaderListener
import com.choosemuse.libmuse.ReaderMuse
import com.choosemuse.libmuse.ReaderPlaybackListener
import java.util.EnumSet

/**
 * A headband (or a [ReaderMuse] viewed as a Muse) known to Dart by [id].
 *
 * Connection and error listeners are always attached; data packet types are
 * registered on demand as Dart subscribes to them.
 */
internal class MuseHandle(val id: String, muse: Muse, private val emitter: EventEmitter) {
    var muse: Muse = muse
        private set

    private val dataTypes: EnumSet<MuseDataPacketType> = EnumSet.noneOf(MuseDataPacketType::class.java)

    private val connectionListener = object : MuseConnectionListener() {
        override fun receiveMuseConnectionPacket(p: MuseConnectionPacket, m: Muse?) {
            emitter.emit(mapOf(
                "event" to "connection",
                "museId" to id,
                "previous" to p.previousConnectionState?.ordinal,
                "current" to p.currentConnectionState?.ordinal,
            ))
        }
    }

    private val errorListener = object : MuseErrorListener() {
        override fun receiveError(e: Error, m: Muse?) {
            emitter.emit(mapOf("event" to "error", "museId" to id, "error" to Codec.error(e)))
        }
    }

    private val dataListener = object : MuseDataListener() {
        override fun receiveMuseDataPacket(p: MuseDataPacket, m: Muse?) {
            emitter.emitPacket(Codec.encodeDataPacket(id, p))
        }

        override fun receiveMuseArtifactPacket(p: MuseArtifactPacket, m: Muse?) {
            emitter.emitPacket(Codec.encodeArtifact(id, p))
        }
    }

    init {
        attachBaseListeners()
    }

    private fun attachBaseListeners() {
        muse.registerConnectionListener(connectionListener)
        muse.registerErrorListener(errorListener)
    }

    /** The SDK returned a new object for the same headband: move listeners over. */
    fun replaceMuse(newMuse: Muse) {
        if (newMuse === muse) return
        detachAll()
        muse = newMuse
        attachBaseListeners()
        dataTypes.forEach { muse.registerDataListener(dataListener, it) }
    }

    fun registerDataType(type: MuseDataPacketType) {
        if (dataTypes.add(type)) muse.registerDataListener(dataListener, type)
    }

    fun unregisterDataType(type: MuseDataPacketType) {
        if (dataTypes.remove(type)) muse.unregisterDataListener(dataListener, type)
    }

    /**
     * `Muse.unregisterAllListeners()`: drops every listener on the headband,
     * including ones registered by native code outside this plugin, then
     * re-attaches the plugin's connection and error listeners.
     */
    fun unregisterAllListeners() {
        muse.unregisterAllListeners()
        dataTypes.clear()
        attachBaseListeners()
    }

    fun detachAll() {
        try {
            dataTypes.forEach { muse.unregisterDataListener(dataListener, it) }
            muse.unregisterConnectionListener(connectionListener)
            muse.unregisterErrorListener(errorListener)
        } catch (_: Throwable) {
        }
    }

    fun dispose() {
        detachAll()
        dataTypes.clear()
    }
}

/** A [MuseFileWriter] plus any native "record this headband" pipes. */
internal class WriterHandle(val writer: MuseFileWriter) {
    private val recordings = HashMap<String, Recording>()

    private inner class Recording(val muse: Muse, val types: Set<MuseDataPacketType>, val messageId: Int) {
        val listener = object : MuseDataListener() {
            override fun receiveMuseDataPacket(p: MuseDataPacket, m: Muse?) {
                writer.addDataPacket(messageId, p)
            }

            override fun receiveMuseArtifactPacket(p: MuseArtifactPacket, m: Muse?) {
                writer.addArtifactPacket(messageId, p)
            }
        }

        fun start() = types.forEach { muse.registerDataListener(listener, it) }
        fun stop() = types.forEach { muse.unregisterDataListener(listener, it) }
    }

    /** Writes packets of [types] from [muse] straight to the file, without a Dart round trip. */
    fun startRecording(museId: String, muse: Muse, types: Set<MuseDataPacketType>, messageId: Int) {
        stopRecording(museId)
        recordings[museId] = Recording(muse, types, messageId).also { it.start() }
    }

    fun stopRecording(museId: String?) {
        if (museId == null) {
            recordings.values.forEach { it.stop() }
            recordings.clear()
        } else {
            recordings.remove(museId)?.stop()
        }
    }

    fun dispose() {
        stopRecording(null)
        try {
            writer.close()
        } catch (_: Throwable) {
        }
    }
}

/** A [ReaderMuse] built from a file reader, plus its Muse view. */
internal class ReaderMuseHandle(
    val id: Int,
    val readerMuse: ReaderMuse,
    val museHandle: MuseHandle,
    val async: Boolean,
    emitter: EventEmitter,
) {
    private val readerListener = object : ReaderListener() {
        override fun receiveAnnotation(a: AnnotationData) = send("annotation", Codec.annotation(a))
        override fun receiveConfiguration(c: MuseConfiguration) = send("configuration", Codec.configuration(c))
        override fun receiveVersion(v: MuseVersion) = send("version", Codec.version(v))
        override fun receiveComputingDeviceConfiguration(c: ComputingDeviceConfiguration) =
            send("computingDevice", Codec.computingDevice(c))

        private fun send(kind: String, payload: Any?) = emitter.emit(mapOf(
            "event" to "readerMessage", "readerMuseId" to id, "kind" to kind, "payload" to payload,
        ))
    }

    private val playbackListener = object : ReaderPlaybackListener() {
        override fun receivePlaybackDone() = send("done")
        override fun receivePlaybackInterrupted() = send("interrupted")

        private fun send(kind: String) = emitter.emit(mapOf(
            "event" to "playback", "readerMuseId" to id, "kind" to kind,
        ))
    }

    init {
        readerMuse.setReaderListener(readerListener)
        readerMuse.setPlaybackListener(playbackListener)
    }

    fun dispose() {
        try {
            readerMuse.stopPlayback()
        } catch (_: Throwable) {
        }
        museHandle.dispose()
    }
}

/** Keeps a reference to the reader so it is not collected while in use. */
internal class ReaderHandle(val reader: MuseFileReader)
