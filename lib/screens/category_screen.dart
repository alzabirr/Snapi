import 'dart:io';
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/screenshot_item.dart';
import '../services/database_service.dart';
import 'capture_details_screen.dart';

class CategoryScreen extends StatefulWidget {
  const CategoryScreen({super.key});

  @override
  State<CategoryScreen> createState() => _CategoryScreenState();
}

class _CategoryScreenState extends State<CategoryScreen> {
  Map<String, List<ScreenshotItem>> _groupedItems = {};
  List<String> _allCategories = ['General', 'Work', 'Personal', 'Social', 'School'];

  @override
  void initState() {
    super.initState();
    _loadCategories();
    _loadItems();
  }

  Future<void> _loadCategories() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList('user_categories');
    if (saved != null) {
      setState(() {
        _allCategories = saved;
      });
    }
  }

  Future<void> _saveCategories() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('user_categories', _allCategories);
  }

  void _loadItems() {
    final allItems = DatabaseService.getAllItems();
    final Map<String, List<ScreenshotItem>> grouped = {};
    
    // Ensure all categories exist in the map even if empty
    for (var cat in _allCategories) {
      grouped[cat] = [];
    }

    for (var item in allItems) {
      final cat = item.category.isEmpty ? 'General' : item.category;
      if (!grouped.containsKey(cat)) {
        grouped[cat] = [];
      }
      grouped[cat]!.add(item);
    }
    
    setState(() {
      _groupedItems = grouped;
    });
  }

  void _addNewFolder() {
    final TextEditingController controller = TextEditingController();
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('New Folder'),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: CupertinoTextField(
            controller: controller,
            placeholder: 'Folder Name',
            autofocus: true,
          ),
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(context),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () {
              if (controller.text.isNotEmpty) {
                setState(() {
                  _allCategories.add(controller.text);
                  _groupedItems[controller.text] = [];
                });
                _saveCategories();
                Navigator.pop(context);
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;
    final folderColors = [
      const Color(0xFF8E8FFA), // Purple
      const Color(0xFFFFCC70), // Yellow
      const Color(0xFFC683D7), // Pink
      const Color(0xFF7BD3EA), // Blue
      const Color(0xFFA1EEBD), // Green
    ];

    return CupertinoPageScaffold(
      backgroundColor: CupertinoTheme.of(context).scaffoldBackgroundColor,
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          CupertinoSliverNavigationBar(
            largeTitle: Text(
              'My Folders',
              style: TextStyle(
                color: CupertinoColors.label.resolveFrom(context),
                letterSpacing: -1.2,
                fontWeight: FontWeight.w800,
              ),
            ),
            backgroundColor: CupertinoTheme.of(context).barBackgroundColor.withOpacity(0.8),
            border: null,
          ),
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 16,
                crossAxisSpacing: 12,
                childAspectRatio: 0.75,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final category = _allCategories[index];
                  final items = _groupedItems[category] ?? [];
                  final color = folderColors[index % folderColors.length];
                  return _FolderCard(
                    category: category,
                    items: items,
                    isDark: isDark,
                    color: color,
                  );
                },
                childCount: _allCategories.length,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FolderCard extends StatelessWidget {
  final String category;
  final List<ScreenshotItem> items;
  final bool isDark;
  final Color color;

  const _FolderCard({
    required this.category,
    required this.items,
    required this.isDark,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        CupertinoPageRoute(
          builder: (context) => CategoryDetailScreen(
            category: category,
            items: items,
          ),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Colorful Folder Icon (Matching Image Style)
          Stack(
            alignment: Alignment.center,
            children: [
              Icon(
                CupertinoIcons.folder_fill,
                size: 70,
                color: color.withOpacity(isDark ? 0.8 : 0.9),
              ),
              // Optional: Sub-icon or glow
              Positioned(
                bottom: 18,
                child: Container(
                  width: 20,
                  height: 3,
                  decoration: BoxDecoration(
                    color: CupertinoColors.white.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            category,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '${items.length} items',
            style: TextStyle(
              fontSize: 11,
              color: CupertinoColors.systemGrey.resolveFrom(context),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class CategoryDetailScreen extends StatelessWidget {
  final String category;
  final List<ScreenshotItem> items;

  const CategoryDetailScreen({super.key, required this.category, required this.items});

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoTheme.of(context).scaffoldBackgroundColor,
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          CupertinoSliverNavigationBar(
            largeTitle: Text(category),
            backgroundColor: CupertinoTheme.of(context).barBackgroundColor.withOpacity(0.8),
            border: null,
          ),
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 0.75,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final item = items[index];
                  return GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      CupertinoPageRoute(
                        builder: (context) => CaptureDetailsScreen(item: item),
                      ),
                    ),
                    child: Hero(
                      tag: 'category_item_${item.id}',
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: CupertinoColors.label.resolveFrom(context).withOpacity(0.1),
                          ),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Image.file(
                          File(item.path),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  );
                },
                childCount: items.length,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
