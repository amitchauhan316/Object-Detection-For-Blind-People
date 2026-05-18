import 'package:flutter/foundation.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:capstone/services/voice_service.dart';
import 'package:capstone/utils/voice_command_handler.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:timezone/data/latest.dart' as tzdata;

import 'services/api_service.dart';
import 'services/tts_service.dart';
import 'services/app_prefs.dart';

import 'utils/access_button.dart';
import 'utils/voice_helper.dart';

late List<CameraDescription> cameras;

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<AIVisionScreenState> aiVisionScreenKey = GlobalKey<AIVisionScreenState>();
final GlobalKey<_HomeDetectPageState> homeDetectPageKey = GlobalKey<_HomeDetectPageState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  tzdata.initializeTimeZones();
  cameras = await availableCameras();
  await TtsService.init();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  runApp(const MyApp());
}


class MyApp extends StatefulWidget {
  const MyApp({super.key});

  static MyAppState of(BuildContext context) =>
      context.findAncestorStateOfType<MyAppState>()!;

  @override
  State<MyApp> createState() => MyAppState();
}

class MyAppState extends State<MyApp> {
  ThemeMode themeMode = ThemeMode.dark;

  @override
  void initState() {
    super.initState();
    loadTheme();
  }

  Future<void> loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final isDark = prefs.getBool("isDarkMode") ?? true;

    setState(() {
      themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    });
  }

  Future<void> toggleTheme() async {
    final prefs = await SharedPreferences.getInstance();

    setState(() {
      themeMode = (themeMode == ThemeMode.dark)
          ? ThemeMode.light
          : ThemeMode.dark;
    });

    await prefs.setBool("isDarkMode", themeMode == ThemeMode.dark);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      navigatorObservers: [routeObserver],

      // ✅ Light Theme
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: Colors.white,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Colors.white,
          selectedItemColor: Color(0xFF7C78FF),
          unselectedItemColor: Colors.black54,
        ),
      ),

      // ✅ Dark Theme
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF1E1F22),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1E1F22),
          foregroundColor: Colors.white,
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Color(0xFF1E1F22),
          selectedItemColor: Color(0xFF7C78FF),
          unselectedItemColor: Colors.white70,
        ),
      ),

      builder: (context, child) {
        return GlobalVoiceAssistantOverlay(child: child!);
      },
      home: const SplashScreen(),
    );
  }
}

//////////////////////////////////////////////////////////////
// ✅ SPLASH SCREEN
//////////////////////////////////////////////////////////////
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  double opacity = 0;

  @override
  void initState() {
    super.initState();

    Future.delayed(const Duration(milliseconds: 200), () {
      setState(() => opacity = 1);
    });

    Timer(const Duration(seconds: 3), () {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => AIVisionScreen(key: aiVisionScreenKey)),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF5D67B4),
                  Color(0xFF0B1A5A),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: -80,
            left: -120,
            child: Container(
              width: 350,
              height: 250,
              decoration: BoxDecoration(
                color: const Color(0xFF07124A),
                borderRadius: BorderRadius.circular(200),
              ),
            ),
          ),
          Center(
            child: AnimatedOpacity(
              duration: const Duration(seconds: 1),
              opacity: opacity,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Text(
                    "VISION WALK",
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 1.2,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    "Hello Aarjav",
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

//////////////////////////////////////////////////////////////
// ✅ AI VISION SCREEN (BOTTOM NAV)
//////////////////////////////////////////////////////////////
class AIVisionScreen extends StatefulWidget {
  const AIVisionScreen({super.key});

  @override
  State<AIVisionScreen> createState() => AIVisionScreenState();
}

class AIVisionScreenState extends State<AIVisionScreen> {
  int selectedIndex = 0;

  Future<void> changeTab(int index) async {
    if (selectedIndex == 0 && index != 0) {
      homeDetectPageKey.currentState?.pauseRealtime();
    } else if (selectedIndex != 0 && index == 0) {
      homeDetectPageKey.currentState?.resumeRealtime();
    }

    setState(() => selectedIndex = index);

    const pages = ["Home", "Assistant", "Activity", "Settings"];
    await TtsService.speak("Opened ${pages[index]} page");
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomeDetectPage(key: homeDetectPageKey),
      const AssistantPage(),
      const ActivityPage(),
      const SettingsPage(),
    ];

    return Scaffold(
      body: IndexedStack(
        index: selectedIndex,
        children: pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor:
        Theme.of(context).bottomNavigationBarTheme.backgroundColor,
        selectedItemColor:
        Theme.of(context).bottomNavigationBarTheme.selectedItemColor,
        unselectedItemColor:
        Theme.of(context).bottomNavigationBarTheme.unselectedItemColor,
        type: BottomNavigationBarType.fixed,
        currentIndex: selectedIndex,
        onTap: changeTab,

        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),
          BottomNavigationBarItem(
              icon: Icon(Icons.smart_toy), label: "AI Assistant"),
          BottomNavigationBarItem(
              icon: Icon(Icons.event_note), label: "Activity"),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: "Settings"),
        ],
      ),
    );
  }
}

//////////////////////////////////////////////////////////////
// ✅ HELP PAGE
//////////////////////////////////////////////////////////////
class HelpPage extends StatelessWidget {
  const HelpPage({super.key});

