import 'dart:typed_data';

import 'enums.g.dart';
import 'map_helpers.dart';

// Models shared by the app-facing package and platform implementations.
// `fromMap` / `toMap` use the standard platform-channel codec representation
// so implementations built on method channels can share them.

/// Result of initialising the SDK.
class MuseSdkStatus {
  /// Creates a status.
  const MuseSdkStatus({required this.nativeLibraryLoaded, this.error, this.libmuseVersion});

  /// Whether `libmuse_android.so` was found and loaded.
  final bool nativeLibraryLoaded;

  /// Why the SDK could not be loaded, if it could not.
  final String? error;

  /// The SDK version, when the SDK loaded.
  final ApiVersion? libmuseVersion;

  @override
  String toString() => 'MuseSdkStatus(nativeLibraryLoaded: $nativeLibraryLoaded, '
      'version: ${libmuseVersion?.string}, error: $error)';
}

/// Mirrors `ApiVersion` (from `LibmuseVersion.instance()`).
class ApiVersion {
  /// Creates a version.
  const ApiVersion({
    required this.major,
    required this.minor,
    required this.patch,
    required this.api,
    required this.monotonic,
    required this.string,
  });

  /// Decodes the platform-channel representation.
  factory ApiVersion.fromMap(Map<String, Object?> m) => ApiVersion(
        major: m['major']! as int,
        minor: m['minor']! as int,
        patch: m['patch']! as int,
        api: m['api']! as int,
        monotonic: m['monotonic']! as int,
        string: m['string']! as String,
      );

  /// Major version.
  final int major;

  /// Minor version.
  final int minor;

  /// Patch version.
  final int patch;

  /// API level.
  final int api;

  /// Monotonically increasing build number.
  final int monotonic;

  /// Human-readable version string.
  final String string;

  @override
  String toString() => string;
}

/// One packet of sensor or algorithm data (mirrors `MuseDataPacket`).
///
/// [values] holds the raw packet values. The typed getters
/// ([getEegChannelValue], [getBatteryValue], ...) return what the SDK's own
/// accessors return; they are only available on packets that came from the
/// SDK and whose [packetType] has such an accessor.
class MuseDataPacket {
  /// Creates a packet, e.g. to write synthetic data to a .muse file.
  MuseDataPacket({required this.packetType, required this.timestamp, required List<double> values})
      : values = Float64List.fromList(values),
        museId = null,
        _accessorValues = null;

  /// Creates a packet received from the SDK. For platform implementations.
  ///
  /// [accessorValues] holds what the SDK's typed accessor for [packetType]
  /// returns for each value of the matching enum (in index order), e.g.
  /// `getEegChannelValue(Eeg.values[i])` for EEG packets; null when the
  /// packet type has no typed accessor.
  MuseDataPacket.fromNative({
    required this.packetType,
    required this.timestamp,
    required this.values,
    Float64List? accessorValues,
    this.museId,
  }) : _accessorValues = accessorValues; // ignore: prefer_initializing_formals

  /// The kind of data in this packet.
  final MuseDataPacketType packetType;

  /// Timestamp in microseconds since the Unix epoch.
  final int timestamp;

  /// Raw packet values.
  final Float64List values;

  /// Id of the headband this packet came from (null for packets read from
  /// a file or created in Dart).
  final String? museId;

  final Float64List? _accessorValues;

  /// Number of values in the packet.
  int get valuesSize => values.length;

  /// Timestamp as a [DateTime].
  DateTime get dateTime => DateTime.fromMicrosecondsSinceEpoch(timestamp);

