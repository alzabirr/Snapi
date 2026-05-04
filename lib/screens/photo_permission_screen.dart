import 'package:flutter/cupertino.dart';
import 'package:photo_manager/photo_manager.dart';

class PhotoPermissionScreen extends StatelessWidget {
  const PhotoPermissionScreen({super.key});

  Future<void> _request(BuildContext context) async {
    final ps = await PhotoManager.requestPermissionExtend();
    if (context.mounted) {
      Navigator.pushNamed(context, '/perm_mic');
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
              CupertinoIcons.photo_fill_on_rectangle_fill,
              size: 100,
              color: CupertinoColors.activeBlue.withOpacity(0.8),
            ),
            const SizedBox(height: 40),
            const Text(
              'Gallery Access',
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
                'Snapi needs to see your photos to find and organize your screenshots automatically.',
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
                    'Allow Gallery Access',
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
