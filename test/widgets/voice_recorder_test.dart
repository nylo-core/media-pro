import 'dart:async';
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
    home: Scaffold(body: child),
  );

  group('VoiceRecorder constructor smoke tests', () {
    testWidgets('hold-to-record idle state renders mic button', (tester) async {
      await tester.pumpWidget(
        wrap(VoiceRecorder(adapterFactory: () => _NoopRecorder())),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byIcon(Icons.mic), findsOneWidget);
    });

    testWidgets('tap-to-record idle state renders mic button', (tester) async {
      await tester.pumpWidget(
        wrap(
          VoiceRecorder(
            mode: RecorderMode.tapToRecord,
            adapterFactory: () => _NoopRecorder(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byIcon(Icons.mic), findsOneWidget);
    });
  });

  group('VoiceRecorder assertion guards', () {
    test('previewBeforeSend without playerFactory throws AssertionError', () {
      expect(
        () => VoiceRecorder(
          adapterFactory: () => _NoopRecorder(),
          previewBeforeSend: true,
        ),
        throwsAssertionError,
      );
    });

    test('previewBeforeSend with playerFactory is allowed', () {
      expect(
        () => VoiceRecorder(
          adapterFactory: () => _NoopRecorder(),
          previewBeforeSend: true,
          playerFactory: () => _NoopPlayer(),
        ),
        returnsNormally,
      );
    });
  });
}

class _NoopRecorder implements AudioRecorderAdapter {
  final _amp = StreamController<double>.broadcast();
  final _dur = StreamController<Duration>.broadcast();
  final _state = StreamController<RecorderState>.broadcast();

  @override
  Future<bool> hasPermission() async => true;
  @override
  Future<bool> requestPermission() async => true;
  @override
  Future<String> start({String? path}) async => path ?? '/tmp/noop.m4a';
  @override
  Future<String?> stop() async => null;
  @override
  Future<void> cancel() async {}
  @override
  Future<void> dispose() async {
    await _amp.close();
    await _dur.close();
    await _state.close();
  }

  @override
  Stream<double> get amplitudeStream => _amp.stream;
  @override
  Stream<Duration> get durationStream => _dur.stream;
  @override
  Stream<RecorderState> get stateStream => _state.stream;
}

class _NoopPlayer implements AudioPlayerAdapter {
  final _position = StreamController<Duration>.broadcast();
  final _duration = StreamController<Duration?>.broadcast();
  final _playing = StreamController<bool>.broadcast();

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
