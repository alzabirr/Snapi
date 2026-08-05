import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import '../main.dart';
import '../services/database_service.dart';
import '../services/screenshot_service.dart';
import 'recycle_bin_screen.dart';
import 'category_manager_screen.dart';
import 'category_screen.dart';
import 'visual_screen.dart';
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
      final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
      await flutterLocalNotificationsPlugin.cancel(888);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Settings',
          style: TextStyle(
            color: theme.colorScheme.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: SafeArea(
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          children: [
            // Profile Card
            GestureDetector(
              onTap: () => _showAssistantModal(context),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: theme.colorScheme.onSurface.withOpacity(0.08),
                    width: 0.5,
                  ),
                  boxShadow: isDark ? [] : [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
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
                                'Krabby Assistant',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: theme.colorScheme.onSurface,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Icon(Icons.auto_awesome, color: theme.colorScheme.primary, size: 16),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Your personal AI companion',
                            style: TextStyle(
                              fontSize: 13,
                              color: theme.colorScheme.onSurface.withOpacity(0.6),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right, color: theme.colorScheme.onSurface.withOpacity(0.4), size: 20),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Section 1: Stats
            _buildSectionHeader('General Info'),
            Card(
              elevation: 0,
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: theme.colorScheme.onSurface.withOpacity(0.08), width: 0.5),
              ),
              child: ListTile(
                leading: _buildIcon(Icons.assignment_turned_in_outlined, Colors.green),
                title: const Text('Saved Captures'),
                trailing: Text('$_totalCaptures', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface.withOpacity(0.7))),
              ),
            ),
            const SizedBox(height: 20),

            // Section 2: Personalization
            _buildSectionHeader('Appearance & AI'),
            Card(
              elevation: 0,
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: theme.colorScheme.onSurface.withOpacity(0.08), width: 0.5),
              ),
              child: Column(
                children: [
                  SwitchListTile(
                    secondary: _buildIcon(Icons.dark_mode_outlined, Colors.purple),
                    title: const Text('Dark Mode'),
                    value: isDark,
                    onChanged: (value) {
                      KrabbyApp.of(context).toggleTheme();
                    },
                    activeColor: theme.colorScheme.primary,
                  ),
                  Divider(height: 1, color: theme.colorScheme.onSurface.withOpacity(0.08)),
                  ListTile(
                    leading: _buildIcon(Icons.auto_awesome_outlined, Colors.blue),
                    title: const Text('Smart Auto-Organize'),
                    subtitle: const Text('AI-powered sorting • Learn how it works'),
                    trailing: Switch(
                      value: _autoSmartFolders,
                      onChanged: _toggleAutoSmartFolders,
                      activeColor: theme.colorScheme.primary,
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const SmartOrganizeDetailScreen()),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Section 3: Utilities
            _buildSectionHeader('Folders & Utilities'),
            Card(
              elevation: 0,
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: theme.colorScheme.onSurface.withOpacity(0.08), width: 0.5),
              ),
              child: Column(
                children: [
                  ListTile(
                    leading: _buildIcon(Icons.folder_outlined, Colors.amber),
                    title: const Text('My Folders'),
                    subtitle: const Text('Organize screenshots into categories'),
                    trailing: Icon(Icons.chevron_right, color: theme.colorScheme.onSurface.withOpacity(0.4)),
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const CategoryScreen()),
                      );
                      _loadStats();
                    },
                  ),
                  Divider(height: 1, color: theme.colorScheme.onSurface.withOpacity(0.08)),
                  ListTile(
                    leading: _buildIcon(Icons.analytics_outlined, Colors.indigo),
                    title: const Text('Visual Analytics'),
                    subtitle: const Text('Explore visual graph and clusters'),
                    trailing: Icon(Icons.chevron_right, color: theme.colorScheme.onSurface.withOpacity(0.4)),
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const VisualScreen()),
                      );
                      _loadStats();
                    },
                  ),
                  Divider(height: 1, color: theme.colorScheme.onSurface.withOpacity(0.08)),
                  ListTile(
                    leading: _buildIcon(Icons.delete_outline_rounded, Colors.orange),
                    title: const Text('Recycle Bin'),
                    trailing: Icon(Icons.chevron_right, color: theme.colorScheme.onSurface.withOpacity(0.4)),
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const RecycleBinScreen()),
                      );
                      _loadStats();
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Section 4: System Permissions
            _buildSectionHeader('App Permissions'),
            Card(
              elevation: 0,
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: theme.colorScheme.onSurface.withOpacity(0.08), width: 0.5),
              ),
              child: Column(
                children: [
                  SwitchListTile(
                    secondary: _buildIcon(Icons.electric_bolt_outlined, Colors.yellow.shade800),
                    title: const Text('Background Monitoring'),
                    value: _isMonitoring,
                    onChanged: _toggleMonitoring,
                    activeColor: theme.colorScheme.primary,
                  ),
                  Divider(height: 1, color: theme.colorScheme.onSurface.withOpacity(0.08)),
                  SwitchListTile(
                    secondary: _buildIcon(Icons.notifications_active_outlined, Colors.teal),
                    title: const Text('Screenshot Detect Alert'),
                    value: _showScreenshotNotifications,
                    onChanged: _toggleScreenshotNotifications,
                    activeColor: theme.colorScheme.primary,
                  ),
                  Divider(height: 1, color: theme.colorScheme.onSurface.withOpacity(0.08)),
                  ListTile(
                    leading: _buildIcon(Icons.photo_library_outlined, Colors.pink),
                    title: const Text('Gallery Access'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _isGalleryLimited ? 'Limited' : (_galleryStatus.isAuth ? 'Allowed' : 'Denied'),
                          style: TextStyle(
                            color: _isGalleryLimited ? Colors.orange : (_galleryStatus.isAuth ? theme.colorScheme.onSurface.withOpacity(0.6) : Colors.red),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(Icons.chevron_right, color: theme.colorScheme.onSurface.withOpacity(0.4), size: 16),
                      ],
                    ),
                    onTap: () => openAppSettings(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Section 5: Legal
            _buildSectionHeader('Info & Security'),
            Card(
              elevation: 0,
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: theme.colorScheme.onSurface.withOpacity(0.08), width: 0.5),
              ),
              child: ListTile(
                leading: _buildIcon(Icons.security_outlined, Colors.green),
                title: const Text('Privacy Policy'),
                trailing: Icon(Icons.chevron_right, color: theme.colorScheme.onSurface.withOpacity(0.4)),
                onTap: () => _showPrivacyPolicy(context),
              ),
            ),
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildIcon(IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, color: color, size: 20),
    );
  }

  void _showAssistantModal(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          height: MediaQuery.of(context).size.height * 0.7,
          decoration: BoxDecoration(
            color: (isDark ? const Color(0xFF1E293B) : Colors.white).withOpacity(0.9),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
            border: Border.all(
              color: theme.colorScheme.onSurface.withOpacity(0.08),
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
                        theme.colorScheme.primary.withOpacity(isDark ? 0.2 : 0.1),
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
                        color: theme.colorScheme.onSurface.withOpacity(0.2),
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
                          color: theme.colorScheme.primary.withOpacity(0.05),
                        ),
                        child: Image.asset('assets/krabby.png', width: 140, height: 140),
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                    Text(
                      "Meet your Krabby Assistant",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 24, 
                        fontWeight: FontWeight.w800,
                        color: theme.colorScheme.onSurface,
                        letterSpacing: -1,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      "I'm here to help you manage your memories.\nI'm learning more every day!",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15, 
                        color: theme.colorScheme.onSurface.withOpacity(0.6),
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
                        _buildAssistantChip(Icons.lightbulb, "View Tips"),
                        _buildAssistantChip(Icons.bolt, "Quick Start"),
                        _buildAssistantChip(Icons.help_center, "Get Help"),
                      ],
                    ),
                    
                    const Spacer(),
                    
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        minimumSize: const Size(double.infinity, 56),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: const Text(
                        "Coming soon !",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
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
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }

  void _showPrivacyPolicy(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (context) => Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 24),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: theme.colorScheme.onSurface.withOpacity(0.08), width: 0.5),
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
                    color: theme.colorScheme.primary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.security,
                    color: theme.colorScheme.primary,
                    size: 40,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Privacy Policy',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Your trust is our priority. Krabby is designed to protect your personal space.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w400,
                    color: theme.colorScheme.onSurface.withOpacity(0.7),
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 20),
                
                // Bullet Points
                _buildPrivacyItem(
                  context,
                  Icons.phone_android,
                  '100% Local Processing',
                  'All text recognition and organization happen locally on your phone.',
                ),
                const SizedBox(height: 12),
                _buildPrivacyItem(
                  context,
                  Icons.cloud_off,
                  'Zero Cloud Uploads',
                  'We never upload your screenshots, voice notes, or metadata to any servers.',
                ),
                const SizedBox(height: 12),
                _buildPrivacyItem(
                  context,
                  Icons.lock_outline,
                  'Completely Private',
                  'No analytics or trackers. Your personal database belongs only to you.',
                ),
                
                const SizedBox(height: 24),
                
                // Dismiss Button
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    minimumSize: const Size(double.infinity, 48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'Got it',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPrivacyItem(
    BuildContext context,
    IconData icon,
    String title,
    String desc,
  ) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          color: theme.colorScheme.primary,
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
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                desc,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
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
