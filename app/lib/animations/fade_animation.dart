import 'package:flutter/material.dart';
import 'package:simple_animations/simple_animations.dart';

class FadeAnimation extends StatelessWidget {
  final double delay;
  final Widget child;
  final bool fadeIn;
  final Offset? offset;

  const FadeAnimation({
    Key? key,
    required this.delay,
    required this.child,
    this.fadeIn = true,
    this.offset,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final tween = MovieTween()
      ..tween('opacity', Tween(begin: 0.0, end: 1.0),
          duration: const Duration(milliseconds: 500))
      ..tween(
          'translateY',
          Tween(
              begin: offset?.dy ?? 50.0,
              end: 0.0),
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOut)
      ..tween(
          'translateX',
          Tween(
              begin: offset?.dx ?? 0.0,
              end: 0.0),
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOut);

    return PlayAnimationBuilder<Movie>(
      delay: Duration(milliseconds: (500 * delay).round()),
      duration: tween.duration,
      tween: tween,
      child: child,
      builder: (context, value, child) => Opacity(
        opacity: fadeIn ? value.get('opacity') : 1,
        child: Transform.translate(
          offset: Offset(value.get('translateX'), value.get('translateY')),
          child: child,
        ),
      ),
    );
  }
}
