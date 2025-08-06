import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:provider/provider.dart';

import '../models/user_model.dart';
import '../models/hierarchy_models.dart';
import '../models/app_state_data.dart';
import '../screens/auth_screen.dart';
import '../screens/admin/admin_dashboard_screen.dart';
import '../screens/equipment_hierarchy_selection_screen.dart';
import 'subdivision_dashboard_tabs/energy_sld_screen.dart';
import '../screens/saved_sld_list_screen.dart';
import 'substation_dashboard/substation_user_dashboard_screen.dart';
import 'subdivision_dashboard_tabs/subdivision_dashboard_screen.dart';
import '../screens/admin/reading_template_management_screen.dart';
import 'subdivision_dashboard_tabs/chart_configuration_screen.dart';
import '../controllers/sld_controller.dart';
import '../utils/snackbar_utils.dart';

class HomeRouter extends StatelessWidget {
  const HomeRouter({super.key});

  @override
  Widget build(BuildContext context) {
    final appStateData = Provider.of<AppStateData>(context);
    final theme = Theme.of(context);

    if (!appStateData.isInitialized) {
      return Scaffold(
        backgroundColor: const Color(0xFFFAFAFA),
        body: Center(
          child: CircularProgressIndicator(color: theme.colorScheme.primary),
        ),
      );
    }

    final AppUser? currentUser = appStateData.currentUser;

    if (currentUser == null) {
      return const AuthScreen();
    } else {
      if (currentUser.approved) {
        switch (currentUser.role) {
          case UserRole.admin:
            return AdminHomeScreen(appUser: currentUser);
          case UserRole.substationUser:
            return SubstationUserHomeScreen(appUser: currentUser);
          case UserRole.subdivisionManager:
            return SubdivisionManagerHomeScreen(appUser: currentUser);
          default:
            WidgetsBinding.instance.addPostFrameCallback((_) {
              SnackBarUtils.showSnackBar(
                context,
                'Your user role is not recognized. Please log in again or contact support.',
                isError: true,
              );
              FirebaseAuth.instance.signOut();
              GoogleSignIn().signOut();
            });
            return const AuthScreen();
        }
      } else {
        return Scaffold(
          backgroundColor: const Color(0xFFFAFAFA),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.hourglass_empty,
                    size: 64,
                    color: theme.colorScheme.primary.withOpacity(0.6),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Your account is pending approval by an admin.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Please wait while an administrator reviews your registration.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: theme.colorScheme.onSurface.withOpacity(0.5),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }
    }
  }
}

abstract class BaseHomeScreen extends StatefulWidget {
  final AppUser appUser;

  const BaseHomeScreen({super.key, required this.appUser});

  @override
  BaseHomeScreenState createState();
}

abstract class BaseHomeScreenState<T extends BaseHomeScreen> extends State<T> {
  @override
  Widget build(BuildContext context) {
    return buildBody(context);
  }

  Widget buildBody(BuildContext context);
}

class AdminHomeScreen extends BaseHomeScreen {
  static const String routeName = '/admin_home';

  const AdminHomeScreen({super.key, required super.appUser});

  @override
  BaseHomeScreenState createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends BaseHomeScreenState<AdminHomeScreen> {
  @override
  Widget buildBody(BuildContext context) {
    return AdminDashboardScreen(adminUser: widget.appUser);
  }
}

class SubstationUserHomeScreen extends BaseHomeScreen {
  static const String routeName = '/substation_user_home';

  const SubstationUserHomeScreen({super.key, required super.appUser});

  @override
  BaseHomeScreenState createState() => _SubstationUserHomeScreenState();
}

class _SubstationUserHomeScreenState
    extends BaseHomeScreenState<SubstationUserHomeScreen> {
  @override
  Widget buildBody(BuildContext context) {
    return SubstationUserDashboardScreen(currentUser: widget.appUser);
  }
}

class SubdivisionManagerHomeScreen extends BaseHomeScreen {
  static const String routeName = '/subdivision_manager_home';

  const SubdivisionManagerHomeScreen({super.key, required super.appUser});

  @override
  BaseHomeScreenState createState() => _SubdivisionManagerHomeScreenState();
}

class _SubdivisionManagerHomeScreenState
    extends BaseHomeScreenState<SubdivisionManagerHomeScreen> {
  @override
  Widget buildBody(BuildContext context) {
    return SubdivisionDashboardScreen(currentUser: widget.appUser);
  }
}
