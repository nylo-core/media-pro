import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:media_pro/media_pro.dart';
import 'package:nylo_support/ny_core.dart';

void main() async {
  final Nylo nylo = await Nylo.init(
    env: (String key, {dynamic defaultValue}) => defaultValue,
  );
  nylo.addEventBus();
  MediaPro.instance.init(debugMode: true);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Media Pro v3',
      navigatorKey: NyNavigator.instance.router.navigatorKey,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 7,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Media Pro v3'),
          bottom: const TabBar(isScrollable: true, tabs: [
            Tab(icon: Icon(Icons.image), text: 'Image'),
            Tab(icon: Icon(Icons.grid_on), text: 'Grid'),
            Tab(icon: Icon(Icons.compress), text: 'Gzip'),
            Tab(icon: Icon(Icons.brush), text: 'Custom'),
            Tab(icon: Icon(Icons.videocam), text: 'Video'),
            Tab(icon: Icon(Icons.music_note), text: 'Audio'),
            Tab(icon: Icon(Icons.insert_drive_file), text: 'File'),
          ]),
        ),
        body: const SafeArea(
          child: TabBarView(children: [
            _SingleTab(),
            _StandardGridTab(),
            _GzipGridTab(),
            _CustomBuildersTab(),
            _VideoTab(),
            _AudioTab(),
            _FileTab(),
          ]),
        ),
      ),
    );
  }
}

/// Tab 1: Demonstrates [SingleImagePicker.compact] — the simplest entry point
/// for picking and uploading a single image.
class _SingleTab extends StatelessWidget {
  const _SingleTab();

  @override
  Widget build(BuildContext context) {
    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'SingleImagePicker.compact',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text(
          'Pick one image, validate size + MIME, and upload via ApiRequest.',
        ),
        const SizedBox(height: 16),
        SingleImagePicker.compact(
          maxSize: 1024 * 1024 * 7,
          setImageUrlFromResponse: (response) {
            if (response['media'] == null) return null;
            return response['media']['original_url'];
          },
          apiUpload: ApiRequest(
            url: "https://mysite.com/upload/animals",
            method: "post",
            postData: {"name": "dog"},
            headers: {"Authorization": "Bearer token here"},
          ),
          allowedMimeTypes: ["image/jpeg", "image/png"],
        ),
      ],
    );
  }
}

/// Tab 2: Demonstrates the default [GridImagePicker] with [UploadMode.standard]
/// and Map-shaped items (the implicit `id` fallback applies, so no
/// `itemIdResolver` is required).
class _StandardGridTab extends StatelessWidget {
  const _StandardGridTab();

  @override
  Widget build(BuildContext context) {
    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'GridImagePicker (standard)',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text(
          'Standard parallel multipart upload, drag-reorder, set-main, and '
          'per-item delete via the Map fallback id resolver.',
        ),
        const SizedBox(height: 16),
        GridImagePicker(
          defaultImages: () async => <Map<String, dynamic>>[
            {
              'id': 1,
              'url': 'https://picsum.photos/seed/grid1/150/150',
              'is_main': true
            },
            {'id': 2, 'url': 'https://picsum.photos/seed/grid2/150/150'},
            {'id': 3, 'url': 'https://picsum.photos/seed/grid3/150/150'},
          ],
          setImageUrlFromItem: (item) => item['url'] as String?,
          apiUpload: ApiRequest(
            url: 'https://mysite.com/upload/animals',
            method: 'post',
          ),
          apiDeleteImage: (item) => ApiRequest(
            url: 'https://mysite.com/delete/${item['id']}',
            method: 'delete',
          ),
          apiMainImage: (item) => ApiRequest(
            url: 'https://mysite.com/main/${item['id']}',
            method: 'post',
          ),
          canDeleteImage: GridImagePicker.alwaysAllowDelete,
          setMainImageFromItem: (item) => item['is_main'] as bool? ?? false,
          onDragCompletion: (newOrder) {
            debugPrint('New order: $newOrder');
          },
        ),
      ],
    );
  }
}