  @override
  Widget build(BuildContext context) {
    final titleColor = Theme.of(context).appBarTheme.foregroundColor;
    final textColor = Theme.of(context).textTheme.bodyLarge?.color;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        elevation: 0,
        title: Text(
          "Help & Instructions",
          style: TextStyle(color: titleColor),
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          _sectionTitle(context, "✅ Quick Start"),
          _infoCard(
            context,
            "1) Open Home screen\n"
                "2) Point camera towards object\n"
                "3) Use Torch if dark\n"
                "4) Switch camera if needed\n"
                "5) Go to AI Assistant for voice help",
          ),
          const SizedBox(height: 14),
          _sectionTitle(context, "📸 Home Screen Controls"),
          _infoCard(
            context,
            "🎥 Camera Preview: shows live view\n"
                "🔄 Switch Camera Button: change front/back camera\n"
                "🔦 Torch Button: ON/OFF flash light\n"
                "📌 Tip: Keep phone steady for best detection",
          ),
          const SizedBox(height: 14),
          _sectionTitle(context, "🧠 AI Assistant (Voice + Chat)"),
          _infoCard(
            context,
            "🎤 Mic Button: Speak your question\n"
                "📩 Send Button: Type and send message\n"
                "🔊 Voice Output: AI can speak answers\n"
                "✅ Example: 'What is in front of me?'",
          ),
          const SizedBox(height: 14),
          _sectionTitle(context, "📅 Activity (Calendar + Tasks)"),
          _infoCard(
            context,
            "📆 Calendar: select a date\n"
                "➕ Add Task: write task and set reminder\n"
                "✅ Checkbox: mark task done\n"
                "🗑 Delete: remove task anytime",
          ),
          const SizedBox(height: 14),
          _sectionTitle(context, "🔍 Detection Pages (Modes)"),
          _infoCard(
            context,
            "Your app also supports these detection modes:\n\n"
                "📝 Text Detection\n"
                "📄 Document Detection\n"
                "💵 Currency Detection\n"
                "🖼 Image Mode",
          ),
          const SizedBox(height: 14),
          _sectionTitle(context, "⚠️ Safety Tips"),
          _infoCard(
            context,
            "✅ Use app in safe place\n"
                "✅ Use earphones for clear voice\n"
                "❌ Do not use while crossing roads\n"
                "✅ Keep brightness medium for battery save",
          ),
          const SizedBox(height: 14),
          Text(
            "If you face any issue, restart the app ✅",
            style: TextStyle(color: textColor),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String text) {
    return Text(
      text,
      style: TextStyle(
        color: Theme.of(context).textTheme.bodyLarge?.color,
        fontSize: 16,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _infoCard(BuildContext context, String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.8),
          fontSize: 14,
          height: 1.4,
        ),
      ),
    );
  }
}

//////////////////////////////////////////////////////////////
// ✅ Drawer Widget
//////////////////////////////////////////////////////////////
class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).textTheme.bodyLarge?.color;
    final iconColor = Theme.of(context).iconTheme.color;

    return Drawer(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      child: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
              decoration: BoxDecoration(
                color: const Color(0xFF0E4D6D),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Row(
                children: [
                  Icon(Icons.visibility, color: Colors.white),
                  SizedBox(width: 12),
                  Text(
                    "VisionWalk",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            drawerItem(context, Icons.text_fields, "Text Detection",
                const TextDetectionPage(), iconColor, textColor),
            drawerItem(context, Icons.description, "Document Detection",
                const DocumentDetectionPage(), iconColor, textColor),
            drawerItem(context, Icons.currency_exchange, "Currency Detection",
                const CurrencyDetectionPage(), iconColor, textColor),
            drawerItem(context, Icons.image_outlined, "Image Detection",
                const ImageDetectionPage(), iconColor, textColor),
            Divider(color: Colors.grey.withValues(alpha: 0.3)),
            drawerItem(context, Icons.help_outline, "Help & Instructions",
                const HelpPage(), iconColor, textColor),
          ],
        ),
      ),
    );
  }

  Widget drawerItem(BuildContext context, IconData icon, String title,
      Widget page, Color? iconColor, Color? textColor) {
    return ListTile(
      leading: Icon(icon, color: iconColor),
      title: Text(title, style: TextStyle(color: textColor)),
      onTap: () async {
        await VoiceHelper.speakAction(title); // 🔊 added
        if (!context.mounted) return;
        Navigator.pop(context);
        Navigator.push(context, MaterialPageRoute(builder: (_) => page));
      },
    );
  }
}

//////////////////////////////////////////////////////////////
// ✅ Activity Storage
//////////////////////////////////////////////////////////////
class ActivityStorage {
  static const String key = "activity_list";

  static Future<void> addActivity(String objectName) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(key) ?? [];

    final data = {"object": objectName, "time": DateTime.now().toString()};

    list.insert(0, jsonEncode(data));
    await prefs.setStringList(key, list);
  }

  static Future<List<Map<String, dynamic>>> getActivities() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(key) ?? [];
    return list.map((e) => jsonDecode(e) as Map<String, dynamic>).toList();
  }
}

/////////////////////////////////////////////////////////////
// ✅ HOME CAMERA PAGE
//////////////////////////////////////////////////////////////
class HomeDetectPage extends StatefulWidget {
  const HomeDetectPage({super.key});

  @override
  State<HomeDetectPage> createState() => _HomeDetectPageState();
}

class _HomeDetectPageState extends State<HomeDetectPage> with RouteAware {
  CameraController? _controller;
  Future<void>? _initializeControllerFuture;

