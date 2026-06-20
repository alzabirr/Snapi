import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';

class PhotoPermissionScreen extends StatelessWidget {
  const PhotoPermissionScreen({super.key});

  Future<void> _request(BuildContext context) async {
    await PhotoManager.requestPermissionExtend();
    if (context.mounted) {
      Navigator.pushNamed(context, '/perm_mic');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(),
            Icon(
              Icons.photo_library,
              size: 100,
              color: theme.colorScheme.primary.withOpacity(0.8),
            ),
            const SizedBox(height: 40),
            Text(
              'Gallery Access',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: theme.colorScheme.onSurface,
                letterSpacing: -1,
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                'Krabby needs to see your photos to find and organize your screenshots automatically.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 17,
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                  height: 1.4,
                ),
              ),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.all(40),
              child: SizedBox(
                width: double.infinity,
                height: 60,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  onPressed: () => _request(context),
                  child: const Text(
                    'Allow Gallery Access',
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.5,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
