import 'dart:typed_data';

import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'enums.g.dart';
import 'events.dart';
import 'models.dart';

/// The interface that platform implementations of `flutter_muse` extend.
///
/// Implementations must extend this class (not implement it) so that new
/// methods added here do not break them. Every method mirrors one call of
/// the Muse SDK (libmuse); headbands are referred to by an id string (the
/// MAC address for discovered headbands), files and reader muses by integer
/// ids returned from the `create*` methods.
abstract class FlutterMusePlatform extends PlatformInterface {
  /// Constructs a FlutterMusePlatform.
  FlutterMusePlatform() : super(token: _token);

  static final Object _token = Object();

  static FlutterMusePlatform _instance = _UnsupportedFlutterMusePlatform();

  /// The platform implementation in use. Platform packages set it from
  /// their `registerWith`.
  static FlutterMusePlatform get instance => _instance;

  static set instance(FlutterMusePlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  /// Events from the SDK (headband list changes, connection changes,
  /// errors, data and artifact packets, logs and reader-muse callbacks).
  Stream<MusePlatformEvent> get events => throw UnimplementedError('events has not been implemented.');


  // -------- General

  /// Loads the SDK and starts delivering [events]. Called once per Dart isolate before anything else; also resets native state left over from a previous isolate (hot restart). Data packets may be delivered in batches collected over [packetBatchInterval].
  Future<MuseSdkStatus> initialize({required Duration packetBatchInterval}) =>
      throw UnimplementedError('initialize() has not been implemented.');

  /// Changes the packet batch interval.
  Future<void> setPacketBatchInterval(Duration interval) =>
      throw UnimplementedError('setPacketBatchInterval() has not been implemented.');

  /// Whether the permissions needed for Bluetooth scanning and connecting are granted.
  Future<bool> hasPermissions() =>
      throw UnimplementedError('hasPermissions() has not been implemented.');

  /// Requests the Bluetooth permissions; returns the status of each.
  Future<Map<String, bool>> requestPermissions() =>
      throw UnimplementedError('requestPermissions() has not been implemented.');

  /// Whether Bluetooth is on.
  Future<bool> isBluetoothEnabled() =>
      throw UnimplementedError('isBluetoothEnabled() has not been implemented.');

  /// `LibmuseVersion.instance()`.
  Future<ApiVersion> getLibmuseVersion() =>
      throw UnimplementedError('getLibmuseVersion() has not been implemented.');

  /// `Stringify.connectionState(state)`.
  Future<String> stringifyConnectionState(MuseConnectionState state) =>
      throw UnimplementedError('stringifyConnectionState() has not been implemented.');

  /// `Stringify.packetType(type)`.
  Future<String> stringifyPacketType(MuseDataPacketType type) =>
      throw UnimplementedError('stringifyPacketType() has not been implemented.');

  /// `ComputingDeviceConfigurationFactory.getComputingDeviceConfiguration()`.
  Future<ComputingDeviceConfiguration> getComputingDeviceConfiguration() =>
      throw UnimplementedError('getComputingDeviceConfiguration() has not been implemented.');

  /// `MuseVersion.makeDefaultVersion()`.
  Future<MuseVersion> makeDefaultVersion() =>
      throw UnimplementedError('makeDefaultVersion() has not been implemented.');

  /// `MuseVersion.makeVersion(json)`.
  Future<MuseVersion> makeVersion(String json) =>
      throw UnimplementedError('makeVersion() has not been implemented.');


  // -------- Muse Elements algorithm settings

  /// `MuseElementsAlgorithmSettings.getElementsVersion()`.
  Future<MuseElementsVersion?> getElementsVersion() =>
      throw UnimplementedError('getElementsVersion() has not been implemented.');

  /// `MuseElementsAlgorithmSettings.setElementsVersion(version)`.
  Future<void> setElementsVersion(MuseElementsVersion version) =>
      throw UnimplementedError('setElementsVersion() has not been implemented.');

  /// `MuseElementsAlgorithmSettings.getEnableMultipleMuseElements()`.
  Future<bool> getEnableMultipleMuseElements() =>
      throw UnimplementedError('getEnableMultipleMuseElements() has not been implemented.');

  /// `MuseElementsAlgorithmSettings.setEnableMultipleMuseElements(enabled)`.
  Future<void> setEnableMultipleMuseElements(bool enabled) =>
      throw UnimplementedError('setEnableMultipleMuseElements() has not been implemented.');


  // -------- Logging

  /// `LogManager.setMinimumSeverity(severity)`.
  Future<void> setLogMinimumSeverity(Severity severity) =>
      throw UnimplementedError('setLogMinimumSeverity() has not been implemented.');

  /// `LogManager.writeLog(severity, raw, tag, message)`.
  Future<void> writeLog(Severity severity, String tag, String message, {bool raw = false}) =>
      throw UnimplementedError('writeLog() has not been implemented.');

  /// `LogManager.getTimestamp()`.
  Future<int> getLogTimestamp() =>
      throw UnimplementedError('getLogTimestamp() has not been implemented.');

  /// `LogManager.timeSince(timestamp)`.
  Future<double> logTimeSince(int timestamp) =>
      throw UnimplementedError('logTimeSince() has not been implemented.');

  /// Enables [MuseLogEvent]s (`LogManager.setLogListener`); when disabled, restores the SDK's default log listener.
  Future<void> setLogListenerEnabled(bool enabled, {bool forwardToSystemLog = true}) =>
      throw UnimplementedError('setLogListenerEnabled() has not been implemented.');

  /// `MuseLog.log(severity, message, raw)`.
  Future<void> museLog(Severity severity, String message, {bool raw = false}) =>
      throw UnimplementedError('museLog() has not been implemented.');


  // -------- Manager

  /// `MuseManager.startListening()`.
  Future<void> startListening() =>
      throw UnimplementedError('startListening() has not been implemented.');

  /// `MuseManager.stopListening()`.
  Future<void> stopListening() =>
      throw UnimplementedError('stopListening() has not been implemented.');

  /// `MuseManager.getMuses()`.
  Future<List<MuseInfo>> getMuses() =>
      throw UnimplementedError('getMuses() has not been implemented.');

  /// `MuseManager.removeFromListAfter(seconds)`.
  Future<void> removeFromListAfter(Duration duration) =>
      throw UnimplementedError('removeFromListAfter() has not been implemented.');

  /// `MuseManager.resetAdvertisingStats()`.
  Future<void> resetAdvertisingStats() =>
      throw UnimplementedError('resetAdvertisingStats() has not been implemented.');

  /// `MuseManager.getAdvertisingStats(muse)`.
  Future<AdvertisingStats?> getAdvertisingStats(String museId) =>
      throw UnimplementedError('getAdvertisingStats() has not been implemented.');

  /// `MuseManagerAndroid.setCompanionMode(enabled, macAddress, manufacturerData, removeOthers)`.
  Future<void> setCompanionMode(bool enabled, {String? macAddress, Uint8List? manufacturerData, bool removeOthers = false}) =>
      throw UnimplementedError('setCompanionMode() has not been implemented.');

  /// `MuseManagerAndroid.museUuid()`.
  Future<String> museUuid() =>
      throw UnimplementedError('museUuid() has not been implemented.');


  // -------- Muse

  /// Reads all `Muse` properties.
  Future<MuseInfo> getMuseInfo(String museId) =>
      throw UnimplementedError('getMuseInfo() has not been implemented.');

  /// `Muse.connect()`.
  Future<void> connect(String museId) =>
      throw UnimplementedError('connect() has not been implemented.');

  /// `Muse.disconnect()`.
  Future<void> disconnect(String museId) =>
      throw UnimplementedError('disconnect() has not been implemented.');

  /// `Muse.runAsynchronously()`.
  Future<void> runAsynchronously(String museId) =>
      throw UnimplementedError('runAsynchronously() has not been implemented.');

  /// `Muse.execute()`.
  Future<void> execute(String museId) =>
      throw UnimplementedError('execute() has not been implemented.');

  /// `Muse.enableDataTransmission(enabled)`.
  Future<void> enableDataTransmission(String museId, bool enabled) =>
      throw UnimplementedError('enableDataTransmission() has not been implemented.');

  /// `Muse.enableException(enabled)`.
  Future<void> enableException(String museId, bool enabled) =>
      throw UnimplementedError('enableException() has not been implemented.');

  /// `Muse.enableLedIndicator(enabled)`.
  Future<void> enableLedIndicator(String museId, bool enabled) =>
      throw UnimplementedError('enableLedIndicator() has not been implemented.');

  /// `Muse.setPreset(preset)`.
  Future<void> setPreset(String museId, MusePreset preset) =>
      throw UnimplementedError('setPreset() has not been implemented.');

  /// `Muse.setNotchFrequency(frequency)`.
  Future<void> setNotchFrequency(String museId, NotchFrequency frequency) =>
      throw UnimplementedError('setNotchFrequency() has not been implemented.');

  /// `Muse.setNumConnectTries(tries)`.
  Future<void> setNumConnectTries(String museId, int tries) =>
      throw UnimplementedError('setNumConnectTries() has not been implemented.');

  /// `Muse.setLicenseData(data)`.
  Future<void> setLicenseData(String museId, Uint8List data) =>
      throw UnimplementedError('setLicenseData() has not been implemented.');

  /// `Muse.getMuseConfiguration()`.
  Future<MuseConfiguration?> getMuseConfiguration(String museId) =>
      throw UnimplementedError('getMuseConfiguration() has not been implemented.');

  /// `Muse.getMuseVersion()`.
  Future<MuseVersion?> getMuseVersion(String museId) =>
      throw UnimplementedError('getMuseVersion() has not been implemented.');

  /// Starts delivering [MuseDataPacketEvent]s (or [MuseArtifactPacketEvent]s for [MuseDataPacketType.artifacts]) of [type] for the headband (`Muse.registerDataListener`). Idempotent.
  Future<void> registerDataType(String museId, MuseDataPacketType type) =>
      throw UnimplementedError('registerDataType() has not been implemented.');

  /// Stops delivering packets of [type] (`Muse.unregisterDataListener`). Idempotent.
  Future<void> unregisterDataType(String museId, MuseDataPacketType type) =>
      throw UnimplementedError('unregisterDataType() has not been implemented.');

  /// `Muse.unregisterAllListeners()`; connection and error events keep being delivered.
  Future<void> unregisterAllListeners(String museId) =>
      throw UnimplementedError('unregisterAllListeners() has not been implemented.');


  // -------- File writer

  /// `MuseFileFactory.getMuseFileWriter(file)`; returns a writer id.
  Future<int> createFileWriter(String path) =>
      throw UnimplementedError('createFileWriter() has not been implemented.');

  /// `MuseFileWriter.open()`.
  Future<bool> writerOpen(int writerId) =>
      throw UnimplementedError('writerOpen() has not been implemented.');

  /// `MuseFileWriter.close()`.
  Future<bool> writerClose(int writerId) =>
      throw UnimplementedError('writerClose() has not been implemented.');

  /// `MuseFileWriter.flush()`.
  Future<bool> writerFlush(int writerId) =>
      throw UnimplementedError('writerFlush() has not been implemented.');

  /// `MuseFileWriter.addDataPacket(id, packet)`.
  Future<void> writerAddDataPacket(int writerId, int messageId, MuseDataPacket packet) =>
      throw UnimplementedError('writerAddDataPacket() has not been implemented.');

  /// `MuseFileWriter.addArtifactPacket(id, packet)`.
  Future<void> writerAddArtifactPacket(int writerId, int messageId, MuseArtifactPacket packet) =>
      throw UnimplementedError('writerAddArtifactPacket() has not been implemented.');

  /// `MuseFileWriter.addAnnotation(id, annotation)`.
  Future<void> writerAddAnnotation(int writerId, int messageId, AnnotationData annotation) =>
      throw UnimplementedError('writerAddAnnotation() has not been implemented.');

  /// `MuseFileWriter.addAnnotationString(id, annotation)`.
  Future<void> writerAddAnnotationString(int writerId, int messageId, String annotation) =>
      throw UnimplementedError('writerAddAnnotationString() has not been implemented.');

  /// `addConfiguration(id, muse.getMuseConfiguration())`.
  Future<void> writerAddConfigurationFromMuse(int writerId, int messageId, String museId) =>
      throw UnimplementedError('writerAddConfigurationFromMuse() has not been implemented.');

  /// `addConfiguration(id, reader.getConfiguration())`.
  Future<void> writerAddConfigurationFromReader(int writerId, int messageId, int readerId) =>
      throw UnimplementedError('writerAddConfigurationFromReader() has not been implemented.');

  /// `addVersion(id, muse.getMuseVersion())`.
  Future<void> writerAddVersionFromMuse(int writerId, int messageId, String museId) =>
      throw UnimplementedError('writerAddVersionFromMuse() has not been implemented.');

  /// `addVersion(id, reader.getVersion())`.
  Future<void> writerAddVersionFromReader(int writerId, int messageId, int readerId) =>
      throw UnimplementedError('writerAddVersionFromReader() has not been implemented.');

  /// `addVersion(id, MuseVersion.makeVersion(json))`, or the default version when [json] is null.
  Future<void> writerAddVersionFromJson(int writerId, int messageId, String? json) =>
      throw UnimplementedError('writerAddVersionFromJson() has not been implemented.');

  /// `addComputingDeviceConfiguration(id, configuration)`; this device's configuration when null.
  Future<void> writerAddComputingDeviceConfiguration(int writerId, int messageId, ComputingDeviceConfiguration? configuration) =>
      throw UnimplementedError('writerAddComputingDeviceConfiguration() has not been implemented.');

  /// `MuseFileWriter.addDsp(id, dsp)`.
  Future<void> writerAddDsp(int writerId, int messageId, DspData dsp) =>
      throw UnimplementedError('writerAddDsp() has not been implemented.');

  /// `MuseFileWriter.setTimestamp(timestamp)`.
  Future<void> writerSetTimestamp(int writerId, int timestamp) =>
      throw UnimplementedError('writerSetTimestamp() has not been implemented.');

  /// `MuseFileWriter.setTimestampMode(mode)`.
  Future<void> writerSetTimestampMode(int writerId, TimestampMode mode) =>
      throw UnimplementedError('writerSetTimestampMode() has not been implemented.');

  /// `MuseFileWriter.discardBufferedPackets()`.
  Future<void> writerDiscardBufferedPackets(int writerId) =>
      throw UnimplementedError('writerDiscardBufferedPackets() has not been implemented.');

  /// Buffer and size statistics.
  Future<MuseFileWriterStats> writerGetStats(int writerId) =>
      throw UnimplementedError('writerGetStats() has not been implemented.');

  /// Writes packets of [types] from the headband to the file natively.
  Future<void> writerStartRecording(int writerId, String museId, List<MuseDataPacketType> types, int messageId) =>
      throw UnimplementedError('writerStartRecording() has not been implemented.');

  /// Stops [writerStartRecording] for one headband, or all when [museId] is null.
  Future<void> writerStopRecording(int writerId, String? museId) =>
      throw UnimplementedError('writerStopRecording() has not been implemented.');

  /// Stops recordings, closes the file and frees the writer.
  Future<void> disposeFileWriter(int writerId) =>
      throw UnimplementedError('disposeFileWriter() has not been implemented.');


  // -------- File reader

  /// `MuseFileFactory.getMuseFileReader(file)`; returns a reader id.
  Future<int> createFileReader(String path) =>
      throw UnimplementedError('createFileReader() has not been implemented.');

  /// `MuseFileReader.open()`.
  Future<bool> readerOpen(int readerId) =>
      throw UnimplementedError('readerOpen() has not been implemented.');

  /// `MuseFileReader.close()`.
  Future<bool> readerClose(int readerId) =>
      throw UnimplementedError('readerClose() has not been implemented.');

  /// `MuseFileReader.gotoNextMessage()`.
  Future<MuseResult> readerGotoNextMessage(int readerId) =>
      throw UnimplementedError('readerGotoNextMessage() has not been implemented.');

  /// The current message and its payload.
  Future<MuseFileMessage> readerCurrentMessage(int readerId) =>
      throw UnimplementedError('readerCurrentMessage() has not been implemented.');

  /// Reads up to [max] messages.
  Future<MuseFileReadBatch> readerReadMessages(int readerId, int max) =>
      throw UnimplementedError('readerReadMessages() has not been implemented.');

  /// Closes the file and frees the reader.
  Future<void> disposeFileReader(int readerId) =>
      throw UnimplementedError('disposeFileReader() has not been implemented.');


  // -------- Reader muse

  /// `ReaderMuseBuilder` + `build` (or `buildWithAsync` when [async]).
  Future<ReaderMuseRef> createReaderMuse(int readerId, {Set<MuseDataPacketType>? packetTypes, Set<MuseDataPacketType>? skipPacketTypes, MuseModel? model, ReaderMusePlaybackSettings? playbackSettings, required bool async}) =>
      throw UnimplementedError('createReaderMuse() has not been implemented.');

  /// `ReaderMuse.playback()`.
  Future<void> readerMusePlayback(int readerMuseId) =>
      throw UnimplementedError('readerMusePlayback() has not been implemented.');

  /// `ReaderMuse.run()`.
  Future<void> readerMuseRun(int readerMuseId) =>
      throw UnimplementedError('readerMuseRun() has not been implemented.');

  /// `ReaderMuse.runInRealTimespan()`.
  Future<void> readerMuseRunInRealTimespan(int readerMuseId) =>
      throw UnimplementedError('readerMuseRunInRealTimespan() has not been implemented.');

  /// `ReaderMuse.stopPlayback()`.
  Future<void> readerMuseStopPlayback(int readerMuseId) =>
      throw UnimplementedError('readerMuseStopPlayback() has not been implemented.');

  /// `ReaderMuse.currentTime()`.
  Future<int> readerMuseCurrentTime(int readerMuseId) =>
      throw UnimplementedError('readerMuseCurrentTime() has not been implemented.');

  /// `ReaderMuse.getPlaybackSettings()`.
  Future<ReaderMusePlaybackSettings?> readerMuseGetPlaybackSettings(int readerMuseId) =>
      throw UnimplementedError('readerMuseGetPlaybackSettings() has not been implemented.');

  /// `ReaderMuse.setPlaybackSettings(settings)`.
  Future<void> readerMuseSetPlaybackSettings(int readerMuseId, ReaderMusePlaybackSettings settings) =>
      throw UnimplementedError('readerMuseSetPlaybackSettings() has not been implemented.');

  /// Stops playback and frees the reader muse.
  Future<void> disposeReaderMuse(int readerMuseId) =>
      throw UnimplementedError('disposeReaderMuse() has not been implemented.');

}

class _UnsupportedFlutterMusePlatform extends FlutterMusePlatform {}
