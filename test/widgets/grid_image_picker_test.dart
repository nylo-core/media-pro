import 'package:flutter/material.dart';
import 'package:flutter_draggable_gridview/flutter_draggable_gridview.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_pro/widgets/grid_image_picker_widget.dart';
import 'package:media_pro/widgets/upload_image_tile.dart';
import 'package:nylo_support/ny_core.dart';

/// Tests for [GridImagePicker]:
/// - `displayValidationHint: false` hides the bottom hint
/// - default id resolver handles Map shape (covered indirectly via render)
/// - smoke test: rendering 3 default Map items finds 3 `UploadImageTile`s
///
/// Skipped (TODO with pseudocode): drag completion, delete-button gating,
/// `onUploadImages` bypass, confirmation title, builder overrides — these
/// require either tapping into private state or driving the
/// `flutter_draggable_gridview` callbacks programmatically. See comments
/// at the bottom of this file.
void main() {
  // GridImagePicker uses Nylo's `match()` helper and `Text.bodySmall()`
  // extension which both depend on `Nylo.instance` and
  // `NyNavigator.instance.router.navigatorKey?.currentContext`. Wire those
  // up before any test pumps the widget.
  setUpAll(() {
    Backpack.instance.save('nylo', Nylo());
  });

  Widget wrap(Widget child) => MaterialApp(
        // Reuse Nylo's navigator key so `Text.bodySmall()` (and other
        // extensions that look up `_context`) resolve properly in tests.
        navigatorKey: NyNavigator.instance.router.navigatorKey,
        home: Scaffold(
          body: SizedBox(
            // Give the grid a finite size so layout works in tests.
            height: 800,
            width: 400,
            child: child,
          ),
        ),
      );

  group('GridImagePicker constructor smoke tests', () {
    testWidgets(
        'constructor with min required params + apiUploadImage: null '
        'does not crash', (tester) async {
      await tester.pumpWidget(wrap(
        GridImagePicker(
          defaultImages: () async => [],
          setImageUrlFromItem: (_) => null,
        ),
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });

  group('GridImagePicker.alwaysAllowDelete', () {
    test('returns true for any item (Map shape)', () {
      expect(GridImagePicker.alwaysAllowDelete({'id': 1}), isTrue);
    });

    test('returns true for any item (model shape)', () {
      expect(GridImagePicker.alwaysAllowDelete(_FakeItem('abc')), isTrue);
    });

    test('returns true for null', () {
      expect(GridImagePicker.alwaysAllowDelete(null), isTrue);
    });
  });

  group('GridImagePicker validation hint', () {
    testWidgets('displayValidationHint: false hides the bottom hint',
        (tester) async {
      await tester.pumpWidget(wrap(
        GridImagePicker(
          defaultImages: () async => [
            {'id': 1, 'url': 'https://example.test/a.jpg'},
          ],
          setImageUrlFromItem: (i) => i['url'] as String?,
          displayValidationHint: false,
        ),
      ));
      await tester.pumpAndSettle();

      // The hint contains "You can upload up to" — assert it is NOT in tree.
      expect(find.textContaining('You can upload up to'), findsNothing);
    });

    testWidgets('displayValidationHint: true shows the bottom hint',
        (tester) async {
      await tester.pumpWidget(wrap(
        GridImagePicker(
          defaultImages: () async => [
            {'id': 1, 'url': 'https://example.test/a.jpg'},
          ],
          setImageUrlFromItem: (i) => i['url'] as String?,
          displayValidationHint: true,
        ),
      ));
      await tester.pumpAndSettle();

      // Default maxImages = 11.
      expect(
        find.textContaining('You can upload up to'),
        findsAtLeastNWidgets(1),
      );
    });
  });

  group('GridImagePicker default items rendering', () {
    testWidgets(
        'pumps with 3 default Map items and finds at least 3 UploadImageTile '
        'widgets', (tester) async {
      await tester.pumpWidget(wrap(
        GridImagePicker(
          defaultImages: () async => [
            {'id': 1, 'url': 'https://example.test/a.jpg'},
            {'id': 2, 'url': 'https://example.test/b.jpg'},
            {'id': 3, 'url': 'https://example.test/c.jpg'},
          ],
          setImageUrlFromItem: (i) => i['url'] as String?,
        ),
      ));
      await tester.pumpAndSettle();

      // Each item slot (and each empty slot up to maxImages) is an
      // UploadImageTile, so the assertion is "at least 3" — proves the
      // default Map+'id' resolver path didn't throw.
      expect(find.byType(UploadImageTile), findsAtLeastNWidgets(3));
    });
  });

  // Regression tests for the bug where `view()` called `_default()` with no
  // args, silently overriding `widget.height` and `widget.placeholder` with
  // `_default`'s own parameter defaults. Causes shrunken tiles and missing
  // placeholders in empty slots when the caller passes explicit values.
  group('GridImagePicker layout propagation', () {
    testWidgets('widget.height flows into the grid delegate childAspectRatio',
        (tester) async {
      const explicitHeight = 600.0;
      const mqWidth = 400.0;

      // The default test surface (800x600) is too small for the rendered
      // grid (4 rows * ~200px cell height + validation hint) and would
      // trigger a RenderFlex overflow during pump. Resize so the layout
      // fits while leaving MediaQuery.of(context).size.width = mqWidth.
      tester.view.physicalSize = const Size(mqWidth, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(MaterialApp(
        navigatorKey: NyNavigator.instance.router.navigatorKey,
        home: Scaffold(
          body: MediaQuery(
            data: const MediaQueryData(size: Size(mqWidth, 800)),
            child: GridImagePicker(
              defaultImages: () async => [],
              setImageUrlFromItem: (_) => null,
              height: explicitHeight,
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      final builder = tester.widget<DraggableGridViewBuilder>(
        find.byType(DraggableGridViewBuilder),
      );
      final delegate =
          builder.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
      expect(delegate.crossAxisCount, 3);
      expect(delegate.childAspectRatio, mqWidth / explicitHeight);
    });

    testWidgets(
        'widget.placeholder is rendered inside empty UploadImageTile slots',
        (tester) async {
      const placeholderText = '__test_placeholder_marker__';

      await tester.pumpWidget(wrap(
        GridImagePicker(
          defaultImages: () async => [],
          setImageUrlFromItem: (_) => null,
          maxImages: 3,
          placeholder: const Text(placeholderText),
        ),
      ));
      await tester.pumpAndSettle();

      // With maxImages=3 and no default images, every grid slot beyond the
      // upload trigger is an empty UploadImageTile, which renders the
      // caller-supplied placeholder.
      expect(find.text(placeholderText), findsAtLeastNWidgets(1));
    });
  });

  // -----
  // The following tests are documented as TODO. They each require either
  // exercising the private `_GridImagePickerState`, mocking the underlying
  // `flutter_draggable_gridview` callbacks, or stubbing
  // `MediaApiService` (see `test/networking/media_api_service_test.dart`
  // for the `MockMediaApiService` plan).
  //
  // TODO: itemIdResolver fallback chain — construct a state directly via
  //   `_GridImagePickerState()`, call `_resolveId(...)` with: a Map with
  //   'id', a model with id getter, and a plain Object — assert that the
  //   third throws StateError with the helpful message. Currently
  //   `_GridImagePickerState` is private; the cleanest fix is to extract
  //   `_resolveId` into a package-private top-level function and test it
  //   directly. Out of scope for v3.0.0.
  //
  // TODO: drag completion emits new id order — programmatically invoke the
  //   `dragCompletion` callback handed to `DraggableGridViewBuilder` and
  //   assert that `widget.onDragCompletion` fires with the new ID list
  //   (resolved via `_resolveId`). Requires reaching into the widget tree
  //   to find the `DraggableGridViewBuilder` and triggering its callback.
  //
  // TODO: delete button gated per-item — pump the grid with two items,
  //   `canDeleteImage: (i) => i['id'] != 1`, and assert the IconButton
  //   with `Icons.delete_forever` appears for item 2 but not item 1.
  //   Requires asserting per-tile button presence — fragile against
  //   layout changes.
  //
  // TODO: onUploadImages bypasses internal service — pump the grid with
  //   `onUploadImages: (images) async { captured = images; return null; }`,
  //   programmatically trigger `_uploadNewImages([fakeXFile])`, then assert
  //   `captured == [fakeXFile]` and that no `MediaApiService` call was
  //   recorded (requires the MockMediaApiService from media_api_service_test).
  //
  // TODO: delete confirmation uses provided title — pump with
  //   `deleteConfirmationTitle: "Custom?"`, tap the delete IconButton,
  //   `pumpAndSettle()`, assert `find.text("Custom?")` finds the dialog title.
  //   Currently confirmAction wraps a Nylo dialog — confirm the dialog
  //   actually exposes the title in its widget tree.
  //
  // TODO: pendingTileBuilder / loadingPlaceholderBuilder /
  //   newItemAnimationBuilder are honored — each requires either driving
  //   `_pendingImages` non-empty (during an upload), `isLocked('uploading_image')`
  //   true, or `_newItemIds` non-empty after `_resetItems`. All three are
  //   private state. Suggest exposing test seams via `@visibleForTesting`
  //   in a future task.
}

class _FakeItem {
  _FakeItem(this.id);
  final String id;
}
