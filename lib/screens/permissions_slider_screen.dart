import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/speech_service.dart';
import 'device_setup_screen.dart';
import '../services/device_setup_service.dart';
import '../main.dart';

class PermissionsSliderScreen extends StatefulWidget {
  const PermissionsSliderScreen({super.key});

  @override
  State<PermissionsSliderScreen> createState() => _PermissionsSliderScreenState();
}

class _PermissionsSliderScreenState extends State<PermissionsSliderScreen> with WidgetsBindingObserver {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  late final List<Map<String, dynamic>> _pages;
  bool _isGalleryLimited = false;
  bool _isGalleryDenied = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initPages();
    _checkCurrentPagePermissionOnResume();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pageController.dispose();
    super.dispose();
  }

  bool _isCheckingPermission = false;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      Future.delayed(const Duration(milliseconds: 500), () {
        _checkCurrentPagePermissionOnResume();
      });
    }
  }

  Future<void> _checkCurrentPagePermissionOnResume() async {
    if (!mounted || _isCheckingPermission) return;
    
    if (_currentPage == 1) {
      _isCheckingPermission = true;
      try {
        await Future.delayed(const Duration(seconds: 1));
        
        final state = await PhotoManager.getPermissionState(requestOption: const PermissionRequestOption());
        final phStatus = await Permission.photos.status;
        
        debugPrint('DEBUG: Resume Check - PM State: $state, PH Status: $phStatus');

        final isActuallyFull = (state == PermissionState.authorized) && 
                               (phStatus == PermissionStatus.granted);
        
        if (isActuallyFull) {
          if (mounted) {
            setState(() {
              _isGalleryLimited = false;
              _isGalleryDenied = false;
            });
            debugPrint('DEBUG: SUCCESS - Full Access Detected!');
            _pageController.nextPage(
              duration: const Duration(milliseconds: 600), 
              curve: Curves.easeInOutQuart
            );
          }
        } else {
          debugPrint('DEBUG: BLOCKED - Access is Limited or Denied');
          if (mounted) {
            setState(() {
              _isGalleryLimited = (state == PermissionState.limited) || (phStatus == PermissionStatus.limited);
              _isGalleryDenied = !isActuallyFull && !_isGalleryLimited;
            });
          }
        }
      } finally {
        _isCheckingPermission = false;
      }
    }
  }

  void _initPages() {
    _pages = [
      {
        'title': 'Krabby',
        'subtitle': 'Your personal space for screenshots.\nOrganize with voice, find with ease.',
        'isWelcome': true,
        'features': [
          {'icon': Icons.grid_view, 'text': 'Smart Catalog'},
          {'icon': Icons.mic, 'text': 'Voice Memos'},
          {'icon': Icons.analytics, 'text': 'Visual'},
          {'icon': Icons.auto_awesome, 'text': 'AI Organization'},
        ],
        'action': (BuildContext context) async => true,
      },
      {
        'title': 'Gallery Access',
        'subtitle': "Select 'Allow All' to find screenshots automatically. Your photos are private and stay safe on your device.",
        'icon': Icons.photo_library,
        'color': const Color(0xFF76608A),
        'action': (BuildContext context) async {
          if (_isCheckingPermission) return false;
          _isCheckingPermission = true;
          
          try {
            if (_isGalleryDenied || _isGalleryLimited) {
              await Future.delayed(const Duration(seconds: 1));
            }
            
            final state = await PhotoManager.requestPermissionExtend();
            final phStatus = await Permission.photos.status;
            
            debugPrint('DEBUG: Manual Request - PM State: $state, PH Status: $phStatus');

            final isFullAccess = (state == PermissionState.authorized) && 
                                 (phStatus == PermissionStatus.granted);
            
            if (mounted) {
              setState(() {
                _isGalleryLimited = (state == PermissionState.limited) || (phStatus == PermissionStatus.limited);
                _isGalleryDenied = !isFullAccess && !_isGalleryLimited;
              });
            }
            
            debugPrint('DEBUG: Result - Full Access: $isFullAccess');
            return isFullAccess;
          } finally {
            _isCheckingPermission = false;
          }
        },
      },
      {
        'title': 'Audio Recording',
        'subtitle': 'Allow Krabby to record audio so you can add voice memos and notes to your screenshots.',
        'icon': Icons.mic,
        'color': Colors.pink,
        'action': (BuildContext context) async {
          final status = await Permission.microphone.request();
          if (status.isGranted) {
            try {
              await SpeechService.init();
            } catch (e) {
              debugPrint('SpeechService init failed: $e');
            }
            return true;
          } else if (status.isPermanentlyDenied) {
            if (mounted) {
              await _showPermissionError(
                context,
                'Microphone Access',
                'Microphone access is permanently denied. Please enable it in Settings to use voice memos.',
              );
            }
            return false;
          }
          return false;
        },
      },
      {
        'title': 'Notifications',
        'subtitle': 'Stay updated! Krabby will alert you when new screenshots are detected.',
        'icon': Icons.notifications_active,
        'color': Colors.amber,
        'action': (BuildContext context) async {
          final status = await Permission.notification.request();
          return status.isGranted;
        },
      },
    ];
  }

  Future<bool?> _showPermissionError(
    BuildContext context,
    String title,
    String message, {
    bool isLimited = false,
  }) async {
    final theme = Theme.of(context);
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Text(message),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceVariant,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text('Required Steps:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  SizedBox(height: 4),
                  Text('1. Tap "Open Settings"', style: TextStyle(fontSize: 12)),
                  Text('2. Go to Permissions', style: TextStyle(fontSize: 12)),
                  Text('3. Select Photos/Videos', style: TextStyle(fontSize: 12)),
                  Text('4. Choose "Allow All"', style: TextStyle(fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(context, false),
          ),
          TextButton(
            onPressed: () async {
              await openAppSettings();
              if (context.mounted) {
                Navigator.pop(context, true);
              }
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  void _handleNext() async {
    if (_currentPage == 1) {
      final state = await PhotoManager.requestPermissionExtend();
      debugPrint('DEBUG: Manual Request State: $state');
      
      setState(() {
        _isGalleryLimited = (state == PermissionState.limited);
        _isGalleryDenied = (state != PermissionState.authorized && state != PermissionState.limited);
      });

      if (state != PermissionState.authorized) {
        return;
      }
    } else {
      final bool canProceed = await _pages[_currentPage]['action'](context);
      if (!canProceed && _currentPage != 0) {
        return;
      }
    }

    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    } else {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('seenOnboarding', true);
      
      if (mounted) {
        try {
          KrabbyApp.of(context).startMonitoring();
        } catch (e) {
          debugPrint('Error starting monitoring from onboarding: $e');
        }

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => DeviceSetupScreen(
              onDone: () {
                Navigator.pushReplacementNamed(context, '/home');
              },
            ),
          ),
        );
      }
    }
  }

  Widget _buildStep(int number, String text) {
    return Row(
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: const BoxDecoration(
            color: Colors.red,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              number.toString(),
              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
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
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          onPressed: () {
                            _pageController.previousPage(
                              duration: const Duration(milliseconds: 500),
                              curve: Curves.easeInOut,
                            );
                          },
                          icon: const Icon(
                            Icons.arrow_back,
                            color: Color(0xFF76608A),
                          ),
                        ),
                      ),
                    Align(
                      alignment: Alignment.center,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(_pages.length, (index) {
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            width: _currentPage == index ? 24 : 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: _currentPage == index 
                                  ? const Color(0xFF76608A) 
                                  : Colors.grey.shade300,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          );
                        }),
                      ),
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
                                  if (!(index == 1 && (_isGalleryLimited || _isGalleryDenied))) ...[
                                    const SizedBox(height: 20),
                                    SizedBox(
                                      height: 280,
                                      child: Center(
                                        child: _FloatingMascot(
                                          child: Stack(
                                            alignment: Alignment.bottomRight,
                                            children: [
                                              Image.asset(
                                                'assets/krabby.png',
                                                width: 240,
                                                height: 240,
                                                fit: BoxFit.contain,
                                              ),
                                              if (page['icon'] != null)
                                                TweenAnimationBuilder<double>(
                                                  tween: Tween(begin: 0.0, end: 1.0),
                                                  duration: const Duration(milliseconds: 800),
                                                  curve: Curves.easeOutBack,
                                                  builder: (context, value, child) => Transform.scale(scale: value, child: child),
                            child: Container(
                                                      padding: const EdgeInsets.all(16),
                                                      decoration: BoxDecoration(
                                                        color: Theme.of(context).scaffoldBackgroundColor.withOpacity(0.9),
                                                        shape: BoxShape.circle,
                                                        boxShadow: [
                                                          BoxShadow(color: page['color'].withOpacity(0.2), blurRadius: 20, spreadRadius: 5),
                                                        ],
                                                        border: Border.all(color: Theme.of(context).scaffoldBackgroundColor, width: 2),
                                                      ),
                                                    child: Icon(page['icon'], color: page['color'], size: 36),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 30),
                                    Text(
                                      page['title'],
                                      style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800, letterSpacing: -1.5, color: Theme.of(context).colorScheme.onSurface),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 12),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 10),
                                      child: (index == 1) 
                                        ? RichText(
                                            textAlign: TextAlign.center,
                                            text: TextSpan(
                                              style: TextStyle(fontSize: 16, color: Colors.grey.shade600, height: 1.4, fontWeight: FontWeight.w500),
                                              children: [
                                                const TextSpan(text: "Select "),
                                                WidgetSpan(
                                                  alignment: PlaceholderAlignment.middle,
                                                  child: _BlinkingText(
                                                    text: "'Allow All' ",
                                                    style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF76608A), fontSize: 17),
                                                  ),
                                                ),
                                                const TextSpan(text: "to find screenshots automatically. Your photos stay safe and private on your device."),
                                              ],
                                            ),
                                          )
                                        : Text(
                                            page['subtitle'],
                                            style: TextStyle(fontSize: 16, color: Colors.grey.shade600, height: 1.4, fontWeight: FontWeight.w500),
                                            textAlign: TextAlign.center,
                                          ),
                                    ),
                                  ],

                                  if (index == 1) ...[
                                    Padding(
                                      padding: EdgeInsets.only(top: (_isGalleryLimited || _isGalleryDenied) ? 0 : 24.0),
                                      child: Column(
                                        children: [
                                          if (!_isGalleryLimited && !_isGalleryDenied) ...[
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                              decoration: BoxDecoration(
                                                gradient: LinearGradient(
                                                  colors: [const Color(0xFF76608A).withOpacity(0.05), const Color(0xFF76608A).withOpacity(0.12)],
                                                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                                                ),
                                                borderRadius: BorderRadius.circular(16),
                                                border: Border.all(color: const Color(0xFF76608A).withOpacity(0.2), width: 1.5),
                                              ),
                                              child: Column(
                                                children: [
                                                  Text(
                                                    'I need full access to your gallery to find and organize your screenshots automatically.',
                                                    textAlign: TextAlign.center,
                                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.grey.shade600, height: 1.25),
                                                  ),
                                                  const SizedBox(height: 10),
                                                  GestureDetector(
                                                    onTap: _handleNext,
                                                    child: Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                                      width: double.infinity,
                                                      decoration: BoxDecoration(
                                                        gradient: const LinearGradient(colors: [Color(0xFF76608A), Color(0xFF5A4A6B)]),
                                                        borderRadius: BorderRadius.circular(12),
                                                        boxShadow: [BoxShadow(color: const Color(0xFF76608A).withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))],
                                                      ),
                                                      child: Row(
                                                        mainAxisAlignment: MainAxisAlignment.center,
                                                        children: const [
                                                          Icon(Icons.check_circle, color: Colors.white, size: 16),
                                                          SizedBox(width: 6),
                                                          Text('Allow All Access', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ] else ...[
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                                              width: double.infinity,
                                              decoration: BoxDecoration(
                                                gradient: LinearGradient(
                                                  colors: [Colors.red.withOpacity(0.15), Colors.red.withOpacity(0.25)],
                                                  begin: Alignment.topCenter, end: Alignment.bottomCenter,
                                                ),
                                                borderRadius: BorderRadius.circular(24),
                                                border: Border.all(color: Colors.red.withOpacity(0.4), width: 1.5),
                                              ),
                                              child: Column(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  const Icon(Icons.warning, color: Colors.red, size: 56),
                                                  const SizedBox(height: 20),
                                                  const Text(
                                                    'ACCESS RESTRICTED',
                                                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.red, letterSpacing: -0.5),
                                                  ),
                                                  const SizedBox(height: 12),
                                                  Text(
                                                    'Krabby cannot work without Full Gallery Access. Please choose "Allow All" to find your screenshots automatically.',
                                                    textAlign: TextAlign.center,
                                                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface, height: 1.3),
                                                  ),
                                                  const SizedBox(height: 24),
                                                  Container(
                                                    padding: const EdgeInsets.all(16),
                                                    decoration: BoxDecoration(
                                                      color: Theme.of(context).scaffoldBackgroundColor.withOpacity(0.9),
                                                      borderRadius: BorderRadius.circular(16),
                                                    ),
                                                    child: Column(
                                                      children: [
                                                        _buildStep(1, 'Tap "Open Settings" below'),
                                                        const SizedBox(height: 12),
                                                        _buildStep(2, 'Change to "Allow All"'),
                                                        const SizedBox(height: 12),
                                                        _buildStep(3, 'Come back to Krabby!'),
                                                      ],
                                                    ),
                                                  ),
                                                  const SizedBox(height: 28),
                                                  GestureDetector(
                                                    onTap: () => openAppSettings(),
                                                    child: Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                                      width: double.infinity,
                                                      decoration: BoxDecoration(
                                                        gradient: const LinearGradient(colors: [Colors.red, Color(0xFFC00000)]),
                                                        borderRadius: BorderRadius.circular(16),
                                                        boxShadow: [BoxShadow(color: Colors.red.withOpacity(0.35), blurRadius: 12, offset: const Offset(0, 6))],
                                                      ),
                                                      child: const Center(
                                                        child: Text('Open Settings to Fix Now', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ] else if (isWelcome && page['features'] != null) ...[
                                    const SizedBox(height: 24),
                                    (() {
                                      final list = page['features'] as List;
                                      
                                      Widget buildCard(Map<String, dynamic> f) {
                                        return Container(
                                          padding: const EdgeInsets.symmetric(vertical: 12),
                                          decoration: BoxDecoration(
                                              color: Theme.of(context).colorScheme.surfaceVariant,
                                            borderRadius: BorderRadius.circular(16),
                                          ),
                                          child: Row(
                                            children: [
                                              const SizedBox(width: 10),
                                              Icon(f['icon'] as IconData, size: 20, color: const Color(0xFF76608A)),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                  child: Text(
                                                    f['text'] as String,
                                                    style: TextStyle(
                                                      fontSize: 12.5,
                                                      fontWeight: FontWeight.bold,
                                                      color: Theme.of(context).colorScheme.onSurface,
                                                    ),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                            ],
                                          ),
                                        );
                                      }

                                      return Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(child: buildCard(list[0] as Map<String, dynamic>)),
                                              const SizedBox(width: 10),
                                              Expanded(child: buildCard(list[1] as Map<String, dynamic>)),
                                            ],
                                          ),
                                          const SizedBox(height: 10),
                                          Row(
                                            children: [
                                              Expanded(child: buildCard(list[2] as Map<String, dynamic>)),
                                              const SizedBox(width: 10),
                                              Expanded(child: buildCard(list[3] as Map<String, dynamic>)),
                                            ],
                                          ),
                                        ],
                                      );
                                    })(),
                                  ],
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
            
            Padding(
              padding: const EdgeInsets.fromLTRB(40, 0, 40, 16),
              child: SizedBox(
                width: double.infinity,
                height: 60,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF76608A),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    elevation: 0,
                  ),
                  onPressed: _handleNext,
                  child: Text(
                    _currentPage == _pages.length - 1 
                        ? 'Get Started' 
                        : (_pages[_currentPage]['title'] == 'Gallery Access' ? 'Request Access' : 'Next'),
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.5,
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

class _BlinkingText extends StatefulWidget {
  final String text;
  final TextStyle style;

  const _BlinkingText({required this.text, required this.style});

  @override
  State<_BlinkingText> createState() => _BlinkingTextState();
}

class _BlinkingTextState extends State<_BlinkingText> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 1.0, end: 0.3).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _animation,
      child: Text(widget.text, style: widget.style),
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
