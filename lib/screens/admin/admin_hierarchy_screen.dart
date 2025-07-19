// lib/screens/admin/admin_hierarchy_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/hierarchy_models.dart';
import '../../models/app_state_data.dart'; // Contains StateModel and CityModel
import 'package:dropdown_search/dropdown_search.dart';
import 'package:provider/provider.dart'; // Required for Consumer and Provider.of
// REMOVED: import '../../models/bay_model.dart'; // No longer needed
import '../../models/user_model.dart'; // Assuming AppUser model exists
import '../../utils/snackbar_utils.dart'; // Assuming SnackBarUtils exists
import 'package:flutter/foundation.dart'; // Import for debugPrint

// --- _AddEditHierarchyItemForm ---
class _AddEditHierarchyItemForm extends StatefulWidget {
  final String itemType;
  final String? parentId;
  final String? parentName;
  final String? parentCollectionName;
  final HierarchyItem? itemToEdit;
  final Function(
    String collectionName,
    Map<String, dynamic> data,
    GlobalKey<FormState> formKey,
    String? docId,
  )
  onAddItem;

  const _AddEditHierarchyItemForm({
    super.key,
    required this.itemType,
    this.parentId,
    this.parentName,
    this.parentCollectionName,
    this.itemToEdit,
    required this.onAddItem,
  });

  @override
  _AddEditHierarchyItemFormState createState() =>
      _AddEditHierarchyItemFormState();
}

