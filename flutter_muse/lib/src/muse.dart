import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_muse_platform_interface/flutter_muse_platform_interface.dart';
import 'package:meta/meta.dart';

import 'runtime.dart';

/// A Muse headband (mirrors `com.choosemuse.libmuse.Muse`).
///
/// Obtain instances from [MuseManager.getMuses] /
/// [MuseManager.museListChanged], or from [ReaderMuse.asMuse] for file
/// playback. There is exactly one [Muse] object per headband, so instances
/// can be compared with `==`.
///
/// The SDK's listener registration maps onto streams:
///
/// | SDK                                           | Dart                     |
/// |-----------------------------------------------|--------------------------|
/// | `registerConnectionListener`                  | [connectionPackets]      |
/// | `registerErrorListener`                       | [errors]                 |
/// | `registerDataListener(l, type)`               | [dataPackets]`(type)`    |
/// | `registerDataListener(l, ARTIFACTS)`          | [artifactPackets]        |
///
/// Data types are registered natively while at least one subscription needs
/// them and unregistered when the last one is cancelled.
class Muse {
  Muse._(this.id);

  static final Map<String, Muse> _registry = {};
  static bool _handlersInstalled = false;

  /// Returns the unique [Muse] for [id], creating it if needed.
  @internal
  static Muse forId(String id) {
    _installHandlers();
    return _registry.putIfAbsent(id, () => Muse._(id));
  }

  /// Drops [id] from the registry (used when a [ReaderMuse] is disposed).
  @internal
  static void forget(String id) => _registry.remove(id);

  /// Creates or updates the [Muse] described by [info].
  @internal
  static Muse fromInfo(MuseInfo info) => forId(info.id).._info = info;

  static void _installHandlers() {
    if (_handlersInstalled) return;
    _handlersInstalled = true;
    MuseRuntime.addListener((event) {
      switch (event) {
        case MuseDataPacketEvent(:final packet):
          _registry[packet.museId]?._dispatchData(packet);
        case MuseArtifactPacketEvent(:final packet):
          _registry[packet.museId]?._dispatchArtifact(packet);
        case MuseConnectionEvent(:final packet):
          _registry[packet.museId]?._onConnection(packet);
        case MuseErrorEvent(:final error):
          _registry[error.museId]?._errors.add(error);
        default:
          break;
      }
    });
  }

  /// Plugin identifier: the MAC address for discovered headbands,
  /// `reader:<n>` for a [ReaderMuse].
  final String id;

  MuseInfo? _info;

  final StreamController<MuseConnectionPacket> _connection = StreamController.broadcast(sync: true);
  final StreamController<MuseError> _errors = StreamController.broadcast(sync: true);
  final Map<MuseDataPacketType, Set<StreamController<MuseDataPacket>>> _dataControllers = {};
  final Set<StreamController<MuseArtifactPacket>> _artifactControllers = {};
  final Map<MuseDataPacketType, int> _typeRefs = {};

  /// The most recent snapshot of this headband's properties (updated by the
  /// manager's list changes, connection events and [getInfo]).
  MuseInfo? get info => _info;

  /// Advertised name (cached).
  String? get name => _info?.name;

  /// Bluetooth MAC address (cached).
  String? get macAddress => _info?.macAddress;

  /// Hardware model (cached).
  MuseModel? get model => _info?.model;

  /// Last known connection state (cached).
  MuseConnectionState? get connectionState => _info?.connectionState;

  // ------------------------------------------------------------- properties

  /// Reads all properties from the SDK and refreshes [info].
  Future<MuseInfo> getInfo() async => _info = await (await MuseRuntime.ready()).getMuseInfo(id);

  /// `getName()`.
  Future<String?> getName() async => (await getInfo()).name;

  /// `getMacAddress()`.
  Future<String?> getMacAddress() async => (await getInfo()).macAddress;

  /// `getModel()`.
  Future<MuseModel?> getModel() async => (await getInfo()).model;

  /// `getRssi()`.
  Future<double?> getRssi() async => (await getInfo()).rssi;

  /// `getLastDiscoveredTime()`.
  Future<double?> getLastDiscoveredTime() async => (await getInfo()).lastDiscoveredTime;

  /// `getConnectionState()`.
  Future<MuseConnectionState?> getConnectionState() async => (await getInfo()).connectionState;

  /// `isLowEnergy()`.
  Future<bool?> isLowEnergy() async => (await getInfo()).isLowEnergy;

  /// `isPaired()`.
  Future<bool?> isPaired() async => (await getInfo()).isPaired;

  /// `isConnectable()`.
  Future<bool?> isConnectable() async => (await getInfo()).isConnectable;

  /// `getMuseConfiguration()`: available once connected.
  Future<MuseConfiguration?> getMuseConfiguration() async =>
      (await MuseRuntime.ready()).getMuseConfiguration(id);

  /// `getMuseVersion()`: available once connected.
  Future<MuseVersion?> getMuseVersion() async => (await MuseRuntime.ready()).getMuseVersion(id);

  // ------------------------------------------------------------- connection

  /// `runAsynchronously()`: connects and streams data on the SDK's event
  /// loop. This is the usual way to connect.
  Future<void> runAsynchronously() async => (await MuseRuntime.ready()).runAsynchronously(id);

  /// `connect()`: connects without starting the asynchronous run loop
  /// (drive it with [execute]).
  Future<void> connect() async => (await MuseRuntime.ready()).connect(id);

  /// `execute()`: one step of the synchronous run loop.
  Future<void> execute() async => (await MuseRuntime.ready()).execute(id);

