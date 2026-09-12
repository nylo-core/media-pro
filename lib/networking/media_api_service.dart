import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:http_parser/http_parser.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:media_pro/media_pro.dart';
import 'package:nylo_support/ny_core.dart';

/* MediaApiService
|--------------------------------------------------------------------------
| Define your API endpoints
| Learn more https://nylo.dev/docs/7.x/networking
|-------------------------------------------------------------------------- */

class MediaApiService extends NyApiService {
  MediaApiService()
      : super(
          decoders: {},
          useNetworkLogger: MediaPro.instance.debugMode == true,
        );

  @override
  Map<Type, Interceptor> get interceptors => {
        ...super.interceptors,
      };

  /// Upload a single image
  Future uploadImage(XFile image, {required ApiRequest apiRequest}) async {
    FormData formData = FormData();

    Uint8List bytes = await image.readAsBytes();

    formData.files.add(MapEntry(apiRequest.imageKey,
        MultipartFile.fromBytes(bytes, filename: image.name)));

    if (apiRequest.postData != null) {
      formData.fields
          .add(MapEntry(apiRequest.postDataKey, apiRequest.postData));
    }

    /// setup the API for the request
    _setupApiFromRequest(apiRequest);

    Uri uri = Uri.parse(apiRequest.url);

    return await network(
      request: (api) => api.request(uri.path,
          queryParameters: uri.queryParameters,
          data: formData,
          options: Options(method: apiRequest.method.toUpperCase())),
      baseUrl: uri.origin,
      headers: apiRequest.headers,
      handleFailure: apiRequest.onError,
    );
  }

  /// Upload multiple images in a single multipart request (parallel form fields).
  Future uploadImages(List<XFile> images,
      {required ApiRequest apiRequest}) async {
    FormData formData = FormData();

    var i = 0;
    for (var image in images) {
      Uint8List bytes = await image.readAsBytes();
      formData.files.add(MapEntry("${apiRequest.imageKey}[$i]",
          MultipartFile.fromBytes(bytes, filename: image.name)));
      i++;
    }

    if (apiRequest.postData != null) {
      formData.fields
          .add(MapEntry(apiRequest.postDataKey, apiRequest.postData));
    }

    /// setup the API for the request
    _setupApiFromRequest(apiRequest);

    Uri uri = Uri.parse(apiRequest.url);

    return await network(
      request: (api) => api.request(uri.path,
          queryParameters: uri.queryParameters,
          data: formData,
          options: Options(method: apiRequest.method.toUpperCase())),
      baseUrl: uri.origin,
      headers: apiRequest.headers,
      handleFailure: apiRequest.onError,
    );
  }

  /// Upload multiple images sequentially — one image per request.
  /// Use when the server can only accept a single image per call.
  Future uploadImagesSequential(List<XFile> images,
      {required ApiRequest apiRequest}) async {
    for (var image in images) {
      await uploadImage(image, apiRequest: apiRequest);
    }
  }

  /// Upload multiple images with smart compression + gzip.
  /// Sets `Content-Encoding: gzip` header. Server must support gzipped multipart.
  Future uploadImagesGzip(List<XFile> images,
      {required ApiRequest apiRequest,
      void Function(int sent, int total)? onSendProgress,
      ImageCompressionOptions? compressionOptions}) async {
    FormData formData = FormData();
    final ImageCompressionOptions options =
        compressionOptions ?? const ImageCompressionOptions();

    var i = 0;
    for (var image in images) {
      // Read and compress the image data
      Uint8List compressedBytes = await compressImage(image, options: options);

      // Create a GZip compressed version of the image data
      List<int> gzippedData = await compressWithGzip(compressedBytes);

      // Add the compressed data to the form
      formData.files.add(
        MapEntry(
          "${apiRequest.imageKey}[$i]",
          MultipartFile.fromBytes(
            gzippedData,
            filename: "${image.name}.gz",
            contentType: MediaType('application', 'gzip'),
          ),
        ),
      );
      i++;
    }

    if (apiRequest.postData != null) {
      formData.fields
          .add(MapEntry(apiRequest.postDataKey, apiRequest.postData));
    }

    /// setup the API for the request
    _setupApiFromRequest(apiRequest);

    Uri uri = Uri.parse(apiRequest.url);

    // Add Content-Encoding header to indicate GZip compression
    final Map<String, dynamic> headers = {
      ...?apiRequest.headers,
      'Content-Encoding': 'gzip',
    };

    return await network(
      request: (api) => api.request(
        uri.path,
        queryParameters: uri.queryParameters,
        data: formData,
        options: Options(method: apiRequest.method.toUpperCase()),
        onSendProgress: onSendProgress,
      ),
      baseUrl: uri.origin,
      headers: headers,
      handleFailure: apiRequest.onError,
    );
  }

