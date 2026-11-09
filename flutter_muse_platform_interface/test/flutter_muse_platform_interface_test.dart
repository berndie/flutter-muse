import 'dart:typed_data';

import 'package:flutter_muse_platform_interface/flutter_muse_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class _Extending extends FlutterMusePlatform {}

class _Implementing implements FlutterMusePlatform {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Mock extends Fake with MockPlatformInterfaceMixin implements FlutterMusePlatform {}

void main() {
  test('default instance reports every method as unimplemented', () {
    expect(() => FlutterMusePlatform.instance.startListening(), throwsUnimplementedError);
    expect(() => FlutterMusePlatform.instance.events, throwsUnimplementedError);
  });

  test('implementations must extend the interface', () {
    FlutterMusePlatform.instance = _Extending();
    FlutterMusePlatform.instance = _Mock();
    expect(() => FlutterMusePlatform.instance = _Implementing(), throwsA(isA<AssertionError>()));
  });

  test('enums mirror the Java ordinals', () {
    expect(MuseDataPacketType.values, hasLength(42));
    expect(MuseDataPacketType.eeg.index, 2);
    expect(MuseDataPacketType.artifacts.index, 26);
    expect(MuseDataPacketType.values.last, MuseDataPacketType.total);
    expect(MuseConnectionState.connected.index, 1);
    expect(MusePreset.values.last, MusePreset.preset63);
    expect(MuseElementsVersion.values.map((v) => v.name), ['v2_0', 'v3_0', 'r1_0', 'v4_0', 'v5_0']);
  });

  test('typed accessors only apply to their packet types', () {
    final eeg = MuseDataPacket.fromNative(
      packetType: MuseDataPacketType.alphaAbsolute,
      timestamp: 1,
      values: Float64List.fromList([1, 2, 3, 4]),
      accessorValues: Float64List.fromList([1, 2, 3, 4, double.nan, double.nan]),
      museId: 'm',
    );
    expect(eeg.getEegChannelValue(Eeg.eeg4), 4);
    expect(eeg.getEegChannelValue(Eeg.auxRight), isNaN);
    expect(() => eeg.getBatteryValue(Battery.millivolts), throwsStateError);

    final created = MuseDataPacket(packetType: MuseDataPacketType.eeg, timestamp: 1, values: [1]);
    expect(() => created.getEegChannelValue(Eeg.eeg1), throwsStateError);
  });

  test('models decode the standard-codec representation', () {
    final message = MuseFileMessage.fromMap(
      {
        'type': MessageType.annotation.index,
        'id': 3,
        'timestamp': 9,
        'annotation': <Object?, Object?>{'data': 'x', 'format': 1, 'eventType': 't', 'eventId': 'e', 'parentId': ''},
      },
      decodePacket: (_) => throw StateError('no packet expected'),
    );
    expect(message.type, MessageType.annotation);
    expect(message.annotation!.format, AnnotationFormat.json);
    expect(AnnotationData.fromMap(message.annotation!.toMap()).eventType, 't');
  });
}
