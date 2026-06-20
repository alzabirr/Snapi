import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotifPermissionScreen extends StatelessWidget {
  const NotifPermissionScreen({super.key});

  Future<void> _request(BuildContext context) async {
    await Permission.notification.request();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('seenOnboarding', true);
    if (context.mounted) {
      Navigator.pushReplacementNamed(context, '/home');
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
              Icons.notifications_active,
              size: 100,
              color: Colors.amber.withOpacity(0.8),
            ),
            const SizedBox(height: 40),
            Text(
              'Notifications',
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
                'Stay updated! Krabby will alert you when new screenshots are detected.',
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
                    'Allow Notifications',
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