  /// Unified entry point that dispatches to the right upload method based
  /// on [mode]. Used by `GridImagePicker` and exposed for advanced consumers.
  Future uploadImagesWithMode(List<XFile> images,
      {required ApiRequest apiRequest,
      required UploadMode mode,
      ImageCompressionOptions? compressionOptions,
      void Function(int sent, int total)? onSendProgress}) async {
    switch (mode) {
      case UploadMode.standard:
        return uploadImages(images, apiRequest: apiRequest);
      case UploadMode.sequential:
        return uploadImagesSequential(images, apiRequest: apiRequest);
      case UploadMode.gzip:
        return uploadImagesGzip(images,
            apiRequest: apiRequest,
            compressionOptions: compressionOptions,
            onSendProgress: onSendProgress);
    }
  }

  /// Compress an image using smart quality tiers + optional downscale.
  /// Files at or below `options.skipBelowBytes` are returned unchanged.
  Future<Uint8List> compressImage(XFile file,
      {ImageCompressionOptions options =
          const ImageCompressionOptions()}) async {
    final Uint8List bytes = await file.readAsBytes();
    if (bytes.lengthInBytes <= options.skipBelowBytes) return bytes;

    final img.Image? image = img.decodeImage(bytes);
    if (image == null) throw Exception('Failed to decode image');

    img.Image processed = image;
    if (image.width > options.maxDimension ||
        image.height > options.maxDimension) {
      processed = image.width >= image.height
          ? img.copyResize(image,
              width: options.maxDimension, interpolation: options.interpolation)
          : img.copyResize(image,
              height: options.maxDimension,
              interpolation: options.interpolation);
    }

    final int quality = options.resolveQualityFor(bytes.lengthInBytes);
    return Uint8List.fromList(img.encodeJpg(processed, quality: quality));
  }

  /// Compress data using GZip in a background isolate to avoid jank.
  Future<List<int>> compressWithGzip(List<int> data) async {
    return await compute((List<int> data) {
      return gzip.encode(data);
    }, data);
  }

  /// Upload a single video.
  Future uploadVideo(PickedFileInfo video,
      {required ApiRequest apiRequest}) async {
    return _uploadPickedFile(video,
        apiRequest: apiRequest, fieldName: apiRequest.videoKey);
  }

  /// Upload a single audio file.
  Future uploadAudio(PickedFileInfo audio,
      {required ApiRequest apiRequest}) async {
    return _uploadPickedFile(audio,
        apiRequest: apiRequest, fieldName: apiRequest.audioKey);
  }

  /// Upload a single arbitrary file.
  Future uploadFile(PickedFileInfo file,
      {required ApiRequest apiRequest}) async {
    return _uploadPickedFile(file,
        apiRequest: apiRequest, fieldName: apiRequest.fileKey);
  }

  /// Upload multiple videos. [UploadMode.gzip] is rejected — gzip on encoded
  /// video is wasted CPU.
  Future uploadVideos(List<PickedFileInfo> videos,
      {required ApiRequest apiRequest,
      UploadMode mode = UploadMode.standard}) async {
    switch (mode) {
      case UploadMode.standard:
        return _uploadPickedFilesParallel(videos,
            apiRequest: apiRequest, fieldName: apiRequest.videoKey);
      case UploadMode.sequential:
        for (var v in videos) {
          await uploadVideo(v, apiRequest: apiRequest);
        }
        return;
      case UploadMode.gzip:
        throw ArgumentError(
            'UploadMode.gzip is image-only. Use standard or sequential for video.');
    }
  }

