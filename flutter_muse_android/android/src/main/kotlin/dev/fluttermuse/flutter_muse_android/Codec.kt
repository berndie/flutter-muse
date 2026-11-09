package dev.fluttermuse.flutter_muse_android

import com.choosemuse.libmuse.Accelerometer
import com.choosemuse.libmuse.AdvertisingStats
import com.choosemuse.libmuse.AnnotationData
import com.choosemuse.libmuse.AnnotationFormat
import com.choosemuse.libmuse.ApiVersion
import com.choosemuse.libmuse.Battery
import com.choosemuse.libmuse.ComputingDeviceConfiguration
import com.choosemuse.libmuse.DrlRef
import com.choosemuse.libmuse.DspData
import com.choosemuse.libmuse.Eeg
import com.choosemuse.libmuse.Error
import com.choosemuse.libmuse.Gyro
import com.choosemuse.libmuse.LogPacket
import com.choosemuse.libmuse.Magnetometer
import com.choosemuse.libmuse.MessageType
import com.choosemuse.libmuse.Muse
import com.choosemuse.libmuse.MuseArtifactPacket
import com.choosemuse.libmuse.MuseConfiguration
import com.choosemuse.libmuse.MuseDataPacket
import com.choosemuse.libmuse.MuseDataPacketType
import com.choosemuse.libmuse.MuseFileReader
import com.choosemuse.libmuse.MuseVersion
import com.choosemuse.libmuse.Ppg
import com.choosemuse.libmuse.Pressure
import com.choosemuse.libmuse.Result
import com.choosemuse.libmuse.UltraViolet
import java.util.EnumSet

/**
 * Conversions between libmuse objects and platform-channel values.
 *
 * Enums are always sent as their Java ordinal; the Dart enums are generated
 * from the jar in the same order (tool/generate_enums.py).
 */
internal object Codec {
    const val KIND_DATA = 0
    const val KIND_ARTIFACT = 1

    private val EEG = Eeg.values()
    private val ACC = Accelerometer.values()
    private val GYRO = Gyro.values()
    private val MAG = Magnetometer.values()
    private val BATTERY = Battery.values()
    private val DRL_REF = DrlRef.values()
    private val PRESSURE = Pressure.values()
    private val UV = UltraViolet.values()
    private val PPG = Ppg.values()

    /** Packet types whose values are addressed per EEG channel. */
    private val EEG_CHANNEL_TYPES: EnumSet<MuseDataPacketType> = EnumSet.of(
        MuseDataPacketType.EEG,
        MuseDataPacketType.QUANTIZATION,
        MuseDataPacketType.ALPHA_ABSOLUTE, MuseDataPacketType.BETA_ABSOLUTE,
        MuseDataPacketType.DELTA_ABSOLUTE, MuseDataPacketType.THETA_ABSOLUTE,
        MuseDataPacketType.GAMMA_ABSOLUTE,
        MuseDataPacketType.ALPHA_RELATIVE, MuseDataPacketType.BETA_RELATIVE,
        MuseDataPacketType.DELTA_RELATIVE, MuseDataPacketType.THETA_RELATIVE,
        MuseDataPacketType.GAMMA_RELATIVE,
        MuseDataPacketType.ALPHA_SCORE, MuseDataPacketType.BETA_SCORE,
        MuseDataPacketType.DELTA_SCORE, MuseDataPacketType.THETA_SCORE,
        MuseDataPacketType.GAMMA_SCORE,
        MuseDataPacketType.IS_GOOD,
        MuseDataPacketType.HSI, MuseDataPacketType.HSI_PRECISION,
        MuseDataPacketType.NOTCH_FILTERED_EEG,
        MuseDataPacketType.VARIANCE_EEG, MuseDataPacketType.VARIANCE_NOTCH_FILTERED_EEG,
    )

