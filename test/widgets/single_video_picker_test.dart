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

  group('SingleVideoPicker constructor smoke tests', () {
    testWidgets('compact() with min required params does not crash',
        (tester) async {
      await tester.pumpWidget(wrap(
        SingleVideoPicker.compact(
          setVideoUrlFromResponse: (_) => null,
        ),
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('simple() with min required params does not crash',
        (tester) async {
      await tester.pumpWidget(wrap(
        SingleVideoPicker.simple(
          setVideoUrlFromResponse: (_) => null,
        ),
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('default constructor with child builder does not crash',
        (tester) async {
      await tester.pumpWidget(wrap(
        SingleVideoPicker(
          child: (_, __) => const SizedBox.shrink(),
          setVideoUrlFromResponse: (_) => null,
        ),
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });

  group('SingleVideoPicker style hierarchy', () {
    test('compact() instantiates CompactVideoPickerStyle', () {
      final picker = SingleVideoPicker.compact(
        setVideoUrlFromResponse: (_) => null,
      );
      expect(picker.style, isA<CompactVideoPickerStyle>());
    });

    test('simple() instantiates SimpleVideoPickerStyle', () {
      final picker = SingleVideoPicker.simple(
        setVideoUrlFromResponse: (_) => null,
      );
      expect(picker.style, isA<SimpleVideoPickerStyle>());
    });

    test('default constructor instantiates CustomVideoPickerStyle', () {
      final picker = SingleVideoPicker(
        child: (_, __) => const SizedBox.shrink(),
        setVideoUrlFromResponse: (_) => null,
      );
      expect(picker.style, isA<CustomVideoPickerStyle>());
    });
  });
}
