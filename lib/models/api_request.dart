/// This class is used to make API requests
class ApiRequest {
  final String url;
  final String method;
  final String imageKey;
  final String postDataKey;
  final Duration? connectTimeout;
  final Duration? sendTimeout;
  final Duration? receiveTimeout;
  final Map<String, dynamic>? headers;
  final dynamic postData;

  ApiRequest({
    required this.url,
    this.method = "post",
    this.imageKey = "image",
    this.postDataKey = "data",
    this.connectTimeout,
    this.sendTimeout,
    this.receiveTimeout,
    this.headers,
    this.postData,
  });
}
