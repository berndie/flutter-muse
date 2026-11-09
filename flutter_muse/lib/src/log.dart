import 'dart:async';

import 'package:flutter_muse_platform_interface/flutter_muse_platform_interface.dart';

import 'runtime.dart';

/// The SDK's log sink (mirrors `LogManager`).
class LogManager {
  LogManager._() {
    MuseRuntime.addListener((event) {
      if (event is MuseLogEvent) _controller.add(event.packet);
    });
  }

  /// `LogManager.instance()`.
  static final LogManager instance = LogManager._();

  late final StreamController<LogPacket> _controller = StreamController.broadcast(
    onListen: () => unawaited(
      MuseRuntime.ready().then((p) => p.setLogListenerEnabled(true, forwardToSystemLog: _forwardToSystemLog)),
    ),
    // Restores the SDK's default log listener.
    onCancel: () => unawaited(MuseRuntime.ready().then((p) => p.setLogListenerEnabled(false))),
  );
  bool _forwardToSystemLog = true;

  /// SDK log lines (`setLogListener`). While subscribed, lines are still
  /// written to the system log (logcat on Android) unless
  /// [forwardToSystemLog] was false for the first subscription.
  Stream<LogPacket> logs({bool forwardToSystemLog = true}) {
    if (!_controller.hasListener) _forwardToSystemLog = forwardToSystemLog;
    return _controller.stream;
  }

  /// `setMinimumSeverity(severity)`.
  Future<void> setMinimumSeverity(Severity severity) async =>
      (await MuseRuntime.ready()).setLogMinimumSeverity(severity);

  /// `writeLog(severity, raw, tag, message)`.
  Future<void> writeLog(Severity severity, String tag, String message, {bool raw = false}) async =>
      (await MuseRuntime.ready()).writeLog(severity, tag, message, raw: raw);

  /// `getTimestamp()`: the SDK's clock.
  Future<int> getTimestamp() async => (await MuseRuntime.ready()).getLogTimestamp();

  /// `timeSince(timestamp)`: seconds elapsed since [timestamp] from
  /// [getTimestamp].
  Future<double> timeSince(int timestamp) async => (await MuseRuntime.ready()).logTimeSince(timestamp);
}

/// Writes to the SDK log (mirrors the static `MuseLog` helpers).
class MuseLog {
  MuseLog._();

  /// `MuseLog.log(severity, message, raw)`.
  static Future<void> log(Severity severity, String message, {bool raw = false}) async =>
      (await MuseRuntime.ready()).museLog(severity, message, raw: raw);

  /// Verbose.
  static Future<void> v(String message) => log(Severity.sevVerbose, message);

  /// Debug.
  static Future<void> d(String message) => log(Severity.sevDebug, message);

  /// Info.
  static Future<void> i(String message) => log(Severity.sevInfo, message);

  /// Warning.
  static Future<void> w(String message) => log(Severity.sevWarn, message);

  /// Error.
  static Future<void> e(String message) => log(Severity.sevError, message);

  /// Fatal.
  static Future<void> f(String message) => log(Severity.sevFatal, message);

  /// Raw (unformatted) verbose message.
  static Future<void> r(String message) => log(Severity.sevVerbose, message, raw: true);
}
