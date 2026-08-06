import 'dart:ui';
import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'settings_screen.dart';
import 'add_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  static final ValueNotifier<double> scrollOffsetNotifier = ValueNotifier(0);

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  double _getIndicatorLeft() {
    switch (_currentIndex) {
      case 0:
        return 5;
      case 2:
        return 72;
      case 1:
        return 139;
      default:
        return 5;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Stack(
        children: [
          IndexedStack(
            index: _currentIndex,
            children: [
              const HomeScreen(),
              const SettingsScreen(),
              AddScreen(isActive: _currentIndex == 2),
            ],
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 20,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: SafeArea(
                top: false,
                left: false,
                right: false,
                child: SizedBox(
                  width: 196,
                  height: 62,
                  child: Stack(
                    children: [
                      // Translucent background capsule pill
                      Positioned.fill(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(31),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
                            child: Container(
                              decoration: BoxDecoration(
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.08)
                                    : Colors.white.withValues(alpha: 0.22),
                                borderRadius: BorderRadius.circular(31),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.15),
                                    blurRadius: 20,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      // Selection circular disc inside capsule
                      AnimatedPositioned(
                        duration: const Duration(milliseconds: 280),
                        curve: Curves.fastOutSlowIn,
                        left: _getIndicatorLeft(),
                        top: 5,
                        child: Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isDark
                                ? const Color(0xFF424242)
                                : Colors.white.withValues(alpha: 0.88),
                          ),
                        ),
                      ),
                      // Navigation items perfectly aligned over selection circle
                      Positioned(
                        left: 5,
                        top: 5,
                        child: _buildNavItem(0, Icons.photo_library_outlined, Icons.photo_library),
                      ),
                      Positioned(
                        left: 72,
                        top: 5,
                        child: _buildNavItem(2, Icons.add_rounded, Icons.add_rounded),
                      ),
                      Positioned(
                        left: 139,
                        top: 5,
                        child: _buildNavItem(1, Icons.settings_outlined, Icons.settings),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(int index, IconData outlinedIcon, IconData filledIcon) {
    final isSelected = _currentIndex == index;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final activeIcon = isDark
        ? (isSelected ? filledIcon : outlinedIcon)
        : outlinedIcon;

    return GestureDetector(
      onTap: () {
        setState(() {
          _currentIndex = index;
        });
      },
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 52,
        height: 52,
        child: Center(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeIn,
            transitionBuilder: (child, anim) {
              return FadeTransition(
                opacity: anim,
                child: child,
              );
            },
            child: Icon(
              activeIcon,
              key: ValueKey<String>('${index}_${isSelected}_$isDark'),
              color: isDark ? Colors.white : Colors.black,
              size: 28,
            ),
          ),
        ),
      ),
    );
  }
}
