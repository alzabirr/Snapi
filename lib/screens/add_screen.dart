import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:photo_manager/photo_manager.dart';
import '../models/screenshot_item.dart';
import '../services/database_service.dart';
import '../widgets/screenshot_popup.dart';

class AddScreen extends StatefulWidget {
  const AddScreen({super.key});

  @override
  State<AddScreen> createState() => _AddScreenState();
}

class _AddScreenState extends State<AddScreen> with SingleTickerProviderStateMixin {
  Map<String, List<AssetEntity>> _groupedAssets = {};
  List<String> _headers = [];
  List<AssetPathEntity> _albums = [];
  AssetPathEntity? _selectedAlbum;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAlbums();
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
    if (date.year == now.year) return '${_getMonthName(date.month)} ${date.day}';
    return '${date.day} ${_getMonthName(date.month)} ${date.year}';
  }

  Future<void> _loadAlbums() async {
    final PermissionState ps = await PhotoManager.requestPermissionExtend();
    if (!ps.isAuth && ps != PermissionState.limited) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    final List<AssetPathEntity> paths = await PhotoManager.getAssetPathList(
      type: RequestType.image,
      filterOption: FilterOptionGroup(
        orders: [
          const OrderOption(type: OrderOptionType.createDate, asc: false),
        ],
      ),
    );
    
    if (paths.isNotEmpty) {
      setState(() {
        _albums = paths;
        _selectedAlbum = paths[0];
      });
      await _loadAssetsForAlbum(paths[0]);
    } else {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadAssetsForAlbum(AssetPathEntity album) async {
    setState(() => _isLoading = true);
    final List<AssetEntity> entities = await album.getAssetListRange(start: 0, end: 300);
    
    final Map<String, List<AssetEntity>> grouped = {};
    for (var asset in entities) {
      final header = _getDateHeader(asset.createDateTime);
      if (!grouped.containsKey(header)) {
        grouped[header] = [];
      }
      grouped[header]!.add(asset);
    }

    if (mounted) {
      setState(() {
        _groupedAssets = grouped;
        _headers = grouped.keys.toList();
        _isLoading = false;
        _selectedAlbum = album;
      });
    }
  }

  void _showAlbumPicker() {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => _AlbumPicker(
        albums: _albums,
        onSelected: (album) {
          Navigator.pop(context);
          _loadAssetsForAlbum(album);
        },
      ),
    );
  }

  void _showNotePopup(AssetEntity asset) {
    final existingItems = DatabaseService.getAllItems();
    final alreadyExists = existingItems.any((item) => item.id == asset.id);
    if (alreadyExists) {
      showCupertinoDialog(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: const Text('Already Added'),
          content: const Text('This capture is already in your list.'),
          actions: [
            CupertinoDialogAction(
              child: const Text('OK'),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      );
      return;
    }

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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? const Color(0xFF000000) : const Color(0xFFF9F9FB);
    
    return CupertinoPageScaffold(
      backgroundColor: backgroundColor,
      child: Stack(
        children: [
          // Background Glows for Premium Look
          // Background Glows removed for pure dark feel as requested

          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              CupertinoSliverNavigationBar(
                largeTitle: GestureDetector(
                  onTap: _showAlbumPicker,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _selectedAlbum?.name ?? 'Library',
                        style: TextStyle(
                          color: isDark ? CupertinoColors.white : CupertinoColors.black,
                          letterSpacing: -1.2,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: isDark ? CupertinoColors.systemGrey.withOpacity(0.1) : CupertinoColors.activeBlue.withOpacity(0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(CupertinoIcons.chevron_down, size: 12, color: isDark ? CupertinoColors.systemGrey : CupertinoColors.activeBlue),
                      ),
                    ],
                  ),
                ),
                backgroundColor: backgroundColor.withOpacity(0.7),
                border: null,
              ),
              
              if (_isLoading)
                const SliverFillRemaining(
                  child: Center(child: CupertinoActivityIndicator(radius: 15)),
                )
              else if (_headers.isEmpty)
                SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(CupertinoIcons.photo_on_rectangle, size: 80, color: CupertinoColors.systemGrey.withOpacity(0.3)),
                        const SizedBox(height: 20),
                        Text(
                          'No memories found',
                          style: TextStyle(
                            color: CupertinoColors.secondaryLabel.resolveFrom(context),
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                ..._headers.expand((header) {
                  final assets = _groupedAssets[header]!;
                  return [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(22, 36, 22, 18),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              header,
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                                color: isDark ? CupertinoColors.white : CupertinoColors.black,
                                letterSpacing: -1.0,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              '${assets.length} items',
                              style: TextStyle(
                                fontSize: 13,
                                color: CupertinoColors.systemGrey.resolveFrom(context).withOpacity(0.6),
                                fontWeight: FontWeight.w600,
                                height: 2.0,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(bottom: 8.0),
                                child: Container(
                                  height: 0.5,
                                  color: CupertinoColors.separator.resolveFrom(context).withOpacity(0.3),
                                ),
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
                          crossAxisCount: 3,
                          mainAxisSpacing: 16,
                          crossAxisSpacing: 16,
                          childAspectRatio: 0.78,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final asset = assets[index];
                            return _AnimatedGridItem(
                              index: index,
                              child: GestureDetector(
                                onTap: () => _showNotePopup(asset),
                                child: Hero(
                                  tag: 'asset_${asset.id}',
                                  child: Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(20),
                                      boxShadow: isDark ? [] : [
                                        BoxShadow(
                                          color: CupertinoColors.black.withOpacity(0.08),
                                          blurRadius: 15,
                                          offset: const Offset(0, 6),
                                        ),
                                      ],
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(20),
                                      child: Stack(
                                        fit: StackFit.expand,
                                        children: [
                                          _AssetThumbnail(asset: asset),
                                          // Enhanced Gradient Overlay
                                          Positioned.fill(
                                            child: Container(
                                              decoration: BoxDecoration(
                                                gradient: LinearGradient(
                                                  begin: Alignment.topCenter,
                                                  end: Alignment.bottomCenter,
                                                  stops: const [0.5, 1.0],
                                                  colors: [
                                                    CupertinoColors.black.withOpacity(0.0),
                                                    CupertinoColors.black.withOpacity(0.35),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                          // Quick Selection Shine Effect (Inner Border)
                                          Positioned.fill(
                                            child: Container(
                                              decoration: BoxDecoration(
                                                borderRadius: BorderRadius.circular(20),
                                                border: Border.all(
                                                  color: CupertinoColors.white.withOpacity(0.08),
                                                  width: 1.0,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                          childCount: assets.length,
                        ),
                      ),
                    ),
                  ];
                }),
              const SliverToBoxAdapter(child: SizedBox(height: 160)),
            ],
          ),
        ],
      ),
    );
  }
}

class _AnimatedGridItem extends StatefulWidget {
  final Widget child;
  final int index;
  const _AnimatedGridItem({required this.child, required this.index});

  @override
  State<_AnimatedGridItem> createState() => _AnimatedGridItemState();
}

class _AnimatedGridItemState extends State<_AnimatedGridItem> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    
    _scaleAnimation = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );
    
    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.0, 0.6, curve: Curves.easeOut)),
    );

    Future.delayed(Duration(milliseconds: widget.index % 9 * 50), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacityAnimation,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: widget.child,
      ),
    );
  }
}

class _AssetThumbnail extends StatelessWidget {
  final AssetEntity asset;

  const _AssetThumbnail({required this.asset});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List?>(
      future: asset.thumbnailData,
      builder: (context, snapshot) {
        final data = snapshot.data;
        if (data == null) {
          return Container(
            color: CupertinoTheme.of(context).brightness == Brightness.dark 
                ? const Color(0xFF151515) 
                : CupertinoColors.systemGrey6,
          );
        }
        return Image.memory(
          data, 
          fit: BoxFit.cover,
          gaplessPlayback: true,
        );
      },
    );
  }
}

class _AlbumPicker extends StatelessWidget {
  final List<AssetPathEntity> albums;
  final Function(AssetPathEntity) onSelected;

  const _AlbumPicker({required this.albums, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;
    
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: BoxDecoration(
          color: (isDark ? const Color(0xFF121212) : CupertinoColors.white).withOpacity(0.85),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(36)),
          border: Border.all(
            color: CupertinoColors.white.withOpacity(0.05),
            width: 0.5,
          ),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: CupertinoColors.systemGrey.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 28),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Your Library',
                    style: TextStyle(
                      fontSize: 28, 
                      fontWeight: FontWeight.w900, 
                      letterSpacing: -1.5,
                    ),
                  ),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isDark ? CupertinoColors.systemGrey.withOpacity(0.1) : CupertinoColors.activeBlue.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(CupertinoIcons.xmark, size: 18, color: isDark ? CupertinoColors.systemGrey : CupertinoColors.activeBlue),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                itemCount: albums.length,
                itemBuilder: (context, index) {
                  final album = albums[index];
                  return _AnimatedAlbumTile(
                    index: index,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: isDark ? CupertinoColors.white.withOpacity(0.04) : CupertinoColors.black.withOpacity(0.02),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: CupertinoColors.label.resolveFrom(context).withOpacity(0.03),
                          width: 0.5,
                        ),
                      ),
                      child: CupertinoButton(
                        padding: const EdgeInsets.all(14),
                        onPressed: () => onSelected(album),
                        child: Row(
                          children: [
                            // Album Thumbnail with Shadow
                            Container(
                              width: 75,
                              height: 75,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(18),
                                boxShadow: [
                                  BoxShadow(
                                    color: CupertinoColors.black.withOpacity(0.15),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: FutureBuilder<List<AssetEntity>>(
                                future: album.getAssetListRange(start: 0, end: 1),
                                builder: (context, snapshot) {
                                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                                    return Container(
                                      color: CupertinoColors.systemGrey6,
                                      child: const Icon(CupertinoIcons.photo, color: CupertinoColors.systemGrey, size: 30),
                                    );
                                  }
                                  return _AssetThumbnail(asset: snapshot.data![0]);
                                },
                              ),
                            ),
                            const SizedBox(width: 22),
                            // Album Info
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    album.name,
                                    style: TextStyle(
                                      fontSize: 19, 
                                      fontWeight: FontWeight.w800,
                                      color: isDark ? CupertinoColors.white : CupertinoColors.black,
                                      letterSpacing: -0.6,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  FutureBuilder<int>(
                                    future: album.assetCountAsync,
                                    builder: (context, snapshot) {
                                      return Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: isDark ? CupertinoColors.systemGrey.withOpacity(0.15) : CupertinoColors.activeBlue.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          '${snapshot.data ?? '0'}',
                                          style: TextStyle(
                                            color: isDark ? CupertinoColors.systemGrey : CupertinoColors.activeBlue,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              CupertinoIcons.chevron_right, 
                              size: 16, 
                              color: CupertinoColors.systemGrey3.resolveFrom(context),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnimatedAlbumTile extends StatefulWidget {
  final Widget child;
  final int index;
  const _AnimatedAlbumTile({required this.child, required this.index});

  @override
  State<_AnimatedAlbumTile> createState() => _AnimatedAlbumTileState();
}

class _AnimatedAlbumTileState extends State<_AnimatedAlbumTile> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _offsetAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    
    _offsetAnimation = Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );

    Future.delayed(Duration(milliseconds: widget.index * 40), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _offsetAnimation,
      child: widget.child,
    );
  }
}
