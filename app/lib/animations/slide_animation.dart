import 'package:flutter/material.dart';
import 'package:simple_animations/simple_animations.dart';

enum SlideDirection { fromLeft, fromRight, fromTop, fromBottom }

class SlideAnimation extends StatelessWidget {
  final double delay;
  final Widget child;
  final SlideDirection direction;
  final double distance;

  const SlideAnimation({
    Key? key,
    required this.delay,
    required this.child,
    this.direction = SlideDirection.fromBottom,
    this.distance = 100.0,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    double dx = 0.0;
    double dy = 0.0;

    switch (direction) {
      case SlideDirection.fromLeft:
        dx = -distance;
        break;
      case SlideDirection.fromRight:
        dx = distance;
        break;
      case SlideDirection.fromTop:
        dy = -distance;
        break;
      case SlideDirection.fromBottom:
        dy = distance;
        break;
    }

    final tween = MovieTween()
      ..tween('opacity', Tween(begin: 0.0, end: 1.0),
          duration: const Duration(milliseconds: 500))
      ..tween(
          'translateX',
          Tween(begin: dx, end: 0.0),
          duration: const Duration(milliseconds: 700),
          curve: Curves.easeOutQuint)
      ..tween(
          'translateY',
          Tween(begin: dy, end: 0.0),
          duration: const Duration(milliseconds: 700),
          curve: Curves.easeOutQuint);

    return PlayAnimationBuilder<Movie>(
      delay: Duration(milliseconds: (300 * delay).round()),
      duration: tween.duration,
      tween: tween,
      child: child,
      builder: (context, value, child) => Opacity(
        opacity: value.get('opacity'),
        child: Transform.translate(
          offset: Offset(value.get('translateX'), value.get('translateY')),
          child: child,
        ),
      ),
    );
  }
}
