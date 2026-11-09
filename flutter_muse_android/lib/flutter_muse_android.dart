/// Android implementation of the `flutter_muse` plugin.
///
/// Apps should depend on `flutter_muse`, which uses this package
/// automatically on Android.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_muse_platform_interface/flutter_muse_platform_interface.dart';

/// [FlutterMusePlatform] for Android, backed by libmuse_android through
/// platform channels.
class FlutterMuseAndroid extends FlutterMusePlatform {
  /// Creates the implementation; normally done by [registerWith].
  FlutterMuseAndroid();

  /// Registers this class as the platform implementation.
  static void registerWith() {
    FlutterMusePlatform.instance = FlutterMuseAndroid();
  }

  /// Method channel (exposed for tests).
  @visibleForTesting
  static const MethodChannel methodChannel = MethodChannel('flutter_muse/methods');

  /// Event channel (exposed for tests).
  @visibleForTesting
  static const EventChannel eventChannel = EventChannel('flutter_muse/events');

  static const int _kindArtifact = 1;

  late final StreamController<MusePlatformEvent> _events = StreamController.broadcast(sync: true);
  StreamSubscription<Object?>? _nativeEvents;

  void _ensureEventsListening() {
    _nativeEvents ??= eventChannel.receiveBroadcastStream().listen(_onNativeEvent);
  }

  @override
  Stream<MusePlatformEvent> get events {
    _ensureEventsListening();
    return _events.stream;
  }

  Future<T?> _invoke<T>(String method, [Map<String, Object?>? args]) => methodChannel.invokeMethod<T>(method, args);

  Future<Map<String, Object?>?> _invokeMap(String method, [Map<String, Object?>? args]) =>
      methodChannel.invokeMapMethod<String, Object?>(method, args);

  Future<Map<String, Object?>> _invokeMapNonNull(String method, [Map<String, Object?>? args]) async =>
      (await _invokeMap(method, args))!;

  // ------------------------------------------------------------------ events

  void _onNativeEvent(Object? event) {
    if (event is! Map) return;
    switch (event['event']) {
      case 'packets':
        for (final p in event['packets']! as List<Object?>) {
          final packet = p! as List<Object?>;
          _events.add(packet[0] == _kindArtifact
              ? MuseArtifactPacketEvent(_decodeArtifact(packet))
              : MuseDataPacketEvent(decodeDataPacket(packet)));
        }
      case 'museListChanged':
        _events.add(MuseListChangedEvent(_decodeInfos(event['muses'])));
      case 'connection':
        _events.add(MuseConnectionEvent(MuseConnectionPacket(
          previousConnectionState: MuseConnectionState.values[event['previous']! as int],
          currentConnectionState: MuseConnectionState.values[event['current']! as int],
          museId: event['museId']! as String,
        )));
      case 'error':
        _events.add(MuseErrorEvent(MuseError.fromMap(_cast(event['error']), museId: event['museId'] as String?)));
      case 'log':
        _events.add(MuseLogEvent(LogPacket.fromMap(_cast(event['log']))));
      case 'readerMessage':
        final id = event['readerMuseId']! as int;
        final payload = _cast(event['payload']);
        _events.add(switch (event['kind']) {
          'annotation' => ReaderMuseMessageEvent(id, annotation: AnnotationData.fromMap(payload)),
          'configuration' => ReaderMuseMessageEvent(id, configuration: MuseConfiguration.fromMap(payload)),
          'version' => ReaderMuseMessageEvent(id, version: MuseVersion.fromMap(payload)),
          _ => ReaderMuseMessageEvent(id, computingDeviceConfiguration: ComputingDeviceConfiguration.fromMap(payload)),
        });
      case 'playback':
        _events.add(ReaderMusePlaybackEvent(
          event['readerMuseId']! as int,
          event['kind'] == 'done' ? ReaderPlaybackEventKind.done : ReaderPlaybackEventKind.interrupted,
        ));
    }
  }

  /// Decodes `[kind, museId, type, timestamp, values, accessorValues]`.
  @visibleForTesting
  static MuseDataPacket decodeDataPacket(Object packet) {
    final p = packet as List<Object?>;
    return MuseDataPacket.fromNative(
      museId: p[1] as String?,
      packetType: MuseDataPacketType.values[p[2]! as int],
      timestamp: p[3]! as int,
      values: p[4]! as Float64List,
      accessorValues: p[5] as Float64List?,
    );
  }