  int cameraIndex = 0;
  bool isTorchOn = false;
  Timer? detectionTimer;
  bool isDetecting = false;
  bool _isRealtimeRunning = false;
  String lastSpokenObject = "";
  String detectedText = "Scanning...";   // ⭐⭐⭐ STATE VARIABLE

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeCameraAndRealtime();
    });

    // 🎤 Set up callbacks
    _setupVoiceCommandCallbacks();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute) {
      routeObserver.subscribe(this, route);
    }
  }

  @override
  void didPushNext() {
    pauseRealtime();
  }

  @override
  void didPopNext() {
    if (mounted && aiVisionScreenKey.currentState?.selectedIndex == 0) {
      resumeRealtime();
    }
  }

  void startRealtimeDetection() {
    if (_isRealtimeRunning || _controller == null || !_controller!.value.isInitialized) return;
    detectionTimer?.cancel();
    detectionTimer = Timer.periodic(
      const Duration(seconds: 2),
          (_) => captureFrameRealtime(),
    );
    _isRealtimeRunning = true;
  }

  void stopRealtimeDetection() {
    detectionTimer?.cancel();
    detectionTimer = null;
    _isRealtimeRunning = false;
  }

  void pauseRealtime() {
    stopRealtimeDetection();
  }

  Future<void> _initializeCameraAndRealtime() async {
    await initCamera(cameraIndex);
    startRealtimeDetection();
  }

  void resumeRealtime() {
    if (!mounted) return;
    startRealtimeDetection();
  }

  /// Setup voice command callbacks for different actions
  void _setupVoiceCommandCallbacks() {
    VoiceCommandHandler.onToggleTorch = toggleTorch;
    VoiceCommandHandler.onSwitchCamera = switchCamera;
    VoiceCommandHandler.onCapture = captureFrameRealtime;
    VoiceCommandHandler.onDescribe = () async {
      await TtsService.speak("Current detection: $detectedText");
    };
  }

  Future<void> toggleTorch() async {
    if (_controller == null) return;

    try {
      if (isTorchOn) {
        await _controller!.setFlashMode(FlashMode.off);
      } else {
        await _controller!.setFlashMode(FlashMode.torch);
      }

      setState(() {
        isTorchOn = !isTorchOn;
      });

      // 🔊 GLOBAL TTS (respects language + voice enabled)
      await VoiceHelper.speakAction(
        isTorchOn ? "Torch on" : "Torch off",
      );

    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Torch not supported on this device")),
      );

      await VoiceHelper.speakAction("Torch not supported");
    }
  }


  Future<void> initCamera(int index) async {
    await _controller?.dispose();

    _controller = CameraController(
      cameras[index],
      ResolutionPreset.medium,
      enableAudio: false,
    );

    try {
      _initializeControllerFuture = _controller!.initialize();
      await _initializeControllerFuture;
    } catch (e) {
      debugPrint('Camera initialization failed: $e');
      _initializeControllerFuture = null;
      return;
    }

    if (mounted) setState(() {});
  }

  Future<void> switchCamera() async {
    if (cameras.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No second camera found")),
      );
      return;
    }

    cameraIndex = (cameraIndex == 0) ? 1 : 0;
    await initCamera(cameraIndex);
    await VoiceHelper.speakAction("Camera switched");
  }

  Future<void> captureFrameRealtime() async {

    if (_controller == null || !_controller!.value.isInitialized || isDetecting || _controller!.value.isTakingPicture) return;

    try {
      isDetecting = true;

      if (_initializeControllerFuture != null) {
        await _initializeControllerFuture;
      }

      if (_controller == null || !_controller!.value.isInitialized) return;

      final picture = await _controller!.takePicture();

      final result =
      await ApiService.sendImage(File(picture.path));

      /// ⭐ USE THIS IF BACKEND RETURNS top_object
      final detectedObject =
          result["top_object"] ?? "Nothing";

      if (detectedObject != lastSpokenObject) {

        lastSpokenObject = detectedObject;

        /// ⭐ UPDATE UI
        setState(() {
          detectedText = "Detected: $detectedObject";
        });

        /// ⭐ SPEAK
        await TtsService.speak(
          "Detected $detectedObject",
        );
      }

    } on CameraException catch (e) {
      debugPrint("Realtime CameraException: ${e.code} ${e.description}");
      await initCamera(cameraIndex);
    } catch (e) {
      debugPrint("Realtime detection error: $e");
    } finally {
      isDetecting = false;
    }
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    stopRealtimeDetection();
    _controller?.dispose();
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    final iconColor = Theme.of(context).iconTheme.color;
    final titleColor = Theme.of(context).appBarTheme.foregroundColor;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      drawer: const AppDrawer(),
      appBar: AppBar(
        elevation: 0,
        leading: Builder(
          builder: (context) => IconButton(
            icon: Icon(Icons.menu, color: iconColor),
            onPressed: () {
              Scaffold.of(context).openDrawer();
            },
          ),
        ),
        title: Text(
          "AI Vision",
          style: TextStyle(color: titleColor, fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.help_outline, color: iconColor),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const HelpPage()),
              );
            },
          ),
        ],
      ),
      body: FutureBuilder(
        future: _initializeControllerFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            return Stack(
              children: [
                Positioned.fill(child: CameraPreview(_controller!)),
                Positioned.fill(child: Container(color: Colors.black.withAlpha(115))),

                // TORCH BUTTON
                Positioned(
                  bottom: 90,
                  right: 20,
                  child: AccessButton(
                    label: isTorchOn ? "Torch off" : "Torch on",
                    onPressed: toggleTorch,
                    child: FloatingActionButton(
                      backgroundColor:
                      isTorchOn ? Colors.orange : const Color(0xFF7C78FF),
                      onPressed: null,
                      child: Icon(
                        isTorchOn ? Icons.flash_on : Icons.flash_off,
                        color: Colors.white,
                      ),
                    ),
                  ),

                ),

                // SWITCH CAMERA BUTTON
                Positioned(
                  bottom: 20,
                  right: 20,
                  child: AccessButton(
                    label: "Switch camera",
                    onPressed: switchCamera,
                    child: FloatingActionButton(
                      backgroundColor: const Color(0xFF7C78FF),
                      onPressed: null,
                      child: const Icon(Icons.cameraswitch, color: Colors.white),
                    ),
                  ),

                ),

                /// 🔥 REALTIME DETECT TEXT
                Positioned(
                  bottom: 140,
                  left: 20,
                  right: 20,
                  child: Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      detectedText,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

              ],
            );
          } else {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF7C78FF)),
            );
          }
        },
      ),
    );
  }
}

