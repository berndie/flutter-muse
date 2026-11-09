# flutter_muse_platform_interface

A common platform interface for the [`flutter_muse`](../flutter_muse) plugin.

Platform implementations extend `FlutterMusePlatform` (rather than implement
it) and register themselves with `FlutterMusePlatform.instance = ...`. The
interface mirrors the Muse SDK (libmuse) one call per method. It refers to
headbands by id string and to files and reader muses by integer handles.
Native callbacks arrive as typed `MusePlatformEvent`s on
`FlutterMusePlatform.events`.

The package also defines the enums and value types shared by every
implementation. The enums are generated from the Android SDK jar
(`tool/generate_enums.py` in the repository), so their indexes equal the
Java ordinals. The Muse SDK is the same djinni-generated API on every
platform, so these ordinals are expected to hold on iOS too.

Prefer non-breaking changes (adding methods) over breaking ones. See
[the Flutter guidance on breaking changes](https://flutter.dev/go/platform-interface-breaking-changes).