    /** Message types in a .muse file whose payload is a [MuseDataPacket]. */
    private val DATA_MESSAGE_TYPES: EnumSet<MessageType> = EnumSet.of(
        MessageType.EEG, MessageType.QUANTIZATION, MessageType.ACCELEROMETER,
        MessageType.BATTERY, MessageType.GYRO, MessageType.PRESSURE,
        MessageType.TEMPERATURE, MessageType.ULTRA_VIOLET, MessageType.MAGNETOMETER,
        MessageType.PPG, MessageType.EEG_DROPPED, MessageType.ACC_DROPPED,
        MessageType.ALG_VALUE, MessageType.MUSE_ELEMENTS,
    )

    inline fun <reified T : Enum<T>> enumAt(ordinal: Int): T = enumValues<T>()[ordinal]

    // ---------------------------------------------------------------- packets

    /**
     * `[KIND_DATA, museId, typeOrdinal, timestamp, values, accessorValues]`.
     *
     * `accessorValues` holds the result of the SDK's typed accessor
     * (getEegChannelValue, getBatteryValue, ...) for every value of the
     * matching enum, in ordinal order, or null when the packet type has no
     * typed accessor. Computing it here, through the SDK itself, avoids
     * guessing the SDK's internal value layout.
     */
    fun encodeDataPacket(museId: String?, p: MuseDataPacket): List<Any?> {
        val type = p.packetType()
        val raw = p.values()
        val values = DoubleArray(raw.size) { raw[it] ?: Double.NaN }
        return listOf(KIND_DATA, museId, type.ordinal, p.timestamp(), values, accessorValues(p, type, values.size))
    }

    fun encodeArtifact(museId: String?, a: MuseArtifactPacket): List<Any?> =
        listOf(KIND_ARTIFACT, museId, a.headbandOn, a.blink, a.jawClench, a.timestamp)

    private fun accessorValues(p: MuseDataPacket, type: MuseDataPacketType, size: Int): DoubleArray? =
        when {
            // Only ask for channels the packet actually carries.
            type in EEG_CHANNEL_TYPES -> safe(EEG.size) { if (it < size) p.getEegChannelValue(EEG[it]) else Double.NaN }
            type == MuseDataPacketType.ACCELEROMETER -> safe(ACC.size) { p.getAccelerometerValue(ACC[it]) }
            type == MuseDataPacketType.GYRO -> safe(GYRO.size) { p.getGyroValue(GYRO[it]) }
            type == MuseDataPacketType.MAGNETOMETER -> safe(MAG.size) { p.getMagnetometerValue(MAG[it]) }
            type == MuseDataPacketType.BATTERY -> safe(BATTERY.size) { p.getBatteryValue(BATTERY[it]) }
            type == MuseDataPacketType.DRL_REF -> safe(DRL_REF.size) { p.getDrlRefValue(DRL_REF[it]) }
            type == MuseDataPacketType.PRESSURE -> safe(PRESSURE.size) { p.getPressureValue(PRESSURE[it]) }
            type == MuseDataPacketType.ULTRA_VIOLET -> safe(UV.size) { p.getUvValue(UV[it]) }
            type == MuseDataPacketType.PPG -> safe(PPG.size) { if (it < size) p.getPpgChannelValue(PPG[it]) else Double.NaN }
            type == MuseDataPacketType.TEMPERATURE -> safe(1) { p.temperatureValue }
            else -> null
        }

    private inline fun safe(n: Int, f: (Int) -> Double) =
        DoubleArray(n) { i -> try { f(i) } catch (t: Throwable) { Double.NaN } }

    /** Builds a native packet from Dart `{type, timestamp, values}`. */
    fun decodeDataPacket(m: Map<*, *>): MuseDataPacket {
        val type = enumAt<MuseDataPacketType>(m["type"] as Int)
        val timestamp = (m["timestamp"] as Number).toLong()
        val values = ArrayList<Double>()
        (m["values"] as? DoubleArray)?.forEach { values.add(it) }
            ?: (m["values"] as List<*>).forEach { values.add((it as Number).toDouble()) }
        return MuseDataPacket.makePacket(type, timestamp, values)
    }

    fun decodeArtifact(m: Map<*, *>) = MuseArtifactPacket(
        m["headbandOn"] as Boolean,
        m["blink"] as Boolean,
        m["jawClench"] as Boolean,
        (m["timestamp"] as Number).toLong(),
    )

