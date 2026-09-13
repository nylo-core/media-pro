import 'dart:io';

import 'package:flutter/material.dart';

/// Local file thumbnail with overlay + circular progress for in-flight uploads.
/// Used by [GridImagePicker] while uploads are in progress.
class PendingUploadTile extends StatelessWidget {
  const PendingUploadTile({
    super.key,
    required this.file,
    this.progress,
    this.overlayColor,
    this.progressColor = Colors.white,
    this.progressStrokeWidth = 3,
    this.borderRadius,
  });

  final File file;
  final double? progress;
  final Color? overlayColor;
  final Color progressColor;
  final double progressStrokeWidth;

  /// Corner radius of the tile and its thumbnail. Defaults to 8.
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final Color effectiveOverlayColor =
        overlayColor ?? Colors.black.withValues(alpha: 0.35);
    final BorderRadius radius = borderRadius ?? BorderRadius.circular(8);
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: radius,
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 1, offset: Offset(0, 0)),
        ],
      ),
      margin: const EdgeInsets.all(8),
      child: ClipRRect(
        borderRadius: radius,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.file(file, fit: BoxFit.cover),
            Container(color: effectiveOverlayColor),
            Center(
              child: SizedBox(
                width: 32,
                height: 32,
                child: CircularProgressIndicator(
                  value: progress,
                  strokeWidth: progressStrokeWidth,
                  color: progressColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
