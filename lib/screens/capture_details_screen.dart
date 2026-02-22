import 'dart:io';
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_tts/flutter_tts.dart';
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

  void _editItem() {
    showCupertinoModalPopup(
      context: context,
      barrierDismissible: false,
      builder: (context) => ScreenshotPopup(
        initialNote: _currentItem.note,
        initialReminder: _currentItem.reminderTime,
        imagePath: _currentItem.path,
        onSave: (note, reminder) async {
          setState(() {
            _currentItem.note = note;
            _currentItem.reminderTime = reminder;
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
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.black,
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
                          boxShadow: [
                            BoxShadow(
                              color: CupertinoColors.activeBlue.withOpacity(0.15),
                              blurRadius: 40,
                              offset: const Offset(0, 10),
                            ),
                            BoxShadow(
                              color: CupertinoColors.black.withOpacity(0.5),
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
                              const Color(0xFF1A1A1A).withOpacity(0.9),
                              const Color(0xFF121212).withOpacity(0.95),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(32),
                          border: Border.all(
                            color: CupertinoColors.white.withOpacity(0.15),
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
                                      color: CupertinoColors.white.withOpacity(0.05),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: CupertinoColors.white.withOpacity(0.1), width: 0.5),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(CupertinoIcons.bell_fill, size: 13, color: CupertinoColors.activeBlue),
                                        const SizedBox(width: 6),
                                        Text(
                                          _currentItem.reminderTime.toString().substring(11, 16),
                                          style: const TextStyle(
                                            fontSize: 13,
                                            color: CupertinoColors.white,
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
                              style: const TextStyle(
                                fontSize: 18,
                                color: CupertinoColors.white,
                                height: 1.6,
                                fontWeight: FontWeight.w400,
                                letterSpacing: 0.2,
                              ),
                            ),
                            const SizedBox(height: 48),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _ActionButton(
                                  icon: CupertinoIcons.pencil_circle_fill,
                                  label: 'Edit',
                                  onPressed: _editItem,
                                  color: CupertinoColors.white,
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
                  color: CupertinoColors.black.withOpacity(_headerOpacity.clamp(0, 0.8)),
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
                            child: const Text(
                              'Capture Details',
                              style: TextStyle(
                                color: CupertinoColors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 18,
                                letterSpacing: -0.5,
                              ),
                            ),
                          ),
                          const SizedBox(width: 44),
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

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onPressed,
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
            child: Icon(icon, color: color, size: 28),
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
