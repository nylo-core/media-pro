import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_pro/media_pro.dart';

/// Tests for [AudioMessageController] — the one-playing-at-a-time
/// coordinator wrapped around an [AudioPlayerAdapter].
///
/// Uses a stub adapter that records load/play/pause/seek calls and
/// re-emits state through controllable streams.
void main() {
  group('AudioMessageController', () {
    late _StubAdapter adapter;
    late AudioMessageController controller;

    setUp(() {
      adapter = _StubAdapter();
      controller = AudioMessageController(adapter);
    });

    tearDown(() {
      controller.dispose();
    });

    test('initial state has no active source and is not playing', () {
      expect(controller.activeSource, isNull);
      expect(controller.isPlaying, isFalse);
      expect(controller.position, Duration.zero);
      expect(controller.duration, isNull);
    });

    test('isActive returns false for any source initially', () {
      expect(controller.isActive('a'), isFalse);
      expect(controller.isActive('b'), isFalse);
    });

    test('playSource loads adapter and marks source active', () async {
      await controller.playSource('a');
      expect(adapter.loadCalls, ['a']);
      expect(adapter.playCount, 1);
      expect(controller.activeSource, 'a');
      expect(controller.isActive('a'), isTrue);
    });

    test('playSource on same source skips load but still calls play', () async {
      await controller.playSource('a');
      await controller.playSource('a');
      expect(adapter.loadCalls, ['a']); // still just one load
      expect(adapter.playCount, 2); // play called twice
    });

    test(
      'playSource on different source loads new and switches active',
      () async {
        await controller.playSource('a');
        await controller.playSource('b');
        expect(adapter.loadCalls, ['a', 'b']);
        expect(controller.activeSource, 'b');
        expect(controller.isActive('a'), isFalse);
        expect(controller.isActive('b'), isTrue);
      },
    );

    test('switching source resets position to zero', () async {
      await controller.playSource('a');
      adapter.emitPosition(const Duration(seconds: 5));
      await Future<void>.delayed(Duration.zero);
      expect(controller.position, const Duration(seconds: 5));

      await controller.playSource('b');
      // Position resets when switching sources
      expect(controller.position, Duration.zero);
    });

    test('pauseSource only pauses when source is active', () async {
      await controller.playSource('a');
      await controller.pauseSource('b'); // not active — no-op
      expect(adapter.pauseCount, 0);

      await controller.pauseSource('a');
      expect(adapter.pauseCount, 1);
    });

    test('toggleSource plays when not playing, pauses when playing', () async {
      await controller.toggleSource('a');
      expect(adapter.playCount, 1);

      adapter.emitPlaying(true);
      await Future<void>.delayed(Duration.zero);
      await controller.toggleSource('a');
      expect(adapter.pauseCount, 1);
    });

    test('toggleSource on inactive source switches to it and plays', () async {
      await controller.playSource('a');
      adapter.emitPlaying(true);
      await Future<void>.delayed(Duration.zero);

      // 'b' is not active — toggle should load and play it
      await controller.toggleSource('b');
      expect(adapter.loadCalls, ['a', 'b']);
      expect(controller.activeSource, 'b');
    });

    test(
      'isPlayingSource is true only for the active + playing source',
      () async {
        await controller.playSource('a');
        adapter.emitPlaying(true);
        await Future<void>.delayed(Duration.zero);

        expect(controller.isPlayingSource('a'), isTrue);
        expect(controller.isPlayingSource('b'), isFalse);

        adapter.emitPlaying(false);
        await Future<void>.delayed(Duration.zero);
        expect(controller.isPlayingSource('a'), isFalse);
      },
    );

    test('seek is a no-op when no source is active', () async {
      await controller.seek(const Duration(seconds: 5));
      expect(adapter.seekCalls, isEmpty);
    });

    test('seek forwards to adapter when a source is active', () async {
      await controller.playSource('a');
      await controller.seek(const Duration(seconds: 5));
      expect(adapter.seekCalls, [const Duration(seconds: 5)]);
    });

    test(
      'position stream updates the controller and notifies listeners',
      () async {
        await controller.playSource('a');

        var notifications = 0;
        controller.addListener(() => notifications++);

        adapter.emitPosition(const Duration(seconds: 3));
        // Stream emissions run on the next microtask — flush before asserting.
        await Future<void>.delayed(Duration.zero);
        expect(controller.position, const Duration(seconds: 3));
        expect(notifications, greaterThanOrEqualTo(1));
      },
    );

    test('duration stream updates the controller', () async {
      await controller.playSource('a');
      adapter.emitDuration(const Duration(seconds: 30));
      await Future<void>.delayed(Duration.zero);
      expect(controller.duration, const Duration(seconds: 30));
    });

    test('dispose cancels subscriptions and disposes adapter', () async {
      // Use a local controller — the shared one is already disposed in
      // tearDown, and ChangeNotifier rejects double-dispose.
      final localAdapter = _StubAdapter();
      final localController = AudioMessageController(localAdapter);
      await localController.playSource('a');
      localController.dispose();
      expect(localAdapter.disposed, isTrue);
    });
  });
}

/// Records calls and exposes manual stream control.
class _StubAdapter implements AudioPlayerAdapter {
  final loadCalls = <String>[];
  final seekCalls = <Duration>[];
  int playCount = 0;
  int pauseCount = 0;
  bool disposed = false;

  final _position = StreamController<Duration>.broadcast();
  final _duration = StreamController<Duration?>.broadcast();
  final _playing = StreamController<bool>.broadcast();

  void emitPosition(Duration p) => _position.add(p);
  void emitDuration(Duration? d) => _duration.add(d);
  void emitPlaying(bool p) => _playing.add(p);

  @override
  Future<void> load(String source) async {
    loadCalls.add(source);
  }

  @override
  Future<void> play() async {
    playCount++;
  }

  @override
  Future<void> pause() async {
    pauseCount++;
  }

  @override
  Future<void> seek(Duration position) async {
    seekCalls.add(position);
  }

  @override
  Future<void> dispose() async {
    disposed = true;
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
