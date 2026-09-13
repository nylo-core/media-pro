import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '/media_pro.dart';

/// Drop-in network video tile — the analogue of [CachedNetworkImage] for
/// video. Renders the poster up-front, defers player initialization until
/// the user taps play (or [autoPlay] is true), and shows a play overlay
/// whenever paused.
///
/// Pluggable via [adapterFactory] so the host app picks its own video
/// backend (`video_player`, `media_kit`, etc.) — `media_pro` doesn't pull
/// in a player dependency.
class NetworkVideo extends StatefulWidget {
  final String url;
  final String? posterUrl;
  final VideoPlayerAdapter Function() adapterFactory;
  final bool autoPlay;
  final BorderRadius? borderRadius;

  /// Falls back to the adapter's reported [VideoPlayerAdapter.aspectRatio]
  /// once initialized; defaults to 16:9 before that.
  final double? aspectRatio;

  /// Replaces the default centered play-circle overlay shown while paused.
  final Widget? playOverlay;

  /// Replaces the default loading spinner shown during initialization.
  final Widget? loadingIndicator;

  const NetworkVideo({
    super.key,
    required this.url,
    required this.adapterFactory,
    this.posterUrl,
    this.autoPlay = false,
    this.borderRadius,
    this.aspectRatio,
    this.playOverlay,
    this.loadingIndicator,
  });

  @override
  State<NetworkVideo> createState() => _NetworkVideoState();
}

class _NetworkVideoState extends State<NetworkVideo> {
  VideoPlayerAdapter? _adapter;
  bool _initialized = false;
  bool _playing = false;
  bool _loading = false;

  StreamSubscription<bool>? _initSub;
  StreamSubscription<bool>? _playSub;

  @override
  void initState() {
    super.initState();
    if (widget.autoPlay) {
      _initAndPlay();
    }
  }

  Future<void> _initAndPlay() async {
    if (_loading) return;
    if (_initialized) {
      _togglePlayback();
      return;
    }
    setState(() => _loading = true);

    final VideoPlayerAdapter adapter = widget.adapterFactory();
    _adapter = adapter;
    _initSub = adapter.initializedStream.listen((init) {
      if (mounted) setState(() => _initialized = init);
    });
    _playSub = adapter.playingStream.listen((p) {
      if (mounted) setState(() => _playing = p);
    });

    try {
      await adapter.initialize(widget.url);
      await adapter.play();
    } catch (e) {
      if (kDebugMode && (MediaPro.instance.debugMode ?? false)) {
        debugPrint("NetworkVideo init failed: $e");
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _togglePlayback() async {
    if (_adapter == null) return;
    if (_playing) {
      await _adapter!.pause();
    } else {
      await _adapter!.play();
    }
  }

  @override
  void dispose() {
    _initSub?.cancel();
    _playSub?.cancel();
    _adapter?.dispose();
    super.dispose();
  }

  Widget _buildPoster() {
    if (widget.posterUrl != null && widget.posterUrl!.isNotEmpty) {
      return CachedNetworkImage(imageUrl: widget.posterUrl!, fit: BoxFit.cover);
    }
    return Container(color: Colors.black12);
  }

  Widget _buildPlayOverlay() {
    return widget.playOverlay ??
        Container(
          color: Colors.black26,
          child: const Center(
            child: Icon(Icons.play_circle_fill, size: 56, color: Colors.white),
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    final double aspect = widget.aspectRatio ?? _adapter?.aspectRatio ?? 16 / 9;

    final stack = Stack(
      fit: StackFit.expand,
      children: [
        if (_initialized && _adapter != null)
          _adapter!.buildView()
        else
          _buildPoster(),
        if (!_playing && !_loading) _buildPlayOverlay(),
        if (_loading)
          Center(
            child:
                widget.loadingIndicator ??
                const CircularProgressIndicator(color: Colors.white),
          ),
      ],
    );

    final tappable = GestureDetector(onTap: _initAndPlay, child: stack);

    final wrapped = AspectRatio(
      aspectRatio: aspect,
      child: widget.borderRadius != null
          ? ClipRRect(borderRadius: widget.borderRadius!, child: tappable)
          : tappable,
    );

    return wrapped;
  }
}
