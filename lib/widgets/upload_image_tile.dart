import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Renders a single image tile in the [GridImagePicker] grid.
///
/// When [imageUrl] is non-null, the network image is loaded via
/// [CachedNetworkImage]. When [imageUrl] is null, [placeholder] is rendered
/// in its place — defaults to [SizedBox.shrink].
class UploadImageTile extends StatelessWidget {
  const UploadImageTile(
      {super.key, this.imageUrl, this.placeholder = const SizedBox.shrink()});

  final String? imageUrl;
  final Widget placeholder;

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
          ? placeholder
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
