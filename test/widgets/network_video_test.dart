import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_pro/media_pro.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(
        home: Scaffold(body: child),
      );

  testWidgets('NetworkVideo renders without crashing', (tester) async {
    await tester.pumpWidget(wrap(
      NetworkVideo(
        url: 'https://example.com/video.mp4',
        adapterFactory: () => _NoopVideoAdapter(),
      ),
    ));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('NetworkVideo shows play overlay when not yet initialized',
      (tester) async {
    await tester.pumpWidget(wrap(
      NetworkVideo(
        url: 'https://example.com/video.mp4',
        adapterFactory: () => _NoopVideoAdapter(),
      ),
    ));
    await tester.pumpAndSettle();
    // Default play overlay uses Icons.play_circle_fill.
    expect(find.byIcon(Icons.play_circle_fill), findsOneWidget);
  });

  testWidgets('autoPlay triggers initialization on initState', (tester) async {
    final adapter = _NoopVideoAdapter();
    await tester.pumpWidget(wrap(
      NetworkVideo(
        url: 'https://example.com/video.mp4',
        adapterFactory: () => adapter,
        autoPlay: true,
      ),
    ));
    // Pump enough for initialize() to be called (the factory hands back the
    // same instance for inspection).
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 10));
    expect(adapter.initializeCalls, ['https://example.com/video.mp4']);
  });
}

class _NoopVideoAdapter implements VideoPlayerAdapter {
  final initializeCalls = <String>[];

  final _position = StreamController<Duration>.broadcast();
  final _duration = StreamController<Duration?>.broadcast();
  final _playing = StreamController<bool>.broadcast();
  final _initialized = StreamController<bool>.broadcast();

  @override
  double? get aspectRatio => 16 / 9;

  @override
  Future<void> initialize(String source) async {
    initializeCalls.add(source);
  }

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
    await _initialized.close();
  }

  @override
  Widget buildView() => const SizedBox.shrink();

  @override
  Stream<Duration> get positionStream => _position.stream;
  @override
  Stream<Duration?> get durationStream => _duration.stream;
  @override
  Stream<bool> get playingStream => _playing.stream;
  @override
  Stream<bool> get initializedStream => _initialized.stream;
}
