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

  group('GridVideoPicker', () {
    testWidgets('renders with empty default list and add tile present', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          GridVideoPicker(
            defaultVideos: () async => <Map<String, dynamic>>[],
            setVideoUrlFromItem: (item) => item['url'] as String?,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      // Add tile shown when count < maxVideos.
      expect(find.byIcon(Icons.add_circle_outline), findsOneWidget);
    });

    test('alwaysAllowDelete returns true for any item', () {
      expect(GridVideoPicker.alwaysAllowDelete('anything'), isTrue);
      expect(GridVideoPicker.alwaysAllowDelete(null), isTrue);
      expect(GridVideoPicker.alwaysAllowDelete(42), isTrue);
    });

    test('asserts maxVideos > 0', () {
      expect(
        () => GridVideoPicker(
          maxVideos: 0,
          defaultVideos: () async => [],
          setVideoUrlFromItem: (_) => null,
        ),
        throwsAssertionError,
      );
    });
  });
}