  /// Decodes `[kind, museId, headbandOn, blink, jawClench, timestamp]`.
  static MuseArtifactPacket _decodeArtifact(List<Object?> p) => MuseArtifactPacket(
        museId: p[1] as String?,
        headbandOn: p[2]! as bool,
        blink: p[3]! as bool,
        jawClench: p[4]! as bool,
        timestamp: p[5]! as int,
      );

  static Map<String, Object?> _cast(Object? m) => (m! as Map<Object?, Object?>).cast<String, Object?>();

  static List<MuseInfo> _decodeInfos(Object? list) =>
      [for (final m in list as List<Object?>? ?? const []) MuseInfo.fromMap(_cast(m))];

  static MuseFileMessage _decodeMessage(Object? m) => MuseFileMessage.fromMap(_cast(m), decodePacket: decodeDataPacket);

  // ----------------------------------------------------------------- general

  @override
  Future<MuseSdkStatus> initialize({required Duration packetBatchInterval}) async {
    _ensureEventsListening();
    final m = await _invokeMapNonNull('initialize', {'batchIntervalMs': packetBatchInterval.inMilliseconds});
    return MuseSdkStatus(
      nativeLibraryLoaded: m['nativeLibraryLoaded'] as bool? ?? false,
      error: m['error'] as String?,
      libmuseVersion: m['libmuseVersion'] == null ? null : ApiVersion.fromMap(_cast(m['libmuseVersion'])),
    );
  }

  @override
  Future<void> setPacketBatchInterval(Duration interval) =>
      _invoke<void>('setPacketBatchInterval', {'ms': interval.inMilliseconds});

  @override
  Future<bool> hasPermissions() async => await _invoke<bool>('hasPermissions') ?? false;

  @override
  Future<Map<String, bool>> requestPermissions() async =>
      (await _invokeMap('requestPermissions'))?.map((k, v) => MapEntry(k, v! as bool)) ?? const {};

  @override
  Future<bool> isBluetoothEnabled() async => await _invoke<bool>('isBluetoothEnabled') ?? false;

  @override
  Future<ApiVersion> getLibmuseVersion() async => ApiVersion.fromMap(await _invokeMapNonNull('getLibmuseVersion'));

  @override
  Future<String> stringifyConnectionState(MuseConnectionState state) async =>
      (await _invoke<String>('stringifyConnectionState', {'state': state.index}))!;

  @override
  Future<String> stringifyPacketType(MuseDataPacketType type) async =>
      (await _invoke<String>('stringifyPacketType', {'type': type.index}))!;

  @override
  Future<ComputingDeviceConfiguration> getComputingDeviceConfiguration() async =>
      ComputingDeviceConfiguration.fromMap(await _invokeMapNonNull('getComputingDeviceConfiguration'));

  @override
  Future<MuseVersion> makeDefaultVersion() async => MuseVersion.fromMap(await _invokeMapNonNull('makeDefaultVersion'));

  @override
  Future<MuseVersion> makeVersion(String json) async =>
      MuseVersion.fromMap(await _invokeMapNonNull('makeVersion', {'json': json}));

  // --------------------------------------------------------------- elements

  @override
  Future<MuseElementsVersion?> getElementsVersion() async {
    final index = (await _invokeMapNonNull('elementsGetSettings'))['version'] as int?;
    return index == null ? null : MuseElementsVersion.values[index];
  }

  @override
  Future<void> setElementsVersion(MuseElementsVersion version) =>
      _invoke<void>('elementsSetVersion', {'version': version.index});

  @override
  Future<bool> getEnableMultipleMuseElements() async =>
      (await _invokeMapNonNull('elementsGetSettings'))['enableMultipleMuseElements']! as bool;

  @override
  Future<void> setEnableMultipleMuseElements(bool enabled) =>
      _invoke<void>('elementsSetEnableMultiple', {'enabled': enabled});

  // ---------------------------------------------------------------- logging

  @override
  Future<void> setLogMinimumSeverity(Severity severity) =>
      _invoke<void>('logSetMinimumSeverity', {'severity': severity.index});

  @override
  Future<void> writeLog(Severity severity, String tag, String message, {bool raw = false}) =>
      _invoke<void>('logWrite', {'severity': severity.index, 'raw': raw, 'tag': tag, 'message': message});

  @override
  Future<int> getLogTimestamp() async => (await _invoke<int>('logGetTimestamp'))!;