class CapturedPreviewPage extends StatefulWidget {
  final String imagePath;
  final String type;
  const CapturedPreviewPage({super.key, required this.imagePath, required Map<String, dynamic> result, required this.type});

  @override
  State<CapturedPreviewPage> createState() => _CapturedPreviewPageState();
}

class _CapturedPreviewPageState extends State<CapturedPreviewPage> {
  String? detectionResult;
  bool isDetecting = true;

  @override
  void initState() {
    super.initState();
    _detectImage();
  }

  String _getResultObject(Map<String, dynamic> result) {
    return result["object"]?.toString() ??
        result["prediction"]?.toString() ??
        result["label"]?.toString() ??
        "Unknown";
  }

  Future<void> _detectImage() async {
    try {
      final result = await ApiService.captureDetect(File(widget.imagePath), widget.type);
      final String detectedObject = _getResultObject(result);

      await ActivityStorage.addActivity(detectedObject);
      await TtsService.speak("Detected $detectedObject");

      if (mounted) {
        setState(() {
          detectionResult = "Detected: $detectedObject";
          isDetecting = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Detected: $detectedObject")),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          detectionResult = "Detection failed ❌";
          isDetecting = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Detection failed ❌")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text("Captured Image"),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          Center(
            child: Image.file(
              File(widget.imagePath),
              fit: BoxFit.contain,
            ),
          ),
          if (isDetecting)
            const Center(
              child: CircularProgressIndicator(color: Color(0xFF7C78FF)),
            ),
          if (!isDetecting && detectionResult != null)
            Positioned(
              bottom: 40,
              left: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  detectionResult!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
//////////////////////////////////////////////////////////////
// ✅ CAMERA TEMPLATE PAGE
//////////////////////////////////////////////////////////////
class CameraDetectionTemplatePage extends StatefulWidget {
  final String title;
  final String subtitle;
  final String type;

  const CameraDetectionTemplatePage({
    super.key,
    required this.title,
    required this.subtitle,
    required this.type,
  });

  @override
  State<CameraDetectionTemplatePage> createState() =>
      _CameraDetectionTemplatePageState();
}

class _CameraDetectionTemplatePageState
    extends State<CameraDetectionTemplatePage> {
  CameraController? _controller;
  Future<void>? _initializeControllerFuture;

  int cameraIndex = 0;
  bool isTorchOn = false;

  @override
  void initState() {
    super.initState();
    initCamera(cameraIndex);

    VoiceCommandHandler.onToggleTorch = toggleTorch;
    VoiceCommandHandler.onSwitchCamera = switchCamera;
    VoiceCommandHandler.onCapture = captureFrame;
  }

  Future<void> initCamera(int index) async {
    await _controller?.dispose();

    _controller = CameraController(
      cameras[index],
      ResolutionPreset.medium,
      enableAudio: false,
    );

    try {
      _initializeControllerFuture = _controller!.initialize();
      await _initializeControllerFuture;
    } catch (e) {
      debugPrint('Camera initialization failed: $e');
      _initializeControllerFuture = null;
      return;
    }

    if (mounted) setState(() {});
  }

  Future<void> switchCamera() async {
    if (cameras.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No second camera found")),
      );
      return;
    }

    cameraIndex = (cameraIndex == 0) ? 1 : 0;
    await initCamera(cameraIndex);
  }

  Future<void> toggleTorch() async {
    if (_controller == null) return;

    try {
      if (isTorchOn) {
        await _controller!.setFlashMode(FlashMode.off);
      } else {
        await _controller!.setFlashMode(FlashMode.torch);
      }

      setState(() {
        isTorchOn = !isTorchOn;
      });

      // 🔊 Speak AFTER state change
      await TtsService.speak(
        isTorchOn ? "Torch on" : "Torch off",
      );

    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Torch not supported on this device")),
      );

      await TtsService.speak("Torch not supported on this device");
    }
  }


  String _getResultObject(Map<String, dynamic> result) {
    return result["object"]?.toString() ??
        result["prediction"]?.toString() ??
        result["label"]?.toString() ??
        "Unknown";
  }

  Future<void> captureFrame() async {
    if (_controller == null || !_controller!.value.isInitialized || _controller!.value.isTakingPicture) return;

    try {
      if (_initializeControllerFuture != null) {
        await _initializeControllerFuture;
      }

      if (!mounted || _controller == null || !_controller!.value.isInitialized) return;

      final picture = await _controller!.takePicture();

      if (!mounted) return;

      // 🔥 API CALL HERE
      final result = await ApiService.captureDetect(
        File(picture.path),
        widget.type, // 🔥 THIS IS THE MAGIC
      );

      print("Detection Result: $result");

      final detectedObject = _getResultObject(result);

      // 👉 Optional: TTS for blind users
      await TtsService.speak(
        "Detected $detectedObject",
      );

      if (!mounted) return;
      final navigator = Navigator.of(context);
      navigator.push(
        MaterialPageRoute(
          builder: (_) => CapturedPreviewPage(
            imagePath: picture.path,
            result: result,
            type: widget.type, // 🔥 pass result
          ),
        ),
      );

    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Capture failed ❌")),
      );
    }
  }

  @override
  void dispose() {
    VoiceCommandHandler.onToggleTorch = null;
    VoiceCommandHandler.onSwitchCamera = null;
    VoiceCommandHandler.onCapture = null;
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final titleColor = Theme.of(context).appBarTheme.foregroundColor;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        elevation: 0,
        title: Text(widget.title, style: TextStyle(color: titleColor)),
        centerTitle: true,
      ),
      body: FutureBuilder(
        future: _initializeControllerFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            return Stack(
              children: [
                Positioned.fill(child: CameraPreview(_controller!)),
                Positioned.fill(child: Container(color: Colors.black.withAlpha(115))),

                Positioned(
                  top: 20,
                  left: 16,
                  right: 16,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white10,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Text(
                      widget.subtitle,
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ),
                ),

                // 📸 Capture Button (BOTTOM CENTER)
                Positioned(
                  bottom: 20,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: AccessButton(
                      label: "Capture image",
                      onPressed: captureFrame,
                      child: FloatingActionButton(
                        backgroundColor: const Color(0xFF7C78FF),
                        onPressed: captureFrame,
                        child: const Icon(Icons.camera_alt, color: Colors.white),
                      ),
                    ),

                  ),
                ),


                Positioned(
                  bottom: 90,
                  right: 20,
                  child: AccessButton(
                    label: isTorchOn ? "Torch off" : "Torch on",
                    onPressed: toggleTorch,
                    child: FloatingActionButton(
                      backgroundColor:
                      isTorchOn ? Colors.orange : const Color(0xFF7C78FF),
                      onPressed: null,
                      child: Icon(
                        isTorchOn ? Icons.flash_on : Icons.flash_off,
                        color: Colors.white,
                      ),
                    ),
                  ),


                ),

                Positioned(
                  bottom: 20,
                  right: 20,
                  child: AccessButton(
                    label: "Switch camera",
                    onPressed: switchCamera,
                    child: FloatingActionButton(
                      backgroundColor: const Color(0xFF7C78FF),
                      onPressed: null,
                      child: const Icon(Icons.cameraswitch, color: Colors.white),
                    ),
                  ),

                ),
              ],
            );
          }

          return const Center(
            child: CircularProgressIndicator(color: Color(0xFF7C78FF)),
          );
        },
      ),
    );
  }
}

