import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:file_picker/file_picker.dart' as fp;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mime/mime.dart';
import 'package:nylo_support/ny_core.dart';
import '/media_pro.dart';
import '/mixins/media_helper_mixin.dart';

/// [GridVideoPicker] — multi-video grid picker. Uses `file_picker` with
/// `FileType.video` for multi-pick. No camera support (picking multiple
/// videos via camera doesn't fit the multi-select UX).
///
/// Uploads dispatch through [MediaApiService.uploadVideos] using the
/// configured [uploadMode] ([UploadMode.standard] or [UploadMode.sequential];
/// [UploadMode.gzip] throws — gzip on encoded video is wasted CPU).
class GridVideoPicker extends StatefulWidget {
  GridVideoPicker(
      {super.key,
      required this.defaultVideos,
      required this.setVideoUrlFromItem,
      this.setVideoThumbnailFromItem,
      this.apiUpload,
      this.apiDelete,
      this.canDeleteVideo,
      this.maxVideos = 10,
      this.maxSize = 50 * 1024 * 1024,
      this.allowedMimeTypes,
      this.uploadMode = UploadMode.standard,
      this.itemIdResolver,
      this.onVideoUploaded,
      this.onDeleteVideoResponse,
      this.onUploadVideos,
      this.height = 100,
      this.width = 100,
      this.loading,
      this.placeholder = const SizedBox.shrink(),
      this.deleteConfirmationTitle = "Delete video?"}) {
    assert(maxVideos > 0, "maxVideos must be greater than 0");
    assert(maxSize > 0, "maxSize must be greater than 0");
  }

  static bool alwaysAllowDelete(dynamic _) => true;

  final ApiRequest? apiUpload;
  final ApiRequest Function(dynamic item)? apiDelete;
  final dynamic Function() defaultVideos;
  final String? Function(dynamic item) setVideoUrlFromItem;
  final String? Function(dynamic item)? setVideoThumbnailFromItem;
  final bool Function(dynamic item)? canDeleteVideo;
  final int maxVideos;
  final double maxSize;
  final List<String>? allowedMimeTypes;
  final UploadMode uploadMode;
  final String Function(dynamic item)? itemIdResolver;
  final Function(dynamic response)? onVideoUploaded;
  final Function(dynamic response)? onDeleteVideoResponse;

  /// Bypass [MediaApiService] entirely — receives the picked videos and is
  /// responsible for uploading + returning a list of items to merge into the
  /// grid.
  final Future<dynamic> Function(List<PickedFileInfo> videos)? onUploadVideos;

  final double height;
  final double width;
  final Widget? loading;
  final Widget placeholder;
  final String deleteConfirmationTitle;

  @override
  createState() => _GridVideoPickerState();
}

