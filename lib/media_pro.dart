// ignore: unnecessary_library_name
library media_pro;

export '/models/api_request.dart';
export '/models/upload_mode.dart';
export '/models/image_compression_options.dart';
export '/models/compression_tier.dart';
export '/models/image_picker_style.dart';
export '/models/video_picker_style.dart';
export '/models/video_picker_options.dart';
export '/models/audio_picker_style.dart';
export '/models/audio_picker_options.dart';
export '/models/file_picker_style.dart';
export '/models/picked_file_info.dart';
export '/networking/media_api_service.dart';
export '/widgets/single_image_picker_widget.dart';
export '/widgets/single_video_picker_widget.dart';
export '/widgets/single_audio_picker_widget.dart';
export '/widgets/single_file_picker_widget.dart';
export '/widgets/grid_image_picker_widget.dart';
export '/widgets/grid_video_picker_widget.dart';
export '/widgets/audio_message_tile.dart';
export '/widgets/network_video.dart';
export '/widgets/voice_recorder.dart';
export '/adapters/audio_player_adapter.dart';
export '/adapters/audio_recorder_adapter.dart';
export '/adapters/video_player_adapter.dart';
export '/widgets/animated_image_tile.dart';
export '/widgets/loading_placeholder_tile.dart';
export '/widgets/pending_upload_tile.dart';
export '/widgets/upload_image_tile.dart';
export '/widgets/image_uploader.dart';
export '/widgets/media_loader.dart';

/// MediaPro version
const String _mediaProVersion = '3.0.0-beta.1';

/// MediaPro class
class MediaPro {
  MediaPro._privateConstructor();

  static final MediaPro instance = MediaPro._privateConstructor();

  /// MediaPro version
  static String get version => _mediaProVersion;

  /// Debug mode
  bool? debugMode = false;

  /// Initialize MediaPro
  void init({bool? debugMode}) {
    this.debugMode = debugMode;
  }
}
