// lib/screens/subdivision_dashboard_tabs/asset_management_tab.dart

import 'package:flutter/material.dart';

import '../../models/user_model.dart';
import 'subdivision_asset_management_screen.dart'; // Assuming this screen exists

class AssetManagementTab extends StatelessWidget {
  final AppUser currentUser;
  final String subdivisionId;

  const AssetManagementTab({
    Key? key,
    required this.currentUser,
    required this.subdivisionId,
    String? selectedSubstationId,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SubdivisionAssetManagementScreen(
      subdivisionId: subdivisionId,
      currentUser: currentUser,
    );
  }
}