  /// Packet types whose values are addressed per EEG channel (must match
  /// `EEG_CHANNEL_TYPES` in Codec.kt).
  static const Set<MuseDataPacketType> eegChannelTypes = {
    MuseDataPacketType.eeg,
    MuseDataPacketType.quantization,
    MuseDataPacketType.alphaAbsolute,
    MuseDataPacketType.betaAbsolute,
    MuseDataPacketType.deltaAbsolute,
    MuseDataPacketType.thetaAbsolute,
    MuseDataPacketType.gammaAbsolute,
    MuseDataPacketType.alphaRelative,
    MuseDataPacketType.betaRelative,
    MuseDataPacketType.deltaRelative,
    MuseDataPacketType.thetaRelative,
    MuseDataPacketType.gammaRelative,
    MuseDataPacketType.alphaScore,
    MuseDataPacketType.betaScore,
    MuseDataPacketType.deltaScore,
    MuseDataPacketType.thetaScore,
    MuseDataPacketType.gammaScore,
    MuseDataPacketType.isGood,
    MuseDataPacketType.hsi,
    MuseDataPacketType.hsiPrecision,
    MuseDataPacketType.notchFilteredEeg,
    MuseDataPacketType.varianceEeg,
    MuseDataPacketType.varianceNotchFilteredEeg,
  };

  double _accessor(bool applies, int index, String name) {
    final acc = _accessorValues;
    if (!applies || acc == null || index >= acc.length) {
      throw StateError('$name is not available for $packetType packets');
    }
    return acc[index];
  }

  /// EEG (or per-channel derived) value of [channel]; NaN when the packet
  /// does not carry that channel. For EEG, band power, score, IS_GOOD, HSI
  /// and variance packets.
  double getEegChannelValue(Eeg channel) =>
      _accessor(eegChannelTypes.contains(packetType), channel.index, 'getEegChannelValue');

  /// Accelerometer value on [axis] (g).
  double getAccelerometerValue(Accelerometer axis) =>
      _accessor(packetType == MuseDataPacketType.accelerometer, axis.index, 'getAccelerometerValue');

  /// Gyroscope value on [axis] (degrees/s).
  double getGyroValue(Gyro axis) => _accessor(packetType == MuseDataPacketType.gyro, axis.index, 'getGyroValue');

  /// Magnetometer value on [axis].
  double getMagnetometerValue(Magnetometer axis) =>
      _accessor(packetType == MuseDataPacketType.magnetometer, axis.index, 'getMagnetometerValue');

  /// Battery value.
  double getBatteryValue(Battery value) =>
      _accessor(packetType == MuseDataPacketType.battery, value.index, 'getBatteryValue');

  /// DRL/REF value.
  double getDrlRefValue(DrlRef value) =>
      _accessor(packetType == MuseDataPacketType.drlRef, value.index, 'getDrlRefValue');

  /// Pressure value.
  double getPressureValue(Pressure value) =>
      _accessor(packetType == MuseDataPacketType.pressure, value.index, 'getPressureValue');

  /// Ultraviolet value.
  double getUvValue(UltraViolet value) =>
      _accessor(packetType == MuseDataPacketType.ultraViolet, value.index, 'getUvValue');

  /// PPG channel value; NaN when the packet does not carry that channel.
  double getPpgChannelValue(Ppg channel) =>
      _accessor(packetType == MuseDataPacketType.ppg, channel.index, 'getPpgChannelValue');

  /// Temperature value.
  double getTemperatureValue() =>
      _accessor(packetType == MuseDataPacketType.temperature, 0, 'getTemperatureValue');

  /// Encoding used when sending a packet to native code.
  Map<String, Object?> toMap() => {'type': packetType.index, 'timestamp': timestamp, 'values': values};

  @override
  String toString() => 'MuseDataPacket($packetType, $timestamp, $values)';
}

/// Blink / jaw clench / headband-on detection (mirrors `MuseArtifactPacket`).
class MuseArtifactPacket {
  /// Creates an artifact packet.
  const MuseArtifactPacket({
    required this.headbandOn,
    required this.blink,
    required this.jawClench,
    required this.timestamp,
    this.museId,
  });

