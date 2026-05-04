import 'package:flutter/cupertino.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart';
import '../services/database_service.dart';
import '../services/screenshot_service.dart';
import 'recycle_bin_screen.dart';
import 'category_manager_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  int _totalCaptures = 0;
  int _deletedCaptures = 0;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }
  void _loadStats() {
    setState(() {
      _totalCaptures = DatabaseService.getAllItems().length;
      _deletedCaptures = DatabaseService.getDeletedItems().length;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;

    // Reload stats when building in case we return from Recycle Bin
    _loadStats();

    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Settings'),
      ),
      child: SafeArea(
        child: ListView(
          children: [
            CupertinoListSection.insetGrouped(
              header: const Text('Appearance'),
              children: [
                CupertinoListTile(
                  title: const Text('Dark Mode'),
                  leading: const Icon(CupertinoIcons.moon_fill),
                  trailing: CupertinoSwitch(
                    value: isDark,
                    onChanged: (value) {
                      SnapiApp.of(context).toggleTheme();
                    },
                  ),
                ),
                CupertinoListTile(
                  title: const Text('Manage Folders'),
                  leading: const Icon(CupertinoIcons.folder_badge_plus, color: CupertinoColors.activeBlue),
                  trailing: const CupertinoListTileChevron(),
                  onTap: () {
                    Navigator.push(
                      context,
                      CupertinoPageRoute(builder: (context) => const CategoryManagerScreen()),
                    );
                  },
                ),
              ],
            ),
            CupertinoListSection.insetGrouped(
              header: const Text('Storage & Data'),
              children: [
                CupertinoListTile(
                  title: const Text('Total Captures'),
                  leading: const Icon(CupertinoIcons.doc_on_clipboard_fill, color: CupertinoColors.systemGreen),
                  trailing: Text('$_totalCaptures saved', style: const TextStyle(color: CupertinoColors.systemGrey)),
                ),
                CupertinoListTile(
                  title: const Text('Recycle Bin'),
                  leading: const Icon(CupertinoIcons.trash, color: CupertinoColors.systemOrange),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('$_deletedCaptures items', style: const TextStyle(color: CupertinoColors.systemGrey)),
                      const SizedBox(width: 8),
                      const CupertinoListTileChevron(),
                    ],
                  ),
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
              header: const Text('Help & Support'),
              children: [
                CupertinoListTile(
                  title: const Text('Privacy Policy'),
                  leading: const Icon(CupertinoIcons.shield_fill, color: CupertinoColors.activeBlue),
                  trailing: const CupertinoListTileChevron(),
                  onTap: () {
                    showCupertinoDialog(
                      context: context,
                      builder: (context) => CupertinoAlertDialog(
                        title: const Text('Privacy Policy'),
                        content: const Text('Your screenshots and notes stay safely on your device. We don’t upload any personal data to the cloud mainly because we don’t have personal servers, and honestly running them would be too expensive.'),
                        actions: [
                          CupertinoDialogAction(
                            child: const Text('OK'),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                CupertinoListTile(
                  title: const Text('About'),
                  leading: const Icon(CupertinoIcons.info_circle_fill, color: CupertinoColors.systemGrey),
                  trailing: const Text('v1.0.0'),
                ),
              ],
            ),
            const SizedBox(height: 100), // Space for bottom nav
          ],
        ),
      ),
    );
  }
}
