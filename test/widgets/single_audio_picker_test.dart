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

  group('SingleAudioPicker constructor smoke tests', () {
    testWidgets('simple() with min required params does not crash', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(SingleAudioPicker.simple(setAudioUrlFromResponse: (_) => null)),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('default constructor with child builder does not crash', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          SingleAudioPicker(
            child: (_, _) => const SizedBox.shrink(),
            setAudioUrlFromResponse: (_) => null,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });

  group('SingleAudioPicker style hierarchy', () {
    test('simple() instantiates SimpleAudioPickerStyle', () {
      final picker = SingleAudioPicker.simple(
        setAudioUrlFromResponse: (_) => null,
      );
      expect(picker.style, isA<SimpleAudioPickerStyle>());
    });

    test('default constructor instantiates CustomAudioPickerStyle', () {
      final picker = SingleAudioPicker(
        child: (_, _) => const SizedBox.shrink(),
        setAudioUrlFromResponse: (_) => null,
      );
      expect(picker.style, isA<CustomAudioPickerStyle>());
    });
  });
}
