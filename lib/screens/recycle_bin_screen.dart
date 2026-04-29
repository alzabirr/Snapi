import 'dart:io';
import 'package:flutter/cupertino.dart';
import '../models/screenshot_item.dart';
import '../services/database_service.dart';

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
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Delete Permanently?'),
        content: const Text('This capture will be deleted forever.'),
        actions: [
          CupertinoDialogAction(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(context),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: const Text('Delete'),
            onPressed: () async {
              await DatabaseService.permanentlyDeleteItem(item);
              if (mounted) {
                Navigator.pop(context);
                _loadItems();
              }
            },
          ),
        ],
      ),
    );
  }

  void _emptyRecycleBin() {
    if (_deletedItems.isEmpty) return;
    
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Empty Recycle Bin?'),
        content: const Text('All items in the recycle bin will be permanently deleted.'),
        actions: [
          CupertinoDialogAction(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(context),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: const Text('Empty Bin'),
            onPressed: () async {
              await DatabaseService.emptyRecycleBin();
              if (mounted) {
                Navigator.pop(context);
                _loadItems();
              }
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
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
            : ListView.builder(
                itemCount: _deletedItems.length,
                itemBuilder: (context, index) {
                  final item = _deletedItems[index];
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
                    subtitle: Text('Deleted: ${item.createdAt.day}/${item.createdAt.month}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CupertinoButton(
                          padding: EdgeInsets.zero,
                          child: const Icon(CupertinoIcons.arrow_counterclockwise, color: CupertinoColors.activeBlue),
                          onPressed: () => _restoreItem(item),
                        ),
                        CupertinoButton(
                          padding: EdgeInsets.zero,
                          child: const Icon(CupertinoIcons.trash_fill, color: CupertinoColors.destructiveRed),
                          onPressed: () => _permanentlyDeleteItem(item),
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
