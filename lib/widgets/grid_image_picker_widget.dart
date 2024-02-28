import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_draggable_gridview/flutter_draggable_gridview.dart';
import 'package:image_picker/image_picker.dart';
import 'package:media_pro/mixins/media_helper_mixin.dart';
import 'package:media_pro/models/api_request.dart';
import 'package:media_pro/networking/media_api_service.dart';
import 'package:media_pro/widgets/media_loader.dart';
import 'package:mime/mime.dart';
import 'package:nylo_support/helpers/extensions.dart';
import 'package:nylo_support/helpers/helper.dart';
import 'package:nylo_support/localization/app_localization.dart';
import 'package:nylo_support/widgets/ny_state.dart';

/// [GridImagePicker] widget is used to upload and display images in a grid view.
class GridImagePicker extends StatefulWidget {
  GridImagePicker(
      {super.key,
      required this.defaultImages,
      required this.setImageUrlFromItem,
      this.apiUploadImage,
      this.apiMainImage,
      this.apiDeleteImage,
      this.height = 70,
      this.width = 70,
      this.loading,
      this.imageQuality = 80,
      this.canDeleteImage = true,
      this.canSetMainImage = true,
      this.maxImages = 11,
      this.maxSize = 1024 * 1024 * 7, // 7MB
      this.allowedMimeTypes,
      this.setMainImageFromItem,
      this.onImageUploaded,
      this.onMainImageResponse,
      this.onDeleteImageResponse})
      : style = "default" {
    assert(maxImages > 0, "maxImages must be greater than 0");
    assert(maxSize > 0, "maxSize must be greater than 0");
  }

  final ApiRequest? apiUploadImage;
  final ApiRequest Function(dynamic item)? apiDeleteImage;
  final ApiRequest Function(dynamic item)? apiMainImage;

  final ImagePicker picker = ImagePicker();
  final dynamic Function() defaultImages;
  final double height;
  final double width;
  final Widget? loading;
  final int? imageQuality;
  final String? style;
  final bool canDeleteImage;
  final bool canSetMainImage;
  final int maxImages;
  final List<dynamic> items = [];
  final double maxSize;
  final List<String>? allowedMimeTypes;

  final String? Function(dynamic item) setImageUrlFromItem;
  final bool? Function(dynamic item)? setMainImageFromItem;

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

  @override
  init() async {
    items = await widget.defaultImages() ?? [];
  }

  /// Upload new images to the server
  _uploadNewImages(List<XFile> images) async {
    if (images.isEmpty) return;
    if (items.length > 11) {
      showToastOops(description: "Please remove a photo to add new ones".tr());
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
        if (!widget.allowedMimeTypes!.contains(mimeType)) {
          showToastSorry(
              description:
                  "The file type must be one of $extensionsFromMimeTypes".tr());
          return;
        }
      }
    }

    if (widget.apiUploadImage == null) {
      printToConsole("uploadImageUrl is required");
      return;
    }

    dynamic data = await _mediaApiService.uploadImages(images,
        apiRequest: widget.apiUploadImage!);

    if (widget.onImageUploaded != null) {
      await widget.onImageUploaded!(data);
    }

