import 'package:flutter/material.dart';

class CuteRouteTransition extends PageRouteBuilder {
  final Widget page;

  CuteRouteTransition({required this.page})
      : super(
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionDuration: const Duration(milliseconds: 500),
          reverseTransitionDuration: const Duration(milliseconds: 300),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            // A bouncy scale transition using an ElasticOut curve
            final scaleAnimation = Tween<double>(begin: 0.85, end: 1.0).animate(
              CurvedAnimation(
                parent: animation,
                curve: Curves.elasticOut,
              ),
            );

            final fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
              CurvedAnimation(
                parent: animation,
                curve: Curves.easeInOut,
              ),
            );

            return FadeTransition(
              opacity: fadeAnimation,
              child: ScaleTransition(
                scale: scaleAnimation,
                alignment: Alignment.center,
                child: child,
              ),
            );
          },
        );
}
