// lib/screens/subdivision_asset_management_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'package:provider/provider.dart'; // Import provider for ChangeNotifierProvider
import '../../models/user_model.dart';
import '../../models/hierarchy_models.dart';
import '../../utils/snackbar_utils.dart';
import './substation_detail_screen.dart';
import 'export_master_data_screen.dart';
import '../controllers/sld_controller.dart'; // Import SldController

class SubdivisionAssetManagementScreen extends StatefulWidget {
  final String subdivisionId;
  final AppUser currentUser;

  const SubdivisionAssetManagementScreen({
    super.key,
    required this.subdivisionId,
    required this.currentUser,
  });

  @override
  State<SubdivisionAssetManagementScreen> createState() =>
      _SubdivisionAssetManagementScreenState();
}

class _SubdivisionAssetManagementScreenState
    extends State<SubdivisionAssetManagementScreen> {
  bool _isLoading = true;
  List<Substation> _substationsInSubdivision = [];

  @override
  void initState() {
    super.initState();
    _fetchSubstationsInSubdivision();
  }

  Future<void> _fetchSubstationsInSubdivision() async {
    // Add mounted check here as well to prevent setState after dispose
    if (!mounted) return;

    setState(() => _isLoading = true);
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('substations')
          .where('subdivisionId', isEqualTo: widget.subdivisionId)
          .orderBy('name')
          .get();
      _substationsInSubdivision = snapshot.docs
          .map((doc) => Substation.fromFirestore(doc))
          .toList();
    } catch (e) {
      if (mounted) // Ensure widget is still mounted before showing SnackBar
        SnackBarUtils.showSnackBar(
          context,
          'Failed to load substations: $e',
          isError: true,
        );
    } finally {
      if (mounted)
        setState(
          () => _isLoading = false,
        ); // Ensure widget is still mounted before setState
    }
  }

  Future<Substation?> _showSubstationSelectionDialog() async {
    if (_substationsInSubdivision.isEmpty) {
      if (mounted) {
        SnackBarUtils.showSnackBar(
          context,
          'No substations found in this subdivision.',
          isError: true,
        );
      }
      return null;
    }

    return await showModalBottomSheet<Substation>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Select Substation',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 20),
              DropdownSearch<Substation>(
                popupProps: const PopupProps.menu(showSearchBox: true),
                items: _substationsInSubdivision,
                itemAsString: (s) => s.name,
                onChanged: (Substation? selected) {
                  Navigator.of(context).pop(selected);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Asset Management',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 24),
          Card(
            elevation: 3,
            child: ListTile(
              leading: const Icon(Icons.electrical_services),
              title: const Text('Manage Bays & Equipment'),
              subtitle: const Text(
                'View and manage assets within your substations',
              ),
              onTap: () async {
                final selectedSubstation =
                    await _showSubstationSelectionDialog();
                if (selectedSubstation != null && mounted) {
                  // [FIX] Provide SldController when navigating to SubstationDetailScreen
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => ChangeNotifierProvider(
                        create: (context) => SldController(
                          substationId: selectedSubstation
                              .id, // Pass the actual substation ID
                          transformationController:
                              TransformationController(), // Provide a new controller
                        ),
                        child: SubstationDetailScreen(
                          substationId: selectedSubstation.id,
                          substationName: selectedSubstation.name,
                          currentUser: widget.currentUser,
                        ),
                      ),
                    ),
                  );
                }
              },
            ),
          ),
          const SizedBox(height: 16),
          Card(
            elevation: 3,
            child: ListTile(
              leading: const Icon(Icons.download),
              title: const Text('Export Master Data'),
              subtitle: const Text('Generate CSV reports of your assets'),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => ExportMasterDataScreen(
                      currentUser: widget.currentUser,
                      subdivisionId: widget.subdivisionId,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
