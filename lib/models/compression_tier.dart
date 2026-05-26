/// One quality tier in an [ImageCompressionOptions] tier list.
class CompressionTier {
  /// Minimum byte size this tier applies to.
  /// `null` means catch-all (used when no other tier matches).
  final int? minBytes;

  /// JPEG quality (0-100) for files in this tier.
  final int jpegQuality;

  const CompressionTier({this.minBytes, required this.jpegQuality});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CompressionTier &&
          minBytes == other.minBytes &&
          jpegQuality == other.jpegQuality;

  @override
  int get hashCode => Object.hash(minBytes, jpegQuality);
}