  @override
  Future<double> logTimeSince(int timestamp) async =>
      (await _invoke<double>('logTimeSince', {'timestamp': timestamp}))!;

  @override
  Future<void> setLogListenerEnabled(bool enabled, {bool forwardToSystemLog = true}) =>
      _invoke<void>('logSetListener', {'enabled': enabled, 'forwardToLogcat': forwardToSystemLog});

  @override
  Future<void> museLog(Severity severity, String message, {bool raw = false}) =>
      _invoke<void>('museLog', {'severity': severity.index, 'message': message, 'raw': raw});

  // ---------------------------------------------------------------- manager

  @override
  Future<void> startListening() => _invoke<void>('managerStartListening');

  @override
  Future<void> stopListening() => _invoke<void>('managerStopListening');

  @override
  Future<List<MuseInfo>> getMuses() async => _decodeInfos(await _invoke<List<Object?>>('managerGetMuses'));

  @override
  Future<void> removeFromListAfter(Duration duration) =>
      _invoke<void>('managerRemoveFromListAfter', {'seconds': duration.inSeconds});

  @override
  Future<void> resetAdvertisingStats() => _invoke<void>('managerResetAdvertisingStats');

  @override
  Future<AdvertisingStats?> getAdvertisingStats(String museId) async {
    final m = await _invokeMap('managerGetAdvertisingStats', {'museId': museId});
    return m == null ? null : AdvertisingStats.fromMap(m);
  }

  @override
  Future<void> setCompanionMode(
    bool enabled, {
    String? macAddress,
    Uint8List? manufacturerData,
    bool removeOthers = false,
  }) =>
      _invoke<void>('managerSetCompanionMode', {
        'enabled': enabled,
        'macAddress': macAddress,
        'manufacturerData': manufacturerData,
        'removeOthers': removeOthers,
      });

  @override
  Future<String> museUuid() async => (await _invoke<String>('managerMuseUuid'))!;

  // ------------------------------------------------------------------- muse

  Future<void> _muse(String method, String museId, [Map<String, Object?> extra = const {}]) =>
      _invoke<void>(method, {'museId': museId, ...extra});

  @override
  Future<MuseInfo> getMuseInfo(String museId) async =>
      MuseInfo.fromMap(await _invokeMapNonNull('museGetInfo', {'museId': museId}));

  @override
  Future<void> connect(String museId) => _muse('museConnect', museId);

  @override
  Future<void> disconnect(String museId) => _muse('museDisconnect', museId);

  @override
  Future<void> runAsynchronously(String museId) => _muse('museRunAsynchronously', museId);

  @override
  Future<void> execute(String museId) => _muse('museExecute', museId);

  @override
  Future<void> enableDataTransmission(String museId, bool enabled) =>
      _muse('museEnableDataTransmission', museId, {'enabled': enabled});

  @override
  Future<void> enableException(String museId, bool enabled) =>
      _muse('museEnableException', museId, {'enabled': enabled});

  @override
  Future<void> enableLedIndicator(String museId, bool enabled) =>
      _muse('museEnableLedIndicator', museId, {'enabled': enabled});

  @override
  Future<void> setPreset(String museId, MusePreset preset) =>
      _muse('museSetPreset', museId, {'preset': preset.index});

  @override
  Future<void> setNotchFrequency(String museId, NotchFrequency frequency) =>
      _muse('museSetNotchFrequency', museId, {'frequency': frequency.index});

  @override
  Future<void> setNumConnectTries(String museId, int tries) =>
      _muse('museSetNumConnectTries', museId, {'tries': tries});

  @override
  Future<void> setLicenseData(String museId, Uint8List data) => _muse('museSetLicenseData', museId, {'data': data});

  @override
  Future<MuseConfiguration?> getMuseConfiguration(String museId) async {
    final m = await _invokeMap('museGetConfiguration', {'museId': museId});
    return m == null ? null : MuseConfiguration.fromMap(m);
  }

  @override
  Future<MuseVersion?> getMuseVersion(String museId) async {
    final m = await _invokeMap('museGetVersion', {'museId': museId});
    return m == null ? null : MuseVersion.fromMap(m);
  }

  @override
  Future<void> registerDataType(String museId, MuseDataPacketType type) =>
      _muse('museRegisterDataType', museId, {'type': type.index});

