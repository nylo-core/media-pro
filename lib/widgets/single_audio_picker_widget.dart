import 'dart:io';
import 'package:file_picker/file_picker.dart' as fp;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mime/mime.dart';
import 'package:nylo_support/ny_core.dart';
import '/media_pro.dart';
import '/mixins/media_helper_mixin.dart';

/// [SingleAudioPicker] widget can be used to upload a single audio file.
/// Two styles are available — see [AudioPickerStyle].
///
/// Audio is picked via `file_picker` (no camera/gallery distinction). Pass
/// [AudioPickerOptions.allowedExtensions] to constrain the picker dialog.
class SingleAudioPicker extends StatefulWidget {
  SingleAudioPicker({
    super.key,
    required Widget Function(BuildContext context, Function upload) child,
    this.defaultAudio,
    this.options = const AudioPickerOptions(),
    this.apiUpload,
    required this.setAudioUrlFromResponse,
    this.loading,
    this.onError,
    this.canUpdate = true,
    this.maxSize,
    this.allowedMimeTypes,
  }) : style = CustomAudioPickerStyle(child);

  const SingleAudioPicker.simple({
    super.key,
    this.defaultAudio,
    this.options = const AudioPickerOptions(),
    this.apiUpload,
    required this.setAudioUrlFromResponse,
    this.loading,
    this.onError,
    this.canUpdate = true,
    this.maxSize,
    this.allowedMimeTypes,
  }) : style = const SimpleAudioPickerStyle();

  final dynamic defaultAudio;
  final AudioPickerOptions options;
  final ApiRequest? apiUpload;
  final Function(dynamic response) setAudioUrlFromResponse;
  final Widget? loading;
  final Function? onError;
  final bool canUpdate;
  final double? maxSize;
  final List<String>? allowedMimeTypes;
  final AudioPickerStyle style;

  @override
  createState() => _SingleAudioPickerState();
}

class _SingleAudioPickerState extends NyState<SingleAudioPicker>
    with MediaHelperMixin {
  final MediaApiService _mediaApiService = MediaApiService();

  dynamic _defaultAudio;
  PickedFileInfo? _pickedAudio;

  @override
  get init => () {
    _defaultAudio = widget.defaultAudio;
    if (widget.defaultAudio is PickedFileInfo) {
      _pickedAudio = widget.defaultAudio;
    }
  };

  Future<void> _handleAudioUpload() async {
    if (widget.canUpdate == false) return;
    if (!mounted) return;
    lockRelease(
      'audio_upload',
      perform: () async {
        fp.PlatformFile? platformFile;
        try {
          platformFile = await fp.FilePicker.pickFile(
            type: widget.options.allowedExtensions != null
                ? fp.FileType.custom
                : fp.FileType.audio,
            allowedExtensions: widget.options.allowedExtensions,
          );
        } on Exception catch (e) {
          if (MediaPro.instance.debugMode ?? false) {
            if (kDebugMode) {
              print(e.toString());
            }
          }
        }

        if (platformFile == null) return;

        if (platformFile.path == null) {
          showToastSorry(description: "Could not read file path".tr());
          return;
        }

        File file = File(platformFile.path!);
        if (widget.maxSize != null) {
          int fileInBytes = file.lengthSync();
          if (fileInBytes > (widget.maxSize!)) {
            showToastSorry(
              description:
                  "The file is too large. It must be under ${calculateMaxSizeToReadableFormat(widget.maxSize!)}"
                      .tr(),
            );
            return;
          }
        }

        final String? mimeType = lookupMimeType(file.path);
        if (widget.allowedMimeTypes?.isNotEmpty ?? false) {
          if (mimeType == null ||
              !widget.allowedMimeTypes!.contains(mimeType)) {
            showToastSorry(
              description:
                  "The file type must be one of ${widget.allowedMimeTypes!.join(', ')}"
                      .tr(),
            );
            return;
          }
        }

        final Duration? maxDuration = widget.options.maxDuration;
        final Future<Duration?> Function(String path)? durationResolver =
            widget.options.durationResolver;
        if (maxDuration != null && durationResolver != null) {
          try {
            final Duration? duration = await durationResolver(file.path);
            if (duration != null && duration > maxDuration) {
              showToastSorry(
                description:
                    "The audio is too long. It must be under ${_formatDuration(maxDuration)}"
                        .tr(),
              );
              return;
            }
          } catch (e) {
            printToConsole(
              "durationResolver threw: $e — skipping duration check",
            );
          }
        }

        final picked = PickedFileInfo.fromPlatformFile(
          platformFile,
          mimeType: mimeType,
        );

        if (widget.apiUpload == null) {
          printToConsole("apiUpload parameter is required to upload audio");
          return;
        }

        dynamic response = await _mediaApiService.uploadAudio(
          picked,
          apiRequest: widget.apiUpload!,
        );

        _pickedAudio = picked;
        String? uploaded = widget.setAudioUrlFromResponse(response);
        if (uploaded != null) {
          _defaultAudio = uploaded;
        }
      },
    );
  }

  @override
  Widget view(BuildContext context) {
    switch (currentState()) {
      case "loading":
        {
          return widget.loading ?? const MediaLoader();
        }
      case "default":
        {
          return switch (widget.style) {
            CustomAudioPickerStyle style => style.builder(
              context,
              _handleAudioUpload,
            ),
            SimpleAudioPickerStyle() => _simple(),
          };
        }
      default:
        {
          return const SizedBox();
        }
    }
  }

  String currentState() {
    if (isLocked('audio_upload')) return 'loading';
    return 'default';
  }

  String _formatDuration(Duration d) {
    if (d.inHours > 0) return "${d.inHours}h ${d.inMinutes.remainder(60)}m";
    if (d.inMinutes > 0) {
      return "${d.inMinutes}m ${d.inSeconds.remainder(60)}s";
    }
    return "${d.inSeconds}s";
  }

  String _resolveLabel() {
    if (_pickedAudio != null) return _pickedAudio!.name;
    if (_defaultAudio is String && (_defaultAudio as String).isNotEmpty) {
      return "Audio uploaded".tr();
    }
    return "Upload audio".tr();
  }

  Widget _simple() {
    final String label = _resolveLabel();
    final int? size = _pickedAudio?.sizeBytes;
    return InkWell(
      onTap: _handleAudioUpload,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            const Icon(Icons.music_note_rounded),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(label, overflow: TextOverflow.ellipsis),
                  if (size != null)
                    Text(
                      calculateMaxSizeToReadableFormat(size.toDouble()),
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                ],
              ),
            ),
            if (widget.canUpdate) const Icon(Icons.upload_rounded),
          ],
        ),
      ),
    );
  }
}
