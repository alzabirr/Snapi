import 'package:flutter/cupertino.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PermissionsSliderScreen extends StatefulWidget {
  const PermissionsSliderScreen({super.key});

  @override
  State<PermissionsSliderScreen> createState() => _PermissionsSliderScreenState();
}

class _PermissionsSliderScreenState extends State<PermissionsSliderScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<Map<String, dynamic>> _pages = [
    {
      'title': 'Hi, I am Snapi',
      'subtitle': 'Your personal space for screenshots.\nOrganize with voice, find with ease.',
      'isWelcome': true,
      'features': [
        {'icon': CupertinoIcons.square_grid_2x2_fill, 'text': 'Smart Catalog'},
        {'icon': CupertinoIcons.mic_fill, 'text': 'Voice Memos'},
        {'icon': CupertinoIcons.graph_circle_fill, 'text': 'Mind Map'},
      ],
      'action': (BuildContext context) async {},
    },
    {
      'title': 'Gallery Access',
      'subtitle': 'Snapi needs to see your photos to find and organize your screenshots automatically.',
      'icon': CupertinoIcons.photo_fill_on_rectangle_fill,
      'color': CupertinoColors.activeBlue,
      'action': (BuildContext context) async => await PhotoManager.requestPermissionExtend(),
    },
    {
      'title': 'Microphone',
      'subtitle': 'Enable your microphone to add voice memos and notes to your screenshots effortlessly.',
      'icon': CupertinoIcons.mic_fill,
      'color': CupertinoColors.systemPink,
      'action': (BuildContext context) async => await Permission.microphone.request(),
    },
    {
      'title': 'Notifications',
      'subtitle': 'Stay updated! Snapi will alert you when new screenshots are detected or reminders are due.',
      'icon': CupertinoIcons.bell_fill,
      'color': CupertinoColors.systemYellow,
      'action': (BuildContext context) async => await Permission.notification.request(),
    },
  ];

  void _handleNext() async {
    // Execute permission request for current page
    await _pages[_currentPage]['action'](context);

    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    } else {
      // Finish onboarding
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('seenOnboarding', true);
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/home');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.white,
      child: SafeArea(
        child: Column(
          children: [
            // Top Navigation Bar (Fixed height to prevent shifting)
            SizedBox(
              height: 44,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    if (_currentPage > 0)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: CupertinoButton(
                          padding: EdgeInsets.zero,
                          onPressed: () {
                            _pageController.previousPage(
                              duration: const Duration(milliseconds: 500),
                              curve: Curves.easeInOut,
                            );
                          },
                          child: const Icon(
                            CupertinoIcons.back,
                            color: CupertinoColors.activeBlue,
                          ),
                        ),
                      ),
                    
                    // Dots
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(_pages.length, (index) {
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: _currentPage == index ? 24 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: _currentPage == index 
                                ? CupertinoColors.activeBlue 
                                : CupertinoColors.systemGrey4,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        );
                      }),
                    ),
                  ],
                ),
              ),
            ),
            
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                physics: const BouncingScrollPhysics(),
                onPageChanged: (int page) {
                  setState(() => _currentPage = page);
                },
                itemCount: _pages.length,
                itemBuilder: (context, index) {
                  final page = _pages[index];
                  final isWelcome = page['isWelcome'] ?? false;
                  
                  return LayoutBuilder(
                    builder: (context, constraints) {
                      return SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(minHeight: constraints.maxHeight),
                          child: IntrinsicHeight(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 40.0),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const SizedBox(height: 20),
                                  
                                  // Fixed height container to keep alignment perfect
                                  SizedBox(
                                    height: 280,
                                    child: Center(
                                      child: _FloatingMascot(
                                        child: Stack(
                                          alignment: Alignment.bottomRight,
                                          children: [
                                            // Uniform Mascot Size
                                            Image.asset(
                                              'assets/snapi.png',
                                              width: 240,
                                              height: 240,
                                              fit: BoxFit.contain,
                                            ),
                                            if (page['icon'] != null)
                                              TweenAnimationBuilder<double>(
                                                tween: Tween(begin: 0.0, end: 1.0),
                                                duration: const Duration(milliseconds: 800),
                                                curve: Curves.easeOutBack,
                                                builder: (context, value, child) {
                                                  return Transform.scale(
                                                    scale: value,
                                                    child: child,
                                                  );
                                                },
                                                child: Container(
                                                  padding: const EdgeInsets.all(16),
                                                  decoration: BoxDecoration(
                                                    color: CupertinoColors.white.withOpacity(0.9),
                                                    shape: BoxShape.circle,
                                                    boxShadow: [
                                                      BoxShadow(
                                                        color: page['color'].withOpacity(0.2),
                                                        blurRadius: 20,
                                                        spreadRadius: 5,
                                                      ),
                                                      BoxShadow(
                                                        color: CupertinoColors.black.withOpacity(0.05),
                                                        blurRadius: 10,
                                                        offset: const Offset(0, 4),
                                                      ),
                                                    ],
                                                    border: Border.all(
                                                      color: CupertinoColors.white,
                                                      width: 2,
                                                    ),
                                                  ),
                                                  child: Icon(
                                                    page['icon'],
                                                    color: page['color'],
                                                    size: 36,
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  
                                  const SizedBox(height: 30),
                                  
                                  // Unified Animated Text Content
                                  TweenAnimationBuilder<double>(
                                    key: ValueKey(index),
                                    tween: Tween(begin: 0.0, end: 1.0),
                                    duration: const Duration(milliseconds: 600),
                                    curve: Curves.easeOutCubic,
                                    builder: (context, value, child) {
                                      return Opacity(
                                        opacity: value,
                                        child: Transform.translate(
                                          offset: Offset(0, 20 * (1 - value)),
                                          child: child,
                                        ),
                                      );
                                    },
                                    child: Column(
                                      children: [
                                        Text(
                                          page['title'],
                                          style: const TextStyle(
                                            fontSize: 32,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: -1.5,
                                            color: CupertinoColors.black,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                        const SizedBox(height: 12),
                                        Text(
                                          page['subtitle'],
                                          style: const TextStyle(
                                            fontSize: 16,
                                            color: CupertinoColors.secondaryLabel,
                                            height: 1.4,
                                            letterSpacing: -0.2,
                                            fontWeight: FontWeight.w500,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                        
                                        // Fixed height space for features to prevent layout shifting
                                        SizedBox(
                                          height: 110,
                                          child: (isWelcome && page['features'] != null)
                                            ? Padding(
                                                padding: const EdgeInsets.only(top: 30.0),
                                                child: Row(
                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                  children: (page['features'] as List).map((f) {
                                                    return Padding(
                                                      padding: const EdgeInsets.symmetric(horizontal: 10.0),
                                                      child: Column(
                                                        children: [
                                                          Container(
                                                            padding: const EdgeInsets.all(10),
                                                            decoration: BoxDecoration(
                                                              color: CupertinoColors.systemGrey6,
                                                              borderRadius: BorderRadius.circular(12),
                                                            ),
                                                            child: Icon(f['icon'] as IconData, size: 22, color: CupertinoColors.activeBlue),
                                                          ),
                                                          const SizedBox(height: 6),
                                                          Text(
                                                            f['text'] as String,
                                                            style: const TextStyle(
                                                              fontSize: 11,
                                                              fontWeight: FontWeight.w600,
                                                              color: CupertinoColors.secondaryLabel,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    );
                                                  }).toList(),
                                                ),
                                              )
                                            : const SizedBox.shrink(),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 40),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            
            // Fixed Bottom Button
            Padding(
              padding: const EdgeInsets.fromLTRB(40, 0, 40, 40),
              child: SizedBox(
                width: double.infinity,
                height: 60,
                child: CupertinoButton(
                  padding: EdgeInsets.zero,
                  color: CupertinoColors.activeBlue,
                  borderRadius: BorderRadius.circular(20),
                  onPressed: _handleNext,
                  child: Text(
                    _currentPage == _pages.length - 1 ? 'Get Started' : 'Next',
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5,
                      color: CupertinoColors.white,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FloatingMascot extends StatefulWidget {
  final Widget child;
  const _FloatingMascot({required this.child});

  @override
  State<_FloatingMascot> createState() => _FloatingMascotState();
}

class _FloatingMascotState extends State<_FloatingMascot> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat(reverse: true);
    
    _animation = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(0, 0.05),
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOutSine,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _animation,
      child: widget.child,
    );
  }
}
