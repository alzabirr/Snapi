import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:photo_manager/photo_manager.dart';
import 'services/database_service.dart';
import 'services/notification_service.dart';
import 'services/speech_service.dart';
import 'services/screenshot_service.dart';
import 'services/background_service.dart';
import 'models/screenshot_item.dart';
import 'widgets/screenshot_popup.dart';
import 'screens/main_screen.dart';
import 'screens/permissions_slider_screen.dart';

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
  
  // SpeechService.init() moved to after onboarding check or permission slide

  try {
    await BackgroundService.initialize();
  } catch (e) {
    debugPrint('BackgroundService init failed: $e');
  }

  // Check persistent storage for onboarding state
  Widget initialWidget = const PermissionsSliderScreen();
  try {
    final prefs = await SharedPreferences.getInstance();
    final bool seenOnboarding = prefs.getBool('seenOnboarding') ?? false;
    
    if (seenOnboarding) {
      initialWidget = const MainScreen();
      // Initialize speech service if already onboarded
      try {
        await SpeechService.init();
      } catch (e) {
        debugPrint('SpeechService init failed: $e');
      }
    }
  } catch (e) {
    debugPrint('Startup preferences check failed: $e');
  }
  
  runApp(SnapiApp(initialWidget: initialWidget));
}

class SnapiApp extends StatefulWidget {
  final Widget initialWidget;

  const SnapiApp({super.key, required this.initialWidget});

  static _SnapiAppState of(BuildContext context) => 
      context.findAncestorStateOfType<_SnapiAppState>()!;

  @override
  State<SnapiApp> createState() => _SnapiAppState();
}

class _SnapiAppState extends State<SnapiApp> with WidgetsBindingObserver {
  Brightness _brightness = Brightness.light;
  StreamSubscription? _screenshotSubscription;
  StreamSubscription? _notificationSubscription;
  final Set<String> _pendingPopups = {};
  bool _monitoringStarted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadTheme();
    // Start monitoring after the first frame so navigatorKey is available
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initScreenshotMonitoring();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _screenshotSubscription?.cancel();
    _notificationSubscription?.cancel();
    ScreenshotService.stopMonitoring();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_monitoringStarted) {
      _initScreenshotMonitoring();
    }
  }

  Future<void> _initScreenshotMonitoring() async {
    if (_monitoringStarted) return;

    // Only start if onboarding is complete
    final prefs = await SharedPreferences.getInstance();
    final bool seenOnboarding = prefs.getBool('seenOnboarding') ?? false;
    if (!seenOnboarding) return;

    _monitoringStarted = true;

    // Listen for screenshot detections
    _screenshotSubscription = ScreenshotService.screenshotStream.listen((asset) {
      debugPrint('DEBUG: Screenshot stream received asset: ${asset.id}');
      _showNotePopup(asset);
    });

    // Listen for notification taps
    _notificationSubscription = NotificationService.notificationStream.listen((assetId) async {
      debugPrint('DEBUG: Notification tapped for assetId: $assetId');
      final asset = await AssetEntity.fromId(assetId);
      if (asset != null) {
        _showNotePopup(asset);
      }
    });

    // Request notification permission
    try {
      await NotificationService.requestPermission();
    } catch (_) {}

    // Start the screenshot monitoring
    await ScreenshotService.startMonitoring();
  }

  void _showNotePopup(AssetEntity asset) {
    final navigator = navigatorKey.currentState;
    if (navigator == null) {
      debugPrint('DEBUG: No navigator state available for popup.');
      return;
    }

    // Prevent duplicate popups
    if (_pendingPopups.contains(asset.id)) {
      debugPrint('DEBUG: Screenshot ${asset.id} already has an active popup. Skipping.');
      return;
    }

    // Check if already saved
    final existingItems = DatabaseService.getAllItems();
    final alreadyExists = existingItems.any((item) => item.id == asset.id);
    if (alreadyExists) {
      debugPrint('DEBUG: Screenshot ${asset.id} already exists in database. Skipping popup.');
      return;
    }

    _pendingPopups.add(asset.id);
    debugPrint('DEBUG: Showing popup for asset: ${asset.id}');

    // Use showGeneralDialog to bypass Hero system entirely
    showGeneralDialog(
      context: navigator.context,
      barrierDismissible: false,
      barrierLabel: 'Screenshot Popup',
      barrierColor: CupertinoColors.black.withOpacity(0.4),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) {
        return Align(
          alignment: Alignment.bottomCenter,
          child: ScreenshotPopup(
            asset: asset,
            onSave: (note, category, extractedText) async {
              _pendingPopups.remove(asset.id);
              final file = await asset.file;
              if (file == null) {
                debugPrint('DEBUG: Error - asset file is null.');
                return;
              }

              final newItem = ScreenshotItem(
                id: asset.id,
                path: file.path,
                note: note,
                category: category,
                createdAt: DateTime.now(),
                extractedText: extractedText,
              );
              await DatabaseService.addItem(newItem);
            },
            onDelete: () {
              _pendingPopups.remove(asset.id);
            },
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 1),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut)),
          child: child,
        );
      },
    ).then((_) {
      _pendingPopups.remove(asset.id);
    });
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final isDark = prefs.getBool('isDark') ?? false;
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
      title: 'Snapi',
      theme: CupertinoThemeData(
        primaryColor: CupertinoColors.activeBlue,
        brightness: _brightness,
        scaffoldBackgroundColor: _brightness == Brightness.dark 
            ? CupertinoColors.black 
            : CupertinoColors.white,
      ),
      home: widget.initialWidget,
      debugShowCheckedModeBanner: false,
      routes: {
        '/permissions_slider': (context) => const PermissionsSliderScreen(),
        '/home': (context) => const MainScreen(),
      },
    );
  }
}
