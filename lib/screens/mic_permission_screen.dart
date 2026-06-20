import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class MicPermissionScreen extends StatelessWidget {
  const MicPermissionScreen({super.key});

  Future<void> _request(BuildContext context) async {
    await Permission.microphone.request();
    if (context.mounted) {
      Navigator.pushNamed(context, '/perm_notif');
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
              Icons.mic,
              size: 100,
              color: Colors.red.withOpacity(0.8),
            ),
            const SizedBox(height: 40),
            Text(
              'Microphone',
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
                'Enable your microphone to add voice memos and notes to your screenshots effortlessly.',
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
                    'Enable Microphone',
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
