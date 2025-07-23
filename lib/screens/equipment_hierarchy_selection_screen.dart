// lib/screens/equipment_hierarchy_selection_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'package:provider/provider.dart';
import 'package:collection/collection.dart'; // For firstWhereOrNull

import '../models/user_model.dart';
import '../models/hierarchy_models.dart'; // Contains AppScreenState now
import '../utils/snackbar_utils.dart';
import 'subdivision_dashboard_tabs/substation_detail_screen.dart';
import '../controllers/sld_controller.dart'; // Import SldController

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
  // State variables for selected hierarchy levels
  String? _selectedScreenStateId;
  String? _selectedScreenZoneId;
  String? _selectedScreenCircleId;
  String? _selectedScreenDivisionId;
  String? _selectedScreenSubdivisionId;

  // Lists to populate dropdowns
  List<AppScreenState> _states = [];
  List<Zone> _zones = [];
  List<Circle> _circles = [];
  List<Division> _divisions = [];
  List<Subdivision> _subdivisions = [];
  List<Substation> _substations = [];

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHierarchyData();
  }

  Future<void> _loadHierarchyData() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });
    try {
      // Fetch States
      final statesSnapshot = await FirebaseFirestore.instance
          .collection('states')
          .get();
      _states = statesSnapshot.docs
          .map((doc) => AppScreenState.fromFirestore(doc))
          .toList();

      // Determine initial selection based on user role and assigned levels
      // Access assigned levels correctly using assignedLevels map
      if (widget.currentUser.role == UserRole.zoneManager) {
        final String? userZoneId = widget.currentUser.assignedLevels?['zoneId'];
        if (userZoneId != null) {
          _selectedScreenZoneId = userZoneId;
          await _fetchCircles(_selectedScreenZoneId!);
          await _fetchSubstationsForZone(_selectedScreenZoneId!);
        }
      } else if (widget.currentUser.role == UserRole.circleManager) {
        final String? userCircleId =
            widget.currentUser.assignedLevels?['circleId'];
        if (userCircleId != null) {
          _selectedScreenCircleId = userCircleId;
          // Fetch zone based on circle
          final circleDoc = await FirebaseFirestore.instance
              .collection('circles')
              .doc(_selectedScreenCircleId!)
              .get();
          // Null-safe cast for data access
          _selectedScreenZoneId = circleDoc.data()?['zoneId'] as String?;
          if (_selectedScreenZoneId != null) {
            await _fetchCircles(_selectedScreenZoneId!);
          }

          await _fetchDivisions(_selectedScreenCircleId!);
          await _fetchSubstationsForCircle(_selectedScreenCircleId!);
        }
      } else if (widget.currentUser.role == UserRole.divisionManager) {
        final String? userDivisionId =
            widget.currentUser.assignedLevels?['divisionId'];
        if (userDivisionId != null) {
          _selectedScreenDivisionId = userDivisionId;
          final divisionDoc = await FirebaseFirestore.instance
              .collection('divisions')
              .doc(_selectedScreenDivisionId!)
              .get();
          final String? circleId = divisionDoc.data()?['circleId'] as String?;
          if (circleId != null) {
            _selectedScreenCircleId = circleId;
            final circleDoc = await FirebaseFirestore.instance
                .collection('circles')
                .doc(circleId)
                .get();
            _selectedScreenZoneId = circleDoc.data()?['zoneId'] as String?;
            if (_selectedScreenZoneId != null) {
              await _fetchCircles(_selectedScreenZoneId!);
            }
          }
          await _fetchSubdivisions(_selectedScreenDivisionId!);
          await _fetchSubstationsForDivision(_selectedScreenDivisionId!);
        }
      } else if (widget.currentUser.role == UserRole.subdivisionManager) {
        final String? userSubdivisionId =
            widget.currentUser.assignedLevels?['subdivisionId'];
        if (userSubdivisionId != null) {
          _selectedScreenSubdivisionId = userSubdivisionId;
          final subdivisionDoc = await FirebaseFirestore.instance
              .collection('subdivisions')
              .doc(_selectedScreenSubdivisionId!)
              .get();
          final String? divisionId =
              subdivisionDoc.data()?['divisionId'] as String?;
          if (divisionId != null) {
            _selectedScreenDivisionId = divisionId;
            final divisionDoc = await FirebaseFirestore.instance
                .collection('divisions')
                .doc(divisionId)
                .get();
            final String? circleId = divisionDoc.data()?['circleId'] as String?;
            if (circleId != null) {
              _selectedScreenCircleId = circleId;
              final circleDoc = await FirebaseFirestore.instance
                  .collection('circles')
                  .doc(circleId)
                  .get();
              _selectedScreenZoneId = circleDoc.data()?['zoneId'] as String?;
              if (_selectedScreenZoneId != null) {
                await _fetchCircles(_selectedScreenZoneId!);
              }
            }
          }
          await _fetchSubstationsForSubdivision(_selectedScreenSubdivisionId!);
        }
      } else if (widget.currentUser.role == UserRole.substationUser) {
        // Correct role name from substationManager to substationUser
        final String? userSubstationId =
            widget.currentUser.assignedLevels?['substationId'];
        if (userSubstationId != null) {
          await _fetchSubstationById(userSubstationId);
        }
      }
    } catch (e) {
      if (mounted) {
        SnackBarUtils.showSnackBar(
          context,
          'Error loading hierarchy: $e',
          isError: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _fetchZones(String stateId) async {
    if (!mounted) return;
    setState(() {
      _zones = [];
      _selectedScreenZoneId = null;
      _circles = [];
      _selectedScreenCircleId = null;
      _divisions = [];
      _selectedScreenDivisionId = null;
      _subdivisions = [];
      _selectedScreenSubdivisionId = null;
      _substations = [];
    });
    final zonesSnapshot = await FirebaseFirestore.instance
        .collection('zones')
        .where('stateId', isEqualTo: stateId)
        .get();
    if (mounted) {
      setState(() {
        _zones = zonesSnapshot.docs
            .map((doc) => Zone.fromFirestore(doc))
            .toList();
      });
    }
  }

  Future<void> _fetchCircles(String zoneId) async {
    if (!mounted) return;
    setState(() {
      _circles = [];
      _selectedScreenCircleId = null;
      _divisions = [];
      _selectedScreenDivisionId = null;
      _subdivisions = [];
      _selectedScreenSubdivisionId = null;
      _substations = [];
    });
    final circlesSnapshot = await FirebaseFirestore.instance
        .collection('circles')
        .where('zoneId', isEqualTo: zoneId)
        .get();
    if (mounted) {
      setState(() {
        _circles = circlesSnapshot.docs
            .map((doc) => Circle.fromFirestore(doc))
            .toList();
      });
    }
  }

  Future<void> _fetchDivisions(String circleId) async {
    if (!mounted) return;
    setState(() {
      _divisions = [];
      _selectedScreenDivisionId = null;
      _subdivisions = [];
      _selectedScreenSubdivisionId = null;
      _substations = [];
    });
    final divisionsSnapshot = await FirebaseFirestore.instance
        .collection('divisions')
        .where('circleId', isEqualTo: circleId)
        .get();
    if (mounted) {
      setState(() {
        _divisions = divisionsSnapshot.docs
            .map((doc) => Division.fromFirestore(doc))
            .toList();
      });
    }
  }

  Future<void> _fetchSubdivisions(String divisionId) async {
    if (!mounted) return;
    setState(() {
      _subdivisions = [];
      _selectedScreenSubdivisionId = null;
      _substations = [];
    });
    final subdivisionsSnapshot = await FirebaseFirestore.instance
        .collection('subdivisions')
        .where('divisionId', isEqualTo: divisionId)
        .get();
    if (mounted) {
      setState(() {
        _subdivisions = subdivisionsSnapshot.docs
            .map((doc) => Subdivision.fromFirestore(doc))
            .toList();
      });
    }
  }

  Future<void> _fetchSubstationsForState(String stateId) async {
    if (!mounted) return;
    setState(() {
      _substations = [];
    });
    final substationsSnapshot = await FirebaseFirestore.instance
        .collection('substations')
        .where('stateId', isEqualTo: stateId)
        .get();
    if (mounted) {
      setState(() {
        _substations = substationsSnapshot.docs
            .map((doc) => Substation.fromFirestore(doc))
            .toList();
      });
    }
  }

  Future<void> _fetchSubstationsForZone(String zoneId) async {
    if (!mounted) return;
    setState(() {
      _substations = [];
    });
    final substationsSnapshot = await FirebaseFirestore.instance
        .collection('substations')
        .where('zoneId', isEqualTo: zoneId)
        .get();
    if (mounted) {
      setState(() {
        _substations = substationsSnapshot.docs
            .map((doc) => Substation.fromFirestore(doc))
            .toList();
      });
    }
  }

  Future<void> _fetchSubstationsForCircle(String circleId) async {
    if (!mounted) return;
    setState(() {
      _substations = [];
    });
    final substationsSnapshot = await FirebaseFirestore.instance
        .collection('substations')
        .where('circleId', isEqualTo: circleId)
        .get();
    if (mounted) {
      setState(() {
        _substations = substationsSnapshot.docs
            .map((doc) => Substation.fromFirestore(doc))
            .toList();
      });
    }
  }

  Future<void> _fetchSubstationsForDivision(String divisionId) async {
    if (!mounted) return;
    setState(() {
      _substations = [];
    });
    final substationsSnapshot = await FirebaseFirestore.instance
        .collection('substations')
        .where('divisionId', isEqualTo: divisionId)
        .get();
    if (mounted) {
      setState(() {
        _substations = substationsSnapshot.docs
            .map((doc) => Substation.fromFirestore(doc))
            .toList();
      });
    }
  }

  Future<void> _fetchSubstationsForSubdivision(String subdivisionId) async {
    if (!mounted) return;
    setState(() {
      _substations = [];
    });
    final substationsSnapshot = await FirebaseFirestore.instance
        .collection('substations')
        .where('subdivisionId', isEqualTo: subdivisionId)
        .get();
    if (mounted) {
      setState(() {
        _substations = substationsSnapshot.docs
            .map((doc) => Substation.fromFirestore(doc))
            .toList();
      });
    }
  }

  Future<void> _fetchSubstationById(String substationId) async {
    if (!mounted) return;
    setState(() {
      _substations = [];
    });
    final substationDoc = await FirebaseFirestore.instance
        .collection('substations')
        .doc(substationId)
        .get();
    if (mounted && substationDoc.exists) {
      setState(() {
        _substations.add(Substation.fromFirestore(substationDoc));
      });
    }
  }

  bool _canAccessDropdown(UserRole dropdownRole) {
    if (widget.currentUser.role == UserRole.admin) {
      return true;
    }
    switch (dropdownRole) {
      // Corrected role name usage here
      case UserRole.stateManager:
        return widget.currentUser.role == UserRole.stateManager ||
            widget.currentUser.role == UserRole.zoneManager ||
            widget.currentUser.role == UserRole.circleManager ||
            widget.currentUser.role == UserRole.divisionManager ||
            widget.currentUser.role == UserRole.subdivisionManager ||
            widget.currentUser.role == UserRole.substationUser;
      case UserRole.zoneManager:
        return widget.currentUser.role == UserRole.zoneManager ||
            widget.currentUser.role == UserRole.circleManager ||
            widget.currentUser.role == UserRole.divisionManager ||
            widget.currentUser.role == UserRole.subdivisionManager ||
            widget.currentUser.role == UserRole.substationUser;
      case UserRole.circleManager:
        return widget.currentUser.role == UserRole.circleManager ||
            widget.currentUser.role == UserRole.divisionManager ||
            widget.currentUser.role == UserRole.subdivisionManager ||
            widget.currentUser.role == UserRole.substationUser;
      case UserRole.divisionManager:
        return widget.currentUser.role == UserRole.divisionManager ||
            widget.currentUser.role == UserRole.subdivisionManager ||
            widget.currentUser.role == UserRole.substationUser;
      case UserRole.subdivisionManager:
        return widget.currentUser.role == UserRole.subdivisionManager ||
            widget.currentUser.role == UserRole.substationUser;
      case UserRole.substationUser: // Corrected role name here
        return widget.currentUser.role == UserRole.substationUser;
      case UserRole
          .pending: // Handle pending explicitly if needed, or it will go to default
      case UserRole.admin: // Admin case handled at the top of the method
        return false;
      default:
        return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Loading Hierarchy'),
        ), // Removed const from Text as per common issue
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Select Substation')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Check roles and assigned levels for visibility
            if (widget.currentUser.role == UserRole.admin ||
                _canAccessDropdown(
                  UserRole.stateManager,
                )) // Use _canAccessDropdown helper
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: DropdownSearch<AppScreenState>(
                  popupProps: const PopupProps.menu(
                    showSearchBox: true,
                    fit: FlexFit.loose,
                  ),
                  dropdownDecoratorProps: const DropDownDecoratorProps(
                    // Corrected casing
                    dropdownSearchDecoration: InputDecoration(
                      labelText: 'Select State',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  itemAsString: (AppScreenState s) => s.name,
                  items: _states,
                  selectedItem: _states.firstWhereOrNull(
                    (state) => state.id == _selectedScreenStateId,
                  ),
                  onChanged: (newValue) {
                    if (newValue != null) {
                      setState(() {
                        _selectedScreenStateId = newValue.id;
                        _selectedScreenZoneId = null;
                        _selectedScreenCircleId = null;
                        _selectedScreenDivisionId = null;
                        _selectedScreenSubdivisionId = null;
                        _substations
                            .clear(); // Clear substations when state changes
                      });
                      _fetchZones(newValue.id);
                      _fetchSubstationsForState(newValue.id);
                    }
                  },
                ),
              ),
            if (widget.currentUser.role == UserRole.admin ||
                _canAccessDropdown(
                  UserRole.zoneManager,
                )) // Use _canAccessDropdown helper
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: DropdownSearch<Zone>(
                  popupProps: const PopupProps.menu(
                    showSearchBox: true,
                    fit: FlexFit.loose,
                  ),
                  dropdownDecoratorProps: const DropDownDecoratorProps(
                    // Corrected casing
                    dropdownSearchDecoration: InputDecoration(
                      labelText: 'Select Zone',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  itemAsString: (Zone z) => z.name,
                  items: _zones,
                  selectedItem: _zones.firstWhereOrNull(
                    (zone) => zone.id == _selectedScreenZoneId,
                  ),
                  onChanged: (newValue) {
                    if (newValue != null) {
                      setState(() {
                        _selectedScreenZoneId = newValue.id;
                        _selectedScreenCircleId = null;
                        _selectedScreenDivisionId = null;
                        _selectedScreenSubdivisionId = null;
                        _substations
                            .clear(); // Clear substations when zone changes
                      });
                      _fetchCircles(newValue.id);
                      _fetchSubstationsForZone(newValue.id);
                    }
                  },
                ),
              ),
            if (widget.currentUser.role == UserRole.admin ||
                _canAccessDropdown(
                  UserRole.circleManager,
                )) // Use _canAccessDropdown helper
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: DropdownSearch<Circle>(
                  popupProps: const PopupProps.menu(
                    showSearchBox: true,
                    fit: FlexFit.loose,
                  ),
                  dropdownDecoratorProps: const DropDownDecoratorProps(
                    // Corrected casing
                    dropdownSearchDecoration: InputDecoration(
                      labelText: 'Select Circle',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  itemAsString: (Circle c) => c.name,
                  items: _circles,
                  selectedItem: _circles.firstWhereOrNull(
                    (circle) => circle.id == _selectedScreenCircleId,
                  ),
                  onChanged: (newValue) {
                    if (newValue != null) {
                      setState(() {
                        _selectedScreenCircleId = newValue.id;
                        _selectedScreenDivisionId = null;
                        _selectedScreenSubdivisionId = null;
                        _substations
                            .clear(); // Clear substations when circle changes
                      });
                      _fetchDivisions(newValue.id);
                      _fetchSubstationsForCircle(newValue.id);
                    }
                  },
                ),
              ),
            if (widget.currentUser.role == UserRole.admin ||
                _canAccessDropdown(
                  UserRole.divisionManager,
                )) // Use _canAccessDropdown helper
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: DropdownSearch<Division>(
                  popupProps: const PopupProps.menu(
                    showSearchBox: true,
                    fit: FlexFit.loose,
                  ),
                  dropdownDecoratorProps: const DropDownDecoratorProps(
                    // Corrected casing
                    dropdownSearchDecoration: InputDecoration(
                      labelText: 'Select Division',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  itemAsString: (Division d) => d.name,
                  items: _divisions,
                  selectedItem: _divisions.firstWhereOrNull(
                    (division) => division.id == _selectedScreenDivisionId,
                  ),
                  onChanged: (newValue) {
                    if (newValue != null) {
                      setState(() {
                        _selectedScreenDivisionId = newValue.id;
                        _selectedScreenSubdivisionId = null;
                        _substations
                            .clear(); // Clear substations when division changes
                      });
                      _fetchSubdivisions(newValue.id);
                      _fetchSubstationsForDivision(newValue.id);
                    }
                  },
                ),
              ),
            if (widget.currentUser.role == UserRole.admin ||
                _canAccessDropdown(
                  UserRole.subdivisionManager,
                )) // Use _canAccessDropdown helper
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: DropdownSearch<Subdivision>(
                  popupProps: const PopupProps.menu(
                    showSearchBox: true,
                    fit: FlexFit.loose,
                  ),
                  dropdownDecoratorProps: const DropDownDecoratorProps(
                    // Corrected casing
                    dropdownSearchDecoration: InputDecoration(
                      labelText: 'Select Subdivision',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  itemAsString: (Subdivision s) => s.name,
                  items: _subdivisions,
                  selectedItem: _subdivisions.firstWhereOrNull(
                    (subdivision) =>
                        subdivision.id == _selectedScreenSubdivisionId,
                  ),
                  onChanged: (newValue) {
                    if (newValue != null) {
                      setState(() {
                        _selectedScreenSubdivisionId = newValue.id;
                        _substations
                            .clear(); // Clear substations when subdivision changes
                      });
                      _fetchSubstationsForSubdivision(newValue.id);
                    }
                  },
                ),
              ),
            // Corrected role name for substationUser and using _canAccessDropdown
            if (_canAccessDropdown(UserRole.substationUser))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: DropdownSearch<Substation>(
                  popupProps: const PopupProps.menu(
                    showSearchBox: true,
                    fit: FlexFit.loose,
                  ),
                  dropdownDecoratorProps: const DropDownDecoratorProps(
                    // Corrected casing
                    dropdownSearchDecoration: InputDecoration(
                      labelText: 'Select Substation',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  itemAsString: (Substation s) => s.name,
                  items: _substations,
                  // For substation user, pre-select their substation
                  selectedItem:
                      widget.currentUser.role == UserRole.substationUser
                      ? _substations.firstWhereOrNull(
                          (sub) =>
                              sub.id ==
                              widget
                                  .currentUser
                                  .assignedLevels?['substationId'], // Corrected assignedLevels access
                        )
                      : null,
                  onChanged: (newValue) {
                    if (newValue != null) {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => ChangeNotifierProvider(
                            create: (context) => SldController(
                              substationId:
                                  newValue.id, // Pass the actual substation ID
                              transformationController:
                                  TransformationController(), // Provide a new controller
                            ),
                            child: SubstationDetailScreen(
                              substationId: newValue.id,
                              substationName: newValue.name,
                              currentUser: widget.currentUser,
                            ),
                          ),
                        ),
                      );
                    }
                  },
                ),
              ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
