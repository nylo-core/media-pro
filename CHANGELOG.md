## [3.0.0] - 2026-05-26

### Breaking
- `MediaApiService` constructor no longer accepts `BuildContext` — instantiate as `MediaApiService()` (Nylo v7 alignment).
- `MediaApiService.interceptors` is now a getter (`Map<Type, Interceptor> get interceptors`); subclasses must override the getter, not assign a field.
- `GridImagePicker.canDeleteImage` changed from `bool` to `bool Function(dynamic item)?`. Use `GridImagePicker.alwaysAllowDelete` for the previous `true` behavior; omit the param for the previous `false` behavior.
- Picker upload field renamed to `apiUpload` across all `Single*Picker` and `Grid*Picker` widgets (was `apiUploadImage` in 2.x).
- `Single*Picker` style strings replaced by sealed style classes — `ImagePickerStyle`, `VideoPickerStyle`, `AudioPickerStyle`, `FilePickerStyle`. Use the named constructors (`.compact()` / `.simple()`) on each picker; `switch` over the style is exhaustive.
- Minimum Dart SDK bumped to `>=3.5.0`; Flutter `>=3.24.0`.
- `pretty_dio_logger` direct dependency removed. Toggle network logging via `MediaPro.instance.init(debugMode: true)`.

### Added
**New picker families**
- `SingleVideoPicker` — pick + upload one video. `.compact()` / `.simple()` styles, optional `thumbnailGenerator`, `VideoPickerOptions` for `maxDuration` / `quality`.
- `SingleAudioPicker` — pick + upload one audio file via `file_picker`. `AudioPickerOptions` with `allowedExtensions`, `maxDuration`, pluggable `durationResolver`.
- `SingleFilePicker` — pick + upload one arbitrary file. `MediaProFileType` enum (`.any` / `.document` / `.custom`).
- `GridVideoPicker` — multi-video grid with poster + play overlay, drag-reorder, set-main, delete.

**Playback widgets**
- `AudioMessageTile` — play/pause/scrub a single audio source. Shared `AudioMessageController` coordinates one-playing-at-a-time across tiles; exposes `playSource`, `pauseSource`, `toggleSource`, `seek`, and per-source `isActive` / `isPlayingSource` helpers.
- `NetworkVideo` — `CachedNetworkImage`-style video tile. Renders the poster up-front, defers player init until the user taps play.

**Recording**
- `VoiceRecorder` — WhatsApp/Telegram-style hold-to-record (with slide-to-cancel) or tap-to-record modes. Live waveform + timer, optional `previewBeforeSend` flow with play/scrub/discard.

**Adapter pattern**
- `AudioPlayerAdapter`, `VideoPlayerAdapter`, `AudioRecorderAdapter` — plug in `just_audio` / `audioplayers` / `record` / `video_player` / `media_kit` / etc. via a small factory function, without forking the package.

**Upload & compression**
- `UploadMode` enum (`standard`, `sequential`, `gzip`) and new `GridImagePicker.uploadMode` parameter (defaults to `standard` — opt into gzip explicitly).
- `ImageCompressionOptions` data class with smart-tier compression and three factory presets: `.disabled()`, `.aggressive()`, `.preserveQuality()`.
- `CompressionTier` value type for custom quality tiers.
- `MediaApiService.uploadImagesGzip()` — gzip-compressed batch upload with `Content-Encoding: gzip` header and progress callback.
- `MediaApiService.uploadImagesSequential()` — one-image-per-request alternative.
- `MediaApiService.uploadImagesWithMode()` — unified upload dispatcher.
- `MediaApiService.compressImage()` — smart quality tiers + downscale to a configurable max dimension.
- `MediaApiService.compressWithGzip()` — isolate-based gzip via `compute()`.
- `MediaApiService.uploadVideo()`, `uploadAudio()`, `uploadFile()` — companion upload methods for the new picker families.

**API surface**
- `ApiRequest.onError` callback — fires on 4xx/5xx for every network method.
- `ApiRequest` per-type field keys — `videoKey`, `audioKey`, `fileKey` join `imageKey` so each upload type has its own multipart form-field name.
- `PickedFileInfo` value type — uniform representation of a picked file across pickers.

