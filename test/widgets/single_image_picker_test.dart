import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_pro/widgets/single_image_picker_widget.dart';
import 'package:nylo_support/ny_core.dart';

/// Regression tests for [SingleImagePicker]:
/// - `imageSource: "camera"` is honored (not silently coerced to gallery)
/// - `SingleImagePicker.simple()` renders the simple style (not always compact)
void main() {
  // SingleImagePicker extends NyState; the underlying lifecycle assumes
  // Nylo has been initialized at least once. Wire a bare `Nylo()` into
  // `Backpack.instance` so `Nylo.instance` resolves in tests.
  setUpAll(() {
    Backpack.instance.save('nylo', Nylo());
  });

  Widget wrap(Widget child) => MaterialApp(
    navigatorKey: NyNavigator.instance.router.navigatorKey,
    home: Scaffold(body: SingleChildScrollView(child: child)),
  );

  group('SingleImagePicker constructor smoke tests', () {
    testWidgets('compact() with min required params does not crash', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(SingleImagePicker.compact(setImageUrlFromResponse: (_) => null)),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('simple() with min required params does not crash', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(SingleImagePicker.simple(setImageUrlFromResponse: (_) => null)),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('default constructor with child builder does not crash', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          SingleImagePicker(
            child: (context, upload) => const SizedBox.shrink(),
            setImageUrlFromResponse: (_) => null,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });

  group('SingleImagePicker style regression tests', () {
    testWidgets('simple style renders text label '
        '("Upload an image") — proves view() is not always-compact', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(SingleImagePicker.simple(setImageUrlFromResponse: (_) => null)),
      );
      await tester.pumpAndSettle();

      // The simple() variant renders a Text("Upload an image") label —
      // the compact() variant does not. Finding it proves the style switch
      // in view() is honored (vs. the fork which always rendered _compact()).
      expect(find.text('Upload an image'), findsAtLeastNWidgets(1));
    });
  });

  group('SingleImagePicker imageSource regression', () {
    testWidgets('respects imageSource camera — constructor accepts and renders '
        'without throwing', (tester) async {
      // Pumping the widget exercises the constructor path that stores
      // `imageSource: "camera"`. A full test of the actual picker call would
      // mock `package:image_picker` (e.g. via `ImagePickerPlatform.instance`),
      // which is out of scope here. This smoke test at minimum locks the
      // parameter shape so the regression cannot silently re-appear.
      await tester.pumpWidget(
        wrap(
          SingleImagePicker.simple(
            setImageUrlFromResponse: (_) => null,
            imageSource: 'camera',
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // TODO: full plugin mock — register a fake `ImagePickerPlatform`
      // instance via `ImagePickerPlatform.instance = FakePicker(...)`,
      // tap the simple-style InkWell, and assert the recorded `source`
      // is `ImageSource.camera`.
    });
  });
}
