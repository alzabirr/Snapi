import 'package:flutter/cupertino.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'main_screen.dart';
import '../services/background_service.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  Future<void> _requestPermissions(BuildContext context) async {
    // Request Photos/Gallery using PhotoManager (This is most reliable for the plugin)
    PermissionState ps = await PhotoManager.requestPermissionExtend();
    
    // Explicitly request using permission_handler for Android 13+ and below
    Map<Permission, PermissionStatus> statuses = await [
      Permission.photos,
      Permission.videos,
      Permission.audio,
      Permission.microphone,
      Permission.notification,
      Permission.scheduleExactAlarm,
      // For older Android versions
      Permission.storage,
    ].request();

    // Re-check photo manager state after permission_handler call
    ps = await PhotoManager.getPermissionState(
      requestOption: const PermissionRequestOption(),
    );

    final prefs = await SharedPreferences.getInstance();

    if (ps.isAuth) { // Only 'Authorized' is full access
      await prefs.setBool('seenOnboarding', true);

      // Initialize background service now that we have permissions
      try {
        await BackgroundService.initialize();
      } catch (e) {
        debugPrint('BackgroundService init failed: $e');
      }

      if (context.mounted) {
        Navigator.pushReplacement(
          context,
          CupertinoPageRoute(builder: (context) => const MainScreen()),
        );
      }
    } else if (ps == PermissionState.limited) {
      // If limited, we show a message explaining how to give full access
      if (context.mounted) {
        showCupertinoDialog(
          context: context,
          builder: (context) => CupertinoAlertDialog(
            title: const Text('Full Access Recommended'),
            content: const Text('You have granted limited access. For the best experience (monitoring all screenshots), please "Allow All" in settings.'),
            actions: [
              CupertinoDialogAction(
                child: const Text('Open Settings'),
                onPressed: () {
                  PhotoManager.openSetting();
                  Navigator.pop(context);
                },
              ),
              CupertinoDialogAction(
                child: const Text('Continue with Limited'),
                onPressed: () async {
                  await prefs.setBool('seenOnboarding', true);

                  // Initialize background service
                  try {
                    await BackgroundService.initialize();
                  } catch (e) {
                    debugPrint('BackgroundService init failed: $e');
                  }

                  if (context.mounted) {
                    Navigator.pop(context);
                    Navigator.pushReplacement(
                      context,
                      CupertinoPageRoute(builder: (context) => const MainScreen()),
                    );
                  }
                },
              ),
            ],
          ),
        );
      }
    }
else {
      // Handle case where photos permission is denied
      if (context.mounted) {
        showCupertinoDialog(
          context: context,
          builder: (context) => CupertinoAlertDialog(
            title: const Text('Permission Required'),
            content: const Text('Gallery access is needed to detect screenshots.'),
            actions: [
              CupertinoDialogAction(
                child: const Text('OK'),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.black,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30.0),
          child: Column(
            children: [
              const Spacer(flex: 2),
              
              // App Icon with subtle glow
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFF1C1C1E),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: CupertinoColors.activeBlue.withOpacity(0.3),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: CupertinoColors.activeBlue.withOpacity(0.15),
                      blurRadius: 40,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: const Icon(
                  CupertinoIcons.camera_viewfinder,
                  size: 64,
                  color: CupertinoColors.activeBlue,
                ),
              ),
              
              const SizedBox(height: 40),
              
              // Title
              Text(
                'Snapi',
                style: CupertinoTheme.of(context).textTheme.navLargeTitleTextStyle.copyWith(
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1,
                  color: CupertinoColors.white,
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 12),
              
              Text(
                'Your  Screenshot Assistant',
                style: TextStyle(
                  fontSize: 17,
                  color: CupertinoColors.systemGrey,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
              
              const Spacer(flex: 1),
              
              // Feature List
              _FeatureRow(
                icon: CupertinoIcons.bolt_fill,
                color: CupertinoColors.systemYellow,
                title: 'Auto Detection',
                subtitle: 'Instantly prompt for notes when a screenshot is taken.',
              ),
              const SizedBox(height: 24),
              _FeatureRow(
                icon: CupertinoIcons.mic_fill,
                color: CupertinoColors.systemRed,
                title: 'Smart Management',
                subtitle: 'Add voice or text notes to organize your captures.',
              ),
              const SizedBox(height: 24),
              _FeatureRow(
                icon: CupertinoIcons.shield_fill,
                color: CupertinoColors.systemGreen,
                title: 'Privacy First',
                subtitle: 'All data stays on your device. Zero cloud sync.',
              ),
              
              const Spacer(flex: 2),
              
              // Premium Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: CupertinoButton(
                  padding: EdgeInsets.zero,
                  color: CupertinoColors.activeBlue,
                  borderRadius: BorderRadius.circular(16),
                  onPressed: () => _requestPermissions(context),
                  child: const Text(
                    'Get Started',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: CupertinoColors.white,
                    ),
                  ),
                ),
              ),
              
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;

  const _FeatureRow({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 14,
                  color: CupertinoColors.systemGrey,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
