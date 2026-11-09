import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_muse_android/flutter_muse_android.dart';
import 'package:flutter_muse_platform_interface/flutter_muse_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late List<MethodCall> calls;
  late Map<String, Object? Function(MethodCall)> responses;
  late FlutterMuseAndroid platform;

  Future<void> emit(Map<String, Object?> event) => messenger.handlePlatformMessage(
        FlutterMuseAndroid.eventChannel.name,
        const StandardMethodCodec().encodeSuccessEnvelope(event),
        (_) {},
      );

  setUp(() {
    calls = [];
    responses = {};
    platform = FlutterMuseAndroid();
    messenger.setMockMethodCallHandler(FlutterMuseAndroid.methodChannel, (call) async {
      calls.add(call);
      return responses[call.method]?.call(call);
    });
    messenger.setMockMethodCallHandler(MethodChannel(FlutterMuseAndroid.eventChannel.name), (_) async => null);
  });

  test('registerWith installs the implementation', () {
    FlutterMuseAndroid.registerWith();
    expect(FlutterMusePlatform.instance, isA<FlutterMuseAndroid>());
  });

  test('initialize', () async {
    responses['initialize'] = (_) => {
          'nativeLibraryLoaded': false,
          'error': 'java.lang.UnsatisfiedLinkError: no muse_android',
        };
    final status = await platform.initialize(packetBatchInterval: const Duration(milliseconds: 40));
    expect(calls.single.arguments, {'batchIntervalMs': 40});
    expect(status.nativeLibraryLoaded, isFalse);
    expect(status.error, contains('UnsatisfiedLinkError'));
  });

  test('decodes batched packets and other events', () async {
    final events = <MusePlatformEvent>[];
    final sub = platform.events.listen(events.add);
    await emit({
      'event': 'packets',
      'packets': [
        [0, 'AA', MuseDataPacketType.eeg.index, 1000, Float64List.fromList([1, 2]), Float64List.fromList([1, 2])],
        [1, 'AA', true, false, true, 2000],
      ],
    });
    await emit({'event': 'connection', 'museId': 'AA', 'previous': 2, 'current': 1});
    await emit({
      'event': 'museListChanged',
      'muses': [
        {'id': 'AA', 'name': 'Muse-AA', 'model': 2},
      ],
    });
    await emit({'event': 'playback', 'readerMuseId': 4, 'kind': 'done'});

    expect(events, hasLength(5));
    final data = (events[0] as MuseDataPacketEvent).packet;
    expect(data.museId, 'AA');
    expect(data.getEegChannelValue(Eeg.eeg2), 2);
    final artifact = (events[1] as MuseArtifactPacketEvent).packet;
    expect(artifact.headbandOn, isTrue);
    expect(artifact.jawClench, isTrue);
    expect((events[2] as MuseConnectionEvent).packet.currentConnectionState, MuseConnectionState.connected);
    expect((events[3] as MuseListChangedEvent).muses.single.model, MuseModel.mu03);
    expect((events[4] as ReaderMusePlaybackEvent).kind, ReaderPlaybackEventKind.done);
    await sub.cancel();
  });

  test('sends the native method names and arguments', () async {
    await platform.registerDataType('AA', MuseDataPacketType.battery);
    await platform.setPreset('AA', MusePreset.preset21);
    await platform.writerAddVersionFromJson(7, 0, null);
    await platform.writerStopRecording(7, null);
    await platform.writerAddDataPacket(
      7,
      2,
      MuseDataPacket(packetType: MuseDataPacketType.accelerometer, timestamp: 5, values: [0.5]),
    );
    expect(calls.map((c) => c.method), [
      'museRegisterDataType',
      'museSetPreset',
      'writerAddVersion',
      'writerStopRecording',
      'writerAddDataPacket',
    ]);
    expect(calls[0].arguments, {'museId': 'AA', 'type': MuseDataPacketType.battery.index});
    expect(calls[1].arguments, {'museId': 'AA', 'preset': MusePreset.preset21.index});
    expect(calls[2].arguments, {'id': 7, 'messageId': 0});
    expect(calls[3].arguments, {'id': 7});
    expect(calls[4].arguments['packet']['type'], MuseDataPacketType.accelerometer.index);
  });

  test('decodes file messages and reader muse refs', () async {
    responses['readerReadMessages'] = (_) => {
          'messages': [
            {
              'type': MessageType.eeg.index,
              'id': 0,
              'timestamp': 10,
              'packet': [0, null, MuseDataPacketType.eeg.index, 10, Float64List.fromList([5, 6]), null],
            },
          ],
          'result': {'level': ResultLevel.rInfo.index, 'code': 0, 'type': 'eof', 'info': ''},
        };
    responses['readerMuseCreate'] = (_) => {'id': 3, 'museId': 'reader:3'};

    final batch = await platform.readerReadMessages(1, 100);
    expect(batch.messages.single.dataPacket!.values, [5, 6]);
    expect(batch.endResult!.level, ResultLevel.rInfo);

    final ref = await platform.createReaderMuse(1, model: MuseModel.mu02, async: true);
    expect(ref, (id: 3, museId: 'reader:3'));
    expect(calls.last.arguments, {'readerId': 1, 'model': MuseModel.mu02.index, 'async': true});
  });
}
