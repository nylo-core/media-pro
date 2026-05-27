# Media Pro

<p align="center">
  <a href="https://github.com/nylo-core/media-pro/releases/latest"><img src="https://img.shields.io/github/v/release/nylo-core/media-pro?style=plastic" alt="Latest Release Version"></a>
  <a href="https://github.com/nylo-core/media-pro/releases/latest"><img src="https://img.shields.io/github/license/nylo-core/media-pro?style=plastic" alt="Latest Stable Version"></a>
  <a href="https://github.com/nylo-core/media-pro"><img alt="GitHub stars" src="https://img.shields.io/github/stars/nylo-core/media-pro?style=plastic"></a>
</p>

Media Pro is a Flutter package of media widgets — pickers, playback tiles, and a voice recorder — with pluggable backend adapters so you keep your preferred audio/video engine.

## Widgets

| Widget | Purpose |
| --- | --- |
| `SingleImagePicker` | Pick + upload one image. Three styles (custom / compact / simple). |
| `SingleVideoPicker` | Pick + upload one video. Three styles. |
| `SingleAudioPicker` | Pick + upload one audio file via `file_picker`. |
| `SingleFilePicker` | Pick + upload one arbitrary file. |
| `GridImagePicker` | Multi-image grid with drag-reorder, set-main, delete, gzip mode. |
| `GridVideoPicker` | Multi-video grid (poster + play overlay). |
| `AudioMessageTile` | Play/pause/scrub a single audio source. One-playing-at-a-time across tiles via shared controller. |
| `NetworkVideo` | `CachedNetworkImage`-style tile for video — poster + tap to play. |
| `VoiceRecorder` | Hold-to-record or tap-to-record with live waveform, slide-to-cancel, and optional preview-before-send. |

## Installation

```yaml
dependencies:
  media_pro: ^3.0.0-beta.1
```

```bash
dart pub add media_pro
```

## Pickers

### SingleImagePicker

```dart
SingleImagePicker.compact(
  defaultImage: "https://via.placeholder.com/150",
  apiUpload: ApiRequest(url: "https://mysite.com/upload-image"),
  setImageUrlFromResponse: (response) => response['media']?['original_url'],
  allowedMimeTypes: ["image/jpeg", "image/png"],
  maxSize: 1024 * 1024 * 7, // 7MB
);
```

Three styles via sealed `ImagePickerStyle`:

- **Custom** — default constructor, requires a `child` builder.
- **Compact** — `SingleImagePicker.compact(...)` — circular thumbnail with edit badge.
- **Simple** — `SingleImagePicker.simple(...)` — centered thumbnail with label.

### SingleVideoPicker

```dart
SingleVideoPicker.compact(
  videoSource: "gallery", // or "camera"
  options: const VideoPickerOptions(
    maxDuration: Duration(seconds: 30),
    quality: VideoQualityPreset.medium,
  ),
  apiUpload: ApiRequest(url: "https://mysite.com/upload-video"),
  setVideoUrlFromResponse: (response) => response['media']?['original_url'],
  thumbnailGenerator: (file) async {
    // wire video_thumbnail or similar to produce a poster
    return null;
  },
);
```

### SingleAudioPicker

Uses `file_picker` (no camera/gallery distinction).

```dart
SingleAudioPicker.simple(
  options: const AudioPickerOptions(
    allowedExtensions: ['mp3', 'wav', 'm4a'],
    maxDuration: Duration(minutes: 5),
    durationResolver: myDurationReader, // optional, plug in your metadata package
  ),
  apiUpload: ApiRequest(url: "https://mysite.com/upload-audio"),
  setAudioUrlFromResponse: (response) => response['media']?['original_url'],
);
```

### SingleFilePicker

```dart
SingleFilePicker.simple(
  fileType: MediaProFileType.document, // .any | .document | .custom
  // allowedExtensions: ['pdf', 'docx'], // required when fileType is .custom
  apiUpload: ApiRequest(url: "https://mysite.com/upload-file"),
  setFileUrlFromResponse: (response) => response['media']?['original_url'],
);
```

### GridImagePicker

```dart
GridImagePicker(
  maxImages: 8,
  defaultImages: () async => myExistingImages,
  setImageUrlFromItem: (item) => item['original_url'],
  apiUpload: ApiRequest(url: "https://mysite.com/upload-image"),
  uploadMode: UploadMode.standard, // .standard | .sequential | .gzip
  canDeleteImage: GridImagePicker.alwaysAllowDelete,
  apiDeleteImage: (item) => ApiRequest(
    url: "https://mysite.com/delete/${item['id']}",
    method: "delete",
  ),
);
```

### GridVideoPicker

```dart
GridVideoPicker(
  maxVideos: 6,
  defaultVideos: () async => myExistingVideos,
  setVideoUrlFromItem: (item) => item['url'],
  setVideoThumbnailFromItem: (item) => item['thumbnail'],
  apiUpload: ApiRequest(url: "https://mysite.com/upload-video"),
  apiDelete: (item) => ApiRequest(
    url: "https://mysite.com/delete/${item['id']}",
    method: "delete",
  ),
  canDeleteVideo: GridVideoPicker.alwaysAllowDelete,
);
```

## Playback

Audio and video playback widgets use **pluggable adapters** so the package doesn't ship a hard dependency on `just_audio`, `audioplayers`, `video_player`, or any other engine. You write a small adapter against your preferred package and pass it in.

### AudioMessageTile

Render a row of voice notes / podcast tiles where only one plays at a time. Tiles share a single `AudioMessageController` that owns the underlying `AudioPlayerAdapter`.

