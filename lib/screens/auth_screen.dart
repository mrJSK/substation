import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../screens/home_screen.dart';

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
        } else {
          print('Existing user signed in: ${firebaseUser.email}');
        }
      }
    } catch (e) {
      print('Error during Google Sign-In: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to sign in with Google: ${e.toString()}'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
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
                        'assets/google_logo.webp', // --- FIXED: Changed to .webp ---
                        height: 24,
                        width: 24,
                      ),
                      label: const Expanded(
                        // --- FIXED: Wrapped Text with Expanded ---
                        child: Text(
                          'Sign In with Google',
                          overflow:
                              TextOverflow.ellipsis, // Add overflow handling
                        ),
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
