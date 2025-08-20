import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:provider/provider.dart';
import '../models/app_state_data.dart';
import '../screens/home_screen.dart'; // Import your home screen

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  late VideoPlayerController _videoController;
  bool _isVideoInitialized = false;
  bool _hasNavigated = false;

  @override
  void initState() {
    super.initState();

    _videoController = VideoPlayerController.asset('assets/video.mp4')
      ..initialize().then((_) {
        if (mounted) {
          setState(() {
            _isVideoInitialized = true;
          });
          _videoController.play();
        }
      });

    // Listen for video completion and navigate
    _videoController.addListener(() {
      if (_videoController.value.isInitialized &&
          !_videoController.value.isPlaying &&
          _videoController.value.position >= _videoController.value.duration &&
          !_hasNavigated) {
        _hasNavigated = true;
        _navigateToNextScreen();
      }
    });
  }

  void _navigateToNextScreen() async {
    if (!mounted) return;

    // Wait for AppStateData to be initialized (same logic as your original FutureBuilder)
    final appStateData = context.read<AppStateData>();

    // Wait up to 5 seconds for initialization to complete
    final startTime = DateTime.now();
    while (!appStateData.isInitialized &&
        DateTime.now().difference(startTime).inSeconds < 5) {
      await Future.delayed(const Duration(milliseconds: 100));
    }

    // Navigate to HomeRouter (same as your original main.dart)
    if (mounted) {
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (_) => const HomeRouter()));
    }
  }

  @override
  void dispose() {
    _videoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: _isVideoInitialized
          ? SizedBox.expand(
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: _videoController.value.size.width,
                  height: _videoController.value.size.height,
                  child: VideoPlayer(_videoController),
                ),
              ),
            )
          : const Center(
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2,
              ),
            ),
    );
  }
}