    fun artifactMap(a: MuseArtifactPacket): Map<String, Any?> = mapOf(
        "headbandOn" to a.headbandOn,
        "blink" to a.blink,
        "jawClench" to a.jawClench,
        "timestamp" to a.timestamp,
    )

    // ------------------------------------------------------------- muse info

    fun museInfo(id: String, muse: Muse): Map<String, Any?> = mapOf(
        "id" to id,
        "name" to tryOrNull { muse.name },
        "macAddress" to tryOrNull { muse.macAddress },
        "model" to tryOrNull { muse.model?.ordinal },
        "rssi" to tryOrNull { muse.rssi },
        "lastDiscoveredTime" to tryOrNull { muse.lastDiscoveredTime },
        "connectionState" to tryOrNull { muse.connectionState?.ordinal },
        "isLowEnergy" to tryOrNull { muse.isLowEnergy },
        "isPaired" to tryOrNull { muse.isPaired },
        "isConnectable" to tryOrNull { muse.isConnectable },
    )

    fun configuration(c: MuseConfiguration?): Map<String, Any?>? = c?.let {
        mapOf(
            "headbandName" to it.headbandName,
            "microcontrollerId" to it.microcontrollerId,
            "preset" to it.preset?.ordinal,
            "eegChannelCount" to it.eegChannelCount,
            "afeGain" to it.afeGain,
            "downsampleRate" to it.downsampleRate,
            "seroutMode" to it.seroutMode,
            "outputFrequency" to it.outputFrequency,
            "adcFrequency" to it.adcFrequency,
            "notchFilterEnabled" to it.notchFilterEnabled,
            "notchFilter" to it.notchFilter?.ordinal,
            "accelerometerSampleFrequency" to it.accelerometerSampleFrequency,
            "batteryDataEnabled" to it.batteryDataEnabled,
            "drlRefEnabled" to it.drlRefEnabled,
            "drlRefFrequency" to it.drlRefFrequency,
            "batteryPercentRemaining" to it.batteryPercentRemaining,
            "bluetoothMac" to it.bluetoothMac,
            "serialNumber" to it.serialNumber,
            "headsetSerialNumber" to it.headsetSerialNumber,
            "model" to it.model?.ordinal,
            "licenseNonce" to it.licenseNonce,
        )
    }

    fun version(v: MuseVersion?): Map<String, Any?>? = v?.let {
        mapOf(
            "hardwareVersion" to it.hardwareVersion,
            "firmwareVersion" to it.firmwareVersion,
            "bootloaderVersion" to it.bootloaderVersion,
            "firmwareBuildNumber" to it.firmwareBuildNumber,
            "firmwareType" to it.firmwareType,
            "protocolVersion" to it.protocolVersion,
            "bspVersion" to it.bspVersion,
            "runningState" to it.runningState,
        )
    }

    fun apiVersion(v: ApiVersion): Map<String, Any?> = mapOf(
        "major" to v.major,
        "minor" to v.minor,
        "patch" to v.patch,
        "api" to v.api,
        "monotonic" to v.monotonic,
        "string" to v.string,
    )

    fun computingDevice(c: ComputingDeviceConfiguration?): Map<String, Any?>? = c?.let {
        mapOf(
            "osType" to it.osType,
            "osVersion" to it.osVersion,
            "hardwareModelName" to it.hardwareModelName,
            "hardwareModelId" to it.hardwareModelId,
            "processorName" to it.processorName,
            "processorSpeed" to it.processorSpeed,
            "numberOfProcessors" to it.numberOfProcessors,
            "memorySize" to it.memorySize,
            "bluetoothVersion" to it.bluetoothVersion,
            "timeZone" to it.timeZone,
            "timeZoneOffsetSeconds" to it.timeZoneOffsetSeconds,
        )
    }