/// A tiny model used by [_GzipGridTab] to demonstrate the
/// [GridImagePicker.itemIdResolver] hook for non-Map items.
class Photo {
  final String uuid;
  final String url;
  const Photo(this.uuid, this.url);
}

/// Tab 3: Demonstrates [GridImagePicker] with [UploadMode.gzip], aggressive
/// compression, and a custom item shape ([Photo]) wired up via
/// `itemIdResolver`.
class _GzipGridTab extends StatelessWidget {
  const _GzipGridTab();

  @override
  Widget build(BuildContext context) {
    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'GridImagePicker (gzip + aggressive compression)',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text(
          'Compresses each image (640px max, q=60) then gzip-encodes the batch '
          'before upload. Items are typed `Photo` instances resolved via '
          'itemIdResolver.',
        ),
        const SizedBox(height: 16),
        GridImagePicker(
          uploadMode: UploadMode.gzip,
          compressionOptions: ImageCompressionOptions.aggressive(),
          defaultImages: () async => const <Photo>[
            Photo('a', 'https://picsum.photos/seed/photoa/150/150'),
            Photo('b', 'https://picsum.photos/seed/photob/150/150'),
          ],
          itemIdResolver: (item) => (item as Photo).uuid,
          setImageUrlFromItem: (item) => (item as Photo).url,
          apiUpload: ApiRequest(
            url: 'https://mysite.com/upload/animals',
            method: 'post',
          ),
          onImageUploaded: (response) {
            debugPrint('Uploaded: $response');
          },
        ),
      ],
    );
  }
}

/// Tab 4: Demonstrates the three builder hooks that let you swap the default
/// pending tile, new-item entrance animation, and empty-slot placeholder.
class _CustomBuildersTab extends StatelessWidget {
  const _CustomBuildersTab();

  @override
  Widget build(BuildContext context) {
    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'GridImagePicker (custom builders)',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text(
          'pendingTileBuilder, newItemAnimationBuilder, and '
          'loadingPlaceholderBuilder replace the default tile widgets.',
        ),
        const SizedBox(height: 16),
        GridImagePicker(
          defaultImages: () async => <Map<String, dynamic>>[
            {'id': 1, 'url': 'https://picsum.photos/seed/custom1/150/150'},
          ],
          setImageUrlFromItem: (item) => item['url'] as String?,
          apiUpload: ApiRequest(
            url: 'https://mysite.com/upload/animals',
            method: 'post',
          ),
          pendingTileBuilder: (context, file, progress) => Container(
            color: Colors.amber,
            child: Text(
              'Uploading: ${((progress ?? 0) * 100).toStringAsFixed(0)}%',
            ),
          ),
          newItemAnimationBuilder: (context, child) => RotationTransition(
            turns: const AlwaysStoppedAnimation(0.05),
            child: child,
          ),
          loadingPlaceholderBuilder: (context) => const ColoredBox(
            color: Colors.green,
          ),
        ),
      ],
    );
  }
}

/// Stub audio adapter that simulates playback with a timer. Real apps wire
/// up `just_audio` / `audioplayers` / `flutter_sound` here — the
/// [AudioPlayerAdapter] interface is what makes the player swap-able.
class _FakeAudioAdapter implements AudioPlayerAdapter {
  final _position = StreamController<Duration>.broadcast();
  final _duration = StreamController<Duration?>.broadcast();
  final _playing = StreamController<bool>.broadcast();

  Timer? _timer;
  Duration _pos = Duration.zero;
  Duration? _dur;
  bool _isPlaying = false;

  @override
  Future<void> load(String source) async {
    _pos = Duration.zero;
    _dur = const Duration(seconds: 30);
    _position.add(_pos);
    _duration.add(_dur);
    _isPlaying = false;
    _playing.add(false);
    _timer?.cancel();
  }

