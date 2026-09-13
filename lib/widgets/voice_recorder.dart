import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:nylo_support/ny_core.dart';
import '/media_pro.dart';
import '/mixins/media_helper_mixin.dart';

/// Recording UX style for [VoiceRecorder].
enum RecorderMode {
  /// Press-and-hold the mic to record. Drag left past
  /// [VoiceRecorder.cancelThreshold] to cancel; release to send.
  holdToRecord,

  /// Tap the mic to start. Tap stop to send. Tap the X to cancel.
  tapToRecord,
}

/// Whatsapp / Telegram-style voice message recorder. Renders an idle mic
/// button that expands into a recording row (timer + waveform + cancel UX)
/// while active. All active states render at intrinsic width, so the widget
/// is safe to place directly in a `Row` alongside other flex children
/// without giving up bounded constraints.
///
/// Recording engine is pluggable via [adapterFactory] — implement
/// [AudioRecorderAdapter] against `record`, `flutter_sound`, or your
/// preferred package.
///
/// On stop, the file is either uploaded via [apiUpload] +
/// [MediaApiService.uploadAudio] (and [onUploaded] called with the
/// response) OR handed off as a path to [onRecorded] for custom flows.
class VoiceRecorder extends StatefulWidget {
  final AudioRecorderAdapter Function() adapterFactory;
  final RecorderMode mode;

  /// Upload destination. Ignored when [onRecorded] is supplied.
  final ApiRequest? apiUpload;

  /// Fired with the upload response when [apiUpload] is used.
  final void Function(dynamic response)? onUploaded;

  /// When set, bypasses [MediaApiService] entirely and hands off the local
  /// file path. Caller owns the file after this returns.
  final void Function(String path)? onRecorded;

  /// Auto-stops recording at this duration. Null = no cap.
  final Duration? maxDuration;

  /// Recordings shorter than this are rejected (helps catch accidental
  /// taps in [RecorderMode.holdToRecord]).
  final Duration minDuration;

  /// Show a preview row (play/scrub/duration + Send/Discard) before the
  /// recorded file is uploaded. Requires [playerFactory] to be supplied.
  final bool previewBeforeSend;

  /// Factory for the playback adapter used in the preview state. Required
  /// when [previewBeforeSend] is `true`.
  final AudioPlayerAdapter Function()? playerFactory;

  /// Label for the send button in preview state.
  final String previewSendLabel;

  /// Label for the discard button in preview state.
  final String previewDiscardLabel;

  final Color? accentColor;
  final Color? backgroundColor;
  final IconData micIcon;
  final IconData stopIcon;
  final String slideToCancelLabel;

  /// Pixels of leftward drag in [RecorderMode.holdToRecord] before the
  /// recording is treated as cancelled on release.
  final double cancelThreshold;

  const VoiceRecorder({
    super.key,
    required this.adapterFactory,
    this.mode = RecorderMode.holdToRecord,
    this.apiUpload,
    this.onUploaded,
    this.onRecorded,
    this.maxDuration,
    this.minDuration = const Duration(seconds: 1),
    this.previewBeforeSend = false,
    this.playerFactory,
    this.previewSendLabel = "Send",
    this.previewDiscardLabel = "Discard",
    this.accentColor,
    this.backgroundColor,
    this.micIcon = Icons.mic,
    this.stopIcon = Icons.stop,
    this.slideToCancelLabel = "← Slide to cancel",
    this.cancelThreshold = 100,
  }) : assert(
         !previewBeforeSend || playerFactory != null,
         'playerFactory is required when previewBeforeSend is true',
       );

  @override
  createState() => _VoiceRecorderState();
}

enum _UiState { idle, recording, previewing, sending }

class _VoiceRecorderState extends NyState<VoiceRecorder> with MediaHelperMixin {
  AudioRecorderAdapter? _adapter;

  _UiState _uiState = _UiState.idle;
  Duration _elapsed = Duration.zero;
  final List<double> _amplitudes = [];
  static const int _waveLength = 25;

  bool _willCancel = false;
  double _dragOffset = 0;

