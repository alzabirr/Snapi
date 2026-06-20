import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
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
  final String _extractedText = '';

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
        await _loadCategories();
        
        setState(() {
          _suggestedCategory = result.category;
          _selectedCategory = result.category;
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
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New Folder'),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: TextField(
            controller: controller,
            decoration: const InputDecoration(
              hintText: 'Folder Name',
              border: OutlineInputBorder(),
            ),
            autofocus: true,
            textCapitalization: TextCapitalization.words,
          ),
        ),
        actions: [
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(context),
          ),
          TextButton(
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;
    
    final backgroundColor = theme.scaffoldBackgroundColor;
    final surfaceColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textColor = theme.colorScheme.onSurface;
    final secondaryTextColor = textColor.withOpacity(0.6);
    final iconColor = textColor.withOpacity(0.5);
    final borderColor = textColor.withOpacity(0.08);

    return Material(
      color: Colors.transparent,
      child: Container(
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
              child: IconButton(
                onPressed: () => Navigator.pop(context),
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.close, color: textColor, size: 20),
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
                              color: Colors.black.withOpacity(isDark ? 0.5 : 0.1),
                              blurRadius: 40,
                            ),
                          ],
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: _imageFile != null 
                          ? Image.file(_imageFile!, fit: BoxFit.contain)
                          : Center(child: CircularProgressIndicator(color: theme.colorScheme.primary)),
                      ),
                    ),
                  ),
                ),

                // PART 2: Krabby Suggest & Category Section
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
                              color: theme.colorScheme.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.auto_awesome, color: theme.colorScheme.primary, size: 14),
                                const SizedBox(width: 6),
                                Text(
                                  'KRABBY SUGGESTS: ',
                                  style: TextStyle(
                                    color: theme.colorScheme.primary.withOpacity(0.7),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1.0,
                                  ),
                                ),
                                Text(
                                  _suggestedCategory!.toUpperCase(),
                                  style: TextStyle(
                                    color: theme.colorScheme.primary,
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
                                  color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: borderColor),
                                ),
                                child: Icon(Icons.add, color: textColor, size: 18),
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
                                    color: isSelected ? theme.colorScheme.primary : (isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03)),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: isSelected ? theme.colorScheme.primary : borderColor),
                                  ),
                                  child: Center(
                                    child: Text(
                                      cat,
                                      style: TextStyle(
                                        color: isSelected ? Colors.white : secondaryTextColor,
                                        fontSize: 12,
                                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
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
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                      ],
                    ),
                    child: Row(
                      children: [
                        // Voice Button
                        IconButton(
                          onPressed: _toggleListening,
                          icon: Icon(
                            _isListening ? Icons.stop : Icons.mic,
                            color: _isListening ? Colors.red : iconColor,
                            size: 20,
                          ),
                        ),
                        
                        // Text Input
                        Expanded(
                          child: TextField(
                            controller: _noteController,
                            decoration: InputDecoration(
                              hintText: 'Add a note...',
                              hintStyle: TextStyle(
                                color: secondaryTextColor.withOpacity(0.4),
                                fontSize: 16,
                              ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            ),
                            style: TextStyle(color: textColor, fontSize: 16),
                            cursorColor: theme.colorScheme.primary,
                            autofocus: true,
                          ),
                        ),

                        // Action Button
                        GestureDetector(
                          onTap: () {
                            widget.onSave(_noteController.text, _selectedCategory, _extractedText);
                            Navigator.pop(context);
                          },
                          child: Container(
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.arrow_forward,
                              color: Colors.white,
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
    ),
  );
}
}
