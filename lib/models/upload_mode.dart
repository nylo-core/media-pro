/// Strategy for batch image uploads in [GridImagePicker] and [MediaApiService].
enum UploadMode {
  /// Standard parallel multipart upload. Default. No compression, no gzip.
  /// Equivalent to [MediaApiService.uploadImages].
  standard,

  /// Sequential multipart upload — one image per request.
  /// Use when the server can only accept one image at a time.
  /// Equivalent to [MediaApiService.uploadImagesSequential].
  sequential,

  /// Compressed batch upload with smart quality tiers + gzip.
  /// Sets `Content-Encoding: gzip` header. Server must support gzip multipart.
  /// Equivalent to [MediaApiService.uploadImagesGzip].
  gzip,
}