**GridImagePicker**
- `GridImagePicker.itemIdResolver` — abstracts away the `item['id']` assumption (with a fallback chain that handles `Map` and any object exposing an `id` getter).
- `GridImagePicker.compressionOptions` — opt-in compression with full configurability.
- `GridImagePicker.onUploadImages` — bypass `MediaApiService` entirely for custom upload flows.
- `GridImagePicker.onDragCompletion` — fires after a drag-reorder with the new ID list.
- `GridImagePicker.onImageLongPress` — replace the default action dialog with custom long-press behavior.
- `GridImagePicker.displayValidationHint` — toggle the bottom validation text.
- `GridImagePicker.placeholder` — widget shown in empty grid slots.
- `GridImagePicker.deleteConfirmationTitle` — customize the delete confirmation dialog title.
- `GridImagePicker.newItemAnimationBuilder`, `loadingPlaceholderBuilder`, `pendingTileBuilder`, `dragPlaceholderBuilder`, `dragFeedbackBuilder` — replace the default tile widgets and drag visuals with custom builders.

**Public exports**
- New public widgets: `AnimatedImageTile`, `LoadingPlaceholderTile`, `PendingUploadTile`, `UploadImageTile`, `ImageUploader`, `MediaLoader`.
- `MediaApiService` is now exported from the package entry point.

### Changed
- `GridImagePicker` now wires drag-to-reorder properly (was visual-only in 2.x). Items are draggable when there are items to reorder.
- `MediaApiService` upload methods now parse `apiRequest.url` per-request (`Uri.parse`), so query parameters and paths in the URL are honored without leaking state across calls.
- `handleFailure: apiRequest.onError` is now passed on every `MediaApiService` network call (was only on `deleteImage` previously).
- Pulse/animation tiles (`AnimatedImageTile`, `LoadingPlaceholderTile`, `PendingUploadTile`) are now public and customizable via constructor params.
- `VoiceRecorder` waveform now scrolls right-to-left within a fixed slot — newest amplitudes stay visible, older ones clip off the left, no flex overflow when placed in a `Row`.

### Removed
- `pretty_dio_logger` direct dependency.
- `BuildContext` parameter from `MediaApiService` constructor.

### Migration quick reference
| 2.x | 3.0 |
| --- | --- |
| `MediaApiService(buildContext: context)` | `MediaApiService()` |
| `canDeleteImage: true` | `canDeleteImage: GridImagePicker.alwaysAllowDelete` |
| `canDeleteImage: false` | omit the parameter |
| Implicit logging | `MediaPro.instance.init(debugMode: true)` |
| Items must be `Map` with `id` | Any shape; supply `itemIdResolver` for custom |
| `final interceptors = {...}` | `Map<Type, Interceptor> get interceptors => {...}` |
| `style: 'compact'` | `SingleImagePicker.compact(...)` (or matching sealed style) |
| `apiUploadImage: ApiRequest(...)` | `apiUpload: ApiRequest(...)` |

## [2.0.3] - 2024-12-31

* Update copyright year
* pubspec.yaml dependency updates

## [2.0.2] - 2024-12-16

* pubspec.yaml dependency updates

## [2.0.1] - 2024-12-06

* pubspec.yaml dependency updates

## [2.0.0] - 2024-11-25

* Refactor project for Nylo v6
* pubspec.yaml dependency updates

## [1.1.1] - 2024-06-15

* pubspec.yaml dependency updates

## [1.1.0] - 2024-06-10

* Update docs and readme
* pubspec.yaml dependency updates

## [1.0.20] - 2024-06-06

* pubspec.yaml dependency updates

## [1.0.19] - 2024-05-14

* pubspec.yaml dependency updates

## [1.0.18] - 2024-05-14

* pubspec.yaml dependency updates

## [1.0.17] - 2024-05-12

* pubspec.yaml dependency updates

## [1.0.16] - 2024-05-05

* pubspec.yaml dependency updates

## [1.0.15] - 2024-05-02

* pubspec.yaml dependency updates

## [1.0.14] - 2024-05-01

* pubspec.yaml dependency updates

## [1.0.13] - 2024-04-27

* pubspec.yaml dependency updates

## [1.0.12] - 2024-04-26

* pubspec.yaml dependency updates

## [1.0.11] - 2024-04-23

* pubspec.yaml dependency updates

## [1.0.10] - 2024-04-08

* pubspec.yaml dependency updates

## [1.0.9] - 2024-04-01

* pubspec.yaml dependency updates

## [1.0.8] - 2024-03-28

* pubspec.yaml dependency updates

## [1.0.7] - 2024-03-21

* pubspec.yaml dependency updates

## [1.0.6] - 2024-03-11

* pubspec.yaml dependency updates

## [1.0.5] - 2024-03-06

* pubspec.yaml dependency updates

## [1.0.4] - 2024-03-04

* Remove 'v' from version number
* pubspec.yaml dependency updates

## [1.0.3] - 2024-02-28

* Fix workflow

## [1.0.2] - 2024-02-28

* pubspec.yaml dependency updates

## [1.0.1] - 2024-02-27

* Fix `GridImagePicker`

## [1.0.0] - 2024-02-27

* Initial release.
