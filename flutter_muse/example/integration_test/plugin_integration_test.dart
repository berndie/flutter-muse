// Runs on a device: flutter test integration_test (from example/).
// Needs the Muse SDK native library in the plugin's jniLibs, but no headband.
import 'package:flutter_muse/flutter_muse.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('SDK loads and reports its version', (tester) async {
    final status = await FlutterMuse.initialize();
    expect(status.nativeLibraryLoaded, isTrue, reason: status.error);
    expect(status.libmuseVersion!.string, isNotEmpty);
    expect(await FlutterMuse.stringifyPacketType(MuseDataPacketType.eeg), isNotEmpty);
    expect(await MuseManager.instance.museUuid(), isNotEmpty);
  });
}
