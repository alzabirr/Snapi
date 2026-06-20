import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/database_service.dart';
import '../widgets/custom_delete_dialog.dart';

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
    final cats = prefs.getStringList('user_categories') ?? ['Uncategorized', 'Work', 'Personal', 'Social'];
    setState(() {
      _categories = cats;
      _isLoading = false;
    });
  }

  Future<void> _saveCategories() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('user_categories', _categories);
    DatabaseService.categoryNotifier.value++;
  }

  void _addCategory() {
    final TextEditingController controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Category'),
        content: Padding(
          padding: const EdgeInsets.only(top: 12.0),
          child: TextField(
            controller: controller,
            decoration: const InputDecoration(
              hintText: 'Folder Name',
              border: OutlineInputBorder(),
            ),
            autofocus: true,
          ),
        ),
        actions: [
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(context),
          ),
          TextButton(
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
    if (_categories[index] == 'Uncategorized') {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Cannot Delete'),
          content: const Text('The "Uncategorized" category is default and cannot be removed.'),
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

    showCustomDeleteDialog(
      context: context,
      title: 'Delete Folder',
      subtitle: 'Are you sure you want to delete "${_categories[index]}"? Items in this folder will move to "Uncategorized".',
      deleteButtonText: 'Delete',
      onDelete: () {
        setState(() {
          _categories.removeAt(index);
        });
        _saveCategories();
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
        title: const Text('Manage Folders'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.add_circle, size: 28, color: theme.colorScheme.primary),
            onPressed: _addCategory,
          ),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? Center(child: CircularProgressIndicator(color: theme.colorScheme.primary))
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _categories.length,
                itemBuilder: (context, index) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(
                        color: theme.colorScheme.onSurface.withOpacity(0.12),
                        width: 0.5,
                      ),
                    ),
                    child: ListTile(
                      leading: Icon(Icons.folder, color: theme.colorScheme.primary),
                      title: Text(
                        _categories[index],
                        style: TextStyle(
                          color: theme.colorScheme.onSurface,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      trailing: _categories[index] == 'Uncategorized'
                          ? null
                          : IconButton(
                              icon: Icon(Icons.delete_outline, color: theme.colorScheme.error, size: 22),
                              onPressed: () => _deleteCategory(index),
                            ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
