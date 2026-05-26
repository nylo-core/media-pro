import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_draggable_gridview/flutter_draggable_gridview.dart';
import 'package:image_picker/image_picker.dart';
import 'package:media_pro/mixins/media_helper_mixin.dart';
import 'package:media_pro/models/api_request.dart';
import 'package:media_pro/models/image_compression_options.dart';
import 'package:media_pro/models/upload_mode.dart';
import 'package:media_pro/networking/media_api_service.dart';
import 'package:media_pro/widgets/media_loader.dart';
import 'package:mime/mime.dart';
import 'package:nylo_support/ny_core.dart';

import 'animated_image_tile.dart';
import 'image_uploader.dart';
import 'loading_placeholder_tile.dart';
import 'pending_upload_tile.dart';
import 'upload_image_tile.dart';

/// [GridImagePicker] widget is used to upload and display images in a grid view.
///
/// - [uploadMode] selects the upload strategy ([UploadMode.standard],
///   [UploadMode.sequential] or [UploadMode.gzip]).
/// - [compressionOptions] controls image compression for [UploadMode.gzip].
/// - [itemIdResolver] supplies stable string IDs for items that aren't
///   `Map`s with an `'id'` key. Falls back to `item['id']` (Map) or
///   `item.id` (model) when null.
/// - [onUploadImages] bypasses [MediaApiService] entirely (custom upload flow).
/// - [onDragCompletion] fires after a drag-reorder with the new ID list.
/// - [onImageLongPress] replaces the default action dialog.
/// - [newItemAnimationBuilder], [loadingPlaceholderBuilder] and
///   [pendingTileBuilder] override the default tile widgets.
/// - [canDeleteImage] is a per-item callback (see
///   [GridImagePicker.alwaysAllowDelete] for the always-on shortcut).
class GridImagePicker extends StatefulWidget {
  GridImagePicker(
      {super.key,
      required this.defaultImages,
      required this.setImageUrlFromItem,
      this.apiUpload,
      this.apiMainImage,
      this.apiDeleteImage,
      this.height = 400,
      this.width = 70,
      this.loading,
      this.imageQuality = 80,
      this.canDeleteImage,
      this.canSetMainImage = true,
      this.maxImages = 11,
      this.maxSize = 1024 * 1024 * 7, // 7MB
      this.allowedMimeTypes,
      this.setMainImageFromItem,
      this.onImageUploaded,
      this.onMainImageResponse,
      this.onDeleteImageResponse,
      this.itemIdResolver,
      this.uploadMode = UploadMode.standard,
      this.compressionOptions,
      this.displayValidationHint = true,
      this.placeholder = const SizedBox.shrink(),
      this.onDragCompletion,
      this.onImageLongPress,
      this.onUploadImages,
      this.newItemAnimationBuilder,
      this.loadingPlaceholderBuilder,
      this.pendingTileBuilder,
      this.dragPlaceholderBuilder,
      this.dragFeedbackBuilder,
      this.deleteConfirmationTitle = "Delete image?"}) {
    assert(maxImages > 0, "maxImages must be greater than 0");
    assert(maxSize > 0, "maxSize must be greater than 0");
  }

  /// Convenience helper that always allows deletion regardless of the item.
  /// Pass as `canDeleteImage: GridImagePicker.alwaysAllowDelete`.
  static bool alwaysAllowDelete(dynamic _) => true;

  final ApiRequest? apiUpload;
  final ApiRequest Function(dynamic item)? apiDeleteImage;
  final ApiRequest Function(dynamic item)? apiMainImage;

  final ImagePicker picker = ImagePicker();
  final dynamic Function() defaultImages;
  final double height;
  final double width;
  final Widget? loading;
  final int? imageQuality;

  /// Per-item delete gate. When null, no delete button is rendered. When
  /// supplied, a delete button appears only on items for which this returns
  /// `true`. Use [GridImagePicker.alwaysAllowDelete] to enable for all items.
  final bool Function(dynamic item)? canDeleteImage;
  final bool canSetMainImage;
  final int maxImages;
  final List<dynamic> items = [];
  final double maxSize;
  final List<String>? allowedMimeTypes;

