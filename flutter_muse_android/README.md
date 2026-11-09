# flutter_muse_android

The Android implementation of [`flutter_muse`](../flutter_muse).

## Usage

This package is [endorsed](https://docs.flutter.dev/packages-and-plugins/developing-packages#endorsed-federated-plugin):
depend on `flutter_muse` and it is used automatically on Android. Depend on
this package directly only if you need its classes.

## The Muse SDK

The Muse SDK (`libmuse_android.jar` and `libmuse_android.so`) is
proprietary and is **not** distributed with this package. Put your copy in a
directory:

```
<sdk dir>/libmuse_android.jar
<sdk dir>/<abi>/libmuse_android.so      # arm64-v8a, armeabi-v7a, x86_64, ...
```

The build looks for that directory in this order:

1. `museSdkDir=<dir>` in the app's `android/gradle.properties` (or `-PmuseSdkDir=<dir>`)
2. `muse.sdk.dir=<dir>` in the app's `android/local.properties`
3. the `MUSE_SDK_DIR` environment variable
4. this package's own `android/libs/` (used when developing the plugin in
   its repository; git- and pub-ignored)

Relative paths resolve against the app's `android/` directory. The jar is
an `api` dependency, so app code can use `com.choosemuse.libmuse` classes
directly.

## Platform channel protocol

`FlutterMuseAndroid` (Dart) talks to `FlutterMusePlugin` (Kotlin) over the
`flutter_muse/methods` method channel and the `flutter_muse/events` event
channel. Enums are sent as their Java ordinals. High-rate data and artifact
packets are batched into one `packets` event at a time.