  StreamSubscription<double>? _ampSub;
  StreamSubscription<Duration>? _durSub;

  // Preview state
  AudioPlayerAdapter? _previewPlayer;
  String? _previewPath;
  Duration _previewPos = Duration.zero;
  Duration? _previewDur;
  bool _previewPlaying = false;

  StreamSubscription<Duration>? _previewPosSub;
  StreamSubscription<Duration?>? _previewDurSub;
  StreamSubscription<bool>? _previewPlaySub;

  Future<bool> _ensurePermission() async {
    final AudioRecorderAdapter adapter = _adapter!;
    if (await adapter.hasPermission()) return true;
    final bool granted = await adapter.requestPermission();
    if (!granted) {
      showToastSorry(description: "Microphone permission denied".tr());
    }
    return granted;
  }

  Future<void> _startRecording() async {
    if (_uiState != _UiState.idle) return;

    _adapter = widget.adapterFactory();

    if (!await _ensurePermission()) {
      await _adapter!.dispose();
      _adapter = null;
      return;
    }

    _ampSub = _adapter!.amplitudeStream.listen((amp) {
      if (!mounted) return;
      setState(() {
        _amplitudes.add(amp.clamp(0.0, 1.0));
        if (_amplitudes.length > _waveLength) _amplitudes.removeAt(0);
      });
    });

    _durSub = _adapter!.durationStream.listen((d) {
      if (!mounted) return;
      setState(() => _elapsed = d);
      if (widget.maxDuration != null && d >= widget.maxDuration!) {
        _stopAndSend();
      }
    });

    await _adapter!.start();
    if (!mounted) return;
    setState(() {
      _uiState = _UiState.recording;
      _elapsed = Duration.zero;
      _amplitudes.clear();
      _willCancel = false;
      _dragOffset = 0;
    });
  }

  Future<void> _stopAndSend() async {
    if (_uiState != _UiState.recording) return;

    if (_elapsed < widget.minDuration) {
      showToastSorry(description: "Hold longer to record".tr());
      await _cancelRecording();
      return;
    }

    String? path;
    try {
      path = await _adapter!.stop();
    } catch (e) {
      printToConsole("VoiceRecorder stop failed: $e");
    }

    // Recorder is done — release it before transitioning state.
    await _ampSub?.cancel();
    await _durSub?.cancel();
    try {
      await _adapter?.dispose();
    } catch (e) {
      printToConsole("VoiceRecorder dispose failed: $e");
    }
    _ampSub = null;
    _durSub = null;
    _adapter = null;

    if (path == null || !mounted) {
      await _cleanup();
      return;
    }

    if (widget.previewBeforeSend && widget.playerFactory != null) {
      await _enterPreview(path);
      return;
    }

    await _uploadAndFinish(path);
  }

  Future<void> _cancelRecording() async {
    try {
      await _adapter?.cancel();
    } catch (e) {
      printToConsole("VoiceRecorder cancel failed: $e");
    }
    await _cleanup();
  }

  /// Drives the upload (or [VoiceRecorder.onRecorded] handoff) and resets
  /// to idle. Shared by the no-preview stop path and the send-from-preview
  /// path.
  Future<void> _uploadAndFinish(String path) async {
    if (mounted) setState(() => _uiState = _UiState.sending);

    if (mounted) {
      if (widget.onRecorded != null) {
        widget.onRecorded!(path);
      } else if (widget.apiUpload != null) {
        try {
          final picked = PickedFileInfo.fromPath(path);
          final dynamic response = await MediaApiService().uploadAudio(
            picked,
            apiRequest: widget.apiUpload!,
          );
          if (mounted) widget.onUploaded?.call(response);
        } catch (e) {
          printToConsole("VoiceRecorder upload failed: $e");
          if (mounted) showToastSorry(description: "Upload failed".tr());
        }
      }
    }

    await _cleanup();
  }

