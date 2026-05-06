import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import '../models/screenshot_item.dart';
import '../services/database_service.dart';
import '../services/notification_service.dart';
import '../widgets/screenshot_popup.dart';
import 'capture_details_screen.dart';
import 'package:photo_manager/photo_manager.dart';
import 'dart:typed_data';
import 'search_screen.dart';
import 'package:hive_flutter/hive_flutter.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _instructionIndex = 0;
  late final Timer _instructionTimer;
  final List<String> _instructions = [
    "Hi! I am Snapi",
    "Take any screenshot!",
    "I'll detect it!",
    "Adding Voice Notes",
    "Smart Organizing",
    "Mind Map View",
    "Try it now!",
  ];

  @override
  void initState() {
    super.initState();
    _instructionTimer = Timer.periodic(const Duration(milliseconds: 2500), (timer) {
      if (mounted) {
        setState(() {
          _instructionIndex = (_instructionIndex + 1) % _instructions.length;
        });
      }
    });
  }

  @override
  void dispose() {
    _instructionTimer.cancel();
    super.dispose();
  }

  Future<void> _pickFromGallery() async {
    final PermissionState ps = await PhotoManager.requestPermissionExtend();
    if (!ps.isAuth && ps != PermissionState.limited) return;

    if (!mounted) return;

    // Show a simple gallery picker as a modal
    showCupertinoModalPopup(
      context: context,
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

    showCupertinoModalPopup(
      context: context,
      barrierDismissible: false,
      builder: (context) => ScreenshotPopup(
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
        onDelete: () {
          // User discarded the manual gallery pick
        },
      ),
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
    return CupertinoPageScaffold(
      backgroundColor: CupertinoTheme.of(context).scaffoldBackgroundColor,
      child: ValueListenableBuilder<Box<ScreenshotItem>>(
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
            physics: const BouncingScrollPhysics(),
            slivers: [
              CupertinoSliverNavigationBar(
                largeTitle: Text(
                  'My Captures',
                  style: TextStyle(
                    color: CupertinoColors.label.resolveFrom(context),
                    letterSpacing: -1.2,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                backgroundColor: CupertinoTheme.of(context).barBackgroundColor.withOpacity(0.8),
                border: null,
                trailing: CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: () {
                    Navigator.push(
                      context,
                      CupertinoPageRoute(builder: (context) => const SearchScreen()),
                    );
                  },
                  child: const Icon(CupertinoIcons.search, size: 28, color: CupertinoColors.activeBlue),
                ),
              ),
              
              if (items.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 40.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Mascot with Speech Bubble
                          Stack(
                            clipBehavior: Clip.none,
                            alignment: Alignment.center,
                            children: [
                              // Speech Bubble with Cycling Text
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
                                      color: CupertinoColors.activeBlue,
                                      borderRadius: BorderRadius.circular(18),
                                      boxShadow: [
                                        BoxShadow(
                                          color: CupertinoColors.activeBlue.withOpacity(0.3),
                                          blurRadius: 15,
                                          offset: const Offset(0, 5),
                                        ),
                                      ],
                                    ),
                                    child: Text(
                                      _instructions[_instructionIndex],
                                      style: const TextStyle(
                                        color: CupertinoColors.white,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              _FloatingMascot(
                                child: Image.asset(
                                  'assets/snapi.png',
                                  width: 150,
                                  height: 150,
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
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
                                color: CupertinoColors.systemGrey.resolveFrom(context).withOpacity(0.8),
                                letterSpacing: 1.5,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Container(
                                height: 1,
                                color: CupertinoColors.systemGrey.resolveFrom(context).withOpacity(0.1),
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
                                // Prevent double-push Hero crash
                                if (!mounted) return;
                                
                                await Navigator.push(
                                  context,
                                  CupertinoPageRoute(
                                    builder: (context) => CaptureDetailsScreen(item: item),
                                  ),
                                );
                              },
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(24),
                                  border: Border.all(
                                    color: CupertinoColors.systemGrey.resolveFrom(context).withOpacity(0.15),
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
                                          color: CupertinoColors.systemGrey6,
                                          child: const Icon(CupertinoIcons.photo, color: CupertinoColors.systemGrey),
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
                                              CupertinoColors.transparent,
                                              CupertinoColors.black.withOpacity(0.4),
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
                                              color: CupertinoTheme.of(context).brightness == Brightness.dark 
                                                  ? const Color(0xFF1A1A1A).withOpacity(0.75)
                                                  : CupertinoColors.white.withOpacity(0.88),
                                              border: Border(
                                                top: BorderSide(
                                                  color: CupertinoColors.label.resolveFrom(context).withOpacity(0.08),
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
                                                    color: CupertinoColors.label.resolveFrom(context),
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
                                                            color: CupertinoColors.systemGrey.withOpacity(0.9),
                                                            fontWeight: FontWeight.w600,
                                                            letterSpacing: -0.1,
                                                          ),
                                                        ),
                                                        const SizedBox(width: 8),
                                                        Container(
                                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                          decoration: BoxDecoration(
                                                            color: CupertinoColors.activeBlue.withOpacity(0.1),
                                                            borderRadius: BorderRadius.circular(5),
                                                          ),
                                                          child: Text(
                                                            item.category.toUpperCase(),
                                                            style: const TextStyle(
                                                              fontSize: 8,
                                                              fontWeight: FontWeight.w800,
                                                              color: CupertinoColors.activeBlue,
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
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: const Color(0xFF151515),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(
          color: CupertinoColors.white.withOpacity(0.1),
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
              color: CupertinoColors.systemGrey.withOpacity(0.4),
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
                  style: CupertinoTheme.of(context).textTheme.navTitleTextStyle.copyWith(
                    color: CupertinoColors.label.resolveFrom(context),
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  child: const Text('Close', style: TextStyle(color: CupertinoColors.activeBlue)),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading 
              ? const Center(child: CupertinoActivityIndicator(radius: 15))
              : _assets.isEmpty
                ? const Center(child: Text('No images found', style: TextStyle(color: CupertinoColors.systemGrey)))
                : GridView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                      mainAxisSpacing: 2,
                      crossAxisSpacing: 2,
                    ),
                    itemCount: _assets.length,
                    itemBuilder: (context, index) {
                      return GestureDetector(
                        onTap: () => widget.onSelected(_assets[index]),
                        child: AssetThumbnail(asset: _assets[index]),
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

  const AssetThumbnail({super.key, required this.asset});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List?>(
      future: asset.thumbnailData,
      builder: (context, snapshot) {
        final data = snapshot.data;
        if (data == null) return Container(color: CupertinoColors.systemGrey6);
        return Image.memory(data, fit: BoxFit.cover);
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