  /// Decodes the map representation (used for file messages).
  factory MuseArtifactPacket.fromMap(Map<String, Object?> m) => MuseArtifactPacket(
        headbandOn: m['headbandOn']! as bool,
        blink: m['blink']! as bool,
        jawClench: m['jawClench']! as bool,
        timestamp: m['timestamp']! as int,
      );

  /// Whether the headband is being worn.
  final bool headbandOn;

  /// Whether a blink was detected.
  final bool blink;

  /// Whether a jaw clench was detected.
  final bool jawClench;

  /// Timestamp in microseconds since the Unix epoch.
  final int timestamp;

  /// Id of the headband this packet came from, if any.
  final String? museId;

  /// Encoding used when sending a packet to native code.
  Map<String, Object?> toMap() =>
      {'headbandOn': headbandOn, 'blink': blink, 'jawClench': jawClench, 'timestamp': timestamp};

  @override
  String toString() =>
      'MuseArtifactPacket(headbandOn: $headbandOn, blink: $blink, jawClench: $jawClench, timestamp: $timestamp)';
}

/// A connection state change (mirrors `MuseConnectionPacket`).
class MuseConnectionPacket {
  /// Creates a connection packet.
  const MuseConnectionPacket({required this.previousConnectionState, required this.currentConnectionState, required this.museId});

  /// State before the change.
  final MuseConnectionState previousConnectionState;

  /// State after the change.
  final MuseConnectionState currentConnectionState;

  /// Id of the headband whose state changed.
  final String museId;

  @override
  String toString() => 'MuseConnectionPacket($museId: $previousConnectionState -> $currentConnectionState)';
}

/// An error reported by a headband (mirrors `com.choosemuse.libmuse.Error`).
class MuseError {
  /// Creates an error.
  const MuseError({required this.type, required this.code, required this.info, this.museId});

  /// Decodes the platform-channel representation.
  factory MuseError.fromMap(Map<String, Object?> m, {String? museId}) => MuseError(
        type: enumAt(ErrorType.values, m['type']),
        code: m['code']! as int,
        info: m['info'] as String? ?? '',
        museId: museId,
      );

  /// Error category.
  final ErrorType type;

  /// Error code.
  final int code;

  /// Description.
  final String info;

  /// Id of the headband that reported the error.
  final String? museId;

  @override
  String toString() => 'MuseError($type, $code, $info)';
}

/// Snapshot of a headband's properties.
class MuseInfo {
  /// Creates a snapshot.
  const MuseInfo({
    required this.id,
    this.name,
    this.macAddress,
    this.model,
    this.rssi,
    this.lastDiscoveredTime,
    this.connectionState,
    this.isLowEnergy,
    this.isPaired,
    this.isConnectable,
  });

  /// Decodes the platform-channel representation.
  factory MuseInfo.fromMap(Map<String, Object?> m) => MuseInfo(
        id: m['id']! as String,
        name: m['name'] as String?,
        macAddress: m['macAddress'] as String?,
        model: enumAtOrNull(MuseModel.values, m['model']),
        rssi: (m['rssi'] as num?)?.toDouble(),
        lastDiscoveredTime: (m['lastDiscoveredTime'] as num?)?.toDouble(),
        connectionState: enumAtOrNull(MuseConnectionState.values, m['connectionState']),
        isLowEnergy: m['isLowEnergy'] as bool?,
        isPaired: m['isPaired'] as bool?,
        isConnectable: m['isConnectable'] as bool?,
      );

  /// Plugin identifier (the MAC address for discovered headbands).
  final String id;

  /// Advertised name, e.g. `Muse-1A2B`.
  final String? name;

  /// Bluetooth MAC address.
  final String? macAddress;

  /// Hardware model.
  final MuseModel? model;

  /// Signal strength (dBm).
  final double? rssi;

  /// When the headband was last seen advertising (seconds, SDK clock).
  final double? lastDiscoveredTime;

