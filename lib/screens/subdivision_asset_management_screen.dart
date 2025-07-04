// lib/screens/subdivision_asset_management_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dropdown_search/dropdown_search.dart'; // Import dropdown_search for selection
import '../../models/user_model.dart';
import '../../models/hierarchy_models.dart';
import '../../utils/snackbar_utils.dart';
import './substation_detail_screen.dart'; // For Bay creation/management
import './bay_equipment_management_screen.dart'; // For direct equipment management
// Import the new export screens (you would create these files)
// import 'export_reports_screen.dart';
// import 'export_master_data_screen.dart';

class SubdivisionAssetManagementScreen extends StatefulWidget {
  final String subdivisionId;
  final AppUser currentUser;
  // REMOVED: final String? selectedSubstationId; // No longer passed directly

  const SubdivisionAssetManagementScreen({
    super.key,
    required this.subdivisionId,
    required this.currentUser,
    String? selectedSubstationId,
    // REMOVED: this.selectedSubstationId,
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
    setState(() {
      _isLoading = true;
    });
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('substations')
          .where('subdivisionId', isEqualTo: widget.subdivisionId)
          .orderBy('name')
          .get();
      setState(() {
        _substationsInSubdivision = snapshot.docs
            .map((doc) => Substation.fromFirestore(doc))
            .toList();
        _isLoading = false;
      });
    } catch (e) {
      print("Error fetching substations for subdivision manager: $e");
      if (mounted) {
        SnackBarUtils.showSnackBar(
          context,
          'Failed to load substations for management: $e',
          isError: true,
        );
      }
      setState(() {
        _isLoading = false;
      });
    }
  }

