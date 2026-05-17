import 'dart:io';
import 'package:flutter/cupertino.dart';
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
    final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;
    return CupertinoPageScaffold(
      backgroundColor: isDark ? const Color(0xFF000000) : const Color(0xFFF2F2F7),
      navigationBar: CupertinoNavigationBar(
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => Navigator.pop(context),
          child: const Icon(CupertinoIcons.chevron_back, size: 28),
        ),
        backgroundColor: isDark ? const Color(0xFF000000) : const Color(0xFFF2F2F7),
        middle: const Text('Recycle Bin'),
        trailing: _deletedItems.isNotEmpty 
          ? CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: _emptyRecycleBin,
              child: const Text('Empty', style: TextStyle(color: CupertinoColors.destructiveRed)),
            )
          : null,
      ),
      child: SafeArea(
        child: _deletedItems.isEmpty
            ? const Center(
                child: Text(
                  'Recycle Bin is empty',
                  style: TextStyle(color: CupertinoColors.systemGrey),
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
                        color: CupertinoColors.systemGrey.resolveFrom(context).withOpacity(0.2),
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
                            color: CupertinoColors.black.withOpacity(0.6),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                CupertinoButton(
                                  padding: EdgeInsets.zero,
                                  minSize: 36,
                                  child: const Icon(CupertinoIcons.arrow_counterclockwise, color: CupertinoColors.white, size: 18),
                                  onPressed: () => _restoreItem(item),
                                ),
                                CupertinoButton(
                                  padding: EdgeInsets.zero,
                                  minSize: 36,
                                  child: const Icon(CupertinoIcons.trash, color: CupertinoColors.systemRed, size: 18),
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
