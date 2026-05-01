import 'dart:io';
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../models/screenshot_item.dart';
import '../services/database_service.dart';
import '../services/notification_service.dart';
import '../widgets/screenshot_popup.dart';

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

      // Normalize languages to find a match (handle en_US vs en-US)
      bool hasEnUs = languages.any((l) => l.toString().replaceAll('_', '-') == 'en-US');
      
      if (!hasEnUs) {
         // Try to find any English
         var anyEnglish = languages.firstWhere(
           (l) => l.toString().startsWith('en'), 
           orElse: () => languages.isNotEmpty ? languages.first : "en-US"
         );
         targetLang = anyEnglish.toString();
      }

      debugPrint('TTS: Setting language to $targetLang');
      await _flutterTts.setLanguage(targetLang);
      await _flutterTts.setSpeechRate(0.5);
      await _flutterTts.setVolume(1.0);
      await _flutterTts.setPitch(1.0);
      
      // More robust handlers

      _flutterTts.setStartHandler(() {
        debugPrint('TTS: Started speaking');
        if (mounted) setState(() => _isSpeaking = true);
      });
      _flutterTts.setCompletionHandler(() {
        debugPrint('TTS: Completed speaking');
        if (mounted) setState(() => _isSpeaking = false);
      });
      _flutterTts.setErrorHandler((msg) {
        debugPrint('TTS: Error - $msg');
        if (mounted) setState(() => _isSpeaking = false);
      });
    } catch (e) {
      debugPrint('TTS: Init Error - $e');
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
    debugPrint('TTS: Button clicked. Current state: speaking=$_isSpeaking');
    if (_isSpeaking) {
      await _flutterTts.stop();
      if (mounted) setState(() => _isSpeaking = false);
    } else {
      if (_currentItem.note.isNotEmpty) {
        debugPrint('TTS: Speaking - ${_currentItem.note}');
        if (Platform.isAndroid) {
          await Future.delayed(const Duration(milliseconds: 200));
        }
        var result = await _flutterTts.speak(_currentItem.note);
        debugPrint('TTS: Speak result code: $result');
      } else {
        debugPrint('TTS: Note is empty');
      }
    }
  }

  Future<void> _extractText() async {
    setState(() => _isExtractingText = true);
    try {
      final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
      final inputImage = InputImage.fromFilePath(_currentItem.path);
      final recognizedText = await textRecognizer.processImage(inputImage);
      await textRecognizer.close();

      if (recognizedText.text.isNotEmpty) {
        setState(() {
          _currentItem.extractedText = recognizedText.text.replaceAll('\n', ' ').trim();
        });
        await DatabaseService.addItem(_currentItem);
      } else {
        if (mounted) {
          showCupertinoDialog(
            context: context,
            builder: (context) => CupertinoAlertDialog(
              title: const Text('No Text Found'),
              content: const Text('Could not find any readable text in this screenshot.'),
              actions: [
                CupertinoDialogAction(
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
    showCupertinoModalPopup(
      context: context,
      barrierDismissible: false,
      builder: (context) => ScreenshotPopup(
        initialNote: _currentItem.note,
        initialCategory: _currentItem.category,
        initialReminder: _currentItem.reminderTime,
        imagePath: _currentItem.path,
        onSave: (note, category, reminder, extractedText) async {
          setState(() {
            _currentItem.note = note;
            _currentItem.category = category;
            _currentItem.reminderTime = reminder;
            // Only update extracted text if it was empty before
            if (_currentItem.extractedText.isEmpty) {
              _currentItem.extractedText = extractedText;
            }
          });
          await DatabaseService.addItem(_currentItem);
          
          if (reminder != null) {
            // Ensure permission is granted before scheduling
            await NotificationService.requestPermission();
            
            NotificationService.scheduleReminder(
              id: _currentItem.id.hashCode,
              title: 'Screenshot Reminder',
              body: note.isNotEmpty ? note : 'View your screenshot note',
              scheduledDate: reminder,
              payload: _currentItem.id,
            );
          }
        },
      ),
    );
  }

  void _shareItem() {
    Share.shareXFiles([XFile(_currentItem.path)], text: _currentItem.note);
  }

  void _deleteItem() {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Delete Capture'),
        content: const Text('Are you sure you want to delete this capture?'),
        actions: [
          CupertinoDialogAction(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(context),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () async {
              await DatabaseService.deleteItem(_currentItem);
              if (mounted) {
                Navigator.pop(context); // Close dialog
                Navigator.pop(context, true); // Return to home
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;
    return CupertinoPageScaffold(
      backgroundColor: CupertinoTheme.of(context).scaffoldBackgroundColor,
      child: Stack(
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
                      child: Container(
                        width: double.infinity,
                        height: MediaQuery.of(context).size.height * 0.55,
                        decoration: BoxDecoration(
                          boxShadow: isDark ? [] : [
                            BoxShadow(
                              color: CupertinoColors.activeBlue.withOpacity(0.1),
                              blurRadius: 40,
                              offset: const Offset(0, 10),
                            ),
                            BoxShadow(
                              color: CupertinoColors.black.withOpacity(0.1),
                              blurRadius: 30,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          child: InteractiveViewer(
                            minScale: 1.0,
                            maxScale: 4.0,
                            child: Image.file(
                              File(_currentItem.path),
                              fit: BoxFit.contain,
                            ),
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
                              isDark ? const Color(0xFF1A1A1A).withOpacity(0.9) : CupertinoColors.white.withOpacity(0.9),
                              isDark ? const Color(0xFF121212).withOpacity(0.95) : CupertinoColors.systemGrey6.withOpacity(0.9),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(32),
                          border: Border.all(
                            color: CupertinoColors.label.resolveFrom(context).withOpacity(0.15),
                            width: 0.8,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: CupertinoColors.black.withOpacity(0.6),
                              blurRadius: 35,
                              offset: const Offset(0, 15),
                            ),
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
                                        color: CupertinoColors.activeBlue.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Text(
                                        'DESCRIPTION',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w900,
                                          color: CupertinoColors.activeBlue,
                                          letterSpacing: 2.0,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    if (_currentItem.note.isNotEmpty)
                                      CupertinoButton(
                                        padding: EdgeInsets.zero,
                                        onPressed: _speakNote,
                                        child: Icon(
                                          _isSpeaking ? CupertinoIcons.stop_circle_fill : CupertinoIcons.play_circle_fill,
                                          color: CupertinoColors.activeBlue,
                                          size: 28,
                                        ),
                                      ),
                                  ],
                                ),
                                if (_currentItem.reminderTime != null)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: CupertinoColors.systemFill.resolveFrom(context).withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: CupertinoColors.label.resolveFrom(context).withOpacity(0.1), width: 0.5),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(CupertinoIcons.bell_fill, size: 13, color: CupertinoColors.activeBlue),
                                        const SizedBox(width: 6),
                                        Text(
                                          _currentItem.reminderTime.toString().substring(11, 16),
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: CupertinoColors.label.resolveFrom(context),
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            Text(
                              _currentItem.note.isNotEmpty ? _currentItem.note : 'No description provided for this capture.',
                              style: TextStyle(
                                fontSize: 18,
                                color: CupertinoColors.label.resolveFrom(context),
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
                                  color: CupertinoColors.systemOrange.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  'AI RECOGNIZED TEXT',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                    color: CupertinoColors.systemOrange,
                                    letterSpacing: 1.5,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: isDark 
                                      ? CupertinoColors.white.withOpacity(0.03) 
                                      : CupertinoColors.black.withOpacity(0.03),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: CupertinoColors.label.resolveFrom(context).withOpacity(0.05),
                                  ),
                                ),
                                child: Text(
                                  _currentItem.extractedText,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: CupertinoColors.label.resolveFrom(context).withOpacity(0.7),
                                    height: 1.5,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ),
                            ],
                            
                            const SizedBox(height: 48),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _ActionButton(
                                  icon: CupertinoIcons.pencil_circle_fill,
                                  label: 'Edit',
                                  onPressed: _editItem,
                                  color: CupertinoColors.label.resolveFrom(context),
                                ),
                                _ActionButton(
                                  icon: CupertinoIcons.sparkles,
                                  label: _isExtractingText ? 'Reading...' : 'Magic Read',
                                  onPressed: _isExtractingText ? () {} : _extractText,
                                  color: CupertinoColors.systemOrange,
                                  isLoading: _isExtractingText,
                                ),
                                _ActionButton(
                                  icon: CupertinoIcons.arrowshape_turn_up_right_circle_fill,
                                  label: 'Share',
                                  onPressed: _shareItem,
                                  color: CupertinoColors.activeBlue,
                                ),
                                _ActionButton(
                                  icon: CupertinoIcons.trash_circle_fill,
                                  label: 'Delete',
                                  onPressed: _deleteItem,
                                  color: CupertinoColors.destructiveRed,
                                ),
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

          // Custom Header
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10 * _headerOpacity, sigmaY: 10 * _headerOpacity),
                child: Container(
                  padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
                  color: (isDark ? CupertinoColors.black : CupertinoColors.white).withOpacity(_headerOpacity.clamp(0, 0.8)),
                  child: SizedBox(
                    height: 60,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          CupertinoButton(
                            padding: EdgeInsets.zero,
                            onPressed: () => Navigator.pop(context),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: CupertinoColors.black.withOpacity(0.3),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(CupertinoIcons.back, color: CupertinoColors.white, size: 22),
                            ),
                          ),
                          Opacity(
                            opacity: _headerOpacity,
                            child: Text(
                              'Capture Details',
                              style: TextStyle(
                                color: CupertinoColors.label.resolveFrom(context),
                                fontWeight: FontWeight.w700,
                                fontSize: 18,
                                letterSpacing: -0.5,
                              ),
                            ),
                          ),
                          CupertinoButton(
                            padding: EdgeInsets.zero,
                            onPressed: () async {
                              setState(() {
                                _currentItem.isFavorite = !_currentItem.isFavorite;
                              });
                              await DatabaseService.addItem(_currentItem);
                            },
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: CupertinoColors.black.withOpacity(0.3),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                _currentItem.isFavorite ? CupertinoIcons.heart_fill : CupertinoIcons.heart,
                                color: _currentItem.isFavorite ? CupertinoColors.systemRed : CupertinoColors.white,
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
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final Color color;
  final bool isLoading;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    required this.color,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: isLoading ? null : onPressed,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  color.withOpacity(0.2),
                  color.withOpacity(0.05),
                ],
              ),
              shape: BoxShape.circle,
              border: Border.all(
                color: color.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: isLoading 
              ? const SizedBox(
                  width: 28,
                  height: 28,
                  child: CupertinoActivityIndicator(radius: 10),
                )
              : Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: color.withOpacity(0.9),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
