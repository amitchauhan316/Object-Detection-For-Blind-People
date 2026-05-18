import 'package:flutter_tts/flutter_tts.dart';
import 'app_prefs.dart';

class TtsService {
  static final FlutterTts _tts = FlutterTts();
  static String _currentLang = "en-IN";

  static Future<void> init() async {
    final lang = await AppPrefs.getLanguage();
    _currentLang = _mapLang(lang);

    await _tts.setLanguage(_currentLang);
    await _tts.setSpeechRate(0.45);
    await _tts.setPitch(1.0);
  }

  static Future<void> speak(String text) async {
    final enabled = await AppPrefs.isVoiceEnabled();
    if (!enabled) return;

    await _tts.stop();
    await _tts.speak(text);
  }

  static Future<void> changeLanguage(String lang) async {
    await AppPrefs.setLanguage(lang);
    _currentLang = _mapLang(lang);
    await _tts.setLanguage(_currentLang);
  }

  static String _mapLang(String lang) {
    switch (lang) {
      case "Hindi":
        return "hi-IN";
      case "Gujarati":
        return "gu-IN";
      default:
        return "en-IN";
    }
  }
}
