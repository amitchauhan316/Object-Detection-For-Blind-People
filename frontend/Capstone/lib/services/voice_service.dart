import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

class VoiceService {
  static final stt.SpeechToText _speech = stt.SpeechToText();
  static bool _isListening = false;
  static bool _shouldListenContinuously = false;
  static bool _isRestarting = false;
  
  static Function(String)? _onResultCallback;
  static Function(String)? _onErrorCallback;

  /// Initialize speech recognition
  static Future<bool> init() async {
    try {
      return await _speech.initialize(
        onError: (error) {
          debugPrint('Speech recognition error: $error');
          _onErrorCallback?.call(error.errorMsg);
          _handleRestart();
        },
        onStatus: (status) {
          debugPrint('Speech recognition status: $status');
          if (status == 'done' || status == 'notListening') {
            _isListening = false;
            _handleRestart();
          }
        },
      );
    } catch (e) {
      debugPrint('Error initializing speech: $e');
      return false;
    }
  }

  static void _handleRestart() {
    if (_shouldListenContinuously && !_isListening && !_isRestarting) {
      _isRestarting = true;
      Future.delayed(const Duration(milliseconds: 1500), () async {
        if (_shouldListenContinuously && !_isListening) {
          await _startListeningInternal();
        }
        _isRestarting = false;
      });
    }
  }

  /// Start listening to user voice
  static Future<void> startListening(
    Function(String) onResult, {
    Function(String)? onError,
  }) async {
    _onResultCallback = onResult;
    _onErrorCallback = onError;
    _shouldListenContinuously = true;

    if (_isListening) {
      debugPrint('Already listening');
      return;
    }

    await _startListeningInternal();
  }

  static Future<void> _startListeningInternal() async {
    try {
      bool available = await _speech.initialize();

      if (!available) {
        available = await init();
      }

      if (!available) {
        _onErrorCallback?.call('Speech recognition not available');
        return;
      }

      _isListening = true;

      await _speech.listen(
        onResult: (result) {
          if (result.recognizedWords.isNotEmpty) {
             _onResultCallback?.call(result.recognizedWords);
          }
        },
        listenFor: const Duration(hours: 1), 
        pauseFor: const Duration(seconds: 2),
        listenOptions: stt.SpeechListenOptions(partialResults: false),
      );
    } catch (e) {
      debugPrint('Error starting listening: $e');
      _onErrorCallback?.call(e.toString());
      _isListening = false;
      _handleRestart();
    }
  }

  /// Stop listening
  static Future<void> stopListening() async {
    _shouldListenContinuously = false;
    _isRestarting = false;
    try {
      await _speech.stop();
      _isListening = false;
    } catch (e) {
      debugPrint('Error stopping listening: $e');
    }
  }

  /// Check if currently listening
  static bool get isListening => _isListening;

  /// Cancel listening
  static Future<void> cancel() async {
    _shouldListenContinuously = false;
    _isRestarting = false;
    try {
      await _speech.cancel();
      _isListening = false;
    } catch (e) {
      debugPrint('Error canceling listening: $e');
    }
  }
}