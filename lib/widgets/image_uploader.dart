import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:media_pro/mixins/media_helper_mixin.dart';
import 'package:media_pro/widgets/media_loader.dart';
import 'package:nylo_support/ny_core.dart';

/// Tappable widget that opens the image picker and forwards the selected
/// images to the supplied [upload] callback.
///
/// When [upload] is null the widget renders as disabled (the gesture detector
/// receives a null `onTap`). While the picker is in flight a [MediaLoader]
/// is shown via the `image_upload` lock.
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

  final Function(List<XFile> images)? upload;

  @override
  createState() => _ImageUploaderState();
}

class _ImageUploaderState extends NyState<ImageUploader> with MediaHelperMixin {
  _ImageUploaderState();

  Future<void> _handleImageUpload() async {
    if (widget.upload == null) return;
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

      await widget.upload!(images);
    });
  }

  @override
  Widget view(BuildContext context) {
    if (isLocked('image_upload')) {
      return const MediaLoader();
    }

    return GestureDetector(
      onTap: (widget.upload == null) ? null : _handleImageUpload,
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
