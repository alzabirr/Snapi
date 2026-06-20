import 'dart:io';
import 'package:flutter/material.dart';
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Search'),
        actions: [
          IconButton(
            icon: Icon(
              _showFavoritesOnly ? Icons.favorite : Icons.favorite_border,
              color: _showFavoritesOnly ? Colors.red : theme.colorScheme.primary,
            ),
            onPressed: () {
              setState(() {
                _showFavoritesOnly = !_showFavoritesOnly;
                _filterItems();
              });
            },
          ),
        ],
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: SearchBar(
                controller: _searchController,
                hintText: 'Search notes, text inside images...',
                leading: const Icon(Icons.search),
                elevation: MaterialStateProperty.all(0),
                backgroundColor: MaterialStateProperty.all(
                  isDark ? const Color(0xFF1E293B) : Colors.grey.shade100,
                ),
                shape: MaterialStateProperty.all(
                  RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
            Expanded(
              child: _filteredItems.isEmpty
                  ? Center(
                      child: Text(
                        'No matching captures found.',
                        style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.6)),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _filteredItems.length,
                      itemBuilder: (context, index) {
                        final item = _filteredItems[index];
                        
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          child: InkWell(
                            onTap: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => CaptureDetailsScreen(item: item),
                                ),
                              );
                              _loadItems();
                            },
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.transparent,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Hero(
                                    tag: 'search_item_${item.id}',
                                    child: Container(
                                      width: 75,
                                      height: 75,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(16),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(0.1),
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
                                  
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          item.note.isNotEmpty ? item.note : 'Untitled Capture',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: -0.3,
                                            color: theme.colorScheme.onSurface,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        
                                        if (item.extractedText.isNotEmpty) ...[
                                          Text(
                                            item.extractedText.replaceAll('\n', ' '),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: theme.colorScheme.onSurface.withOpacity(0.6),
                                              height: 1.2,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                        ],

                                        Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: theme.colorScheme.primary.withOpacity(0.1),
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(Icons.folder, size: 10, color: theme.colorScheme.primary),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    item.category.isEmpty ? 'Uncategorized' : item.category,
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      fontWeight: FontWeight.bold,
                                                      color: theme.colorScheme.primary,
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
                                                color: theme.colorScheme.onSurface.withOpacity(0.5),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  
                                  if (item.isFavorite)
                                    const Padding(
                                      padding: EdgeInsets.only(right: 8.0),
                                      child: Icon(Icons.favorite, color: Colors.red, size: 20),
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
