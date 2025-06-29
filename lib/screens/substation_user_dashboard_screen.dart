// lib/screens/substation_user_dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dropdown_search/dropdown_search.dart';

import '../../models/user_model.dart';
import '../../models/hierarchy_models.dart'; // For Substation model
import '../../utils/snackbar_utils.dart';
import 'logsheet_entry_screen.dart'; // For LogsheetEntryScreen

class SubstationUserDashboardScreen extends StatefulWidget {
  final AppUser currentUser;

  const SubstationUserDashboardScreen({super.key, required this.currentUser});

  @override
  State<SubstationUserDashboardScreen> createState() =>
      _SubstationUserDashboardScreenState();
}

class _SubstationUserDashboardScreenState
    extends State<SubstationUserDashboardScreen> {
  Substation? _selectedSubstationForLogsheet;
  List<Substation> _accessibleSubstations = [];
  bool _isLoadingSubstations = true;

  @override
  void initState() {
    super.initState();
    _loadAccessibleSubstations();
  }

  Future<void> _loadAccessibleSubstations() async {
    setState(() {
      _isLoadingSubstations = true;
    });

    try {
      Query query = FirebaseFirestore.instance.collection('substations');

      // Filter substations based on user's role and assigned levels
      if (widget.currentUser.role == UserRole.subdivisionManager &&
          widget.currentUser.assignedLevels != null &&
          widget.currentUser.assignedLevels!.containsKey('subdivisionId')) {
        query = query.where(
          'subdivisionId',
          isEqualTo: widget.currentUser.assignedLevels!['subdivisionId'],
        );
      } else if (widget.currentUser.role == UserRole.substationUser &&
          widget.currentUser.assignedLevels != null &&
          widget.currentUser.assignedLevels!.containsKey('substationId')) {
        query = query.where(
          FieldPath.documentId,
          isEqualTo: widget.currentUser.assignedLevels!['substationId'],
        );
      } else {
        // Roles not explicitly handled or without assigned levels
        _accessibleSubstations = [];
        _isLoadingSubstations = false;
        return;
      }

      final snapshot = await query.orderBy('name').get();
      setState(() {
        _accessibleSubstations = snapshot.docs
            .map((doc) => Substation.fromFirestore(doc))
            .toList();
        // Automatically select the substation if it's a SubstationUser with one assigned
        if (widget.currentUser.role == UserRole.substationUser &&
            _accessibleSubstations.length == 1) {
          _selectedSubstationForLogsheet = _accessibleSubstations.first;
        }
      });
    } catch (e) {
      print("Error loading accessible substations: $e");
      if (mounted) {
        SnackBarUtils.showSnackBar(
          context,
          'Failed to load substations: $e',
          isError: true,
        );
      }
    } finally {
      setState(() {
        _isLoadingSubstations = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingSubstations) {
      return const Center(child: CircularProgressIndicator());
    } else if (_accessibleSubstations.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.info_outline,
                size: 80,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 20),
              Text(
                'Welcome, ${widget.currentUser.email}!',
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                'Role: ${widget.currentUser.role.toString().split('.').last}',
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(color: Colors.grey.shade700),
              ),
              const SizedBox(height: 20),
              const Text(
                'No substations assigned or found for your role. Please contact your administrator.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontStyle: FontStyle.italic,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      // Determine if substation dropdown should be shown
      final bool showSubstationDropdown =
          !(widget.currentUser.role == UserRole.substationUser &&
              _accessibleSubstations.length == 1);

      return DefaultTabController(
        // DefaultTabController now wraps the entire content
        length: 3, // Operations, Energy, Tripping/Shutdown
        child: Column(
          children: [
            if (showSubstationDropdown)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: DropdownSearch<Substation>(
                  popupProps: PopupProps.menu(
                    showSearchBox: true,
                    menuProps: MenuProps(
                      borderRadius: BorderRadius.circular(10),
                    ),
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
                      labelText: 'Select Substation',
                      hintText: 'Choose a substation to view logsheets',
                      prefixIcon: const Icon(Icons.electrical_services),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  itemAsString: (Substation s) => s.name,
                  selectedItem: _selectedSubstationForLogsheet,
                  items: _accessibleSubstations,
                  onChanged: (Substation? newValue) {
                    setState(() {
                      _selectedSubstationForLogsheet = newValue;
                    });
                  },
                  validator: (value) =>
                      value == null ? 'Please select a Substation' : null,
                ),
              ),
            if (_selectedSubstationForLogsheet != null)
              Expanded(
                child: TabBarView(
                  children: [
                    // Operations (Hourly) Tab
                    LogsheetEntryScreen(
                      substationId: _selectedSubstationForLogsheet!.id,
                      substationName: _selectedSubstationForLogsheet!.name,
                      currentUser: widget.currentUser,
                      initialFrequencyFilter: 'hourly', // Pre-filter for hourly
                    ),
                    // Energy (Daily) Tab
                    LogsheetEntryScreen(
                      substationId: _selectedSubstationForLogsheet!.id,
                      substationName: _selectedSubstationForLogsheet!.name,
                      currentUser: widget.currentUser,
                      initialFrequencyFilter: 'daily', // Pre-filter for daily
                    ),
                    // Tripping & Shutdown Tab (Placeholder)
                    Center(
                      child: Text(
                        'Tripping & Shutdown features coming soon!',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontStyle: FontStyle.italic),
                      ),
                    ),
                  ],
                ),
              ),
            // NEW: TabBar at the bottom
            if (_selectedSubstationForLogsheet != null)
              Padding(
                padding: EdgeInsets.zero, // No extra padding for the TabBar
                child: TabBar(
                  labelColor: Theme.of(context).colorScheme.primary,
                  unselectedLabelColor: Colors.grey,
                  indicatorColor: Theme.of(context).colorScheme.primary,
                  tabs: const [
                    Tab(
                      text: 'Operations',
                      icon: Icon(Icons.access_time_filled),
                    ),
                    Tab(text: 'Energy', icon: Icon(Icons.electric_meter)),
                    Tab(text: 'Tripping & Shutdown', icon: Icon(Icons.warning)),
                  ],
                ),
              ),
          ],
        ),
      );
    }
  }
}
