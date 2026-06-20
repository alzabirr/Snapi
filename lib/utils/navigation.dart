import 'package:flutter/material.dart';

Route<T> _zoomRoute<T>(final Widget page) {
  return PageRouteBuilder<T>(
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionDuration: const Duration(milliseconds: 300),
    reverseTransitionDuration: const Duration(milliseconds: 300),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final scale = Tween<double>(begin: 0.0, end: 1.0)
          .chain(CurveTween(curve: Curves.easeOutBack));

      final fade = Tween<double>(begin: 0.0, end: 1.0)
          .chain(CurveTween(curve: Curves.easeIn));

      return ScaleTransition(
        scale: animation.drive(scale),
        child: FadeTransition(
          opacity: animation.drive(fade),
          child: child,
        ),
      );
    },
  );
}

dynamic appPush(
  final BuildContext context,
  final Widget page, {
  final bool fullscreenDialog = false,
}) async {
  return await Navigator.push(
    context,
    _zoomRoute(page),
  );
}

dynamic appPushReplacement(
  final BuildContext context,
  final Widget page,
) async {
  return await Navigator.pushReplacement(
    context,
    _zoomRoute(page),
  );
}

void appPop(final BuildContext context, {final dynamic data}) {
  Navigator.pop(context, data);
}