//////////////////////////////////////////////////////////////
// ✅ DETECTION PAGES
//////////////////////////////////////////////////////////////
class TextDetectionPage extends StatelessWidget {
  const TextDetectionPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const CameraDetectionTemplatePage(
      title: "Text Detection",
      subtitle: "Point camera at text (book/board) to read it.",
      type: "text",
    );
  }
}

class DocumentDetectionPage extends StatelessWidget {
  const DocumentDetectionPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const CameraDetectionTemplatePage(
      title: "Document Detection",
      subtitle: "Keep document flat and capture properly.",
      type: "document",
    );
  }
}

class CurrencyDetectionPage extends StatelessWidget {
  const CurrencyDetectionPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const CameraDetectionTemplatePage(
      title: "Currency Detection",
      subtitle: "Point camera at currency note for value detection.",
      type: "currency",
    );
  }
}



class ImageDetectionPage extends StatelessWidget {
  const ImageDetectionPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const CameraDetectionTemplatePage(
      title: "Image Detection",
      subtitle: "Point camera at image to understand content.",
      type: "image",
    );
  }
}

final RouteObserver<ModalRoute<void>> routeObserver =
RouteObserver<ModalRoute<void>>();

mixin SpeakOnPageOpen<T extends StatefulWidget> on State<T>
implements RouteAware {

  String get pageName;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context)!);
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  // ✅ REQUIRED IMPLEMENTATIONS (EMPTY BUT VALID)

  @override
  void didPush() {
    TtsService.speak("Opened $pageName page");
  }

  @override
  void didPop() {}

  @override
  void didPopNext() {
    TtsService.speak("Back to $pageName page");
  }

  @override
  void didPushNext() {}
}
//////////////////////////////////////////////////////////////
// ✅ AI ASSISTANT PAGE (Same Feature)
//////////////////////////////////////////////////////////////
class AssistantPage extends StatefulWidget {
  const AssistantPage({super.key});

  @override
  State<AssistantPage> createState() => _AssistantPageState();
}

class _AssistantPageState extends State<AssistantPage> with SpeakOnPageOpen
{
  @override
  String get pageName => "AI Assistant";
  final TextEditingController controller = TextEditingController();
  List<Map<String, String>> messages = [];
  bool isLoading = false;


