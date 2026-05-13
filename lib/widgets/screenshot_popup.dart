import 'dart:io';
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/speech_service.dart';
import '../services/database_service.dart';
import '../services/ai_service.dart';

class ScreenshotPopup extends StatefulWidget {
  final AssetEntity? asset;
  final String? imagePath;
  final String? initialNote;
  final String? initialCategory;
  final Function(String note, String category, String extractedText) onSave;

  const ScreenshotPopup({
    super.key,
    this.asset,
    this.imagePath,
    this.initialNote,
    this.initialCategory,
    required this.onSave,
  });

  @override
  State<ScreenshotPopup> createState() => _ScreenshotPopupState();
}

class _ScreenshotPopupState extends State<ScreenshotPopup> with SingleTickerProviderStateMixin {
  late final TextEditingController _noteController;
  String _selectedCategory = 'Uncategorized';
  List<String> _categories = ['Uncategorized', 'Personal'];
  bool _isListening = false;
  bool _isAnalyzingAI = false;
  String? _suggestedCategory;
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
        // Only reset _selectedCategory if it's not in the new list
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
      // Run AI analysis only if we're not editing an existing item
      if (widget.initialCategory == null && _imageFile != null) {
        final prefs = await SharedPreferences.getInstance();
        final isAuto = prefs.getBool('auto_smart_folders') ?? true;
        if (isAuto) {
          _runAIAnalysis();
        }
      }
    }
  }

  Future<void> _runAIAnalysis() async {
    setState(() => _isAnalyzingAI = true);
    try {
      final result = await AIService.analyzeAndSuggest(_imageFile!.path);
      if (mounted && result.category != 'Other') {
        // Refresh categories list in case AIService created a new one silently
        await _loadCategories();
        
        setState(() {
          _suggestedCategory = result.category;
          _selectedCategory = result.category; // Auto-select the suggestion
        });
      }
    } catch (e) {
      print('DEBUG: AI Analysis error: $e');
    } finally {
      if (mounted) setState(() => _isAnalyzingAI = false);
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
    final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;
    
    // Theme-based colors
    final backgroundColor = isDark ? const Color(0xFF000000) : const Color(0xFFFFFFFF);
    final surfaceColor = isDark ? const Color(0xFF1C1C1E) : const Color(0xFFF2F2F7);
    final textColor = isDark ? CupertinoColors.white : CupertinoColors.black;
    final secondaryTextColor = isDark ? CupertinoColors.white.withOpacity(0.5) : CupertinoColors.black.withOpacity(0.5);
    final iconColor = isDark ? CupertinoColors.white.withOpacity(0.4) : CupertinoColors.black.withOpacity(0.4);
    final borderColor = isDark ? CupertinoColors.white.withOpacity(0.08) : CupertinoColors.black.withOpacity(0.08);

    return Container(
      height: MediaQuery.of(context).size.height,
      width: MediaQuery.of(context).size.width,
      color: backgroundColor,
      child: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            // Close button at top
            Positioned(
              top: 20,
              right: 20,
              child: CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isDark ? CupertinoColors.white.withOpacity(0.1) : CupertinoColors.black.withOpacity(0.05),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(CupertinoIcons.xmark, color: textColor, size: 20),
                ),
              ),
            ),

            // Main Layout Column
            Column(
              children: [
                // PART 1: Large Image Section
                Expanded(
                  flex: 3,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 40, 20, 20),
                    child: Center(
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(28),
                          boxShadow: [
                            BoxShadow(
                              color: CupertinoColors.black.withOpacity(isDark ? 0.5 : 0.1),
                              blurRadius: 40,
                            ),
                          ],
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: _imageFile != null 
                          ? Image.file(_imageFile!, fit: BoxFit.contain)
                          : const CupertinoActivityIndicator(),
                      ),
                    ),
                  ),
                ),

                // PART 2: Snapi Suggest & Category Section
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_suggestedCategory != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                            decoration: BoxDecoration(
                              color: CupertinoColors.activeBlue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(CupertinoIcons.sparkles, color: CupertinoColors.activeBlue, size: 14),
                                const SizedBox(width: 6),
                                Text(
                                  'SNAPI SUGGESTS: ',
                                  style: TextStyle(
                                    color: CupertinoColors.activeBlue.withOpacity(0.7),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1.0,
                                  ),
                                ),
                                Text(
                                  _suggestedCategory!.toUpperCase(),
                                  style: const TextStyle(
                                    color: CupertinoColors.activeBlue,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.0,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      
                      // Folder List
                      SizedBox(
                        height: 42,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          children: [
                            // Add Folder
                            GestureDetector(
                              onTap: _showAddCategoryDialog,
                              child: Container(
                                margin: const EdgeInsets.only(right: 10),
                                padding: const EdgeInsets.symmetric(horizontal: 14),
                                decoration: BoxDecoration(
                                  color: isDark ? CupertinoColors.white.withOpacity(0.08) : CupertinoColors.black.withOpacity(0.05),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: borderColor),
                                ),
                                child: Icon(CupertinoIcons.add, color: textColor, size: 18),
                              ),
                            ),
                            ..._categories.map((cat) {
                              final isSelected = _selectedCategory == cat;
                              return GestureDetector(
                                onTap: () => setState(() => _selectedCategory = cat),
                                child: Container(
                                  margin: const EdgeInsets.only(right: 8),
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  decoration: BoxDecoration(
                                    color: isSelected ? CupertinoColors.activeBlue : (isDark ? CupertinoColors.white.withOpacity(0.05) : CupertinoColors.black.withOpacity(0.03)),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: isSelected ? CupertinoColors.activeBlue : borderColor),
                                  ),
                                  child: Center(
                                    child: Text(
                                      cat,
                                      style: TextStyle(
                                        color: isSelected ? CupertinoColors.white : secondaryTextColor,
                                        fontSize: 12,
                                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // PART 3: Input Section
                Padding(
                  padding: EdgeInsets.only(
                    left: 20, 
                    right: 20, 
                    bottom: bottomPadding > 0 ? bottomPadding + 10 : 30
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: surfaceColor,
                      borderRadius: BorderRadius.circular(40),
                      border: Border.all(color: borderColor),
                      boxShadow: [
                        if (!isDark)
                          BoxShadow(
                            color: CupertinoColors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                      ],
                    ),
                    child: Row(
                      children: [
                        // Voice Button
                        CupertinoButton(
                          padding: const EdgeInsets.only(left: 10),
                          onPressed: _toggleListening,
                          child: Icon(
                            _isListening ? CupertinoIcons.stop_fill : CupertinoIcons.mic_fill,
                            color: _isListening ? CupertinoColors.systemRed : iconColor,
                            size: 20,
                          ),
                        ),
                        
                        // Text Input
                        Expanded(
                          child: CupertinoTextField(
                            controller: _noteController,
                            placeholder: 'Add a note...',
                            placeholderStyle: TextStyle(
                              color: secondaryTextColor.withOpacity(0.4),
                              fontSize: 16,
                            ),
                            style: TextStyle(color: textColor, fontSize: 16),
                            decoration: null,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            cursorColor: CupertinoColors.activeBlue,
                            autofocus: true,
                          ),
                        ),

                        // Action Button (Blue & Flat)
                        GestureDetector(
                          onTap: () {
                            widget.onSave(_noteController.text, _selectedCategory, _extractedText);
                            Navigator.pop(context);
                          },
                          child: Container(
                            width: 46,
                            height: 46,
                            decoration: const BoxDecoration(
                              color: CupertinoColors.activeBlue,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              CupertinoIcons.arrow_right,
                              color: CupertinoColors.white,
                              size: 20,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
