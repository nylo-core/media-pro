import 'package:flutter_test/flutter_test.dart';
import 'package:media_pro/models/compression_tier.dart';
import 'package:media_pro/models/image_compression_options.dart';

/// Tests for [ImageCompressionOptions] and [CompressionTier]:
/// preset behavior (aggressive/disabled/preserveQuality), smart-tier
/// resolution at boundary file sizes, and value equality.
void main() {
  group('ImageCompressionOptions defaults', () {
    test('default constructor has skipBelowBytes = 1MB', () {
      const options = ImageCompressionOptions();
      expect(options.skipBelowBytes, 1 * 1024 * 1024);
    });

    test('default constructor has maxDimension = 2048', () {
      const options = ImageCompressionOptions();
      expect(options.maxDimension, 2048);
    });

    test('default constructor has 3 tiers', () {
      const options = ImageCompressionOptions();
      expect(options.tiers.length, 3);
    });
  });

  group('ImageCompressionOptions presets', () {
    test('disabled preset returns 100 quality at any size', () {
      final options = ImageCompressionOptions.disabled();
      // Even huge file sizes resolve to 100 quality.
      expect(options.resolveQualityFor(100 * 1024 * 1024), 100);
      // The skipBelowBytes effectively skips re-encoding entirely.
      expect(options.skipBelowBytes, 1 << 62);
    });

    test('aggressive preset uses 60q + 640px max', () {
      final options = ImageCompressionOptions.aggressive();
      expect(options.maxDimension, 640);
      expect(options.resolveQualityFor(0), 60);
      expect(options.resolveQualityFor(50 * 1024 * 1024), 60);
    });

    test('preserveQuality preset returns 95 quality', () {
      final options = ImageCompressionOptions.preserveQuality();
      expect(options.resolveQualityFor(0), 95);
      expect(options.resolveQualityFor(100 * 1024 * 1024), 95);
    });
  });

  group('ImageCompressionOptions.resolveQualityFor — default tiers', () {
    const options = ImageCompressionOptions();

    test('500 KB returns 85 (catch-all)', () {
      expect(options.resolveQualityFor(500 * 1024), 85);
    });

    test('5 MB returns 80 (>4MB tier)', () {
      expect(options.resolveQualityFor(5 * 1024 * 1024), 80);
    });

    test('10 MB returns 75 (>8MB tier)', () {
      expect(options.resolveQualityFor(10 * 1024 * 1024), 75);
    });

    test('100 MB returns 75 (>8MB tier)', () {
      expect(options.resolveQualityFor(100 * 1024 * 1024), 75);
    });
  });

  group('CompressionTier value equality', () {
    test('two tiers with same fields are ==', () {
      const a = CompressionTier(minBytes: 1024, jpegQuality: 80);
      const b = CompressionTier(minBytes: 1024, jpegQuality: 80);
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('tiers with different minBytes are not ==', () {
      const a = CompressionTier(minBytes: 1024, jpegQuality: 80);
      const b = CompressionTier(minBytes: 2048, jpegQuality: 80);
      expect(a, isNot(equals(b)));
    });

    test('tiers with different jpegQuality are not ==', () {
      const a = CompressionTier(minBytes: 1024, jpegQuality: 80);
      const b = CompressionTier(minBytes: 1024, jpegQuality: 75);
      expect(a, isNot(equals(b)));
    });

    test('catch-all tier with null minBytes equals another null minBytes', () {
      const a = CompressionTier(jpegQuality: 85);
      const b = CompressionTier(jpegQuality: 85);
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });
  });

  group('ImageCompressionOptions value equality', () {
    test('two options with same fields are ==', () {
      const a = ImageCompressionOptions();
      const b = ImageCompressionOptions();
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('options with different skipBelowBytes are not ==', () {
      const a = ImageCompressionOptions();
      const b = ImageCompressionOptions(skipBelowBytes: 2 * 1024 * 1024);
      expect(a, isNot(equals(b)));
    });

    test('options with different maxDimension are not ==', () {
      const a = ImageCompressionOptions();
      const b = ImageCompressionOptions(maxDimension: 1024);
      expect(a, isNot(equals(b)));
    });

    test('options with different tiers are not ==', () {
      const a = ImageCompressionOptions(
        tiers: [CompressionTier(jpegQuality: 85)],
      );
      const b = ImageCompressionOptions(
        tiers: [CompressionTier(jpegQuality: 75)],
      );
      expect(a, isNot(equals(b)));
    });
  });
}