class _AddEditHierarchyItemFormState extends State<_AddEditHierarchyItemForm>
    with SingleTickerProviderStateMixin {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController nameController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();
  final TextEditingController landmarkController = TextEditingController();
  final TextEditingController contactNumberController = TextEditingController();
  final TextEditingController contactPersonController = TextEditingController();
  final TextEditingController addressController = TextEditingController();
  final TextEditingController substationAddressController =
      TextEditingController();
  final TextEditingController statusDescriptionController =
      TextEditingController();
  final TextEditingController voltageLevelController = TextEditingController();
  final TextEditingController typeController = TextEditingController();
  final TextEditingController sasMakeController = TextEditingController();
  // REMOVED: final TextEditingController multiplyingFactorController = TextEditingController();

  Timestamp? commissioningDate;
  String?
  bottomSheetSelectedState; // Stores StateModel.id.toString() (e.g., "34.0")
  String? bottomSheetSelectedCompany;
  String? bottomSheetSelectedZone;
  String? bottomSheetSelectedCircle;
  String? bottomSheetSelectedDivision;
  String? bottomSheetSelectedSubdivision;

  double? selectedCityId;
  String? selectedCityName; // Used for displaying city name in DropdownSearch
  String? selectedVoltageLevel;
  // REMOVED: String? selectedBayType;
  String? selectedContactDesignation;
  String? selectedOperation;
  String? selectedStatus;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  final List<String> contactDesignations = [
    'CE',
    'SE',
    'EE',
    'SDO',
    'JE',
    'Control Room',
  ];

  // REMOVED: final List<String> bayTypes = [...];

  final List<String> operationTypes = ['Manual', 'SAS'];

  // Add a boolean flag to track if initialization is complete
  bool _isInitializing = true;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _animationController.forward();

    // Delay initialization until after the first frame to ensure context is available
    // and Provider data (`AppStateData`) has had a chance to load.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeFormFields().then((_) {
        if (mounted) {
          setState(() {
            _isInitializing = false; // Mark initialization as complete
          });
        }
      });
    });
  }

  @override
  void dispose() {
    nameController.dispose();
    descriptionController.dispose();
    landmarkController.dispose();
    contactNumberController.dispose();
    contactPersonController.dispose();
    addressController.dispose();
    substationAddressController.dispose();
    voltageLevelController.dispose();
    typeController.dispose();
    sasMakeController.dispose();
    statusDescriptionController.dispose();
    // REMOVED: multiplyingFactorController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _initializeFormFields() async {
    debugPrint(
      'DEBUG: _AddEditHierarchyItemFormState: Initializing form for itemType: ${widget.itemType}',
    );

    // Common fields initialization (for editing existing items)
    if (widget.itemToEdit != null) {
      debugPrint(
        'DEBUG: _AddEditHierarchyItemFormState: Item to edit found: ${widget.itemToEdit!.name} (ID: ${widget.itemToEdit!.id})',
      );
      nameController.text = widget.itemToEdit!.name;
      descriptionController.text = widget.itemToEdit!.description ?? '';
      landmarkController.text = widget.itemToEdit!.landmark ?? '';
      contactNumberController.text = widget.itemToEdit!.contactNumber ?? '';
      contactPersonController.text = widget.itemToEdit!.contactPerson ?? '';
      selectedContactDesignation = widget.itemToEdit!.contactDesignation;
      addressController.text = widget.itemToEdit!.address ?? '';

      // Set specific fields for Substation if editing a Substation
      if (widget.itemToEdit is Substation) {
        final item = widget.itemToEdit as Substation;
        substationAddressController.text = item.address ?? '';
        voltageLevelController.text = item.voltageLevel ?? '';
        typeController.text = item.type ?? '';
        sasMakeController.text = item.sasMake ?? '';
        commissioningDate = item.commissioningDate;
        selectedVoltageLevel = item.voltageLevel;
        selectedOperation = item.operation;
        selectedStatus = item.status;
        statusDescriptionController.text = item.statusDescription ?? '';

        if (item.cityId != null) {
          selectedCityId = double.tryParse(item.cityId!);
          // Access AppStateData after first frame to ensure it's initialized
          final appState = Provider.of<AppStateData>(context, listen: false);
          final city = appState.allCityModels.firstWhere(
            (c) => c.id == selectedCityId,
            orElse: () => CityModel(id: -1, name: '', stateId: -1),
          );
          if (city.id != -1) selectedCityName = city.name;
        }
      }
    } else {
      debugPrint('DEBUG: _AddEditHierarchyItemFormState: Adding new item.');
      selectedOperation = 'Manual'; // Default for new substations
      selectedStatus = 'Working'; // Default for new substations
    }

    String?
    directParentIdFromFirestore; // This will hold the actual Firestore ID of the direct parent
    String?
    directParentCollection; // This will hold the collection name of the direct parent

    if (widget.itemToEdit != null) {
      // When editing, retrieve the direct parent's ID and collection from the itemToEdit itself
      if (widget.itemToEdit is Company) {
        // For Company, its stateId is the document ID (name) of the state.
        directParentIdFromFirestore = (widget.itemToEdit as Company).stateId;
        directParentCollection = 'appscreenstates';
      } else if (widget.itemToEdit is Zone) {
        directParentIdFromFirestore = (widget.itemToEdit as Zone).companyId;
        directParentCollection = 'companys';
      } else if (widget.itemToEdit is Circle) {
        directParentIdFromFirestore = (widget.itemToEdit as Circle).zoneId;
        directParentCollection = 'zones';
      } else if (widget.itemToEdit is Division) {
        directParentIdFromFirestore = (widget.itemToEdit as Division).circleId;
        directParentCollection = 'circles';
      } else if (widget.itemToEdit is Subdivision) {
        directParentIdFromFirestore =
            (widget.itemToEdit as Subdivision).divisionId;
        directParentCollection = 'divisions';
      } else if (widget.itemToEdit is Substation) {
        directParentIdFromFirestore =
            (widget.itemToEdit as Substation).subdivisionId;
        directParentCollection = 'subdivisions';
      }
    } else if (widget.parentId != null && widget.parentCollectionName != null) {
      // When adding, use the provided parentId and parentCollectionName
      directParentIdFromFirestore = widget.parentId;
      directParentCollection = widget.parentCollectionName;
    }

    // Now, use the identified direct parent to find the full ancestry of IDs
    if (directParentIdFromFirestore != null && directParentCollection != null) {
      final appState = Provider.of<AppStateData>(context, listen: false);

      if (directParentCollection == 'appscreenstates') {
        // If the direct parent is an AppScreenState, its Firestore ID is its name.
        // We need to convert this name to the numeric ID for `bottomSheetSelectedState`.
        final stateNameFromFirestore = directParentIdFromFirestore;
        final stateModel = appState.allStateModels.firstWhere(
          (s) => s.name == stateNameFromFirestore,
          orElse: () => StateModel(id: -1, name: ''), // Fallback
        );
        if (stateModel.id != -1) {
          if (mounted) {
            setState(() {
              bottomSheetSelectedState = stateModel.id.toString();
              debugPrint(
                'DEBUG: Initialized State to ID: $bottomSheetSelectedState (from name: $stateNameFromFirestore)',
              );
            });
          }
        } else {
          debugPrint(
            'WARNING: _initializeFormFields: State name "$stateNameFromFirestore" (from Firestore) not found in AppStateData.',
          );
        }
      } else {
        // For other hierarchy levels, _findParentHierarchy will get the chain of parent IDs.
        final Map<String, String?> parents = await _findParentHierarchy(
          directParentCollection,
          directParentIdFromFirestore,
        );

        if (mounted) {
          setState(() {
            // Apply IDs to all relevant dropdowns.
            // For 'stateId', ensure we fetch the numeric ID from AppStateData if `parents['stateId']` is a name.
            if (parents['stateId'] != null) {
              final stateModel = appState.allStateModels.firstWhere(
                (s) =>
                    s.name ==
                    parents['stateId'], // Assuming parents['stateId'] is the state name from AppScreenState document
                orElse: () => StateModel(id: -1, name: ''),
              );
              if (stateModel.id != -1) {
                bottomSheetSelectedState = stateModel.id.toString();
                debugPrint(
                  'DEBUG: Initialized State to ID: $bottomSheetSelectedState (from _findParentHierarchy name: ${parents['stateId']})',
                );
              } else {
                debugPrint(
                  'WARNING: _initializeFormFields: State ID from hierarchy (${parents['stateId']}) not found in AppStateData for parent chain.',
                );
              }
            } else {
              bottomSheetSelectedState = null; // No state found in hierarchy
            }

            bottomSheetSelectedCompany = parents['companyId'];
            bottomSheetSelectedZone = parents['zoneId'];
            bottomSheetSelectedCircle = parents['circleId'];
            bottomSheetSelectedDivision = parents['divisionId'];
            bottomSheetSelectedSubdivision = parents['subdivisionId'];
          });
        }
      }
    }

    // Mark initialization complete
    if (mounted) {
      setState(() {
        _isInitializing = false;
      });
    }
  }

  Future<Map<String, String?>> _findParentHierarchy(
    String childCollection,
    String childId,
  ) async {
    Map<String, String?> hierarchy = {};
    try {
      DocumentSnapshot childDoc = await FirebaseFirestore.instance
          .collection(childCollection)
          .doc(childId)
          .get();

      if (!childDoc.exists || childDoc.data() == null) {
        debugPrint(
          'WARNING: _findParentHierarchy: Child doc $childId in $childCollection not found.',
        );
        return hierarchy;
      }

      final data = childDoc.data() as Map<String, dynamic>;

      // Recursively find all parents up the chain
      // Note: For 'appscreenstates', the 'id' of the StateModel is a double,
      // but the Firestore document ID is the state name string.
      // So, data['stateId'] from Company will be the state *name*.
      // We need to return this 'name' as stateId here, and convert it later
      // when assigning to bottomSheetSelectedState.
      if (childCollection == 'companys') {
        hierarchy['stateId'] =
            data['stateId']; // This will be the state name (e.g., "Uttar Pradesh")
      } else if (childCollection == 'zones') {
        hierarchy['companyId'] = data['companyId'];
        if (data['companyId'] != null) {
          final companyParents = await _findParentHierarchy(
            'companys',
            data['companyId'],
          );
          hierarchy.addAll(companyParents);
        }
      } else if (childCollection == 'circles') {
        hierarchy['zoneId'] = data['zoneId'];
        if (data['zoneId'] != null) {
          final zoneParents = await _findParentHierarchy(
            'zones',
            data['zoneId'],
          );
          hierarchy.addAll(zoneParents);
        }
      } else if (childCollection == 'divisions') {
        hierarchy['circleId'] = data['circleId'];
        if (data['circleId'] != null) {
          final circleParents = await _findParentHierarchy(
            'circles',
            data['circleId'],
          );
          hierarchy.addAll(circleParents);
        }
      } else if (childCollection == 'subdivisions') {
        hierarchy['divisionId'] = data['divisionId'];
        if (data['divisionId'] != null) {
          final divisionParents = await _findParentHierarchy(
            'divisions',
            data['divisionId'],
          );
          hierarchy.addAll(divisionParents);
        }
      } else if (childCollection == 'substations') {
        hierarchy['subdivisionId'] = data['subdivisionId'];
        if (data['subdivisionId'] != null) {
          final subdivisionParents = await _findParentHierarchy(
            'subdivisions',
            data['subdivisionId'],
          );
          hierarchy.addAll(subdivisionParents);
        }
      }
    } catch (e) {
      debugPrint(
        "ERROR: _findParentHierarchy: Error finding parent hierarchy for $childCollection/$childId: $e",
      );
    }
    return hierarchy;
  }

  Future<void> _selectCommissioningDate(BuildContext context) async {
    debugPrint(
      'DEBUG: _AddEditHierarchyItemFormState: _selectCommissioningDate called.',
    );
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: commissioningDate?.toDate() ?? DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime(2200),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: Theme.of(context).colorScheme.primary,
              onPrimary: Theme.of(context).colorScheme.onPrimary,
              surface: Theme.of(context).colorScheme.surface,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != commissioningDate?.toDate()) {
      setState(() {
        commissioningDate = Timestamp.fromDate(picked);
        debugPrint(
          'DEBUG: _AddEditHierarchyItemFormState: Commissioning date selected: $commissioningDate',
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isEditing = widget.itemToEdit != null;
    debugPrint(
      'DEBUG: _AddEditHierarchyItemFormState: Building form for itemType: ${widget.itemType}, isEditing: $isEditing',
    );

    // Show a loading indicator if initialization is still in progress
    if (_isInitializing) {
      return Container(
        height: 200, // Or adjust as needed
        alignment: Alignment.center,
        child: const CircularProgressIndicator(),
      );
    }

    // Get AppStateData for dropdowns
    final appState = Provider.of<AppStateData>(context);

    return FadeTransition(
      opacity: _fadeAnimation,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: SingleChildScrollView(
          child: Container(
            padding: const EdgeInsets.all(24.0),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 48,
                    height: 6,
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  isEditing
                      ? 'Edit ${widget.itemType}'
                      : widget.itemType == 'AppScreenState'
                      ? 'Add New State'
                      : 'Add New ${widget.itemType}',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                if (widget.parentName != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      'Under: ${widget.parentName}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withOpacity(0.7),
                      ),
                    ),
                  ),
                const SizedBox(height: 24),
                Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Conditional input for AppScreenState (only for adding a new top-level state)
                      // This dropdown is for selecting a *name* to be the document ID for the state.
                      if (widget.itemType == 'AppScreenState')
                        DropdownSearch<String>(
                          selectedItem: nameController.text.isNotEmpty
                              ? nameController.text
                              : null, // Set name directly
                          popupProps: PopupProps.menu(
                            showSearchBox: true,
                            menuProps: MenuProps(
                              borderRadius: BorderRadius.circular(12),
                              elevation: 4,
                            ),
                            searchFieldProps: TextFieldProps(
                              decoration: InputDecoration(
                                labelText: 'Search State',
                                prefixIcon: Icon(
                                  Icons.search,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurface.withOpacity(0.2),
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                    width: 2,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          itemAsString: (String s) => s,
                          asyncItems: (String filter) async {
                            final existingFirestoreStates =
                                await FirebaseFirestore.instance
                                    .collection('appscreenstates')
                                    .get()
                                    .then(
                                      (snapshot) => snapshot.docs
                                          .map((doc) => doc.id)
                                          .toSet(),
                                    );
                            final filteredStates = appState.states
                                .where(
                                  (stateName) =>
                                      stateName.toLowerCase().contains(
                                        filter.toLowerCase(),
                                      ) &&
                                      // Only show states not already in Firestore as a top-level item
                                      !existingFirestoreStates.contains(
                                        stateName,
                                      ),
                                )
                                .toList();
                            return filteredStates;
                          },
                          dropdownDecoratorProps: DropDownDecoratorProps(
                            dropdownSearchDecoration: InputDecoration(
                              labelText: 'Select State Name',
                              hintText:
                                  'Choose a state name for the new record',
                              prefixIcon: Icon(
                                Icons.map,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurface.withOpacity(0.2),
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: Theme.of(context).colorScheme.primary,
                                  width: 2,
                                ),
                              ),
                              helperText:
                                  'Search or select a state from the list to create a top-level entry',
                            ),
                          ),
                          onChanged: (String? newValue) {
                            setState(() {
                              // For AppScreenState, the name *is* the ID in Firestore, and the display value.
                              // So, we set both nameController and bottomSheetSelectedState to the name.
                              nameController.text = newValue ?? '';
                              bottomSheetSelectedState = newValue;
                              debugPrint(
                                'DEBUG: AppScreenState selected: $newValue',
                              );
                            });
                          },
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please select a state name';
                            }
                            return null;
                          },
                        ),
                      // General name field for other hierarchy items (Company, Zone, etc.)
                      if (widget.itemType != 'AppScreenState')
                        TextFormField(
                          controller: nameController,
                          decoration: InputDecoration(
                            labelText: '${widget.itemType} Name',
                            prefixIcon: Icon(
                              Icons.edit_note,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            helperText: 'Enter a unique name',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurface.withOpacity(0.2),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: Theme.of(context).colorScheme.primary,
                                width: 2,
                              ),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter a name';
                            }
                            return null;
                          },
                        ),

                      // Parent State selection (AppScreenState is excluded as it's the top level)
                      if (widget.itemType != 'AppScreenState') ...[
                        const SizedBox(height: 16),
                        InkWell(
                          onTap: bottomSheetSelectedState != null && isEditing
                              ? () {
                                  SnackBarUtils.showSnackBar(
                                    context,
                                    'State is pre-filled and cannot be changed for existing items.',
                                  );
                                }
                              : null,
                          child: AbsorbPointer(
                            absorbing:
                                bottomSheetSelectedState != null && isEditing,
                            child: DropdownButtonFormField<String>(
                              value:
                                  bottomSheetSelectedState, // This MUST be the StateModel.id.toString()
                              decoration: InputDecoration(
                                labelText: 'Parent State',
                                prefixIcon: Icon(
                                  Icons.map,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                                helperText: 'Choose a parent state',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurface.withOpacity(0.2),
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                    width: 2,
                                  ),
                                ),
                              ),
                              isExpanded: true,
                              items: appState.allStateModels.map((stateItem) {
                                return DropdownMenuItem<String>(
                                  value: stateItem.id
                                      .toString(), // Value is the numeric ID as a string
                                  child: Text(
                                    stateItem.name, // Display is the state name
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodyMedium,
                                  ),
                                );
                              }).toList(),
                              onChanged:
                                  isEditing // Disable onChanged if editing
                                  ? null
                                  : (String? newValue) {
                                      setState(() {
                                        bottomSheetSelectedState = newValue;
                                        // Reset all dependent dropdowns when state changes
                                        bottomSheetSelectedCompany = null;
                                        bottomSheetSelectedZone = null;
                                        bottomSheetSelectedCircle = null;
                                        bottomSheetSelectedDivision = null;
                                        bottomSheetSelectedSubdivision = null;
                                        selectedCityId = null;
                                        selectedCityName = null;
                                        debugPrint(
                                          'DEBUG: Parent State selected: $newValue',
                                        );
                                      });
                                    },
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please select a parent state';
                                }
                                return null;
                              },
                            ),
                          ),
                        ),
                      ],

                      // Company selection
                      if (widget.itemType != 'AppScreenState' &&
                          widget.itemType != 'Company') ...[
                        const SizedBox(height: 16),
                        StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('companys')
                              .where(
                                'stateId',
                                isEqualTo: bottomSheetSelectedState != null
                                    ? appState.allStateModels
                                          .firstWhere(
                                            (s) =>
                                                s.id.toString() ==
                                                bottomSheetSelectedState,
                                            orElse: () =>
                                                StateModel(id: -1, name: ''),
                                          )
                                          .name // Convert ID back to name for Firestore query
                                    : null,
                              )
                              .orderBy('name')
                              .snapshots(),
                          builder: (context, snapshot) {
                            if (snapshot.hasError) {
                              return Text(
                                'Error loading companies: ${snapshot.error}',
                              );
                            }
                            if (bottomSheetSelectedState == null) {
                              return const Text(
                                'Select a state first to load companies.',
                              );
                            }
                            if (!snapshot.hasData ||
                                snapshot.data!.docs.isEmpty) {
                              return const Text(
                                'No companies available for the selected state.',
                              );
                            }
                            final companies = snapshot.data!.docs
                                .map((doc) => Company.fromFirestore(doc))
                                .toList();
                            return InkWell(
                              onTap:
                                  bottomSheetSelectedCompany != null &&
                                      isEditing
                                  ? () {
                                      SnackBarUtils.showSnackBar(
                                        context,
                                        'Company is pre-filled and cannot be changed for existing items.',
                                      );
                                    }
                                  : null,
                              child: AbsorbPointer(
                                absorbing:
                                    bottomSheetSelectedCompany != null &&
                                    isEditing,
                                child: DropdownButtonFormField<String>(
                                  value: bottomSheetSelectedCompany,
                                  decoration: InputDecoration(
                                    labelText: 'Select Company',
                                    prefixIcon: Icon(
                                      Icons.business,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                    ),
                                    helperText: 'Choose a company',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface
                                            .withOpacity(0.2),
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.primary,
                                        width: 2,
                                      ),
                                    ),
                                  ),
                                  isExpanded: true,
                                  items: companies.map((company) {
                                    return DropdownMenuItem<String>(
                                      value: company.id,
                                      child: Text(
                                        company.name,
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 1,
                                        style: Theme.of(
                                          context,
                                        ).textTheme.bodyMedium,
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: isEditing
                                      ? null
                                      : (String? newValue) {
                                          setState(() {
                                            bottomSheetSelectedCompany =
                                                newValue;
                                            bottomSheetSelectedZone = null;
                                            bottomSheetSelectedCircle = null;
                                            bottomSheetSelectedDivision = null;
                                            bottomSheetSelectedSubdivision =
                                                null;
                                            selectedCityId = null;
                                            selectedCityName = null;
                                            debugPrint(
                                              'DEBUG: Parent Company selected: $newValue',
                                            );
                                          });
                                        },
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Please select a company';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                            );
                          },
                        ),
                      ],

                      // Zone selection
                      if (widget.itemType != 'AppScreenState' &&
                          widget.itemType != 'Company' &&
                          widget.itemType != 'Zone') ...[
                        const SizedBox(height: 16),
                        StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('zones')
                              .where(
                                'companyId',
                                isEqualTo: bottomSheetSelectedCompany,
                              )
                              .orderBy('name')
                              .snapshots(),
                          builder: (context, snapshot) {
                            if (snapshot.hasError) {
                              return Text(
                                'Error loading zones: ${snapshot.error}',
                              );
                            }
                            if (bottomSheetSelectedCompany == null) {
                              return const Text(
                                'Select a company first to load zones.',
                              );
                            }
                            if (!snapshot.hasData ||
                                snapshot.data!.docs.isEmpty) {
                              return const Text(
                                'No zones available for the selected company.',
                              );
                            }
                            final zones = snapshot.data!.docs
                                .map((doc) => Zone.fromFirestore(doc))
                                .toList();
                            return InkWell(
                              onTap:
                                  bottomSheetSelectedZone != null && isEditing
                                  ? () {
                                      SnackBarUtils.showSnackBar(
                                        context,
                                        'Zone is pre-filled and cannot be changed for existing items.',
                                      );
                                    }
                                  : null,
                              child: AbsorbPointer(
                                absorbing:
                                    bottomSheetSelectedZone != null &&
                                    isEditing,
                                child: DropdownButtonFormField<String>(
                                  value: bottomSheetSelectedZone,
                                  decoration: InputDecoration(
                                    labelText: 'Select Zone',
                                    prefixIcon: Icon(
                                      Icons.location_on,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                    ),
                                    helperText: 'Choose a zone',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface
                                            .withOpacity(0.2),
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.primary,
                                        width: 2,
                                      ),
                                    ),
                                  ),
                                  isExpanded: true,
                                  items: zones.map((zone) {
                                    return DropdownMenuItem<String>(
                                      value: zone.id,
                                      child: Text(
                                        zone.name,
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 1,
                                        style: Theme.of(
                                          context,
                                        ).textTheme.bodyMedium,
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: isEditing
                                      ? null
                                      : (String? newValue) {
                                          setState(() {
                                            bottomSheetSelectedZone = newValue;
                                            bottomSheetSelectedCircle = null;
                                            bottomSheetSelectedDivision = null;
                                            bottomSheetSelectedSubdivision =
                                                null;
                                            selectedCityId = null;
                                            selectedCityName = null;
                                            debugPrint(
                                              'DEBUG: Parent Zone selected: $newValue',
                                            );
                                          });
                                        },
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Please select a zone';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                            );
                          },
                        ),
                      ],

                      // Circle selection
                      if (widget.itemType != 'AppScreenState' &&
                          widget.itemType != 'Company' &&
                          widget.itemType != 'Zone' &&
                          widget.itemType != 'Circle') ...[
                        const SizedBox(height: 16),
                        StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('circles')
                              .where(
                                'zoneId',
                                isEqualTo: bottomSheetSelectedZone,
                              )
                              .orderBy('name')
                              .snapshots(),
                          builder: (context, snapshot) {
                            if (snapshot.hasError) {
                              return Text(
                                'Error loading circles: ${snapshot.error}',
                              );
                            }
                            if (bottomSheetSelectedZone == null) {
                              return const Text(
                                'Select a zone first to load circles.',
                              );
                            }
                            if (!snapshot.hasData ||
                                snapshot.data!.docs.isEmpty) {
                              return const Text(
                                'No circles available for the selected zone.',
                              );
                            }
                            final circles = snapshot.data!.docs
                                .map((doc) => Circle.fromFirestore(doc))
                                .toList();
                            return InkWell(
                              onTap:
                                  bottomSheetSelectedCircle != null && isEditing
                                  ? () {
                                      SnackBarUtils.showSnackBar(
                                        context,
                                        'Circle is pre-filled and cannot be changed for existing items.',
                                      );
                                    }
                                  : null,
                              child: AbsorbPointer(
                                absorbing:
                                    bottomSheetSelectedCircle != null &&
                                    isEditing,
                                child: DropdownButtonFormField<String>(
                                  value: bottomSheetSelectedCircle,
                                  decoration: InputDecoration(
                                    labelText: 'Select Circle',
                                    prefixIcon: Icon(
                                      Icons.radio_button_checked,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                    ),
                                    helperText: 'Choose a circle',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface
                                            .withOpacity(0.2),
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.primary,
                                        width: 2,
                                      ),
                                    ),
                                  ),
                                  isExpanded: true,
                                  items: circles.map((circle) {
                                    return DropdownMenuItem<String>(
                                      value: circle.id,
                                      child: Text(
                                        circle.name,
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 1,
                                        style: Theme.of(
                                          context,
                                        ).textTheme.bodyMedium,
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: isEditing
                                      ? null
                                      : (String? newValue) {
                                          setState(() {
                                            bottomSheetSelectedCircle =
                                                newValue;
                                            bottomSheetSelectedDivision = null;
                                            bottomSheetSelectedSubdivision =
                                                null;
                                            selectedCityId = null;
                                            selectedCityName = null;
                                            debugPrint(
                                              'DEBUG: Parent Circle selected: $newValue',
                                            );
                                          });
                                        },
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Please select a circle';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                            );
                          },
                        ),
                      ],

                      // Division selection
                      if (widget.itemType != 'AppScreenState' &&
                          widget.itemType != 'Company' &&
                          widget.itemType != 'Zone' &&
                          widget.itemType != 'Circle' &&
                          widget.itemType != 'Division') ...[
                        const SizedBox(height: 16),
                        StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('divisions')
                              .where(
                                'circleId',
                                isEqualTo: bottomSheetSelectedCircle,
                              )
                              .orderBy('name')
                              .snapshots(),
                          builder: (context, snapshot) {
                            if (snapshot.hasError) {
                              return Text(
                                'Error loading divisions: ${snapshot.error}',
                              );
                            }
                            if (bottomSheetSelectedCircle == null) {
                              return const Text(
                                'Select a circle first to load divisions.',
                              );
                            }
                            if (!snapshot.hasData ||
                                snapshot.data!.docs.isEmpty) {
                              return const Text(
                                'No divisions available for the selected circle.',
                              );
                            }
                            final divisions = snapshot.data!.docs
                                .map((doc) => Division.fromFirestore(doc))
                                .toList();
                            return InkWell(
                              onTap:
                                  bottomSheetSelectedDivision != null &&
                                      isEditing
                                  ? () {
                                      SnackBarUtils.showSnackBar(
                                        context,
                                        'Division is pre-filled and cannot be changed for existing items.',
                                      );
                                    }
                                  : null,
                              child: AbsorbPointer(
                                absorbing:
                                    bottomSheetSelectedDivision != null &&
                                    isEditing,
                                child: DropdownButtonFormField<String>(
                                  value: bottomSheetSelectedDivision,
                                  decoration: InputDecoration(
                                    labelText: 'Select Division',
                                    prefixIcon: Icon(
                                      Icons.group_work,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                    ),
                                    helperText: 'Choose a division',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface
                                            .withOpacity(0.2),
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.primary,
                                        width: 2,
                                      ),
                                    ),
                                  ),
                                  isExpanded: true,
                                  items: divisions.map((division) {
                                    return DropdownMenuItem<String>(
                                      value: division.id,
                                      child: Text(
                                        division.name,
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 1,
                                        style: Theme.of(
                                          context,
                                        ).textTheme.bodyMedium,
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: isEditing
                                      ? null
                                      : (String? newValue) {
                                          setState(() {
                                            bottomSheetSelectedDivision =
                                                newValue;
                                            bottomSheetSelectedSubdivision =
                                                null;
                                            selectedCityId = null;
                                            selectedCityName = null;
                                            debugPrint(
                                              'DEBUG: Parent Division selected: $newValue',
                                            );
                                          });
                                        },
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Please select a division';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                            );
                          },
                        ),
                      ],

                      // Subdivision selection (only for Substation)
                      if (widget.itemType == 'Substation') ...[
                        const SizedBox(height: 16),
                        StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('subdivisions')
                              .where(
                                'divisionId',
                                isEqualTo: bottomSheetSelectedDivision,
                              )
                              .orderBy('name')
                              .snapshots(),
                          builder: (context, snapshot) {
                            if (snapshot.hasError) {
                              return Text(
                                'Error loading subdivisions: ${snapshot.error}',
                              );
                            }
                            if (bottomSheetSelectedDivision == null) {
                              return const Text(
                                'Select a division first to load subdivisions.',
                              );
                            }
                            if (!snapshot.hasData ||
                                snapshot.data!.docs.isEmpty) {
                              return const Text(
                                'No subdivisions available for the selected division.',
                              );
                            }
                            final subdivisions = snapshot.data!.docs
                                .map((doc) => Subdivision.fromFirestore(doc))
                                .toList();
                            return InkWell(
                              onTap:
                                  bottomSheetSelectedSubdivision != null &&
                                      isEditing
                                  ? () {
                                      SnackBarUtils.showSnackBar(
                                        context,
                                        'Subdivision is pre-filled and cannot be changed for existing items.',
                                      );
                                    }
                                  : null,
                              child: AbsorbPointer(
                                absorbing:
                                    bottomSheetSelectedSubdivision != null &&
                                    isEditing,
                                child: DropdownButtonFormField<String>(
                                  value: bottomSheetSelectedSubdivision,
                                  decoration: InputDecoration(
                                    labelText: 'Select Subdivision',
                                    prefixIcon: Icon(
                                      Icons.scatter_plot,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                    ),
                                    helperText: 'Choose a subdivision',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface
                                            .withOpacity(0.2),
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.primary,
                                        width: 2,
                                      ),
                                    ),
                                  ),
                                  isExpanded: true,
                                  items: subdivisions.map((subdivision) {
                                    return DropdownMenuItem<String>(
                                      value: subdivision.id,
                                      child: Text(
                                        subdivision.name,
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 1,
                                        style: Theme.of(
                                          context,
                                        ).textTheme.bodyMedium,
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: isEditing
                                      ? null
                                      : (String? newValue) {
                                          setState(() {
                                            bottomSheetSelectedSubdivision =
                                                newValue;
                                            selectedCityId = null;
                                            selectedCityName = null;
                                            debugPrint(
                                              'DEBUG: Parent Subdivision selected: $newValue',
                                            );
                                          });
                                        },
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Please select a subdivision';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                            );
                          },
                        ),
                      ],

                      // Substation-specific fields (rest remain the same)
                      if (widget.itemType == 'Substation') ...[
                        const SizedBox(height: 16),
                        Text(
                          'Substation Technical Details',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                        ),
                        const Divider(height: 24, thickness: 1),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          value: selectedVoltageLevel,
                          decoration: InputDecoration(
                            labelText: 'Voltage Level',
                            prefixIcon: Icon(
                              Icons.flash_on,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            helperText: 'Select the voltage level',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurface.withOpacity(0.2),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: Theme.of(context).colorScheme.primary,
                                width: 2,
                              ),
                            ),
                          ),
                          items:
                              <String>[
                                '765kV',
                                '400kV',
                                '220kV',
                                '132kV',
                                '33kV',
                                '11kV',
                              ].map((String value) {
                                return DropdownMenuItem<String>(
                                  value: value,
                                  child: Text(value),
                                );
                              }).toList(),
                          onChanged: (String? newValue) {
                            setState(() {
                              selectedVoltageLevel = newValue;
                              debugPrint(
                                'DEBUG: Substation Voltage Level selected: $newValue',
                              );
                            });
                          },
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please select a voltage level';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          value: typeController.text.isNotEmpty
                              ? typeController.text
                              : null,
                          decoration: InputDecoration(
                            labelText: 'Type',
                            prefixIcon: Icon(
                              Icons.category,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            helperText: 'Select substation type',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurface.withOpacity(0.2),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: Theme.of(context).colorScheme.primary,
                                width: 2,
                              ),
                            ),
                          ),
                          items: ['AIS', 'GIS', 'Hybrid'].map((String value) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Text(value),
                            );
                          }).toList(),
                          onChanged: (String? newValue) {
                            setState(() {
                              typeController.text = newValue ?? '';
                              debugPrint(
                                'DEBUG: Substation Type selected: $newValue',
                              );
                            });
                          },
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please select a type';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // OPERATION DROPDOWN
                        DropdownButtonFormField<String>(
                          value: selectedOperation,
                          decoration: InputDecoration(
                            labelText: 'Operation',
                            prefixIcon: Icon(
                              Icons.settings,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            helperText: 'Select operation type',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurface.withOpacity(0.2),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: Theme.of(context).colorScheme.primary,
                                width: 2,
                              ),
                            ),
                          ),
                          items: operationTypes.map((String value) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Text(value),
                            );
                          }).toList(),
                          onChanged: (String? newValue) {
                            setState(() {
                              selectedOperation = newValue;
                              if (selectedOperation != 'SAS') {
                                sasMakeController.clear();
                              }
                              debugPrint(
                                'DEBUG: Substation Operation selected: $newValue',
                              );
                            });
                          },
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please select an operation type';
                            }
                            return null;
                          },
                        ),
                        if (selectedOperation == 'SAS') ...[
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: sasMakeController,
                            decoration: InputDecoration(
                              labelText: 'SAS Make',
                              prefixIcon: Icon(
                                Icons.precision_manufacturing,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              helperText: 'Enter SAS manufacturer',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurface.withOpacity(0.2),
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: Theme.of(context).colorScheme.primary,
                                  width: 2,
                                ),
                              ),
                            ),
                            validator: (value) {
                              if (selectedOperation == 'SAS' &&
                                  (value == null || value.isEmpty)) {
                                return 'Please enter SAS Make';
                              }
                              return null;
                            },
                          ),
                        ],
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          value: selectedStatus,
                          decoration: InputDecoration(
                            labelText: 'Status',
                            prefixIcon: Icon(
                              Icons.check_circle_outline,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            helperText: 'Select operational status',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurface.withOpacity(0.2),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: Theme.of(context).colorScheme.primary,
                                width: 2,
                              ),
                            ),
                          ),
                          items: ['Working', 'Non-Working'].map((String value) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Text(value),
                            );
                          }).toList(),
                          onChanged: (String? newValue) {
                            setState(() {
                              selectedStatus = newValue;
                              if (newValue == 'Working') {
                                statusDescriptionController.clear();
                              }
                              debugPrint(
                                'DEBUG: Substation Status selected: $newValue',
                              );
                            });
                          },
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please select a status';
                            }
                            return null;
                          },
                        ),
                        if (selectedStatus == 'Non-Working')
                          const SizedBox(height: 16),
                        if (selectedStatus == 'Non-Working')
                          TextFormField(
                            controller: statusDescriptionController,
                            decoration: InputDecoration(
                              labelText:
                                  'Status Description (Reason for Non-Working)',
                              prefixIcon: Icon(
                                Icons.info_outline,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              helperText: 'Provide details',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurface.withOpacity(0.2),
                                ),
                              ),
                            ),
                            maxLines: 3,
                            validator: (value) {
                              if (selectedStatus == 'Non-Working' &&
                                  (value == null || value.isEmpty)) {
                                return 'Please provide a reason for non-working status';
                              }
                              return null;
                            },
                          ),
                        const SizedBox(height: 16),
                        // Date of Commissioning - Made Mandatory
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Date of Commissioning',
                              style: Theme.of(context).textTheme.bodyLarge!
                                  .copyWith(
                                    fontWeight: FontWeight.w500,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurface,
                                  ),
                            ),
                            const SizedBox(height: 8),
                            InkWell(
                              onTap: () => _selectCommissioningDate(context),
                              child: InputDecorator(
                                decoration: InputDecoration(
                                  labelText: commissioningDate == null
                                      ? 'Select Date'
                                      : 'Date Selected',
                                  hintText: 'Tap to select date',
                                  prefixIcon: Icon(
                                    Icons.calendar_today,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurface.withOpacity(0.2),
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                      width: 2,
                                    ),
                                  ),
                                ),
                                isEmpty: commissioningDate == null,
                                child: Text(
                                  commissioningDate == null
                                      ? 'No date chosen'
                                      : commissioningDate!
                                            .toDate()
                                            .toLocal()
                                            .toString()
                                            .split(' ')[0],
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium!
                                      .copyWith(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSurface,
                                      ),
                                ),
                              ),
                            ),
                            if (commissioningDate == null &&
                                (!isEditing &&
                                    _formKey.currentState?.validate() == false))
                              // Removed the redundant validation check here, as it's better handled on button press.
                              // The direct form.validate() on button press is sufficient for indicating missing fields.
                              Padding(
                                padding: const EdgeInsets.only(
                                  top: 8.0,
                                  left: 12.0,
                                ),
                                child: Text(
                                  'Date of Commissioning is mandatory',
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.error,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                          ],
                        ),

                        const SizedBox(height: 16),
                        Text(
                          'Substation Location Details',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                        ),
                        const Divider(height: 24, thickness: 1),
                        const SizedBox(height: 8),
                        DropdownSearch<CityModel>(
                          selectedItem: selectedCityId != null
                              ? appState.allCityModels.firstWhere(
                                  (c) => c.id == selectedCityId,
                                  orElse: () =>
                                      CityModel(id: -1, name: '', stateId: -1),
                                )
                              : null,
                          popupProps: PopupProps.menu(
                            showSearchBox: true,
                            menuProps: MenuProps(
                              borderRadius: BorderRadius.circular(12),
                              elevation: 4,
                            ),
                            searchFieldProps: TextFieldProps(
                              decoration: InputDecoration(
                                labelText: 'Search City',
                                prefixIcon: Icon(
                                  Icons.search,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurface.withOpacity(0.2),
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                    width: 2,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          itemAsString: (CityModel c) => c.name,
                          asyncItems: (String filter) async {
                            if (bottomSheetSelectedState == null) {
                              SnackBarUtils.showSnackBar(
                                context,
                                'Please select a state first.',
                                isError: true,
                              );
                              return [];
                            }
                            // Convert the stored state ID back to the state name for getCitiesForStateName
                            final selectedStateName = appState.allStateModels
                                .firstWhere(
                                  (s) =>
                                      s.id.toString() ==
                                      bottomSheetSelectedState,
                                  orElse: () => StateModel(id: -1, name: ''),
                                )
                                .name;

                            if (selectedStateName.isEmpty ||
                                selectedStateName == 'null') {
                              // Check for invalid state name from mapping
                              return [];
                            }

                            final cities = appState.getCitiesForStateName(
                              selectedStateName,
                            );
                            final filteredCities = cities
                                .where(
                                  (city) => city.name.toLowerCase().contains(
                                    filter.toLowerCase(),
                                  ),
                                )
                                .toList();
                            return filteredCities;
                          },
                          dropdownDecoratorProps: DropDownDecoratorProps(
                            dropdownSearchDecoration: InputDecoration(
                              labelText: 'City',
                              hintText: 'Select City',
                              prefixIcon: Icon(
                                Icons.location_city,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurface.withOpacity(0.2),
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: Theme.of(context).colorScheme.primary,
                                  width: 2,
                                ),
                              ),
                              helperText: 'Search or select a city',
                            ),
                          ),
                          onChanged: (CityModel? city) {
                            setState(() {
                              selectedCityId = city?.id;
                              selectedCityName = city?.name;
                              debugPrint(
                                'DEBUG: City selected: ${city?.name} (ID: ${city?.id})',
                              );
                            });
                          },
                          validator: (value) {
                            if (selectedCityId == null) {
                              return 'Please select a city';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        // Substation specific address field
                        TextFormField(
                          controller: substationAddressController,
                          decoration: InputDecoration(
                            labelText:
                                'Substation Address (Specific) (Optional)',
                            prefixIcon: Icon(
                              Icons.location_on,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            helperText: 'Enter detailed address',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurface.withOpacity(0.2),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: Theme.of(context).colorScheme.primary,
                                width: 2,
                              ),
                            ),
                          ),
                          maxLines: 2,
                        ),
                        const SizedBox(height: 16),
                      ],

                      // General address field for all non-AppScreenState, non-Substation items
                      if (widget.itemType != 'AppScreenState' &&
                          widget.itemType != 'Substation') ...[
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: addressController,
                          decoration: InputDecoration(
                            labelText: 'Office Address (Optional)',
                            prefixIcon: Icon(
                              Icons.location_on,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            helperText: 'Enter the office address',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurface.withOpacity(0.2),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: Theme.of(context).colorScheme.primary,
                                width: 2,
                              ),
                            ),
                          ),
                          maxLines: 2,
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Optional fields common to many HierarchyItems (e.g., Description, Landmark, Contact Info)
                      if (widget.itemType != 'AppScreenState') ...[
                        TextFormField(
                          controller: landmarkController,
                          decoration: InputDecoration(
                            labelText: 'Landmark (Optional)',
                            prefixIcon: Icon(
                              Icons.flag,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            helperText: 'Nearby landmark',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurface.withOpacity(0.2),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: Theme.of(context).colorScheme.primary,
                                width: 2,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: contactNumberController,
                          decoration: InputDecoration(
                            labelText: 'Contact Number (Optional)',
                            prefixIcon: Icon(
                              Icons.phone,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            helperText: 'Enter phone number',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurface.withOpacity(0.2),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: Theme.of(context).colorScheme.primary,
                                width: 2,
                              ),
                            ),
                          ),
                          keyboardType: TextInputType.phone,
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          value: selectedContactDesignation,
                          decoration: InputDecoration(
                            labelText: 'Contact Designation',
                            prefixIcon: Icon(
                              Icons.badge,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            helperText: 'Select designation',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurface.withOpacity(0.2),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: Theme.of(context).colorScheme.primary,
                                width: 2,
                              ),
                            ),
                          ),
                          items: contactDesignations.map((String designation) {
                            return DropdownMenuItem<String>(
                              value: designation,
                              child: Text(designation),
                            );
                          }).toList(),
                          onChanged: (String? newValue) {
                            setState(() {
                              selectedContactDesignation = newValue;
                              debugPrint(
                                'DEBUG: Contact Designation selected: $newValue',
                              );
                            });
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: descriptionController,
                          decoration: InputDecoration(
                            labelText: widget.itemType == 'AppScreenState'
                                ? 'State Description (Optional)'
                                : '${widget.itemType} Description (Optional)',
                            prefixIcon: Icon(
                              Icons.description,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            helperText: 'Additional details',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurface.withOpacity(0.2),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: Theme.of(context).colorScheme.primary,
                                width: 2,
                              ),
                            ),
                          ),
                          maxLines: 3,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        debugPrint(
                          'DEBUG: Add/Edit form: Cancel button pressed.',
                        );
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: Theme.of(
                          context,
                        ).colorScheme.onSurface.withOpacity(0.6),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () {
                        if (!_formKey.currentState!.validate()) {
                          debugPrint(
                            'DEBUG: Add/Edit form: Form validation failed.',
                          );
                          if (widget.itemType == 'Substation' &&
                              commissioningDate == null) {
                            SnackBarUtils.showSnackBar(
                              context,
                              'Date of Commissioning is mandatory.',
                              isError: true,
                            );
                          }
                          return;
                        }

                        if (widget.itemType == 'Substation' &&
                            commissioningDate == null) {
                          SnackBarUtils.showSnackBar(
                            context,
                            'Date of Commissioning is mandatory.',
                            isError: true,
                          );
                          return;
                        }

                        Map<String, dynamic> data = {
                          'name': nameController.text,
                          'description': descriptionController.text.isEmpty
                              ? null
                              : descriptionController.text,
                          'landmark': landmarkController.text.isEmpty
                              ? null
                              : landmarkController.text,
                          'contactNumber': contactNumberController.text.isEmpty
                              ? null
                              : contactNumberController.text,
                          'contactPerson': contactPersonController.text.isEmpty
                              ? null
                              : contactPersonController.text,
                          'contactDesignation': selectedContactDesignation,
                          'address': widget.itemType == 'Substation'
                              ? substationAddressController.text.isEmpty
                                    ? null
                                    : substationAddressController.text
                              : addressController.text.isEmpty
                              ? null
                              : addressController.text,
                        };
                        debugPrint(
                          'DEBUG: Add/Edit form: Collected data: $data',
                        );

                        String? docToUseId = isEditing
                            ? widget.itemToEdit!.id
                            : null;

                        if (widget.itemType == 'AppScreenState') {
                          docToUseId = nameController
                              .text; // The state name is its Firestore ID
                          data['name'] = nameController.text;
                          debugPrint(
                            'DEBUG: Add/Edit form: AppScreenState logic - docId: $docToUseId',
                          );
                        }

                        // Add all currently selected parent IDs (if not null)
                        // These are now reliably set in _initializeFormFields as string IDs from AppStateData.
                        if (bottomSheetSelectedState != null) {
                          // For Firestore, we need the actual state name as the ID
                          final stateNameForFirestore = appState.allStateModels
                              .firstWhere(
                                (s) =>
                                    s.id.toString() == bottomSheetSelectedState,
                                orElse: () => StateModel(id: -1, name: ''),
                              )
                              .name;
                          if (stateNameForFirestore.isNotEmpty &&
                              stateNameForFirestore != 'null') {
                            data['stateId'] = stateNameForFirestore;
                          } else {
                            data['stateId'] =
                                null; // Or handle as an error if state is mandatory
                          }
                        } else {
                          data['stateId'] = null;
                        }

                        if (bottomSheetSelectedCompany != null)
                          data['companyId'] = bottomSheetSelectedCompany;
                        if (bottomSheetSelectedZone != null)
                          data['zoneId'] = bottomSheetSelectedZone;
                        if (bottomSheetSelectedCircle != null)
                          data['circleId'] = bottomSheetSelectedCircle;
                        if (bottomSheetSelectedDivision != null)
                          data['divisionId'] = bottomSheetSelectedDivision;
                        if (bottomSheetSelectedSubdivision != null)
                          data['subdivisionId'] =
                              bottomSheetSelectedSubdivision;

                        if (widget.itemType == 'Substation') {
                          data['cityId'] = selectedCityId?.toString();
                          data['voltageLevel'] = selectedVoltageLevel;
                          data['type'] = typeController.text.isEmpty
                              ? null
                              : typeController.text;
                          data['operation'] = selectedOperation;
                          data['sasMake'] = sasMakeController.text.isEmpty
                              ? null
                              : sasMakeController.text;
                          data['commissioningDate'] = commissioningDate;
                          data['status'] = selectedStatus;
                          data['statusDescription'] =
                              statusDescriptionController.text.isEmpty
                              ? null
                              : statusDescriptionController.text;
                          debugPrint(
                            'DEBUG: Add/Edit form: Substation logic - cityId: ${data['cityId']}, voltage: ${data['voltageLevel']}, status: ${data['status']}',
                          );
                        }
                        // REMOVED: Bay data creation logic
                        // else if (widget.itemType == 'Bay') {
                        //   data['bayType'] = selectedBayType;
                        //   data['voltageLevel'] = selectedVoltageLevel;
                        //   data['multiplyingFactor'] = double.tryParse(multiplyingFactorController.text);
                        // }

                        widget.onAddItem(
                          '${widget.itemType.toLowerCase()}s',
                          data,
                          _formKey,
                          docToUseId,
                        );
                        debugPrint(
                          'DEBUG: Add/Edit form: Calling onAddItem for collection: ${widget.itemType.toLowerCase()}s, docId: $docToUseId',
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Theme.of(
                          context,
                        ).colorScheme.onPrimary,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                      ),
                      child: Text(isEditing ? 'Update' : 'Add'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showSnackBar(String message, {bool isError = false}) {
    SnackBarUtils.showSnackBar(context, message, isError: isError);
  }
}

class AdminHierarchyScreen extends StatefulWidget {
  const AdminHierarchyScreen({super.key});

  @override
  State<AdminHierarchyScreen> createState() => _AdminHierarchyScreenState();
}

class _AdminHierarchyScreenState extends State<AdminHierarchyScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    debugPrint('DEBUG: AdminHierarchyScreenState: Initializing screen.');
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    debugPrint('DEBUG: AdminHierarchyScreenState: Disposing screen.');
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _addHierarchyItem(
    String collectionName,
    Map<String, dynamic> data,
    GlobalKey<FormState> formKey,
    String? docId,
  ) async {
    debugPrint('DEBUG: _addHierarchyItem: Attempting to add/update item.');
    debugPrint(
      'DEBUG: _addHierarchyItem: Collection: $collectionName, DocId: $docId, Data: $data',
    );
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      SnackBarUtils.showSnackBar(
        context,
        'Error: User not logged in.',
        isError: true,
      );
      debugPrint('ERROR: _addHierarchyItem: User not logged in.');
      return;
    }

    if (!formKey.currentState!.validate()) {
      debugPrint('DEBUG: _addHierarchyItem: Form validation failed.');
      return;
    }

    try {
      if (docId == null || docId.isEmpty) {
        debugPrint(
          'DEBUG: _addHierarchyItem: Adding new document to $collectionName without specific ID.',
        );
        await FirebaseFirestore.instance.collection(collectionName).add({
          ...data,
          'createdBy': currentUser.uid,
          'createdAt': FieldValue.serverTimestamp(),
        });
        SnackBarUtils.showSnackBar(
          context,
          '$collectionName added successfully!',
        );
        debugPrint(
          'DEBUG: _addHierarchyItem: Document added successfully to $collectionName.',
        );
      } else {
        debugPrint(
          'DEBUG: _addHierarchyItem: Setting/Updating document $docId in $collectionName.',
        );
        await FirebaseFirestore.instance.collection(collectionName).doc(docId).set(
          {
            ...data,
            'updatedAt':
                FieldValue.serverTimestamp(), // Update timestamp on modification
          },
          SetOptions(merge: true), // Merge existing fields with new data
        );
        SnackBarUtils.showSnackBar(
          context,
          '$collectionName updated successfully!',
        );
        debugPrint(
          'DEBUG: _addHierarchyItem: Document $docId updated/set successfully in $collectionName.',
        );
      }

      if (context.mounted) {
        Navigator.of(context).pop();
        debugPrint(
          'DEBUG: _addHierarchyItem: Popping navigator after successful operation.',
        );
      }
    } catch (e) {
      SnackBarUtils.showSnackBar(
        context,
        'Failed to ${docId == null ? 'add' : 'update'} $collectionName: ${e.toString()}',
        isError: true,
      );
      debugPrint(
        'ERROR: _addHierarchyItem: Error ${docId == null ? 'adding' : 'updating'} $collectionName: $e',
      );
    }
  }

  void _showAddBottomSheet({
    required String itemType,
    String? parentId,
    String? parentName,
    String? parentCollectionName,
    HierarchyItem? itemToEdit,
  }) {
    debugPrint(
      'DEBUG: _showAddBottomSheet: Opening bottom sheet for itemType: $itemType, parentId: $parentId, parentCollectionName: $parentCollectionName, itemToEdit: ${itemToEdit?.name}',
    );
    // User check should ideally be done here before opening bottom sheet
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      SnackBarUtils.showSnackBar(
        context,
        'You must be logged in to add/edit items.',
        isError: true,
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return _AddEditHierarchyItemForm(
          itemType: itemType,
          parentId: parentId,
          parentName: parentName,
          parentCollectionName: parentCollectionName,
          itemToEdit: itemToEdit,
          onAddItem: _addHierarchyItem,
        );
      },
    );
  }

  // Helper to determine the next collection name based on itemType
  String _getNextCollectionName(String currentItemType) {
    switch (currentItemType) {
      case 'AppScreenState':
        return 'companys';
      case 'Company':
        return 'zones';
      case 'Zone':
        return 'circles';
      case 'Circle':
        return 'divisions';
      case 'Division':
        return 'subdivisions';
      case 'Subdivision':
        return 'substations';
      // Removed 'Bay' from here. Substation is the last level.
      case 'Substation':
        return ''; // No children for Substation anymore
      default:
        return ''; // No children
    }
  }

  // Helper to determine the parent ID field name for the next collection
  String _getParentIdFieldName(String currentItemType) {
    switch (currentItemType) {
      case 'Company':
        return 'stateId';
      case 'Zone':
        return 'companyId';
      case 'Circle':
        return 'zoneId';
      case 'Division':
        return 'circleId';
      case 'Subdivision':
        return 'divisionId';
      case 'Substation':
        return 'subdivisionId';
      // Removed 'Bay' from here.
      default:
        return '';
    }
  }

  // Recursive function to check for children
  Future<bool> _hasChildren(String collectionName, String parentId) async {
    final nextCollectionName = _getNextCollectionName(
      collectionName.replaceAll('s', ''), // e.g., 'companys' -> 'company'
    );

    if (nextCollectionName.isEmpty) {
      debugPrint(
        'DEBUG: _hasChildren: No further collections for $collectionName. No children to check.',
      );
      return false; // No more levels down, so no children from here (e.g., Substation)
    }

    // Ensure the parentIdFieldName is correctly retrieved for the *current* collection type
    // This is important to query the *next* collection using the correct foreign key
    String currentItemType = collectionName.replaceAll(
      's',
      '',
    ); // e.g., 'companys' -> 'company'
    String parentIdFieldNameForNextCollection;

    switch (currentItemType) {
      case 'appscreenstate': // Children are 'companys', parentId in 'companys' is 'stateId'
        parentIdFieldNameForNextCollection = 'stateId';
        break;
      case 'company': // Children are 'zones', parentId in 'zones' is 'companyId'
        parentIdFieldNameForNextCollection = 'companyId';
        break;
      case 'zone': // Children are 'circles', parentId in 'circles' is 'zoneId'
        parentIdFieldNameForNextCollection = 'zoneId';
        break;
      case 'circle': // Children are 'divisions', parentId in 'divisions' is 'circleId'
        parentIdFieldNameForNextCollection = 'circleId';
        break;
      case 'division': // Children are 'subdivisions', parentId in 'subdivisions' is 'divisionId'
        parentIdFieldNameForNextCollection = 'divisionId';
        break;
      case 'subdivision': // Children are 'substations', parentId in 'substations' is 'subdivisionId'
        parentIdFieldNameForNextCollection = 'subdivisionId';
        break;
      case 'substation': // No children for substation, already handled by nextCollectionName.isEmpty
        return false;
      default:
        debugPrint(
          'WARNING: _hasChildren: Unrecognized collection type for parentIdFieldName lookup: $currentItemType.',
        );
        return false;
    }

    final querySnapshot = await FirebaseFirestore.instance
        .collection(nextCollectionName)
        .where(parentIdFieldNameForNextCollection, isEqualTo: parentId)
        .limit(1) // Just need to know if at least one exists
        .get();

    debugPrint(
      'DEBUG: _hasChildren: Checking $nextCollectionName for parent $parentIdFieldNameForNextCollection=$parentId. Found ${querySnapshot.docs.length} children.',
    );
    return querySnapshot.docs.isNotEmpty;
  }

  void _confirmDelete(String collection, String docId, String name) {
    debugPrint(
      'DEBUG: _confirmDelete: Confirming deletion for item: $name (ID: $docId) from collection: $collection',
    );
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            'Confirm Delete',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.error,
              fontWeight: FontWeight.w600,
            ),
          ),
          content: FutureBuilder<bool>(
            future: _hasChildren(collection, docId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 10),
                    Text('Checking for child items...'),
                  ],
                );
              }
              if (snapshot.hasError) {
                return Text('Error checking children: ${snapshot.error}');
              }

              final hasChildren =
                  snapshot.data ??
                  false; // Default to false unless explicitly true
              if (hasChildren) {
                return Text(
                  'Cannot delete "$name" as it still contains lower-level hierarchy items. Please delete all child items first.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.error,
                  ),
                );
              } else {
                return Text(
                  'Are you sure you want to delete "$name"? This action cannot be undone.',
                  style: Theme.of(context).textTheme.bodyMedium,
                );
              }
            },
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                debugPrint('DEBUG: Delete dialog: Cancel button pressed.');
              },
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(
                  context,
                ).colorScheme.onSurface.withOpacity(0.6),
              ),
              child: const Text('Cancel'),
            ),
            FutureBuilder<bool>(
              future: _hasChildren(collection, docId),
              builder: (context, snapshot) {
                final hasChildren =
                    snapshot.data ??
                    false; // Default to false unless explicitly true
                return ElevatedButton(
                  onPressed: hasChildren
                      ? null // Disable button if children exist
                      : () async {
                          try {
                            debugPrint(
                              'DEBUG: Delete dialog: Deleting item: $docId from $collection.',
                            );
                            await FirebaseFirestore.instance
                                .collection(collection)
                                .doc(docId)
                                .delete();
                            SnackBarUtils.showSnackBar(
                              context,
                              '$name deleted successfully!',
                            );
                            debugPrint(
                              'DEBUG: Delete dialog: Item $name deleted successfully.',
                            );
                            if (context.mounted) {
                              Navigator.of(context).pop();
                            }
                          } catch (e) {
                            SnackBarUtils.showSnackBar(
                              context,
                              'Failed to delete $name: ${e.toString()}',
                              isError: true,
                            );
                            debugPrint(
                              'ERROR: Delete dialog: Error deleting $name: $e',
                            );
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.error,
                    foregroundColor: Theme.of(context).colorScheme.onError,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                  child: const Text('Delete'),
                );
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildHierarchyList<T extends HierarchyItem>(
    CollectionReference collection,
    T Function(DocumentSnapshot) fromFirestore, {
    String?
    stateIdFilter, // This will now be the state NAME for Firestore queries
    String? companyIdFilter,
    String? zoneIdFilter,
    String? circleIdFilter,
    String? divisionIdFilter,
    String? subdivisionIdFilter,
    String nextLevelItemType = '',
  }) {
    debugPrint(
      'DEBUG: _buildHierarchyList: Building list for collection: ${collection.id}',
    );
    debugPrint(
      'DEBUG: _buildHierarchyList: Filters - stateIdFilter: $stateIdFilter, companyIdFilter: $companyIdFilter, zoneIdFilter: $zoneIdFilter, circleIdFilter: $circleIdFilter, divisionIdFilter: $divisionIdFilter, subdivisionIdFilter: $subdivisionIdFilter',
    );

    Query query = collection;
    final appState = Provider.of<AppStateData>(context, listen: false);

    // Apply specific filters based on current collection and its parent relationships
    if (collection.id == 'companys' && stateIdFilter != null) {
      // For 'companys', the 'stateId' in Firestore is the STATE NAME (AppScreenState document ID)
      // So, if stateIdFilter is the numeric ID from StateModel, we need to convert it to the name.
      final stateNameForQuery = appState.allStateModels
          .firstWhere(
            (s) =>
                s.id.toString() ==
                stateIdFilter, // stateIdFilter is the numeric ID as string
            orElse: () => StateModel(id: -1, name: ''),
          )
          .name;
      if (stateNameForQuery.isNotEmpty && stateNameForQuery != 'null') {
        query = query.where('stateId', isEqualTo: stateNameForQuery);
      }
    } else if (collection.id == 'zones' && companyIdFilter != null) {
      query = query.where('companyId', isEqualTo: companyIdFilter);
    } else if (collection.id == 'circles' && zoneIdFilter != null) {
      query = query.where('zoneId', isEqualTo: zoneIdFilter);
    } else if (collection.id == 'divisions' && circleIdFilter != null) {
      query = query.where('circleId', isEqualTo: circleIdFilter);
    } else if (collection.id == 'subdivisions' && divisionIdFilter != null) {
      query = query.where('divisionId', isEqualTo: divisionIdFilter);
    } else if (collection.id == 'substations' && subdivisionIdFilter != null) {
      query = query.where('subdivisionId', isEqualTo: subdivisionIdFilter);
    }

    query = query.orderBy('name');
    debugPrint('DEBUG: _buildHierarchyList: Ordering by name.');

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        debugPrint(
          'DEBUG: _buildHierarchyList (StreamBuilder for ${collection.id}): ConnectionState: ${snapshot.connectionState}, HasError: ${snapshot.hasError}, HasData: ${snapshot.hasData}',
        );
        if (snapshot.hasError) {
          debugPrint(
            'ERROR: _buildHierarchyList (StreamBuilder for ${collection.id}): Error: ${snapshot.error}',
          );
          return Center(
            child: Text(
              'Error: ${snapshot.error}',
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
                fontSize: 11,
              ),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          debugPrint(
            'DEBUG: _buildHierarchyList (StreamBuilder for ${collection.id}): Waiting for data.',
          );
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.data!.docs.isEmpty) {
          String emptyMessage = 'No ${collection.id} found here.';
          if (nextLevelItemType.isNotEmpty) {
            emptyMessage += ' Click "Add $nextLevelItemType" to add one.';
          } else if (collection.id == 'appscreenstates') {
            emptyMessage = 'No states found. Click the "+" button to add one.';
          } else {
            emptyMessage += ' Click the "+" button above to add one.';
          }
          debugPrint(
            'DEBUG: _buildHierarchyList (StreamBuilder for ${collection.id}): No documents found. Displaying: "$emptyMessage"',
          );
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                emptyMessage,
                style: TextStyle(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withOpacity(0.6),
                  fontStyle: FontStyle.italic,
                  fontSize: 11,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        final items = snapshot.data!.docs.map((doc) {
          debugPrint(
            'DEBUG: _buildHierarchyList (StreamBuilder for ${collection.id}): Processing document: ${doc.id}, data: ${doc.data()}',
          );
          return fromFirestore(doc);
        }).toList();
        items.sort((a, b) => a.name.compareTo(b.name));
        debugPrint(
          'DEBUG: _buildHierarchyList (StreamBuilder for ${collection.id}): Found ${items.length} items after processing.',
        );

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            debugPrint(
              'DEBUG: _buildHierarchyList (ListView for ${collection.id}): Building item $index: ${item.name} (ID: ${item.id})',
            );
            return Card(
              elevation: 2,
              margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withOpacity(0.1),
                ),
              ),
              child: ExpansionTile(
                key: ValueKey(item.id),
                tilePadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                leading: Icon(
                  Icons.folder,
                  color: Theme.of(context).colorScheme.primary,
                  size: 24,
                ),
                title: Text(
                  item.name,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                subtitle:
                    item.description != null && item.description!.isNotEmpty
                    ? Text(
                        item.description!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withOpacity(0.6),
                          fontSize: 11,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      )
                    : null,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16.0,
                      vertical: 8.0,
                    ),
                    child: Wrap(
                      alignment: WrapAlignment.start,
                      spacing: 12.0,
                      runSpacing: 8.0,
                      children: [
                        ElevatedButton.icon(
                          onPressed: () {
                            debugPrint(
                              'DEBUG: Edit button pressed for item: ${item.name} (Type: ${item.runtimeType})',
                            );
                            String currentItemTypeString;
                            if (item is AppScreenState) {
                              currentItemTypeString = 'AppScreenState';
                            } else if (item is Company) {
                              currentItemTypeString = 'Company';
                            } else if (item is Zone) {
                              currentItemTypeString = 'Zone';
                            } else if (item is Circle) {
                              currentItemTypeString = 'Circle';
                            } else if (item is Division) {
                              currentItemTypeString = 'Division';
                            } else if (item is Subdivision) {
                              currentItemTypeString = 'Subdivision';
                            } else if (item is Substation) {
                              currentItemTypeString = 'Substation';
                            }
                            // REMOVED: else if (item is Bay) logic
                            else {
                              currentItemTypeString = 'Unknown';
                            }
                            _showAddBottomSheet(
                              itemType: currentItemTypeString,
                              itemToEdit: item,
                            );
                          },
                          icon: const Icon(Icons.edit),
                          label: const Text('Edit'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(
                              context,
                            ).colorScheme.tertiary,
                            foregroundColor: Theme.of(
                              context,
                            ).colorScheme.onTertiary,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 2,
                          ),
                        ),
                        if (nextLevelItemType.isNotEmpty)
                          ElevatedButton.icon(
                            onPressed: () {
                              debugPrint(
                                'DEBUG: Add child button pressed for item: ${item.name}, nextLevel: $nextLevelItemType',
                              );
                              _showAddBottomSheet(
                                itemType: nextLevelItemType,
                                parentId: item
                                    .id, // Firestore document ID (name for AppScreenState)
                                parentName: item.name,
                                parentCollectionName: collection.id,
                              );
                            },
                            icon: const Icon(Icons.add),
                            label: Text('Add $nextLevelItemType'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Theme.of(
                                context,
                              ).colorScheme.secondary,
                              foregroundColor: Theme.of(
                                context,
                              ).colorScheme.onSecondary,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 2,
                            ),
                          ),
                        ElevatedButton.icon(
                          onPressed: () {
                            debugPrint(
                              'DEBUG: Delete button pressed for item: ${item.name}',
                            );
                            _confirmDelete(collection.id, item.id, item.name);
                          },
                          icon: const Icon(Icons.delete_outline),
                          label: const Text('Delete'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(
                              context,
                            ).colorScheme.error,
                            foregroundColor: Theme.of(
                              context,
                            ).colorScheme.onError,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Recursive calls for next level of hierarchy
                  if (collection.id == 'appscreenstates')
                    _buildHierarchyList<Company>(
                      FirebaseFirestore.instance.collection('companys'),
                      Company.fromFirestore,
                      stateIdFilter:
                          item.id, // This is the state NAME as Firestore ID
                      nextLevelItemType: 'Company',
                    ),
                  if (collection.id == 'companys')
                    _buildHierarchyList<Zone>(
                      FirebaseFirestore.instance.collection('zones'),
                      Zone.fromFirestore,
                      companyIdFilter: item.id,
                      nextLevelItemType: 'Zone',
                    ),
                  if (collection.id == 'zones')
                    _buildHierarchyList<Circle>(
                      FirebaseFirestore.instance.collection('circles'),
                      Circle.fromFirestore,
                      zoneIdFilter: item.id,
                      nextLevelItemType: 'Circle',
                    ),
                  if (collection.id == 'circles')
                    _buildHierarchyList<Division>(
                      FirebaseFirestore.instance.collection('divisions'),
                      Division.fromFirestore,
                      circleIdFilter: item.id,
                      nextLevelItemType: 'Division',
                    ),
                  if (collection.id == 'divisions')
                    _buildHierarchyList<Subdivision>(
                      FirebaseFirestore.instance.collection('subdivisions'),
                      Subdivision.fromFirestore,
                      divisionIdFilter: item.id,
                      nextLevelItemType: 'Substation', // Corrected
                    ),
                  if (collection.id == 'subdivisions')
                    _buildHierarchyList<Substation>(
                      FirebaseFirestore.instance.collection('substations'),
                      Substation.fromFirestore,
                      subdivisionIdFilter: item.id,
                      nextLevelItemType: '', // Substation is the last level
                    ),
                  // REMOVED: Bay list as it's no longer created here
                  const SizedBox(height: 8),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext nullContext) {
    debugPrint(
      'DEBUG: AdminHierarchyScreenState: Building AdminHierarchyScreen.',
    );
    return Scaffold(
      backgroundColor: Theme.of(nullContext).colorScheme.background,
      appBar: AppBar(
        title: const Text('Manage Hierarchy'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Theme.of(nullContext).colorScheme.surface,
        foregroundColor: Theme.of(nullContext).colorScheme.onSurface,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          debugPrint('DEBUG: Add New State FAB pressed.');
          _showAddBottomSheet(itemType: 'AppScreenState');
        },
        label: const Text('Add New State'),
        icon: const Icon(Icons.add),
        backgroundColor: Theme.of(nullContext).colorScheme.primary,
        foregroundColor: Theme.of(nullContext).colorScheme.onPrimary,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SingleChildScrollView(
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Manage Substation Hierarchy',
                    style: Theme.of(nullContext).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: Theme.of(nullContext).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Consumer<AppStateData>(
                    builder: (context, appState, child) {
                      debugPrint(
                        'DEBUG: AdminHierarchyScreen: Consumer for AppStateData rebuilding. States loaded in AppStateData: ${appState.states.length}',
                      );
                      if (appState.states.isEmpty) {
                        debugPrint(
                          'DEBUG: AdminHierarchyScreen: AppStateData.states is empty. Displaying no states loaded message.',
                        );
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Text(
                              'No states loaded. Please ensure state_sql_command.txt is correct and loaded.',
                              style: TextStyle(
                                color: Theme.of(
                                  nullContext,
                                ).colorScheme.onSurface.withOpacity(0.6),
                                fontStyle: FontStyle.italic,
                                fontSize: 11,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        );
                      }

                      return StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('appscreenstates')
                            .orderBy('name')
                            .snapshots(),
                        builder: (context, snapshot) {
                          debugPrint(
                            'DEBUG: AdminHierarchyScreen (Top-level StreamBuilder for appScreenStates): ConnectionState: ${snapshot.connectionState}, HasError: ${snapshot.hasError}, HasData: ${snapshot.hasData}',
                          );
                          if (snapshot.hasError) {
                            debugPrint(
                              'ERROR: AdminHierarchyScreen (Top-level StreamBuilder for appScreenStates): Error: ${snapshot.error}',
                            );
                            return Center(
                              child: Text(
                                'Error: ${snapshot.error}',
                                style: TextStyle(
                                  color: Theme.of(
                                    nullContext,
                                  ).colorScheme.error,
                                  fontSize: 11,
                                ),
                              ),
                            );
                          }

                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            debugPrint(
                              'DEBUG: AdminHierarchyScreen (Top-level StreamBuilder for appScreenStates): Waiting for data.',
                            );
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }

                          if (snapshot.data!.docs.isEmpty) {
                            debugPrint(
                              'DEBUG: AdminHierarchyScreen (Top-level StreamBuilder for appScreenStates): No documents from Firestore. Docs count: ${snapshot.data!.docs.length}.',
                            );
                            return Center(
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Text(
                                  'No states found. Click "Add New State" to get started!',
                                  style: TextStyle(
                                    color: Theme.of(
                                      nullContext,
                                    ).colorScheme.onSurface.withOpacity(0.6),
                                    fontStyle: FontStyle.italic,
                                    fontSize: 11,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            );
                          }

                          final states = snapshot.data!.docs.map((doc) {
                            debugPrint(
                              'DEBUG: AdminHierarchyScreen (Top-level StreamBuilder for appScreenStates): Processing document: ${doc.id}, data: ${doc.data()}',
                            );
                            return AppScreenState.fromFirestore(doc);
                          }).toList();
                          states.sort((a, b) => a.name.compareTo(b.name));
                          debugPrint(
                            'DEBUG: AdminHierarchyScreen (Top-level StreamBuilder for appScreenStates): Found ${states.length} states from Firestore for display.',
                          );

                          return ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: states.length,
                            itemBuilder: (context, index) {
                              final stateItem = states.elementAt(index);
                              debugPrint(
                                'DEBUG: AdminHierarchyScreen (ListView): Building state item $index: ${stateItem.name} (ID: ${stateItem.id})',
                              );
                              return Card(
                                elevation: 2,
                                margin: const EdgeInsets.symmetric(
                                  vertical: 8,
                                  horizontal: 0,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: BorderSide(
                                    color: Theme.of(
                                      nullContext,
                                    ).colorScheme.onSurface.withOpacity(0.1),
                                  ),
                                ),
                                child: ExpansionTile(
                                  key: ValueKey('state-${stateItem.id}'),
                                  leading: Icon(
                                    Icons.map,
                                    color: Theme.of(
                                      nullContext,
                                    ).colorScheme.primary,
                                    size: 24,
                                  ),
                                  title: Text(
                                    stateItem.name,
                                    style: Theme.of(nullContext)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(
                                          fontWeight: FontWeight.w600,
                                          color: Theme.of(
                                            nullContext,
                                          ).colorScheme.primary,
                                        ),
                                  ),
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16.0,
                                        vertical: 8.0,
                                      ),
                                      child: Wrap(
                                        alignment: WrapAlignment.start,
                                        spacing: 12.0,
                                        runSpacing: 8.0,
                                        children: [
                                          ElevatedButton.icon(
                                            onPressed: () {
                                              debugPrint(
                                                'DEBUG: Edit State button pressed for: ${stateItem.name}',
                                              );
                                              _showAddBottomSheet(
                                                itemType: 'AppScreenState',
                                                itemToEdit: stateItem,
                                              );
                                            },
                                            icon: const Icon(Icons.edit),
                                            label: const Text('Edit State'),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Theme.of(
                                                nullContext,
                                              ).colorScheme.tertiary,
                                              foregroundColor: Theme.of(
                                                nullContext,
                                              ).colorScheme.onTertiary,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 12,
                                                    vertical: 8,
                                                  ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                              elevation: 2,
                                            ),
                                          ),
                                          ElevatedButton.icon(
                                            onPressed: () {
                                              debugPrint(
                                                'DEBUG: Add Company button pressed under state: ${stateItem.name}',
                                              );
                                              _showAddBottomSheet(
                                                itemType: 'Company',
                                                parentId: stateItem
                                                    .id, // This is the state NAME (Firestore ID)
                                                parentName: stateItem.name,
                                                parentCollectionName:
                                                    'appscreenstates',
                                              );
                                            },
                                            icon: const Icon(Icons.add),
                                            label: const Text('Add Company'),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Theme.of(
                                                nullContext,
                                              ).colorScheme.secondary,
                                              foregroundColor: Theme.of(
                                                nullContext,
                                              ).colorScheme.onSecondary,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 12,
                                                    vertical: 8,
                                                  ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                              elevation: 2,
                                            ),
                                          ),
                                          ElevatedButton.icon(
                                            onPressed: () {
                                              debugPrint(
                                                'DEBUG: Delete State button pressed for: ${stateItem.name}',
                                              );
                                              _confirmDelete(
                                                'appscreenstates',
                                                stateItem
                                                    .id, // This is the state NAME (Firestore ID)
                                                stateItem.name,
                                              );
                                            },
                                            icon: const Icon(
                                              Icons.delete_outline,
                                            ),
                                            label: const Text('Delete State'),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Theme.of(
                                                nullContext,
                                              ).colorScheme.error,
                                              foregroundColor: Theme.of(
                                                nullContext,
                                              ).colorScheme.onError,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 12,
                                                    vertical: 8,
                                                  ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                              elevation: 2,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    // Companies nested under this State
                                    _buildHierarchyList<Company>(
                                      FirebaseFirestore.instance.collection(
                                        'companys',
                                      ),
                                      Company.fromFirestore,
                                      stateIdFilter: stateItem
                                          .id, // This is the state NAME as Firestore ID
                                      nextLevelItemType: 'Company',
                                    ),
                                    const SizedBox(height: 8),
                                  ],
                                ),
                              );
                            },
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
