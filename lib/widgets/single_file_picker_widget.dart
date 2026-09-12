import 'dart:io';
import 'package:file_picker/file_picker.dart' as fp;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mime/mime.dart';
import 'package:nylo_support/ny_core.dart';
import '/media_pro.dart';
import '/mixins/media_helper_mixin.dart';

/// [SingleFilePicker] widget can be used to upload a single arbitrary file.
/// Two styles are available — see [FilePickerStyle].
///
/// Use [fileType] to constrain the picker dialog. When [fileType] is
/// [MediaProFileType.custom], you must also pass [allowedExtensions].
class SingleFilePicker extends StatefulWidget {
  SingleFilePicker(
      {super.key,
      required Widget Function(
              BuildContext context, Function upload, PickedFileInfo? picked)
          builder,
      this.defaultFile,
      this.fileType = MediaProFileType.any,
      this.allowedExtensions,
      this.apiUpload,
      required this.setFileUrlFromResponse,
      this.loading,
      this.onError,
      this.canUpdate = true,
      this.maxSize,
      this.allowedMimeTypes})
      : style = CustomFilePickerStyle(builder),
        assert(fileType != MediaProFileType.custom || allowedExtensions != null,
            "allowedExtensions is required when fileType is MediaProFileType.custom");

  const SingleFilePicker.simple(
      {super.key,
      this.defaultFile,
      this.fileType = MediaProFileType.any,
      this.allowedExtensions,
      this.apiUpload,
      required this.setFileUrlFromResponse,
      this.loading,
      this.onError,
      this.canUpdate = true,
      this.maxSize,
      this.allowedMimeTypes})
      : style = const SimpleFilePickerStyle(),
        assert(fileType != MediaProFileType.custom || allowedExtensions != null,
            "allowedExtensions is required when fileType is MediaProFileType.custom");

  final dynamic defaultFile;
  final MediaProFileType fileType;
  final List<String>? allowedExtensions;
  final ApiRequest? apiUpload;
  final Function(dynamic response) setFileUrlFromResponse;
  final Widget? loading;
  final Function? onError;
  final bool canUpdate;
  final double? maxSize;
  final List<String>? allowedMimeTypes;
  final FilePickerStyle style;

  @override
  createState() => _SingleFilePickerState();
}

class _SingleFilePickerState extends NyState<SingleFilePicker>
    with MediaHelperMixin {
  final MediaApiService _mediaApiService = MediaApiService();

  dynamic _defaultFile;
  PickedFileInfo? _pickedFile;

  @override
  get init => () {
        _defaultFile = widget.defaultFile;
        if (widget.defaultFile is PickedFileInfo) {
          _pickedFile = widget.defaultFile;
        }
      };

  Future<void> _handleFileUpload() async {
    if (widget.canUpdate == false) return;
    if (!mounted) return;
    lockRelease('file_upload', perform: () async {
      fp.PlatformFile? platformFile;
      try {
        final List<String>? extensions =
            widget.allowedExtensions ?? widget.fileType.defaultExtensions;
        platformFile = await fp.FilePicker.pickFile(
          type: widget.fileType.toFilePickerType(),
          allowedExtensions: extensions,
        );
      } on Exception catch (e) {
        if (MediaPro.instance.debugMode ?? false) {
          if (kDebugMode) {
            print(e.toString());
          }
        }
      }

      if (platformFile == null) return;

      if (platformFile.path == null) {
        showToastSorry(description: "Could not read file path".tr());
        return;
      }

      File file = File(platformFile.path!);
      if (widget.maxSize != null) {
        int fileInBytes = file.lengthSync();
        if (fileInBytes > (widget.maxSize!)) {
          showToastSorry(
              description:
                  "The file is too large. It must be under ${calculateMaxSizeToReadableFormat(widget.maxSize!)}"
                      .tr());
          return;
        }
      }

      final String? mimeType = lookupMimeType(file.path);
      if (widget.allowedMimeTypes?.isNotEmpty ?? false) {
        if (mimeType == null || !widget.allowedMimeTypes!.contains(mimeType)) {
          showToastSorry(
              description:
                  "The file type must be one of ${widget.allowedMimeTypes!.join(', ')}"
                      .tr());
          return;
        }
      }

      final picked =
          PickedFileInfo.fromPlatformFile(platformFile, mimeType: mimeType);

      if (widget.apiUpload == null) {
        printToConsole("apiUpload parameter is required to upload file");
        return;
      }

      dynamic response = await _mediaApiService.uploadFile(
        picked,
        apiRequest: widget.apiUpload!,
      );

      setState(() {
        _pickedFile = picked;
      });
      String? uploaded = widget.setFileUrlFromResponse(response);
      if (uploaded != null) {
        _defaultFile = uploaded;
      }
    });
  }

  @override
  Widget view(BuildContext context) {
    switch (currentState()) {
      case "loading":
        {
          return widget.loading ?? const MediaLoader();
        }
      case "default":
        {
          return switch (widget.style) {
            CustomFilePickerStyle style =>
              style.builder(context, _handleFileUpload, _pickedFile),
            SimpleFilePickerStyle() => _simple(),
          };
        }
      default:
        {
          return const SizedBox();
        }
    }
  }

  String currentState() {
    if (isLocked('file_upload')) return 'loading';
    return 'default';
  }

  IconData _iconForExtension(String? extension) {
    switch (extension?.toLowerCase()) {
      case 'pdf':
        return Icons.picture_as_pdf_rounded;
      case 'doc':
      case 'docx':
      case 'txt':
      case 'rtf':
      case 'odt':
        return Icons.description_rounded;
      case 'xls':
      case 'xlsx':
      case 'csv':
        return Icons.table_chart_rounded;
      case 'zip':
      case 'rar':
      case '7z':
        return Icons.folder_zip_rounded;
      default:
        return Icons.insert_drive_file_rounded;
    }
  }

  String _resolveLabel() {
    if (_pickedFile != null) return _pickedFile!.name;
    if (_defaultFile is String && (_defaultFile as String).isNotEmpty) {
      return "File uploaded".tr();
    }
    return "Upload a file".tr();
  }

  Widget _simple() {
    final String label = _resolveLabel();
    final int? size = _pickedFile?.sizeBytes;
    final IconData icon = _iconForExtension(_pickedFile?.extension);
    return InkWell(
      onTap: _handleFileUpload,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Icon(icon),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(label, overflow: TextOverflow.ellipsis),
                  if (size != null)
                    Text(
                      calculateMaxSizeToReadableFormat(size.toDouble()),
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                ],
              ),
            ),
            if (widget.canUpdate) const Icon(Icons.upload_rounded),
          ],
        ),
      ),
    );
  }
}
