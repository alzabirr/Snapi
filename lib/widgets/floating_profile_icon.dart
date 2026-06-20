import 'package:flutter/material.dart';

class FloatingProfileIcon extends StatelessWidget {
  const FloatingProfileIcon({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withOpacity(0.1),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Image.asset(
            'assets/krabby.png',
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}
