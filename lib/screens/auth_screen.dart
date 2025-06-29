import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../screens/home_screen.dart';
import '../utils/snackbar_utils.dart'; // Ensure this is imported for Snackbars

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _isLoading = false;

  Future<void> _signInWithGoogle() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final GoogleSignIn googleSignIn = GoogleSignIn();
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();

      if (googleUser == null) {
        // User cancelled the sign-in flow
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

        AppUser appUser;
        if (!userDoc.exists) {
          // New user: Create a pending user document
          appUser = AppUser(
            uid: firebaseUser.uid,
            email: firebaseUser.email ?? 'no-email@example.com',
            role: UserRole.pending,
            approved: false,
          );
          await userDocRef.set(appUser.toFirestore());
          print('New user document created for ${firebaseUser.email}');
        } else {
          // Existing user: Load their data
          appUser = AppUser.fromFirestore(userDoc);
          print('Existing user signed in: ${firebaseUser.email}');
        }

        // --- Navigation based on approval status ---
        if (mounted) {
          if (appUser.approved) {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(
                builder: (context) => HomeScreen(appUser: appUser),
              ),
              (Route<dynamic> route) => false,
            );
          } else {
            // User is not yet approved
            Navigator.of(context).pushAndRemoveUntil(
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
                            style: TextStyle(fontSize: 18, color: Colors.grey),
                          ),
                          SizedBox(height: 10),
                          Text(
                            'Please wait while an administrator reviews your registration.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 14, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              (Route<dynamic> route) => false,
            );
          }
        }
      }
    } catch (e) {
      print('Error during Google Sign-In: $e');
      if (mounted) {
        SnackBarUtils.showSnackBar(
          context,
          'Failed to sign in with Google: ${e.toString()}',
          isError: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sign In'), centerTitle: true),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Welcome to Substation Manager Pro',
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              _isLoading
                  ? const CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                    )
                  : ElevatedButton.icon(
                      onPressed: _signInWithGoogle,
                      icon: Image.asset(
                        'assets/google_logo.webp',
                        height: 24,
                        width: 24,
                      ),
                      // FIX: Removed Expanded from label
                      label: const Text(
                        'Sign In with Google',
                        overflow: TextOverflow.ellipsis,
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black87,
                        side: BorderSide(color: Colors.grey.shade300),
                        elevation: 3,
                        minimumSize: const Size(250, 50),
                      ),
                    ),
              const SizedBox(height: 20),
              Text(
                'Please sign in to continue. Your account will require admin approval.',
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