  @override
  Future<void> play() async {
    if (_isPlaying) return;
    _isPlaying = true;
    _playing.add(true);
    _timer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (_dur != null && _pos >= _dur!) {
        pause();
        return;
      }
      _pos += const Duration(milliseconds: 100);
      _position.add(_pos);
    });
  }

  @override
  Future<void> pause() async {
    _isPlaying = false;
    _playing.add(false);
    _timer?.cancel();
    _timer = null;
  }

  @override
  Future<void> seek(Duration position) async {
    _pos = position;
    _position.add(_pos);
  }

  @override
  Future<void> dispose() async {
    _timer?.cancel();
    await _position.close();
    await _duration.close();
    await _playing.close();
  }

  @override
  Stream<Duration> get positionStream => _position.stream;
  @override
  Stream<Duration?> get durationStream => _duration.stream;
  @override
  Stream<bool> get playingStream => _playing.stream;
}

/// Stub video adapter — buildView renders a gradient with a position counter
/// instead of a real video. Real apps wire `video_player` / `media_kit` here.
class _FakeVideoAdapter implements VideoPlayerAdapter {
  final _position = StreamController<Duration>.broadcast();
  final _duration = StreamController<Duration?>.broadcast();
  final _playing = StreamController<bool>.broadcast();
  final _initialized = StreamController<bool>.broadcast();

  Timer? _timer;
  Duration _pos = Duration.zero;
  bool _isPlaying = false;
  bool _isInit = false;

  @override
  double? get aspectRatio => _isInit ? 16 / 9 : null;

  @override
  Future<void> initialize(String source) async {
    await Future.delayed(const Duration(milliseconds: 600));
    _isInit = true;
    _initialized.add(true);
    _duration.add(const Duration(seconds: 10));
  }

  @override
  Future<void> play() async {
    if (_isPlaying) return;
    _isPlaying = true;
    _playing.add(true);
    _timer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      _pos += const Duration(milliseconds: 100);
      _position.add(_pos);
    });
  }

  @override
  Future<void> pause() async {
    _isPlaying = false;
    _playing.add(false);
    _timer?.cancel();
    _timer = null;
  }

  @override
  Future<void> seek(Duration position) async {
    _pos = position;
    _position.add(_pos);
  }

  @override
  Future<void> dispose() async {
    _timer?.cancel();
    await _position.close();
    await _duration.close();
    await _playing.close();
    await _initialized.close();
  }

  @override
  Widget buildView() {
    return StreamBuilder<Duration>(
      stream: _position.stream,
      builder: (context, snap) {
        return Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.deepPurple, Colors.indigo],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            'fake video — ${(_pos.inMilliseconds / 1000).toStringAsFixed(1)}s',
            style: const TextStyle(color: Colors.white, fontSize: 18),
          ),
        );
      },
    );
  }

  @override
  Stream<Duration> get positionStream => _position.stream;
  @override
  Stream<Duration?> get durationStream => _duration.stream;
  @override
  Stream<bool> get playingStream => _playing.stream;
  @override
  Stream<bool> get initializedStream => _initialized.stream;
}

/// Stub recorder — writes an empty file and emits random amplitudes.
/// Real apps wire `record` / `flutter_sound` against [AudioRecorderAdapter].
class _FakeRecorderAdapter implements AudioRecorderAdapter {
  final _amplitude = StreamController<double>.broadcast();
  final _duration = StreamController<Duration>.broadcast();
  final _state = StreamController<RecorderState>.broadcast();

  Timer? _ampTimer;
  Timer? _durTimer;
  Duration _elapsed = Duration.zero;
  String? _path;
  final _rng = Random();

