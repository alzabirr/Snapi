import 'dart:typed_data';
import 'package:flutter/cupertino.dart';
import 'package:photo_manager/photo_manager.dart';
import '../models/screenshot_item.dart';
import '../services/database_service.dart';
import '../services/notification_service.dart';
import '../widgets/screenshot_popup.dart';

class AddScreen extends StatefulWidget {
  const AddScreen({super.key});

  @override
  State<AddScreen> createState() => _AddScreenState();
}

class _AddScreenState extends State<AddScreen> {
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
        onSave: (note, category, reminder, extractedText) async {
          final file = await asset.file;
          if (file == null) return;

          final newItem = ScreenshotItem(
            id: asset.id,
            path: file.path,
            note: note,
            category: category,
            reminderTime: reminder,
            createdAt: DateTime.now(),
            extractedText: extractedText,
          );
          await DatabaseService.addItem(newItem);
          
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;
    
    return CupertinoPageScaffold(
      backgroundColor: isDark ? CupertinoColors.black : CupertinoColors.white,
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          CupertinoSliverNavigationBar(
            largeTitle: GestureDetector(
              onTap: _showAlbumPicker,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_selectedAlbum?.name ?? 'Library'),
                  const SizedBox(width: 4),
                  const Icon(CupertinoIcons.chevron_down, size: 18, color: CupertinoColors.systemGrey),
                ],
              ),
            ),
            backgroundColor: (isDark ? CupertinoColors.black : CupertinoColors.white).withOpacity(0.8),
            border: null,
          ),
          
          if (_isLoading)
            const SliverFillRemaining(
              child: Center(child: CupertinoActivityIndicator(radius: 15)),
            )
          else if (_headers.isEmpty)
            const SliverFillRemaining(
              child: Center(child: Text('No images found', style: TextStyle(color: CupertinoColors.systemGrey))),
            )
          else
            ..._headers.expand((header) {
              final assets = _groupedAssets[header]!;
              return [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
                    child: Text(
                      header,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  sliver: SliverGrid(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      mainAxisSpacing: 2,
                      crossAxisSpacing: 2,
                      childAspectRatio: 1.0,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final asset = assets[index];
                        return GestureDetector(
                          onTap: () => _showNotePopup(asset),
                          child: _AssetThumbnail(asset: asset),
                        );
                      },
                      childCount: assets.length,
                    ),
                  ),
                ),
              ];
            }),
          const SliverToBoxAdapter(child: SizedBox(height: 120)),
        ],
      ),
    );
  }
}

class _AssetThumbnail extends StatelessWidget {
  final AssetEntity asset;

  const _AssetThumbnail({required this.asset});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
      ),
      clipBehavior: Clip.antiAlias,
      child: FutureBuilder<Uint8List?>(
        future: asset.thumbnailData,
        builder: (context, snapshot) {
          final data = snapshot.data;
          if (data == null) {
            return Container(
              color: CupertinoTheme.of(context).brightness == Brightness.dark 
                  ? CupertinoColors.systemGrey6.withOpacity(0.1) 
                  : CupertinoColors.systemGrey6,
            );
          }
          return Image.memory(
            data, 
            fit: BoxFit.cover,
            gaplessPlayback: true,
          );
        },
      ),
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
    
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : CupertinoColors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 36,
            height: 5,
            decoration: BoxDecoration(
              color: CupertinoColors.systemGrey.withOpacity(0.4),
              borderRadius: BorderRadius.circular(2.5),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Albums',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.5),
                ),
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Done', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 17)),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 40),
              itemCount: albums.length,
              itemBuilder: (context, index) {
                final album = albums[index];
                return GestureDetector(
                  onTap: () => onSelected(album),
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    child: Row(
                      children: [
                        // Album Thumbnail
                        Container(
                          width: 70,
                          height: 70,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            color: CupertinoColors.systemGrey6,
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: FutureBuilder<List<AssetEntity>>(
                            future: album.getAssetListRange(start: 0, end: 1),
                            builder: (context, snapshot) {
                              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                                return const Icon(CupertinoIcons.photo, color: CupertinoColors.systemGrey, size: 30);
                              }
                              return _AssetThumbnail(asset: snapshot.data![0]);
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        // Album Info
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                album.name,
                                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 4),
                              FutureBuilder<int>(
                                future: album.assetCountAsync,
                                builder: (context, snapshot) {
                                  return Text(
                                    '${snapshot.data ?? '0'}',
                                    style: TextStyle(
                                      color: CupertinoColors.systemGrey.resolveFrom(context),
                                      fontSize: 15,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                        const Icon(CupertinoIcons.chevron_right, size: 16, color: CupertinoColors.systemGrey4),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

