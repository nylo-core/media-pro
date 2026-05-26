/// This class is used to make API requests.
///
/// The `*Key` fields control the multipart form field name for each upload
/// type. Defaults match the picker family — override only when your endpoint
/// expects a different field name.
class ApiRequest {
  final String url;
  final String method;
  final String imageKey;
  final String videoKey;
  final String audioKey;
  final String fileKey;
  final String postDataKey;
  final Duration? connectTimeout;
  final Duration? sendTimeout;
  final Duration? receiveTimeout;
  final Map<String, dynamic>? headers;
  final dynamic postData;
  final Function(dynamic error)? onError;

  ApiRequest({
    required this.url,
    this.method = "post",
    this.imageKey = "image",
    this.videoKey = "video",
    this.audioKey = "audio",
    this.fileKey = "file",
    this.postDataKey = "data",
    this.connectTimeout,
    this.sendTimeout,
    this.receiveTimeout,
    this.headers,
    this.postData,
    this.onError,
  });
}
