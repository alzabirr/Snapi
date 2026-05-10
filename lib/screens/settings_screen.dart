import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart' show Colors;
import 'package:permission_handler/permission_handler.dart';
import '../main.dart';
import '../services/database_service.dart';
import '../services/screenshot_service.dart';
import 'recycle_bin_screen.dart';
import 'category_manager_screen.dart';
import '../widgets/floating_profile_icon.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  int _totalCaptures = 0;
  int _deletedCaptures = 0;
  bool _showScreenshotNotifications = true;
  bool _autoSmartFolders = true;
  PermissionStatus _micStatus = PermissionStatus.denied;
  PermissionStatus _notificationStatus = PermissionStatus.denied;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }
  void _loadStats() async {
    final prefs = await SharedPreferences.getInstance();
    final mic = await Permission.microphone.status;
    final notif = await Permission.notification.status;
    
    setState(() {
      _totalCaptures = DatabaseService.getAllItems().length;
      _deletedCaptures = DatabaseService.getDeletedItems().length;
      _showScreenshotNotifications = prefs.getBool('show_screenshot_notifications') ?? true;
      _autoSmartFolders = prefs.getBool('auto_smart_folders') ?? true;
      _micStatus = mic;
      _notificationStatus = notif;
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
  @override
  Widget build(BuildContext context) {
    final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;


    return CupertinoPageScaffold(
      backgroundColor: isDark ? const Color(0xFF000000) : const Color(0xFFF2F2F7),
      navigationBar: CupertinoNavigationBar(
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
                  subtitle: const Text('AI-powered capture sorting'),
                  leading: _buildIOSIcon(CupertinoIcons.sparkles, CupertinoColors.activeBlue),
                  trailing: CupertinoSwitch(
                    value: _autoSmartFolders,
                    onChanged: _toggleAutoSmartFolders,
                  ),
                  onTap: () => _showAutoOrganizeInfo(context),
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
                  title: const Text('Screenshot Detect Alert'),
                  leading: _buildIOSIcon(CupertinoIcons.eye_fill, CupertinoColors.systemTeal),
                  trailing: CupertinoSwitch(
                    value: _showScreenshotNotifications,
                    onChanged: _toggleScreenshotNotifications,
                  ),
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
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Privacy Policy'),
        content: const Text('Your screenshots and notes stay safely on your device. We don’t upload any personal data to the cloud.'),
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