  /// Current connection state.
  final MuseConnectionState? connectionState;

  /// Whether the headband uses Bluetooth Low Energy.
  final bool? isLowEnergy;

  /// Whether the headband is paired with this device.
  final bool? isPaired;

  /// Whether the headband can be connected to right now.
  final bool? isConnectable;

  @override
  String toString() => 'MuseInfo($name, $macAddress, $model, rssi: $rssi, $connectionState)';
}

/// Headband configuration (mirrors `MuseConfiguration`).
class MuseConfiguration {
  /// Creates a configuration snapshot.
  const MuseConfiguration({
    required this.headbandName,
    required this.microcontrollerId,
    required this.preset,
    required this.eegChannelCount,
    required this.afeGain,
    required this.downsampleRate,
    required this.seroutMode,
    required this.outputFrequency,
    required this.adcFrequency,
    required this.notchFilterEnabled,
    required this.notchFilter,
    required this.accelerometerSampleFrequency,
    required this.batteryDataEnabled,
    required this.drlRefEnabled,
    required this.drlRefFrequency,
    required this.batteryPercentRemaining,
    required this.bluetoothMac,
    required this.serialNumber,
    required this.headsetSerialNumber,
    required this.model,
    required this.licenseNonce,
  });

  /// Decodes the platform-channel representation.
  factory MuseConfiguration.fromMap(Map<String, Object?> m) => MuseConfiguration(
        headbandName: m['headbandName'] as String? ?? '',
        microcontrollerId: m['microcontrollerId'] as String? ?? '',
        preset: enumAtOrNull(MusePreset.values, m['preset']),
        eegChannelCount: m['eegChannelCount']! as int,
        afeGain: m['afeGain']! as int,
        downsampleRate: m['downsampleRate']! as int,
        seroutMode: m['seroutMode']! as int,
        outputFrequency: m['outputFrequency']! as int,
        adcFrequency: m['adcFrequency']! as int,
        notchFilterEnabled: m['notchFilterEnabled']! as bool,
        notchFilter: enumAtOrNull(NotchFrequency.values, m['notchFilter']),
        accelerometerSampleFrequency: m['accelerometerSampleFrequency']! as int,
        batteryDataEnabled: m['batteryDataEnabled']! as bool,
        drlRefEnabled: m['drlRefEnabled']! as bool,
        drlRefFrequency: m['drlRefFrequency']! as int,
        batteryPercentRemaining: (m['batteryPercentRemaining']! as num).toDouble(),
        bluetoothMac: m['bluetoothMac'] as String? ?? '',
        serialNumber: m['serialNumber'] as String? ?? '',
        headsetSerialNumber: m['headsetSerialNumber'] as String? ?? '',
        model: enumAtOrNull(MuseModel.values, m['model']),
        licenseNonce: m['licenseNonce'] as String? ?? '',
      );

  /// Headband name.
  final String headbandName;

  /// Microcontroller identifier.
  final String microcontrollerId;

  /// Active preset.
  final MusePreset? preset;

  /// Number of EEG channels.
  final int eegChannelCount;

  /// Analog front-end gain.
  final int afeGain;

  /// Downsample rate.
  final int downsampleRate;

  /// Serial output mode.
  final int seroutMode;

  /// EEG output frequency (Hz).
  final int outputFrequency;

  /// ADC frequency (Hz).
  final int adcFrequency;

  /// Whether the notch filter is enabled.
  final bool notchFilterEnabled;

  /// Notch filter frequency.
  final NotchFrequency? notchFilter;

  /// Accelerometer sample frequency (Hz).
  final int accelerometerSampleFrequency;

  /// Whether battery data is enabled.
  final bool batteryDataEnabled;

  /// Whether DRL/REF data is enabled.
  final bool drlRefEnabled;

  /// DRL/REF frequency (Hz).
  final int drlRefFrequency;

  /// Battery charge remaining (percent).
  final double batteryPercentRemaining;