  void sendMessage() async {
    final text = controller.text.trim();
    if (text.isEmpty) return;

    setState(() {
      messages.add({"role": "user", "text": text});
      controller.clear();
      isLoading = true;
    });

    try {
      final reply = await ApiService.sendChatMessage(text);

      setState(() {
        messages.add({"role": "ai", "text": reply});
        isLoading = false;
      });

      // 🔊 SPEAK AI RESPONSE
      await TtsService.speak(reply);

    } catch (e) {
      setState(() {
        messages.add({
          "role": "ai",
          "text": "Backend not responding ❌"
        });
        isLoading = false;
      });

      // 🔊 SPEAK ERROR
      await TtsService.speak("Backend not responding");
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final titleColor = Theme.of(context).appBarTheme.foregroundColor;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        elevation: 0,
        title: Text("AI Assistant", style: TextStyle(color: titleColor)),
        centerTitle: true,
      ),
      body: Column(
        children: [
          if (isLoading)
            const LinearProgressIndicator(color: Color(0xFF7C78FF)),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: messages.length,
              itemBuilder: (context, index) {
                final msg = messages[index];
                final isUser = msg["role"] == "user";

                return Align(
                  alignment:
                  isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    constraints: const BoxConstraints(maxWidth: 280),
                    decoration: BoxDecoration(
                      color: isUser
                          ? const Color(0xFF7C78FF)
                          : const Color(0xFF2B2C31),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isUser ? "You" : "AI Assistant",
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          msg["text"] ?? "",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              color: Color(0xFF1E1F22),
              border: Border(top: BorderSide(color: Colors.white12)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.white10,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: TextField(
                      controller: controller,
                      enabled: !isLoading,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        hintText: "Type your query or instruction...",
                        hintStyle: TextStyle(color: Colors.white54),
                        border: InputBorder.none,
                      ),
                      onSubmitted: (_) => sendMessage(),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                CircleAvatar(
                  radius: 22,
                  backgroundColor: const Color(0xFF7C78FF),
                  child: AccessButton(
                    label: "Microphone",
                    onPressed: () async {
                      bool available = await VoiceService.init();
                      debugPrint("Speech available: $available");

                      if (available) {
                        await VoiceService.startListening((command) async {
                          await VoiceCommandHandler.handle(command);
                          //await VoiceService.stopListening();
                        });
                      }
                    },
                    child: IconButton(
                      onPressed: null,
                      icon: const Icon(Icons.mic, color: Colors.white),
                    ),
                  ),

                ),
                const SizedBox(width: 10),
                CircleAvatar(
                  radius: 22,
                  backgroundColor: isLoading ? Colors.grey : Colors.white10,
                  child: AccessButton(
                    label: "Send message",
                    onPressed: isLoading ? null : sendMessage,
                    child: IconButton(
                      onPressed: null,
                      icon: isLoading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.send, color: Colors.white),
                    ),
                  ),

                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}


//////////////////////////////////////////////////////////////
// ✅ Calendar Storage (Same Feature)
//////////////////////////////////////////////////////////////
class CalendarTaskStorage {
  static const String key = "calendar_tasks";

  static String _dateKey(DateTime date) {
    return "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
  }

  static Future<Map<String, dynamic>> _loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key);
    if (raw == null) return {};
    return jsonDecode(raw);
  }

  static Future<void> addTask({
    required DateTime date,
    required String task,
    DateTime? reminderTime,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final all = await _loadAll();

    final dKey = _dateKey(date);
    all[dKey] = all[dKey] ?? [];

    all[dKey].add({
      "title": task,
      "done": false,
      "reminder": reminderTime?.toString(),
    });

    await prefs.setString(key, jsonEncode(all));
  }

  static Future<List<Map<String, dynamic>>> getTasks(DateTime date) async {
    final all = await _loadAll();
    final dKey = _dateKey(date);
    if (all[dKey] == null) return [];
    return List<Map<String, dynamic>>.from(all[dKey]);
  }

  static Future<void> toggleDone(DateTime date, int index, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    final all = await _loadAll();

    final dKey = _dateKey(date);
    if (all[dKey] == null) return;

    all[dKey][index]["done"] = value;

    await prefs.setString(key, jsonEncode(all));
  }

  static Future<void> deleteTask(DateTime date, int index) async {
    final prefs = await SharedPreferences.getInstance();
    final all = await _loadAll();

    final dKey = _dateKey(date);
    if (all[dKey] == null) return;

    all[dKey].removeAt(index);

    await prefs.setString(key, jsonEncode(all));
  }
}

//////////////////////////////////////////////////////////////
// ✅ ACTIVITY PAGE (Same Feature)
//////////////////////////////////////////////////////////////
class ActivityPage extends StatefulWidget {
  const ActivityPage({super.key});

  @override
  State<ActivityPage> createState() => _ActivityPageState();
}

class _ActivityPageState extends State<ActivityPage> {
  DateTime selectedDay = DateTime.now();
  DateTime focusedDay = DateTime.now();

  List<Map<String, dynamic>> tasks = [];
  List<Map<String, dynamic>> detectedHistory = [];

  final TextEditingController taskController = TextEditingController();

  @override
  void initState() {
    super.initState();
    loadAll();
  }

  @override
  void dispose() {
    taskController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    loadAll();
  }


  Future<void> loadAll() async {
    tasks = await CalendarTaskStorage.getTasks(selectedDay);
    detectedHistory = await ActivityStorage.getActivities();
    setState(() {});
  }

  Future<void> addTaskWithReminder() async {
    final text = taskController.text.trim();
    if (text.isEmpty) return;

    TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );

    DateTime? reminderDateTime;
    if (pickedTime != null) {
      reminderDateTime = DateTime(
        selectedDay.year,
        selectedDay.month,
        selectedDay.day,
        pickedTime.hour,
        pickedTime.minute,
      );
    }

    await CalendarTaskStorage.addTask(
      date: selectedDay,
      task: text,
      reminderTime: reminderDateTime,
    );

    taskController.clear();
    await loadAll();
    await TtsService.speak(
      "Task added on ${selectedDay.day}/${selectedDay.month} at "
          "${pickedTime?.hour}:${pickedTime?.minute}. Task is $text",
    );

  }

  String formatTime(String time) {
    final dt = DateTime.tryParse(time);
    if (dt == null) return time;

    final h = dt.hour > 12 ? dt.hour - 12 : dt.hour;
    final hour = h == 0 ? 12 : h;
    final min = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour >= 12 ? "PM" : "AM";
    return "$hour:$min $ampm";
  }

  @override
  Widget build(BuildContext context) {
    final titleColor = Theme.of(context).appBarTheme.foregroundColor;
    final iconColor = Theme.of(context).iconTheme.color;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        elevation: 0,
        title: Text("Activity", style: TextStyle(color: titleColor)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: iconColor),
            onPressed: loadAll,
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
                  ),
                  child: TableCalendar(
                    firstDay: DateTime.utc(2020, 1, 1),
                    lastDay: DateTime.utc(2035, 12, 31),
                    focusedDay: focusedDay,
                    selectedDayPredicate: (day) => isSameDay(selectedDay, day),
                    onDaySelected: (selected, focused) async {
                      setState(() {
                        selectedDay = selected;
                        focusedDay = focused;
                      });
                      await loadAll();
                    },
                    calendarStyle: const CalendarStyle(
                      todayDecoration: BoxDecoration(
                        color: Color(0xFF7C78FF),
                        shape: BoxShape.circle,
                      ),
                      selectedDecoration: BoxDecoration(
                        color: Colors.deepPurple,
                        shape: BoxShape.circle,
                      ),
                    ),
                    headerStyle: const HeaderStyle(
                      formatButtonVisible: false,
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Detected Objects History 👁️",
                        style: TextStyle(
                          color: Theme.of(context).textTheme.bodyLarge?.color,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 60,
                        child: detectedHistory.isEmpty
                            ? Text(
                          "No detected history yet...",
                          style: TextStyle(
                            color: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.color
                                ?.withValues(alpha: 0.7),
                          ),
                        )
                            : ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: detectedHistory.length > 10
                              ? 10
                              : detectedHistory.length,
                          itemBuilder: (context, index) {
                            final item = detectedHistory[index];
                            return Container(
                              margin: const EdgeInsets.only(right: 10),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF444469),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Column(
                                mainAxisAlignment:
                                MainAxisAlignment.center,
                                children: [
                                  Text(
                                    "${item["object"]}",
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    formatTime(item["time"]),
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: taskController,
                        decoration: InputDecoration(
                          hintText: "Add task for the day...",
                          filled: true,
                          fillColor: Theme.of(context)
                              .cardColor
                              .withValues(alpha: 0.08),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    AccessButton(
                      label: "Add task",
                      onPressed: addTaskWithReminder,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF7C78FF),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: null,
                        child: const Icon(Icons.alarm_add),
                      ),
                    ),

                  ],
                ),

                const SizedBox(height: 12),

                SizedBox(
                  height: 320,
                  child: tasks.isEmpty
                      ? Text(
                    "No tasks for this day ✅",
                    style: TextStyle(
                      color: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.color
                          ?.withValues(alpha: 0.8),
                    ),
                  )
                      : ListView.builder(
                    itemCount: tasks.length,
                    itemBuilder: (context, index) {
                      final item = tasks[index];
                      final bool done = item["done"] ?? false;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .cardColor
                              .withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                              color: Colors.grey.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            Checkbox(
                              value: done,
                              activeColor: const Color(0xFF7C78FF),
                              onChanged: (val) async {
                                await CalendarTaskStorage.toggleDone(
                                  selectedDay,
                                  index,
                                  val ?? false,
                                );
                                await loadAll();
                              },
                            ),
                            Expanded(
                              child: Text(
                                "${item["title"]}",
                                style: TextStyle(
                                  color: Theme.of(context)
                                      .textTheme
                                      .bodyLarge
                                      ?.color,
                                  fontSize: 16,
                                  decoration: done
                                      ? TextDecoration.lineThrough
                                      : TextDecoration.none,
                                ),
                              ),
                            ),
                            AccessButton(
                              label: "Delete task",
                              onPressed: () async {
                                await CalendarTaskStorage.deleteTask(selectedDay, index);
                                await loadAll();
                              },
                              child: const Icon(Icons.delete, color: Colors.redAccent),
                            ),

                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

//////////////////////////////////////////////////////////////
// ✅ SETTINGS PAGE (Only Theme Switch Same Feature)
//////////////////////////////////////////////////////////////
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool voiceOutput = true;
  bool vibrationAlert = true;

  // ✅ NEW: Selected Language
  String selectedLanguage = "English";

  @override
  void initState() {
    super.initState();
    loadLanguage();
  }

  Future<void> loadLanguage() async {
    selectedLanguage = await AppPrefs.getLanguage();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final appState = MyApp.of(context);
    final bool isDark = appState.themeMode == ThemeMode.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text("Settings"),
        centerTitle: true,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(isDark ? Icons.dark_mode : Icons.light_mode),
                    const SizedBox(width: 10),
                    Text(
                      isDark ? "Dark Mode" : "Light Mode",
                      style: const TextStyle(fontSize: 16),
                    ),
                  ],
                ),
                Switch(
                  value: isDark,
                  onChanged: (val) async {
                    await appState.toggleTheme();
                    await TtsService.speak(
                      val ? "Dark mode enabled" : "Light mode enabled",
                    );
                  },

                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          _settingSwitchTile(
            icon: Icons.volume_up,
            title: "Voice Output",
            subtitle: voiceOutput ? "ON" : "OFF",
            value: voiceOutput,
            onChanged: (val) async {
              setState(() => voiceOutput = val);
              await AppPrefs.setVoiceEnabled(val);

              await TtsService.speak(
                val ? "Voice output enabled" : "Voice output disabled",
              );
            },

          ),

          _settingSwitchTile(
            icon: Icons.vibration,
            title: "Vibration Alert",
            subtitle: vibrationAlert ? "ON" : "OFF",
            value: vibrationAlert,
            onChanged: (val) async {
              setState(() => vibrationAlert = val);
              await VoiceHelper.speakAction(val ? "Vibration on" : "Vibration off");

              await TtsService.speak(
                val ? "Vibration On" : "Vibration Off",
              );
            },

          ),

          const SizedBox(height: 14),

          _settingButtonTile(
            icon: Icons.text_increase,
            title: "Text Size",
            subtitle: "Medium",
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Text Size option coming soon ✅")),
              );
            },
          ),

          // ✅ UPDATED: Voice Language Dropdown inside tile
          _settingButtonTile(
            icon: Icons.record_voice_over,
            title: "Voice Language",
            subtitle: selectedLanguage,
            onTap: () {}, // no need tap
            trailing: DropdownButton<String>(
              value: selectedLanguage,
              underline: const SizedBox(),
              items: const [
                DropdownMenuItem(value: "English", child: Text("English")),
                DropdownMenuItem(value: "Hindi", child: Text("Hindi")),
                DropdownMenuItem(value: "Gujarati", child: Text("Gujarati")),
              ],
              onChanged: (val) async {
                if (val == null) return;

                setState(() => selectedLanguage = val);
                await TtsService.changeLanguage(val);

                await TtsService.speak(
                  val == "Hindi"
                      ? "भाषा बदल दी गई है"
                      : val == "Gujarati"
                      ? "ભાષા બદલાઈ ગઈ છે"
                      : "Language changed successfully",
                );
              },


            ),
          ),

          _settingButtonTile(
            icon: Icons.security,
            title: "Privacy & Permissions",
            subtitle: "Camera, Mic",
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Permissions page coming soon ✅")),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _settingSwitchTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required Function(bool) onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 16)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: const TextStyle(color: Colors.grey)),
                ],
              ),
            ],
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }

  // ✅ UPDATED: trailing optional added
  Widget _settingButtonTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Widget? trailing,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(icon),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 16)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: const TextStyle(color: Colors.grey)),
                  ],
                ),
              ],
            ),

            // ✅ if dropdown exists show it, else show arrow
            trailing ?? const Icon(Icons.arrow_forward_ios, size: 16),
          ],
        ),
      ),
    );
  }
}

