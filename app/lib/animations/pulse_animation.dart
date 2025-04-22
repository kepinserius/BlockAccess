import 'package:flutter/material.dart';
import 'package:simple_animations/simple_animations.dart';

class PulseAnimation extends StatelessWidget {
  final Widget child;
  final Duration duration;
  final bool infinite;

  const PulseAnimation({
    Key? key,
    required this.child,
    this.duration = const Duration(milliseconds: 1500),
    this.infinite = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final tween = MovieTween()
      ..tween(
        'scale',
        Tween<double>(begin: 1.0, end: 1.1),
        duration: duration ~/ 2,
      )
      ..tween(
        'scale',
        Tween<double>(begin: 1.1, end: 1.0),
        duration: duration ~/ 2,
        curve: Curves.easeInOut,
      );

    return PlayAnimationBuilder<Movie>(
      tween: tween,
      duration: tween.duration,
      builder: (context, value, child) {
        return Transform.scale(
          scale: value.get('scale'),
          child: child,
        );
      },
      child: child,
      control: infinite ? Control.loop : Control.play,
    );
  }
}