  @override
  Future<bool> hasPermission() async => true;

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<String> start({String? path}) async {
    _path = path ??
        '${Directory.systemTemp.path}/fake_voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
    File(_path!).writeAsStringSync('');
    _elapsed = Duration.zero;
    _state.add(RecorderState.recording);

    _ampTimer = Timer.periodic(const Duration(milliseconds: 80), (_) {
      _amplitude.add(_rng.nextDouble());
    });
    _durTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      _elapsed += const Duration(milliseconds: 100);
      _duration.add(_elapsed);
    });
    return _path!;
  }

  @override
  Future<String?> stop() async {
    _ampTimer?.cancel();
    _durTimer?.cancel();
    _state.add(RecorderState.stopped);
    return _path;
  }

  @override
  Future<void> cancel() async {
    _ampTimer?.cancel();
    _durTimer?.cancel();
    if (_path != null) {
      final f = File(_path!);
      if (f.existsSync()) f.deleteSync();
    }
    _state.add(RecorderState.idle);
  }

  @override
  Future<void> dispose() async {
    _ampTimer?.cancel();
    _durTimer?.cancel();
    await _amplitude.close();
    await _duration.close();
    await _state.close();
  }

  @override
  Stream<double> get amplitudeStream => _amplitude.stream;
  @override
  Stream<Duration> get durationStream => _duration.stream;
  @override
  Stream<RecorderState> get stateStream => _state.stream;
}