    fun decodeComputingDevice(m: Map<*, *>) = ComputingDeviceConfiguration(
        m["osType"] as String,
        m["osVersion"] as String,
        m["hardwareModelName"] as String,
        m["hardwareModelId"] as String,
        m["processorName"] as String,
        m["processorSpeed"] as String,
        m["numberOfProcessors"] as Int,
        m["memorySize"] as String,
        m["bluetoothVersion"] as String,
        m["timeZone"] as String,
        m["timeZoneOffsetSeconds"] as Int,
    )

    fun annotation(a: AnnotationData?): Map<String, Any?>? = a?.let {
        mapOf(
            "data" to it.data,
            "format" to it.format?.ordinal,
            "eventType" to it.eventType,
            "eventId" to it.eventId,
            "parentId" to it.parentId,
        )
    }

    fun decodeAnnotation(m: Map<*, *>) = AnnotationData(
        m["data"] as String,
        enumAt<AnnotationFormat>(m["format"] as Int),
        m["eventType"] as String,
        m["eventId"] as String,
        m["parentId"] as String,
    )

    fun dsp(d: DspData?): Map<String, Any?>? = d?.let {
        mapOf(
            "type" to it.type,
            "floatArray" to it.floatArray.map { v -> v ?: Double.NaN },
            "intArray" to it.intArray.map { v -> v ?: 0L },
            "version" to it.version,
        )
    }

    fun decodeDsp(m: Map<*, *>) = DspData(
        m["type"] as String,
        ArrayList((m["floatArray"] as List<*>).map { (it as Number).toDouble() }),
        ArrayList((m["intArray"] as List<*>).map { (it as Number).toLong() }),
        m["version"] as String,
    )

    fun result(r: Result): Map<String, Any?> = mapOf(
        "level" to r.level?.ordinal,
        "code" to r.code,
        "type" to r.type,
        "info" to r.info,
    )

    fun error(e: Error): Map<String, Any?> = mapOf(
        "type" to e.type?.ordinal,
        "code" to e.code,
        "info" to e.info,
    )

    fun logPacket(p: LogPacket): Map<String, Any?> = mapOf(
        "severity" to p.severity?.ordinal,
        "raw" to p.raw,
        "tag" to p.tag,
        "timestamp" to p.timestamp,
        "message" to p.message,
    )

    fun advertisingStats(s: AdvertisingStats?): Map<String, Any?>? = s?.let {
        mapOf(
            "numAdvertisingPackets" to it.numAdvertisingPackets,
            "avgAdvertisingInterval" to it.avgAdvertisingInterval,
            "maxAdvertisingInterval" to it.maxAdvertisingInterval,
            "sigmaAdvertisingInterval" to it.sigmaAdvertisingInterval,
            "hasBadMac" to it.hasBadMac,
            "isLost" to it.isLost,
        )
    }

    // ------------------------------------------------------------ file reader

    /** Encodes the reader's current message together with its payload. */
    fun fileMessage(r: MuseFileReader): Map<String, Any?> {
        val type = r.messageType
        val m = hashMapOf<String, Any?>(
            "type" to type?.ordinal,
            "id" to r.messageId,
            "timestamp" to r.messageTimestamp,
        )
        when (type) {
            null -> {}
            MessageType.ARTIFACT -> m["artifact"] = tryOrNull { artifactMap(r.artifactPacket) }
            MessageType.ANNOTATION -> m["annotation"] = tryOrNull { annotation(r.annotation) }
            MessageType.CONFIGURATION -> m["configuration"] = tryOrNull { configuration(r.configuration) }
            MessageType.VERSION -> m["version"] = tryOrNull { version(r.version) }
            MessageType.COMPUTING_DEVICE -> m["computingDevice"] = tryOrNull { computingDevice(r.computingDeviceConfiguration) }
            MessageType.DSP -> m["dsp"] = tryOrNull { dsp(r.dsp) }
            in DATA_MESSAGE_TYPES -> m["packet"] = tryOrNull { encodeDataPacket(null, r.dataPacket) }
            else -> {}
        }
        return m
    }

    inline fun <T> tryOrNull(f: () -> T): T? = try { f() } catch (t: Throwable) { null }
}
