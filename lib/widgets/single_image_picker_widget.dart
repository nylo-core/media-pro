import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';
import 'package:nylo_support/helpers/helper.dart';
import 'package:nylo_support/localization/app_localization.dart';
import 'package:nylo_support/widgets/ny_state.dart';
import '/media_pro.dart';
import '/mixins/media_helper_mixin.dart';
import '/networking/media_api_service.dart';
import '/widgets/media_loader.dart';

/// [SingleImagePicker] widget can be used to upload a single image
/// from the gallery. It can be used in three different styles:
/// - default
/// - compact
/// - simple
///
/// The [default] style is the default style and it allows you to
/// pass a custom child widget to the [SingleImagePicker] widget.
///
/// The [compact] style is a compact version of the [SingleImagePicker]
/// widget. It is a small widget that can be used in a compact space.
///
/// The [simple] style is a simple version of the [SingleImagePicker]
/// widget. It is a simple widget that can be used in a simple space.
///
/// The [SingleImagePicker] widget requires the [uploadUrl] parameter
/// to be set. The [uploadUrl] parameter is the URL to which the image
/// will be uploaded.
///
/// The [setImageUrlFromResponse] parameter is a function that can be used
/// to set the image from the response. It is a function that takes the
/// response as a parameter and returns the image.
class SingleImagePicker extends StatefulWidget {
  SingleImagePicker(
      {super.key,
      required this.child,
      this.defaultImage,
      this.onError,
      this.height = 70,
      this.width = 70,
      this.loading,
      this.apiUploadImage,
      required this.setImageUrlFromResponse,
      this.imageQuality = 80,
      this.imageSource = "gallery", // camera, gallery
      this.cameraDevice = "rear", // rear, front
      this.canUpdate = true,
      this.borderRadius,
      this.maxSize,
      this.allowedMimeTypes})
      : style = "default";

  /// Compact style
  /// The [compact] style is a compact version of the [SingleImagePicker]
  SingleImagePicker.compact(
      {super.key,
      this.defaultImage,
      this.height = 100,
      this.width = 100,
      this.onError,
      this.loading,
      this.apiUploadImage,
      required this.setImageUrlFromResponse,
      this.imageQuality = 80,
      this.imageSource = "gallery", // camera, gallery
      this.cameraDevice = "rear", // rear, front
      this.canUpdate = true,
      this.borderRadius,
      this.maxSize,
      this.allowedMimeTypes})
      : style = "compact",
        child = null;

  /// Simple style
  /// The [simple] style is a simple version of the [SingleImagePicker]
  SingleImagePicker.simple(
      {super.key,
      this.defaultImage,
      this.height = 70,
      this.width = 70,
      this.onError,
      this.loading,
      this.apiUploadImage,
      required this.setImageUrlFromResponse,
      this.imageQuality = 80,
      this.imageSource = "gallery", // camera, gallery
      this.cameraDevice = "rear", // rear, front
      this.canUpdate = true,
      this.borderRadius,
      this.maxSize,
      this.allowedMimeTypes})
      : style = "simple",
        child = null;

  final ImagePicker picker = ImagePicker();
  final Widget Function(BuildContext context, Function upload)? child;
  final dynamic defaultImage;
  final double height;
  final double width;
  final Function? onError;
  final Widget? loading;
  final ApiRequest? apiUploadImage;
  final int? imageQuality;
  final Function(dynamic response) setImageUrlFromResponse;
  final String? style;
  final String imageSource;
  final String cameraDevice;
  final bool canUpdate;
  final BorderRadius? borderRadius;
  final double? maxSize;
  final List<String>? allowedMimeTypes;

  @override
  createState() => _SingleImagePickerState();
}

class _SingleImagePickerState extends NyState<SingleImagePicker>
    with MediaHelperMixin {
  final MediaApiService _mediaApiService = MediaApiService();

  dynamic _defaultImage;

  @override
  get init => () {
        _defaultImage = widget.defaultImage;
      };

  /// Handle image upload
  _handleImageUpload() async {
    if (widget.canUpdate == false) return;
    if (!mounted) return;
    lockRelease('image_upload', perform: () async {
      XFile? image;
      try {
        ImageSource source = widget.imageSource == "camera"
            ? ImageSource.camera
            : ImageSource.gallery;
        CameraDevice cameraDevice = widget.cameraDevice == "rear"
            ? CameraDevice.rear
            : CameraDevice.front;
        image = await widget.picker.pickImage(
            source: source,
            imageQuality: widget.imageQuality,
            preferredCameraDevice: cameraDevice);
      } on Exception catch (e) {
        if (MediaPro.instance.debugMode ?? false) {
          if (kDebugMode) {
            print(e.toString());
          }
        }
      }

      if (image == null) {
        return;
      }

      File file = File(image.path);
      if (widget.maxSize != null) {
        int fileInBytes = file.lengthSync();
        // check if the file is too large
        if (fileInBytes > (widget.maxSize!)) {
          showToastSorry(
              description:
                  "The file is too large. It must be under ${calculateMaxSizeToReadableFormat(widget.maxSize!)}"
                      .tr());
          return;
        }
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
                  "The file type must be one of ${widget.allowedMimeTypes?.map((mimeType) => getImageExtensionFromMimeType(mimeType)).join(', ')}"
                      .tr());
          return;
        }
      }

      if (widget.apiUploadImage == null) {
        printToConsole("apiUploadImage parameter is required to upload image");
        return;
      }

      dynamic imageResponse = await _mediaApiService.uploadImage(
        image,
        apiRequest: widget.apiUploadImage!,
      );

      String? imageUploaded = widget.setImageUrlFromResponse(imageResponse);
      if (imageUploaded != null) {
        _defaultImage = imageUploaded;
      }
    });
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
          return match(
              widget.style,
              () => {
                    "compact": _compact(),
                    "simple": _simple(),
                    "default": widget.child != null
                        ? widget.child!(context, _handleImageUpload)
                        : SizedBox.shrink()
                  });
        }
      default:
        {
          return const SizedBox();
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

  /// Find the image widget
  Widget _findImageWidget() {
    if (_defaultImage == null) {
      return Container(
        height: widget.height,
        width: widget.width,
        decoration: BoxDecoration(color: Colors.grey[50]),
        child: const Icon(Icons.camera_enhance_rounded),
      );
    }

    if (_defaultImage is String) {
      return CachedNetworkImage(
        imageUrl: _defaultImage ?? "",
        height: widget.height,
        width: widget.width,
        fit: BoxFit.cover,
        placeholder: (context, url) => const Center(
          child: MediaLoader(),
        ),
      );
    }

    if (_defaultImage is Image) {
      return _defaultImage;
    }

    throw Exception("Invalid image type");
  }

  /// Compact style
  Widget _compact() {
    return GestureDetector(
      onTap: _handleImageUpload,
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
                child: _findImageWidget(),
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
              )
          ],
        ),
      ),
    );
  }

  /// Simple style
  Widget _simple() {
    return InkWell(
      onTap: _handleImageUpload,
      child: Center(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ClipRRect(
              borderRadius: widget.borderRadius ?? BorderRadius.circular(50),
              child: _findImageWidget(),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
            ),
            Text("Upload an image".tr()),
          ],
        ),
      ),
    );
  }
}
