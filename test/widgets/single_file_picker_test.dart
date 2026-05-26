import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_pro/media_pro.dart';
import 'package:nylo_support/ny_core.dart';

void main() {
  setUpAll(() {
    Backpack.instance.save('nylo', Nylo());
  });

  Widget wrap(Widget child) => MaterialApp(
        navigatorKey: NyNavigator.instance.router.navigatorKey,
        home: Scaffold(body: SingleChildScrollView(child: child)),
      );

  group('SingleFilePicker constructor smoke tests', () {
    testWidgets('simple() with min required params does not crash',
        (tester) async {
      await tester.pumpWidget(wrap(
        SingleFilePicker.simple(
          setFileUrlFromResponse: (_) => null,
        ),
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('default constructor with builder does not crash',
        (tester) async {
      await tester.pumpWidget(wrap(
        SingleFilePicker(
          builder: (_, __, ___) => const SizedBox.shrink(),
          setFileUrlFromResponse: (_) => null,
        ),
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });

  group('SingleFilePicker assertion guards', () {
    test('custom fileType without allowedExtensions throws AssertionError', () {
      expect(
        () => SingleFilePicker.simple(
          fileType: MediaProFileType.custom,
          setFileUrlFromResponse: (_) => null,
        ),
        throwsAssertionError,
      );
    });

    test('document fileType without allowedExtensions is allowed', () {
      // Document type uses its own default extension list — no assertion.
      expect(
        () => SingleFilePicker.simple(
          fileType: MediaProFileType.document,
          setFileUrlFromResponse: (_) => null,
        ),
        returnsNormally,
      );
    });
  });
}
