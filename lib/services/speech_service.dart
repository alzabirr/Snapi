import 'package:speech_to_text/speech_to_text.dart' as stt;

class SpeechService {
  static final stt.SpeechToText _speech = stt.SpeechToText();
  static bool _isAvailable = false;

  static Future<void> init() async {
    _isAvailable = await _speech.initialize(
      onStatus: (status) => print('Speech status: $status'),
      onError: (error) => print('Speech error: $error'),
    );
  }

  static bool get isAvailable => _isAvailable;

  static Future<void> startListening(Function(String) onResult) async {
    if (!_isAvailable) return;

    var systemLocale = await _speech.systemLocale();
    var localeId = systemLocale?.localeId ?? 'en_US';

    await _speech.listen(
      onResult: (result) {
        onResult(result.recognizedWords);
      },
      localeId: localeId,
      listenFor: const Duration(seconds: 30),
      cancelOnError: true,
      partialResults: true,
    );
  }

  static Future<void> stopListening() async {
    await _speech.stop();
  }

  static bool get isListening => _speech.isListening;
}