/// Tab 5: Video — picker, grid, and the new [NetworkVideo] tile.
class _VideoTab extends StatelessWidget {
  const _VideoTab();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('SingleVideoPicker.compact',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        const Text(
            'Pick one video from gallery (or camera). Pass thumbnailGenerator '
            'to render a poster.'),
        const SizedBox(height: 16),
        SingleVideoPicker.compact(
          maxSize: 1024 * 1024 * 50,
          options: const VideoPickerOptions(
            maxDuration: Duration(seconds: 30),
            quality: VideoQualityPreset.medium,
          ),
          setVideoUrlFromResponse: (response) =>
              response?['media']?['original_url'],
          apiUpload: ApiRequest(
            url: 'https://mysite.com/upload/videos',
            method: 'post',
            videoKey: 'video',
          ),
          allowedMimeTypes: const ['video/mp4', 'video/quicktime'],
        ),
        const SizedBox(height: 32),
        const Text('SingleVideoPicker (custom builder + thumbnailGenerator)',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        const Text(
            'Default constructor — render your own widget and (optionally) '
            'plug a thumbnail generator (video_thumbnail, ffmpeg_kit, etc.) so '
            'the picker can show a real poster after pick.'),
        const SizedBox(height: 16),
        SingleVideoPicker(
          setVideoUrlFromResponse: (response) =>
              response?['media']?['original_url'],
          apiUpload: ApiRequest(
            url: 'https://mysite.com/upload/videos',
            method: 'post',
          ),
          // Wire a real generator here in production. Returning null
          // falls back to the generic video icon.
          thumbnailGenerator: (file) async => null,
          child: (context, upload) => Card(
            child: InkWell(
              onTap: () => upload(),
              child: const Padding(
                padding: EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.video_call_outlined, size: 32),
                    SizedBox(width: 12),
                    Text('Record or pick a video'),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 32),
        const Text('GridVideoPicker',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        const Text(
            'Multi-pick via file_picker. Tile shows thumbnail + play overlay.'),
        const SizedBox(height: 16),
        SizedBox(
          height: 320,
          child: GridVideoPicker(
            defaultVideos: () async => <Map<String, dynamic>>[
              {
                'id': 1,
                'url': 'https://example.com/video1.mp4',
                'thumbnail': 'https://picsum.photos/seed/videothumb1/150/150',
              },
            ],
            setVideoUrlFromItem: (item) => item['url'] as String?,
            setVideoThumbnailFromItem: (item) => item['thumbnail'] as String?,
            apiUpload: ApiRequest(
              url: 'https://mysite.com/upload/videos',
              method: 'post',
            ),
            apiDelete: (item) => ApiRequest(
              url: 'https://mysite.com/delete/${item['id']}',
              method: 'delete',
            ),
            canDeleteVideo: GridVideoPicker.alwaysAllowDelete,
            maxVideos: 6,
          ),
        ),
        const SizedBox(height: 32),
        const Text('NetworkVideo',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        const Text('CachedNetworkImage-style tile for video. Renders the '
            'poster, defers player init until tap, swaps in the real video '
            'view when ready. Adapter is pluggable — example uses a fake '
            'gradient adapter.'),
        const SizedBox(height: 16),
        NetworkVideo(
          url: 'https://example.com/video.mp4',
          posterUrl: 'https://picsum.photos/seed/poster1/640/360',
          adapterFactory: () => _FakeVideoAdapter(),
          borderRadius: BorderRadius.circular(12),
        ),
        const SizedBox(height: 32),
        const Text('NetworkVideo (autoPlay)',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        const Text('Initializes the adapter on first build and starts playing '
            'immediately — feed-style auto-play.'),
        const SizedBox(height: 16),
        NetworkVideo(
          url: 'https://example.com/video-2.mp4',
          posterUrl: 'https://picsum.photos/seed/poster2/640/360',
          adapterFactory: () => _FakeVideoAdapter(),
          borderRadius: BorderRadius.circular(12),
          autoPlay: true,
        ),
      ],
    );
  }
}

/// Tab 6: Audio — picker plus [AudioMessageTile] coordinated via a shared
/// [AudioMessageController]. Tapping play on one tile pauses the others.
class _AudioTab extends StatefulWidget {
  const _AudioTab();

  @override
  State<_AudioTab> createState() => _AudioTabState();
}

class _AudioTabState extends State<_AudioTab> {
  late final AudioMessageController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AudioMessageController(_FakeAudioAdapter());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('SingleAudioPicker.simple',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        const Text('Pick one audio file. Pass durationResolver to enforce '
            'maxDuration without a heavy metadata dep.'),
        const SizedBox(height: 16),
        SingleAudioPicker.simple(
          maxSize: 1024 * 1024 * 25,
          options: AudioPickerOptions(
            allowedExtensions: const ['mp3', 'wav', 'm4a'],
            maxDuration: const Duration(minutes: 10),
            // In production wire just_audio_metadata / audioplayers /
            // flutter_sound here. Returning null skips the duration check
            // for that file.
            durationResolver: (path) async => null,
          ),
          setAudioUrlFromResponse: (response) =>
              response?['media']?['original_url'],
          apiUpload: ApiRequest(
            url: 'https://mysite.com/upload/audio',
            method: 'post',
          ),
        ),
        const SizedBox(height: 32),
        const Text('SingleAudioPicker (custom builder)',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        const Text('Default constructor — render whatever UI you want. The '
            'builder receives the upload callback to wire to your own widget.'),
        const SizedBox(height: 16),
        SingleAudioPicker(
          setAudioUrlFromResponse: (response) =>
              response?['media']?['original_url'],
          apiUpload: ApiRequest(
            url: 'https://mysite.com/upload/audio',
            method: 'post',
          ),
          child: (context, upload) => OutlinedButton.icon(
            onPressed: () => upload(),
            icon: const Icon(Icons.audiotrack),
            label: const Text('Choose audio clip'),
          ),
        ),
        const SizedBox(height: 32),
        const Text('AudioMessageTile (one-playing-at-a-time)',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        const Text('Three tiles share an AudioMessageController. Pressing '
            'play on one auto-pauses the others. Adapter is pluggable — '
            'example uses a fake timer-based adapter.'),
        const SizedBox(height: 16),
        for (final url in [
          'https://example.com/voice-1.mp3',
          'https://example.com/voice-2.mp3',
          'https://example.com/voice-3.mp3',
        ])
          AudioMessageTile(
            source: url,
            controller: _controller,
            duration: const Duration(seconds: 30),
            leading: const CircleAvatar(child: Icon(Icons.person, size: 18)),
          ),
        const SizedBox(height: 32),
        const Text('VoiceRecorder (hold-to-record, apiUpload)',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        const Text('Press and hold the mic. Drag left to cancel, release to '
            'send. Uploads via apiUpload — onUploaded receives the response.'),
        const SizedBox(height: 16),
        Row(
          children: [
            const Expanded(child: Text('Type a message...')),
            VoiceRecorder(
              adapterFactory: () => _FakeRecorderAdapter(),
              minDuration: const Duration(milliseconds: 500),
              maxDuration: const Duration(seconds: 60),
              apiUpload: ApiRequest(
                url: 'https://mysite.com/upload/voice',
                method: 'post',
                audioKey: 'voice_note',
              ),
              onUploaded: (response) {
                debugPrint('Upload response: $response');
              },
            ),
          ],
        ),
        const SizedBox(height: 32),
        const Text('VoiceRecorder (tap-to-record)',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        const Text('Tap to start, tap stop to send, X to cancel.'),
        const SizedBox(height: 16),
        VoiceRecorder(
          mode: RecorderMode.tapToRecord,
          adapterFactory: () => _FakeRecorderAdapter(),
          minDuration: const Duration(milliseconds: 500),
          maxDuration: const Duration(seconds: 60),
          onRecorded: (path) {
            debugPrint('Recorded to: $path');
          },
        ),
        const SizedBox(height: 32),
        const Text('VoiceRecorder (tap, with preview-before-send)',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        const Text('After stopping, switches to a preview row with play/scrub '
            'and Send/Discard buttons. Requires a playerFactory.'),
        const SizedBox(height: 16),
        VoiceRecorder(
          mode: RecorderMode.tapToRecord,
          adapterFactory: () => _FakeRecorderAdapter(),
          previewBeforeSend: true,
          playerFactory: () => _FakeAudioAdapter(),
          minDuration: const Duration(milliseconds: 500),
          onRecorded: (path) {
            debugPrint('Sent from preview: $path');
          },
        ),
      ],
    );
  }
}

/// Tab 7: File pickers — single (simple row) and grid (vertical list with
/// extension-aware icons).
class _FileTab extends StatelessWidget {
  const _FileTab();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('SingleFilePicker.simple',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        const Text('Picks a document (pdf/doc/txt/etc.) via the document '
            'preset.'),
        const SizedBox(height: 16),
        SingleFilePicker.simple(
          fileType: MediaProFileType.document,
          maxSize: 1024 * 1024 * 10,
          setFileUrlFromResponse: (response) =>
              response?['media']?['original_url'],
          apiUpload: ApiRequest(
            url: 'https://mysite.com/upload/files',
            method: 'post',
          ),
        ),
        const SizedBox(height: 32),
        const Text('SingleFilePicker (custom builder)',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        const Text('Default constructor — the builder receives PickedFileInfo? '
            '(null until a file is picked) so you can render empty state vs '
            'picked state from one widget.'),
        const SizedBox(height: 16),
        SingleFilePicker(
          fileType: MediaProFileType.any,
          maxSize: 1024 * 1024 * 25,
          setFileUrlFromResponse: (response) =>
              response?['media']?['original_url'],
          apiUpload: ApiRequest(
            url: 'https://mysite.com/upload/files',
            method: 'post',
          ),
          builder: (context, upload, picked) {
            if (picked == null) {
              return OutlinedButton.icon(
                onPressed: () => upload(),
                icon: const Icon(Icons.attach_file),
                label: const Text('Attach a file'),
              );
            }
            return ListTile(
              leading: const Icon(Icons.insert_drive_file_outlined),
              title: Text(picked.name, overflow: TextOverflow.ellipsis),
              subtitle:
                  Text('${(picked.sizeBytes / 1024).toStringAsFixed(1)} KB'),
              trailing: IconButton(
                icon: const Icon(Icons.refresh),
                tooltip: 'Replace',
                onPressed: () => upload(),
              ),
            );
          },
        ),
        const SizedBox(height: 32),
        const Text('SingleFilePicker (custom extensions — spreadsheets only)',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        const Text('MediaProFileType.custom requires an allowedExtensions list '
            '(asserted at construction). Use this when the document preset is '
            'too broad.'),
        const SizedBox(height: 16),
        SingleFilePicker.simple(
          fileType: MediaProFileType.custom,
          allowedExtensions: const ['csv', 'xls', 'xlsx'],
          maxSize: 1024 * 1024 * 5,
          setFileUrlFromResponse: (response) =>
              response?['media']?['original_url'],
          apiUpload: ApiRequest(
            url: 'https://mysite.com/upload/spreadsheets',
            method: 'post',
            fileKey: 'spreadsheet',
          ),
        ),
      ],
    );
  }
}
