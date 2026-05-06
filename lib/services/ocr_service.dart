import 'dart:io';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class OCRService {
  static TextRecognizer? _textRecognizer;
  
  static TextRecognizer get _recognizer {
    _textRecognizer ??= TextRecognizer();
    return _textRecognizer!;
  }

  static Future<String> extractText(String imagePath) async {
    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final RecognizedText recognizedText = await _recognizer.processImage(inputImage);
      
      return _smartClean(recognizedText.text);
    } catch (e) {
      print('OCR Error: $e');
      return '';
    }
  }

  static String _smartClean(String text) {
    if (text.isEmpty) return '';

    // 1. Common UI words that often appear as noise in screenshots
    final noiseWords = {'done', 'cancel', 'edit', 'search', 'back', 'reply', 'send', 'typing...', 'online'};

    // 2. Filter out common system noise like Time (e.g., 10:30 AM) and Battery (e.g., 85%)
    String cleaned = text.replaceAll(RegExp(r'\d{1,2}:\d{2}(\s?[APMapm]{2})?'), '');
    cleaned = cleaned.replaceAll(RegExp(r'\d{1,3}%'), '');
    
    // 3. Clean up per-line
    List<String> lines = cleaned.split('\n');
    List<String> usefulLines = [];
    
    for (var line in lines) {
      String trimmed = line.trim();
      String lower = trimmed.toLowerCase();
      
      // Filter out noise words and very short artifacts
      if (trimmed.length > 2 && !noiseWords.contains(lower)) {
        usefulLines.add(trimmed);
      }
    }

    // 4. Join back with newlines
    return usefulLines.join('\n').trim();
  }

  static void dispose() {
    _textRecognizer?.close();
    _textRecognizer = null;
  }
}
