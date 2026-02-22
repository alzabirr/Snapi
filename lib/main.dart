import 'package:flutter/cupertino.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/database_service.dart';
import 'services/notification_service.dart';
import 'services/speech_service.dart';
import 'services/background_service.dart';
import 'screens/onboarding_screen.dart';
import 'screens/home_screen.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize services
  try {
    await DatabaseService.init();
  } catch (e) {
    debugPrint('DatabaseService init failed: $e');
  }
  
  try {
    await NotificationService.init();
  } catch (e) {
    debugPrint('NotificationService init failed: $e');
  }
  
  try {
    await SpeechService.init();
  } catch (e) {
    debugPrint('SpeechService init failed: $e');
  }

  try {
    await BackgroundService.initialize();
  } catch (e) {
    debugPrint('BackgroundService init failed: $e');
  }

  // Check persistent storage for onboarding state
  Widget initialWidget = const OnboardingScreen();
  try {
    final prefs = await SharedPreferences.getInstance();
    final bool seenOnboarding = prefs.getBool('seenOnboarding') ?? false;
    
    if (seenOnboarding) {
      initialWidget = const HomeScreen();
    }
  } catch (e) {
    debugPrint('Startup preferences check failed: $e');
  }
  
  runApp(SnapshotMemoApp(initialWidget: initialWidget));
}

class SnapshotMemoApp extends StatelessWidget {
  final Widget initialWidget;

  const SnapshotMemoApp({super.key, required this.initialWidget});

  @override
  Widget build(BuildContext context) {
    return CupertinoApp(
      navigatorKey: navigatorKey,
      title: 'SnapshotMemo',
      theme: const CupertinoThemeData(
        primaryColor: CupertinoColors.activeBlue,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: CupertinoColors.black,
      ),
      home: initialWidget,
      debugShowCheckedModeBanner: false,
    );
  }
}
