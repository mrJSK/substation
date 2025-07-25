// lib/main.dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';

import '../firebase_options.dart'; // Ensure this path is correct
import '../models/app_state_data.dart';
import '../screens/auth_screen.dart';
import '../screens/home_screen.dart'; // This will be the new routing screen
import '../screens/splash_screen.dart'; // The initial splash screen

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Initialize Firebase once at the application start
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(
    // Provide AppStateData globally
    ChangeNotifierProvider(
      create: (context) => AppStateData(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  // Define your color scheme constants here
  static const Color primaryBlue = Color(0xFF0D6EFD);
  static const Color secondaryGreen = Color(0xFF28A745);
  static const Color tertiaryYellow = Color(0xFFFFC107);
  static const Color errorRed = Color(0xFFDC3545);

  @override
  Widget build(BuildContext context) {
    // Access AppStateData to react to theme changes and initialization status
    final appStateData = Provider.of<AppStateData>(context);

    return MaterialApp(
      title: 'Substation Manager Pro',
      debugShowCheckedModeBanner: false,
      // Define light theme
      theme: ThemeData(
        brightness: Brightness.light,
        colorScheme: ColorScheme.fromSeed(
          seedColor: primaryBlue,
          primary: primaryBlue,
          onPrimary: Colors.white,
          secondary: secondaryGreen,
          onSecondary: Colors.white,
          tertiary: tertiaryYellow,
          onTertiary: Colors.black87,
          surface: Colors.white,
          onSurface: Colors.black87,
          background: Colors.white,
          onBackground: Colors.black87,
          error: errorRed,
          onError: Colors.white,
          brightness: Brightness.light,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: primaryBlue,
          foregroundColor: Colors.white,
          elevation: 4.0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
            fontFamily: 'Inter',
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryBlue,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            elevation: 4,
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              fontFamily: 'Inter',
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: primaryBlue.withOpacity(0.05),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: primaryBlue, width: 2),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(
              color: primaryBlue.withOpacity(0.3),
              width: 1,
            ),
          ),
          labelStyle: TextStyle(color: primaryBlue.withOpacity(0.8)),
          hintStyle: TextStyle(color: Colors.grey.shade600),
          prefixIconColor: primaryBlue,
          contentPadding: const EdgeInsets.symmetric(
            vertical: 16,
            horizontal: 16,
          ),
        ),
        cardTheme: CardThemeData(
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: Colors.white,
        ),
        progressIndicatorTheme: ProgressIndicatorThemeData(
          color: primaryBlue,
          linearTrackColor: primaryBlue.withOpacity(0.2),
        ),
        textTheme: const TextTheme(
          headlineSmall: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.black87,
            fontSize: 24,
          ),
          titleMedium: TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.black87,
            fontSize: 18,
          ),
          bodyLarge: TextStyle(fontSize: 16.0, color: Colors.black87),
          bodyMedium: TextStyle(fontSize: 14.0, color: Colors.black54),
          bodySmall: TextStyle(fontSize: 12.0, color: Colors.black45),
          labelLarge: TextStyle(
            fontSize: 16.0,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ).apply(fontFamily: 'Inter'),
        bottomNavigationBarTheme: BottomNavigationBarThemeData(
          selectedItemColor: primaryBlue,
          unselectedItemColor: Colors.grey.shade600,
          backgroundColor: Colors.white,
          type: BottomNavigationBarType.fixed,
          selectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            fontFamily: 'Inter',
          ),
          unselectedLabelStyle: const TextStyle(fontFamily: 'Inter'),
        ),
        iconTheme: const IconThemeData(color: primaryBlue),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: primaryBlue,
          foregroundColor: Colors.white,
          elevation: 6,
        ),
        dividerTheme: DividerThemeData(
          color: Colors.grey.shade200,
          space: 1,
          thickness: 1,
        ),
        scaffoldBackgroundColor: Colors.white,
      ),
      // Define dark theme
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: primaryBlue,
          primary: primaryBlue,
          onPrimary: Colors.black,
          secondary: Colors.cyan,
          onSecondary: Colors.white,
          tertiary: Colors.orange,
          onTertiary: Colors.black87,
          surface: Colors.grey.shade900,
          onSurface: Colors.white,
          background: Colors.black,
          onBackground: Colors.white,
          error: errorRed,
          onError: Colors.white,
          brightness: Brightness.dark,
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.grey.shade900,
          foregroundColor: Colors.white,
          elevation: 4.0,
          centerTitle: true,
          titleTextStyle: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
            fontFamily: 'Inter',
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryBlue,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            elevation: 4,
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              fontFamily: 'Inter',
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.grey.shade800,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: primaryBlue, width: 2),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(
              color: primaryBlue.withOpacity(0.3),
              width: 1,
            ),
          ),
          labelStyle: TextStyle(color: Colors.white.withOpacity(0.8)),
          hintStyle: TextStyle(color: Colors.grey.shade400),
          prefixIconColor: primaryBlue,
          contentPadding: const EdgeInsets.symmetric(
            vertical: 16,
            horizontal: 16,
          ),
        ),
        cardTheme: CardThemeData(
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: Colors.grey.shade800,
        ),
        progressIndicatorTheme: ProgressIndicatorThemeData(
          color: primaryBlue,
          linearTrackColor: primaryBlue.withOpacity(0.2),
        ),
        textTheme: TextTheme(
          headlineSmall: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontSize: 24,
          ),
          titleMedium: TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.white,
            fontSize: 18,
          ),
          bodyLarge: const TextStyle(fontSize: 16.0, color: Colors.white),
          bodyMedium: TextStyle(fontSize: 14.0, color: Colors.white70),
          bodySmall: TextStyle(fontSize: 12.0, color: Colors.white54),
          labelLarge: const TextStyle(
            fontSize: 16.0,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ).apply(fontFamily: 'Inter'),
        bottomNavigationBarTheme: BottomNavigationBarThemeData(
          selectedItemColor: primaryBlue,
          unselectedItemColor: Colors.grey.shade400,
          backgroundColor: Colors.grey.shade900,
          type: BottomNavigationBarType.fixed,
          selectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            fontFamily: 'Inter',
          ),
          unselectedLabelStyle: const TextStyle(fontFamily: 'Inter'),
        ),
        iconTheme: const IconThemeData(color: primaryBlue),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: primaryBlue,
          foregroundColor: Colors.white,
          elevation: 6,
        ),
        dividerTheme: DividerThemeData(
          color: Colors.grey.shade700,
          space: 1,
          thickness: 1,
        ),
        scaffoldBackgroundColor: Colors.black,
      ),
      themeMode: appStateData.themeMode, // Use themeMode from AppStateData
      // Use a FutureBuilder to wait for AppStateData to be initialized
      home: FutureBuilder(
        // The future to await is the initialization of AppStateData
        // We'll expose a Future from AppStateData for this purpose
        future: appStateData.isInitialized
            ? Future.value(true)
            : null, // Only run if not already initialized
        builder: (context, snapshot) {
          // If AppStateData is still loading, show the SplashScreen
          if (!appStateData.isInitialized) {
            return const SplashScreen();
          }
          // Once AppStateData is initialized, HomeRouter handles further routing
          return const HomeRouter();
        },
      ),
    );
  }
}
