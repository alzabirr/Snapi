import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:hive_flutter/hive_flutter.dart';
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