  /// Bluetooth MAC address.
  final String bluetoothMac;

  /// Serial number.
  final String serialNumber;

  /// Headset serial number.
  final String headsetSerialNumber;

  /// Hardware model.
  final MuseModel? model;

  /// Nonce used to request license data.
  final String licenseNonce;

  @override
  String toString() => 'MuseConfiguration($headbandName, $model, $preset, '
      'channels: $eegChannelCount, battery: $batteryPercentRemaining%)';
}

/// Headband firmware/hardware version (mirrors `MuseVersion`).
class MuseVersion {
  /// Creates a version snapshot.
  const MuseVersion({
    required this.hardwareVersion,
    required this.firmwareVersion,
    required this.bootloaderVersion,
    required this.firmwareBuildNumber,
    required this.firmwareType,
    required this.protocolVersion,
    required this.bspVersion,
    required this.runningState,
  });

  /// Decodes the platform-channel representation.
  factory MuseVersion.fromMap(Map<String, Object?> m) => MuseVersion(
        hardwareVersion: m['hardwareVersion'] as String? ?? '',
        firmwareVersion: m['firmwareVersion'] as String? ?? '',
        bootloaderVersion: m['bootloaderVersion'] as String? ?? '',
        firmwareBuildNumber: m['firmwareBuildNumber'] as String? ?? '',
        firmwareType: m['firmwareType'] as String? ?? '',
        protocolVersion: m['protocolVersion']! as int,
        bspVersion: m['bspVersion'] as String? ?? '',
        runningState: m['runningState'] as String? ?? '',
      );

  /// Hardware version.
  final String hardwareVersion;

  /// Firmware version.
  final String firmwareVersion;

  /// Bootloader version.
  final String bootloaderVersion;

  /// Firmware build number.
  final String firmwareBuildNumber;

  /// Firmware type (e.g. consumer or research).
  final String firmwareType;

  /// Protocol version.
  final int protocolVersion;

  /// Board support package version.
  final String bspVersion;

  /// Running state.
  final String runningState;

  @override
  String toString() => 'MuseVersion(hw: $hardwareVersion, fw: $firmwareVersion, '
      'build: $firmwareBuildNumber, type: $firmwareType, protocol: $protocolVersion)';
}

/// Information about the device running the app (mirrors
/// `ComputingDeviceConfiguration`).
class ComputingDeviceConfiguration {
  /// Creates a configuration.
  const ComputingDeviceConfiguration({
    required this.osType,
    required this.osVersion,
    required this.hardwareModelName,
    required this.hardwareModelId,
    required this.processorName,
    required this.processorSpeed,
    required this.numberOfProcessors,
    required this.memorySize,
    required this.bluetoothVersion,
    required this.timeZone,
    required this.timeZoneOffsetSeconds,
  });

  /// Decodes the platform-channel representation.
  factory ComputingDeviceConfiguration.fromMap(Map<String, Object?> m) => ComputingDeviceConfiguration(
        osType: m['osType'] as String? ?? '',
        osVersion: m['osVersion'] as String? ?? '',
        hardwareModelName: m['hardwareModelName'] as String? ?? '',
        hardwareModelId: m['hardwareModelId'] as String? ?? '',
        processorName: m['processorName'] as String? ?? '',
        processorSpeed: m['processorSpeed'] as String? ?? '',
        numberOfProcessors: m['numberOfProcessors']! as int,
        memorySize: m['memorySize'] as String? ?? '',
        bluetoothVersion: m['bluetoothVersion'] as String? ?? '',
        timeZone: m['timeZone'] as String? ?? '',
        timeZoneOffsetSeconds: m['timeZoneOffsetSeconds']! as int,
      );

  /// OS type.
  final String osType;

  /// OS version.
  final String osVersion;

  /// Hardware model name.
  final String hardwareModelName;