  /// Internal: parallel multipart upload of multiple PickedFileInfo in one request.
  Future _uploadPickedFilesParallel(List<PickedFileInfo> files,
      {required ApiRequest apiRequest, required String fieldName}) async {
    FormData formData = FormData();

    var i = 0;
    for (var file in files) {
      if (file.path.isEmpty) {
        throw Exception('PickedFileInfo.path is empty — cannot upload');
      }
      formData.files.add(MapEntry("$fieldName[$i]",
          await MultipartFile.fromFile(file.path, filename: file.name)));
      i++;
    }

    if (apiRequest.postData != null) {
      formData.fields
          .add(MapEntry(apiRequest.postDataKey, apiRequest.postData));
    }

    _setupApiFromRequest(apiRequest);

    Uri uri = Uri.parse(apiRequest.url);

    return await network(
      request: (api) => api.request(uri.path,
          queryParameters: uri.queryParameters,
          data: formData,
          options: Options(method: apiRequest.method.toUpperCase())),
      baseUrl: uri.origin,
      headers: apiRequest.headers,
      handleFailure: apiRequest.onError,
    );
  }

  /// Internal: multipart upload for a [PickedFileInfo] (file_picker / wrapped XFile).
  /// Streams from path rather than reading into memory — files can be large.
  Future _uploadPickedFile(PickedFileInfo file,
      {required ApiRequest apiRequest, required String fieldName}) async {
    if (file.path.isEmpty) {
      throw Exception('PickedFileInfo.path is empty — cannot upload');
    }

    FormData formData = FormData();

    formData.files.add(MapEntry(fieldName,
        await MultipartFile.fromFile(file.path, filename: file.name)));

    if (apiRequest.postData != null) {
      formData.fields
          .add(MapEntry(apiRequest.postDataKey, apiRequest.postData));
    }

    _setupApiFromRequest(apiRequest);

    Uri uri = Uri.parse(apiRequest.url);

    return await network(
      request: (api) => api.request(uri.path,
          queryParameters: uri.queryParameters,
          data: formData,
          options: Options(method: apiRequest.method.toUpperCase())),
      baseUrl: uri.origin,
      headers: apiRequest.headers,
      handleFailure: apiRequest.onError,
    );
  }

  /// Set an image as the main image
  Future setMainImage({required ApiRequest apiRequest}) async {
    FormData formData = FormData();

    if (apiRequest.postData != null) {
      formData.fields
          .add(MapEntry(apiRequest.postDataKey, apiRequest.postData));
    }

    /// setup the API for the request
    _setupApiFromRequest(apiRequest);

    Uri uri = Uri.parse(apiRequest.url);

    return await network(
      request: (api) => api.request(uri.path,
          queryParameters: uri.queryParameters,
          data: formData,
          options: Options(method: apiRequest.method.toUpperCase())),
      baseUrl: uri.origin,
      headers: apiRequest.headers,
      handleFailure: apiRequest.onError,
    );
  }

  /// Delete an image
  Future deleteImage(dynamic item, {required ApiRequest apiRequest}) async {
    FormData formData = FormData();

    if (apiRequest.postData != null) {
      formData.fields.add(MapEntry("data", apiRequest.postData));
    }

    /// setup the API for the request
    _setupApiFromRequest(apiRequest);

    Uri uri = Uri.parse(apiRequest.url);

    return await network(
      request: (api) => api.request(uri.path,
          queryParameters: uri.queryParameters,
          data: formData,
          options: Options(method: apiRequest.method.toUpperCase())),
      baseUrl: uri.origin,
      headers: apiRequest.headers,
      handleFailure: apiRequest.onError,
    );
  }

  /// Set the API request from the [ApiRequest] object.
  /// Note: `baseUrl` and `headers` are now passed per-request to `network()`,
  /// so they are intentionally NOT set here (avoids mutable state leaking
  /// across calls).
  void _setupApiFromRequest(ApiRequest apiRequest) {
    /// Set the method
    setMethod(apiRequest.method.toLowerCase());

    /// Set the connect timeout
    if (apiRequest.connectTimeout != null) {
      setConnectTimeout(apiRequest.connectTimeout!);
    }

    /// Set the receive timeout
    if (apiRequest.receiveTimeout != null) {
      setReceiveTimeout(apiRequest.receiveTimeout!);
    }

    /// Set the send timeout
    if (apiRequest.sendTimeout != null) {
      setSendTimeout(apiRequest.sendTimeout!);
    }
  }
}
