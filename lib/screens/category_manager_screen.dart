import 'package:flutter/cupertino.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/database_service.dart';

class CategoryManagerScreen extends StatefulWidget {
  const CategoryManagerScreen({super.key});

  @override
  State<CategoryManagerScreen> createState() => _CategoryManagerScreenState();
}

class _CategoryManagerScreenState extends State<CategoryManagerScreen> {
  List<String> _categories = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    final prefs = await SharedPreferences.getInstance();
    final cats = prefs.getStringList('user_categories') ?? ['General', 'Work', 'Personal', 'Social', 'School'];
    setState(() {
      _categories = cats;
      _isLoading = false;
    });
  }

  Future<void> _saveCategories() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('user_categories', _categories);
    // Notify other screens to refresh
    DatabaseService.categoryNotifier.value++;
  }

  void _addCategory() {
    final TextEditingController controller = TextEditingController();
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Add Category'),
        content: Padding(
          padding: const EdgeInsets.only(top: 12.0),
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
            child: const Text('Add'),
            onPressed: () {
              if (controller.text.isNotEmpty) {
                setState(() {
                  _categories.add(controller.text);
                });
                _saveCategories();
                Navigator.pop(context);
              }
            },
          ),
        ],
      ),
    );
  }

  void _deleteCategory(int index) {
    if (_categories[index] == 'General') {
      showCupertinoDialog(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: const Text('Cannot Delete'),
          content: const Text('The "General" category is default and cannot be removed.'),
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

    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Delete Folder?'),
        content: Text('Are you sure you want to delete "${_categories[index]}"? Items in this folder will move to "General".'),
        actions: [
          CupertinoDialogAction(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(context),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: const Text('Delete'),
            onPressed: () {
              setState(() {
                _categories.removeAt(index);
              });
              _saveCategories();
              Navigator.pop(context);
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
        middle: const Text('Manage Folders'),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _addCategory,
          child: const Icon(CupertinoIcons.plus_circle_fill, size: 28),
        ),
      ),
      child: SafeArea(
        child: _isLoading
            ? const Center(child: CupertinoActivityIndicator())
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _categories.length,
                itemBuilder: (context, index) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: CupertinoTheme.of(context).barBackgroundColor,
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(
                        color: CupertinoColors.systemGrey.withOpacity(0.2),
                      ),
                    ),
                    child: CupertinoListTile(
                      leading: const Icon(CupertinoIcons.folder_fill, color: CupertinoColors.activeBlue),
                      title: Text(_categories[index]),
                      trailing: _categories[index] == 'General'
                          ? null
                          : CupertinoButton(
                              padding: EdgeInsets.zero,
                              onPressed: () => _deleteCategory(index),
                              child: const Icon(CupertinoIcons.trash, color: CupertinoColors.destructiveRed, size: 20),
                            ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