```dart
final controller = AudioMessageController(myAudioAdapter);

// in build():
for (final url in voiceMessageUrls)
  AudioMessageTile(
    source: url,
    controller: controller,
    duration: const Duration(seconds: 30), // optional, if you know it server-side
    leading: const CircleAvatar(child: Icon(Icons.person)),
  ),
```

Tap play on one tile → it auto-pauses any other tile sharing the controller. The controller exposes `playSource`, `pauseSource`, `toggleSource`, `seek`, plus per-source helpers `isActive(source)` and `isPlayingSource(source)`.

### NetworkVideo

Drop-in network video tile. Renders the poster up-front, defers player initialization until the user taps play, and renders `adapter.buildView()` once initialized.

```dart
NetworkVideo(
  url: 'https://example.com/video.mp4',
  posterUrl: 'https://example.com/poster.jpg',
  adapterFactory: () => MyVideoAdapter(),
  borderRadius: BorderRadius.circular(12),
);
```

## Recording

### VoiceRecorder

WhatsApp / Telegram-style voice message recorder. Idle mic button expands into a recording row with timer + live waveform + cancel UX while active.

**Hold-to-record** (drag left to cancel, release to send):

```dart
VoiceRecorder(
  adapterFactory: () => MyRecorderAdapter(),
  apiUpload: ApiRequest(url: "https://mysite.com/upload-audio"),
  onUploaded: (response) => print(response),
  minDuration: const Duration(milliseconds: 500),
  maxDuration: const Duration(seconds: 60),
);
```

**Tap-to-record** with **preview-before-send** (play back the recording, then send or discard):

```dart
VoiceRecorder(
  mode: RecorderMode.tapToRecord,
  adapterFactory: () => MyRecorderAdapter(),
  previewBeforeSend: true,
  playerFactory: () => MyAudioAdapter(),
  apiUpload: ApiRequest(url: "https://mysite.com/upload-audio"),
);
```

Output options — uploaded via `apiUpload` + `MediaApiService.uploadAudio` (calling `onUploaded`), or handed off as a local path via `onRecorded` for custom flows.

## The adapter pattern

Three adapter interfaces decouple `media_pro` from any specific media engine:

- `AudioPlayerAdapter` — used by `AudioMessageTile` and `VoiceRecorder` (preview).
- `VideoPlayerAdapter` — used by `NetworkVideo`.
- `AudioRecorderAdapter` — used by `VoiceRecorder`.

You write a small wrapper around your preferred package once and pass a factory function. See `example/lib/main.dart` for fully-working stub adapters that demonstrate the lifecycle (real apps wire `just_audio`, `record`, `video_player`, etc.).

## Requirements

### iOS — `Info.plist`

```xml
<key>NSPhotoLibraryUsageDescription</key>
<string>To upload images and videos to your account.</string>
<key>NSCameraUsageDescription</key>
<string>This app requires camera access to record videos and take photos.</string>
<key>NSMicrophoneUsageDescription</key>
<string>This app requires microphone access to record voice messages.</string>
```

### Android — `AndroidManifest.xml`

```xml
<uses-permission android:name="android.permission.READ_MEDIA_IMAGES"/>
<uses-permission android:name="android.permission.READ_MEDIA_VIDEO"/>
<uses-permission android:name="android.permission.READ_MEDIA_AUDIO"/>
<uses-permission android:name="android.permission.RECORD_AUDIO"/>
<uses-permission android:name="android.permission.CAMERA"/>
```

The recorder adapter is responsible for runtime permission requests (it implements `hasPermission()` / `requestPermission()`).

## What's new in 3.0

- **New picker families** — `SingleVideoPicker`, `SingleAudioPicker`, `SingleFilePicker`, `GridVideoPicker`. All follow the same constructor + sealed-style pattern as `SingleImagePicker`.
- **Playback widgets** — `AudioMessageTile` (with shared controller for one-at-a-time coordination) and `NetworkVideo` (poster + tap-to-play, like `CachedNetworkImage` for video).
- **Voice recorder** — `VoiceRecorder` with hold-to-record / tap-to-record modes, live waveform, slide-to-cancel, and optional preview-before-send.
- **Adapter pattern** — `AudioPlayerAdapter`, `VideoPlayerAdapter`, `AudioRecorderAdapter`. Plug in `just_audio` / `audioplayers` / `record` / `video_player` / `media_kit` / etc. without forking the package.
- **Sealed style classes** — `ImagePickerStyle` / `VideoPickerStyle` / `AudioPickerStyle` / `FilePickerStyle` replace string-typed `style` fields. Per-style data lives with its variant; `switch` is exhaustive.
- **`apiUpload` rename** — across all single + grid pickers, the upload `ApiRequest` field is now `apiUpload` (was per-type: `apiUploadImage` / `apiUploadVideo` / etc.).
- **`UploadMode.gzip`** for image grids — smart-tier compression + isolate-based gzip encoding.
- **`ImageCompressionOptions`** with three factory presets (`.aggressive()`, `.preserveQuality()`, default smart tiers).
- **`ApiRequest` per-type field keys** — `videoKey` / `audioKey` / `fileKey` join `imageKey` so each upload type has its own multipart form-field name.
- **`itemIdResolver`** on grid pickers — items no longer need to be `Map`s with an `'id'` key.

> **Migrating from 2.x?** See [CHANGELOG.md](CHANGELOG.md) for the full breaking change list and migration steps.

Try the [example](/example) app — it demonstrates every widget with working stub adapters.

## Changelog

See [CHANGELOG.md](https://github.com/nylo-core/media-pro/blob/master/CHANGELOG.md) for what has changed recently.

## Social

* [Twitter](https://twitter.com/nylo_dev)

## License

The MIT License (MIT). Please view the [License](https://github.com/nylo-core/media_pro/blob/main/LICENSE) file for more information.