  /// `disconnect()`.
  Future<void> disconnect() async => (await MuseRuntime.ready()).disconnect(id);

  /// `setNumConnectTries(tries)`.
  Future<void> setNumConnectTries(int tries) async => (await MuseRuntime.ready()).setNumConnectTries(id, tries);

  /// `setLicenseData(data)`: unlocks licensed headbands
  /// ([MuseConnectionState.needsLicense]).
  Future<void> setLicenseData(Uint8List data) async => (await MuseRuntime.ready()).setLicenseData(id, data);

  // ---------------------------------------------------------- configuration

  /// `enableDataTransmission(enabled)`: pause/resume streaming.
  Future<void> enableDataTransmission(bool enabled) async =>
      (await MuseRuntime.ready()).enableDataTransmission(id, enabled);

  /// `enableException(enabled)`.
  Future<void> enableException(bool enabled) async => (await MuseRuntime.ready()).enableException(id, enabled);

  /// `enableLedIndicator(enabled)`.
  Future<void> enableLedIndicator(bool enabled) async =>
      (await MuseRuntime.ready()).enableLedIndicator(id, enabled);

  /// `setPreset(preset)`: call before connecting.
  Future<void> setPreset(MusePreset preset) async => (await MuseRuntime.ready()).setPreset(id, preset);

  /// `setNotchFrequency(frequency)`.
  Future<void> setNotchFrequency(NotchFrequency frequency) async =>
      (await MuseRuntime.ready()).setNotchFrequency(id, frequency);

  // -------------------------------------------------------------- listeners

  /// Connection state changes (`MuseConnectionListener`).
  Stream<MuseConnectionPacket> get connectionPackets {
    unawaited(MuseRuntime.initialize());
    return _connection.stream;
  }

  /// Errors (`MuseErrorListener`).
  Stream<MuseError> get errors {
    unawaited(MuseRuntime.initialize());
    return _errors.stream;
  }

  /// Data packets of the given [types] (`MuseDataListener`).
  ///
  /// Use [artifactPackets] for [MuseDataPacketType.artifacts].
  Stream<MuseDataPacket> dataPackets(Iterable<MuseDataPacketType> types) {
    final typeSet = types.toSet();
    late final StreamController<MuseDataPacket> controller;
    controller = StreamController<MuseDataPacket>(
      sync: true,
      onListen: () {
        for (final t in typeSet) {
          _dataControllers.putIfAbsent(t, () => {}).add(controller);
          _retain(t);
        }
      },
      onCancel: () {
        for (final t in typeSet) {
          _dataControllers[t]?.remove(controller);
          _release(t);
        }
      },
    );
    return controller.stream;
  }

  /// Data packets of a single [type].
  Stream<MuseDataPacket> dataPacketsOf(MuseDataPacketType type) => dataPackets([type]);

  /// Blink, jaw clench and headband-on detection
  /// (`receiveMuseArtifactPacket`, registered as
  /// [MuseDataPacketType.artifacts]).
  Stream<MuseArtifactPacket> get artifactPackets {
    late final StreamController<MuseArtifactPacket> controller;
    controller = StreamController<MuseArtifactPacket>(
      sync: true,
      onListen: () {
        _artifactControllers.add(controller);
        _retain(MuseDataPacketType.artifacts);
      },
      onCancel: () {
        _artifactControllers.remove(controller);
        _release(MuseDataPacketType.artifacts);
      },
    );
    return controller.stream;
  }

  /// `unregisterAllListeners()`.
  ///
  /// Removes every listener on the native headband (including any added by
  /// native code outside this plugin). Active [dataPackets] and
  /// [artifactPackets] subscriptions stop receiving packets; cancel them and
  /// subscribe again to resume. [connectionPackets] and [errors] keep
  /// working.
  Future<void> unregisterAllListeners() async {
    _typeRefs.clear();
    _dataControllers.clear();
    _artifactControllers.clear();
    await (await MuseRuntime.ready()).unregisterAllListeners(id);
  }

  void _retain(MuseDataPacketType type) {
    final count = _typeRefs[type] ?? 0;
    _typeRefs[type] = count + 1;
    if (count == 0) unawaited(MuseRuntime.ready().then((p) => p.registerDataType(id, type)));
  }

  void _release(MuseDataPacketType type) {
    final count = _typeRefs[type];
    if (count == null) return;
    if (count <= 1) {
      _typeRefs.remove(type);
      unawaited(MuseRuntime.ready().then((p) => p.unregisterDataType(id, type)).catchError((Object _) {}));
    } else {
      _typeRefs[type] = count - 1;
    }
  }

  void _onConnection(MuseConnectionPacket packet) {
    final info = _info;
    _info = MuseInfo(
      id: id,
      name: info?.name,
      macAddress: info?.macAddress,
      model: info?.model,
      rssi: info?.rssi,
      lastDiscoveredTime: info?.lastDiscoveredTime,
      connectionState: packet.currentConnectionState,
      isLowEnergy: info?.isLowEnergy,
      isPaired: info?.isPaired,
      isConnectable: info?.isConnectable,
    );
    _connection.add(packet);
  }

  void _dispatchData(MuseDataPacket packet) {
    final controllers = _dataControllers[packet.packetType];
    if (controllers == null) return;
    for (final c in controllers.toList()) {
      c.add(packet);
    }
  }

  void _dispatchArtifact(MuseArtifactPacket packet) {
    for (final c in _artifactControllers.toList()) {
      c.add(packet);
    }
  }

  @override
  String toString() => 'Muse($id${name == null ? '' : ', $name'})';
}
