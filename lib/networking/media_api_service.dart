import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:media_pro/models/api_request.dart';
import 'package:nylo_support/networking/ny_api_service.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';

/* MediaApiService
|--------------------------------------------------------------------------
| Define your API endpoints
| Learn more https://nylo.dev/docs/6.x/networking
|-------------------------------------------------------------------------- */

class MediaApiService extends NyApiService {
  MediaApiService({BuildContext? buildContext})
      : super(
          buildContext,
          decoders: {},
        );

  @override
  final interceptors = {
    PrettyDioLogger: PrettyDioLogger(),
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

    /// Set the API request
    _setupApiFromRequest(apiRequest);

    /// Send the request
    return await network(
      request: (api) => api.request("/", data: formData),
    );
  }

  /// Upload multiple images
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

    return await network(
      request: (api) => api.request("/", data: formData),
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

    return await network(
      request: (api) => api.request("/", data: formData),
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

    return await network(
      request: (api) => api.request("/", data: formData),
    );
  }

  /// Set the API request from the [ApiRequest] object
  _setupApiFromRequest(ApiRequest apiRequest) {
    /// Set the base URL
    setBaseUrl(apiRequest.url);

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

    /// Set the headers
    if (apiRequest.headers != null) {
      setHeaders(apiRequest.headers!);
    }
  }
}
