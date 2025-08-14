import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../services/user_service.dart';
import '../screens/admin/admin_dashboard_screen.dart';
import '../screens/substation_dashboard/substation_user_dashboard_screen.dart';
import '../screens/subdivision_dashboard_tabs/subdivision_dashboard_screen.dart';
import 'user_profile_screen.dart';

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
    if (_isLoading) return;
    setState(() => _isLoading = true);

    try {
      final GoogleSignIn googleSignIn = GoogleSignIn();
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();

      if (googleUser == null) {
        setState(() => _isLoading = false);
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
        await _handleUserDocument(firebaseUser);
      }
    } catch (e) {
      print('Error during Google Sign-In: $e');
      if (context.mounted) {
        _showSnackBar('Failed to sign in: ${e.toString()}', isError: true);
      }
    } finally {
      if (context.mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleUserDocument(User firebaseUser) async {
    try {
      // Check if user document exists
      AppUser? existingUser = await UserService.getUser(firebaseUser.uid);

      if (existingUser == null) {
        // First-time login - Create new user document with basic info
        final newUser = AppUser(
          uid: firebaseUser.uid,
          email: firebaseUser.email ?? 'no-email@example.com',
          name:
              firebaseUser.displayName ??
              '', // Get name from Google if available
          cugNumber: '', // Will be filled in profile
          designation: Designation.technician, // Default designation
          role: UserRole.pending,
          approved: false,
          createdAt: Timestamp.now(),
          profileCompleted: false, // Important: Set to false initially
        );

        await UserService.createUser(newUser);
        print('Created new user document for ${firebaseUser.email}');

        if (context.mounted) {
          _showSnackBar('Welcome! Please complete your profile.');
          // Navigate to profile screen for first-time setup
          _navigateToProfile(newUser);
        }
      } else {
        // Existing user - check profile completion and approval status
        await _handleExistingUser(existingUser);
      }
    } catch (e) {
      print('Error handling user document: $e');
      if (context.mounted) {
        _showSnackBar(
          'Error accessing user profile: ${e.toString()}',
          isError: true,
        );
      }
    }
  }

  Future<void> _handleExistingUser(AppUser existingUser) async {
    if (!context.mounted) return;

    // ✅ FIXED: Check mandatory profile fields completion
    if (!_isMandatoryProfileComplete(existingUser)) {
      _showSnackBar('Please complete your mandatory profile fields.');
      _navigateToProfile(existingUser);
      return;
    }

    // Check if user is approved
    if (!existingUser.approved) {
      _showSnackBar('Your account is pending admin approval.', isError: true);
      return;
    }

    // User is approved and profile is complete - navigate to appropriate dashboard
    await _navigateBasedOnRole(existingUser);
  }

  // ✅ NEW: Method to check if mandatory profile fields are complete
  bool _isMandatoryProfileComplete(AppUser user) {
    // Check all mandatory fields
    final bool hasName = user.name.trim().isNotEmpty;
    final bool hasMobile =
        user.mobile.trim().isNotEmpty && user.mobile.trim().length == 10;
    final bool hasDesignation = user.designation != null;

    print('Profile completion check:');
    print('  - Has name: $hasName (${user.name})');
    print('  - Has mobile: $hasMobile (${user.mobile})');
    print('  - Has designation: $hasDesignation (${user.designation})');
    print('  - Profile completed flag: ${user.profileCompleted}');

    // All mandatory fields must be present AND profileCompleted flag must be true
    return hasName && hasMobile && hasDesignation && user.profileCompleted;
  }

  void _navigateToProfile(AppUser user) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => UserProfileScreen(currentUser: user),
      ),
    );
  }

  Future<void> _navigateBasedOnRole(AppUser appUser) async {
    if (!context.mounted) return;

    Widget destinationScreen;

    switch (appUser.role) {
      case UserRole.admin:
      case UserRole.superAdmin:
        destinationScreen = AdminDashboardScreen(adminUser: appUser);
        break;
      case UserRole.substationUser:
        destinationScreen = SubstationUserDashboardScreen(currentUser: appUser);
        break;
      case UserRole.subdivisionManager:
        destinationScreen = SubdivisionDashboardScreen(currentUser: appUser);
        break;
      case UserRole.divisionManager:
        destinationScreen = SubdivisionDashboardScreen(currentUser: appUser);
        break;
      case UserRole.circleManager:
        destinationScreen = SubdivisionDashboardScreen(currentUser: appUser);
        break;
      case UserRole.zoneManager:
        destinationScreen = SubdivisionDashboardScreen(currentUser: appUser);
        break;
      case UserRole.stateManager:
        destinationScreen = SubdivisionDashboardScreen(currentUser: appUser);
        break;
      case UserRole.companyManager:
        destinationScreen = SubdivisionDashboardScreen(currentUser: appUser);
        break;
      case UserRole.pending:
        _showSnackBar('Your account is pending admin approval.', isError: true);
        return;
      default:
        _showSnackBar('Unsupported user role: ${appUser.role}', isError: true);
        return;
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => destinationScreen),
    );
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: isError
                ? Colors.white
                : Theme.of(context).colorScheme.onSurface,
          ),
        ),
        backgroundColor: isError
            ? Theme.of(context).colorScheme.error
            : Theme.of(context).colorScheme.primary.withOpacity(0.9),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        margin: const EdgeInsets.all(16),
        elevation: 2,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: 24.0,
              vertical: 16.0,
            ),
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: colorScheme.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.electrical_services,
                        size: 40,
                        color: colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Substation Manager Pro',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Sign in to manage your substations efficiently',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: colorScheme.onSurface.withOpacity(0.6),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
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
                        label: Text(
                          _isLoading ? 'Signing in...' : 'Sign in with Google',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colorScheme.primary,
                          foregroundColor: colorScheme.onPrimary,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                          minimumSize: const Size(280, 48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          elevation: 2,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _isLoading
                          ? 'Setting up your account...'
                          : 'Your account requires profile completion and admin approval.',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: colorScheme.onSurface.withOpacity(0.5),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    if (_isLoading) ...[
                      const SizedBox(height: 16),
                      CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation(colorScheme.primary),
                        strokeWidth: 3,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
