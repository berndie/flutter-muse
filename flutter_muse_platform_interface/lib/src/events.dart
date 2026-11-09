import 'models.dart';
import 'flutter_muse_platform.dart';

/// An event from the native SDK, delivered by [FlutterMusePlatform.events].
sealed class MusePlatformEvent {
  const MusePlatformEvent();
}

/// `MuseListener.museListChanged()`, with the new list.
final class MuseListChangedEvent extends MusePlatformEvent {
  /// Creates the event.
  const MuseListChangedEvent(this.muses);

  /// The headbands now known to the manager.
  final List<MuseInfo> muses;
}

/// `MuseConnectionListener.receiveMuseConnectionPacket()`.
final class MuseConnectionEvent extends MusePlatformEvent {
  /// Creates the event.
  const MuseConnectionEvent(this.packet);

  /// The state change.
  final MuseConnectionPacket packet;
}

/// `MuseErrorListener.receiveError()`. [MuseError.museId] is always set.
final class MuseErrorEvent extends MusePlatformEvent {
  /// Creates the event.
  const MuseErrorEvent(this.error);

  /// The error.
  final MuseError error;
}

/// `MuseDataListener.receiveMuseDataPacket()`. [MuseDataPacket.museId] is
/// always set.
final class MuseDataPacketEvent extends MusePlatformEvent {
  /// Creates the event.
  const MuseDataPacketEvent(this.packet);

  /// The packet.
  final MuseDataPacket packet;
}

/// `MuseDataListener.receiveMuseArtifactPacket()`.
/// [MuseArtifactPacket.museId] is always set.
final class MuseArtifactPacketEvent extends MusePlatformEvent {
  /// Creates the event.
  const MuseArtifactPacketEvent(this.packet);

  /// The packet.
  final MuseArtifactPacket packet;
}

/// `LogListener.receiveLog()` (while the log listener is enabled).
final class MuseLogEvent extends MusePlatformEvent {
  /// Creates the event.
  const MuseLogEvent(this.packet);

  /// The log line.
  final LogPacket packet;
}

/// `ReaderListener` callbacks of a ReaderMuse. Exactly one payload is set.
final class ReaderMuseMessageEvent extends MusePlatformEvent {
  /// Creates the event.
  const ReaderMuseMessageEvent(
    this.readerMuseId, {
    this.annotation,
    this.configuration,
    this.version,
    this.computingDeviceConfiguration,
  });

  /// [ReaderMuseRef.id] of the reader muse.
  final int readerMuseId;

  /// `receiveAnnotation`.
  final AnnotationData? annotation;

  /// `receiveConfiguration`.
  final MuseConfiguration? configuration;

  /// `receiveVersion`.
  final MuseVersion? version;

  /// `receiveComputingDeviceConfiguration`.
  final ComputingDeviceConfiguration? computingDeviceConfiguration;
}

/// `ReaderPlaybackListener` callbacks of a ReaderMuse.
final class ReaderMusePlaybackEvent extends MusePlatformEvent {
  /// Creates the event.
  const ReaderMusePlaybackEvent(this.readerMuseId, this.kind);

  /// [ReaderMuseRef.id] of the reader muse.
  final int readerMuseId;

  /// Done or interrupted.
  final ReaderPlaybackEventKind kind;
}
