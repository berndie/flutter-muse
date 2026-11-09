# flutter_muse

Flutter plugin for the [Muse](https://choosemuse.com) SDK (libmuse) on
Android. It wraps the public API of `libmuse_android.jar`:

- discover headbands (`MuseManager`), including companion-device pairing
- connect, configure (preset, notch filter, LED, license data) and read
  configuration/version
- stream every `MuseDataPacketType` (raw EEG, band powers, scores, HSI,
  accelerometer, gyro, PPG, battery, ...), artifacts (blink, jaw clench,
  headband on), connection changes and errors
- write `.muse` files, including native recording that does not route
  packets through Dart
- read `.muse` files message by message or in batches, and play them back
  as a virtual headband (`ReaderMuse`)
- SDK logging, version, Muse Elements settings and helpers

Android only for now (minSdk 24). The plugin is
[federated](https://docs.flutter.dev/packages-and-plugins/developing-packages#federated-plugins):
this package is the app-facing API, `flutter_muse_android` is the Android
implementation (selected automatically), and `flutter_muse_platform_interface`
is the interface that future platform implementations, such as iOS, will extend.

## Setup

### 1. The Muse SDK (required)

The Muse SDK is proprietary and is **not** included in this package. Get it
from Interaxon (Muse), then put these files in one directory, for example
`android/muse_sdk/` in your app:

```
muse_sdk/
  libmuse_android.jar
  arm64-v8a/libmuse_android.so
  armeabi-v7a/libmuse_android.so
  x86_64/libmuse_android.so          # for the emulator, if you have it
```

Then tell the build where the directory is. Add this to your app's
`android/gradle.properties`; relative paths resolve against `android/`:

```properties
museSdkDir=muse_sdk
```

Alternatively, set `muse.sdk.dir` in `android/local.properties` or the
`MUSE_SDK_DIR` environment variable. If the jar can't be found, the Android
build stops with an error that says where it looked. If the `.so` files are
missing, the app still builds, but `FlutterMuse.initialize()` returns
`nativeLibraryLoaded: false`.

Remember to add the SDK directory to your app's `.gitignore` if your
license doesn't allow committing it.

### 2. Permissions

The plugin's manifest declares the Bluetooth permissions (`BLUETOOTH_SCAN`
with `neverForLocation` and `BLUETOOTH_CONNECT` on Android 12+;
`BLUETOOTH`, `BLUETOOTH_ADMIN` and `ACCESS_FINE_LOCATION` up to Android 11).
They are merged into your app automatically. Ask for them at runtime with
`MuseManager.instance.requestPermissions()`.

## Usage

```dart
import 'package:flutter_muse/flutter_muse.dart';

final status = await FlutterMuse.initialize();
if (!status.nativeLibraryLoaded) throw StateError(status.error ?? 'no libmuse');

final manager = MuseManager.instance;
await manager.requestPermissions();

manager.museListChanged.listen((muses) async {
  if (muses.isEmpty) return;
  final muse = muses.first;
  await manager.stopListening();

  muse.connectionPackets.listen((p) => print('${p.currentConnectionState}'));
  muse.dataPacketsOf(MuseDataPacketType.eeg).listen((p) {
    print('TP9 ${p.getEegChannelValue(Eeg.eeg1)} µV');
  });
  muse.dataPacketsOf(MuseDataPacketType.alphaAbsolute).listen((p) {
    print('alpha ${p.values}');
  });
  muse.artifactPackets.listen((a) => print('blink: ${a.blink}'));

  await muse.runAsynchronously(); // connect and start streaming
});
await manager.startListening();
```

### Recording and playback

```dart
final writer = await MuseFileFactory.getMuseFileWriter(path);
await writer.open();
await writer.addVersion(0, muse);
await writer.addConfiguration(0, muse);
await writer.startRecording(muse, [MuseDataPacketType.eeg, MuseDataPacketType.artifacts]);
// ...
await writer.dispose(); // stops recording, flushes and closes

final reader = await MuseFileFactory.getMuseFileReader(path);
await reader.open();
await for (final message in reader.readAll()) {
  print('${message.type} ${message.dataPacket?.values}');
}
await reader.dispose();

// Or play the file back as if it were a headband:
final reader2 = await MuseFileFactory.getMuseFileReader(path);
final readerMuse = await ReaderMuseBuilder()
    .withPlaybackSettings(ReaderMusePlaybackSettings.simulatedWithSavedTimestamp)
    .buildWithAsync(reader2);
readerMuse.asMuse().dataPacketsOf(MuseDataPacketType.eeg).listen(print);
await readerMuse.playback();
```

The example app in `example/` scans, connects, shows live EEG, alpha,
battery and artifacts, records to a file, and reads and plays the file back.

## Mapping from the Java SDK

| Java (`com.choosemuse.libmuse`) | Dart |
|---|---|
| `MuseManagerAndroid.getInstance()` | `MuseManager.instance` |
| `setContext`, `handleActivityResult` | done by the plugin |
| `setMuseListener(MuseListener)` | `MuseManager.museListChanged` stream |
| `startListening`, `stopListening`, `getMuses`, `removeFromListAfter`, `getAdvertisingStats`, `resetAdvertisingStats`, `setCompanionMode`, `museUuid` | same names |
| `getDefaultAdapter()` | `isBluetoothEnabled()` |
| `Muse.registerConnectionListener` | `muse.connectionPackets` |
| `Muse.registerErrorListener` | `muse.errors` |
| `Muse.registerDataListener(l, type)` | `muse.dataPackets([types])` / `muse.dataPacketsOf(type)` |
| `MuseDataListener.receiveMuseArtifactPacket` | `muse.artifactPackets` |
| `Muse.unregister*Listener` | cancel the stream subscription |
| other `Muse` methods | same names, returning `Future`s |
| `MuseDataPacket` getters | `MuseDataPacket` (`values`, `timestamp`, `getEegChannelValue`, ...) |
| `MuseFileFactory`, `MuseFileWriter`, `MuseFileReader` | same names (plus `readMessages`, `readAll`, `startRecording`) |
| `ReaderMuseBuilder`, `ReaderMuse`, `ReaderListener`, `ReaderPlaybackListener` | `ReaderMuseBuilder`, `ReaderMuse` (listeners are streams) |
| `LogManager`, `LogListener`, `MuseLog` | `LogManager.instance` (`logs()` stream), `MuseLog` |
| `LibmuseVersion`, `Stringify`, `ComputingDeviceConfigurationFactory` | `FlutterMuse.*` |
| `MuseVersion.makeVersion` / `makeDefaultVersion` | `FlutterMuse.makeVersion` / `makeDefaultVersion` |
| `MuseElementsAlgorithmSettings` | same name |
| `Error`, `Result`, `ConnectionState` | `MuseError`, `MuseResult`, `MuseConnectionState` (avoid clashing with Dart/Flutter names) |

Enum values are lowerCamelCase (`MuseDataPacketType.ALPHA_ABSOLUTE` →
`MuseDataPacketType.alphaAbsolute`).

### Not exposed to Dart

- **Package-private SDK internals** (`LeDevice`, `CharacteristicMapper`,
  `MusePlatformAndroid`, `HwLogger`, `ComputingDeviceBridge`,
  `RestrictedFeatures`, `WebsocketConfig`, ...): these are implementation
  details that apps cannot call, not public API.
- **`PlatformSocketIoClientFactorySingleton.set(...)`**: the SDK calls this
  socket.io client synchronously from native threads, so it can't be
  implemented in Dart. The jar is an `api` dependency, so you can implement
  it in Kotlin/Java in your app's `MainActivity` if you need it.
- Listener callbacks receive `(packet, muse)` in Java. In Dart, the stream
  you subscribed to already tells you the headband, and packets carry a
  `museId`.
- **`EventLoop` / `HandlerEventLoop` / `Action`**: the plugin uses the
  main-thread event loop internally.

## Notes

- **Threading:** all SDK calls run on the Android main thread, which
  `MuseManagerAndroid` requires. If you build a `ReaderMuse` with
  `build()` (synchronous), its blocking calls run on a background thread.
- **Throughput:** EEG arrives at 256 packets/s per headband. Packets are
  sent to Dart in batches every 16 ms by default; change this with
  `FlutterMuse.initialize(packetBatchInterval: ...)`. For recording, use
  `MuseFileWriter.startRecording`, which writes natively.
- **Typed accessors:** `getEegChannelValue`, `getBatteryValue`, and the
  other typed getters return the values from the SDK's own accessors,
  which are computed natively for each packet. They throw a `StateError`
  when the packet type has no such accessor.
- **Updating the SDK:** replace your SDK directory's contents. If the
  SDK's enums changed, the plugin needs a new release: its Dart enums must
  match the Java ordinals (see `tool/generate_enums.py` in the repository).
