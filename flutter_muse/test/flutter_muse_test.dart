import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_muse/flutter_muse.dart';
import 'package:flutter_muse/src/runtime.dart';
import 'package:flutter_muse_platform_interface/flutter_muse_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';

/// Records calls; unlisted methods throw UnimplementedError (base class).
class FakePlatform extends FlutterMusePlatform {
  final calls = <String>[];
  final events$ = StreamController<MusePlatformEvent>.broadcast(sync: true);
  List<MuseInfo> muses = [];

  void emit(MusePlatformEvent e) => events$.add(e);

  @override
  Stream<MusePlatformEvent> get events => events$.stream;

  @override
  Future<MuseSdkStatus> initialize({required Duration packetBatchInterval}) async {
    calls.add('initialize ${packetBatchInterval.inMilliseconds}');
    return const MuseSdkStatus(nativeLibraryLoaded: true);
  }

  @override
  Future<List<MuseInfo>> getMuses() async => muses;

  @override
  Future<void> startListening() async => calls.add('startListening');

  @override
  Future<void> registerDataType(String museId, MuseDataPacketType type) async =>
      calls.add('register $museId ${type.name}');

  @override
  Future<void> unregisterDataType(String museId, MuseDataPacketType type) async =>
      calls.add('unregister $museId ${type.name}');

  @override
  Future<int> createFileWriter(String path) async => 7;

  @override
  Future<void> writerStartRecording(int writerId, String museId, List<MuseDataPacketType> types, int messageId) async =>
      calls.add('record $writerId $museId ${types.map((t) => t.name).join(',')} $messageId');

  @override
  Future<void> disposeFileWriter(int writerId) async => calls.add('disposeWriter $writerId');

  @override
  Future<int> createFileReader(String path) async => 1;

  int _reads = 0;

  @override
  Future<MuseFileReadBatch> readerReadMessages(int readerId, int max) async {
    _reads++;
    final m = MuseFileMessage(type: MessageType.eeg, id: 0, timestamp: _reads);
    return _reads < 3
        ? MuseFileReadBatch(messages: [m, m])
        : MuseFileReadBatch(
            messages: [m],
            endResult: const MuseResult(level: ResultLevel.rInfo, code: 0, type: 'eof', info: ''),
          );
  }

  @override
  Future<ReaderMuseRef> createReaderMuse(
    int readerId, {
    Set<MuseDataPacketType>? packetTypes,
    Set<MuseDataPacketType>? skipPacketTypes,
    MuseModel? model,
    ReaderMusePlaybackSettings? playbackSettings,
    required bool async,
  }) async {
    calls.add('createReaderMuse $readerId ${packetTypes?.map((t) => t.name)} $async');
    return (id: 2, museId: 'reader:2');
  }

  @override
  Future<void> disposeReaderMuse(int readerMuseId) async => calls.add('disposeReaderMuse $readerMuseId');

  @override
  Future<void> setLogListenerEnabled(bool enabled, {bool forwardToSystemLog = true}) async =>
      calls.add('log $enabled $forwardToSystemLog');
}

MuseDataPacket packet(String museId, MuseDataPacketType type, List<double> values) => MuseDataPacket.fromNative(
      museId: museId,
      packetType: type,
      timestamp: 1,
      values: Float64List.fromList(values),
      accessorValues: Float64List.fromList(values),
    );

