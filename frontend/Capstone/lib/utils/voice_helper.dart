import '../services/tts_service.dart';

class VoiceHelper {
  static Future<void> speakAction(String text) async {
    await TtsService.speak(text);
  }

  static Future<void> speakPage(String page) async {
    await TtsService.speak("Opened $page page");
  }

  static Future<void> speakButton(String label) async {
    await TtsService.speak("$label pressed");
  }

  static Future<void> speakToggle(String label, bool value) async {
    await TtsService.speak(
      value ? "$label enabled" : "$label disabled",
    );
  }
}
