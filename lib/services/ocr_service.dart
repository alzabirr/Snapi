import 'dart:io';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class OCRService {
  static final TextRecognizer _textRecognizer = TextRecognizer();

  static Future<String> extractText(String imagePath) async {
    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final RecognizedText recognizedText = await _textRecognizer.processImage(inputImage);
      
      String text = recognizedText.text;
      
      // Clean up text: remove extra newlines and spaces
      text = text.replaceAll('\n', ' ').trim();
      
      return text;
    } catch (e) {
      print('OCR Error: $e');
      return '';
    }
  }

  static void dispose() {
    _textRecognizer.close();
  }
}
