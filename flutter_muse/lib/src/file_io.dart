import 'dart:async';

import 'package:flutter_muse_platform_interface/flutter_muse_platform_interface.dart';

import 'muse.dart';
import 'runtime.dart';

/// Creates .muse file readers and writers (mirrors `MuseFileFactory`).
class MuseFileFactory {
  MuseFileFactory._();

  /// `getMuseFileWriter(file)`. Call [MuseFileWriter.open] before writing.
  static Future<MuseFileWriter> getMuseFileWriter(String path) async =>
      MuseFileWriter._(await (await MuseRuntime.ready()).createFileWriter(path));

  /// `getMuseFileReader(file)`. Call [MuseFileReader.open] before reading.
  static Future<MuseFileReader> getMuseFileReader(String path) async =>
      MuseFileReader._(await (await MuseRuntime.ready()).createFileReader(path));
}

/// Writes .muse files (mirrors `MuseFileWriter`).
///
/// Every `add*` method takes a message id; use it to tell headbands apart
/// when recording several into one file (the SDK samples use 0).
///
/// To record a live headband, prefer [startRecording]: packets go straight
/// from the SDK into the file without crossing into Dart.
class MuseFileWriter {
  MuseFileWriter._(this._id);

  final int _id;
  bool _disposed = false;

  Future<FlutterMusePlatform> get _p {
    if (_disposed) throw StateError('MuseFileWriter has been disposed');
    return MuseRuntime.ready();
  }

  /// `open()`.
  Future<bool> open() async => (await _p).writerOpen(_id);

  /// `close()`: flushes and closes the file.
  Future<bool> close() async => (await _p).writerClose(_id);

  /// `flush()`: writes buffered messages to disk.
  Future<bool> flush() async => (await _p).writerFlush(_id);

  /// `addDataPacket(id, packet)`.
  Future<void> addDataPacket(int messageId, MuseDataPacket packet) async =>
      (await _p).writerAddDataPacket(_id, messageId, packet);

  /// `addArtifactPacket(id, packet)`.
  Future<void> addArtifactPacket(int messageId, MuseArtifactPacket packet) async =>
      (await _p).writerAddArtifactPacket(_id, messageId, packet);

  /// `addAnnotation(id, annotation)`.
  Future<void> addAnnotation(int messageId, AnnotationData annotation) async =>
      (await _p).writerAddAnnotation(_id, messageId, annotation);

  /// `addAnnotationString(id, annotation)`.
  Future<void> addAnnotationString(int messageId, String annotation) async =>
      (await _p).writerAddAnnotationString(_id, messageId, annotation);

  /// `addConfiguration(id, muse.getMuseConfiguration())`.
  Future<void> addConfiguration(int messageId, Muse muse) async =>
      (await _p).writerAddConfigurationFromMuse(_id, messageId, muse.id);

  /// `addConfiguration(id, reader.getConfiguration())`: copies the current
  /// configuration message of [reader].
  Future<void> addConfigurationFromReader(int messageId, MuseFileReader reader) async =>
      (await _p).writerAddConfigurationFromReader(_id, messageId, reader._id);

  /// `addVersion(id, muse.getMuseVersion())`.
  Future<void> addVersion(int messageId, Muse muse) async =>
      (await _p).writerAddVersionFromMuse(_id, messageId, muse.id);

  /// `addVersion(id, reader.getVersion())`: copies the current version
  /// message of [reader].
  Future<void> addVersionFromReader(int messageId, MuseFileReader reader) async =>
      (await _p).writerAddVersionFromReader(_id, messageId, reader._id);

  /// `addVersion(id, MuseVersion.makeVersion(json))`, or
  /// `MuseVersion.makeDefaultVersion()` when [json] is null.
  Future<void> addVersionFromJson(int messageId, [String? json]) async =>
      (await _p).writerAddVersionFromJson(_id, messageId, json);

  /// `addComputingDeviceConfiguration(id, configuration)`. With no
  /// [configuration], writes this device's configuration.
  Future<void> addComputingDeviceConfiguration(int messageId, [ComputingDeviceConfiguration? configuration]) async =>
      (await _p).writerAddComputingDeviceConfiguration(_id, messageId, configuration);

  /// `addDsp(id, dsp)`.
  Future<void> addDsp(int messageId, DspData dsp) async => (await _p).writerAddDsp(_id, messageId, dsp);

  /// `setTimestamp(timestamp)`: timestamp for subsequent messages in
  /// [TimestampMode.explicit] mode (microseconds since the epoch).
  Future<void> setTimestamp(int timestamp) async => (await _p).writerSetTimestamp(_id, timestamp);

  /// `setTimestampMode(mode)`.
  Future<void> setTimestampMode(TimestampMode mode) async => (await _p).writerSetTimestampMode(_id, mode);

