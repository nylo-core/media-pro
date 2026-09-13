import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Renders a single image tile in the [GridImagePicker] grid.
///
/// When [imageUrl] is non-null, the network image is loaded via
/// [CachedNetworkImage]. When [imageUrl] is null, [placeholder] is rendered
/// in its place — defaults to [SizedBox.shrink].
class UploadImageTile extends StatelessWidget {
  const UploadImageTile({
    super.key,
    this.imageUrl,
    this.placeholder = const SizedBox.shrink(),
    this.borderRadius,
  });

  final String? imageUrl;
  final Widget placeholder;

  /// Corner radius of the tile and its image. Defaults to 8.
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final BorderRadius radius = borderRadius ?? BorderRadius.circular(8);
    return Container(
      decoration: BoxDecoration(
        // Follow the ambient theme so empty tiles don't glare on dark UIs.
        color: isDark ? const Color(0xFF1B1E24) : Colors.white,
        borderRadius: radius,
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 1, offset: Offset(0, 0)),
        ],
      ),
      margin: const EdgeInsets.all(8),
      child: imageUrl == null
          ? placeholder
          : ClipRRect(
              borderRadius: radius,
              child: CachedNetworkImage(
                fit: BoxFit.cover,
                imageUrl: imageUrl ?? "",
              ),
            ),
    );
  }
}
