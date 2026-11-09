import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_muse/flutter_muse.dart';

void main() => runApp(const MaterialApp(title: 'Muse demo', home: MuseDemo()));

class MuseDemo extends StatefulWidget {
  const MuseDemo({super.key});

  @override
  State<MuseDemo> createState() => _MuseDemoState();
}

class _MuseDemoState extends State<MuseDemo> {
  final _manager = MuseManager.instance;
  StreamSubscription<List<Muse>>? _listSubscription;
  final _museSubscriptions = <StreamSubscription<Object?>>[];

  MuseSdkStatus? _status;
  List<Muse> _muses = const [];
  bool _scanning = false;
  Muse? _muse;
  MuseConnectionState _state = MuseConnectionState.unknown;
  MuseVersion? _version;
  MuseConfiguration? _configuration;
  Map<Eeg, double> _eeg = const {};
  Map<Eeg, double> _alpha = const {};
  double? _battery;
  MuseArtifactPacket? _artifact;
  int _eegPackets = 0;
  final _log = <String>[];

  MuseFileWriter? _writer;
  String? _recordingPath;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final status = await FlutterMuse.initialize();
    setState(() => _status = status);
    if (!status.nativeLibraryLoaded) return;
    _listSubscription = _manager.museListChanged.listen((muses) => setState(() => _muses = muses));
  }

  void _addLog(String line) => setState(() {
        _log.insert(0, line);
        if (_log.length > 50) _log.removeLast();
      });

  Future<void> _toggleScan() async {
    if (_scanning) {
      await _manager.stopListening();
    } else {
      final granted = await _manager.requestPermissions();
      if (granted.values.any((g) => !g)) {
        _addLog('Bluetooth permissions denied: $granted');
        return;
      }
      if (!await _manager.isBluetoothEnabled()) {
        _addLog('Bluetooth is off');
        return;
      }
      await _manager.startListening();
    }
    setState(() => _scanning = !_scanning);
  }

  Future<void> _connect(Muse muse) async {
    await _disconnect();
    await _manager.stopListening();
    setState(() {
      _scanning = false;
      _muse = muse;
    });

    _museSubscriptions.addAll([
      muse.connectionPackets.listen((p) async {
        setState(() => _state = p.currentConnectionState);
        _addLog('${muse.name}: ${p.previousConnectionState.name} -> ${p.currentConnectionState.name}');
        if (p.currentConnectionState == MuseConnectionState.connected) {
          final version = await muse.getMuseVersion();
          final configuration = await muse.getMuseConfiguration();
          setState(() {
            _version = version;
            _configuration = configuration;
          });
        }
      }),
      muse.errors.listen((e) => _addLog('Error: $e')),
      muse.dataPacketsOf(MuseDataPacketType.eeg).listen((p) {
        _eegPackets++;
        // Repaint at most ~10 times per second.
        if (_eegPackets % 25 == 0) {
          setState(() => _eeg = {for (final c in Eeg.values) c: p.getEegChannelValue(c)});
        }
      }),
      muse.dataPacketsOf(MuseDataPacketType.alphaAbsolute).listen(
            (p) => setState(() => _alpha = {for (final c in Eeg.values) c: p.getEegChannelValue(c)}),
          ),
      muse.dataPacketsOf(MuseDataPacketType.battery).listen(
            (p) => setState(() => _battery = p.getBatteryValue(Battery.chargePercentageRemaining)),
          ),
      muse.artifactPackets.listen((a) => setState(() => _artifact = a)),
    ]);

    await muse.runAsynchronously();
  }

  Future<void> _disconnect() async {
    await _stopRecording();
    for (final s in _museSubscriptions) {
      await s.cancel();
    }
    _museSubscriptions.clear();
    await _muse?.disconnect();
    setState(() {
      _muse = null;
      _state = MuseConnectionState.unknown;
      _version = null;
      _configuration = null;
      _eeg = const {};
      _alpha = const {};
      _battery = null;
      _artifact = null;
    });
  }

  Future<void> _startRecording() async {
    final muse = _muse;
    if (muse == null) return;
    final path = '${Directory.systemTemp.path}/recording_${DateTime.now().millisecondsSinceEpoch}.muse';
    final writer = await MuseFileFactory.getMuseFileWriter(path);
    await writer.open();
    await writer.addComputingDeviceConfiguration(0);
    await writer.addVersion(0, muse);
    await writer.addConfiguration(0, muse);
    await writer.addAnnotationString(0, 'Recording started');
    await writer.startRecording(muse, const [
      MuseDataPacketType.eeg,
      MuseDataPacketType.accelerometer,
      MuseDataPacketType.alphaAbsolute,
      MuseDataPacketType.battery,
      MuseDataPacketType.artifacts,
    ]);
    setState(() {
      _writer = writer;
      _recordingPath = path;
    });
    _addLog('Recording to $path');
  }

  Future<void> _stopRecording() async {
    final writer = _writer;
    if (writer == null) return;
    await writer.stopRecording();
    final stats = await writer.getStats();
    await writer.dispose();
    setState(() => _writer = null);
    _addLog('Recording stopped: $stats');
  }

  Future<void> _summarizeRecording() async {
    final path = _recordingPath;
    if (path == null) return;
    final reader = await MuseFileFactory.getMuseFileReader(path);
    if (!await reader.open()) {
      _addLog('Could not open $path');
      return;
    }
    final counts = <MessageType?, int>{};
    await for (final message in reader.readAll()) {
      counts[message.type] = (counts[message.type] ?? 0) + 1;
    }
    await reader.dispose();
    _addLog('File contents: ${counts.entries.map((e) => '${e.key?.name}: ${e.value}').join(', ')}');
  }

  Future<void> _playBack() async {
    final path = _recordingPath;
    if (path == null) return;
    final reader = await MuseFileFactory.getMuseFileReader(path);
    final readerMuse = await ReaderMuseBuilder()
        .withPlaybackSettings(ReaderMusePlaybackSettings.asFastAsPossibleWithSavedTimestamp)
        .buildWithAsync(reader);
    var packets = 0;
    final sub = readerMuse.asMuse().dataPacketsOf(MuseDataPacketType.eeg).listen((_) => packets++);
    readerMuse.playbackEvents.first.then((event) async {
      await sub.cancel();
      _addLog('Playback ${event.kind.name}: $packets EEG packets');
      await readerMuse.dispose();
      await reader.dispose();
    });
    await readerMuse.playback();
  }

  @override
  void dispose() {
    _listSubscription?.cancel();
    for (final s in _museSubscriptions) {
      s.cancel();
    }
    _manager.stopListening();
    _muse?.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final status = _status;
    return Scaffold(
      appBar: AppBar(title: Text('Muse ${status?.libmuseVersion?.string ?? ''}')),
      body: status == null
          ? const Center(child: CircularProgressIndicator())
          : !status.nativeLibraryLoaded
              ? Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('The Muse SDK native library is missing.\n\n'
                      'Copy libmuse_android.so into the plugin\'s android/src/main/jniLibs/<abi>/ '
                      'directories (see README).\n\n${status.error}'),
                )
              : ListView(padding: const EdgeInsets.all(16), children: _muse == null ? _scanView() : _museView()),
    );
  }

  List<Widget> _scanView() => [
        FilledButton.icon(
          onPressed: _toggleScan,
          icon: Icon(_scanning ? Icons.stop : Icons.bluetooth_searching),
          label: Text(_scanning ? 'Stop scanning' : 'Scan for headbands'),
        ),
        const SizedBox(height: 8),
        for (final muse in _muses)
          ListTile(
            title: Text(muse.name ?? muse.id),
            subtitle: Text('${muse.model?.name ?? ''}  ${muse.macAddress ?? ''}  RSSI ${muse.info?.rssi?.round()}'),
            trailing: const Icon(Icons.link),
            onTap: () => _connect(muse),
          ),
        if (_recordingPath != null) ...[
          const Divider(),
          OutlinedButton(onPressed: _summarizeRecording, child: const Text('Summarize last recording')),
          OutlinedButton(onPressed: _playBack, child: const Text('Play back last recording')),
        ],
        ..._logView(),
      ];

  List<Widget> _museView() {
    String fmt(Map<Eeg, double> m) =>
        m.entries.where((e) => !e.value.isNaN).map((e) => '${e.key.name}: ${e.value.toStringAsFixed(2)}').join('\n');
    final artifact = _artifact;
    return [
      Text('${_muse!.name}  -  ${_state.name}', style: Theme.of(context).textTheme.titleLarge),
      if (_version != null) Text('Firmware ${_version!.firmwareVersion} (${_version!.firmwareType})'),
      if (_configuration != null) Text('Preset ${_configuration!.preset?.name}, ${_configuration!.eegChannelCount} channels'),
      if (_battery != null) Text('Battery ${_battery!.toStringAsFixed(0)}%'),
      if (artifact != null)
        Text('Headband on: ${artifact.headbandOn}  Blink: ${artifact.blink}  Jaw clench: ${artifact.jawClench}'),
      const SizedBox(height: 12),
      Text('EEG (µV), $_eegPackets packets', style: Theme.of(context).textTheme.titleMedium),
      Text(fmt(_eeg)),
      const SizedBox(height: 12),
      Text('Alpha absolute (Bels)', style: Theme.of(context).textTheme.titleMedium),
      Text(fmt(_alpha)),
      const SizedBox(height: 12),
      Wrap(spacing: 8, children: [
        FilledButton(
          onPressed: _state == MuseConnectionState.connected ? (_writer == null ? _startRecording : _stopRecording) : null,
          child: Text(_writer == null ? 'Record' : 'Stop recording'),
        ),
        OutlinedButton(onPressed: _disconnect, child: const Text('Disconnect')),
      ]),
      ..._logView(),
    ];
  }

  List<Widget> _logView() => [
        const Divider(),
        for (final line in _log) Text(line, style: Theme.of(context).textTheme.bodySmall),
      ];
}
