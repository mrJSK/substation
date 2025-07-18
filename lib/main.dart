// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../firebase_options.dart';

import '../screens/splash_screen.dart';
import '../screens/auth_screen.dart';
import '../screens/home_screen.dart';
import '../models/user_model.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'package:provider/provider.dart';

import '../models/app_state_data.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(
    ChangeNotifierProvider(
      create: (context) => AppStateData(), // Provide AppStateData
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  // Changed to StatefulWidget
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState(); // Create a State
}

class _MyAppState extends State<MyApp> {
  @override
  Widget build(BuildContext context) {
    const Color primaryBlue = Color(0xFF0D6EFD);
    const Color secondaryGreen = Color(0xFF28A745);
    const Color tertiaryYellow = Color(0xFFFFC107);
    const Color errorRed = Color(0xFFDC3545);

    // Listen to AppStateData for theme changes
    final appStateData = Provider.of<AppStateData>(context); //

    return MaterialApp(
      title: 'Substation Manager Pro',
      debugShowCheckedModeBanner: false,
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
      home: const SplashScreen(),
    );
  }
}