  /// `discardBufferedPackets()`.
  Future<void> discardBufferedPackets() async => (await _p).writerDiscardBufferedPackets(_id);

  /// Buffer and size statistics.
  Future<MuseFileWriterStats> getStats() async => (await _p).writerGetStats(_id);

  /// Writes every packet of [types] from [muse] to this file, natively.
  /// Include [MuseDataPacketType.artifacts] to record artifact packets.
  /// Calling it again for the same headband replaces the packet types.
  Future<void> startRecording(Muse muse, Iterable<MuseDataPacketType> types, {int messageId = 0}) async =>
      (await _p).writerStartRecording(_id, muse.id, types.toList(), messageId);

  /// Stops [startRecording] for [muse], or for all headbands.
  Future<void> stopRecording([Muse? muse]) async => (await _p).writerStopRecording(_id, muse?.id);

  /// Stops recordings, closes the file and frees the native writer.
  Future<void> dispose() async {
    if (_disposed) return;
    await (await _p).disposeFileWriter(_id);
    _disposed = true;
  }
}

/// Reads .muse files (mirrors `MuseFileReader`).
///
/// Either step through messages with [gotoNextMessage] and
/// [currentMessage], or read many at once with [readMessages] (much faster:
/// one platform call per batch).
class MuseFileReader {
  MuseFileReader._(this._id);

  final int _id;
  bool _disposed = false;

  Future<FlutterMusePlatform> get _p {
    if (_disposed) throw StateError('MuseFileReader has been disposed');
    return MuseRuntime.ready();
  }

  /// `open()`.
  Future<bool> open() async => (await _p).readerOpen(_id);

  /// `close()`.
  Future<bool> close() async => (await _p).readerClose(_id);

  /// `gotoNextMessage()`: advances to the next message. Anything but
  /// [ResultLevel.rSuccess] means there is no next message (end of file or
  /// an error).
  Future<MuseResult> gotoNextMessage() async => (await _p).readerGotoNextMessage(_id);

  /// The current message with its payload (`getMessageType()`,
  /// `getMessageId()`, `getMessageTimestamp()` and the matching
  /// `getDataPacket()` / `getAnnotation()` / ... getter).
  Future<MuseFileMessage> currentMessage() async => (await _p).readerCurrentMessage(_id);

  /// Reads up to [max] messages. [MuseFileReadBatch.endResult] is set when
  /// reading stopped early (end of file or error).
  Future<MuseFileReadBatch> readMessages({int max = 1000}) async => (await _p).readerReadMessages(_id, max);

  /// Every remaining message, in batches of [batchSize].
  Stream<MuseFileMessage> readAll({int batchSize = 1000}) async* {
    while (true) {
      final batch = await readMessages(max: batchSize);
      yield* Stream.fromIterable(batch.messages);
      if (batch.endResult != null) return;
    }
  }

  /// Closes the file and frees the native reader.
  Future<void> dispose() async {
    if (_disposed) return;
    await (await _p).disposeFileReader(_id);
    _disposed = true;
  }
}

/// Builds a [ReaderMuse] (mirrors `ReaderMuseBuilder`).
class ReaderMuseBuilder {
  /// `ReaderMuseBuilder.get()`.
  ReaderMuseBuilder();

  Set<MuseDataPacketType>? _packetTypes;
  Set<MuseDataPacketType>? _skipPacketTypes;
  MuseModel? _model;
  ReaderMusePlaybackSettings? _playbackSettings;

  /// `withPacketTypes(types)`: only play back these types.
  ReaderMuseBuilder withPacketTypes(Iterable<MuseDataPacketType> types) {
    _packetTypes = types.toSet();
    return this;
  }

  /// `skipPacketTypes(types)`: do not play back these types.
  ReaderMuseBuilder skipPacketTypes(Iterable<MuseDataPacketType> types) {
    _skipPacketTypes = types.toSet();
    return this;
  }

  /// `withModel(model)`.
  ReaderMuseBuilder withModel(MuseModel model) {
    _model = model;
    return this;
  }

  /// `withPlaybackSettings(settings)`.
  ReaderMuseBuilder withPlaybackSettings(ReaderMusePlaybackSettings settings) {
    _playbackSettings = settings;
    return this;
  }

  /// `buildWithAsync(reader, eventLoop)` with the main-thread event loop:
  /// [ReaderMuse.playback] and friends return immediately and packets
  /// arrive as the file plays.
  Future<ReaderMuse> buildWithAsync(MuseFileReader reader) => _build(reader, async: true);

  /// `build(reader)`: [ReaderMuse.playback] and friends complete when the
  /// file has been consumed (they run on a background thread).
  Future<ReaderMuse> build(MuseFileReader reader) => _build(reader, async: false);

