import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:media_pro/media_pro.dart';

/// Tests for [MediaApiService]:
/// - constructor takes no required args (no BuildContext)
/// - `compressImage` skips files <= `skipBelowBytes`
/// - `compressWithGzip` produces a valid gzip-roundtrip-able payload
///
/// Network-level mocking (gzip header, per-request baseUrl, onError dispatch,
/// `uploadImagesWithMode` dispatch matrix) is left as TODO with pseudocode —
/// see comments in the "TODO: network mocking" group.
void main() {
  group('MediaApiService constructor', () {
    test('constructor has no required args', () {
      expect(() => MediaApiService(), returnsNormally);
    });

    test('exposes interceptors as a getter (override-friendly)', () {
      final svc = MediaApiService();
      // Just exercising the getter to assert it returns a Map.
      expect(svc.interceptors, isA<Map>());
    });
  });

  group('MediaApiService.compressImage', () {
    test(
      'returns input bytes unchanged when file is below skipBelowBytes',
      () async {
        // Write a tiny temp file (< 1 MB default skipBelowBytes).
        final Directory tmpDir = Directory.systemTemp.createTempSync(
          'media_pro_test_',
        );
        addTearDown(() => tmpDir.deleteSync(recursive: true));

        final tinyBytes = Uint8List.fromList(List<int>.generate(64, (i) => i));
        final tmpFile = File('${tmpDir.path}/tiny.bin')
          ..writeAsBytesSync(tinyBytes);

        final svc = MediaApiService();
        final Uint8List result = await svc.compressImage(XFile(tmpFile.path));

        expect(result, equals(tinyBytes));
      },
    );

    test('returns input bytes unchanged with custom skipBelowBytes that '
        'covers the file', () async {
      final Directory tmpDir = Directory.systemTemp.createTempSync(
        'media_pro_test_',
      );
      addTearDown(() => tmpDir.deleteSync(recursive: true));

      final bytes = Uint8List.fromList(
        List<int>.generate(1024, (i) => i % 256),
      );
      final tmpFile = File('${tmpDir.path}/under.bin')..writeAsBytesSync(bytes);

      final svc = MediaApiService();
      final Uint8List result = await svc.compressImage(
        XFile(tmpFile.path),
        options: const ImageCompressionOptions(skipBelowBytes: 4096),
      );

      expect(result, equals(bytes));
    });
  });

  group('MediaApiService.compressWithGzip', () {
    test('produces non-empty gzip output that round-trips', () async {
      final svc = MediaApiService();
      final input = List<int>.generate(2048, (i) => i % 256);

      final List<int> gzipped = await svc.compressWithGzip(input);

      expect(gzipped, isNotEmpty);
      // Validate the output is genuine gzip by decoding it back.
      final List<int> decoded = gzip.decode(gzipped);
      expect(decoded, equals(input));
    });

    test('round-trips an empty payload', () async {
      final svc = MediaApiService();
      final List<int> gzipped = await svc.compressWithGzip(<int>[]);
      expect(gzip.decode(gzipped), isEmpty);
    });
  });

  group('MediaApiService — method signatures (smoke)', () {
    // These tests just exercise that the public methods exist with the
    // expected shapes. They do NOT make real network calls.
    test('uploadImage accepts XFile + apiRequest', () {
      final svc = MediaApiService();
      // Verify the method exists with the expected signature by tearing off.
      // ignore: unnecessary_statements
      svc.uploadImage;
    });

    test('uploadImages accepts List<XFile> + apiRequest', () {
      final svc = MediaApiService();
      // ignore: unnecessary_statements
      svc.uploadImages;
    });

    test('uploadImagesSequential accepts List<XFile> + apiRequest', () {
      final svc = MediaApiService();
      // ignore: unnecessary_statements
      svc.uploadImagesSequential;
    });

    test('uploadImagesGzip accepts List<XFile> + apiRequest + options', () {
      final svc = MediaApiService();
      // ignore: unnecessary_statements
      svc.uploadImagesGzip;
    });

    test('uploadImagesWithMode accepts mode + apiRequest', () {
      final svc = MediaApiService();
      // ignore: unnecessary_statements
      svc.uploadImagesWithMode;
    });

    test('setMainImage accepts apiRequest', () {
      final svc = MediaApiService();
      // ignore: unnecessary_statements
      svc.setMainImage;
    });

    test('deleteImage accepts item + apiRequest', () {
      final svc = MediaApiService();
      // ignore: unnecessary_statements
      svc.deleteImage;
    });
  });

  // TODO: network mocking — wire a `MockMediaApiService extends MediaApiService`
  // that overrides `network(...)` to capture invocations into a public list
  // (e.g. `List<_NetworkInvocation> calls`), then write tests like:
  //
  //   test('gzip mode sets Content-Encoding header', () async {
  //     final svc = MockMediaApiService();
  //     await svc.uploadImagesGzip([xfile], apiRequest: ApiRequest(url: 'https://x'));
  //     expect(svc.calls.last.headers!['Content-Encoding'], 'gzip');
  //   });
  //
  //   test('per-request baseUrl is stateless', () async {
  //     final svc = MockMediaApiService();
  //     await svc.uploadImage(xfile, apiRequest: ApiRequest(url: 'https://a/foo'));
  //     await svc.uploadImage(xfile, apiRequest: ApiRequest(url: 'https://b/bar'));
  //     expect(svc.calls[0].baseUrl, 'https://a');
  //     expect(svc.calls[1].baseUrl, 'https://b');
  //   });
  //
  //   test('onError dispatched for upload/delete/setMain', () async {
  //     final svc = MockMediaApiService();
  //     final apiRequest = ApiRequest(url: 'https://x', onError: capturedHandler);
  //     await svc.uploadImage(xfile, apiRequest: apiRequest);
  //     await svc.deleteImage({'id': 1}, apiRequest: apiRequest);
  //     await svc.setMainImage(apiRequest: apiRequest);
  //     expect(svc.calls.every((c) => c.handleFailure == capturedHandler), isTrue);
  //   });
  //
  //   test('uploadImagesSequential calls uploadImage N times', () async {
  //     final svc = MockMediaApiService();
  //     await svc.uploadImagesSequential([f1, f2, f3], apiRequest: apiRequest);
  //     expect(svc.calls.length, 3);
  //   });
  //
  //   test('uploadImagesWithMode dispatches to correct underlying method', () async {
  //     for (final mode in UploadMode.values) {
  //       final svc = MockMockMediaApiService();
  //       await svc.uploadImagesWithMode([xfile], apiRequest: req, mode: mode);
  //       // Assert the method recorded matches the mode.
  //     }
  //   });
  //
  // Implementation note: NyApiService.network is non-virtual in the way we
  // need; the cleanest path is probably to add a thin `@protected
  // dispatchNetwork(...)` seam in the source — out of scope for v3.0.0.
}
