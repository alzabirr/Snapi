import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'settings_screen.dart';
import 'add_screen.dart';
import 'category_screen.dart';
import 'visual_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  static final ValueNotifier<double> scrollOffsetNotifier = ValueNotifier(0);

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  bool _navVisible = true;
  late AnimationController _animController;
  late Animation<Offset> _slideAnimation;
  double _previousScrollOffset = 0;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _slideAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(0, 1),
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeInOut));

    MainScreen.scrollOffsetNotifier.addListener(_onScrollUpdate);
  }

  @override
  void dispose() {
    MainScreen.scrollOffsetNotifier.removeListener(_onScrollUpdate);
    _animController.dispose();
    super.dispose();
  }

  void _onScrollUpdate() {
    final currentOffset = MainScreen.scrollOffsetNotifier.value;
    final delta = currentOffset - _previousScrollOffset;

    if (delta > 10 && _navVisible) {
      _navVisible = false;
      _animController.forward();
    } else if (delta < -10 && !_navVisible) {
      _navVisible = true;
      _animController.reverse();
    }

    _previousScrollOffset = currentOffset;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Stack(
        children: [
          IndexedStack(
            index: _currentIndex,
            children: [
              const HomeScreen(),
              const CategoryScreen(),
              const VisualScreen(),
              const SettingsScreen(),
              AddScreen(isActive: _currentIndex == 4),
            ],
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SlideTransition(
              position: _slideAnimation,
              child: Container(
                color: Theme.of(context).scaffoldBackgroundColor,
                child: SafeArea(
                  top: false,
                  child: SizedBox(
                    height: 52,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildNavItem(0, Icons.photo_library_outlined, Icons.photo_library),
                        _buildNavItem(1, Icons.folder_outlined, Icons.folder),
                        _buildCenterAddButton(),
                        _buildNavItem(2, Icons.analytics_outlined, Icons.analytics),
                        _buildNavItem(3, Icons.settings_outlined, Icons.settings),
                      ],
                    ),
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
    return GestureDetector(
      onTap: () {
        setState(() {
          _currentIndex = index;
          _navVisible = true;
          _animController.reverse();
          _previousScrollOffset = 0;
        });
      },
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 56,
        height: 56,
        child: Center(
          child: Icon(
            isSelected ? filledIcon : outlinedIcon,
            color: isSelected
                ? (isDark ? Colors.white : Colors.black)
                : (isDark ? Colors.grey.shade600 : Colors.grey),
            size: 28,
          ),
        ),
      ),
    );
  }

  Widget _buildCenterAddButton() {
    final isSelected = _currentIndex == 4;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: () {
        setState(() {
          _currentIndex = 4;
          _navVisible = true;
          _animController.reverse();
          _previousScrollOffset = 0;
        });
      },
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 48,
        height: 40,
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? Colors.white : Colors.black)
              : (isDark ? Colors.grey.shade600 : Colors.grey),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(
          Icons.add,
          color: isDark ? Colors.black : Colors.white,
          size: 28,
        ),
      ),
    );
  }
}