  @override
  Future<void> unregisterDataType(String museId, MuseDataPacketType type) =>
      _muse('museUnregisterDataType', museId, {'type': type.index});

  @override
  Future<void> unregisterAllListeners(String museId) => _muse('museUnregisterAllListeners', museId);

  // ------------------------------------------------------------ file writer

  Future<T?> _writer<T>(String method, int writerId, [Map<String, Object?> extra = const {}]) =>
      _invoke<T>(method, {'id': writerId, ...extra});

  @override
  Future<int> createFileWriter(String path) async => (await _invoke<int>('writerCreate', {'path': path}))!;

  @override
  Future<bool> writerOpen(int writerId) async => await _writer<bool>('writerOpen', writerId) ?? false;

  @override
  Future<bool> writerClose(int writerId) async => await _writer<bool>('writerClose', writerId) ?? false;

  @override
  Future<bool> writerFlush(int writerId) async => await _writer<bool>('writerFlush', writerId) ?? false;

  @override
  Future<void> writerAddDataPacket(int writerId, int messageId, MuseDataPacket packet) =>
      _writer<void>('writerAddDataPacket', writerId, {
        'messageId': messageId,
        'packet': {'type': packet.packetType.index, 'timestamp': packet.timestamp, 'values': packet.values},
      });

  @override
  Future<void> writerAddArtifactPacket(int writerId, int messageId, MuseArtifactPacket packet) =>
      _writer<void>('writerAddArtifactPacket', writerId, {'messageId': messageId, 'packet': packet.toMap()});

  @override
  Future<void> writerAddAnnotation(int writerId, int messageId, AnnotationData annotation) =>
      _writer<void>('writerAddAnnotation', writerId, {'messageId': messageId, 'annotation': annotation.toMap()});

  @override
  Future<void> writerAddAnnotationString(int writerId, int messageId, String annotation) =>
      _writer<void>('writerAddAnnotationString', writerId, {'messageId': messageId, 'annotation': annotation});

  @override
  Future<void> writerAddConfigurationFromMuse(int writerId, int messageId, String museId) =>
      _writer<void>('writerAddConfiguration', writerId, {'messageId': messageId, 'museId': museId});

  @override
  Future<void> writerAddConfigurationFromReader(int writerId, int messageId, int readerId) =>
      _writer<void>('writerAddConfiguration', writerId, {'messageId': messageId, 'readerId': readerId});

  @override
  Future<void> writerAddVersionFromMuse(int writerId, int messageId, String museId) =>
      _writer<void>('writerAddVersion', writerId, {'messageId': messageId, 'museId': museId});

  @override
  Future<void> writerAddVersionFromReader(int writerId, int messageId, int readerId) =>
      _writer<void>('writerAddVersion', writerId, {'messageId': messageId, 'readerId': readerId});

  @override
  Future<void> writerAddVersionFromJson(int writerId, int messageId, String? json) =>
      _writer<void>('writerAddVersion', writerId, {'messageId': messageId, 'json': ?json});

  @override
  Future<void> writerAddComputingDeviceConfiguration(
    int writerId,
    int messageId,
    ComputingDeviceConfiguration? configuration,
  ) =>
      _writer<void>('writerAddComputingDeviceConfiguration', writerId,
          {'messageId': messageId, 'configuration': configuration?.toMap()});

  @override
  Future<void> writerAddDsp(int writerId, int messageId, DspData dsp) =>
      _writer<void>('writerAddDsp', writerId, {'messageId': messageId, 'dsp': dsp.toMap()});

  @override
  Future<void> writerSetTimestamp(int writerId, int timestamp) =>
      _writer<void>('writerSetTimestamp', writerId, {'timestamp': timestamp});

  @override
  Future<void> writerSetTimestampMode(int writerId, TimestampMode mode) =>
      _writer<void>('writerSetTimestampMode', writerId, {'mode': mode.index});

  @override
  Future<void> writerDiscardBufferedPackets(int writerId) => _writer<void>('writerDiscardBufferedPackets', writerId);

  @override
  Future<MuseFileWriterStats> writerGetStats(int writerId) async =>
      MuseFileWriterStats.fromMap(_cast(await _writer<Map<Object?, Object?>>('writerGetStats', writerId)));

  @override
  Future<void> writerStartRecording(int writerId, String museId, List<MuseDataPacketType> types, int messageId) =>
      _writer<void>('writerStartRecording', writerId, {
        'museId': museId,
        'types': [for (final t in types) t.index],
        'messageId': messageId,
      });

