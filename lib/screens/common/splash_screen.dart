import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;
import '../../models/app_state_data.dart';
import 'home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  bool _hasNavigated = false;
  late AnimationController _fadeController;
  late AnimationController _scaleController;
  late AnimationController _rotationController;
  late AnimationController _textController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotationAnimation;
  late Animation<double> _textFadeAnimation;
  late Animation<Offset> _textSlideAnimation;

  @override
  void initState() {
    super.initState();

    // Initialize animation controllers
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _rotationController = AnimationController(
      duration: const Duration(milliseconds: 3000),
      vsync: this,
    );

    _textController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    // Setup animations
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _fadeController,
        curve: const Interval(0.0, 0.8, curve: Curves.easeOut),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.elasticOut),
    );

    _rotationAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _rotationController, curve: Curves.linear),
    );

    _textFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _textController,
        curve: const Interval(0.3, 1.0, curve: Curves.easeOut),
      ),
    );

    _textSlideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.5), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _textController,
            curve: const Interval(0.3, 1.0, curve: Curves.easeOut),
          ),
        );

    // Start animations sequence
    _startAnimations();

    // Navigate after 4 seconds
    Future.delayed(const Duration(seconds: 4), () {
      _navigateToNextScreen();
    });
  }

  void _startAnimations() async {
    // Start logo animations
    _fadeController.forward();
    await Future.delayed(const Duration(milliseconds: 300));
    _scaleController.forward();

    // Start continuous rotation
    _rotationController.repeat();

    // Start text animation after logo settles
    await Future.delayed(const Duration(milliseconds: 800));
    _textController.forward();
  }

  void _navigateToNextScreen() async {
    if (!mounted || _hasNavigated) return;
    _hasNavigated = true;

    // Wait for AppStateData to be initialized
    final appStateData = context.read<AppStateData>();

    // Wait up to 5 seconds for initialization to complete
    final startTime = DateTime.now();
    while (!appStateData.isInitialized &&
        DateTime.now().difference(startTime).inSeconds < 5) {
      await Future.delayed(const Duration(milliseconds: 100));
    }

    // Navigate to HomeRouter
    if (mounted) {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              const HomeRouter(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position:
                    Tween<Offset>(
                      begin: const Offset(1.0, 0.0),
                      end: Offset.zero,
                    ).animate(
                      CurvedAnimation(
                        parent: animation,
                        curve: Curves.easeInOut,
                      ),
                    ),
                child: child,
              ),
            );
          },
          transitionDuration: const Duration(milliseconds: 700),
        ),
      );
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _scaleController.dispose();
    _rotationController.dispose();
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          // Enhanced radial gradient matching your logo's background
          gradient: RadialGradient(
            center: Alignment.center,
            radius: 1.5,
            colors: [
              Color(0xFF2B2B52), // Deep purple center
              Color(0xFF1E1E3F), // Dark blue-purple
              Color(0xFF16213E), // Navy blue
              Color(0xFF0F1B2D), // Deep navy
              Color(0xFF0A0A0A), // Almost black
            ],
            stops: [0.0, 0.3, 0.6, 0.8, 1.0],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              // Animated background particles (optional)
              ...List.generate(
                6,
                (index) => AnimatedBuilder(
                  animation: _rotationAnimation,
                  builder: (context, child) {
                    return Positioned(
                      left:
                          size.width * 0.1 +
                          (size.width * 0.8) *
                              math.sin(
                                _rotationAnimation.value * 2 * math.pi + index,
                              ),
                      top:
                          size.height * 0.2 +
                          (size.height * 0.6) *
                              math.cos(
                                _rotationAnimation.value * 2 * math.pi + index,
                              ),
                      child: FadeTransition(
                        opacity: _fadeAnimation,
                        child: Container(
                          width: 4,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.amber.withOpacity(0.6),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.amber.withOpacity(0.3),
                                blurRadius: 8,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

              // Main content
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Logo section
                    Expanded(
                      flex: 3,
                      child: Center(
                        child: AnimatedBuilder(
                          animation: Listenable.merge([
                            _fadeAnimation,
                            _scaleAnimation,
                            _rotationAnimation,
                          ]),
                          builder: (context, child) {
                            return FadeTransition(
                              opacity: _fadeAnimation,
                              child: Transform.scale(
                                scale: _scaleAnimation.value,
                                child: Container(
                                  width: 220,
                                  height: 220,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.amber.withOpacity(0.4),
                                        blurRadius: 40,
                                        spreadRadius: 10,
                                      ),
                                      BoxShadow(
                                        color: Colors.blue.withOpacity(0.3),
                                        blurRadius: 60,
                                        spreadRadius: 15,
                                      ),
                                      BoxShadow(
                                        color: Colors.purple.withOpacity(0.2),
                                        blurRadius: 80,
                                        spreadRadius: 20,
                                      ),
                                    ],
                                  ),
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      // Outer rotating ring
                                      Transform.rotate(
                                        angle:
                                            _rotationAnimation.value *
                                            2 *
                                            math.pi,
                                        child: Container(
                                          width: 200,
                                          height: 200,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            gradient: SweepGradient(
                                              colors: [
                                                Colors.amber.withOpacity(0.8),
                                                Colors.orange.withOpacity(0.6),
                                                Colors.blue.withOpacity(0.7),
                                                Colors.cyan.withOpacity(0.5),
                                                Colors.purple.withOpacity(0.4),
                                                Colors.amber.withOpacity(0.8),
                                              ],
                                              stops: const [
                                                0.0,
                                                0.2,
                                                0.4,
                                                0.6,
                                                0.8,
                                                1.0,
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),

                                      // Inner rotating ring (counter-rotation)
                                      Transform.rotate(
                                        angle:
                                            -_rotationAnimation.value *
                                            1.5 *
                                            math.pi,
                                        child: Container(
                                          width: 160,
                                          height: 160,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            gradient: SweepGradient(
                                              colors: [
                                                Colors.blue.withOpacity(0.6),
                                                Colors.purple.withOpacity(0.4),
                                                Colors.amber.withOpacity(0.7),
                                                Colors.blue.withOpacity(0.6),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),

                                      // Logo container
                                      Container(
                                        width: 140,
                                        height: 140,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: const Color(
                                            0xFF1A1A2E,
                                          ).withOpacity(0.9),
                                          border: Border.all(
                                            color: Colors.amber.withOpacity(
                                              0.5,
                                            ),
                                            width: 2,
                                          ),
                                        ),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            70,
                                          ),
                                          child: Image.asset(
                                            'assets/logo.png',
                                            width: 100,
                                            height: 100,
                                            fit: BoxFit.contain,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),

                    // Text section
                    Expanded(
                      flex: 1,
                      child: AnimatedBuilder(
                        animation: _textController,
                        builder: (context, child) {
                          return SlideTransition(
                            position: _textSlideAnimation,
                            child: FadeTransition(
                              opacity: _textFadeAnimation,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  // Main Title with enhanced styling
                                  ShaderMask(
                                    shaderCallback: (bounds) =>
                                        const LinearGradient(
                                          colors: [
                                            Colors.amber,
                                            Colors.orange,
                                            Colors.yellow,
                                          ],
                                        ).createShader(bounds),
                                    child: const Text(
                                      'Substation',
                                      style: TextStyle(
                                        fontSize: 42,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                        letterSpacing: 3.0,
                                        shadows: [
                                          Shadow(
                                            color: Colors.amber,
                                            blurRadius: 15,
                                            offset: Offset(0, 3),
                                          ),
                                          Shadow(
                                            color: Colors.orange,
                                            blurRadius: 25,
                                            offset: Offset(0, 6),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 16),

                                  // Subtitle with glow effect
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 24,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(25),
                                      gradient: LinearGradient(
                                        colors: [
                                          Colors.blue.withOpacity(0.2),
                                          Colors.purple.withOpacity(0.1),
                                        ],
                                      ),
                                      border: Border.all(
                                        color: Colors.blue.withOpacity(0.3),
                                        width: 1,
                                      ),
                                    ),
                                    child: Text(
                                      'Smart Substation Management App',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.white.withOpacity(0.9),
                                        letterSpacing: 1.0,
                                        shadows: [
                                          Shadow(
                                            color: Colors.blue.withOpacity(0.5),
                                            blurRadius: 8,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                  const SizedBox(height: 32),

                                  // Enhanced loading indicator
                                  Container(
                                    width: 50,
                                    height: 50,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: RadialGradient(
                                        colors: [
                                          Colors.amber.withOpacity(0.3),
                                          Colors.transparent,
                                        ],
                                      ),
                                    ),
                                    child: const CircularProgressIndicator(
                                      valueColor: AlwaysStoppedAnimation(
                                        Colors.amber,
                                      ),
                                      strokeWidth: 4,
                                      backgroundColor: Colors.transparent,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
