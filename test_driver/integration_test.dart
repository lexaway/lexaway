import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() async {
  await integrationDriver(
    onScreenshot: (String name, List<int> image, [Map<String, Object?>? args]) async {
      final currentDirectory = Directory.current;
      final directory = Directory('${currentDirectory.path}/screenshots/');
      final exists = await directory.exists();

      if (!exists) {
        await directory.create(recursive: true);
      }

      final file = File('${directory.path}/$name.png');

      await file.writeAsBytes(image);

      return true;
    },
  );
}
