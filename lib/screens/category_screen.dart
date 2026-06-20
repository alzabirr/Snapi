import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/screenshot_item.dart';
import '../services/database_service.dart';
import 'capture_details_screen.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../widgets/custom_delete_dialog.dart';
import 'main_screen.dart';

class CategoryScreen extends StatefulWidget {
  const CategoryScreen({super.key});

  @override
  State<CategoryScreen> createState() => _CategoryScreenState();
}

class _CategoryScreenState extends State<CategoryScreen> {
  Map<String, List<ScreenshotItem>> _groupedItems = {};
  List<String> _allCategories = ['Uncategorized', 'Personal'];
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(() {
      MainScreen.scrollOffsetNotifier.value = _scrollController.offset;
    });
    _loadCategories();
    _loadItems();
    DatabaseService.box.listenable().addListener(_onDatabaseChange);
    DatabaseService.categoryNotifier.addListener(_onDatabaseChange);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    DatabaseService.box.listenable().removeListener(_onDatabaseChange);
    DatabaseService.categoryNotifier.removeListener(_onDatabaseChange);
    super.dispose();
  }

  void _onDatabaseChange() {
    if (mounted) {
      _loadCategories().then((_) {
        _loadItems();
      });
    }
  }

  Future<void> _loadCategories() async {
    final prefs = await SharedPreferences.getInstance();
    List<String>? saved = prefs.getStringList('user_categories');
    
    if (mounted) {
      setState(() {
        if (saved == null || saved.isEmpty) {
          _allCategories = ['Uncategorized', 'Personal'];
        } else {
          // Always ensure Uncategorized is present
          if (!saved.contains('Uncategorized')) {
            saved.insert(0, 'Uncategorized');
          }
          _allCategories = saved;
        }
      });
      _loadItems();
    }
  }

  Future<void> _saveCategories() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('user_categories', _allCategories);
    // Notify other screens to refresh
    DatabaseService.categoryNotifier.value++;
  }

  void _loadItems() {
    if (!mounted) return;
    final allItems = DatabaseService.getAllItems();
    final Map<String, List<ScreenshotItem>> grouped = {};
    
    // Ensure all categories exist in the map even if empty
    for (var cat in _allCategories) {
      grouped[cat] = [];
    }

    bool categoriesUpdated = false;
    for (var item in allItems) {
      String cat = item.category.isEmpty ? 'Uncategorized' : item.category;
      
      // Forcefully remove 'Work' and 'Social' if they exist in DB
      if (cat == 'Work' || cat == 'Social') {
        cat = 'Uncategorized';
      }
      
      // If a restored image has a category that was deleted, bring the folder back
      if (!_allCategories.contains(cat)) {
        _allCategories.add(cat);
        categoriesUpdated = true;
      }
      
      if (!grouped.containsKey(cat)) {
        grouped[cat] = [];
      }
      grouped[cat]!.add(item);
    }
    
    if (categoriesUpdated) {
      _saveCategories();
    }
    
    setState(() {
      _groupedItems = grouped;
    });
  }

  void _addNewFolder() {
    final TextEditingController controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New Folder'),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'Folder Name',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        actions: [
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(context),
          ),
          TextButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                final folderName = controller.text.trim();
                setState(() {
                  _allCategories.add(folderName);
                  _groupedItems[folderName] = [];
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

  void _showFolderOptions(String category) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'Folder: $category',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Rename Folder'),
              onTap: () {
                Navigator.pop(context);
                _renameFolder(category);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('Delete Folder', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _confirmDeleteFolder(category);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _renameFolder(String oldName) {
    if (oldName == 'Uncategorized') {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Cannot Rename'),
          content: const Text('The Uncategorized folder is a system folder and cannot be renamed.'),
          actions: [
            TextButton(
              child: const Text('OK'),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      );
      return;
    }

    final TextEditingController controller = TextEditingController(text: oldName);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename Folder'),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'New Folder Name',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        actions: [
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(context),
          ),
          TextButton(
            onPressed: () async {
              final newName = controller.text.trim();
              if (newName.isNotEmpty && newName != oldName) {
                // 1. Check if new name already exists (Merge case)
                bool merging = _allCategories.contains(newName);
                
                // 2. Update category list in MEMORY first
                setState(() {
                  if (merging) {
                    _allCategories.remove(oldName);
                  } else {
                    final index = _allCategories.indexOf(oldName);
                    if (index != -1) {
                      _allCategories[index] = newName;
                    }
                  }
                });
                
                // 3. Save categories to PREFERENCES immediately
                await _saveCategories();
                
                // 4. Update items in DB (Atomic update)
                await DatabaseService.renameCategory(oldName, newName);
                
                if (mounted) {
                  Navigator.pop(context);
                  _loadItems(); 
                }
              } else {
                Navigator.pop(context);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteFolder(String category) {
    if (category == 'Uncategorized') return;

    showCustomDeleteDialog(
      context: context,
      title: 'Delete Folder',
      subtitle: 'All screenshots inside "$category" will be deleted.',
      deleteButtonText: 'Delete',
      onDelete: () async {
        await DatabaseService.deleteCategory(category);
        setState(() {
          _allCategories.remove(category);
          _groupedItems.remove(category);
        });
        await _saveCategories();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final folderColors = [
      const Color(0xFF8E8FFA), // Purple
      const Color(0xFFFFCC70), // Yellow
      const Color(0xFFC683D7), // Pink
      const Color(0xFF7BD3EA), // Blue
      const Color(0xFFA1EEBD), // Green
    ];

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: CustomScrollView(
        controller: _scrollController,
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar(
            pinned: true,
            title: Text(
              'My Folders',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                letterSpacing: -1.2,
                fontWeight: FontWeight.w800,
              ),
            ),
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            scrolledUnderElevation: 0,
            actions: [
              IconButton(
                onPressed: _addNewFolder,
                icon: const Icon(Icons.create_new_folder_outlined, size: 28),
              ),
              const SizedBox(width: 8),
            ],
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 16,
                crossAxisSpacing: 12,
                childAspectRatio: 0.70,
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
                    onLongPress: () => _showFolderOptions(category),
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
  final VoidCallback onLongPress;

  const _FolderCard({
    required this.category,
    required this.items,
    required this.isDark,
    required this.color,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    // Get up to 3 latest images for the stack effect
    final stackItems = items.take(3).toList();
    
    return GestureDetector(
      onLongPress: onLongPress,
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CategoryDetailScreen(
            category: category,
            items: items,
          ),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Stacked Images & Folder Icon
          SizedBox(
            width: 100,
            height: 90,
            child: Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                // Back Images (Stacked and Rotated)
                if (stackItems.length >= 3)
                  Positioned(
                    top: 5,
                    left: 20,
                    child: Transform.rotate(
                      angle: -0.15,
                      child: _buildPeekImage(stackItems[2].path),
                    ),
                  ),
                if (stackItems.length >= 2)
                  Positioned(
                    top: 2,
                    right: 20,
                    child: Transform.rotate(
                      angle: 0.1,
                      child: _buildPeekImage(stackItems[1].path),
                    ),
                  ),
                if (stackItems.isNotEmpty)
                  Positioned(
                    top: -5,
                    child: Transform.rotate(
                      angle: -0.05,
                      child: _buildPeekImage(stackItems[0].path),
                    ),
                  ),
                
                // Front Folder Icon
                Positioned(
                  bottom: 0,
                  child: SizedBox(
                    width: 76,
                    height: 64,
                    child: Stack(
                      children: [
                        // Back Flap of Folder
                        Container(
                          width: 76,
                          height: 58,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                color.withValues(alpha: 0.85),
                                color.withValues(alpha: 1.0),
                              ],
                            ),
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(8),
                              topRight: Radius.circular(15),
                              bottomLeft: Radius.circular(15),
                              bottomRight: Radius.circular(15),
                            ),
                          ),
                        ),
                        // Folder Tab
                        Positioned(
                          top: 0,
                          left: 0,
                          child: Container(
                            width: 32,
                            height: 12,
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.9),
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(8),
                                topRight: Radius.circular(8),
                              ),
                            ),
                          ),
                        ),
                        // Inner Content Shadow (Depth)
                        Positioned(
                          top: 15,
                          left: 4,
                          right: 4,
                          child: Container(
                            height: 40,
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                        // Front Flap (Solid)
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: Container(
                            height: 48,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  color,
                                  color.withValues(alpha: 0.9),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(15),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.2),
                                width: 0.5,
                              ),
                            ),
                            child: Center(
                              child: Container(
                                width: 14,
                                height: 2,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.5),
                                  borderRadius: BorderRadius.circular(1),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            category,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '${items.length} items',
            style: TextStyle(
              fontSize: 11,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPeekImage(String path) {
    return Container(
      width: 55,
      height: 55,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.file(
          File(path),
          fit: BoxFit.cover,
          cacheWidth: 150,
        ),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar.large(
            title: Text(category),
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            scrolledUnderElevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => Navigator.pop(context),
            ),
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
                      MaterialPageRoute(
                        builder: (context) => CaptureDetailsScreen(item: item),
                      ),
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: isDark 
                          ? [] 
                          : [
                              BoxShadow(
                                color: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.08),
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
                            tag: 'category_item_${item.id}',
                            child: Image.file(
                              File(item.path),
                              fit: BoxFit.cover,
                              cacheWidth: 400,
                              width: double.infinity,
                              errorBuilder: (context, error, stackTrace) => Container(
                                color: Theme.of(context).colorScheme.surfaceContainer,
                                child: const Icon(Icons.image_not_supported_outlined),
                              ),
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
                                    Colors.black.withValues(alpha: 0.2),
                                    Colors.transparent,
                                    Colors.black.withValues(alpha: 0.3),
                                    Colors.black.withValues(alpha: 0.7),
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
                                    color: isDark 
                                        ? const Color(0xFF1A1A1A).withValues(alpha: 0.7)
                                        : Colors.white.withValues(alpha: 0.85),
                                    border: Border(
                                      top: BorderSide(
                                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.12),
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
                                          color: Theme.of(context).colorScheme.onSurface,
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
                                              color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
                                              fontWeight: FontWeight.w600,
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
                childCount: items.length,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getMonthName(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[month - 1];
  }
}
