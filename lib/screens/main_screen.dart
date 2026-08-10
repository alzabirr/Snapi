import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'home_screen.dart';
import 'settings_screen.dart';
import 'add_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  static final ValueNotifier<double> scrollOffsetNotifier = ValueNotifier(0);

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen>
    with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  int? _pressedIndex;

  late final AnimationController _controller;
  late final Animation<double> _slideAnimation;

  double _startCenter = 31.0;
  double _targetCenter = 31.0;
  double _moveDistance = 0.0;

  double _getCenterForIndex(int index) {
    switch (index) {
      case 0:
        return 5.0 + 26.0; // 31.0
      case 2:
        return 72.0 + 26.0; // 98.0
      case 1:
        return 139.0 + 26.0; // 165.0
      default:
        return 31.0;
    }
  }

  @override
  void initState() {
    super.initState();
    _startCenter = _getCenterForIndex(_currentIndex);
    _targetCenter = _startCenter;

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 360),
    );

    _slideAnimation = CurvedAnimation(
      parent: _controller,
      curve: const Cubic(0.2, 0.0, 0.0, 1.0),
    );

    _controller.value = 1.0;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTabSelected(int index) {
    if (_currentIndex == index) return;

    HapticFeedback.lightImpact();

    final fromCenter = _getCenterForIndex(_currentIndex);
    final toCenter = _getCenterForIndex(index);

    setState(() {
      _startCenter = fromCenter;
      _targetCenter = toCenter;
      _moveDistance = (_targetCenter - _startCenter).abs();
      _currentIndex = index;
    });

    _controller.forward(from: 0.0);
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
          // Screens with smooth fade transitions
          IndexedStack(
            index: _currentIndex,
            children: [
              _buildScreenWrapper(0, const HomeScreen()),
              _buildScreenWrapper(1, const SettingsScreen()),
              _buildScreenWrapper(2, AddScreen(isActive: _currentIndex == 2)),
            ],
          ),

          // Floating Liquid Glassmorphic Navigation Bar
          Positioned(
            left: 0,
            right: 0,
            bottom: 22,
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
                    clipBehavior: Clip.none,
                    children: [
                      // Translucent Glass Capsule Background (Isolated with RepaintBoundary for 60/120fps fluidity)
                      Positioned.fill(
                        child: RepaintBoundary(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(31),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? Colors.black.withValues(alpha: 0.38)
                                      : Colors.white.withValues(alpha: 0.38),
                                  borderRadius: BorderRadius.circular(31),
                                  border: Border.all(
                                    color: isDark
                                        ? Colors.white.withValues(alpha: 0.14)
                                        : Colors.white.withValues(alpha: 0.7),
                                    width: 1.2,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: isDark ? 0.45 : 0.12,
                                      ),
                                      blurRadius: 24,
                                      offset: const Offset(0, 10),
                                    ),
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: isDark ? 0.2 : 0.04,
                                      ),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),

                      // Fluid Morphing Selection Pill (Spring & Liquid Stretch)
                      AnimatedBuilder(
                        animation: _slideAnimation,
                        builder: (context, child) {
                          final t = _slideAnimation.value;
                          final currentCenter = lerpDouble(
                            _startCenter,
                            _targetCenter,
                            t,
                          )!;

                          // Liquid stretch factor during transition flight
                          final stretchAmount = _moveDistance > 80 ? 12.0 : 7.0;
                          final currentStretch =
                              math.sin(t * math.pi) * stretchAmount;
                          final pillWidth = 52.0 + currentStretch;
                          final pillLeft = currentCenter - (pillWidth / 2);

                          return Positioned(
                            left: pillLeft,
                            top: 5,
                            child: Container(
                              width: pillWidth,
                              height: 52,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(26),
                                color: isDark
                                    ? const Color(0xFF2E2E32)
                                    : Colors.white.withValues(alpha: 0.95),
                                border: Border.all(
                                  color: isDark
                                      ? Colors.white.withValues(alpha: 0.12)
                                      : Colors.white.withValues(alpha: 0.85),
                                  width: 0.8,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(
                                      alpha: isDark ? 0.38 : 0.08,
                                    ),
                                    blurRadius: 10,
                                    spreadRadius: 0,
                                    offset: const Offset(0, 3),
                                  ),
                                  BoxShadow(
                                    color: isDark
                                        ? Colors.white.withValues(alpha: 0.05)
                                        : Colors.white.withValues(alpha: 0.7),
                                    blurRadius: 2,
                                    spreadRadius: 0,
                                    offset: const Offset(0, -1),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),

                      // Interactive Navigation Items with Tactile Bounce
                      Positioned(
                        left: 5,
                        top: 5,
                        child: _buildNavItem(
                          index: 0,
                          outlinedIcon: Icons.photo_library_outlined,
                          filledIcon: Icons.photo_library_rounded,
                        ),
                      ),
                      Positioned(
                        left: 72,
                        top: 5,
                        child: _buildNavItem(
                          index: 2,
                          outlinedIcon: Icons.add_rounded,
                          filledIcon: Icons.add_rounded,
                        ),
                      ),
                      Positioned(
                        left: 139,
                        top: 5,
                        child: _buildNavItem(
                          index: 1,
                          outlinedIcon: Icons.settings_outlined,
                          filledIcon: Icons.settings_rounded,
                        ),
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

  Widget _buildScreenWrapper(int index, Widget child) {
    final isCurrent = _currentIndex == index;
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      opacity: isCurrent ? 1.0 : 0.0,
      child: child,
    );
  }

  Widget _buildNavItem({
    required int index,
    required IconData outlinedIcon,
    required IconData filledIcon,
  }) {
    final isSelected = _currentIndex == index;
    final isPressed = _pressedIndex == index;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final activeIcon = isSelected ? filledIcon : outlinedIcon;

    final iconColor = isDark
        ? (isSelected ? Colors.white : Colors.white.withValues(alpha: 0.45))
        : (isSelected ? Colors.black : Colors.black.withValues(alpha: 0.42));

    return GestureDetector(
      onTapDown: (_) {
        setState(() {
          _pressedIndex = index;
        });
      },
      onTapUp: (_) {
        setState(() {
          _pressedIndex = null;
        });
      },
      onTapCancel: () {
        setState(() {
          _pressedIndex = null;
        });
      },
      onTap: () => _onTabSelected(index),
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 52,
        height: 52,
        child: Center(
          child: AnimatedScale(
            duration: Duration(milliseconds: isPressed ? 100 : 250),
            curve: isPressed ? Curves.easeOutQuad : Curves.easeOutBack,
            scale: isPressed ? 0.88 : (isSelected ? 1.06 : 0.94),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, anim) {
                return FadeTransition(
                  opacity: anim,
                  child: ScaleTransition(
                    scale: Tween<double>(begin: 0.85, end: 1.0).animate(anim),
                    child: child,
                  ),
                );
              },
              child: Icon(
                activeIcon,
                key: ValueKey<String>('${index}_${isSelected}_$isDark'),
                color: iconColor,
                size: 26,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
