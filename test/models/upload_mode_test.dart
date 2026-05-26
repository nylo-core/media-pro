import 'package:flutter_test/flutter_test.dart';
import 'package:media_pro/models/upload_mode.dart';

/// Tests for [UploadMode] — verifies the enum stays at exactly 3 values
/// (any addition is a breaking change for `uploadImagesWithMode`).
void main() {
  group('UploadMode enum', () {
    test('enum has 3 values', () {
      expect(UploadMode.values.length, 3);
    });

    test('enum values are exactly standard, sequential, gzip', () {
      expect(UploadMode.values, [
        UploadMode.standard,
        UploadMode.sequential,
        UploadMode.gzip,
      ]);
    });

    test('UploadMode.standard.name returns "standard"', () {
      expect(UploadMode.standard.name, 'standard');
    });

    test('UploadMode.sequential.name returns "sequential"', () {
      expect(UploadMode.sequential.name, 'sequential');
    });

    test('UploadMode.gzip.name returns "gzip"', () {
      expect(UploadMode.gzip.name, 'gzip');
    });
  });
}
