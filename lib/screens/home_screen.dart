import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart'; // For signing out of Google

import '../models/user_model.dart'; // Our AppUser model
import '../screens/auth_screen.dart'; // For redirecting on sign out
import '../screens/admin/admin_dashboard_screen.dart'; // NEW: Import the AdminDashboardScreen
import '../screens/admin/admin_hierarchy_screen.dart'; // Still needed for navigation from dashboard

class HomeScreen extends StatelessWidget {
  final AppUser appUser;

  const HomeScreen({super.key, required this.appUser});

  @override
  Widget build(BuildContext context) {
    Widget bodyContent;
    String appBarTitle;
    List<BottomNavigationBarItem> bottomNavItems = [];
    int selectedIndex = 0; // Default to Dashboard-like view

    // Define main screen content based on role
    if (appUser.role == UserRole.admin) {
      appBarTitle = 'Admin Dashboard'; // The dashboard title
      bodyContent = AdminDashboardScreen(
        adminUser: appUser,
      ); // Admin goes to the new dashboard
      bottomNavItems = [
        const BottomNavigationBarItem(
          icon: Icon(Icons.admin_panel_settings),
          label: 'Admin',
        ),
      ];
    } else {
      appBarTitle = 'Dashboard'; // Default title for non-admin roles
      bodyContent = Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.construction,
              size: 80,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 20),
            Text(
              'Welcome, ${appUser.email}!',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              'Role: ${appUser.role.toString().split('.').last}',
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: Colors.grey.shade700),
            ),
            const SizedBox(height: 20),
            const Text(
              'Your dashboard features are coming soon!',
              style: TextStyle(
                fontSize: 16,
                fontStyle: FontStyle.italic,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
      bottomNavItems = [
        const BottomNavigationBarItem(
          icon: Icon(Icons.dashboard),
          label: 'Dashboard',
        ),
        const BottomNavigationBarItem(
          icon: Icon(Icons.schedule),
          label: 'Operations',
        ),
        const BottomNavigationBarItem(
          icon: Icon(Icons.electric_meter),
          label: 'Energy',
        ),
      ];
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(appBarTitle),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              await GoogleSignIn().signOut();
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => const AuthScreen()),
                  (Route<dynamic> route) => false,
                );
              }
            },
          ),
        ],
      ),
      body: bodyContent,
      bottomNavigationBar:
          (bottomNavItems.isNotEmpty && appUser.role != UserRole.admin)
          ? BottomNavigationBar(
              items: bottomNavItems,
              currentIndex: selectedIndex,
              selectedItemColor: Theme.of(context).colorScheme.primary,
              unselectedItemColor: Theme.of(
                context,
              ).colorScheme.onSurface.withOpacity(0.6),
            )
          : null,
    );
  }
}
