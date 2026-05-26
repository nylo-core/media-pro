import 'dart:io';
import 'package:file_picker/file_picker.dart' as fp;
import 'package:image_picker/image_picker.dart' show XFile;

/// Type of file the picker accepts. Maps to `file_picker`'s [fp.FileType].
enum MediaProFileType {
  /// Any file. No extension filter applied.
  any,

  /// Documents (pdf, doc, docx, txt, rtf, odt) via custom extensions.
  document,

  /// User supplies the extension list via `allowedExtensions`.
  custom;

  fp.FileType toFilePickerType() => switch (this) {
        MediaProFileType.any => fp.FileType.any,
        MediaProFileType.document => fp.FileType.custom,
        MediaProFileType.custom => fp.FileType.custom,
      };

  /// Default extension list for [MediaProFileType.document]. Returns null for
  /// other types — the caller supplies their own list.
  List<String>? get defaultExtensions => switch (this) {
        MediaProFileType.document => const [
            'pdf',
            'doc',
            'docx',
            'txt',
            'rtf',
            'odt',
          ],
        _ => null,
      };
}

/// Lightweight value object exposing picked-file metadata to widget builders
/// without leaking the underlying `file_picker` types.
class PickedFileInfo {
  final String name;
  final String path;
  final int sizeBytes;
  final String? extension;
  final String? mimeType;

  const PickedFileInfo({
    required this.name,
    required this.path,
    required this.sizeBytes,
    this.extension,
    this.mimeType,
  });

  factory PickedFileInfo.fromPlatformFile(fp.PlatformFile file,
      {String? mimeType}) {
    return PickedFileInfo(
      name: file.name,
      path: file.path ?? '',
      sizeBytes: file.size,
      extension: file.extension,
      mimeType: mimeType,
    );
  }

  /// Wraps an [XFile] (from `image_picker`) in a [PickedFileInfo]. Reads
  /// length synchronously from the underlying [File] — fine for local paths.
  factory PickedFileInfo.fromXFile(XFile file, {String? mimeType}) {
    final dot = file.name.lastIndexOf('.');
    final ext = dot > -1 && dot < file.name.length - 1
        ? file.name.substring(dot + 1)
        : null;
    return PickedFileInfo(
      name: file.name,
      path: file.path,
      sizeBytes: File(file.path).lengthSync(),
      extension: ext,
      mimeType: mimeType,
    );
  }

  /// Constructs from a local file path. Useful for files produced in-app
  /// (e.g. by [VoiceRecorder]) where there's no [XFile] / [fp.PlatformFile]
  /// wrapper.
  factory PickedFileInfo.fromPath(String path,
      {String? name, String? mimeType}) {
    final f = File(path);
    final filename = name ?? path.split('/').last;
    final dot = filename.lastIndexOf('.');
    final ext = dot > -1 && dot < filename.length - 1
        ? filename.substring(dot + 1)
        : null;
    return PickedFileInfo(
      name: filename,
      path: path,
      sizeBytes: f.lengthSync(),
      extension: ext,
      mimeType: mimeType,
    );
  }
}
