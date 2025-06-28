// lib/screens/equipment_hierarchy_selection_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:dropdown_search/dropdown_search.dart';

import '../models/user_model.dart';
import '../models/hierarchy_models.dart';
import '../models/app_state_data.dart';
import '../screens/substation_detail_screen.dart';

class EquipmentHierarchySelectionScreen extends StatefulWidget {
  final AppUser currentUser;

  const EquipmentHierarchySelectionScreen({
    super.key,
    required this.currentUser,
  });

  @override
  State<EquipmentHierarchySelectionScreen> createState() =>
      _EquipmentHierarchySelectionScreenState();
}

class _EquipmentHierarchySelectionScreenState
    extends State<EquipmentHierarchySelectionScreen> {
  String? _selectedScreenStateName;
  String? _selectedScreenZoneId;
  String? _selectedScreenZoneName;
  String? _selectedScreenCircleId;
  String? _selectedScreenCircleName;
  String? _selectedScreenDivisionId;
  String? _selectedScreenDivisionName;
  String? _selectedScreenSubdivisionId;
  String? _selectedScreenSubdivisionName;

  @override
  void initState() {
    super.initState();
    _initializeHierarchyForManagers();
  }

  void _initializeHierarchyForManagers() async {
    if (widget.currentUser.role == UserRole.subdivisionManager &&
        widget.currentUser.assignedLevels != null &&
        widget.currentUser.assignedLevels!.containsKey('subdivisionId')) {
      final subdivisionId = widget.currentUser.assignedLevels!['subdivisionId'];
      setState(() {
        _selectedScreenSubdivisionId = subdivisionId;
      });
      try {
        final doc = await FirebaseFirestore.instance
            .collection('subdivisions')
            .doc(subdivisionId)
            .get();
        if (doc.exists && mounted) {
          setState(() {
            _selectedScreenSubdivisionName =
                (doc.data() as Map<String, dynamic>)['name'];
          });
        }
      } catch (e) {
        print("Error fetching subdivision name for manager: $e");
      }
    }
  }

  Future<void> _fetchSubdivisionName(String subdivisionId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('subdivisions')
          .doc(subdivisionId)
          .get();
      if (doc.exists && mounted) {
        setState(() {
          _selectedScreenSubdivisionName =
              (doc.data() as Map<String, dynamic>)['name'];
        });
      }
    } catch (e) {
      print("Error fetching subdivision name: $e");
    }
  }

  InputDecoration _getDropdownDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      filled: true,
      fillColor: Theme.of(context).colorScheme.primary.withOpacity(0.05),
    );
  }

  PopupProps<T> _getPopupProps<T>(String hintText) {
    return PopupProps.menu(
      showSearchBox: true,
      menuProps: MenuProps(borderRadius: BorderRadius.circular(10)),
      searchFieldProps: TextFieldProps(
        decoration: InputDecoration(
          labelText: 'Search $hintText',
          prefixIcon: const Icon(Icons.search),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Select Substation')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select Substation to Manage Equipment',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            // --- Selected Hierarchy Path Display ---
            if (widget.currentUser.role == UserRole.admin &&
                (_selectedScreenStateName != null ||
                    _selectedScreenZoneName != null ||
                    _selectedScreenCircleName != null ||
                    _selectedScreenDivisionName != null ||
                    _selectedScreenSubdivisionName != null))
              Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Text.rich(
                  TextSpan(
                    text: 'Selected Path: ',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    children: [
                      if (_selectedScreenStateName != null)
                        TextSpan(
                          text: 'State: ${_selectedScreenStateName!} > ',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      if (_selectedScreenZoneName != null)
                        TextSpan(
                          text: 'Zone: ${_selectedScreenZoneName!} > ',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      if (_selectedScreenCircleName != null)
                        TextSpan(
                          text: 'Circle: ${_selectedScreenCircleName!} > ',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      if (_selectedScreenDivisionName != null)
                        TextSpan(
                          text: 'Division: ${_selectedScreenDivisionName!} > ',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      if (_selectedScreenSubdivisionName != null)
                        TextSpan(
                          text:
                              'Subdivision: ${_selectedScreenSubdivisionName!} ',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                    ],
                  ),
                ),
              ) // Removed the comma here
            else if (widget.currentUser.role == UserRole.subdivisionManager &&
                _selectedScreenSubdivisionName != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Text(
                  'Managed Subdivision: ${_selectedScreenSubdivisionName!}',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),

            // --- End Selected Hierarchy Path Display ---
            if (widget.currentUser.role == UserRole.admin) ...[
              Consumer<AppStateData>(
                builder: (context, appState, child) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: DropdownSearch<String>(
                      selectedItem: _selectedScreenStateName,
                      popupProps: _getPopupProps<String>('State'),
                      dropdownDecoratorProps: DropDownDecoratorProps(
                        dropdownSearchDecoration: _getDropdownDecoration(
                          'State',
                          Icons.map,
                        ),
                      ),
                      items: appState.states,
                      onChanged: (newValue) {
                        setState(() {
                          _selectedScreenStateName = newValue;
                          _selectedScreenZoneId = null;
                          _selectedScreenZoneName = null;
                          _selectedScreenCircleId = null;
                          _selectedScreenCircleName = null;
                          _selectedScreenDivisionId = null;
                          _selectedScreenDivisionName = null;
                          _selectedScreenSubdivisionId = null;
                          _selectedScreenSubdivisionName = null;
                        });
                      },
                      validator: (value) =>
                          value == null ? 'Please select a State' : null,
                    ),
                  );
                },
              ),
              if (_selectedScreenStateName != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: DropdownSearch<Zone>(
                    selectedItem: _selectedScreenZoneId != null
                        ? Zone(
                            id: _selectedScreenZoneId!,
                            name: _selectedScreenZoneName!,
                            createdBy: '',
                            createdAt: Timestamp.now(),
                            stateName: _selectedScreenStateName!,
                          )
                        : null,
                    popupProps: _getPopupProps('Zone'),
                    dropdownDecoratorProps: DropDownDecoratorProps(
                      dropdownSearchDecoration: _getDropdownDecoration(
                        'Zone',
                        Icons.public,
                      ),
                    ),
                    itemAsString: (item) => item.name,
                    asyncItems: (String filter) async {
                      if (_selectedScreenStateName == null) return [];
                      final snapshot = await FirebaseFirestore.instance
                          .collection('zones')
                          .where(
                            'stateName',
                            isEqualTo: _selectedScreenStateName,
                          )
                          .orderBy('name')
                          .get();
                      return snapshot.docs
                          .map((doc) => Zone.fromFirestore(doc))
                          .where(
                            (zone) => zone.name.toLowerCase().contains(
                              filter.toLowerCase(),
                            ),
                          )
                          .toList();
                    },
                    onChanged: (newValue) {
                      setState(() {
                        _selectedScreenZoneId = newValue?.id;
                        _selectedScreenZoneName = newValue?.name;
                        _selectedScreenCircleId = null;
                        _selectedScreenCircleName = null;
                        _selectedScreenDivisionId = null;
                        _selectedScreenDivisionName = null;
                        _selectedScreenSubdivisionId = null;
                        _selectedScreenSubdivisionName = null;
                      });
                    },
                    validator: (value) =>
                        value == null ? 'Please select a Zone' : null,
                  ),
                ),
              if (_selectedScreenZoneId != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: DropdownSearch<Circle>(
                    selectedItem: _selectedScreenCircleId != null
                        ? Circle(
                            id: _selectedScreenCircleId!,
                            name: _selectedScreenCircleName!,
                            createdBy: '',
                            createdAt: Timestamp.now(),
                            zoneId: _selectedScreenZoneId!,
                          )
                        : null,
                    popupProps: _getPopupProps('Circle'),
                    dropdownDecoratorProps: DropDownDecoratorProps(
                      dropdownSearchDecoration: _getDropdownDecoration(
                        'Circle',
                        Icons.circle,
                      ),
                    ),
                    itemAsString: (item) => item.name,
                    asyncItems: (String filter) async {
                      if (_selectedScreenZoneId == null) return [];
                      final snapshot = await FirebaseFirestore.instance
                          .collection('circles')
                          .where('zoneId', isEqualTo: _selectedScreenZoneId)
                          .orderBy('name')
                          .get();
                      return snapshot.docs
                          .map((doc) => Circle.fromFirestore(doc))
                          .where(
                            (circle) => circle.name.toLowerCase().contains(
                              filter.toLowerCase(),
                            ),
                          )
                          .toList();
                    },
                    onChanged: (newValue) {
                      setState(() {
                        _selectedScreenCircleId = newValue?.id;
                        _selectedScreenCircleName = newValue?.name;
                        _selectedScreenDivisionId = null;
                        _selectedScreenDivisionName = null;
                        _selectedScreenSubdivisionId = null;
                        _selectedScreenSubdivisionName = null;
                      });
                    },
                    validator: (value) =>
                        value == null ? 'Please select a Circle' : null,
                  ),
                ),
              if (_selectedScreenCircleId != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: DropdownSearch<Division>(
                    selectedItem: _selectedScreenDivisionId != null
                        ? Division(
                            id: _selectedScreenDivisionId!,
                            name: _selectedScreenDivisionName!,
                            createdBy: '',
                            createdAt: Timestamp.now(),
                            circleId: _selectedScreenCircleId!,
                          )
                        : null,
                    popupProps: _getPopupProps('Division'),
                    dropdownDecoratorProps: DropDownDecoratorProps(
                      dropdownSearchDecoration: _getDropdownDecoration(
                        'Division',
                        Icons.apartment,
                      ),
                    ),
                    itemAsString: (item) => item.name,
                    asyncItems: (String filter) async {
                      if (_selectedScreenCircleId == null) return [];
                      final snapshot = await FirebaseFirestore.instance
                          .collection('divisions')
                          .where('circleId', isEqualTo: _selectedScreenCircleId)
                          .orderBy('name')
                          .get();
                      return snapshot.docs
                          .map((doc) => Division.fromFirestore(doc))
                          .where(
                            (division) => division.name.toLowerCase().contains(
                              filter.toLowerCase(),
                            ),
                          )
                          .toList();
                    },
                    onChanged: (newValue) {
                      setState(() {
                        _selectedScreenDivisionId = newValue?.id;
                        _selectedScreenDivisionName = newValue?.name;
                        _selectedScreenSubdivisionId = null;
                        _selectedScreenSubdivisionName = null;
                      });
                    },
                    validator: (value) =>
                        value == null ? 'Please select a Division' : null,
                  ),
                ),
              if (_selectedScreenDivisionId != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: DropdownSearch<Subdivision>(
                    selectedItem: _selectedScreenSubdivisionId != null
                        ? Subdivision(
                            id: _selectedScreenSubdivisionId!,
                            name: _selectedScreenSubdivisionName!,
                            createdBy: '',
                            createdAt: Timestamp.now(),
                            divisionId: _selectedScreenDivisionId!,
                          )
                        : null,
                    popupProps: _getPopupProps('Subdivision'),
                    dropdownDecoratorProps: DropDownDecoratorProps(
                      dropdownSearchDecoration: _getDropdownDecoration(
                        'Subdivision',
                        Icons.merge_type,
                      ),
                    ),
                    itemAsString: (item) => item.name,
                    asyncItems: (String filter) async {
                      if (_selectedScreenDivisionId == null) return [];
                      final snapshot = await FirebaseFirestore.instance
                          .collection('subdivisions')
                          .where(
                            'divisionId',
                            isEqualTo: _selectedScreenDivisionId,
                          )
                          .orderBy('name')
                          .get();
                      return snapshot.docs
                          .map((doc) => Subdivision.fromFirestore(doc))
                          .where(
                            (subdivision) => subdivision.name
                                .toLowerCase()
                                .contains(filter.toLowerCase()),
                          )
                          .toList();
                    },
                    onChanged: (newValue) {
                      setState(() {
                        _selectedScreenSubdivisionId = newValue?.id;
                        _selectedScreenSubdivisionName = newValue?.name;
                      });
                    },
                    validator: (value) =>
                        value == null ? 'Please select a Subdivision' : null,
                  ),
                ),
            ],
            if (_selectedScreenSubdivisionId != null ||
                widget.currentUser.role == UserRole.subdivisionManager)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: DropdownSearch<Substation>(
                  // selectedItem should be null if we want it to clear after navigation
                  selectedItem: null,
                  popupProps: _getPopupProps('Substation'),
                  dropdownDecoratorProps: DropDownDecoratorProps(
                    dropdownSearchDecoration: _getDropdownDecoration(
                      'Substation',
                      Icons.electrical_services,
                    ),
                  ),
                  itemAsString: (item) => item.name,
                  asyncItems: (String filter) async {
                    if (_selectedScreenSubdivisionId == null &&
                        widget.currentUser.role != UserRole.subdivisionManager)
                      return [];

                    Query query = FirebaseFirestore.instance.collection(
                      'substations',
                    );
                    if (widget.currentUser.role ==
                            UserRole.subdivisionManager &&
                        widget.currentUser.assignedLevels!.containsKey(
                          'subdivisionId',
                        )) {
                      query = query.where(
                        'subdivisionId',
                        isEqualTo:
                            widget.currentUser.assignedLevels!['subdivisionId'],
                      );
                    } else if (_selectedScreenSubdivisionId != null) {
                      query = query.where(
                        'subdivisionId',
                        isEqualTo: _selectedScreenSubdivisionId,
                      );
                    } else {
                      return [];
                    }

                    final snapshot = await query.orderBy('name').get();
                    return snapshot.docs
                        .map((doc) => Substation.fromFirestore(doc))
                        .where(
                          (substation) => substation.name
                              .toLowerCase()
                              .contains(filter.toLowerCase()),
                        )
                        .toList();
                  },
                  onChanged: (newValue) {
                    if (newValue != null) {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => SubstationDetailScreen(
                            substationId: newValue.id,
                            substationName: newValue.name,
                            currentUser: widget.currentUser,
                          ),
                        ),
                      );
                      // Reset state after navigation to clear dropdown visually upon returning
                      setState(() {
                        _selectedScreenStateName = null;
                        _selectedScreenZoneId = null;
                        _selectedScreenZoneName = null;
                        _selectedScreenCircleId = null;
                        _selectedScreenCircleName = null;
                        _selectedScreenDivisionId = null;
                        _selectedScreenDivisionName = null;
                        _selectedScreenSubdivisionId =
                            (widget.currentUser.role ==
                                    UserRole.subdivisionManager &&
                                widget.currentUser.assignedLevels != null &&
                                widget.currentUser.assignedLevels!.containsKey(
                                  'subdivisionId',
                                ))
                            ? widget
                                  .currentUser
                                  .assignedLevels!['subdivisionId']
                            : null;
                        if (widget.currentUser.role ==
                                UserRole.subdivisionManager &&
                            _selectedScreenSubdivisionId != null) {
                          _fetchSubdivisionName(_selectedScreenSubdivisionId!);
                        } else {
                          _selectedScreenSubdivisionName = null;
                        }
                      });
                    }
                  },
                  validator: (value) =>
                      value == null ? 'Please select a Substation' : null,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
