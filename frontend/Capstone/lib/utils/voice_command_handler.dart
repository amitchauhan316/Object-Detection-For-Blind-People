import 'package:flutter/foundation.dart';
import '../services/tts_service.dart';
import '../services/api_service.dart';

typedef TorchCallback = Future<void> Function();
typedef SwitchCameraCallback = Future<void> Function();
typedef CaptureCallback = Future<void> Function();
typedef DescribeCallback = Future<void> Function();
typedef NavigateCallback = Future<void> Function(String pageName);

class VoiceCommandHandler {
  static TorchCallback? onToggleTorch;
  static SwitchCameraCallback? onSwitchCamera;
  static CaptureCallback? onCapture;
  static DescribeCallback? onDescribe;
  static NavigateCallback? onNavigate;

  static String? _localNavigation(String command) {
    final text = command.toLowerCase();

    if (text.contains("home") || text.contains("ghar") || text.contains("મુખપૃષ્ઠ") || text.contains("home page")) {
      return "navigate_home";
    }
    if (text.contains("assistant") || text.contains("voice") || text.contains("help me") || text.contains("મદદ")) {
      return "navigate_assistant";
    }
    if (text.contains("activity") || text.contains("calendar") || text.contains("note")) {
      return "navigate_activity";
    }
    if (text.contains("setting") || text.contains("settings") || text.contains("પ્રાથમિકતા")) {
      return "navigate_settings";
    }
    if (text.contains("text") || text.contains("read") || text.contains("લખાણ")) {
      return "navigate_text";
    }
    if (text.contains("document") || text.contains("paper") || text.contains("દસ્તાવેજ")) {
      return "navigate_document";
    }
    if (text.contains("currency") || text.contains("note value") || text.contains("રોકડ")) {
      return "navigate_currency";
    }
    if (text.contains("image")) {
      return "navigate_image";
    }
    if (text.contains("help")) {
      return "navigate_help";
    }
    if (text.contains("find") || text.contains("search")) {
      return "navigate_find";
    }
    return null;
  }

  /// Handle voice commands
  /// Handle voice commands using backend Gemini API
  static Future<void> handle(String command) async {
    debugPrint("🎤 Command received: $command");

    command = command.trim();
    if (command.isEmpty) return;
    
    // Call backend API for intent parsing
    final response = await ApiService.sendCommandToBackend(command);
    var action = response["action"] ?? "unknown";
    final reply = response["reply"];

    if (action == "error" || action == "unknown") {
      final fallbackAction = _localNavigation(command);
      if (fallbackAction != null) {
        action = fallbackAction;
        debugPrint("🔁 Fallback local navigation action: $action");
      }
    }

    debugPrint("🧠 AI Action parsed: $action");
    
    try {
      switch (action) {
        case "torch_on":
          await onToggleTorch?.call(); // Toggle handles the physical state 
          // Note: if you specifically only want ON, you might need a separate callback
          // But for now, we'll try turning it "on"/"toggled" and speak explicitly.
          await TtsService.speak("Torch turned on");
          break;
        case "torch_off":
          await onToggleTorch?.call();
          await TtsService.speak("Torch turned off");
          break;
        case "torch_toggle":
          await onToggleTorch?.call();
          await TtsService.speak("Torch toggled");
          break;

        case "camera_switch":
          await onSwitchCamera?.call();
          await TtsService.speak("Camera switched");
          break;

        case "capture":
          await onCapture?.call();
          await TtsService.speak("Image captured");
          break;

        case "describe":
          await onDescribe?.call();
          await TtsService.speak("Describing current view");
          break;

        case "navigate_home":
          await onNavigate?.call("home");
          break;
        case "navigate_assistant":
          await onNavigate?.call("assistant");
          break;
        case "navigate_activity":
          await onNavigate?.call("activity");
          break;
        case "navigate_settings":
          await onNavigate?.call("settings");
          break;
        case "navigate_text":
          await onNavigate?.call("text_detection");
          break;
        case "navigate_document":
          await onNavigate?.call("document_detection");
          break;
        case "navigate_currency":
          await onNavigate?.call("currency_detection");
          break;
        case "navigate_food":
          await onNavigate?.call("food_labels");
          break;
        case "navigate_find":
          await onNavigate?.call("find_mode");
          break;
        case "navigate_image":
          await onNavigate?.call("image_detection");
          break;
        case "navigate_help":
          await onNavigate?.call("help");
          break;

        case "chat":
          if (reply != null) {
            await TtsService.speak(reply);
          }
          break;

        case "error":
        case "unknown":
        default:
          if (reply != null) {
            await TtsService.speak(reply);
          } else {
            await TtsService.speak("Command not recognized. Try saying torch, camera, or open settings.");
          }
          break;
      }
    } catch (e) {
      debugPrint("Error executing command $action: $e");
    }
  }
}