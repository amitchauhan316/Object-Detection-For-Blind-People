import 'package:flutter/foundation.dart';
import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  // 🔴 Android Emulator માટે
  static const String baseUrl = "http://10.13.51.11:8000";

  // ============================
  // 1️⃣ CHECK BACKEND STATUS
  // ============================
  static Future<Map<String, dynamic>> checkServer() async {
    final response = await http.get(Uri.parse("$baseUrl/"));

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception("Backend not reachable");
    }
  }

  // ============================
  // 2️⃣ IMAGE DETECTION API
  // ============================
  static Future<Map<String, dynamic>> sendImage(File imageFile) async {
    var request = http.MultipartRequest(
      'POST',
      Uri.parse("$baseUrl/detect"),
    );

    request.files.add(
      await http.MultipartFile.fromPath(
        'file',
        imageFile.path,
      ),
    );

    var response = await request.send();
    final responseBody = await response.stream.bytesToString();

    if (response.statusCode == 200) {
      return jsonDecode(responseBody);
    } else {
      throw Exception("Image upload failed");
    }
  }
// ============================
// MANUAL CAPTURE DETECTION
// ============================
  static Future<Map<String, dynamic>> captureDetect(File imageFile, String type) async {

    var request = http.MultipartRequest(
      'POST',
      Uri.parse("$baseUrl/capture-detect/$type"), // ⭐ VERY IMPORTANT
    );

    request.files.add(
      await http.MultipartFile.fromPath(
        'file',
        imageFile.path,
      ),
    );

    var response = await request.send();
    final responseBody = await response.stream.bytesToString();

    if (response.statusCode == 200) {
      return jsonDecode(responseBody);
    } else {
      throw Exception("Capture detection failed");
    }
  }

  // ============================
  // 3️⃣ AI ASSISTANT CHAT
  // ============================
  static Future<String> sendChatMessage(String message) async {
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/assistant/chat"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"message": message}),
      ).timeout(const Duration(seconds: 20));

      debugPrint("STATUS: ${response.statusCode}");
      debugPrint("BODY: ${response.body}");

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data["reply"] ?? "No reply";
      } else {
        throw Exception("Server error ${response.statusCode}");
      }

    } catch (e) {
      debugPrint("API ERROR: $e");
      rethrow;
    }
  }

  // ============================
  // 3.5️⃣ AI ASSISTANT COMMAND ROUTER
  // ============================
  static Future<Map<String, dynamic>> sendCommandToBackend(String message) async {
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/assistant/command"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"message": message}),
      ).timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception("Server error ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("API ERROR: $e");
      return {"action": "error", "reply": "Failed to connect to backend"};
    }
  }


  // ============================
  // 4️⃣ FETCH HISTORY / LOGS
  // ============================
  static Future<List<dynamic>> fetchHistory() async {
    final response = await http.get(Uri.parse("$baseUrl/history"));

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception("Failed to load history");
    }
  }

  // ============================
  // 5️⃣ CLEAR HISTORY
  // ============================
  static Future<void> clearHistory() async {
    final response =
    await http.delete(Uri.parse("$baseUrl/history/clear"));

    if (response.statusCode != 200) {
      throw Exception("Failed to clear history");
    }
  }
}
