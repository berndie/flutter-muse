# flutter_muse (repository)

A federated Flutter plugin for the Muse EEG headband SDK (libmuse).

| Package | Purpose |
|---|---|
| [`flutter_muse`](flutter_muse) | The app-facing API. Start here. Contains the example app. |
| [`flutter_muse_platform_interface`](flutter_muse_platform_interface) | The interface, enums and models shared by platform implementations. |
| [`flutter_muse_android`](flutter_muse_android) | The Android implementation (Kotlin + `libmuse_android`). |

An iOS implementation would be added as `flutter_muse_ios`, with
`flutter_muse/pubspec.yaml` listing it as the iOS `default_package`.

## Development

The packages form a [pub workspace](https://dart.dev/tools/pub/workspaces):

```sh
flutter pub get            # once, at the repository root
```

The proprietary Muse SDK is git-ignored and never published. To build the
example, put your copy in `flutter_muse_android/android/libs/`
(`libmuse_android.jar` plus `<abi>/libmuse_android.so`), or point
`MUSE_SDK_DIR` at it.

```sh
(cd flutter_muse && flutter test)
(cd flutter_muse_platform_interface && flutter test)
(cd flutter_muse_android && flutter test)
(cd flutter_muse/example && flutter build apk --debug)
python3 tool/generate_enums.py   # after updating the SDK
```