  @override
  Future<void> writerStopRecording(int writerId, String? museId) =>
      _writer<void>('writerStopRecording', writerId, {'museId': ?museId});

  @override
  Future<void> disposeFileWriter(int writerId) => _writer<void>('writerDispose', writerId);

  // ------------------------------------------------------------ file reader

  Future<T?> _reader<T>(String method, int readerId, [Map<String, Object?> extra = const {}]) =>
      _invoke<T>(method, {'id': readerId, ...extra});

  @override
  Future<int> createFileReader(String path) async => (await _invoke<int>('readerCreate', {'path': path}))!;

  @override
  Future<bool> readerOpen(int readerId) async => await _reader<bool>('readerOpen', readerId) ?? false;

  @override
  Future<bool> readerClose(int readerId) async => await _reader<bool>('readerClose', readerId) ?? false;

  @override
  Future<MuseResult> readerGotoNextMessage(int readerId) async =>
      MuseResult.fromMap(_cast(await _reader<Map<Object?, Object?>>('readerGotoNextMessage', readerId)));

  @override
  Future<MuseFileMessage> readerCurrentMessage(int readerId) async =>
      _decodeMessage(await _reader<Map<Object?, Object?>>('readerCurrentMessage', readerId));

  @override
  Future<MuseFileReadBatch> readerReadMessages(int readerId, int max) async {
    final m = _cast(await _reader<Map<Object?, Object?>>('readerReadMessages', readerId, {'max': max}));
    return MuseFileReadBatch(
      messages: [for (final msg in m['messages']! as List<Object?>) _decodeMessage(msg)],
      endResult: m['result'] == null ? null : MuseResult.fromMap(_cast(m['result'])),
    );
  }

  @override
  Future<void> disposeFileReader(int readerId) => _reader<void>('readerDispose', readerId);

  // ------------------------------------------------------------ reader muse

  Future<T?> _readerMuse<T>(String method, int readerMuseId, [Map<String, Object?> extra = const {}]) =>
      _invoke<T>(method, {'id': readerMuseId, ...extra});

  @override
  Future<ReaderMuseRef> createReaderMuse(
    int readerId, {
    Set<MuseDataPacketType>? packetTypes,
    Set<MuseDataPacketType>? skipPacketTypes,
    MuseModel? model,
    ReaderMusePlaybackSettings? playbackSettings,
    required bool async,
  }) async {
    final m = await _invokeMapNonNull('readerMuseCreate', {
      'readerId': readerId,
      'packetTypes': ?packetTypes?.map((t) => t.index).toList(),
      'skipPacketTypes': ?skipPacketTypes?.map((t) => t.index).toList(),
      'model': ?model?.index,
      'playbackSettings': ?playbackSettings?.index,
      'async': async,
    });
    return (id: m['id']! as int, museId: m['museId']! as String);
  }

  @override
  Future<void> readerMusePlayback(int readerMuseId) => _readerMuse<void>('readerMusePlayback', readerMuseId);

  @override
  Future<void> readerMuseRun(int readerMuseId) => _readerMuse<void>('readerMuseRun', readerMuseId);

  @override
  Future<void> readerMuseRunInRealTimespan(int readerMuseId) =>
      _readerMuse<void>('readerMuseRunInRealTimespan', readerMuseId);

  @override
  Future<void> readerMuseStopPlayback(int readerMuseId) => _readerMuse<void>('readerMuseStopPlayback', readerMuseId);

  @override
  Future<int> readerMuseCurrentTime(int readerMuseId) async =>
      (await _readerMuse<int>('readerMuseCurrentTime', readerMuseId))!;

  @override
  Future<ReaderMusePlaybackSettings?> readerMuseGetPlaybackSettings(int readerMuseId) async {
    final index = await _readerMuse<int>('readerMuseGetPlaybackSettings', readerMuseId);
    return index == null ? null : ReaderMusePlaybackSettings.values[index];
  }

  @override
  Future<void> readerMuseSetPlaybackSettings(int readerMuseId, ReaderMusePlaybackSettings settings) =>
      _readerMuse<void>('readerMuseSetPlaybackSettings', readerMuseId, {'settings': settings.index});

  @override
  Future<void> disposeReaderMuse(int readerMuseId) => _readerMuse<void>('readerMuseDispose', readerMuseId);
}
