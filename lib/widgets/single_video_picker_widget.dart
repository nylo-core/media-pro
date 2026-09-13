import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';
import 'package:nylo_support/ny_core.dart';
import '/media_pro.dart';
import '/mixins/media_helper_mixin.dart';

/// [SingleVideoPicker] widget can be used to upload a single video from the
/// gallery or camera. Three styles are available — see [VideoPickerStyle].
///
/// Provide [thumbnailGenerator] to render a real poster from the picked
/// video; without it the picker shows a generic video icon. Pass
/// [thumbnailUrl] to display a remote poster for an already-uploaded video.
class SingleVideoPicker extends StatefulWidget {
  SingleVideoPicker({
    super.key,
    required Widget Function(BuildContext context, Function upload) child,
    this.defaultVideo,
    this.thumbnailUrl,
    this.thumbnailGenerator,
    this.options = const VideoPickerOptions(),
    this.videoSource = "gallery",
    this.cameraDevice = "rear",
    this.apiUpload,
    required this.setVideoUrlFromResponse,
    this.height = 70,
    this.width = 70,
    this.loading,
    this.onError,
    this.canUpdate = true,
    this.borderRadius,
    this.maxSize,
    this.allowedMimeTypes,
  }) : style = CustomVideoPickerStyle(child);

  SingleVideoPicker.compact({
    super.key,
    this.defaultVideo,
    this.thumbnailUrl,
    this.thumbnailGenerator,
    this.options = const VideoPickerOptions(),
    this.videoSource = "gallery",
    this.cameraDevice = "rear",
    this.apiUpload,
    required this.setVideoUrlFromResponse,
    this.height = 100,
    this.width = 100,
    this.loading,
    this.onError,
    this.canUpdate = true,
    this.borderRadius,
    this.maxSize,
    this.allowedMimeTypes,
  }) : style = const CompactVideoPickerStyle();

  SingleVideoPicker.simple({
    super.key,
    this.defaultVideo,
    this.thumbnailUrl,
    this.thumbnailGenerator,
    this.options = const VideoPickerOptions(),
    this.videoSource = "gallery",
    this.cameraDevice = "rear",
    this.apiUpload,
    required this.setVideoUrlFromResponse,
    this.height = 70,
    this.width = 70,
    this.loading,
    this.onError,
    this.canUpdate = true,
    this.borderRadius,
    this.maxSize,
    this.allowedMimeTypes,
  }) : style = const SimpleVideoPickerStyle();

  final ImagePicker picker = ImagePicker();
  final dynamic defaultVideo;
  final String? thumbnailUrl;
  final Future<File?> Function(File video)? thumbnailGenerator;
  final VideoPickerOptions options;
  final String videoSource;
  final String cameraDevice;
  final ApiRequest? apiUpload;
  final Function(dynamic response) setVideoUrlFromResponse;
  final double height;
  final double width;
  final Widget? loading;
  final Function? onError;
  final bool canUpdate;
  final BorderRadius? borderRadius;
  final double? maxSize;
  final List<String>? allowedMimeTypes;
  final VideoPickerStyle style;

  @override
  createState() => _SingleVideoPickerState();
}

class _SingleVideoPickerState extends NyState<SingleVideoPicker>
    with MediaHelperMixin {
  final MediaApiService _mediaApiService = MediaApiService();

  dynamic _defaultVideo;
  File? _generatedThumbnail;

  @override
  get init => () {
    _defaultVideo = widget.defaultVideo;
  };

  Future<void> _handleVideoUpload() async {
    if (widget.canUpdate == false) return;
    if (!mounted) return;
    lockRelease(
      'video_upload',
      perform: () async {
        XFile? video;
        try {
          ImageSource source = widget.videoSource == "camera"
              ? ImageSource.camera
              : ImageSource.gallery;
          CameraDevice cameraDevice = widget.cameraDevice == "rear"
              ? CameraDevice.rear
              : CameraDevice.front;
          video = await widget.picker.pickVideo(
            source: source,
            maxDuration: widget.options.maxDuration,
            preferredCameraDevice: cameraDevice,
          );
        } on Exception catch (e) {
          if (MediaPro.instance.debugMode ?? false) {
            if (kDebugMode) {
              print(e.toString());
            }
          }
        }

        if (video == null) return;

        File file = File(video.path);
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

        if (widget.allowedMimeTypes?.isNotEmpty ?? false) {
          final String? mimeType = lookupMimeType(file.path);
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

        if (widget.apiUpload == null) {
          printToConsole("apiUpload parameter is required to upload video");
          return;
        }

        if (widget.thumbnailGenerator != null) {
          try {
            _generatedThumbnail = await widget.thumbnailGenerator!(file);
          } catch (e) {
            printToConsole("Failed to generate thumbnail: $e");
          }
        }

        final picked = PickedFileInfo.fromXFile(
          video,
          mimeType: lookupMimeType(file.path),
        );

        dynamic response = await _mediaApiService.uploadVideo(
          picked,
          apiRequest: widget.apiUpload!,
        );

        String? uploaded = widget.setVideoUrlFromResponse(response);
        if (uploaded != null) {
          _defaultVideo = uploaded;
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
            CustomVideoPickerStyle style => style.builder(
              context,
              _handleVideoUpload,
            ),
            CompactVideoPickerStyle() => _compact(),
            SimpleVideoPickerStyle() => _simple(),
          };
        }
      default:
        {
          return const SizedBox();
        }
    }
  }

  String currentState() {
    if (isLocked('video_upload')) return 'loading';
    return 'default';
  }

  /// Resolves the thumbnail to render. Priority: locally-generated > remote
  /// thumbnail URL > generic icon.
  Widget _findThumbnailWidget() {
    if (_generatedThumbnail != null) {
      return Image.file(
        _generatedThumbnail!,
        height: widget.height,
        width: widget.width,
        fit: BoxFit.cover,
      );
    }

    if (widget.thumbnailUrl != null && widget.thumbnailUrl!.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: widget.thumbnailUrl!,
        height: widget.height,
        width: widget.width,
        fit: BoxFit.cover,
        placeholder: (context, url) => const Center(child: MediaLoader()),
      );
    }

    return Container(
      height: widget.height,
      width: widget.width,
      color: Colors.grey[200],
      child: Icon(
        _defaultVideo == null ? Icons.videocam_rounded : Icons.play_circle_fill,
        size: 32,
      ),
    );
  }

  Widget _compact() {
    return GestureDetector(
      onTap: _handleVideoUpload,
      child: SizedBox(
        height: widget.height,
        width: widget.width,
        child: Stack(
          children: [
            Positioned.fill(
              left: 5,
              top: 5,
              bottom: 5,
              right: 5,
              child: ClipRRect(
                borderRadius: widget.borderRadius ?? BorderRadius.circular(50),
                child: _findThumbnailWidget(),
              ),
            ),
            if (_defaultVideo != null || _generatedThumbnail != null)
              Positioned.fill(
                child: Center(
                  child: Icon(
                    Icons.play_circle_fill,
                    color: Colors.white.withValues(alpha: 0.85),
                    size: 32,
                  ),
                ),
              ),
            if (widget.canUpdate == true)
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  height: 30,
                  width: 30,
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(50),
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: const Icon(Icons.edit),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _simple() {
    return InkWell(
      onTap: _handleVideoUpload,
      child: Center(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ClipRRect(
              borderRadius: widget.borderRadius ?? BorderRadius.circular(8),
              child: _findThumbnailWidget(),
            ),
            const Padding(padding: EdgeInsets.symmetric(vertical: 8)),
            Text("Upload a video".tr()),
          ],
        ),
      ),
    );
  }
}
