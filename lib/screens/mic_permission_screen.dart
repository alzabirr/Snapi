import 'package:flutter/cupertino.dart';
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
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.white,
      child: SafeArea(
        child: Column(
          children: [
            const Spacer(),
            Icon(
              CupertinoIcons.mic_fill,
              size: 100,
              color: CupertinoColors.systemRed.withOpacity(0.8),
            ),
            const SizedBox(height: 40),
            const Text(
              'Microphone',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                letterSpacing: -1,
              ),
            ),
            const SizedBox(height: 16),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                'Enable your microphone to add voice memos and notes to your screenshots effortlessly.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 17,
                  color: CupertinoColors.secondaryLabel,
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
                child: CupertinoButton(
                  color: CupertinoColors.activeBlue,
                  borderRadius: BorderRadius.circular(20),
                  onPressed: () => _request(context),
                  child: const Text(
                    'Enable Microphone',
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5,
                      color: CupertinoColors.white,
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
