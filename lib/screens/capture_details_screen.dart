import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../models/screenshot_item.dart';
import '../services/database_service.dart';
import '../services/notification_service.dart';
import '../widgets/screenshot_popup.dart';
import '../services/ocr_service.dart';
import '../widgets/custom_delete_dialog.dart';

class CaptureDetailsScreen extends StatefulWidget {
  final ScreenshotItem item;

  const CaptureDetailsScreen({super.key, required this.item});

  @override
  State<CaptureDetailsScreen> createState() => _CaptureDetailsScreenState();
}

class _CaptureDetailsScreenState extends State<CaptureDetailsScreen> {
  late ScreenshotItem _currentItem;
  final ScrollController _scrollController = ScrollController();
  final FlutterTts _flutterTts = FlutterTts();
  double _headerOpacity = 0.0;
  bool _isSpeaking = false;
  bool _isExtractingText = false;

  @override
  void initState() {
    super.initState();
    _currentItem = widget.item;
    _scrollController.addListener(_onScroll);
    _initTts();
  }

  Future<void> _initTts() async {
    try {
      await _flutterTts.awaitSpeakCompletion(true);
      if (Platform.isAndroid) {
        await Future.delayed(const Duration(milliseconds: 500));
      }
      List<dynamic> languages = await _flutterTts.getLanguages;
      String targetLang = "en-US";
      bool hasEnUs = languages.any((l) => l.toString().replaceAll('_', '-') == 'en-US');
      if (!hasEnUs) {
         var anyEnglish = languages.firstWhere(
           (l) => l.toString().startsWith('en'), 
           orElse: () => languages.isNotEmpty ? languages.first : "en-US"
         );
         targetLang = anyEnglish.toString();
      }
      await _flutterTts.setLanguage(targetLang);
      await _flutterTts.setSpeechRate(0.5);
      await _flutterTts.setVolume(1.0);
      await _flutterTts.setPitch(1.0);
      _flutterTts.setStartHandler(() {
        if (mounted) setState(() => _isSpeaking = true);
      });
      _flutterTts.setCompletionHandler(() {
        if (mounted) setState(() => _isSpeaking = false);
      });
      _flutterTts.setErrorHandler((msg) {
        if (mounted) setState(() => _isSpeaking = false);
      });
    } catch (e) {
      debugPrint('TTS Error: $e');
    }
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    double opacity = (_scrollController.offset / 150).clamp(0.0, 1.0);
    if (opacity != _headerOpacity) {
      setState(() => _headerOpacity = opacity);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _flutterTts.stop();
    super.dispose();
  }

  Future<void> _speakNote() async {
    if (_isSpeaking) {
      await _flutterTts.stop();
      if (mounted) setState(() => _isSpeaking = false);
    } else {
      if (_currentItem.note.isNotEmpty) {
        if (Platform.isAndroid) {
          await Future.delayed(const Duration(milliseconds: 200));
        }
        await _flutterTts.speak(_currentItem.note);
      }
    }
  }

  Future<void> _extractText() async {
    // Toggle OFF: If text is already extracted, clicking again clears it
    if (_currentItem.extractedText.isNotEmpty) {
      setState(() {
        _currentItem.extractedText = '';
      });
      await DatabaseService.addItem(_currentItem);
      return;
    }

    // Toggle ON: Run OCR
    setState(() => _isExtractingText = true);
    try {
      String text = await OCRService.extractText(_currentItem.path);
      
      if (text.isNotEmpty) {
        // Format the text: Clean extra spaces, fix line breaks
        // Intelligent paragraph formatting
        String formattedText = text
            .replaceAll(RegExp(r'(?<!\n)\n(?!\n)'), ' ') // Replace single newlines with space
            .replaceAll(RegExp(r'\n{2,}'), '\n\n') // Normalize multiple newlines
            .replaceAll(RegExp(r' {2,}'), ' ') // Clean extra spaces
            .trim();

        setState(() {
          _currentItem.extractedText = formattedText;
        });
        await DatabaseService.addItem(_currentItem);
      } else {
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('No Text Found'),
              content: const Text('Could not find any readable text in this image.'),
              actions: [
                TextButton(
                  child: const Text('OK'),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('OCR Error: $e');
    } finally {
      if (mounted) setState(() => _isExtractingText = false);
    }
  }

  void _editItem() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ScreenshotPopup(
        initialNote: _currentItem.note,
        initialCategory: _currentItem.category,
        imagePath: _currentItem.path,
        onSave: (note, category, extractedText) async {
          setState(() {
            _currentItem.note = note;
            _currentItem.category = category;
            if (_currentItem.extractedText.isEmpty) {
              _currentItem.extractedText = extractedText;
            }
          });
          await DatabaseService.addItem(_currentItem);
        },
      ),
    );
  }

  void _shareItem() {
    final hasNote = _currentItem.note.isNotEmpty;
    final hasText = _currentItem.extractedText.isNotEmpty;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'Share Capture',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.all_inclusive_outlined),
              title: const Text('Share All (Image + Text)'),
              onTap: () {
                Navigator.pop(context);
                String shareText = _currentItem.note;
                if (hasText) {
                  if (shareText.isNotEmpty) shareText += '\n\n--- Extracted Text ---\n';
                  shareText += _currentItem.extractedText;
                }
                Share.shareXFiles(
                  [XFile(_currentItem.path)],
                  text: shareText,
                  subject: hasNote ? _currentItem.note : 'Shared Screenshot',
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.image_outlined),
              title: const Text('Share Image Only'),
              onTap: () {
                Navigator.pop(context);
                Share.shareXFiles([XFile(_currentItem.path)]);
              },
            ),
            if (hasNote || hasText)
              ListTile(
                leading: const Icon(Icons.text_fields_outlined),
                title: const Text('Share Text Only'),
                onTap: () {
                  Navigator.pop(context);
                  String shareText = _currentItem.note;
                  if (hasText) {
                    if (shareText.isNotEmpty) shareText += '\n\n';
                    shareText += _currentItem.extractedText;
                  }
                  Share.share(shareText);
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _deleteItem() {
    showCustomDeleteDialog(
      context: context,
      title: 'Delete media',
      subtitle: 'Are you sure you want to delete this photo?',
      deleteButtonText: 'Delete',
      onDelete: () async {
        await DatabaseService.deleteItem(_currentItem);
        if (mounted) {
          Navigator.pop(context, true);
        }
      },
    );
  }

  Widget _buildActionChips(String text) {
    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;
    final surfaceColor = Theme.of(context).colorScheme.surface;
    final onSurfaceColor = Theme.of(context).colorScheme.onSurface;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Stack(
        children: [
          CustomScrollView(
            controller: _scrollController,
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Column(
                  children: [
                    Hero(
                      tag: 'capture_${_currentItem.id}',
                      child: SizedBox(
                        width: double.infinity,
                        height: MediaQuery.of(context).size.height * 0.55,
                        child: ClipRRect(
                          child: InteractiveViewer(
                            minScale: 1.0,
                            maxScale: 4.0,
                            child: Image.file(File(_currentItem.path), fit: BoxFit.contain),
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
                      child: Container(
                        padding: const EdgeInsets.all(28),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              isDark ? const Color(0xFF1A1A1A).withValues(alpha: 0.9) : Colors.white.withValues(alpha: 0.9),
                              isDark ? const Color(0xFF121212).withValues(alpha: 0.95) : Theme.of(context).colorScheme.surfaceContainer.withValues(alpha: 0.9),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(32),
                          border: Border.all(color: onSurfaceColor.withValues(alpha: 0.15), width: 0.8),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.3), 
                              blurRadius: 35, 
                              offset: const Offset(0, 15),
                            )
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: primaryColor.withValues(alpha: 0.1), 
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        'NOTE', 
                                        style: TextStyle(
                                          fontSize: 11, 
                                          fontWeight: FontWeight.w900, 
                                          color: primaryColor, 
                                          letterSpacing: 2.0,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    if (_currentItem.note.isNotEmpty)
                                      IconButton(
                                        padding: EdgeInsets.zero,
                                        onPressed: _speakNote,
                                        icon: Icon(
                                          _isSpeaking ? Icons.stop_circle : Icons.play_circle, 
                                          color: primaryColor, 
                                          size: 28,
                                        ),
                                      ),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.04),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: onSurfaceColor.withValues(alpha: 0.1), width: 0.5),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.folder, size: 14, color: Theme.of(context).colorScheme.onSurfaceVariant),
                                      const SizedBox(width: 6),
                                      Text(
                                        _currentItem.category.toUpperCase(),
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w800,
                                          color: onSurfaceColor.withValues(alpha: 0.6),
                                          letterSpacing: 1.0,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            Text(
                              _currentItem.note.isNotEmpty ? _currentItem.note : 'No description provided.',
                              style: TextStyle(
                                fontSize: 18, 
                                color: onSurfaceColor, 
                                height: 1.6, 
                                fontWeight: FontWeight.w500, 
                                letterSpacing: 0.2,
                              ),
                            ),
                            if (_currentItem.extractedText.isNotEmpty) ...[
                              const SizedBox(height: 32),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.1), 
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Image.asset('assets/krabby.png', width: 14, height: 14),
                                    const SizedBox(width: 6),
                                    const Text(
                                      'KRABBY VISION', 
                                      style: TextStyle(
                                        fontSize: 10, 
                                        fontWeight: FontWeight.w900, 
                                        color: Color(0xFFF75A4C), 
                                        letterSpacing: 1.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.03),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.15), width: 1),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    TextField(
                                      controller: TextEditingController(text: _currentItem.extractedText),
                                      readOnly: true,
                                      maxLines: null,
                                      decoration: const InputDecoration(
                                        border: InputBorder.none,
                                        contentPadding: EdgeInsets.zero,
                                      ),
                                      style: TextStyle(
                                        fontSize: 14, 
                                        color: onSurfaceColor.withValues(alpha: 0.85), 
                                        height: 1.6, 
                                        fontWeight: FontWeight.w400, 
                                        letterSpacing: 0.2,
                                      ),
                                    ),
                                    _buildActionChips(_currentItem.extractedText),
                                  ],
                                ),
                              ),
                            ],
                            const SizedBox(height: 48),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _ActionButton(icon: Icons.edit_outlined, label: 'Edit', onPressed: _editItem, color: primaryColor),
                                _ActionButton(
                                  customIcon: _currentItem.extractedText.isNotEmpty ? null : Image.asset('assets/krabby.png', width: 28, height: 28),
                                  icon: _currentItem.extractedText.isNotEmpty ? Icons.clear : null, 
                                  label: _isExtractingText ? 'Reading...' : (_currentItem.extractedText.isNotEmpty ? 'Clear Text' : 'Krabby Vision'), 
                                  onPressed: _isExtractingText ? () {} : _extractText, 
                                  color: _currentItem.extractedText.isNotEmpty ? Colors.grey : const Color(0xFFF75A4C), 
                                  isLoading: _isExtractingText
                                ),
                                _ActionButton(icon: Icons.share_outlined, label: 'Share', onPressed: _shareItem, color: primaryColor),
                                _ActionButton(icon: Icons.delete_outline, label: 'Delete', onPressed: _deleteItem, color: primaryColor),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 140),
                  ],
                ),
              ),
            ],
          ),
          Positioned(
            top: 0, left: 0, right: 0,
            child: ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10 * _headerOpacity, sigmaY: 10 * _headerOpacity),
                child: Container(
                  padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
                  color: (isDark ? Colors.black : Colors.white).withValues(alpha: _headerOpacity.clamp(0, 0.8)),
                  child: SizedBox(
                    height: 60,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.3), shape: BoxShape.circle),
                              child: const Icon(Icons.arrow_back, color: Colors.white, size: 22),
                            ),
                          ),
                          Opacity(
                            opacity: _headerOpacity,
                            child: Text(
                              'Details', 
                              style: TextStyle(
                                color: onSurfaceColor, 
                                fontWeight: FontWeight.w700, 
                                fontSize: 18, 
                                letterSpacing: -0.5,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () async {
                              setState(() => _currentItem.isFavorite = !_currentItem.isFavorite);
                              await DatabaseService.addItem(_currentItem);
                            },
                            icon: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.3), shape: BoxShape.circle),
                              child: Icon(
                                _currentItem.isFavorite ? Icons.favorite : Icons.favorite_border, 
                                color: _currentItem.isFavorite ? Colors.red : Colors.white, 
                                size: 22,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData? icon;
  final Widget? customIcon;
  final String label;
  final VoidCallback onPressed;
  final Color color;
  final bool isLoading;

  const _ActionButton({this.icon, this.customIcon, required this.label, required this.onPressed, required this.color, this.isLoading = false});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: isLoading ? null : onPressed,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft, 
                  end: Alignment.bottomRight, 
                  colors: [color.withValues(alpha: 0.2), color.withValues(alpha: 0.05)],
                ),
                shape: BoxShape.circle,
                border: Border.all(color: color.withValues(alpha: 0.2), width: 1),
              ),
              child: isLoading 
                ? const SizedBox(
                    width: 28, 
                    height: 28, 
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : (customIcon ?? Icon(icon, color: color, size: 28)),
            ),
            const SizedBox(height: 8),
            Text(
              label, 
              style: TextStyle(
                fontSize: 13, 
                color: color.withValues(alpha: 0.9), 
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? color;

  const _ActionChip({required this.icon, required this.label, required this.value, this.color});

  @override
  Widget build(BuildContext context) {
    final chipColor = color ?? Theme.of(context).colorScheme.secondary;
    return GestureDetector(
      onTap: () async {
        final uri = Uri.parse(value);
        if (await canLaunchUrl(uri)) await launchUrl(uri);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: chipColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: chipColor.withValues(alpha: 0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: chipColor),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: chipColor)),
          ],
        ),
      ),
    );
  }
}