  Future<ReaderMuse> _build(MuseFileReader reader, {required bool async}) async {
    final ref = await (await reader._p).createReaderMuse(
      reader._id,
      packetTypes: _packetTypes,
      skipPacketTypes: _skipPacketTypes,
      model: _model,
      playbackSettings: _playbackSettings,
      async: async,
    );
    return ReaderMuse._(ref.id, Muse.forId(ref.museId));
  }
}

/// A playback status change (`ReaderPlaybackListener`).
class ReaderPlaybackEvent {
  /// Creates an event.
  const ReaderPlaybackEvent(this.kind, this.readerMuse);

  /// What happened.
  final ReaderPlaybackEventKind kind;

  /// The reader muse that played.
  final ReaderMuse readerMuse;

  @override
  String toString() => 'ReaderPlaybackEvent($kind)';
}

/// Plays a .muse file back as if it were a live headband (mirrors
/// `ReaderMuse`). Subscribe to [asMuse]'s data streams before calling
/// [playback].
class ReaderMuse {
  ReaderMuse._(this._id, this._muse) {
    _installHandlers();
    _live[_id] = this;
  }

  static final Map<int, ReaderMuse> _live = {};
  static bool _handlersInstalled = false;

  static void _installHandlers() {
    if (_handlersInstalled) return;
    _handlersInstalled = true;
    MuseRuntime.addListener((event) {
      switch (event) {
        case ReaderMuseMessageEvent():
          final rm = _live[event.readerMuseId];
          if (rm == null) return;
          if (event.annotation case final a?) rm._annotations.add(a);
          if (event.configuration case final c?) rm._configurations.add(c);
          if (event.version case final v?) rm._versions.add(v);
          if (event.computingDeviceConfiguration case final c?) rm._computingDevices.add(c);
        case ReaderMusePlaybackEvent():
          final rm = _live[event.readerMuseId];
          rm?._playback.add(ReaderPlaybackEvent(event.kind, rm));
        default:
          break;
      }
    });
  }

  final int _id;
  final Muse _muse;
  bool _disposed = false;

  final _annotations = StreamController<AnnotationData>.broadcast(sync: true);
  final _configurations = StreamController<MuseConfiguration>.broadcast(sync: true);
  final _versions = StreamController<MuseVersion>.broadcast(sync: true);
  final _computingDevices = StreamController<ComputingDeviceConfiguration>.broadcast(sync: true);
  final _playback = StreamController<ReaderPlaybackEvent>.broadcast(sync: true);

  Future<FlutterMusePlatform> get _p {
    if (_disposed) throw StateError('ReaderMuse has been disposed');
    return MuseRuntime.ready();
  }

  /// `asMuse()`: the file viewed as a headband; subscribe to its
  /// [Muse.dataPackets] / [Muse.artifactPackets].
  Muse asMuse() => _muse;

  /// `ReaderListener.receiveAnnotation`.
  Stream<AnnotationData> get annotations => _annotations.stream;

  /// `ReaderListener.receiveConfiguration`.
  Stream<MuseConfiguration> get configurations => _configurations.stream;

  /// `ReaderListener.receiveVersion`.
  Stream<MuseVersion> get versions => _versions.stream;

  /// `ReaderListener.receiveComputingDeviceConfiguration`.
  Stream<ComputingDeviceConfiguration> get computingDeviceConfigurations => _computingDevices.stream;

  /// `ReaderPlaybackListener`: playback done / interrupted.
  Stream<ReaderPlaybackEvent> get playbackEvents => _playback.stream;

  /// `playback()`: plays according to the playback settings.
  Future<void> playback() async => (await _p).readerMusePlayback(_id);

  /// `run()`.
  Future<void> run() async => (await _p).readerMuseRun(_id);

  /// `runInRealTimespan()`.
  Future<void> runInRealTimespan() async => (await _p).readerMuseRunInRealTimespan(_id);

  /// `stopPlayback()`.
  Future<void> stopPlayback() async => (await _p).readerMuseStopPlayback(_id);

  /// `currentTime()`: playback position (microseconds).
  Future<int> currentTime() async => (await _p).readerMuseCurrentTime(_id);

  /// `getPlaybackSettings()`.
  Future<ReaderMusePlaybackSettings?> getPlaybackSettings() async => (await _p).readerMuseGetPlaybackSettings(_id);

  /// `setPlaybackSettings(settings)`.
  Future<void> setPlaybackSettings(ReaderMusePlaybackSettings settings) async =>
      (await _p).readerMuseSetPlaybackSettings(_id, settings);

  /// Stops playback and frees the native object. The [MuseFileReader] is
  /// not disposed.
  Future<void> dispose() async {
    if (_disposed) return;
    await (await _p).disposeReaderMuse(_id);
    _disposed = true;
    _live.remove(_id);
    Muse.forget(_muse.id);
    await Future.wait([
      _annotations.close(),
      _configurations.close(),
      _versions.close(),
      _computingDevices.close(),
      _playback.close(),
    ]);
  }
}
