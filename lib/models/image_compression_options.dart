import 'package:image/image.dart' as img;
import 'compression_tier.dart';

/// Configuration for in-place image compression before upload.
class ImageCompressionOptions {
  /// Files at or below this byte size are returned unchanged (no re-encode).
  /// Default: 1 MB.
  final int skipBelowBytes;

  /// Maximum dimension (longest side) in pixels. Larger images are downscaled
  /// preserving aspect ratio. Default: 2048.
  final int maxDimension;

  /// Quality tiers, evaluated in `minBytes` descending order.
  /// First match wins. Include one tier with `minBytes: null` as catch-all.
  final List<CompressionTier> tiers;

  /// Interpolation algorithm for downscaling. Default: linear.
  final img.Interpolation interpolation;

  const ImageCompressionOptions({
    this.skipBelowBytes = 1 * 1024 * 1024,
    this.maxDimension = 2048,
    this.tiers = const [
      CompressionTier(minBytes: 8 * 1024 * 1024, jpegQuality: 75),
      CompressionTier(minBytes: 4 * 1024 * 1024, jpegQuality: 80),
      CompressionTier(jpegQuality: 85),
    ],
    this.interpolation = img.Interpolation.linear,
  });

  /// Disables compression entirely. `compressImage` returns the original bytes.
  factory ImageCompressionOptions.disabled() => const ImageCompressionOptions(
    skipBelowBytes: 1 << 62,
    tiers: [CompressionTier(jpegQuality: 100)],
  );

  /// Aggressive compression for bandwidth-constrained scenarios.
  /// Downscale to 640px, 60% quality.
  factory ImageCompressionOptions.aggressive() => const ImageCompressionOptions(
    skipBelowBytes: 0,
    maxDimension: 640,
    tiers: [CompressionTier(jpegQuality: 60)],
  );

  /// Preserve maximum quality (still re-encodes if over [skipBelowBytes]).
  /// No downscale, 95% quality.
  factory ImageCompressionOptions.preserveQuality() =>
      const ImageCompressionOptions(
        maxDimension: 1 << 30,
        tiers: [CompressionTier(jpegQuality: 95)],
      );

  /// Resolves the JPEG quality for a file of the given size, walking the
  /// tier list in `minBytes` descending order. Tiers with `null` minBytes
  /// are treated as catch-all and evaluated last.
  int resolveQualityFor(int fileBytes) {
    final List<CompressionTier> sorted = [...tiers]
      ..sort((a, b) => (b.minBytes ?? -1).compareTo(a.minBytes ?? -1));
    for (final tier in sorted) {
      if (tier.minBytes == null || fileBytes > tier.minBytes!) {
        return tier.jpegQuality;
      }
    }
    return 85;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! ImageCompressionOptions) return false;
    if (skipBelowBytes != other.skipBelowBytes) return false;
    if (maxDimension != other.maxDimension) return false;
    if (interpolation != other.interpolation) return false;
    if (tiers.length != other.tiers.length) return false;
    for (var i = 0; i < tiers.length; i++) {
      if (tiers[i] != other.tiers[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(
    skipBelowBytes,
    maxDimension,
    interpolation,
    Object.hashAll(tiers),
  );
}