  /// Hardware model identifier.
  final String hardwareModelId;

  /// Processor name.
  final String processorName;

  /// Processor speed.
  final String processorSpeed;

  /// Number of processors.
  final int numberOfProcessors;

  /// Memory size.
  final String memorySize;

  /// Bluetooth version.
  final String bluetoothVersion;

  /// Time zone name.
  final String timeZone;

  /// Time zone offset from UTC in seconds.
  final int timeZoneOffsetSeconds;

  /// Encoding used when sending to native code.
  Map<String, Object?> toMap() => {
        'osType': osType,
        'osVersion': osVersion,
        'hardwareModelName': hardwareModelName,
        'hardwareModelId': hardwareModelId,
        'processorName': processorName,
        'processorSpeed': processorSpeed,
        'numberOfProcessors': numberOfProcessors,
        'memorySize': memorySize,
        'bluetoothVersion': bluetoothVersion,
        'timeZone': timeZone,
        'timeZoneOffsetSeconds': timeZoneOffsetSeconds,
      };

  @override
  String toString() => 'ComputingDeviceConfiguration($osType $osVersion, $hardwareModelName)';
}

/// An annotation stored in a .muse file (mirrors `AnnotationData`).
class AnnotationData {
  /// Creates an annotation.
  const AnnotationData({
    required this.data,
    this.format = AnnotationFormat.plainString,
    this.eventType = '',
    this.eventId = '',
    this.parentId = '',
  });

  /// Decodes the platform-channel representation.
  factory AnnotationData.fromMap(Map<String, Object?> m) => AnnotationData(
        data: m['data'] as String? ?? '',
        format: enumAt(AnnotationFormat.values, m['format']),
        eventType: m['eventType'] as String? ?? '',
        eventId: m['eventId'] as String? ?? '',
        parentId: m['parentId'] as String? ?? '',
      );

  /// Annotation payload.
  final String data;

  /// Payload format.
  final AnnotationFormat format;

  /// Event type.
  final String eventType;

  /// Event identifier.
  final String eventId;

  /// Parent event identifier.
  final String parentId;

  /// Encoding used when sending to native code.
  Map<String, Object?> toMap() =>
      {'data': data, 'format': format.index, 'eventType': eventType, 'eventId': eventId, 'parentId': parentId};

  @override
  String toString() => 'AnnotationData($format, $data)';
}

/// DSP data stored in a .muse file (mirrors `DspData`).
class DspData {
  /// Creates DSP data.
  const DspData({required this.type, this.floatArray = const [], this.intArray = const [], this.version = ''});

  /// Decodes the platform-channel representation.
  factory DspData.fromMap(Map<String, Object?> m) => DspData(
        type: m['type'] as String? ?? '',
        floatArray: (m['floatArray']! as List<Object?>).map((e) => (e! as num).toDouble()).toList(),
        intArray: (m['intArray']! as List<Object?>).map((e) => e! as int).toList(),
        version: m['version'] as String? ?? '',
      );

  /// DSP type.
  final String type;

  /// Floating point values.
  final List<double> floatArray;

  /// Integer values.
  final List<int> intArray;

  /// Version.
  final String version;

  /// Encoding used when sending to native code.
  Map<String, Object?> toMap() => {'type': type, 'floatArray': floatArray, 'intArray': intArray, 'version': version};

  @override
  String toString() => 'DspData($type, $version, floats: ${floatArray.length}, ints: ${intArray.length})';
}

/// Outcome of a file operation (mirrors `com.choosemuse.libmuse.Result`).
class MuseResult {
  /// Creates a result.
  const MuseResult({required this.level, required this.code, required this.type, required this.info});

  /// Decodes the platform-channel representation.
  factory MuseResult.fromMap(Map<String, Object?> m) => MuseResult(
        level: enumAt(ResultLevel.values, m['level']),
        code: m['code']! as int,
        type: m['type'] as String? ?? '',
        info: m['info'] as String? ?? '',
      );