void main() {
  late FakePlatform platform;

  setUp(() async {
    await MuseRuntime.resetForTesting();
    platform = FakePlatform();
    FlutterMusePlatform.instance = platform;
  });

  test('initialises the platform once, with the batch interval', () async {
    final status = await FlutterMuse.initialize(packetBatchInterval: const Duration(milliseconds: 40));
    expect(status.nativeLibraryLoaded, isTrue);
    await MuseManager.instance.startListening();
    expect(platform.calls, ['initialize 40', 'startListening']);
  });

  test('list changes yield one Muse per headband', () async {
    final lists = <List<Muse>>[];
    final sub = MuseManager.instance.museListChanged.listen(lists.add);
    await pumpEventQueue();
    const info = MuseInfo(id: 'AA:01', name: 'Muse-01', model: MuseModel.mu03);
    platform.emit(const MuseListChangedEvent([info]));
    platform.emit(const MuseListChangedEvent([info]));
    await pumpEventQueue();
    expect(lists, hasLength(2));
    expect(identical(lists[0].single, lists[1].single), isTrue);
    expect(lists[0].single.name, 'Muse-01');
    await sub.cancel();
  });

  test('data types are registered while subscribed', () async {
    platform.muses = [const MuseInfo(id: 'AA:02')];
    final muse = (await MuseManager.instance.getMuses()).single;
    final first = <MuseDataPacket>[];
    final second = <MuseDataPacket>[];
    final s1 = muse.dataPacketsOf(MuseDataPacketType.eeg).listen(first.add);
    final s2 = muse.dataPackets([MuseDataPacketType.eeg, MuseDataPacketType.battery]).listen(second.add);
    await pumpEventQueue();
    expect(platform.calls.where((c) => c.startsWith('register')), ['register AA:02 eeg', 'register AA:02 battery']);

    platform.emit(MuseDataPacketEvent(packet('AA:02', MuseDataPacketType.eeg, [1, 2, 3, 4])));
    platform.emit(MuseDataPacketEvent(packet('AA:02', MuseDataPacketType.battery, [87, 4000, 30])));
    platform.emit(MuseDataPacketEvent(packet('other', MuseDataPacketType.eeg, [9])));
    expect(first.single.getEegChannelValue(Eeg.eeg3), 3);
    expect(second.map((p) => p.packetType), [MuseDataPacketType.eeg, MuseDataPacketType.battery]);

    await s1.cancel();
    await pumpEventQueue();
    expect(platform.calls.where((c) => c.startsWith('unregister')), isEmpty);
    await s2.cancel();
    await pumpEventQueue();
    expect(
      platform.calls.where((c) => c.startsWith('unregister')).toSet(),
      {'unregister AA:02 eeg', 'unregister AA:02 battery'},
    );
  });

  test('artifact, connection and error events', () async {
    platform.muses = [const MuseInfo(id: 'AA:03', connectionState: MuseConnectionState.disconnected)];
    final muse = (await MuseManager.instance.getMuses()).single;
    final artifacts = <MuseArtifactPacket>[];
    final connections = <MuseConnectionPacket>[];
    final errors = <MuseError>[];
    final subs = [
      muse.artifactPackets.listen(artifacts.add),
      muse.connectionPackets.listen(connections.add),
      muse.errors.listen(errors.add),
    ];
    await pumpEventQueue();
    expect(platform.calls.last, 'register AA:03 artifacts');

    platform.emit(const MuseConnectionEvent(MuseConnectionPacket(
      previousConnectionState: MuseConnectionState.connecting,
      currentConnectionState: MuseConnectionState.connected,
      museId: 'AA:03',
    )));
    platform.emit(const MuseArtifactPacketEvent(
      MuseArtifactPacket(headbandOn: true, blink: true, jawClench: false, timestamp: 5, museId: 'AA:03'),
    ));
    platform.emit(const MuseErrorEvent(MuseError(type: ErrorType.timeout, code: 1, info: 'x', museId: 'AA:03')));
    expect(connections.single.currentConnectionState, MuseConnectionState.connected);
    expect(muse.connectionState, MuseConnectionState.connected);
    expect(artifacts.single.blink, isTrue);
    expect(errors.single.type, ErrorType.timeout);
    for (final s in subs) {
      await s.cancel();
    }
  });

  test('file writer and reader', () async {
    platform.muses = [const MuseInfo(id: 'AA:04')];
    final muse = (await MuseManager.instance.getMuses()).single;
    final writer = await MuseFileFactory.getMuseFileWriter('/tmp/a.muse');
    await writer.startRecording(muse, [MuseDataPacketType.eeg, MuseDataPacketType.artifacts]);
    await writer.dispose();
    expect(platform.calls, contains('record 7 AA:04 eeg,artifacts 0'));
    expect(platform.calls.last, 'disposeWriter 7');
    expect(() => writer.flush(), throwsStateError);

    final reader = await MuseFileFactory.getMuseFileReader('/tmp/a.muse');
    expect(await reader.readAll().length, 5);
  });

  test('reader muse forwards playback events and frees its Muse', () async {
    final reader = await MuseFileFactory.getMuseFileReader('/tmp/b.muse');
    final readerMuse = await ReaderMuseBuilder().withPacketTypes([MuseDataPacketType.eeg]).buildWithAsync(reader);
    expect(platform.calls.last, 'createReaderMuse 1 (eeg) true');
    expect(readerMuse.asMuse().id, 'reader:2');

    final done = readerMuse.playbackEvents.first;
    platform.emit(const ReaderMusePlaybackEvent(2, ReaderPlaybackEventKind.done));
    expect((await done).readerMuse, same(readerMuse));

    final annotations = readerMuse.annotations.first;
    platform.emit(const ReaderMuseMessageEvent(2, annotation: AnnotationData(data: 'hi')));
    expect((await annotations).data, 'hi');

    await readerMuse.dispose();
    expect(platform.calls.last, 'disposeReaderMuse 2');
  });

  test('log stream toggles the native listener', () async {
    final logs = <LogPacket>[];
    final sub = LogManager.instance.logs(forwardToSystemLog: false).listen(logs.add);
    await pumpEventQueue();
    expect(platform.calls.last, 'log true false');
    platform.emit(const MuseLogEvent(LogPacket(severity: Severity.sevInfo, raw: false, tag: 't', timestamp: 0, message: 'm')));
    await pumpEventQueue();
    expect(logs.single.message, 'm');
    await sub.cancel();
    await pumpEventQueue();
    expect(platform.calls.last, 'log false true');
  });
}
