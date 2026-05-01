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
  List<AssetEntity> _assets = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAssets();
  }

  Future<void> _loadAssets() async {
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
      final List<AssetEntity> entities = await paths[0].getAssetListRange(start: 0, end: 500);
      if (mounted) {
        setState(() {
          _assets = entities;
          _isLoading = false;
        });
      }
    } else {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showNotePopup(AssetEntity asset) {
    // Check if this screenshot is already in the database
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
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Add Capture'),
      ),
      child: SafeArea(
        child: _isLoading 
          ? const Center(child: CupertinoActivityIndicator(radius: 15))
          : _assets.isEmpty
            ? const Center(child: Text('No images found', style: TextStyle(color: CupertinoColors.systemGrey)))
            : GridView.builder(
                padding: const EdgeInsets.all(2),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 2,
                  crossAxisSpacing: 2,
                ),
                itemCount: _assets.length,
                itemBuilder: (context, index) {
                  return GestureDetector(
                    onTap: () => _showNotePopup(_assets[index]),
                    child: FutureBuilder<Uint8List?>(
                      future: _assets[index].thumbnailData,
                      builder: (context, snapshot) {
                        final data = snapshot.data;
                        if (data == null) return Container(color: CupertinoColors.systemGrey6);
                        return Image.memory(data, fit: BoxFit.cover);
                      },
                    ),
                  );
                },
              ),
      ),
    );
  }
}
