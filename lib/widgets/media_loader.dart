import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// The [MediaLoader] widget is used in the [SingleMediaPicker] and [GridMediaPicker] to
/// show a loader while the image is being uploaded.
class MediaLoader extends StatelessWidget {
  const MediaLoader({super.key});

  @override
  Widget build(BuildContext context) {
    switch (Theme.of(context).platform) {
      case TargetPlatform.android:
        return const Center(child: CircularProgressIndicator());
      case TargetPlatform.iOS:
        return const Center(child: CupertinoActivityIndicator());
      default:
        return const Center(child: CircularProgressIndicator());
    }
  }
}
