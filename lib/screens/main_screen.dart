import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'home_screen.dart';
import 'settings_screen.dart';
import 'add_screen.dart';
import 'search_screen.dart';
import 'category_screen.dart';
import 'visual_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  
  final List<Widget> _screens = [
    const HomeScreen(),
    const CategoryScreen(),
    const VisualScreen(),
    const SettingsScreen(),
    const AddScreen(), // The separate + button will switch to this or show it
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;

    return CupertinoPageScaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: CupertinoTheme.of(context).scaffoldBackgroundColor,
      child: Stack(
        children: [
          // Main Content
          IndexedStack(
            index: _currentIndex,
            children: _screens,
          ),
          
          // Custom Floating Navigation Bar (Matching Image)
          Positioned(
              bottom: 24,
              left: 16,
              right: 16,
              child: Row(
              children: [
                // Main Capsule for Nav Items
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(40),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                      child: Container(
                        height: 60,
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          color: (isDark ? const Color(0xFF1C1C1E) : CupertinoColors.white).withOpacity(0.8),
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(
                            color: CupertinoColors.label.resolveFrom(context).withOpacity(0.1),
                            width: 0.5,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildNavItem(0, CupertinoIcons.photo_on_rectangle),
                            _buildNavItem(1, CupertinoIcons.folder),
                            _buildNavItem(2, CupertinoIcons.graph_circle),
                            _buildNavItem(3, CupertinoIcons.settings),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Separate Add Button (Matching Image)
                GestureDetector(
                  onTap: () => setState(() => _currentIndex = 4),
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: (isDark ? const Color(0xFF1C1C1E) : CupertinoColors.white).withOpacity(0.8),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: CupertinoColors.label.resolveFrom(context).withOpacity(0.1),
                        width: 0.5,
                      ),
                      boxShadow: isDark ? [] : [
                        BoxShadow(
                          color: CupertinoColors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(30),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                        child: Center(
                          child: Icon(
                            CupertinoIcons.plus,
                            color: _currentIndex == 4 ? CupertinoColors.activeBlue : CupertinoColors.label.resolveFrom(context).withOpacity(0.8),
                            size: 24,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon) {
    final isSelected = _currentIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected 
              ? (CupertinoTheme.of(context).brightness == Brightness.dark 
                  ? CupertinoColors.white.withOpacity(0.08) 
                  : CupertinoColors.black.withOpacity(0.05)) 
              : CupertinoColors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Icon(
          icon,
          color: isSelected ? CupertinoColors.activeBlue : CupertinoColors.label.resolveFrom(context).withOpacity(0.6),
          size: 22,
        ),
      ),
    );
  }
}
