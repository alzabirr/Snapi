import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/screenshot_item.dart';
import '../services/database_service.dart';
import '../widgets/custom_delete_dialog.dart';

class RecycleBinScreen extends StatefulWidget {
  const RecycleBinScreen({super.key});

  @override
  State<RecycleBinScreen> createState() => _RecycleBinScreenState();
}

class _RecycleBinScreenState extends State<RecycleBinScreen> {
  List<ScreenshotItem> _deletedItems = [];

  @override
  void initState() {
    super.initState();
    _loadItems();
    DatabaseService.deletedBox.listenable().addListener(_loadItems);
  }

  @override
  void dispose() {
    DatabaseService.deletedBox.listenable().removeListener(_loadItems);
    super.dispose();
  }

  void _loadItems() {
    setState(() {
      _deletedItems = DatabaseService.getDeletedItems();
    });
  }

  void _restoreItem(ScreenshotItem item) async {
    await DatabaseService.restoreItem(item);
    _loadItems();
  }

  void _permanentlyDeleteItem(ScreenshotItem item) {
    showCustomDeleteDialog(
      context: context,
      title: 'Delete permanently',
      subtitle: 'This capture will be deleted forever.',
      deleteButtonText: 'Delete',
      onDelete: () async {
        await DatabaseService.permanentlyDeleteItem(item);
        _loadItems();
      },
    );
  }

  void _emptyRecycleBin() {
    if (_deletedItems.isEmpty) return;
    
    showCustomDeleteDialog(
      context: context,
      title: 'Empty Recycle Bin',
      subtitle: 'All items in the recycle bin will be permanently deleted.',
      deleteButtonText: 'Empty Bin',
      onDelete: () async {
        await DatabaseService.emptyRecycleBin();
        _loadItems();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, size: 28),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Recycle Bin'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        actions: _deletedItems.isNotEmpty 
          ? [
              TextButton(
                onPressed: _emptyRecycleBin,
                child: const Text('Empty', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
              )
            ]
          : null,
      ),
      body: SafeArea(
        child: _deletedItems.isEmpty
            ? const Center(
                child: Text(
                  'Recycle Bin is empty',
                  style: TextStyle(color: Colors.grey, fontSize: 16),
                ),
              )
            : GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  childAspectRatio: 0.8,
                ),
                itemCount: _deletedItems.length,
                itemBuilder: (context, index) {
                  final item = _deletedItems[index];
                  return Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: theme.colorScheme.onSurface.withOpacity(0.12),
                        width: 0.5,
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.file(
                          File(item.path),
                          fit: BoxFit.cover,
                        ),
                        // Action Buttons Overlay
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: Container(
                            color: Colors.black.withOpacity(0.6),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                IconButton(
                                  padding: EdgeInsets.zero,
                                  icon: const Icon(Icons.restore, color: Colors.white, size: 18),
                                  onPressed: () => _restoreItem(item),
                                ),
                                IconButton(
                                  padding: EdgeInsets.zero,
                                  icon: const Icon(Icons.delete_forever, color: Colors.red, size: 18),
                                  onPressed: () => _permanentlyDeleteItem(item),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }
}
