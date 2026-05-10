import 'dart:io';
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/speech_service.dart';
import '../services/database_service.dart';

class ScreenshotPopup extends StatefulWidget {
  final AssetEntity? asset;
  final String? imagePath;
  final String? initialNote;
  final String? initialCategory;
  final Function(String note, String category, String extractedText) onSave;
  final VoidCallback? onDelete;

  const ScreenshotPopup({
    super.key,
    this.asset,
    this.imagePath,
    this.initialNote,
    this.initialCategory,
    required this.onSave,
    this.onDelete,
  });

  @override
  State<ScreenshotPopup> createState() => _ScreenshotPopupState();
}

class _ScreenshotPopupState extends State<ScreenshotPopup> with SingleTickerProviderStateMixin {
  late final TextEditingController _noteController;
  String _selectedCategory = 'Uncategorized';
  List<String> _categories = ['Uncategorized', 'Work', 'Personal', 'Social'];
  bool _isListening = false;
  File? _imageFile;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  String _extractedText = '';

  @override
  void initState() {
    super.initState();
    _noteController = TextEditingController(text: widget.initialNote);
    _selectedCategory = widget.initialCategory ?? 'Uncategorized';
    _loadCategories();
    _loadImage();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  Future<void> _loadCategories() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList('user_categories');
    if (saved != null) {
      setState(() {
        _categories = saved;
        if (!_categories.contains(_selectedCategory)) {
          _selectedCategory = _categories.first;
        }
      });
    }
  }

