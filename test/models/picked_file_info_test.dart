import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:media_pro/media_pro.dart';

/// Tests for [PickedFileInfo] factory constructors. Focuses on the
/// extension/name parsing logic, since size is read from the filesystem.
void main() {
  late File tempFile;

  setUp(() async {
    tempFile = await File(
            '${Directory.systemTemp.path}/picked_file_info_test_${DateTime.now().microsecondsSinceEpoch}.dat')
        .create();
    await tempFile.writeAsBytes([1, 2, 3, 4, 5]);
  });

  tearDown(() {
    if (tempFile.existsSync()) tempFile.deleteSync();
  });

  group('PickedFileInfo.fromPath', () {
    test('extracts name from path when not supplied', () {
      final info = PickedFileInfo.fromPath(tempFile.path);
      expect(info.name, tempFile.uri.pathSegments.last);
      expect(info.path, tempFile.path);
    });

    test('honors explicit name argument', () {
      final info =
          PickedFileInfo.fromPath(tempFile.path, name: 'custom-name.bin');
      expect(info.name, 'custom-name.bin');
      expect(info.extension, 'bin');
    });

    test('reads sizeBytes from the underlying file', () {
      final info = PickedFileInfo.fromPath(tempFile.path);
      expect(info.sizeBytes, 5);
    });

    test('parses extension from filename', () {
      final f = File('${Directory.systemTemp.path}/picked_test_voice.m4a')
        ..createSync()
        ..writeAsBytesSync([0]);
      try {
        final info = PickedFileInfo.fromPath(f.path);
        expect(info.extension, 'm4a');
      } finally {
        f.deleteSync();
      }
    });

    test('extension is null when filename has no dot', () {
      final f = File('${Directory.systemTemp.path}/picked_test_noext')
        ..createSync()
        ..writeAsBytesSync([0]);
      try {
        final info = PickedFileInfo.fromPath(f.path);
        expect(info.extension, isNull);
      } finally {
        f.deleteSync();
      }
    });

    test('extension is null when filename ends with a dot', () {
      final f = File('${Directory.systemTemp.path}/picked_test_trail.')
        ..createSync()
        ..writeAsBytesSync([0]);
      try {
        final info = PickedFileInfo.fromPath(f.path);
        expect(info.extension, isNull);
      } finally {
        f.deleteSync();
      }
    });

    test('mimeType is forwarded when supplied', () {
      final info = PickedFileInfo.fromPath(tempFile.path,
          mimeType: 'application/octet-stream');
      expect(info.mimeType, 'application/octet-stream');
    });
  });

  group('PickedFileInfo.fromXFile', () {
    test('wraps an XFile, reading length and parsing extension', () {
      final f = File('${Directory.systemTemp.path}/picked_xfile_test.png')
        ..createSync()
        ..writeAsBytesSync([0xff, 0xd8, 0xff]);
      try {
        final xfile = XFile(f.path);
        final info = PickedFileInfo.fromXFile(xfile, mimeType: 'image/png');
        expect(info.path, f.path);
        expect(info.extension, 'png');
        expect(info.sizeBytes, 3);
        expect(info.mimeType, 'image/png');
      } finally {
        f.deleteSync();
      }
    });
  });
}