  Future<void> _enterPreview(String path) async {
    final AudioPlayerAdapter player = widget.playerFactory!();
    _previewPlayer = player;
    _previewPath = path;
    _previewPos = Duration.zero;
    _previewDur = null;
    _previewPlaying = false;

    _previewPosSub = player.positionStream.listen((p) {
      if (!mounted) return;
      setState(() => _previewPos = p);
    });
    _previewDurSub = player.durationStream.listen((d) {
      if (!mounted) return;
      setState(() => _previewDur = d);
    });
    _previewPlaySub = player.playingStream.listen((p) {
      if (!mounted) return;
      setState(() => _previewPlaying = p);
    });

    try {
      await player.load(path);
    } catch (e) {
      printToConsole("Preview player load failed: $e");
      await _cleanup();
      return;
    }

    if (!mounted) return;
    setState(() => _uiState = _UiState.previewing);
  }

  Future<void> _togglePreviewPlayback() async {
    if (_previewPlayer == null) return;
    if (_previewPlaying) {
      await _previewPlayer!.pause();
    } else {
      await _previewPlayer!.play();
    }
  }

  Future<void> _seekPreview(Duration position) async {
    if (_previewPlayer == null) return;
    await _previewPlayer!.seek(position);
  }

  Future<void> _sendFromPreview() async {
    final String? path = _previewPath;
    await _disposePreview();
    if (path != null) {
      await _uploadAndFinish(path);
    } else {
      await _cleanup();
    }
  }

  Future<void> _discardFromPreview() async {
    final String? path = _previewPath;
    await _disposePreview();
    if (path != null) {
      try {
        File(path).deleteSync();
      } catch (e) {
        printToConsole("Preview file delete failed: $e");
      }
    }
    await _cleanup();
  }

  Future<void> _disposePreview() async {
    try {
      await _previewPlayer?.pause();
    } catch (e) {
      printToConsole("Preview player pause failed: $e");
    }
    await _previewPosSub?.cancel();
    await _previewDurSub?.cancel();
    await _previewPlaySub?.cancel();
    try {
      await _previewPlayer?.dispose();
    } catch (e) {
      printToConsole("Preview player dispose failed: $e");
    }
    _previewPosSub = null;
    _previewDurSub = null;
    _previewPlaySub = null;
    _previewPlayer = null;
    _previewPath = null;
  }

  Future<void> _cleanup() async {
    await _ampSub?.cancel();
    await _durSub?.cancel();
    try {
      await _adapter?.dispose();
    } catch (e) {
      printToConsole("VoiceRecorder dispose failed: $e");
    }
    _ampSub = null;
    _durSub = null;
    _adapter = null;
    await _disposePreview();
    if (mounted) {
      setState(() {
        _uiState = _UiState.idle;
        _elapsed = Duration.zero;
        _amplitudes.clear();
        _willCancel = false;
        _dragOffset = 0;
        _previewPos = Duration.zero;
        _previewDur = null;
        _previewPlaying = false;
      });
    }
  }

  @override
  void dispose() {
    _ampSub?.cancel();
    _durSub?.cancel();
    _adapter?.dispose();
    _previewPosSub?.cancel();
    _previewDurSub?.cancel();
    _previewPlaySub?.cancel();
    _previewPlayer?.dispose();
    super.dispose();
  }

  String _formatElapsed() {
    final String m = _elapsed.inMinutes.toString().padLeft(2, '0');
    final String s = _elapsed.inSeconds
        .remainder(60)
        .toString()
        .padLeft(2, '0');
    return "$m:$s";
  }

  @override
  Widget view(BuildContext context) {
    if (widget.mode == RecorderMode.holdToRecord) {
      return GestureDetector(
        onLongPressStart: (_) {
          if (_uiState == _UiState.idle) _startRecording();
        },
        onLongPressMoveUpdate: (details) {
          if (_uiState != _UiState.recording) return;
          final double dx = details.localOffsetFromOrigin.dx;
          if (dx <= 0) {
            setState(() {
              _dragOffset = dx;
              _willCancel = dx.abs() >= widget.cancelThreshold;
            });
          }
        },
        onLongPressEnd: (_) {
          if (_uiState != _UiState.recording) return;
          if (_willCancel) {
            _cancelRecording();
          } else {
            _stopAndSend();
          }
        },
        behavior: HitTestBehavior.opaque,
        child: _buildBody(),
      );
    }
    return _buildBody();
  }

