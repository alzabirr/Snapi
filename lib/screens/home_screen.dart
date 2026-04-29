import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import '../models/screenshot_item.dart';
import '../services/database_service.dart';
import '../services/screenshot_service.dart';
import '../services/notification_service.dart';
import '../widgets/screenshot_popup.dart';
import 'capture_details_screen.dart';
import 'package:photo_manager/photo_manager.dart';
import 'dart:typed_data';
import 'search_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<ScreenshotItem> _items = [];
  final Set<String> _pendingPopups = {};
  StreamSubscription? _screenshotSubscription;
  StreamSubscription? _notificationSubscription;

  @override
  void initState() {
    super.initState();
    _loadItems();
    _startMonitoring();
    _checkNotificationPermission();
  }

  @override
  void dispose() {
    _screenshotSubscription?.cancel();
    _notificationSubscription?.cancel();
    ScreenshotService.stopMonitoring();
    super.dispose();
  }

  Future<void> _checkNotificationPermission() async {
    await NotificationService.requestPermission();
  }

  void _loadItems() {
    setState(() {
      _items = DatabaseService.getAllItems();
    });
  }

  void _startMonitoring() {
    _screenshotSubscription = ScreenshotService.screenshotStream.listen((asset) {
      print('DEBUG: Screenshot stream received asset: ${asset.id}');
      // 1. Show notification? Only if you want it even when in app.
      // Usually, if we show the popup immediately, a notification is redundant and noisy.
      // Let's only show notification if the logic requires it (e.g. app was backgrounded).
      // Since this stream is from Foreground service, we are ALREADY in foreground.
      
      // 2. Show popup immediately
      _showNotePopup(asset);
    });

    // Listen for notification taps
    _notificationSubscription = NotificationService.notificationStream.listen((assetId) async {
      print('DEBUG: Notification tapped for assetId: $assetId');
      final asset = await AssetEntity.fromId(assetId);
      if (asset != null) {
        _showNotePopup(asset);
      }
    });

    ScreenshotService.startMonitoring();
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
          _showNotePopup(asset);
        },
      ),
    );
  }

  void _showNotePopup(AssetEntity asset, {String? initialNote, DateTime? initialReminder}) {
    if (!mounted) return;
    
    // PREVENT DUPLICATES: Check if this screenshot is already in the database
    if (initialNote == null) {
      if (_pendingPopups.contains(asset.id)) {
        print('DEBUG: Screenshot ${asset.id} already has an active popup. Skipping.');
        return;
      }

      final existingItems = DatabaseService.getAllItems();
      final alreadyExists = existingItems.any((item) => item.id == asset.id);
      if (alreadyExists) {
        print('DEBUG: Screenshot ${asset.id} already exists in database. Skipping popup.');
        return;
      }
      
      _pendingPopups.add(asset.id);
    }
    
    showCupertinoModalPopup(
      context: context,
      barrierDismissible: false,
      builder: (context) => ScreenshotPopup(
        asset: asset,
        initialNote: initialNote,
        initialReminder: initialReminder,
        onSave: (note, category, reminder) async {
          _pendingPopups.remove(asset.id);
          final newItem = ScreenshotItem(
            id: asset.id,
            path: (await asset.file)!.path,
            note: note,
            category: category,
            reminderTime: reminder,
            createdAt: DateTime.now(),
          );
          await DatabaseService.addItem(newItem);
          _loadItems();
          
          if (reminder != null) {
            NotificationService.scheduleReminder(
              id: asset.id.hashCode,
              title: 'Screenshot Reminder',
              body: note.isNotEmpty ? note : 'View your screenshot note',
              scheduledDate: reminder,
              payload: asset.id,
            );
          }
        },
        onDelete: initialNote != null ? () async {
          final items = DatabaseService.getAllItems();
          final existingItem = items.firstWhere((it) => it.id == asset.id);
          await DatabaseService.deleteItem(existingItem);
          _loadItems();
        } : () {
          _pendingPopups.remove(asset.id);
        },
      ),
    ).then((_) {
      // Ensure cleanup if popup dismissed via some other way, 
      // though barrierDismissible is false.
      _pendingPopups.remove(asset.id);
    });
  }

  String _getMonthName(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[month - 1];
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoTheme.of(context).scaffoldBackgroundColor,
      child: CustomScrollView(
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
          
          if (_items.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(40.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(30),
                        child: Container(
                          width: 100,
                          height: 100,
                          color: CupertinoColors.activeBlue.withOpacity(0.1),
                          child: const Icon(CupertinoIcons.photo, size: 50, color: CupertinoColors.activeBlue),
                        ),
                      ),
                      const SizedBox(height: 30),
                      const Text(
                        'No Captures Yet',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: CupertinoColors.label,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Start monitoring or add manually to see your screenshot notes here.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 15,
                          color: CupertinoColors.systemGrey.withOpacity(0.8),
                        ),
                      ),
                      const SizedBox(height: 30),
                      CupertinoButton.filled(
                        child: const Text('Add First Note'),
                        onPressed: _pickFromGallery,
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 20,
                  crossAxisSpacing: 16,
                  childAspectRatio: 0.72,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final item = _items[index];
                    return GestureDetector(
                      onTap: () async {
                        final result = await Navigator.push(
                          context,
                          CupertinoPageRoute(
                            builder: (context) => CaptureDetailsScreen(item: item),
                          ),
                        );
                        if (result == true) {
                          _loadItems();
                        }
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(28),
                          boxShadow: CupertinoTheme.of(context).brightness == Brightness.dark 
                            ? [] 
                            : [
                                BoxShadow(
                                  color: CupertinoColors.systemFill.resolveFrom(context),
                                  blurRadius: 20,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            // Main Image
                            Hero(
                              tag: 'capture_${item.id}',
                              child: Image.file(
                                File(item.path),
                                fit: BoxFit.cover,
                                width: double.infinity,
                              ),
                            ),
                            
                            // Sophisticated Gradient Overlay
                            Positioned.fill(
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    stops: const [0.0, 0.4, 0.7, 1.0],
                                    colors: [
                                      CupertinoColors.black.withOpacity(0.2),
                                      CupertinoColors.transparent,
                                      CupertinoColors.black.withOpacity(0.3),
                                      CupertinoColors.black.withOpacity(0.7),
                                    ],
                                  ),
                                ),
                              ),
                            ),

                            // Glassmorphic Info Plate
                            Positioned(
                              left: 0,
                              right: 0,
                              bottom: 0,
                              child: ClipRRect(
                                child: BackdropFilter(
                                  filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                                  child: Container(
                                    padding: const EdgeInsets.all(14.0),
                                    decoration: BoxDecoration(
                                      color: CupertinoTheme.of(context).brightness == Brightness.dark 
                                          ? const Color(0xFF1A1A1A).withOpacity(0.7)
                                          : CupertinoColors.white.withOpacity(0.85),
                                      border: Border(
                                        top: BorderSide(
                                          color: CupertinoColors.label.resolveFrom(context).withOpacity(0.12),
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
                                            fontSize: 15,
                                            color: CupertinoColors.label.resolveFrom(context),
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: 0.2,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              '${item.createdAt.day} ${_getMonthName(item.createdAt.month)}',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: CupertinoColors.systemGrey.withOpacity(0.8),
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            if (item.reminderTime != null)
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: CupertinoColors.activeBlue.withOpacity(0.15),
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: Row(
                                                  children: [
                                                    const Icon(CupertinoIcons.bell_fill, size: 10, color: CupertinoColors.activeBlue),
                                                    const SizedBox(width: 3),
                                                    Text(
                                                      item.reminderTime!.toString().substring(11, 16),
                                                      style: const TextStyle(
                                                        fontSize: 10,
                                                        color: CupertinoColors.activeBlue,
                                                        fontWeight: FontWeight.w800,
                                                      ),
                                                    ),
                                                  ],
                                                ),
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
                  childCount: _items.length,
                ),
              ),
            ),
        ],
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
