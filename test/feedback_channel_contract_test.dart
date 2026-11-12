import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('screens use the shared root feedback channel only', () {
    final dartFiles = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'));

    for (final file in dartFiles) {
      final normalizedPath = file.path.replaceAll('\\', '/');
      final source = file.readAsStringSync();
      if (source.contains('showSnackBar(')) {
        expect(normalizedPath, 'lib/app/app.dart',
            reason: 'Only RootFeedbackController may create a SnackBar.');
      }
      expect(source.contains('ScaffoldMessenger.of('), isFalse,
          reason: '$normalizedPath must use showAppSnack instead.');
    }

    final feedback = File('lib/shared/widgets/dialogs.dart').readAsStringSync();
    expect(feedback, contains('showRootStatus(message, error: error)'));
  });
}