  // NEW: Helper to show substation selection dialog
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
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25.0)),
      ),
      builder: (BuildContext context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 16.0,
            right: 16.0,
            top: 24.0,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Select Substation',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 20),
              DropdownSearch<Substation>(
                popupProps: PopupProps.menu(
                  showSearchBox: true,
                  menuProps: MenuProps(borderRadius: BorderRadius.circular(10)),
                  searchFieldProps: TextFieldProps(
                    decoration: InputDecoration(
                      labelText: 'Search Substation',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
                dropdownDecoratorProps: DropDownDecoratorProps(
                  dropdownSearchDecoration: InputDecoration(
                    labelText: 'Choose a Substation',
                    prefixIcon: const Icon(Icons.electrical_services),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                itemAsString: (Substation s) => s.name,
                items: _substationsInSubdivision,
                onChanged: (Substation? selectedSubstation) {
                  Navigator.of(
                    context,
                  ).pop(selectedSubstation); // Pop with selected substation
                },
                validator: (value) =>
                    value == null ? 'Please select a Substation' : null,
              ),
              const SizedBox(height: 20),
              // Optional: Close button for the dialog
              Center(
                child: TextButton(
                  onPressed: () =>
                      Navigator.of(context).pop(), // Pop without selection
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(height: 10),
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
            'Asset Management for Subdivision',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          Text(
            'Subdivision ID: ${widget.subdivisionId}',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),

          // 1. Dashboard for creating bay & managing equipment
          Text(
            'Bays & Equipment',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 10),
          Card(
            elevation: 3,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ListTile(
                    leading: const Icon(Icons.add_box),
                    title: const Text('Create New Bay'),
                    subtitle: const Text(
                      'Add a new bay to any substation in your subdivision',
                    ),
                    onTap: () async {
                      final selectedSubstation =
                          await _showSubstationSelectionDialog();
                      if (selectedSubstation != null && mounted) {
                        // Navigate to SubstationDetailScreen for bay creation in 'add' mode
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => SubstationDetailScreen(
                              substationId: selectedSubstation.id,
                              substationName: selectedSubstation.name,
                              currentUser: widget.currentUser,
                              // You might need to add a flag to SubstationDetailScreen
                              // to explicitly open in 'add bay' mode. For now, it defaults to list.
                              // Consider passing BayDetailViewMode.add if SubstationDetailScreen supports it
                            ),
                          ),
                        );
                      }
                    },
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.electrical_services),
                    title: const Text('Manage Bays & Equipment in Substations'),
                    subtitle: const Text(
                      'View and manage bays and equipment within your assigned substations',
                    ),
                    onTap: () async {
                      final selectedSubstation =
                          await _showSubstationSelectionDialog();
                      if (selectedSubstation != null && mounted) {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => SubstationDetailScreen(
                              substationId: selectedSubstation.id,
                              substationName: selectedSubstation.name,
                              currentUser: widget.currentUser,
                            ),
                          ),
                        );
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // 2. Exporting Reports
          Text('Data Export', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          Card(
            elevation: 3,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ListTile(
                    leading: const Icon(Icons.description),
                    title: const Text('Export Logsheet Readings Report'),
                    subtitle: const Text(
                      'Generate CSV of logsheet data for a selected period',
                    ),
                    onTap: () {
                      SnackBarUtils.showSnackBar(
                        context,
                        'Logsheet export feature coming soon!',
                      );
                      // You might want to show a dialog here for date range and then proceed
                      // Navigator.of(context).push(MaterialPageRoute(builder: (context) => ExportReportsScreen(
                      //   reportType: 'logsheet',
                      //   subdivisionId: widget.subdivisionId,
                      //   currentUser: widget.currentUser,
                      // )));
                    },
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.warning),
                    title: const Text('Export Tripping & Shutdown Report'),
                    subtitle: const Text(
                      'Generate CSV of tripping/shutdown events for a selected period',
                    ),
                    onTap: () {
                      SnackBarUtils.showSnackBar(
                        context,
                        'Tripping/Shutdown export feature coming soon!',
                      );
                      // Navigator.of(context).push(MaterialPageRoute(builder: (context) => ExportReportsScreen(
                      //   reportType: 'tripping_shutdown',
                      //   subdivisionId: widget.subdivisionId,
                      //   currentUser: widget.currentUser,
                      // )));
                    },
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.storage),
                    title: const Text('Export Master Data'),
                    subtitle: const Text(
                      'Generate CSV of substation, bay, and equipment details',
                    ),
                    onTap: () {
                      SnackBarUtils.showSnackBar(
                        context,
                        'Master data export feature coming soon!',
                      );
                      // Navigator.of(context).push(MaterialPageRoute(builder: (context) => ExportMasterDataScreen(
                      //   subdivisionId: widget.subdivisionId,
                      //   currentUser: widget.currentUser,
                      // )));
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // 3. Equipment History (Placeholder/Guidance)
          Text(
            'Equipment History & Replacement',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 10),
          Card(
            elevation: 3,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ListTile(
                    leading: const Icon(Icons.history),
                    title: const Text('View Equipment History'),
                    subtitle: const Text(
                      'Track changes and replacements of equipment over time',
                    ),
                    onTap: () {
                      SnackBarUtils.showSnackBar(
                        context,
                        'Equipment history view is under development. Please manage equipment from "Manage Bays & Equipment" for now.',
                      );
                      // This would likely involve selecting a substation first, then an equipment
                      // Navigator.of(context).push(MaterialPageRoute(builder: (context) => EquipmentHistoryScreen(
                      //   subdivisionId: widget.subdivisionId,
                      //   currentUser: widget.currentUser,
                      // )));
                    },
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.change_circle),
                    title: const Text('Replace Equipment (Create History)'),
                    subtitle: const Text(
                      'Decommission old equipment and add new with history link',
                    ),
                    onTap: () {
                      SnackBarUtils.showSnackBar(
                        context,
                        'Equipment replacement workflow is being developed.',
                      );
                      // This action needs to be performed on a specific equipment instance,
                      // so typically after navigating through substation and bay.
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
