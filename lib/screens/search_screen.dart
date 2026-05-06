import 'dart:io';
import 'package:flutter/cupertino.dart';
import '../models/screenshot_item.dart';
import '../services/database_service.dart';
import 'capture_details_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  List<ScreenshotItem> _allItems = [];
  List<ScreenshotItem> _filteredItems = [];
  final TextEditingController _searchController = TextEditingController();
  bool _showFavoritesOnly = false;

  @override
  void initState() {
    super.initState();
    _loadItems();
    _searchController.addListener(_filterItems);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _loadItems() {
    setState(() {
      _allItems = DatabaseService.getAllItems();
      _filterItems();
    });
  }

  void _filterItems() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredItems = _allItems.where((item) {
        final matchesQuery = item.note.toLowerCase().contains(query) || 
                             item.category.toLowerCase().contains(query) ||
                             item.extractedText.toLowerCase().contains(query);
        final matchesFavorite = !_showFavoritesOnly || item.isFavorite;
        return matchesQuery && matchesFavorite;
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Search'),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          child: Icon(
            _showFavoritesOnly ? CupertinoIcons.heart_fill : CupertinoIcons.heart,
            color: _showFavoritesOnly ? CupertinoColors.systemRed : CupertinoColors.activeBlue,
          ),
          onPressed: () {
            setState(() {
              _showFavoritesOnly = !_showFavoritesOnly;
              _filterItems();
            });
          },
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: CupertinoSearchTextField(
                controller: _searchController,
                placeholder: 'Search notes, text inside images...',
              ),
            ),
            Expanded(
              child: _filteredItems.isEmpty
                  ? const Center(child: Text('No matching captures found.'))
                  : ListView.builder(
                      itemCount: _filteredItems.length,
                      itemBuilder: (context, index) {
                        final item = _filteredItems[index];
                        final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;
                        
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                          child: GestureDetector(
                            onTap: () async {
                              await Navigator.push(
                                context,
                                CupertinoPageRoute(
                                  builder: (context) => CaptureDetailsScreen(item: item),
                                ),
                              );
                              _loadItems();
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                              decoration: BoxDecoration(
                                color: CupertinoColors.transparent,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  // Premium Image Thumbnail
                                  Hero(
                                    tag: 'search_item_${item.id}',
                                    child: Container(
                                      width: 75,
                                      height: 75,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(16),
                                        boxShadow: [
                                          BoxShadow(
                                            color: CupertinoColors.black.withOpacity(0.1),
                                            blurRadius: 5,
                                            offset: const Offset(0, 2),
                                          )
                                        ],
                                      ),
                                      clipBehavior: Clip.antiAlias,
                                      child: Image.file(
                                        File(item.path),
                                        fit: BoxFit.cover,
                                        cacheWidth: 150,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  
                                  // Content Info
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        // Note / Title
                                        Text(
                                          item.note.isNotEmpty ? item.note : 'Untitled Capture',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: -0.3,
                                            color: CupertinoColors.label.resolveFrom(context),
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        
                                        // Extracted Text Snippet (if any)
                                        if (item.extractedText.isNotEmpty) ...[
                                          Text(
                                            item.extractedText.replaceAll('\n', ' '),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: CupertinoColors.systemGrey.resolveFrom(context),
                                              height: 1.2,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                        ],

                                        // Category Pill & Date
                                        Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: CupertinoColors.activeBlue.withOpacity(0.1),
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  const Icon(CupertinoIcons.folder_fill, size: 10, color: CupertinoColors.activeBlue),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    item.category.isEmpty ? 'Uncategorized' : item.category,
                                                    style: const TextStyle(
                                                      fontSize: 10,
                                                      fontWeight: FontWeight.bold,
                                                      color: CupertinoColors.activeBlue,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              '${item.createdAt.day}/${item.createdAt.month}/${item.createdAt.year}',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: CupertinoColors.systemGrey.withOpacity(0.8),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  
                                  // Trailing Icons
                                  if (item.isFavorite)
                                    const Padding(
                                      padding: EdgeInsets.only(right: 8.0),
                                      child: Icon(CupertinoIcons.heart_fill, color: CupertinoColors.systemRed, size: 20),
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
