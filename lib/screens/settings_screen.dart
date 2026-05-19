import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart' show Colors, Material;
import 'package:permission_handler/permission_handler.dart';
import '../main.dart';
import '../services/database_service.dart';
import '../services/screenshot_service.dart';
import 'recycle_bin_screen.dart';
import 'category_manager_screen.dart';
import '../widgets/floating_profile_icon.dart';
import 'smart_organize_detail_screen.dart';
import 'package:photo_manager/photo_manager.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> with WidgetsBindingObserver {
  int _totalCaptures = 0;
  int _deletedCaptures = 0;
  bool _showScreenshotNotifications = true;
  bool _autoSmartFolders = true;
  bool _isMonitoring = true;
  PermissionStatus _micStatus = PermissionStatus.denied;
  PermissionStatus _notificationStatus = PermissionStatus.denied;
  PermissionState _galleryStatus = PermissionState.denied;
  bool _isGalleryLimited = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadStats();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadStats();
    }
  }
  void _loadStats() async {
    final prefs = await SharedPreferences.getInstance();
    final mic = await Permission.microphone.status;
    final notif = await Permission.notification.status;
    final gallery = await PhotoManager.getPermissionState(requestOption: const PermissionRequestOption());
    final phPhotos = await Permission.photos.status;
    final assetCount = await PhotoManager.getAssetCount();
    final service = FlutterBackgroundService();
    final isRunning = await service.isRunning();
    
    setState(() {
      _totalCaptures = DatabaseService.getAllItems().length;
      _deletedCaptures = DatabaseService.getDeletedItems().length;
      _showScreenshotNotifications = prefs.getBool('show_screenshot_notifications') ?? true;
      _autoSmartFolders = prefs.getBool('auto_smart_folders') ?? true;
      _isMonitoring = prefs.getBool('is_monitoring_enabled') ?? true;
      _micStatus = mic;
      _notificationStatus = notif;
      _galleryStatus = gallery;
      // Use the same suspicious count check as Home Screen for consistency
      _isGalleryLimited = (gallery == PermissionState.limited) || 
                          (phPhotos == PermissionStatus.limited) ||
                          (gallery == PermissionState.authorized && assetCount > 0 && assetCount < 5);
    });
  }

  String _getStatusText(PermissionStatus status) {
    if (status.isGranted) return 'Allowed';
    if (status.isPermanentlyDenied) return 'Denied';
    if (status.isLimited) return 'Limited';
    return 'Not Set';
  }

  Future<void> _toggleScreenshotNotifications(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('show_screenshot_notifications', value);
    
    // Notify the background service immediately
    FlutterBackgroundService().invoke('updateConfig', {
      'showNotifications': value,
    });

    setState(() {
      _showScreenshotNotifications = value;
    });
  }
  Future<void> _toggleAutoSmartFolders(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('auto_smart_folders', value);
    setState(() {
      _autoSmartFolders = value;
    });
  }

  Future<void> _toggleMonitoring(bool value) async {
    setState(() {
      _isMonitoring = value;
    });

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_monitoring_enabled', value);
    
    final service = FlutterBackgroundService();
    final isRunning = await service.isRunning();
    
    if (value) {
      if (!isRunning) {
        await service.startService();
      }
      service.invoke('updateConfig', {'is_monitoring_enabled': true});
    } else {
      if (isRunning) {
        service.invoke('stopService');
      }
      // Force cancel notification from main UI immediately
      final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
      await flutterLocalNotificationsPlugin.cancel(888);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;


    return CupertinoPageScaffold(
      backgroundColor: isDark ? const Color(0xFF000000) : const Color(0xFFF2F2F7),
      navigationBar: CupertinoNavigationBar(
        transitionBetweenRoutes: false,
        middle: const Text('Settings'),
        backgroundColor: (isDark ? const Color(0xFF000000) : const Color(0xFFF2F2F7)).withOpacity(0.8),
        border: null,
      ),
      child: SafeArea(
        child: ListView(
          physics: const BouncingScrollPhysics(),
          children: [
            // iOS Style Profile/Stats Header (Interactive)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              child: GestureDetector(
                onTap: () => _showAssistantModal(context),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1C1C1E) : CupertinoColors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: isDark ? [] : [
                      BoxShadow(
                        color: CupertinoColors.black.withOpacity(0.03),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      const FloatingProfileIcon(),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  'Snapi Assistant',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? CupertinoColors.white : CupertinoColors.black,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                const Icon(CupertinoIcons.sparkles, color: CupertinoColors.activeBlue, size: 16),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Your personal AI companion',
                              style: const TextStyle(
                                fontSize: 14,
                                color: CupertinoColors.systemGrey,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(CupertinoIcons.chevron_right, color: CupertinoColors.systemGrey3, size: 18),
                    ],
                  ),
                ),
              ),
            ),

            CupertinoListSection.insetGrouped(
              backgroundColor: CupertinoColors.transparent,
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
              children: [
                CupertinoListTile(
                  title: const Text('Saved Captures'),
                  leading: _buildIOSIcon(CupertinoIcons.doc_on_clipboard_fill, CupertinoColors.systemGreen),
                  trailing: Text('$_totalCaptures', style: const TextStyle(color: CupertinoColors.systemGrey)),
                ),
              ],
            ),

            CupertinoListSection.insetGrouped(
              backgroundColor: CupertinoColors.transparent,
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
              children: [
                CupertinoListTile(
                  title: const Text('Dark Mode'),
                  leading: _buildIOSIcon(CupertinoIcons.moon_fill, CupertinoColors.systemPurple),
                  trailing: CupertinoSwitch(
                    value: isDark,
                    onChanged: (value) {
                      SnapiApp.of(context).toggleTheme();
                    },
                  ),
                ),
                CupertinoListTile(
                  title: const Text('Smart Auto-Organize'),
                  subtitle: const Text('AI-powered sorting • Tap to see how it works'),
                  leading: _buildIOSIcon(CupertinoIcons.sparkles, CupertinoColors.activeBlue),
                  trailing: CupertinoSwitch(
                    value: _autoSmartFolders,
                    onChanged: _toggleAutoSmartFolders,
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      CupertinoPageRoute(builder: (context) => const SmartOrganizeDetailScreen()),
                    );
                  },
                ),
              ],
            ),

            CupertinoListSection.insetGrouped(
              backgroundColor: CupertinoColors.transparent,
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
              children: [
                CupertinoListTile(
                  title: const Text('Recycle Bin'),
                  leading: _buildIOSIcon(CupertinoIcons.trash_fill, CupertinoColors.systemOrange),
                  trailing: const CupertinoListTileChevron(),
                  onTap: () async {
                    await Navigator.push(
                      context,
                      CupertinoPageRoute(builder: (context) => const RecycleBinScreen()),
                    );
                    _loadStats();
                  },
                ),
              ],
            ),

            CupertinoListSection.insetGrouped(
              backgroundColor: CupertinoColors.transparent,
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
              header: const Text('App Permissions'),
              children: [
                CupertinoListTile(
                  title: const Text('Background Monitoring'),
                  leading: _buildIOSIcon(CupertinoIcons.bolt_fill, CupertinoColors.systemYellow),
                  trailing: CupertinoSwitch(
                    value: _isMonitoring,
                    onChanged: _toggleMonitoring,
                  ),
                ),

                CupertinoListTile(
                  title: const Text('Screenshot Detect Alert'),
                  leading: _buildIOSIcon(CupertinoIcons.eye_fill, CupertinoColors.systemTeal),
                  trailing: CupertinoSwitch(
                    value: _showScreenshotNotifications,
                    onChanged: _toggleScreenshotNotifications,
                  ),
                ),
                CupertinoListTile(
                  title: const Text('Gallery Access'),
                  leading: _buildIOSIcon(CupertinoIcons.photo_fill, CupertinoColors.systemPink),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _isGalleryLimited ? 'Limited' : (_galleryStatus.isAuth ? 'Allowed' : 'Denied'),
                        style: TextStyle(
                          color: _isGalleryLimited ? CupertinoColors.systemOrange : (_galleryStatus.isAuth ? CupertinoColors.systemGrey : CupertinoColors.systemRed),
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(CupertinoIcons.chevron_right, color: CupertinoColors.systemGrey3, size: 14),
                    ],
                  ),
                  onTap: () => openAppSettings(),
                ),
              ],
            ),

            CupertinoListSection.insetGrouped(
              backgroundColor: CupertinoColors.transparent,
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
              children: [
                CupertinoListTile(
                  title: const Text('Privacy Policy'),
                  leading: _buildIOSIcon(CupertinoIcons.shield_fill, CupertinoColors.systemGreen),
                  trailing: const CupertinoListTileChevron(),
                  onTap: () => _showPrivacyPolicy(context),
                ),
              ],
            ),
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  Widget _buildIOSIcon(IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Icon(icon, color: CupertinoColors.white, size: 20),
    );
  }

  Widget _buildMinimalStat(String label, String value) {
    // Keep it just in case, but unused in this layout
    return const SizedBox.shrink();
  }

  void _showAssistantModal(BuildContext context) {
    final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;
    showCupertinoModalPopup(
      context: context,
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          height: MediaQuery.of(context).size.height * 0.7,
          decoration: BoxDecoration(
            color: (isDark ? const Color(0xFF1C1C1E) : CupertinoColors.white).withOpacity(0.85),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
            border: Border.all(
              color: (isDark ? CupertinoColors.white : CupertinoColors.activeBlue).withOpacity(0.1),
            ),
          ),
          child: Stack(
            children: [
              // Top Background Glow
              Positioned(
                top: -100,
                left: -50,
                right: -50,
                child: Container(
                  height: 300,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        CupertinoColors.activeBlue.withOpacity(isDark ? 0.2 : 0.1),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    const SizedBox(height: 12),
                    Container(
                      width: 36,
                      height: 5,
                      decoration: BoxDecoration(
                        color: CupertinoColors.systemGrey4.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(2.5),
                      ),
                    ),
                    const SizedBox(height: 40),
                    
                    // Animated Mascot
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.8, end: 1.0),
                      duration: const Duration(milliseconds: 600),
                      curve: Curves.easeOutBack,
                      builder: (context, value, child) => Transform.scale(
                        scale: value,
                        child: child,
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: CupertinoColors.activeBlue.withOpacity(0.05),
                        ),
                        child: Image.asset('assets/snapi.png', width: 140, height: 140),
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                    const Text(
                      "Meet your Snapi Assistant",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 26, 
                        fontWeight: FontWeight.w800,
                        letterSpacing: -1,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      "I'm here to help you manage your memories.\nI'm learning more every day!",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16, 
                        color: CupertinoColors.secondaryLabel.resolveFrom(context),
                        height: 1.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    
                    const SizedBox(height: 32),
                    
                    // Action Chips
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      alignment: WrapAlignment.center,
                      children: [
                        _buildAssistantChip(CupertinoIcons.lightbulb_fill, "View Tips"),
                        _buildAssistantChip(CupertinoIcons.bolt_fill, "Quick Start"),
                        _buildAssistantChip(CupertinoIcons.question_circle_fill, "Get Help"),
                      ],
                    ),
                    
                    const Spacer(),
                    
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: () => Navigator.pop(context),
                      child: Container(
                        width: double.infinity,
                        height: 56,
                        decoration: BoxDecoration(
                          color: CupertinoColors.activeBlue,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: const Center(
                          child: Text(
                            "Coming soon !",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAssistantChip(IconData icon, String label) {
    final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: (isDark ? CupertinoColors.white : CupertinoColors.activeBlue).withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: CupertinoColors.activeBlue),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: CupertinoColors.activeBlue,
            ),
          ),
        ],
      ),
    );
  }

  void _showAutoOrganizeInfo(BuildContext context) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Smart Auto-Organize'),
        content: const Column(
          children: [
            SizedBox(height: 12),
            Text(
              'Snapi uses AI to read the text inside your screenshots and automatically suggests the best folder for them.',
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 12),
            Text(
              'If a matching folder doesn\'t exist, Snapi will even create it for you! You always have the final say before saving.',
              style: TextStyle(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('Got it'),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  void _showPrivacyPolicy(BuildContext context) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: CupertinoColors.black.withOpacity(0.55),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, anim1, anim2) => const SizedBox.shrink(),
      transitionBuilder: (context, anim1, anim2, child) {
        final curveValue = Curves.easeOutBack.transform(anim1.value);
        final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;
        
        return Transform.scale(
          scale: curveValue,
          child: Opacity(
            opacity: anim1.value.clamp(0.0, 1.0),
            child: Center(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 24),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1C1C1E) : CupertinoColors.white,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(isDark ? 0.45 : 0.12),
                      blurRadius: 36,
                      offset: const Offset(0, 16),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Privacy Shield Header Icon
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: CupertinoColors.activeBlue.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          CupertinoIcons.shield_fill,
                          color: CupertinoColors.activeBlue,
                          size: 40,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Privacy Policy',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w400,
                          color: isDark ? CupertinoColors.white : const Color(0xFF1F1F1F),
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Your trust is our priority. Snapi is designed to protect your personal space.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w400,
                          color: isDark ? CupertinoColors.systemGrey : const Color(0xFF555555),
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 20),
                      
                      // Bullet Points
                      _buildPrivacyItem(
                        context,
                        CupertinoIcons.device_phone_portrait,
                        '100% Local Processing',
                        'All text recognition and organization happen locally on your phone.',
                        isDark,
                      ),
                      const SizedBox(height: 12),
                      _buildPrivacyItem(
                        context,
                        CupertinoIcons.eye_slash,
                        'Zero Cloud Uploads',
                        'We never upload your screenshots, voice notes, or metadata to any servers.',
                        isDark,
                      ),
                      const SizedBox(height: 12),
                      _buildPrivacyItem(
                        context,
                        CupertinoIcons.lock_fill,
                        'Completely Private',
                        'No analytics or trackers. Your personal database belongs only to you.',
                        isDark,
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Dismiss Button
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          width: double.infinity,
                          height: 48,
                          decoration: BoxDecoration(
                            color: CupertinoColors.activeBlue,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Center(
                            child: Text(
                              'Got it',
                              style: TextStyle(
                                color: CupertinoColors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPrivacyItem(
    BuildContext context,
    IconData icon,
    String title,
    String desc,
    bool isDark,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          color: CupertinoColors.activeBlue,
          size: 18,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: isDark ? CupertinoColors.white : const Color(0xFF1E1E1E),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                desc,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: isDark ? CupertinoColors.systemGrey2 : const Color(0xFF666666),
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
