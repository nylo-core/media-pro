import 'package:flutter/material.dart';

/// Scale + fade entrance animation for newly added grid items.
/// Used by [GridImagePicker] when an upload completes.
class AnimatedImageTile extends StatefulWidget {
  const AnimatedImageTile({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 400),
    this.scaleCurve = Curves.easeOutBack,
    this.fadeCurve = Curves.easeIn,
  });

  final Widget child;
  final Duration duration;
  final Curve scaleCurve;
  final Curve fadeCurve;

  @override
  State<AnimatedImageTile> createState() => _AnimatedImageTileState();
}

class _AnimatedImageTileState extends State<AnimatedImageTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );
    _scaleAnimation = CurvedAnimation(
      parent: _controller,
      curve: widget.scaleCurve,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: widget.fadeCurve,
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: widget.child,
      ),
    );
  }
}
