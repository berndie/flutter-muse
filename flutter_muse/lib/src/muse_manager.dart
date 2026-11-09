import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_muse_platform_interface/flutter_muse_platform_interface.dart';

import 'muse.dart';
import 'runtime.dart';

/// Discovers headbands (mirrors `MuseManager` / `MuseManagerAndroid`).
///
/// On Android the plugin sets the context and forwards activity results
/// (`handleActivityResult`) for you.
class MuseManager {
  MuseManager._() {
    MuseRuntime.addListener((event) {
      if (event is MuseListChangedEvent) _listChanged.add(event.muses.map(Muse.fromInfo).toList());
    });
  }

  /// `MuseManagerAndroid.getInstance()`.
  static final MuseManager instance = MuseManager._();

  /// `MuseManager.DEFAULT_REMOVE_FROM_LIST_AFTER`.
  static const Duration defaultRemoveFromListAfter = Duration(seconds: 30);

  final StreamController<List<Muse>> _listChanged = StreamController.broadcast();

  /// Emits the current headband list whenever it changes (`MuseListener`).
  Stream<List<Muse>> get museListChanged {
    unawaited(MuseRuntime.initialize());
    return _listChanged.stream;
  }

  /// Whether the Bluetooth permissions the SDK needs are granted
  /// (on Android: BLUETOOTH_SCAN + BLUETOOTH_CONNECT on 12+, fine location
  /// on older versions).
  Future<bool> hasPermissions() async => (await MuseRuntime.ready()).hasPermissions();

  /// Asks the user for the Bluetooth permissions the SDK needs. Returns the
  /// status of each permission.
  Future<Map<String, bool>> requestPermissions() async => (await MuseRuntime.ready()).requestPermissions();

  /// Whether the Bluetooth adapter is on (`getDefaultAdapter().isEnabled()`).
  Future<bool> isBluetoothEnabled() async => (await MuseRuntime.ready()).isBluetoothEnabled();

  /// `startListening()`: starts scanning for headbands.
  Future<void> startListening() async => (await MuseRuntime.ready()).startListening();

  /// `stopListening()`.
  Future<void> stopListening() async => (await MuseRuntime.ready()).stopListening();

  /// `getMuses()`: headbands seen recently.
  Future<List<Muse>> getMuses() async => (await (await MuseRuntime.ready()).getMuses()).map(Muse.fromInfo).toList();

  /// `removeFromListAfter(seconds)`: how long an unseen headband stays in
  /// the list.
  Future<void> removeFromListAfter(Duration duration) async =>
      (await MuseRuntime.ready()).removeFromListAfter(duration);

  /// `resetAdvertisingStats()`.
  Future<void> resetAdvertisingStats() async => (await MuseRuntime.ready()).resetAdvertisingStats();

  /// `getAdvertisingStats(muse)`.
  Future<AdvertisingStats?> getAdvertisingStats(Muse muse) async =>
      (await MuseRuntime.ready()).getAdvertisingStats(muse.id);

  /// `setCompanionMode(enabled, macAddress, manufacturerData, removeOthers)`
  /// (Android 8.0+).
  ///
  /// In companion mode, [startListening] shows the system companion-device
  /// picker instead of scanning silently; the selected headband is added to
  /// the list. Pass the [macAddress] (and [manufacturerData]) of a
  /// previously associated headband to add it without showing the picker.
  /// [removeOthers] drops every other headband from the list.
  Future<void> setCompanionMode(
    bool enabled, {
    String? macAddress,
    Uint8List? manufacturerData,
    bool removeOthers = false,
  }) async =>
      (await MuseRuntime.ready()).setCompanionMode(
        enabled,
        macAddress: macAddress,
        manufacturerData: manufacturerData,
        removeOthers: removeOthers,
      );

  /// `MuseManagerAndroid.museUuid()`: the BLE service UUID of Muse headbands.
  Future<String> museUuid() async => (await MuseRuntime.ready()).museUuid();
}

/// SDK-wide functions that have no natural home elsewhere.
class FlutterMuse {
  FlutterMuse._();

  /// Initialises the plugin. Calling it is optional (every API initialises
  /// lazily) but it lets you check that the native library is present and
  /// choose the packet batch interval.
  ///
  /// Data packets are delivered to Dart in batches collected over
  /// [packetBatchInterval] (default 16 ms); `Duration.zero` sends each
  /// packet on its own.
  static Future<MuseSdkStatus> initialize({Duration? packetBatchInterval}) =>
      MuseRuntime.initialize(batchInterval: packetBatchInterval);

  /// Changes the packet batch interval at runtime.
  static Future<void> setPacketBatchInterval(Duration interval) async =>
      (await MuseRuntime.ready()).setPacketBatchInterval(interval);

  /// `LibmuseVersion.instance()`.
  static Future<ApiVersion> libmuseVersion() async => (await MuseRuntime.ready()).getLibmuseVersion();

  /// `Stringify.instance().connectionState(state)`.
  static Future<String> stringifyConnectionState(MuseConnectionState state) async =>
      (await MuseRuntime.ready()).stringifyConnectionState(state);

  /// `Stringify.instance().packetType(type)`.
  static Future<String> stringifyPacketType(MuseDataPacketType type) async =>
      (await MuseRuntime.ready()).stringifyPacketType(type);

  /// `ComputingDeviceConfigurationFactory.getInstance().getComputingDeviceConfiguration()`.
  static Future<ComputingDeviceConfiguration> computingDeviceConfiguration() async =>
      (await MuseRuntime.ready()).getComputingDeviceConfiguration();

  /// `MuseVersion.makeDefaultVersion()`.
  static Future<MuseVersion> makeDefaultVersion() async => (await MuseRuntime.ready()).makeDefaultVersion();

  /// `MuseVersion.makeVersion(json)`: parses a version JSON string.
  static Future<MuseVersion> makeVersion(String json) async => (await MuseRuntime.ready()).makeVersion(json);
}

/// Settings of the on-device Muse Elements algorithms (mirrors
/// `MuseElementsAlgorithmSettings`).
class MuseElementsAlgorithmSettings {
  MuseElementsAlgorithmSettings._();

  /// `getInstance()`.
  static final MuseElementsAlgorithmSettings instance = MuseElementsAlgorithmSettings._();

  /// `getElementsVersion()`.
  Future<MuseElementsVersion?> getElementsVersion() async => (await MuseRuntime.ready()).getElementsVersion();

  /// `setElementsVersion(version)`.
  Future<void> setElementsVersion(MuseElementsVersion version) async =>
      (await MuseRuntime.ready()).setElementsVersion(version);

  /// `getEnableMultipleMuseElements()`.
  Future<bool> getEnableMultipleMuseElements() async =>
      (await MuseRuntime.ready()).getEnableMultipleMuseElements();

  /// `setEnableMultipleMuseElements(enabled)`.
  Future<void> setEnableMultipleMuseElements(bool enabled) async =>
      (await MuseRuntime.ready()).setEnableMultipleMuseElements(enabled);
}
