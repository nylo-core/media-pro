import 'package:flutter/foundation.dart';
import 'package:media_pro/media_pro.dart';

/// media_helper_mixin.dart
mixin MediaHelperMixin {
  /// Calculate the maximum size to a readable format
  /// The [maxSize] is the maximum size in bytes
  String calculateMaxSizeToReadableFormat(double maxSize) {
    double size = maxSize;
    if (size < 1024) {
      return "${size}b";
    }
    if (size < 1024 * 1024) {
      return "${(size / 1024).toStringAsFixed(2)}kb";
    }
    if (size < 1024 * 1024 * 1024) {
      return "${(size / 1024 / 1024).toStringAsFixed(2)}mb";
    }
    return "${(size / 1024 / 1024 / 1024).toStringAsFixed(2)}gb";
  }

  /// Get the file extension from the mime type
  /// The [mimeType] is the mime type of the file
  String getImageExtensionFromMimeType(String mimeType) {
    switch (mimeType) {
      case "image/jpeg":
        return ".jpg";
      case "image/png":
        return ".png";
      case "image/gif":
        return ".gif";
      case "image/bmp":
        return ".bmp";
      case "image/webp":
        return ".webp";
      default:
        return ".jpg";
    }
  }

  /// Print to console
  /// The [message] is the message to print
  printToConsole(String message) {
    if (MediaPro.instance.debugMode ?? false) {
      if (kDebugMode) {
        print(message);
      }
    }
  }
}
