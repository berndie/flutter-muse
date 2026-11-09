/// Flutter bindings for the Muse SDK (libmuse).
///
/// Start with [MuseManager.instance] to discover headbands, then connect a
/// [Muse] with [Muse.runAsynchronously] and listen to [Muse.dataPackets].
library;

export 'package:flutter_muse_platform_interface/flutter_muse_platform_interface.dart'
    hide
        FlutterMusePlatform,
        MusePlatformEvent,
        MuseListChangedEvent,
        MuseConnectionEvent,
        MuseErrorEvent,
        MuseDataPacketEvent,
        MuseArtifactPacketEvent,
        MuseLogEvent,
        ReaderMuseMessageEvent,
        ReaderMusePlaybackEvent,
        ReaderMuseRef;

export 'src/file_io.dart';
export 'src/log.dart';
export 'src/muse.dart' show Muse;
export 'src/muse_manager.dart';
