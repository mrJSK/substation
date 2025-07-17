import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:provider/provider.dart';

import '../firebase_options.dart';
import '../screens/splash_screen.dart';
import '../screens/auth_screen.dart';
import '../screens/home_screen.dart';
import '../models/user_model.dart';
import '../models/app_state_data.dart';

final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  runApp(
    MultiProvider(
      providers: [ChangeNotifierProvider(create: (ctx) => AppStateData())],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    const Color primaryBlue = Color(0xFF0D6EFD);
    const Color secondaryGreen = Color(0xFF28A745);
    const Color tertiaryYellow = Color(0xFFFFC107);
    const Color errorRed = Color(0xFFDC3545);

    return Consumer<AppStateData>(
      builder: (context, appState, child) {
        return MaterialApp(
          title: 'Substation Manager Pro',
          debugShowCheckedModeBanner: false,
          themeMode: appState.themeMode,
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
              surface: const Color(0xFF121212),
              onSurface: Colors.white70,
              background: const Color(0xFF121212),
              onBackground: Colors.white70,
              error: errorRed,
              onError: Colors.white,
              brightness: Brightness.dark,
            ),
            appBarTheme: const AppBarTheme(
              backgroundColor: Color(0xFF1F1F1F),
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
              color: const Color(0xFF1F1F1F),
            ),
            progressIndicatorTheme: ProgressIndicatorThemeData(
              color: primaryBlue,
              linearTrackColor: primaryBlue.withOpacity(0.2),
            ),
            textTheme: const TextTheme(
              headlineSmall: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white,
                fontSize: 24,
              ),
              titleMedium: TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.white70,
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
              unselectedItemColor: Colors.grey.shade400,
              backgroundColor: const Color(0xFF1F1F1F),
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
            scaffoldBackgroundColor: const Color(0xFF121212),
          ),
          scaffoldMessengerKey: scaffoldMessengerKey,
          home: StreamBuilder<User?>(
            stream: FirebaseAuth.instance.authStateChanges(),
            builder: (ctx, userSnapshot) {
              if (userSnapshot.connectionState == ConnectionState.waiting) {
                return const SplashScreen();
              }
              if (userSnapshot.hasData) {
                final firebaseUser = userSnapshot.data!;
                return FutureBuilder<DocumentSnapshot>(
                  future: FirebaseFirestore.instance
                      .collection('users')
                      .doc(firebaseUser.uid)
                      .get(),
                  builder: (ctx, appUserDocSnapshot) {
                    if (appUserDocSnapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const SplashScreen();
                    }
                    if (appUserDocSnapshot.hasData &&
                        appUserDocSnapshot.data!.exists) {
                      final appUser = AppUser.fromFirestore(
                        appUserDocSnapshot.data!,
                      );
                      if (appUser.approved) {
                        if (appUser.role == UserRole.admin) {
                          return AdminHomeScreen(appUser: appUser);
                        } else if (appUser.role == UserRole.substationUser) {
                          return SubstationUserHomeScreen(appUser: appUser);
                        } else if (appUser.role ==
                            UserRole.subdivisionManager) {
                          return SubdivisionManagerHomeScreen(appUser: appUser);
                        } else {
                          return const Scaffold(
                            body: Center(child: Text('Unsupported user role.')),
                          );
                        }
                      } else {
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
                      FirebaseAuth.instance.signOut();
                      GoogleSignIn().signOut();
                      return const AuthScreen();
                    }
                  },
                );
              }
              return const AuthScreen();
            },
          ),
          routes: {
            AuthScreen.routeName: (ctx) => const AuthScreen(),
            AdminHomeScreen.routeName: (ctx) => AdminHomeScreen(
              appUser: AppUser(
                uid: '',
                email: '',
                role: UserRole.admin,
                approved: true,
              ),
            ),
            SubstationUserHomeScreen.routeName: (ctx) =>
                SubstationUserHomeScreen(
                  appUser: AppUser(
                    uid: '',
                    email: '',
                    role: UserRole.substationUser,
                    approved: true,
                  ),
                ),
            SubdivisionManagerHomeScreen.routeName: (ctx) =>
                SubdivisionManagerHomeScreen(
                  appUser: AppUser(
                    uid: '',
                    email: '',
                    role: UserRole.subdivisionManager,
                    approved: true,
                  ),
                ),
          },
        );
      },
    );
  }
}
