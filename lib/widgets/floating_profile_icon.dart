import 'package:flutter/cupertino.dart';

class FloatingProfileIcon extends StatelessWidget {
  const FloatingProfileIcon({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: CupertinoColors.activeBlue.withOpacity(0.1),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Image.asset(
            'assets/snapi.png',
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}