  /// Severity of the result.
  final ResultLevel level;

  /// Result code.
  final int code;

  /// Result type.
  final String type;

  /// Description.
  final String info;

  /// Whether the operation succeeded.
  bool get isSuccess => level == ResultLevel.rSuccess;

  @override
  String toString() => 'MuseResult($level, $code, $type, $info)';
}

/// A log line from the SDK (mirrors `LogPacket`).
class LogPacket {
  /// Creates a log packet.
  const LogPacket({required this.severity, required this.raw, required this.tag, required this.timestamp, required this.message});

  /// Decodes the platform-channel representation.
  factory LogPacket.fromMap(Map<String, Object?> m) => LogPacket(
        severity: enumAt(Severity.values, m['severity']),
        raw: m['raw']! as bool,
        tag: m['tag'] as String? ?? '',
        timestamp: (m['timestamp']! as num).toDouble(),
        message: m['message'] as String? ?? '',
      );

  /// Severity.
  final Severity severity;

  /// Whether the message is raw (unformatted).
  final bool raw;

  /// Tag.
  final String tag;

  /// Timestamp (seconds, SDK clock).
  final double timestamp;

  /// Message.
  final String message;

  @override
  String toString() => '[$severity] $tag: $message';
}

/// Bluetooth advertising statistics (mirrors `AdvertisingStats`).
class AdvertisingStats {
  /// Creates stats.
  const AdvertisingStats({
    required this.numAdvertisingPackets,
    required this.avgAdvertisingInterval,
    required this.maxAdvertisingInterval,
    required this.sigmaAdvertisingInterval,
    required this.hasBadMac,
    required this.isLost,
  });

  /// Decodes the platform-channel representation.
  factory AdvertisingStats.fromMap(Map<String, Object?> m) => AdvertisingStats(
        numAdvertisingPackets: m['numAdvertisingPackets']! as int,
        avgAdvertisingInterval: (m['avgAdvertisingInterval']! as num).toDouble(),
        maxAdvertisingInterval: (m['maxAdvertisingInterval']! as num).toDouble(),
        sigmaAdvertisingInterval: (m['sigmaAdvertisingInterval']! as num).toDouble(),
        hasBadMac: m['hasBadMac']! as bool,
        isLost: m['isLost']! as bool,
      );

  /// Number of advertising packets seen.
  final int numAdvertisingPackets;

  /// Mean advertising interval.
  final double avgAdvertisingInterval;

  /// Largest advertising interval.
  final double maxAdvertisingInterval;

  /// Standard deviation of the advertising interval.
  final double sigmaAdvertisingInterval;

  /// Whether the MAC address looked invalid.
  final bool hasBadMac;

  /// Whether the headband is considered lost.
  final bool isLost;

  @override
  String toString() => 'AdvertisingStats(n: $numAdvertisingPackets, avg: $avgAdvertisingInterval, '
      'max: $maxAdvertisingInterval, lost: $isLost)';
}

/// One message read from a .muse file.
///
/// [type] says which payload is set: [dataPacket] for sensor/algorithm
/// messages, [artifactPacket], [annotation], [configuration], [version],
/// [computingDeviceConfiguration] or [dsp] for the others.
class MuseFileMessage {
  /// Creates a message.
  const MuseFileMessage({
    required this.type,
    required this.id,
    required this.timestamp,
    this.dataPacket,
    this.artifactPacket,
    this.annotation,
    this.configuration,
    this.version,
    this.computingDeviceConfiguration,
    this.dsp,
  });

