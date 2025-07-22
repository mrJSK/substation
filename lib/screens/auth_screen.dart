// lib/screens/auth_screen.dart
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../screens/admin/admin_dashboard_screen.dart';
import '../screens/substation_user_dashboard_screen.dart';
import 'subdivision_dashboard_tabs/subdivision_dashboard_screen.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});
  static const String routeName = '/auth';

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen>
    with SingleTickerProviderStateMixin {
  bool _isLoading = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _signInWithGoogle() async {
    if (_isLoading) return; // Prevent multiple sign-in attempts

    setState(() {
      _isLoading = true;
    });

    try {
      final GoogleSignIn googleSignIn = GoogleSignIn();
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();

      if (googleUser == null) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential = await FirebaseAuth.instance
          .signInWithCredential(credential);
      final User? firebaseUser = userCredential.user;

      if (firebaseUser != null) {
        final userDocRef = FirebaseFirestore.instance
            .collection('users')
            .doc(firebaseUser.uid);
        final userDoc = await userDocRef.get();

        if (!userDoc.exists) {
          final newUser = AppUser(
            uid: firebaseUser.uid,
            email: firebaseUser.email ?? 'no-email@example.com',
            role: UserRole.pending,
            approved: false,
          );
          await userDocRef.set(newUser.toFirestore());
          print('New user document created for ${firebaseUser.email}');
          _showSnackBar('Account created. Awaiting admin approval.');
        } else {
          print('Existing user signed in: ${firebaseUser.email}');
          final appUser = AppUser.fromFirestore(userDoc);
          if (appUser.approved) {
            if (context.mounted) {
              if (appUser.role == UserRole.admin) {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (context) =>
                        AdminDashboardScreen(adminUser: appUser),
                  ),
                );
              } else if (appUser.role == UserRole.substationUser) {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (context) =>
                        SubstationUserDashboardScreen(currentUser: appUser),
                  ),
                );
              } else if (appUser.role == UserRole.subdivisionManager) {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (context) =>
                        SubdivisionDashboardScreen(currentUser: appUser),
                  ),
                );
              } else {
                _showSnackBar('Unsupported user role.', isError: true);
              }
            }
          } else {
            _showSnackBar(
              'Your account is pending admin approval.',
              isError: true,
            );
          }
        }
      }
    } catch (e) {
      print('Error during Google Sign-In: $e');
      if (context.mounted) {
        _showSnackBar(
          'Failed to sign in with Google: ${e.toString()}',
          isError: true,
        );
      }
    } finally {
      if (context.mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.w500,
          ),
        ),
        backgroundColor: isError
            ? Theme.of(context).colorScheme.errorContainer
            : Theme.of(context).colorScheme.primaryContainer,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        elevation: 4,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context).colorScheme.primary.withOpacity(0.1),
              Theme.of(context).colorScheme.secondary.withOpacity(0.1),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: 24.0,
                vertical: 16.0,
              ),
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Card(
                  elevation: 8,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // App Logo
                        Image.asset(
                          'assets/logo.png', // Replace with your app logo
                          height: 80,
                          width: 80,
                          semanticLabel: 'App Logo',
                        ),
                        const SizedBox(height: 24),
                        // Title
                        Text(
                          'Substation Manager Pro',
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        // Subtitle
                        Text(
                          'Sign in to manage your substations efficiently',
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w400,
                              ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 40),
                        // Sign-In Button
                        AnimatedScale(
                          scale: _isLoading ? 0.95 : 1.0,
                          duration: const Duration(milliseconds: 200),
                          child: ElevatedButton.icon(
                            onPressed: _isLoading ? null : _signInWithGoogle,
                            icon: Image.asset(
                              'assets/google_logo.webp',
                              height: 24,
                              width: 24,
                              semanticLabel: 'Google Logo',
                            ),
                            label: const Text(
                              'Sign in with Google',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.black87,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                              minimumSize: const Size(280, 56),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              side: BorderSide(color: Colors.grey.shade300),
                              elevation: 4,
                              shadowColor: Colors.black.withOpacity(0.2),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        // Info Text
                        Text(
                          'Your account requires admin approval to access the dashboard.',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant.withOpacity(0.7),
                                fontSize: 14,
                              ),
                          textAlign: TextAlign.center,
                        ),
                        if (_isLoading) ...[
                          const SizedBox(height: 24),
                          CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