  /// When true (default), shows the bottom hint listing max images and file
  /// constraints.
  final bool displayValidationHint;

  /// Widget shown in empty grid slots when no image is available.
  final Widget placeholder;

  /// Returns a stable string ID for an item. Falls back to `item['id']` (Map
  /// shape) or `item.id` (model with id getter) when null.
  final String Function(dynamic item)? itemIdResolver;

  /// Selects the upload strategy when uploading via [MediaApiService].
  final UploadMode uploadMode;

  /// Compression options forwarded to [MediaApiService.uploadImagesGzip] when
  /// [uploadMode] is [UploadMode.gzip].
  final ImageCompressionOptions? compressionOptions;

  /// Title shown in the Nylo `confirmAction` dialog when deleting an image.
  final String deleteConfirmationTitle;

  final String? Function(dynamic item) setImageUrlFromItem;
  final bool? Function(dynamic item)? setMainImageFromItem;

  /// Fires after a drag-reorder with the new ID list (resolved via
  /// [itemIdResolver]).
  final void Function(List<String> newOrder)? onDragCompletion;

  /// When provided, replaces the default action dialog on long-press.
  final void Function(dynamic item)? onImageLongPress;

  /// When provided, **bypasses** [MediaApiService] entirely. Use for fully
  /// custom upload flows (signed URLs, S3 multipart, etc.).
  final Future<dynamic> Function(List<XFile> images)? onUploadImages;

  /// Replaces the default [AnimatedImageTile] wrapper for newly uploaded items.
  final Widget Function(BuildContext, Widget child)? newItemAnimationBuilder;

  /// Replaces the default [LoadingPlaceholderTile] for empty slots during
  /// upload.
  final Widget Function(BuildContext)? loadingPlaceholderBuilder;

  /// Replaces the default [PendingUploadTile] for in-flight uploads.
  final Widget Function(BuildContext, File file, double? progress)?
      pendingTileBuilder;

  /// Replaces the default drop-target placeholder (a white square) shown at
  /// the destination cell while a tile is being dragged over it.
  final Widget Function(BuildContext)? dragPlaceholderBuilder;

  /// Replaces the default floating widget shown under the finger while
  /// dragging. Receives the dragged tile's child so callers can wrap or
  /// re-style the original content.
  final Widget Function(BuildContext context, Widget child)?
      dragFeedbackBuilder;

  final Function(dynamic response)? onImageUploaded;
  final Function(dynamic response)? onMainImageResponse;
  final Function(dynamic response)? onDeleteImageResponse;

  @override
  createState() => _GridImagePickerState();
}