  Future<void> _loadImage() async {
    if (widget.imagePath != null) {
      _imageFile = File(widget.imagePath!);
    } else if (widget.asset != null) {
      final file = await widget.asset!.file;
      _imageFile = file;
    }

    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _noteController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _toggleListening() async {
    if (_isListening) {
      await SpeechService.stopListening();
      _pulseController.stop();
      if (mounted) setState(() => _isListening = false);
    } else {
      _pulseController.repeat(reverse: true);
      if (mounted) setState(() => _isListening = true);
      
      await SpeechService.startListening((text) {
        if (mounted) {
          setState(() {
            _noteController.text = text;
            _noteController.selection = TextSelection.fromPosition(
              TextPosition(offset: _noteController.text.length),
            );
          });
        }
      });
    }
  }

  void _showAddCategoryDialog() {
    final TextEditingController controller = TextEditingController();
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('New Folder'),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: CupertinoTextField(
            controller: controller,
            placeholder: 'Folder Name',
            autofocus: true,
            textCapitalization: TextCapitalization.words,
          ),
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(context),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            child: const Text('Create'),
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                final prefs = await SharedPreferences.getInstance();
                if (!_categories.contains(name)) {
                  setState(() {
                    _categories.add(name);
                    _selectedCategory = name;
                  });
                  await prefs.setStringList('user_categories', _categories);
                  DatabaseService.categoryNotifier.value++;
                }
                if (mounted) Navigator.pop(context);
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildImage() {
    if (_imageFile != null) {
      return Container(
        height: 240,
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          color: CupertinoColors.systemFill.resolveFrom(context).withOpacity(0.2),
          border: Border.all(color: CupertinoColors.label.resolveFrom(context).withOpacity(0.1), width: 0.5),
        ),
        clipBehavior: Clip.antiAlias,
        child: Image.file(
          _imageFile!,
          fit: BoxFit.contain,
        ),
      );
    }
    return Container(
      height: 200,
      width: double.infinity,
      decoration: BoxDecoration(
        color: CupertinoColors.systemFill.resolveFrom(context).withOpacity(0.1),
        borderRadius: BorderRadius.circular(24),
      ),
      child: const Center(
        child: Icon(CupertinoIcons.photo, color: CupertinoColors.systemGrey, size: 40),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPopupSurface(
      child: Container(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          left: 20,
          right: 20,
          top: 12,
        ),
        decoration: BoxDecoration(
          color: CupertinoTheme.of(context).barBackgroundColor,
        ),
        child: SafeArea(
          top: false,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Elegant handle
                  Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 24),
                    decoration: BoxDecoration(
                      color: CupertinoColors.systemGrey.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        widget.initialNote == null ? 'NEW CAPTURE' : 'EDIT CAPTURE',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          color: CupertinoColors.activeBlue,
                          letterSpacing: 2.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
    
                  _buildImage(),
                  
                  const SizedBox(height: 20),

                  // Category Selector (New)
                  SizedBox(
                    height: 40,
                    child: Row(
                      children: [
                        // Add New Category Button
                        GestureDetector(
                          onTap: _showAddCategoryDialog,
                          child: Container(
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: CupertinoColors.activeBlue.withOpacity(0.1),
                              shape: BoxShape.circle,
                              border: Border.all(color: CupertinoColors.activeBlue.withOpacity(0.2)),
                            ),
                            child: const Icon(CupertinoIcons.add, color: CupertinoColors.activeBlue, size: 20),
                          ),
                        ),
                        Expanded(
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: _categories.length,
                            itemBuilder: (context, index) {
                              final cat = _categories[index];
                              final isSelected = _selectedCategory == cat;
                              return GestureDetector(
                                onTap: () => setState(() => _selectedCategory = cat),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  margin: const EdgeInsets.only(right: 8),
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  decoration: BoxDecoration(
                                    color: isSelected ? CupertinoColors.activeBlue : CupertinoColors.systemFill.resolveFrom(context).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: isSelected ? CupertinoColors.activeBlue : CupertinoColors.label.resolveFrom(context).withOpacity(0.1),
                                    ),
                                  ),
                                  child: Center(
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          CupertinoIcons.folder_fill,
                                          size: 14,
                                          color: isSelected ? CupertinoColors.white : CupertinoColors.activeBlue.withOpacity(0.7),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          cat,
                                          style: TextStyle(
                                            color: isSelected ? CupertinoColors.white : CupertinoColors.label.resolveFrom(context).withOpacity(0.7),
                                            fontSize: 13,
                                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                          ),
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

                  const SizedBox(height: 20),
                  
                  // Beautiful & User-Friendly Description Area
                  Container(
                    decoration: BoxDecoration(
                      color: CupertinoColors.systemFill.resolveFrom(context).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: _isListening ? CupertinoColors.activeBlue.resolveFrom(context).withOpacity(0.4) : CupertinoColors.label.resolveFrom(context).withOpacity(0.05),
                        width: 1.5,
                      ),
                    ),
                    child: Column(
                      children: [
                        CupertinoTextField(
                          controller: _noteController,
                          placeholder: 'Add a note...',
                          placeholderStyle: TextStyle(
                            color: CupertinoColors.systemGrey.withOpacity(0.3),
                            fontSize: 16,
                            letterSpacing: -0.2,
                          ),
                          maxLines: 5,
                          minLines: 3,
                          padding: const EdgeInsets.fromLTRB(22, 22, 22, 12),
                          style: TextStyle(
                            color: CupertinoColors.label.resolveFrom(context),
                            fontSize: 16,
                            height: 1.5,
                            letterSpacing: -0.1,
                          ),
                          decoration: null,
                          cursorColor: CupertinoColors.activeBlue,
                        ),
                        Padding(
                          padding: const EdgeInsets.only(left: 14, right: 14, bottom: 14),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              // Minimalist Record Button
                              GestureDetector(
                                onTap: _toggleListening,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: _isListening ? CupertinoColors.destructiveRed.withOpacity(0.15) : CupertinoColors.activeBlue.withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(30),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        _isListening ? CupertinoIcons.stop_fill : CupertinoIcons.mic_fill,
                                        size: 16,
                                        color: _isListening ? CupertinoColors.destructiveRed : CupertinoColors.activeBlue,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        _isListening ? 'STOP' : 'ADD VOICE',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 0.5,
                                          color: _isListening ? CupertinoColors.destructiveRed : CupertinoColors.activeBlue,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // Unified Primary Action
                  Row(
                    children: [
                      if (widget.onDelete != null) 
                        CupertinoButton(
                          padding: const EdgeInsets.only(right: 16),
                          onPressed: widget.onDelete,
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: CupertinoColors.destructiveRed.withOpacity(0.1),
                              shape: BoxShape.circle,
                              border: Border.all(color: CupertinoColors.destructiveRed.withOpacity(0.2), width: 0.5),
                            ),
                            child: const Icon(CupertinoIcons.trash, color: CupertinoColors.destructiveRed, size: 22),
                          ),
                        ),
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: CupertinoColors.activeBlue.withOpacity(0.2),
                                blurRadius: 15,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: CupertinoButton(
                            padding: const EdgeInsets.symmetric(vertical: 20),
                            color: CupertinoColors.activeBlue,
                            borderRadius: BorderRadius.circular(20),
                            onPressed: () {
                              widget.onSave(_noteController.text, _selectedCategory, _extractedText);
                              Navigator.pop(context);
                            },
                            child: Center(
                              child: Text(
                                widget.initialNote == null ? 'SAVE CAPTURE' : 'UPDATE CAPTURE',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900, 
                                  fontSize: 16, 
                                  color: CupertinoColors.white,
                                  letterSpacing: 1.0,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  CupertinoButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      'DISCARD',
                      style: TextStyle(
                        color: CupertinoColors.label.resolveFrom(context).withOpacity(0.4),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
}
