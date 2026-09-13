import 'dart:async';
import 'package:flutter/material.dart';
import '/adapters/audio_player_adapter.dart';

/// Coordinates one-playing-at-a-time across many [AudioMessageTile] widgets
/// that share a single [AudioPlayerAdapter]. Hold one instance per logical
/// audio context (a chat thread, a podcast list) and pass the same instance
/// to every tile.
class AudioMessageController extends ChangeNotifier {
  final AudioPlayerAdapter adapter;

  String? _activeSource;
  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration? _duration;

  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration?>? _durationSub;
  StreamSubscription<bool>? _playingSub;

  AudioMessageController(this.adapter) {
    _positionSub = adapter.positionStream.listen((p) {
      _position = p;
      notifyListeners();
    });
    _durationSub = adapter.durationStream.listen((d) {
      _duration = d;
      notifyListeners();
    });
    _playingSub = adapter.playingStream.listen((p) {
      _isPlaying = p;
      notifyListeners();
    });
  }

  String? get activeSource => _activeSource;
  bool get isPlaying => _isPlaying;
  Duration get position => _position;
  Duration? get duration => _duration;

  bool isActive(String source) => _activeSource == source;
  bool isPlayingSource(String source) => isActive(source) && _isPlaying;

  /// Make [source] the active source and start playback. If a different
  /// source was active, it is implicitly paused via [adapter.load].
  Future<void> playSource(String source) async {
    if (_activeSource != source) {
      await adapter.load(source);
      _activeSource = source;
      _position = Duration.zero;
      _duration = null;
      notifyListeners();
    }
    await adapter.play();
  }

  /// Pause if [source] is the active source. No-op otherwise.
  Future<void> pauseSource(String source) async {
    if (_activeSource == source) {
      await adapter.pause();
    }
  }

  /// Toggles play/pause for [source]. Calling on a non-active source switches
  /// to it and starts playing.
  Future<void> toggleSource(String source) async {
    if (isPlayingSource(source)) {
      await pauseSource(source);
    } else {
      await playSource(source);
    }
  }

  /// Seek the active source. No-op if no source is active.
  Future<void> seek(Duration position) async {
    if (_activeSource == null) return;
    await adapter.seek(position);
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _durationSub?.cancel();
    _playingSub?.cancel();
    adapter.dispose();
    super.dispose();
  }
}

/// A play/scrub/duration row for a single audio source. Reads state from a
/// shared [AudioMessageController] so multiple tiles can't play concurrently.
///
/// Pass [duration] when known up-front (e.g. server-stored metadata) so the
/// scrubber renders correctly before the source is loaded.
class AudioMessageTile extends StatelessWidget {
  final String source;
  final AudioMessageController controller;
  final Duration? duration;
  final Widget? leading;
  final EdgeInsetsGeometry padding;

  const AudioMessageTile({
    super.key,
    required this.source,
    required this.controller,
    this.duration,
    this.leading,
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
  });

  String _format(Duration d) {
    final String m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final String s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return d.inHours > 0 ? "${d.inHours}:$m:$s" : "$m:$s";
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final bool isActive = controller.isActive(source);
        final bool isPlaying = controller.isPlayingSource(source);
        final Duration pos = isActive ? controller.position : Duration.zero;
        final Duration? knownDuration = isActive
            ? (controller.duration ?? duration)
            : duration;

        return Padding(
          padding: padding,
          child: Row(
            children: [
              if (leading != null) ...[leading!, const SizedBox(width: 8)],
              IconButton(
                icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow),
                onPressed: () => controller.toggleSource(source),
              ),
              Expanded(
                child:
                    knownDuration == null || knownDuration.inMilliseconds == 0
                    ? const LinearProgressIndicator()
                    : Slider(
                        value: pos.inMilliseconds
                            .clamp(0, knownDuration.inMilliseconds)
                            .toDouble(),
                        max: knownDuration.inMilliseconds.toDouble(),
                        onChanged: isActive
                            ? (v) => controller.seek(
                                Duration(milliseconds: v.toInt()),
                              )
                            : null,
                      ),
              ),
              const SizedBox(width: 8),
              Text(
                _format(isActive ? pos : (knownDuration ?? Duration.zero)),
                style: const TextStyle(
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
