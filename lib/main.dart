// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For SystemChrome
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Needed for AppUser.fromFirestore
import 'package:google_sign_in/google_sign_in.dart'; // Needed for signing out
import 'package:provider/provider.dart';

import '../firebase_options.dart';
import '../screens/splash_screen.dart';
import '../screens/auth_screen.dart';
import '../screens/home_screen.dart';
import '../models/user_model.dart';
import '../models/app_state_data.dart'; // Import AppStateData
import '../state_management/sld_editor_state.dart'; // Import SldEditorState

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Initialize Firebase first and foremost
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Optional: Set preferred orientations if your app has specific requirements
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    const Color primaryBlue = Color(0xFF0D6EFD);
    const Color secondaryGreen = Color(0xFF28A745);
    const Color tertiaryYellow = Color(0xFFFFC107);
    const Color errorRed = Color(0xFFDC3545);

    return MultiProvider(
      providers: [
        // 2. Provide AppStateData globally
        ChangeNotifierProvider(create: (ctx) => AppStateData()),
        // 3. Provide SldEditorState globally
        ChangeNotifierProvider(
          create: (ctx) => SldEditorState(substationId: ''),
        ),
      ],
      // Use Consumer to react to AppStateData changes (e.g., themeMode)
      child: Consumer<AppStateData>(
        builder: (context, appState, child) {
          return MaterialApp(
            title: 'Substation Manager Pro',
            debugShowCheckedModeBanner: false,
            themeMode: appState.themeMode, // Use themeMode from AppStateData
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 14,
                  ),
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
                onPrimary: Colors.white,
                secondary: secondaryGreen,
                onSecondary: Colors.white,
                tertiary: tertiaryYellow,
                onTertiary: Colors.black87,
                surface: const Color(0xFF121212), // Darker surface
                onSurface: Colors.white70,
                background: const Color(0xFF121212), // Darker background
                onBackground: Colors.white70,
                error: errorRed,
                onError: Colors.white,
                brightness: Brightness.dark,
              ),
              appBarTheme: const AppBarTheme(
                backgroundColor: Color(0xFF1F1F1F), // Darker app bar
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 14,
                  ),
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
                fillColor:
                    Colors.grey.shade800, // Darker input field background
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
                  borderSide: BorderSide(color: Colors.grey.shade700, width: 1),
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
                color: const Color(0xFF1F1F1F), // Darker card background
              ),
              progressIndicatorTheme: ProgressIndicatorThemeData(
                color: primaryBlue,
                linearTrackColor: primaryBlue.withOpacity(0.2),
              ),
              textTheme: const TextTheme(
                headlineSmall: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white, // White text for dark mode
                  fontSize: 24,
                ),
                titleMedium: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.white70, // Lighter text for titles
                  fontSize: 18,
                ),
                bodyLarge: TextStyle(fontSize: 16.0, color: Colors.white70),
                bodyMedium: TextStyle(fontSize: 14.0, color: Colors.white60),
                bodySmall: TextStyle(fontSize: 12.0, color: Colors.white54),
                labelLarge: TextStyle(
                  fontSize: 16.0,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ).apply(fontFamily: 'Inter'),
              bottomNavigationBarTheme: BottomNavigationBarThemeData(
                selectedItemColor: primaryBlue,
                unselectedItemColor:
                    Colors.grey.shade400, // Lighter unselected icons
                backgroundColor: const Color(0xFF1F1F1F), // Darker background
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
                color: Colors.grey.shade700, // Darker divider
                space: 1,
                thickness: 1,
              ),
              scaffoldBackgroundColor: const Color(
                0xFF121212,
              ), // Dark background
            ),
            // Use StreamBuilder for authentication flow for the home widget
            home: StreamBuilder<User?>(
              stream: FirebaseAuth.instance.authStateChanges(),
              builder: (ctx, userSnapshot) {
                if (userSnapshot.connectionState == ConnectionState.waiting) {
                  return const SplashScreen(); // Show splash while waiting for auth state
                }
                if (userSnapshot.hasData) {
                  // User is logged in, fetch AppUser data from Firestore
                  final firebaseUser = userSnapshot.data!;
                  return FutureBuilder<DocumentSnapshot>(
                    future: FirebaseFirestore.instance
                        .collection('users')
                        .doc(firebaseUser.uid)
                        .get(),
                    builder: (ctx, appUserDocSnapshot) {
                      if (appUserDocSnapshot.connectionState ==
                          ConnectionState.waiting) {
                        return const SplashScreen(); // Show splash while fetching AppUser
                      }
                      if (appUserDocSnapshot.hasData &&
                          appUserDocSnapshot.data!.exists) {
                        final appUser = AppUser.fromFirestore(
                          appUserDocSnapshot.data!,
                        );
                        if (appUser.approved) {
                          return HomeScreen(
                            appUser: appUser,
                          ); // Approved, go to HomeScreen
                        } else {
                          // Authenticated but not approved
                          return const Scaffold(
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
                                      'Your account is pending admin approval.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 18,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }
                      } else {
                        // Firebase user exists but no AppUser doc, or doc doesn't exist
                        // Log out and send to AuthScreen to re-register or correct.
                        FirebaseAuth.instance.signOut();
                        GoogleSignIn()
                            .signOut(); // Also sign out from Google if applicable
                        return AuthScreen(); // Removed const
                      }
                    },
                  );
                }
                // No user signed in, navigate to AuthScreen
                return AuthScreen(); // Removed const
              },
            ),
            // Define named routes. HomeScreen.routeName will be correctly resolved now.
            routes: {
              AuthScreen.routeName: (ctx) => AuthScreen(), // Removed const
              HomeScreen.routeName: (ctx) => HomeScreen(
                // This is a fallback for named route navigation that requires AppUser.
                // It should ideally not be hit for the main login flow.
                appUser: AppUser(
                  uid: '',
                  email: '',
                  role: UserRole.pending,
                  approved: false,
                ),
              ),
              // Add other named routes as needed, e.g.:
              // SubstationDetailScreen.routeName: (ctx) => const SubstationDetailScreen(),
            },
          );
        },
      ),
    );
  }
}