class _GridImagePickerState extends NyState<GridImagePicker>
    with MediaHelperMixin {
  final MediaApiService _mediaApiService = MediaApiService();

  List<dynamic> items = [];
  List<XFile> _pendingImages = [];
  double? _uploadProgress;
  Set<String> _newItemIds = {};

  @override
  get init => () async {
        items = await widget.defaultImages() ?? [];
      };

  @override
  LoadingStyle get loadingStyle =>
      LoadingStyle.normal(child: widget.loading ?? const MediaLoader());

  /// Resolves a stable string ID for an item.
  ///
  /// Resolution order:
  /// 1. `widget.itemIdResolver` if supplied.
  /// 2. `item['id'].toString()` if the item is a `Map` with a non-null `id`.
  /// 3. `(item as dynamic).id.toString()` if the item exposes an `id` getter.
  /// 4. Throws [StateError] otherwise.
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

  /// Upload new images to the server.
  Future<void> _uploadNewImages(List<XFile> images) async {
    lockRelease('uploading_image', perform: () async {
      if (images.isEmpty) return;
      if (items.length > 11) {
        showToastOops(
            description: "Please remove a photo to add new ones".tr());
        return;
      }
      if ((images.length + items.length) > widget.maxImages) {
        showToastSorry(
            description: "You can only add ${widget.maxImages} images".tr());
        return;
      }

      for (XFile image in images) {
        File file = File(image.path);

        int fileInBytes = file.lengthSync();
        // check if the file is too large
        if (fileInBytes > widget.maxSize) {
          showToastSorry(
              description:
                  "The file is too large. It must be under ${calculateMaxSizeToReadableFormat(widget.maxSize)}"
                      .tr());
          return;
        }

        if (widget.allowedMimeTypes?.isNotEmpty ?? false) {
          final mimeType = lookupMimeType(file.path);
          if (mimeType == null) {
            showToastSorry(description: "Invalid file type".tr());
            return;
          }
          // image/* wildcard accepts any image MIME type.
          if (widget.allowedMimeTypes!.contains("image/*")) {
            continue;
          }
          if (!widget.allowedMimeTypes!.contains(mimeType)) {
            showToastSorry(
                description:
                    "The file type must be one of $extensionsFromMimeTypes"
                        .tr());
            return;
          }
        }
      }

      setState(() {
        _pendingImages = List.from(images);
        _uploadProgress = null;
      });

      dynamic data;
      if (widget.onUploadImages != null) {
        data = await widget.onUploadImages!(images);
      } else {
        if (widget.apiUpload == null) {
          printToConsole("apiUpload is required");
          return;
        }
        data = await _mediaApiService.uploadImagesWithMode(
          images,
          apiRequest: widget.apiUpload!,
          mode: widget.uploadMode,
          compressionOptions: widget.compressionOptions,
          onSendProgress: (sent, total) {
            if (total > 0) {
              setState(() {
                _uploadProgress = sent / total;
              });
            }
          },
        );
      }

      if (widget.onImageUploaded != null) {
        await widget.onImageUploaded!(data);
      }

      await _resetItems();
    });
  }

  /// Get the allowed extensions from the mime types
  String get extensionsFromMimeTypes {
    return widget.allowedMimeTypes
            ?.map((mimeType) => getImageExtensionFromMimeType(mimeType))
            .join(', ') ??
        "";
  }

  @override
  Widget view(BuildContext context) {
    switch (currentState()) {
      case "loading":
        {
          if (widget.loading != null) {
            return widget.loading!;
          }
          return widget.loading ?? const MediaLoader();
        }
      case "default":
        {
          return _default(
            height: widget.height,
            placeholder: widget.placeholder,
          );
        }
      default:
        {
          throw Exception("Invalid state");
        }
    }
  }

  /// Get the current state of the widget
  String currentState() {
    if (isLocked('image_upload')) {
      return 'loading';
    }
    return 'default';
  }

  /// Default style
  Widget _default(
      {double height = 400, Widget placeholder = const SizedBox.shrink()}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ExcludeSemantics works around a `!semantics.parentDataDirty`
        // assertion thrown by `flutter_draggable_gridview` v1.0.0 on
        // Flutter 3.27+. Debug-only; release builds are unaffected.
        ExcludeSemantics(
          child: DraggableGridViewBuilder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: MediaQuery.of(context).size.width / height,
            ),
            children: [
              DraggableGridItem(
                child: ImageUploader(
                  upload: _uploadNewImages,
                  child: isLocked('uploading_image')
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const CupertinoActivityIndicator(),
                            Text("Uploading your images...".tr(),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    fontSize: 12, color: Colors.black87)),
                          ],
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.camera_alt_outlined,
                              color: Colors.black87,
                            ),
                            Text("Upload images".tr()).bodySmall()
                          ],
                        ),
                ),
                isDraggable: false,
                dragCallback: (context, isDragging) {},
              ),
              ...List.generate(
                widget.maxImages,
                (index) {
                  if (index < items.length) {
                    dynamic item = items[index];
                    String? imageUrl = widget.setImageUrlFromItem(item);
                    bool isMainImage = false;
                    if (widget.setMainImageFromItem != null) {
                      isMainImage =
                          (widget.setMainImageFromItem!(item) ?? false);
                    }

                    final bool canDelete =
                        widget.canDeleteImage?.call(item) ?? false;

                    Widget tile = GestureDetector(
                      onLongPress: () {
                        if (widget.onImageLongPress != null) {
                          widget.onImageLongPress!(item);
                        } else {
                          _showImageDialog(item);
                        }
                      },
                      child: Stack(
                        children: [
                          Positioned.fill(
                            bottom: 10,
                            child: UploadImageTile(imageUrl: imageUrl),
                          ),
                          if (isMainImage)
                            Positioned(
                              bottom: 12,
                              left: 0,
                              right: 0,
                              child: Container(
                                decoration: BoxDecoration(
                                    color: Colors.black45,
                                    borderRadius: BorderRadius.circular(8)),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 4),
                                margin:
                                    const EdgeInsets.symmetric(horizontal: 16),
                                child: Text("Main image".tr(),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                    ),
                                    textAlign: TextAlign.center),
                              ),
                            ),
                          if (imageUrl != null && canDelete)
                            Positioned(
                              bottom: 0,
                              left: 0,
                              right: 0,
                              child: Center(
                                child: Container(
                                  width: 32,
                                  height: 32,
                                  alignment: Alignment.bottomCenter,
                                  decoration: const BoxDecoration(
                                    color: Colors.white,
                                    borderRadius:
                                        BorderRadius.all(Radius.circular(20)),
                                  ),
                                  child: IconButton(
                                    onPressed: () {
                                      confirmAction(() {
                                        lockRelease("delete_image",
                                            perform: () async {
                                          dynamic data = await _mediaApiService
                                              .deleteImage(item,
                                                  apiRequest: widget
                                                      .apiDeleteImage!(item));

                                          if (widget.onDeleteImageResponse !=
                                              null) {
                                            await widget
                                                .onDeleteImageResponse!(data);
                                          }

                                          await _resetItems();
                                        });
                                      }, title: widget.deleteConfirmationTitle);
                                    },
                                    icon: Icon(
                                      Icons.delete_forever,
                                      color: Colors.red.shade500,
                                      size: 16,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    );

                    // Apply entrance animation for newly added items.
                    if (_newItemIds.contains(_resolveId(item))) {
                      tile =
                          widget.newItemAnimationBuilder?.call(context, tile) ??
                              AnimatedImageTile(child: tile);
                    }

                    return DraggableGridItem(
                      child: tile,
                      isDraggable: true,
                    );
                  }

                  // Show pending local thumbnails in next available slots.
                  int pendingIndex = index - items.length;
                  if (pendingIndex >= 0 &&
                      pendingIndex < _pendingImages.length) {
                    final File file = File(_pendingImages[pendingIndex].path);
                    final Widget pendingTile = widget.pendingTileBuilder
                            ?.call(context, file, _uploadProgress) ??
                        PendingUploadTile(
                          file: file,
                          progress: _uploadProgress,
                        );
                    return DraggableGridItem(
                      child: pendingTile,
                      isDraggable: false,
                    );
                  }

                  if (isLocked('uploading_image')) {
                    final Widget loadingTile =
                        widget.loadingPlaceholderBuilder?.call(context) ??
                            const LoadingPlaceholderTile();
                    return DraggableGridItem(
                      child: loadingTile,
                      isDraggable: false,
                    );
                  }

                  return DraggableGridItem(
                    child: ImageUploader(
                      upload: _uploadNewImages,
                      imageQuality: widget.imageQuality ?? 80,
                      child: UploadImageTile(placeholder: placeholder),
                    ),
                    isDraggable: false,
                  );
                },
              )
            ],
            isOnlyLongPress: false,
            dragCompletion: (List<DraggableGridItem> list, int beforeIndex,
                int afterIndex) {
              // Slot 0 is the upload button — shift indices into the items list.
              beforeIndex = beforeIndex - 1;
              afterIndex = afterIndex - 1;

              if (beforeIndex < 0 ||
                  afterIndex < 0 ||
                  beforeIndex >= items.length ||
                  afterIndex >= items.length) {
                return;
              }

              dynamic item = items.removeAt(beforeIndex);
              items.insert(afterIndex, item);

              List<String> newOrder = items.map(_resolveId).toList();

              widget.onDragCompletion?.call(newOrder);
            },
            dragFeedback: (List<DraggableGridItem> list, int index) {
              final child = list[index].child;
              if (widget.dragFeedbackBuilder != null) {
                return widget.dragFeedbackBuilder!(context, child);
              }
              return SizedBox(
                height: 200,
                width: 150,
                child: child,
              );
            },
            dragPlaceHolder: (List<DraggableGridItem> list, int index) {
              if (widget.dragPlaceholderBuilder != null) {
                return PlaceHolderWidget(
                  child: Builder(builder: widget.dragPlaceholderBuilder!),
                );
              }
              return PlaceHolderWidget(
                child: Container(
                  color: Colors.white,
                ),
              );
            },
          ),
        ),
        if (widget.displayValidationHint)
          Container(
            margin: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              children: [
                Text("You can upload up to ${widget.maxImages} images".tr())
                    .bodySmall(),
                Text("Files must be under ${calculateMaxSizeToReadableFormat(widget.maxSize)} and $extensionsFromMimeTypes"
                        .tr())
                    .bodySmall(),
              ],
            ),
          ),
      ],
    );
  }

  /// Show the default image action dialog (fallback when [onImageLongPress]
  /// is not provided).
  void _showImageDialog(dynamic item) {
    final bool canDelete = widget.canDeleteImage?.call(item) ?? false;
    final bool showMain =
        widget.canSetMainImage == true && widget.apiMainImage != null;
    final bool showDelete = canDelete && widget.apiDeleteImage != null;

    if (!showMain && !showDelete) {
      return;
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Select an action".tr()),
          content: Container(
            decoration: BoxDecoration(
                border: Border(top: BorderSide(color: Colors.grey[50]!))),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (showMain)
                  ListTile(
                    title: Text("Make main image".tr()),
                    leading: const Icon(Icons.star, color: Colors.teal),
                    onTap: () {
                      lockRelease('make_main_image', perform: () async {
                        dynamic data = await _mediaApiService.setMainImage(
                            apiRequest: widget.apiMainImage!(item));

                        if (widget.onMainImageResponse != null) {
                          await widget.onMainImageResponse!(data);
                        }

                        await _resetItems();
                        pop();
                      });
                    },
                  ),
                if (showDelete)
                  ListTile(
                    title: Text("Delete image".tr()),
                    leading: const Icon(Icons.delete, color: Colors.red),
                    onTap: () {
                      lockRelease('delete_image', perform: () async {
                        dynamic data = await _mediaApiService.deleteImage(item,
                            apiRequest: widget.apiDeleteImage!(item));

                        if (widget.onDeleteImageResponse != null) {
                          await widget.onDeleteImageResponse!(data);
                        }

                        await _resetItems();
                        pop();
                      });
                    },
                  ),
                SizedBox(
                  width: double.infinity,
                  child: MaterialButton(
                    onPressed: pop,
                    child: Text(
                      "Back".tr(),
                    ),
                  ),
                )
              ],
            ),
          ),
        );
      },
    );
  }

  /// Reset the item list, computing which IDs are new for entrance animation.
  Future<void> _resetItems() async {
    dynamic newItems = await widget.defaultImages();

    final Set<String> existingIds = items.map(_resolveId).toSet();
    final Set<String> newIds = {};
    for (final item in (newItems ?? [])) {
      final String id = _resolveId(item);
      if (!existingIds.contains(id)) {
        newIds.add(id);
      }
    }

    setState(() {
      items = newItems ?? [];
      _pendingImages = [];
      _uploadProgress = null;
      _newItemIds = newIds;
    });

    if (newIds.isNotEmpty) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          setState(() {
            _newItemIds = {};
          });
        }
      });
    }
  }
}