  Widget _buildBody() {
    switch (_uiState) {
      case _UiState.idle:
        return _idleBody();
      case _UiState.recording:
        return _recordingBody();
      case _UiState.previewing:
        return _previewBody();
      case _UiState.sending:
        return _sendingBody();
    }
  }

  Color _accent(BuildContext context) =>
      widget.accentColor ?? Theme.of(context).colorScheme.primary;

  Widget _micButton({required bool active}) {
    final Color accent = _accent(context);
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: active ? accent : accent.withValues(alpha: 0.12),
        shape: BoxShape.circle,
      ),
      child: Icon(
        widget.micIcon,
        color: active ? Colors.white : accent,
        size: 22,
      ),
    );
  }

  Widget _stopButton() {
    return Container(
      width: 44,
      height: 44,
      decoration: const BoxDecoration(
        color: Colors.red,
        shape: BoxShape.circle,
      ),
      child: Icon(widget.stopIcon, color: Colors.white, size: 22),
    );
  }

  Widget _waveform() {
    if (_amplitudes.isEmpty) {
      return const SizedBox.shrink();
    }
    final Color accent = _accent(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: _amplitudes
          .map(
            (amp) => Container(
              width: 3,
              height: (2 + amp * 22).clamp(2, 24).toDouble(),
              margin: const EdgeInsets.symmetric(horizontal: 1),
              decoration: BoxDecoration(
                color: _willCancel ? Colors.red : accent,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _idleBody() {
    if (widget.mode == RecorderMode.tapToRecord) {
      return InkWell(
        onTap: _startRecording,
        customBorder: const CircleBorder(),
        child: _micButton(active: false),
      );
    }
    return _micButton(active: false);
  }

  Widget _recordingBody() {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Bounded parent (Expanded slot, sized SizedBox, etc.) → full layout
        // with verbose slide-to-cancel hint and flexible waveform.
        // Unbounded parent (non-flex Row sibling) → compact intrinsic layout
        // with just an arrow icon so we fit alongside other siblings.
        final bool compact = !constraints.maxWidth.isFinite;
        return compact ? _recordingBodyCompact() : _recordingBodyFull();
      },
    );
  }

  Widget _recordingBodyCompact() {
    final isHold = widget.mode == RecorderMode.holdToRecord;
    final Widget leftControl = isHold
        ? Opacity(
            opacity: (1 - _dragOffset.abs() / widget.cancelThreshold).clamp(
              0.0,
              1.0,
            ),
            child: Icon(
              Icons.arrow_back,
              size: 16,
              color: _willCancel ? Colors.red : Colors.grey[700],
            ),
          )
        : IconButton(
            icon: const Icon(Icons.close),
            onPressed: _cancelRecording,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
          );

    return Container(
      decoration: BoxDecoration(
        color: widget.backgroundColor ?? Colors.grey[100],
        borderRadius: BorderRadius.circular(24),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          leftControl,
          const SizedBox(width: 8),
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: Colors.red,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            _formatElapsed(),
            style: TextStyle(
              color: _willCancel ? Colors.red : null,
              fontFeatures: const [FontFeature.tabularFigures()],
              fontWeight: FontWeight.w500,
              fontSize: 13,
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 50,
            height: 22,
            child: ClipRect(
              child: OverflowBox(
                alignment: Alignment.centerRight,
                minWidth: 0,
                maxWidth: double.infinity,
                child: _waveform(),
              ),
            ),
          ),
          const SizedBox(width: 6),
          _recordingRightControl(),
        ],
      ),
    );
  }

  Widget _recordingBodyFull() {
    final isHold = widget.mode == RecorderMode.holdToRecord;
    final Widget leftControl = isHold
        ? Opacity(
            opacity: (1 - _dragOffset.abs() / widget.cancelThreshold).clamp(
              0.0,
              1.0,
            ),
            child: Text(
              widget.slideToCancelLabel,
              style: TextStyle(
                color: _willCancel ? Colors.red : Colors.grey[700],
                fontSize: 12,
              ),
            ),
          )
        : IconButton(
            icon: const Icon(Icons.close),
            onPressed: _cancelRecording,
          );

    return Container(
      decoration: BoxDecoration(
        color: widget.backgroundColor ?? Colors.grey[100],
        borderRadius: BorderRadius.circular(24),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          leftControl,
          const SizedBox(width: 12),
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: Colors.red,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            _formatElapsed(),
            style: TextStyle(
              color: _willCancel ? Colors.red : null,
              fontFeatures: const [FontFeature.tabularFigures()],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ClipRect(
              child: SizedBox(
                height: 24,
                child: OverflowBox(
                  alignment: Alignment.centerRight,
                  minWidth: 0,
                  maxWidth: double.infinity,
                  child: _waveform(),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          _recordingRightControl(),
        ],
      ),
    );
  }

  Widget _recordingRightControl() {
    final isHold = widget.mode == RecorderMode.holdToRecord;
    return isHold
        ? Transform.translate(
            offset: Offset(_dragOffset.clamp(-widget.cancelThreshold, 0), 0),
            child: _micButton(active: true),
          )
        : InkWell(
            onTap: _stopAndSend,
            customBorder: const CircleBorder(),
            child: _stopButton(),
          );
  }

  Widget _previewBody() {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Bounded parent (Expanded slot) → expanded scrubber. Unbounded
        // parent → fixed-width scrubber so we keep an intrinsic width.
        final double? scrubberSlot = constraints.maxWidth.isFinite
            ? null
            : 140.0;
        return _previewBodyImpl(scrubberWidth: scrubberSlot);
      },
    );
  }

  Widget _previewBodyImpl({double? scrubberWidth}) {
    final Color accent = _accent(context);
    final Duration dur = _previewDur ?? Duration.zero;
    final bool hasDuration = dur.inMilliseconds > 0;
    final Widget scrubber = hasDuration
        ? Slider(
            value: _previewPos.inMilliseconds
                .clamp(0, dur.inMilliseconds)
                .toDouble(),
            max: dur.inMilliseconds.toDouble(),
            onChanged: (v) => _seekPreview(Duration(milliseconds: v.toInt())),
          )
        : const LinearProgressIndicator();

    return Container(
      decoration: BoxDecoration(
        color: widget.backgroundColor ?? Colors.grey[100],
        borderRadius: BorderRadius.circular(24),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Row(
        mainAxisSize: scrubberWidth == null
            ? MainAxisSize.max
            : MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: widget.previewDiscardLabel,
            onPressed: _discardFromPreview,
          ),
          IconButton(
            icon: Icon(
              _previewPlaying
                  ? Icons.pause_circle_filled
                  : Icons.play_circle_filled,
              color: accent,
              size: 32,
            ),
            onPressed: _togglePreviewPlayback,
          ),
          if (scrubberWidth == null)
            Expanded(child: scrubber)
          else
            SizedBox(width: scrubberWidth, child: scrubber),
          const SizedBox(width: 4),
          Text(
            _formatPreviewTime(),
            style: const TextStyle(
              fontFeatures: [FontFeature.tabularFigures()],
              fontSize: 12,
            ),
          ),
          const SizedBox(width: 4),
          Material(
            color: accent,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: _sendFromPreview,
              child: const SizedBox(
                width: 44,
                height: 44,
                child: Icon(Icons.send_rounded, color: Colors.white, size: 20),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatPreviewTime() {
    final Duration d = _previewPos;
    final String m = d.inMinutes.toString().padLeft(2, '0');
    final String s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return "$m:$s";
  }

  Widget _sendingBody() {
    return Container(
      decoration: BoxDecoration(
        color: widget.backgroundColor ?? Colors.grey[100],
        borderRadius: BorderRadius.circular(24),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(),
          ),
          const SizedBox(width: 12),
          Text("Sending...".tr()),
        ],
      ),
    );
  }
}