  /// Decodes the platform-channel representation.
  ///
  /// [decodePacket] decodes the data packet payload, whose encoding is
  /// implementation specific.
  factory MuseFileMessage.fromMap(Map<String, Object?> m, {required MuseDataPacket Function(Object) decodePacket}) {
    final packet = m['packet'];
    return MuseFileMessage(
      type: enumAtOrNull(MessageType.values, m['type']),
      id: m['id']! as int,
      timestamp: m['timestamp']! as int,
      dataPacket: packet == null ? null : decodePacket(packet),
      artifactPacket: m['artifact'] == null ? null : MuseArtifactPacket.fromMap(castMap(m['artifact'])),
      annotation: m['annotation'] == null ? null : AnnotationData.fromMap(castMap(m['annotation'])),
      configuration: m['configuration'] == null ? null : MuseConfiguration.fromMap(castMap(m['configuration'])),
      version: m['version'] == null ? null : MuseVersion.fromMap(castMap(m['version'])),
      computingDeviceConfiguration:
          m['computingDevice'] == null ? null : ComputingDeviceConfiguration.fromMap(castMap(m['computingDevice'])),
      dsp: m['dsp'] == null ? null : DspData.fromMap(castMap(m['dsp'])),
    );
  }

  /// Message type, or null if the SDK reported none.
  final MessageType? type;

  /// Message id (the id passed to the writer, e.g. a headband index).
  final int id;

  /// Message timestamp (microseconds since the Unix epoch).
  final int timestamp;

  /// Payload of sensor/algorithm messages.
  final MuseDataPacket? dataPacket;

  /// Payload of [MessageType.artifact] messages.
  final MuseArtifactPacket? artifactPacket;

  /// Payload of [MessageType.annotation] messages.
  final AnnotationData? annotation;

  /// Payload of [MessageType.configuration] messages.
  final MuseConfiguration? configuration;

  /// Payload of [MessageType.version] messages.
  final MuseVersion? version;

  /// Payload of [MessageType.computingDevice] messages.
  final ComputingDeviceConfiguration? computingDeviceConfiguration;

  /// Payload of [MessageType.dsp] messages.
  final DspData? dsp;

  @override
  String toString() => 'MuseFileMessage($type, id: $id, ts: $timestamp)';
}

/// Statistics of a .muse file writer.
class MuseFileWriterStats {
  /// Creates stats.
  const MuseFileWriterStats({
    required this.bufferedMessagesSize,
    required this.bufferedMessagesCount,
    required this.totalBytesWritten,
  });

  /// Decodes the platform-channel representation.
  factory MuseFileWriterStats.fromMap(Map<String, Object?> m) => MuseFileWriterStats(
        bufferedMessagesSize: m['bufferedMessagesSize']! as int,
        bufferedMessagesCount: m['bufferedMessagesCount']! as int,
        totalBytesWritten: m['totalBytesWritten']! as int,
      );

  /// `getBufferedMessagesSize()`: bytes buffered and not yet flushed.
  final int bufferedMessagesSize;

  /// `getBufferredMessagesCount()`: messages buffered and not yet flushed.
  final int bufferedMessagesCount;

  /// `getTotalBytesWritten()`.
  final int totalBytesWritten;

  @override
  String toString() => 'MuseFileWriterStats(buffered: $bufferedMessagesCount msgs / '
      '$bufferedMessagesSize B, written: $totalBytesWritten B)';
}

/// A batch of messages read from a .muse file.
class MuseFileReadBatch {
  /// Creates a batch.
  const MuseFileReadBatch({required this.messages, this.endResult});

  /// Messages read.
  final List<MuseFileMessage> messages;

  /// Why reading stopped before the batch was full (end of file or an
  /// error), if it did.
  final MuseResult? endResult;
}

/// Kind of a reader-muse playback event (`ReaderPlaybackListener`).
enum ReaderPlaybackEventKind {
  /// `receivePlaybackDone()`.
  done,

  /// `receivePlaybackInterrupted()`.
  interrupted,
}

/// Identifies a native ReaderMuse: [id] for reader-muse calls and [museId]
/// for the Muse view of it (`asMuse()`).
typedef ReaderMuseRef = ({int id, String museId});
