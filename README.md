# Media Pro

[![pub package](https://img.shields.io/pub/v/media_pro.svg)](https://pub.dartlang.org/packages/media_pro)
[![GitHub stars](https://img.shields.io/github/stars/nylo-core/media_pro)](

Media Pro is a package that provides a set of widgets to help you work with media in your Flutter apps.

This package is part of the <a href="https://nylo.dev" target="_BLANK">Nylo</a> framework, but can be used as a standalone package.

## Features

- Image Picker

The `SingleMediaPicker` widget allows the user to upload a new image from their gallery or camera.
It will handle displaying the new image and updating the state of the parent widget.

### Widgets

- SingleMediaPicker
- GridImagePicker

`SingleImagePicker.compact` is a compact version of the `SingleImagePicker` widget that shows the image and a edit icon around the image.
`SingleImagePicker.simple` is a simple version of the `SingleImagePicker` widget that only shows the image and text to change the image.

``` dart
import 'package:media_pro/media_pro.dart';

SingleImagePicker.compact(
    defaultImage: "https://via.placeholder.com/150",
    apiUploadImage: ApiRequest(url: "https://myserver.test/upload-image"), // The url to send the image too
    setImageUrlFromResponse: (response) { 
    // `setImageUrlFromResponse` this function will set Widget's image from the response. 
    // After the user has selected an image, the [response] will be the response from the server. 
    // Return the image url from the response.
        if (response['media'] == null) return null;
            dynamic media = response['media'];
            return media['original_url'];
        },
),
```

`GridImagePicker` is a widget that allows the user to upload multiple images from their gallery.
    
``` dart
import 'package:media_pro/media_pro.dart';

GridImagePicker(
  maxImages: 8,
  apiUploadImage: ApiRequest(
    url: "https://mysite.com/uploads/animals",
    method: "post",
  ),
  imageQuality: 80,
  allowedMimeTypes: ["image/jpeg", "image/png"],
  maxSize: 1024 * 1024 * 7, // 7mb
  setImageUrlFromItem: (item) {
    if (item['original_url'] == null) return null;
    return item['original_url'];
  },
  setMainImageFromItem: (item) {
    return false;
  },
  apiDeleteImage: (item) {
    return ApiRequest(
      url: "https://mysite.com/uploads/delete/${item['id']}",
      method: "delete",
    );
  },
  apiMainImage: (item) => ApiRequest(
    url: "https://3f5d-58-136-106-77.ngrok-free.app/main",
    method: "post",
  ),
  defaultImages: () async {
    Map<String, dynamic> data = await api<ApiService>((request) => request.get("https://mysite.com/user/animals"));
    Map<String, dynamic> animals = data['animals'];
    return animals.entries.map((e) => e.value).toList();
  },
),
```

## Getting started

### Installation

Add the following to your `pubspec.yaml` file:

``` yaml
dependencies:
  media_pro: ^1.0.0
```

or with Dart:

``` bash
dart pub add media_pro
```

### Requirements

- IOS - info.plist
``` xml
...
<key>NSPhotoLibraryUsageDescription</key>
<string>To upload images to your ...</string>
<key>NSCameraUsageDescription</key>
<string>This app requires access to the camera.</string>
```

### Usage

``` dart
import 'package:media_pro/media_pro.dart';

```

### Coming soon

- [ ] Video Pickers
- [ ] Audio Pickers
- [ ] File Pickers
- [ ] Better documentation

Try the [example](/example) app to see how it works.

## Changelog
Please see [CHANGELOG](https://github.com/nylo-core/media_pro/blob/master/CHANGELOG.md) for more information what has changed recently.

## Social
* [Twitter](https://twitter.com/nylo_dev)

## Licence

The MIT License (MIT). Please view the [License](https://github.com/nylo-core/media_pro/blob/main/LICENSE) File for more information.
