import 'package:flutter/cupertino.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/database_service.dart';
import 'services/notification_service.dart';
import 'services/speech_service.dart';
import 'services/background_service.dart';
import 'screens/onboarding_screen.dart';
import 'screens/main_screen.dart';

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

  // Check persistent storage for onboarding state
  Widget initialWidget = const OnboardingScreen();
  try {
    final prefs = await SharedPreferences.getInstance();
    final bool seenOnboarding = prefs.getBool('seenOnboarding') ?? false;
    
    if (seenOnboarding) {
      initialWidget = const MainScreen();
      // Only initialize background service if permissions were likely granted
      try {
        await BackgroundService.initialize();
      } catch (e) {
        debugPrint('BackgroundService init failed: $e');
      }
    }
  } catch (e) {
    debugPrint('Startup preferences check failed: $e');
  }
  
  runApp(SnapshotMemoApp(initialWidget: initialWidget));
}

class SnapshotMemoApp extends StatefulWidget {
  final Widget initialWidget;

  const SnapshotMemoApp({super.key, required this.initialWidget});

  static _SnapshotMemoAppState of(BuildContext context) => 
      context.findAncestorStateOfType<_SnapshotMemoAppState>()!;

  @override
  State<SnapshotMemoApp> createState() => _SnapshotMemoAppState();
}

class _SnapshotMemoAppState extends State<SnapshotMemoApp> {
  Brightness _brightness = Brightness.dark;

  @override
  void initState() {
    super.initState();
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final isDark = prefs.getBool('isDark') ?? true;
    setState(() {
      _brightness = isDark ? Brightness.dark : Brightness.light;
    });
  }

  void toggleTheme() async {
    setState(() {
      _brightness = _brightness == Brightness.dark ? Brightness.light : Brightness.dark;
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDark', _brightness == Brightness.dark);
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoApp(
      navigatorKey: navigatorKey,
      title: 'SnapshotMemo',
      theme: CupertinoThemeData(
        primaryColor: CupertinoColors.activeBlue,
        brightness: _brightness,
        scaffoldBackgroundColor: _brightness == Brightness.dark 
            ? CupertinoColors.black 
            : CupertinoColors.systemGroupedBackground,
      ),
      home: widget.initialWidget,
      debugShowCheckedModeBanner: false,
    );
  }
}
