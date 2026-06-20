import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import '../models/screenshot_item.dart';
import '../services/database_service.dart';
import '../services/notification_service.dart';
import '../widgets/screenshot_popup.dart';
import 'capture_details_screen.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:typed_data';
import 'search_screen.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../services/screenshot_service.dart';
import '../services/device_setup_service.dart';
import 'device_setup_screen.dart';
import 'main_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  int _instructionIndex = 0;
  late final Timer _instructionTimer;
  bool _setupSkipped = false;
  bool _isBatteryOptimizationIgnored = true;
  bool _galleryPermissionLimited = false;
  bool _galleryPermissionDenied = false;
  late final ScrollController _scrollController;
  final List<String> _instructions = [
    "Hi! I am Krabby",
    "Organize screenshot photos",
    "Smart Auto-Organize",
    "Extract text instantly",
    "Add Voice notes",
    "Explore your Visual ",
    "Let's get started!",
  ];

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(() {
      MainScreen.scrollOffsetNotifier.value = _scrollController.offset;
    });
    WidgetsBinding.instance.addObserver(this);
    _instructionTimer = Timer.periodic(const Duration(milliseconds: 2500), (timer) {
      if (mounted) {
        setState(() {
          _instructionIndex = (_instructionIndex + 1) % _instructions.length;
        });
      }
    });
    _checkSetupSkipped();
    _checkPermissions();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Small delay to let OS update the permission state
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          _checkPermissions();
          _checkSetupSkipped();
        }
      });
    }
  }

  Future<void> _checkPermissions() async {
    try {
      final state = await PhotoManager.getPermissionState(requestOption: const PermissionRequestOption());
      final phPhotos = await Permission.photos.status;
      
      // Fallback: Check actual asset count
      final assetCount = await PhotoManager.getAssetCount();
      
      debugPrint('DEBUG: Home Screen - PM: $state, PH: $phPhotos, Count: $assetCount');
      
      final isBatteryIgnored = await DeviceSetupService.isBatteryOptimizationIgnored();
      
      if (mounted) {
        setState(() {
          _isBatteryOptimizationIgnored = isBatteryIgnored;
          bool isLimitedByOS = (state == PermissionState.limited) || (phPhotos == PermissionStatus.limited);
          
          bool looksLimitedByData = (state == PermissionState.authorized) && (assetCount > 0 && assetCount < 5);
          
          _galleryPermissionLimited = isLimitedByOS || looksLimitedByData;
          
          final isAuthorized = (state == PermissionState.authorized) && (phPhotos == PermissionStatus.granted) && !looksLimitedByData;
          _galleryPermissionDenied = !isAuthorized && !_galleryPermissionLimited;
          
          if (_galleryPermissionLimited) {
            debugPrint('DEBUG: Detected LIMITED access (either by OS or by low asset count)');
          }
        });
      }
    } catch (e) {
      debugPrint('DEBUG: Error checking permissions on Home: $e');
    }
  }

  Future<void> _checkSetupSkipped() async {
    final skipped = await DeviceSetupService.wasSetupSkipped();
    if (mounted) setState(() => _setupSkipped = skipped);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _instructionTimer.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _pickFromGallery() async {
    final PermissionState ps = await PhotoManager.requestPermissionExtend();
    if (!ps.isAuth && ps != PermissionState.limited) return;

    if (!mounted) return;

    // Show a simple gallery picker as a modal bottom sheet
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _GalleryPicker(
        onSelected: (asset) {
          Navigator.pop(context);
          _showNotePopupForGallery(asset);
        },
      ),
    );
  }

  void _showNotePopupForGallery(AssetEntity asset) {
    if (!mounted) return;

    // Use showGeneralDialog for custom dialog layouts
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'Screenshot Popup',
      barrierColor: Colors.black.withOpacity(0.4),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) {
        return Align(
          alignment: Alignment.bottomCenter,
          child: ScreenshotPopup(
            asset: asset,
            onSave: (note, category, extractedText) async {
              final file = await asset.file;
              if (file == null) return;

              final newItem = ScreenshotItem(
                id: asset.id,
                path: file.path,
                note: note,
                category: category,
                createdAt: DateTime.now(),
                extractedText: extractedText,
              );
              await DatabaseService.addItem(newItem);
            },
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 1),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut)),
          child: child,
        );
      },
    );
  }

  String _getMonthName(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[month - 1];
  }

  String _getDateHeader(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final itemDate = DateTime(date.year, date.month, date.day);

    if (itemDate == today) return 'Today';
    if (itemDate == yesterday) return 'Yesterday';
    return '${date.day} ${_getMonthName(date.month)} ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: ValueListenableBuilder<Box<ScreenshotItem>>(
        valueListenable: DatabaseService.box.listenable(),
        builder: (context, Box<ScreenshotItem> box, _) {
          final items = box.values.toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
          
          final Map<String, List<ScreenshotItem>> groupedItems = {};
          for (var item in items) {
            final header = _getDateHeader(item.createdAt);
            if (!groupedItems.containsKey(header)) {
              groupedItems[header] = [];
            }
            groupedItems[header]!.add(item);
          }
          final headers = groupedItems.keys.toList();

          return CustomScrollView(
            controller: _scrollController,
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverAppBar(
                pinned: true,
                title: Text(
                  'My Captures',
                  style: TextStyle(
                    color: theme.colorScheme.onBackground,
                    letterSpacing: -1.2,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                backgroundColor: theme.scaffoldBackgroundColor,
                elevation: 0,
                scrolledUnderElevation: 0,
                actions: [
                  IconButton(
                    icon: Icon(Icons.search, size: 28, color: theme.colorScheme.primary),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const SearchScreen()),
                      );
                    },
                  ),
                ],
              ),

              // PREMIUM WARNING BANNER
              if (_galleryPermissionLimited || _galleryPermissionDenied)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                    child: GestureDetector(
                      onTap: () => openAppSettings(),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.red.shade700.withOpacity(0.85),
                              Colors.red.shade800.withOpacity(0.95),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.red.withOpacity(0.2),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.15),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.photo_library,
                                color: Colors.white,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _galleryPermissionLimited ? 'Limited Gallery Access' : 'Gallery Access Denied',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                      letterSpacing: -0.2,
                                    ),
                                  ),
                                  const SizedBox(height: 1),
                                  Text(
                                    _galleryPermissionLimited 
                                      ? 'Tap "FIX NOW" and select "Allow All".'
                                      : 'Tap to grant gallery access.',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.white.withOpacity(0.85),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'FIX NOW',
                                style: TextStyle(
                                  color: Colors.red.shade800,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

              // Reminder banner for users who skipped setup
              if ((_setupSkipped || !_isBatteryOptimizationIgnored) && !_galleryPermissionDenied && !_galleryPermissionLimited)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => DeviceSetupScreen(
                              onDone: () {
                                Navigator.pop(context);
                                _checkPermissions();
                              },
                            ),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 13),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF6900).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                              color: const Color(0xFFFF6900).withOpacity(0.35)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.security_rounded,
                                color: Color(0xFFFF6900), size: 22),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Background permission needed',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFFFF6900),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Tap to complete setup for 24/7 screenshot detection.',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: const Color(0xFFFF6900)
                                          .withOpacity(0.8),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right,
                                color: Color(0xFFFF6900), size: 16),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

              if (items.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 40),
                        Stack(
                          clipBehavior: Clip.none,
                          alignment: Alignment.center,
                          children: [
                            Positioned(
                              top: -60,
                              right: -40,
                              child: TweenAnimationBuilder<double>(
                                key: ValueKey(_instructionIndex),
                                tween: Tween(begin: 0.0, end: 1.0),
                                duration: const Duration(milliseconds: 600),
                                curve: Curves.easeOutBack,
                                builder: (context, value, child) {
                                  return Transform.scale(
                                    scale: value,
                                    child: child,
                                  );
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.primary,
                                    borderRadius: BorderRadius.circular(18),
                                  ),

                                  child: Text(
                                    _instructions[_instructionIndex],
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            _FloatingMascot(
                              child: Image.asset(
                                'assets/krabby.png',
                                width: 150,
                                height: 150,
                                fit: BoxFit.contain,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 32),
                        TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0.0, end: 1.0),
                          duration: const Duration(milliseconds: 1000),
                          curve: Curves.easeOutCubic,
                          builder: (context, value, child) {
                            return Transform.translate(
                              offset: Offset(0, 20 * (1 - value)),
                              child: Opacity(
                                opacity: value,
                                child: child,
                              ),
                            );
                          },
                          child: Text(
                            "Take a screenshot anywhere on your phone. Krabby will automatically detect and organize it right here",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 15,
                              color: theme.colorScheme.onSurface.withOpacity(0.6),
                              height: 1.4,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const SizedBox(height: 80),
                      ],
                    ),
                  ),
                )
              else
                ...headers.expand((header) {
                  final groupItems = groupedItems[header]!;
                  return [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(22, 28, 22, 16),
                        child: Row(
                          children: [
                            Text(
                              header.toUpperCase(),
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                                color: theme.colorScheme.onSurface.withOpacity(0.5),
                                letterSpacing: 1.5,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Container(
                                height: 1,
                                color: theme.colorScheme.onSurface.withOpacity(0.1),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      sliver: SliverGrid(
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 20,
                          crossAxisSpacing: 16,
                          childAspectRatio: 0.72,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final item = groupItems[index];
                            return GestureDetector(
                              onTap: () async {
                                if (!mounted) return;
                                
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => CaptureDetailsScreen(item: item),
                                  ),
                                );
                              },
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(24),
                                  border: Border.all(
                                    color: theme.colorScheme.onSurface.withOpacity(0.12),
                                    width: 0.5,
                                  ),
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    Hero(
                                      tag: 'capture_${item.id}',
                                      child: Image.file(
                                        File(item.path),
                                        fit: BoxFit.cover,
                                        cacheWidth: 400,
                                        width: double.infinity,
                                        errorBuilder: (context, error, stackTrace) => Container(
                                          color: theme.colorScheme.surfaceVariant,
                                          child: Icon(Icons.photo_outlined, color: theme.colorScheme.onSurfaceVariant),
                                        ),
                                      ),
                                    ),
                                    // Gradient overlay to protect the text
                                    Positioned.fill(
                                      child: Container(
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            begin: Alignment.topCenter,
                                            end: Alignment.bottomCenter,
                                            stops: const [0.6, 1.0],
                                            colors: [
                                              Colors.transparent,
                                              Colors.black.withOpacity(0.4),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                    // Premium Glassmorphism Info Bar
                                    Positioned(
                                      left: 0,
                                      right: 0,
                                      bottom: 0,
                                      child: ClipRRect(
                                        child: BackdropFilter(
                                          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                            decoration: BoxDecoration(
                                              color: isDark 
                                                  ? const Color(0xFF1E293B).withOpacity(0.75)
                                                  : Colors.white.withOpacity(0.88),
                                              border: Border(
                                                top: BorderSide(
                                                  color: theme.colorScheme.onSurface.withOpacity(0.08),
                                                  width: 0.5,
                                                ),
                                              ),
                                            ),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  item.note.isNotEmpty ? item.note : 'Untitled Note',
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    color: theme.colorScheme.onSurface,
                                                    fontWeight: FontWeight.w700,
                                                    letterSpacing: -0.2,
                                                  ),
                                                ),
                                                const SizedBox(height: 3),
                                                Row(
                                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                  children: [
                                                    Row(
                                                      children: [
                                                        Text(
                                                          '${item.createdAt.day} ${_getMonthName(item.createdAt.month)}',
                                                          style: TextStyle(
                                                            fontSize: 11,
                                                            color: theme.colorScheme.onSurface.withOpacity(0.6),
                                                            fontWeight: FontWeight.w600,
                                                            letterSpacing: -0.1,
                                                          ),
                                                        ),
                                                        const SizedBox(width: 8),
                                                        Container(
                                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                          decoration: BoxDecoration(
                                                            color: theme.colorScheme.primary.withOpacity(0.1),
                                                            borderRadius: BorderRadius.circular(5),
                                                          ),
                                                          child: Text(
                                                            item.category.toUpperCase(),
                                                            style: TextStyle(
                                                              fontSize: 8,
                                                              fontWeight: FontWeight.w800,
                                                              color: theme.colorScheme.primary,
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    // Removed from Gallery Overlay
                                    if (!File(item.path).existsSync())
                                      Positioned.fill(
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color: Colors.black.withOpacity(0.65),
                                          ),
                                          child: Column(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              const Icon(Icons.delete_forever, color: Colors.red, size: 30),
                                              const SizedBox(height: 8),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: Colors.red.withOpacity(0.9),
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: const Text(
                                                  'REMOVED FROM GALLERY',
                                                  style: TextStyle(color: Color(0xFFFFFFFF), fontSize: 7, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                                                  textAlign: TextAlign.center,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
                          childCount: groupItems.length,
                        ),
                      ),
                    ),
                  ];
                }),
              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          );
        },
      ),
    );
  }
}

class _GalleryPicker extends StatefulWidget {
  final Function(AssetEntity) onSelected;

  const _GalleryPicker({required this.onSelected});

  @override
  State<_GalleryPicker> createState() => _GalleryPickerState();
}

class _GalleryPickerState extends State<_GalleryPicker> {
  List<AssetEntity> _assets = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAssets();
  }

  Future<void> _loadAssets() async {
    setState(() => _isLoading = true);
    final List<AssetPathEntity> paths = await PhotoManager.getAssetPathList(
      type: RequestType.image,
      filterOption: FilterOptionGroup(
        orders: [
          const OrderOption(type: OrderOptionType.createDate, asc: false),
        ],
      ),
    );
    if (paths.isNotEmpty) {
      final List<AssetEntity> entities = await paths[0].getAssetListRange(start: 0, end: 500);
      if (mounted) {
        setState(() {
          _assets = entities;
          _isLoading = false;
        });
      }
    } else {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(
          color: theme.colorScheme.onSurface.withOpacity(0.1),
        ),
      ),
      child: Column(
        children: [
          // Drag handle
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurface.withOpacity(0.2),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Select from Gallery',
                  style: TextStyle(
                    color: theme.colorScheme.onSurface,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                TextButton(
                  child: Text('Close', style: TextStyle(color: theme.colorScheme.primary)),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading 
              ? Center(child: CircularProgressIndicator(color: theme.colorScheme.primary))
              : _assets.isEmpty
                ? Center(child: Text('No images found', style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.5))))
                : GridView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                      mainAxisSpacing: 2,
                      crossAxisSpacing: 2,
                    ),
                    itemCount: _assets.length,
                    itemBuilder: (context, index) {
                      final asset = _assets[index];
                      final isScreenshot = ScreenshotService.isScreenshot(asset);
                      
                      return GestureDetector(
                        onTap: () => widget.onSelected(asset),
                        child: AssetThumbnail(
                          asset: asset, 
                          isScreenshot: isScreenshot
                        ),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

class AssetThumbnail extends StatelessWidget {
  final AssetEntity asset;
  final bool isScreenshot;

  const AssetThumbnail({super.key, required this.asset, this.isScreenshot = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FutureBuilder<Uint8List?>(
      future: asset.thumbnailData,
      builder: (context, snapshot) {
        final data = snapshot.data;
        if (data == null) return Container(color: theme.colorScheme.surfaceVariant);
        
        return Stack(
          fit: StackFit.expand,
          children: [
            Image.memory(data, fit: BoxFit.cover),
            if (isScreenshot)
              Positioned(
                top: 4,
                right: 4,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Icon(
                    Icons.document_scanner_outlined,
                    color: Colors.white,
                    size: 12,
                  ),
                ),
              ),
          ],
        );
      },
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
  late final AnimationController _controller;
  late final Animation<Offset> _animation;

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
      curve: Curves.easeInOut,
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
