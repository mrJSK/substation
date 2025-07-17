// lib/screens/splash_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:provider/provider.dart';

import '../models/app_state_data.dart';
import '../models/user_model.dart';
import '../screens/auth_screen.dart';
import '../screens/home_screen.dart';
import '../utils/snackbar_utils.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeInAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _progressAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    );

    _fadeInAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.6, curve: Curves.easeIn),
      ),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(-1.0, 0.0), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _controller,
            curve: const Interval(0.3, 0.8, curve: Curves.easeOutCubic),
          ),
        );

    _progressAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.7, 1.0, curve: Curves.linear),
      ),
    );

    _controller.forward();

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _initializeAppAndNavigate();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  static List<StateModel> _parseStatesSql(String sqlContent) {
    final List<StateModel> states = [];
    final RegExp regex = RegExp(r"VALUES\s*\(\s*(\d+),\s*'([^']*)'\s*\);");
    final Iterable<RegExpMatch> matches = regex.allMatches(sqlContent);

    for (final match in matches) {
      if (match.group(1) != null && match.group(2) != null) {
        final id = double.parse(match.group(1)!);
        final name = match.group(2)!;
        states.add(StateModel(id: id, name: name));
      }
    }
    return states;
  }

  static List<CityModel> _parseCitiesSql(String sqlContent) {
    final List<CityModel> cities = [];
    final RegExp regex = RegExp(
      r"VALUES\s*\(\s*(\d+),\s*'([^']*)',\s*(\d+)\s*\);",
    );
    final Iterable<RegExpMatch> matches = regex.allMatches(sqlContent);

    for (final match in matches) {
      if (match.group(1) != null &&
          match.group(2) != null &&
          match.group(3) != null) {
        final id = double.parse(match.group(1)!);
        final name = match.group(2)!;
        final stateId = double.parse(match.group(3)!);
        cities.add(CityModel(id: id, name: name, stateId: stateId));
      }
    }
    return cities;
  }

  Future<void> _initializeAppAndNavigate() async {
    try {
      print(
        'DEBUG: SplashScreen: Starting asset data loading for states and cities.',
      );
      final String statesSqlContent = await rootBundle.loadString(
        'assets/state_sql_command.txt',
      );
      final String citiesSqlContent = await rootBundle.loadString(
        'assets/city_sql_command.txt',
      );

      final List<StateModel> loadedStateModels = _parseStatesSql(
        statesSqlContent,
      );
      final List<CityModel> loadedCityModels = _parseCitiesSql(
        citiesSqlContent,
      );

      if (mounted) {
        final appStateData = Provider.of<AppStateData>(context, listen: false);
        appStateData.setAllStateModels(loadedStateModels);
        appStateData.setAllCityModels(loadedCityModels);
        print(
          'DEBUG: SplashScreen: Asset data loading complete for states and cities.',
        );
      }

      final User? user = FirebaseAuth.instance.currentUser;

      if (mounted) {
        if (user == null) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const AuthScreen()),
          );
        } else {
          try {
            final userDoc = await FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .get();
            if (userDoc.exists) {
              final appUser = AppUser.fromFirestore(userDoc);
              if (appUser.approved) {
                if (appUser.role == UserRole.admin) {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (context) => AdminHomeScreen(appUser: appUser),
                    ),
                  );
                } else if (appUser.role == UserRole.substationUser) {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (context) =>
                          SubstationUserHomeScreen(appUser: appUser),
                    ),
                  );
                } else if (appUser.role == UserRole.subdivisionManager) {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (context) =>
                          SubdivisionManagerHomeScreen(appUser: appUser),
                    ),
                  );
                } else {
                  SnackBarUtils.showSnackBar(
                    context,
                    'Unsupported user role.',
                    isError: true,
                  );
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (context) => const AuthScreen()),
                  );
                }
              } else {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (context) => const Scaffold(
                      body: Center(
                        child: Padding(
                          padding: EdgeInsets.all(24.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.hourglass_empty,
                                size: 80,
                                color: Colors.blue,
                              ),
                              SizedBox(height: 20),
                              Text(
                                'Your account is pending approval by an admin.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.grey,
                                ),
                              ),
                              SizedBox(height: 10),
                              Text(
                                'Please wait while an administrator reviews your registration.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }
            } else {
              await FirebaseAuth.instance.signOut();
              await GoogleSignIn().signOut();
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (context) => const AuthScreen()),
              );
            }
          } catch (e) {
            print('Error checking user approval from Splash: $e');
            SnackBarUtils.showSnackBar(
              context,
              'Authentication failed: $e',
              isError: true,
            );
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (context) => const AuthScreen()),
            );
          }
        }
      }
    } catch (e) {
      print("ERROR: SplashScreen: Initialization failed: $e");
      if (mounted) {
        SnackBarUtils.showSnackBar(
          context,
          'App initialization failed: $e',
          isError: true,
        );
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const AuthScreen()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.primary,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SlideTransition(
              position: _slideAnimation,
              child: FadeTransition(
                opacity: _fadeInAnimation,
                child: Icon(
                  Icons.factory,
                  size: 120,
                  color: colorScheme.tertiary,
                ),
              ),
            ),
            const SizedBox(height: 30),
            FadeTransition(
              opacity: _fadeInAnimation,
              child: Text(
                'Substation Manager Pro',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: colorScheme.onPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: 150,
              child: AnimatedBuilder(
                animation: _progressAnimation,
                builder: (context, child) {
                  return LinearProgressIndicator(
                    value: _progressAnimation.value,
                    backgroundColor: colorScheme.onPrimary.withOpacity(0.3),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      colorScheme.onPrimary,
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 10),
            FadeTransition(
              opacity: _fadeInAnimation,
              child: Text(
                'Powering tomorrow...',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: colorScheme.onPrimary.withOpacity(0.8),
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
