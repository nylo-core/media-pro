import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_pro/media_pro.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  testWidgets('AudioMessageTile renders without crashing and shows play icon', (
    tester,
  ) async {
    final controller = AudioMessageController(_NoopAdapter());
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      wrap(
        AudioMessageTile(
          source: 'a',
          controller: controller,
          duration: const Duration(seconds: 10),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byIcon(Icons.play_arrow), findsOneWidget);
  });

  testWidgets('AudioMessageTile shows pause icon when playing', (tester) async {
    final adapter = _NoopAdapter();
    final controller = AudioMessageController(adapter);
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      wrap(
        AudioMessageTile(
          source: 'a',
          controller: controller,
          duration: const Duration(seconds: 10),
        ),
      ),
    );
    await controller.playSource('a');
    adapter.emitPlaying(true);
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.pause), findsOneWidget);
  });

  testWidgets('Slider is disabled (onChanged null) for non-active source', (
    tester,
  ) async {
    final controller = AudioMessageController(_NoopAdapter());
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      wrap(
        AudioMessageTile(
          source: 'inactive',
          controller: controller,
          duration: const Duration(seconds: 10),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final Slider slider = tester.widget<Slider>(find.byType(Slider));
    expect(slider.onChanged, isNull);
  });
}

class _NoopAdapter implements AudioPlayerAdapter {
  final _position = StreamController<Duration>.broadcast();
  final _duration = StreamController<Duration?>.broadcast();
  final _playing = StreamController<bool>.broadcast();

  void emitPlaying(bool p) => _playing.add(p);

  @override
  Future<void> load(String source) async {}
  @override
  Future<void> play() async {}
  @override
  Future<void> pause() async {}
  @override
  Future<void> seek(Duration position) async {}
  @override
  Future<void> dispose() async {
    await _position.close();
    await _duration.close();
    await _playing.close();
  }

  @override
  Stream<Duration> get positionStream => _position.stream;
  @override
  Stream<Duration?> get durationStream => _duration.stream;
  @override
  Stream<bool> get playingStream => _playing.stream;
}
