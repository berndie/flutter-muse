import 'dart:async';

import 'package:flutter_muse_platform_interface/flutter_muse_platform_interface.dart';
import 'package:meta/meta.dart';

/// Initialises the platform implementation once per isolate and fans its
/// events out to the app-facing classes.
@internal
class MuseRuntime {
  MuseRuntime._();

  static Future<MuseSdkStatus>? _initialization;
  static StreamSubscription<MusePlatformEvent>? _subscription;
  static Duration _batchInterval = const Duration(milliseconds: 16);
  static final List<void Function(MusePlatformEvent)> _listeners = [];

  /// Registers a receiver for every platform event.
  static void addListener(void Function(MusePlatformEvent) listener) => _listeners.add(listener);

  /// Initialises the platform once (also resets native state left over from
  /// before a hot restart).
  static Future<MuseSdkStatus> initialize({Duration? batchInterval}) {
    if (batchInterval != null) _batchInterval = batchInterval;
    return _initialization ??= _doInitialize();
  }

  static Future<MuseSdkStatus> _doInitialize() async {
    final platform = FlutterMusePlatform.instance;
    _subscription ??= platform.events.listen((event) {
      // A listener may register further listeners (e.g. the first Muse
      // created while handling a list change), so iterate over a snapshot.
      for (final l in List.of(_listeners)) {
        l(event);
      }
    });
    try {
      return await platform.initialize(packetBatchInterval: _batchInterval);
    } catch (_) {
      _initialization = null;
      rethrow;
    }
  }

  /// The platform implementation, once initialised.
  static Future<FlutterMusePlatform> ready() async {
    await initialize();
    return FlutterMusePlatform.instance;
  }

  /// Test hook: forget the initialisation so the next call re-initialises.
  @visibleForTesting
  static Future<void> resetForTesting() async {
    await _subscription?.cancel();
    _subscription = null;
    _initialization = null;
  }
}