class _GridVideoPickerState extends NyState<GridVideoPicker>
    with MediaHelperMixin {
  final MediaApiService _mediaApiService = MediaApiService();

  List<dynamic> items = [];
  List<PickedFileInfo> _pending = [];

  @override
  get init => () async {
        items = await widget.defaultVideos() ?? [];
      };

  @override
  LoadingStyle get loadingStyle =>
      LoadingStyle.normal(child: widget.loading ?? const MediaLoader());

  String _resolveId(dynamic item) {
    if (widget.itemIdResolver != null) return widget.itemIdResolver!(item);
    if (item is Map && item['id'] != null) return item['id'].toString();
    try {
      final id = (item as dynamic).id;
      if (id != null) return id.toString();
    } catch (_) {}
    throw StateError(
      'Could not resolve ID for item of type ${item.runtimeType}. '
      'Provide an `itemIdResolver` callback.',
    );
  }

  Future<void> _handlePickAndUpload() async {
    if (isLocked('grid_video_upload')) return;
    if (items.length + _pending.length >= widget.maxVideos) {
      showToastSorry(
          description:
              "You can only upload up to ${widget.maxVideos} videos.".tr());
      return;
    }

    fp.FilePickerResult? result;
    try {
      result = await fp.FilePicker.pickFiles(
        type: fp.FileType.video,
        allowMultiple: true,
      );
    } on Exception catch (e) {
      if (MediaPro.instance.debugMode ?? false) {
        if (kDebugMode) print(e.toString());
      }
    }

    if (result == null || result.files.isEmpty) return;

    final remaining = widget.maxVideos - items.length - _pending.length;
    final accepted = <PickedFileInfo>[];
    for (final pf in result.files.take(remaining)) {
      if (pf.path == null) continue;
      final file = File(pf.path!);
      if (file.lengthSync() > widget.maxSize) {
        showToastSorry(
            description:
                "${pf.name} is too large (max ${calculateMaxSizeToReadableFormat(widget.maxSize)})"
                    .tr());
        continue;
      }
      final mimeType = lookupMimeType(pf.path!);
      if (widget.allowedMimeTypes?.isNotEmpty ?? false) {
        if (mimeType == null || !widget.allowedMimeTypes!.contains(mimeType)) {
          showToastSorry(
              description: "${pf.name} has an unsupported type".tr());
          continue;
        }
      }
      accepted.add(PickedFileInfo.fromPlatformFile(pf, mimeType: mimeType));
    }

    if (accepted.isEmpty) return;

    setState(() => _pending = [..._pending, ...accepted]);

    await lockRelease('grid_video_upload', perform: () async {
      try {
        dynamic response;
        if (widget.onUploadVideos != null) {
          response = await widget.onUploadVideos!(accepted);
        } else if (widget.apiUpload != null) {
          response = await _mediaApiService.uploadVideos(
            accepted,
            apiRequest: widget.apiUpload!,
            mode: widget.uploadMode,
          );
        } else {
          printToConsole(
              "apiUpload (or onUploadVideos) is required to upload videos");
          return;
        }

        widget.onVideoUploaded?.call(response);

        if (response is List) {
          setState(() {
            items = [...items, ...response];
          });
        } else if (response != null) {
          setState(() {
            items = [...items, response];
          });
        }
      } finally {
        setState(() {
          _pending = _pending
              .where((p) => !accepted.any((a) => a.path == p.path))
              .toList();
        });
      }
    });
  }

  void _handleDelete(dynamic item) {
    final apiDelete = widget.apiDelete;
    if (apiDelete == null) return;

    confirmAction(() {
      lockRelease('grid_video_delete', perform: () async {
        try {
          dynamic response = await _mediaApiService.deleteImage(item,
              apiRequest: apiDelete(item));
          widget.onDeleteVideoResponse?.call(response);
          setState(() {
            items =
                items.where((i) => _resolveId(i) != _resolveId(item)).toList();
          });
        } catch (e) {
          printToConsole("Delete failed: $e");
        }
      });
    }, title: widget.deleteConfirmationTitle.tr());
  }

  @override
  Widget view(BuildContext context) {
    final tiles = <Widget>[
      ...items.map(_existingTile),
      ..._pending.map(_pendingTile),
      if (items.length + _pending.length < widget.maxVideos) _addTile(),
    ];

    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      children: tiles,
    );
  }

  Widget _existingTile(dynamic item) {
    final thumbnailUrl = widget.setVideoThumbnailFromItem?.call(item);
    final canDelete = widget.canDeleteVideo?.call(item) ?? false;
    return GestureDetector(
      onLongPress: canDelete ? () => _handleDelete(item) : null,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: thumbnailUrl != null && thumbnailUrl.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: thumbnailUrl,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => const Center(child: MediaLoader()),
                  )
                : Container(
                    color: Colors.grey[200],
                    child: const Icon(Icons.videocam_rounded, size: 32),
                  ),
          ),
          const Center(
            child:
                Icon(Icons.play_circle_fill, color: Colors.white70, size: 36),
          ),
          if (canDelete)
            Positioned(
              top: 4,
              right: 4,
              child: GestureDetector(
                onTap: () => _handleDelete(item),
                child: const CircleAvatar(
                  radius: 12,
                  backgroundColor: Colors.black54,
                  child: Icon(Icons.close, size: 14, color: Colors.white),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _pendingTile(PickedFileInfo _) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        color: Colors.grey[300],
        child: const Center(child: MediaLoader()),
      ),
    );
  }

  Widget _addTile() {
    return InkWell(
      onTap: _handlePickAndUpload,
      child: DottedBorder(
        color: Colors.grey,
        child: const Icon(Icons.add_circle_outline, size: 32),
      ),
    );
  }
}

/// Cheap dotted-border substitute. Avoids pulling in a dotted-border package
/// just for the placeholder tile.
class DottedBorder extends StatelessWidget {
  final Color color;
  final Widget child;
  const DottedBorder({super.key, required this.color, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color, width: 1.5),
      ),
      child: Center(child: child),
    );
  }
}