    await _resetItems();
  }

  /// Get the allowed extensions from the mime types
  String get extensionsFromMimeTypes {
    return widget.allowedMimeTypes
            ?.map((mimeType) => getImageExtensionFromMimeType(mimeType))
            .join(', ') ??
        "";
  }

  @override
  Widget build(BuildContext context) {
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
          return match(widget.style, () => {"default": _default()});
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
  Widget _default() {
    return Column(
      children: [
        Flexible(
          child: DraggableGridViewBuilder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: MediaQuery.of(context).size.width /
                  (MediaQuery.of(context).size.height / 3),
            ),
            children: [
              DraggableGridItem(
                child: ImageUploader(
                  upload: _uploadNewImages,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.camera_alt_outlined,
                        color: Colors.black87,
                      ),
                      Text("Upload images".tr()).bodySmall(context)
                    ],
                  ),
                ),
                isDraggable: false,
                dragCallback: (context, isDragging) {
                  // tba...
                },
              ),
              if (items.isNotEmpty)
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

                      return DraggableGridItem(
                        child: InkWell(
                          onTap: () => _showImageDialog(item),
                          child: Stack(
                            children: [
                              Positioned.fill(
                                  child: UploadImageTile(imageUrl: imageUrl)),
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
                                    margin: const EdgeInsets.symmetric(
                                        horizontal: 16),
                                    child: Text("Main image".tr(),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                        textAlign: TextAlign.center),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        isDraggable: false,
                        dragCallback: (context, isDragging) {
                          // tba...
                        },
                      );
                    }
                    return DraggableGridItem(
                      child: const UploadImageTile(),
                      isDraggable: false,
                    );
                  },
                )
            ],
            isOnlyLongPress: false,
            dragCompletion: (List<DraggableGridItem> list, int beforeIndex,
                int afterIndex) {},
            dragFeedback: (List<DraggableGridItem> list, int index) {
              return SizedBox(
                width: 200,
                height: 150,
                child: list[index].child,
              );
            },
            dragPlaceHolder: (List<DraggableGridItem> list, int index) {
              return PlaceHolderWidget(
                child: Container(
                  color: Colors.white,
                ),
              );
            },
          ),
        ),
        Container(
          margin: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            children: [
              Text("You can upload up to ${widget.maxImages} images".tr())
                  .bodySmall(context),
              Text("Files must be under ${calculateMaxSizeToReadableFormat(widget.maxSize)} and $extensionsFromMimeTypes"
                      .tr())
                  .bodySmall(context),
            ],
          ),
        ),
      ],
    );
  }

  /// Show image dialog
  _showImageDialog(dynamic item) {
    if (widget.canSetMainImage == false && widget.canDeleteImage == false) {
      return;
    }
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Select an action".tr()),
          content: Container(
            height: 150,
            decoration: BoxDecoration(
                border: Border(top: BorderSide(color: Colors.grey[50]!))),
            child: Column(
              children: [
                if (widget.canSetMainImage == true &&
                    widget.apiMainImage != null)
                  SizedBox(
                    width: double.infinity,
                    child: MaterialButton(
                      textColor: Colors.teal,
                      onPressed: () async {
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
                      child: Text(
                        "Make main image".tr(),
                      ),
                    ),
                  ),
                if (widget.canDeleteImage == true &&
                    widget.apiDeleteImage != null)
                  SizedBox(
                    width: double.infinity,
                    child: MaterialButton(
                      textColor: Colors.red,
                      onPressed: () async {
                        lockRelease("delete_image", perform: () async {
                          dynamic data = await _mediaApiService.deleteImage(
                              item,
                              apiRequest: widget.apiDeleteImage!(item));

                          if (widget.onDeleteImageResponse != null) {
                            await widget.onDeleteImageResponse!(data);
                          }

                          await _resetItems();
                          pop();
                        });
                      },
                      child: Text(
                        "Delete image".tr(),
                      ),
                    ),
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

  /// Reset items
  _resetItems() async {
    dynamic items = await widget.defaultImages();
    setState(() {
      this.items = items;
    });
  }
}

/// Image uploader
class ImageUploader extends StatefulWidget {
  ImageUploader({
    super.key,
    required this.upload,
    this.child,
    this.imageQuality = 80,
  });

  final ImagePicker picker = ImagePicker();
  final Widget? child;
  final int imageQuality;

  final Function(List<XFile> images) upload;

  @override
  createState() => _ImageUploaderState();
}

class _ImageUploaderState extends NyState<ImageUploader> with MediaHelperMixin {
  _ImageUploaderState();

  _handleImageUpload() async {
    lockRelease('image_upload', perform: () async {
      List<XFile>? images = [];
      try {
        images = await widget.picker
            .pickMultiImage(imageQuality: widget.imageQuality);
      } on Exception catch (e) {
        printToConsole(e.toString());
        return;
      }

      if (!mounted) return;

      await widget.upload(images);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (isLocked('image_upload')) {
      return const MediaLoader();
    }
    return InkWell(
      onTap: _handleImageUpload,
      child: widget.child ??
          Center(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text("Upload an images".tr()),
                ),
              ],
            ),
          ),
    );
  }
}

/// Upload image tile
class UploadImageTile extends StatelessWidget {
  const UploadImageTile({super.key, this.imageUrl});

  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 1,
              offset: Offset(0, 0),
            ),
          ]),
      margin: const EdgeInsets.all(8),
      child: imageUrl == null
          ? const SizedBox.shrink()
          : ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: CachedNetworkImage(
                fit: BoxFit.cover,
                imageUrl: imageUrl ?? "",
              ),
            ),
    );
  }
}
