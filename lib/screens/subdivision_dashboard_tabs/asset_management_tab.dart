// lib/screens/subdivision_dashboard_tabs/asset_management_tab.dart

import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import 'subdivision_asset_management_screen.dart';

class AssetManagementTab extends StatelessWidget {
  final AppUser currentUser;
  final String subdivisionId;
  final String? selectedSubstationId;
  final String substationId;

  const AssetManagementTab({
    Key? key,
    required this.currentUser,
    required this.subdivisionId,
    this.selectedSubstationId,
    required this.substationId,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFFAFAFA),
      child: SubdivisionAssetManagementScreen(
        subdivisionId: subdivisionId,
        currentUser: currentUser,
      ),
    );
  }
}