//////////////////////////////////////////////////////////////
// ✅ GLOBAL VOICE ASSISTANT OVERLAY
//////////////////////////////////////////////////////////////
class GlobalVoiceAssistantOverlay extends StatefulWidget {
  final Widget child;

  const GlobalVoiceAssistantOverlay({super.key, required this.child});

  @override
  State<GlobalVoiceAssistantOverlay> createState() =>
      _GlobalVoiceAssistantOverlayState();
}

class _GlobalVoiceAssistantOverlayState
    extends State<GlobalVoiceAssistantOverlay> {
  // 🎤 Voice Recognition Variables
  bool isListening = false;
  String recognizedText = "";
  String listeningStatus = "Starting microphone...";
  Timer? _commandTimer;

  @override
  void initState() {
    super.initState();
    _initializeVoiceService();
    VoiceCommandHandler.onNavigate = navigateToPage;
  }

  Future<void> navigateToPage(String pageName) async {
    final navContext = navigatorKey.currentContext;
    if (navContext == null) return;

    // Pop any pushed routes until we are at first route (AIVisionScreen)
    Navigator.popUntil(navContext, (route) => route.isFirst);

    if (pageName == "home") {
      aiVisionScreenKey.currentState?.changeTab(0);
    } else if (pageName == "assistant") {
      aiVisionScreenKey.currentState?.changeTab(1);
    } else if (pageName == "activity") {
      aiVisionScreenKey.currentState?.changeTab(2);
    } else if (pageName == "settings") {
      aiVisionScreenKey.currentState?.changeTab(3);
    } else if (pageName == "text_detection") {
      Navigator.push(navContext, MaterialPageRoute(builder: (_) => const TextDetectionPage()));
    } else if (pageName == "document_detection") {
      Navigator.push(navContext, MaterialPageRoute(builder: (_) => const DocumentDetectionPage()));
    } else if (pageName == "currency_detection") {
      Navigator.push(navContext, MaterialPageRoute(builder: (_) => const CurrencyDetectionPage()));
    } else if (pageName == "image_detection") {
      Navigator.push(navContext, MaterialPageRoute(builder: (_) => const ImageDetectionPage()));
    } else if (pageName == "help") {
      Navigator.push(navContext, MaterialPageRoute(builder: (_) => const HelpPage()));
    }
  }

  Future<void> _initializeVoiceService() async {
    await VoiceService.init();
    startVoiceRecognition();
  }

  Future<void> startVoiceRecognition() async {
    if (isListening) return;

    if (mounted) {
      setState(() {
        isListening = true;
        recognizedText = "";
        listeningStatus = "Listening continuously...";
      });
    }

    await VoiceService.startListening(
      (result) {
        if (mounted) {
          setState(() {
            recognizedText = result;
            listeningStatus = "Heard: $result";
          });
        }

        // Debounce command processing
        _commandTimer?.cancel();
        _commandTimer = Timer(const Duration(milliseconds: 1500), () async {
          if (recognizedText.isNotEmpty) {
            final command = recognizedText;
            if (mounted) {
              setState(() { recognizedText = ""; });
            }
            await VoiceCommandHandler.handle(command);

            if (mounted && isListening) {
              setState(() {
                listeningStatus = "Listening continuously...";
              });
            }
          }
        });
      },
      onError: (error) {
        if (mounted) {
          setState(() {
            listeningStatus = "Error: $error. Restarting...";
          });
        }
      },
    );
  }

  Future<void> stopVoiceRecognition() async {
    await VoiceService.stopListening();
    if (mounted) {
      setState(() {
        isListening = false;
        listeningStatus = "Tap microphone to speak";
      });
    }
  }

  @override
  void dispose() {
    _commandTimer?.cancel();
    VoiceService.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,

        // 🎤 VOICE STATUS DISPLAY (Top)
        if (isListening)
          Positioned(
            top: MediaQuery.of(context).padding.top + 20,
            left: 20,
            right: 20,
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Text(
                      listeningStatus,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (recognizedText.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        "You said: $recognizedText",
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),

        // 🎤 MICROPHONE BUTTON (Left side)
        Positioned(
          bottom: 90,
          left: 20,
          child: Material(
            color: Colors.transparent,
            child: AccessButton(
              label: isListening ? "Stop listening" : "Speak command",
              onPressed:
                  isListening ? stopVoiceRecognition : startVoiceRecognition,
              child: FloatingActionButton(
                heroTag: "global_mic_btn",
                backgroundColor: isListening ? Colors.red : Colors.green,
                onPressed: null,
                child: Icon(
                  isListening ? Icons.mic : Icons.mic_none,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
