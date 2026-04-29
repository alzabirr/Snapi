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
                             item.category.toLowerCase().contains(query);
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
                placeholder: 'Search notes, categories...',
              ),
            ),
            Expanded(
              child: _filteredItems.isEmpty
                  ? const Center(child: Text('No matching captures found.'))
                  : ListView.builder(
                      itemCount: _filteredItems.length,
                      itemBuilder: (context, index) {
                        final item = _filteredItems[index];
                        return CupertinoListTile(
                          leadingSize: 60,
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(
                              File(item.path),
                              fit: BoxFit.cover,
                              width: 60,
                              height: 60,
                            ),
                          ),
                          title: Text(item.note.isNotEmpty ? item.note : 'Untitled Note'),
                          subtitle: Text('${item.category} • ${item.createdAt.day}/${item.createdAt.month}'),
                          trailing: item.isFavorite 
                              ? const Icon(CupertinoIcons.heart_fill, color: CupertinoColors.systemRed, size: 20)
                              : null,
                          onTap: () async {
                            await Navigator.push(
                              context,
                              CupertinoPageRoute(
                                builder: (context) => CaptureDetailsScreen(item: item),
                              ),
                            );
                            _loadItems();
                          },
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
