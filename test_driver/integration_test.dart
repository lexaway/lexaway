import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() async {
  final deviceName =
      Platform.environment['SCREENSHOT_DEVICE_NAME'] ?? 'default';
  final lang = Platform.environment['SCREENSHOT_LANG'] ?? 'en';

  await integrationDriver(
    onScreenshot: (String name, List<int> image, [Map<String, Object?>? args]) async {
      final directory = Directory(
        '${Directory.current.path}/screenshots/raw/$lang/$deviceName/',
      );
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }

      final file = File('${directory.path}/$name.png');
      await file.writeAsBytes(image);
      return true;
    },
  );
}
