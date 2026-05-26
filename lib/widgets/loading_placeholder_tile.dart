import 'package:flutter/material.dart';

/// Pulsing skeleton placeholder shown in empty grid slots during an upload.
/// Used by [GridImagePicker].
class LoadingPlaceholderTile extends StatefulWidget {
  const LoadingPlaceholderTile({
    super.key,
    this.pulseDuration = const Duration(milliseconds: 1200),
    this.pulseStartColor,
    this.pulseEndColor,
  });

  final Duration pulseDuration;
  final Color? pulseStartColor;
  final Color? pulseEndColor;

  @override
  State<LoadingPlaceholderTile> createState() => _LoadingPlaceholderTileState();
}

class _LoadingPlaceholderTileState extends State<LoadingPlaceholderTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.pulseDuration,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final startColor = widget.pulseStartColor ?? Colors.grey.shade100;
    final endColor = widget.pulseEndColor ?? Colors.grey.shade300;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            color: Color.lerp(startColor, endColor, _controller.value),
            borderRadius: BorderRadius.circular(8),
            boxShadow: const [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 1,
                offset: Offset(0, 0),
              ),
            ],
          ),
          margin: const EdgeInsets.all(8),
        );
      },
    );
  }
}
