import 'package:flutter/material.dart';

import '../features/forms/presentation/forms_admin_screen.dart';
import '../features/iam/presentation/roles_screen.dart';
import '../features/iam/presentation/users_screen.dart';
import '../features/org/presentation/org_structure_screen.dart';

/// T-code → screen. A team ships a micro-app by adding one line here and one
/// row in app_catalog. Codes in the catalog without a screen yet show a
/// "not released" page instead of failing.
final microAppScreens = <String, WidgetBuilder>{
  'OR01': (_) => const OrgStructureScreen(),
  'SU01': (_) => const UsersScreen(),
  'PFCG': (_) => const RolesScreen(),
  'UI01': (_) => const FormsAdminScreen(),
};
