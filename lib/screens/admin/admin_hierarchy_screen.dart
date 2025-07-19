// lib/screens/admin/admin_hierarchy_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/hierarchy_models.dart';
import '../../models/app_state_data.dart'; // Contains StateModel and CityModel
import 'package:dropdown_search/dropdown_search.dart';
import 'package:provider/provider.dart'; // Required for Consumer and Provider.of
import '../../models/bay_model.dart';
import 'package:flutter/foundation.dart'; // Import for debugPrint

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
  final TextEditingController addressController =
      TextEditingController(); // New: General address controller
  final TextEditingController substationAddressController =
      TextEditingController(); // Kept for specific substation address if needed
  final TextEditingController statusDescriptionController =
      TextEditingController();
  final TextEditingController voltageLevelController = TextEditingController();
  final TextEditingController typeController = TextEditingController();
  final TextEditingController sasMakeController = TextEditingController();
  final TextEditingController multiplyingFactorController =
      TextEditingController();

  Timestamp? commissioningDate;
  String? bottomSheetSelectedState;
  String? bottomSheetSelectedCompany; // New: To select parent company for Zone
  double? selectedCityId;
  String? selectedCityName;
  String? selectedVoltageLevel;
  String? selectedBayType;
  String? selectedContactDesignation;
  String? selectedOperation; // New: For Operation dropdown
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

  final List<String> bayTypes = [
    'Line',
    'Transformer',
    'Feeder',
    'Capacitor Bank',
    'Reactor',
    'Bus Coupler',
    'Busbar',
  ];

  // List for Operation dropdown
  final List<String> operationTypes = ['Manual', 'SAS'];

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
    _initializeFormFields();
  }

  @override
  void dispose() {
    nameController.dispose();
    descriptionController.dispose();
    landmarkController.dispose();
    contactNumberController.dispose();
    contactPersonController.dispose();
    addressController.dispose(); // Dispose the new address controller
    substationAddressController.dispose();
    voltageLevelController.dispose();
    typeController.dispose();
    sasMakeController.dispose();
    statusDescriptionController.dispose();
    multiplyingFactorController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _initializeFormFields() async {
    debugPrint(
      'DEBUG: _AddEditHierarchyItemFormState: Initializing form for itemType: ${widget.itemType}',
    );
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
      addressController.text =
          widget.itemToEdit!.address ?? ''; // Initialize general address

      if (widget.itemToEdit is AppScreenState) {
        bottomSheetSelectedState = (widget.itemToEdit as AppScreenState).name;
        debugPrint(
          'DEBUG: _AddEditHierarchyItemFormState: Editing AppScreenState: $bottomSheetSelectedState',
        );
      } else if (widget.itemToEdit is Company) {
        bottomSheetSelectedState = (widget.itemToEdit as Company).stateId;
        debugPrint(
          'DEBUG: _AddEditHierarchyItemFormState: Editing Company, stateId: $bottomSheetSelectedState',
        );
      } else if (widget.itemToEdit is Zone) {
        bottomSheetSelectedCompany = (widget.itemToEdit as Zone).companyId;
        debugPrint(
          'DEBUG: _AddEditHierarchyItemFormState: Editing Zone, companyId: $bottomSheetSelectedCompany',
        );
        if (bottomSheetSelectedCompany != null) {
          String? derivedState = await _findStateNameForCompany(
            bottomSheetSelectedCompany!,
          );
          if (mounted) {
            setState(() {
              bottomSheetSelectedState = derivedState;
            });
            debugPrint(
              'DEBUG: _AddEditHierarchyItemFormState: Derived state for Zone: $bottomSheetSelectedState',
            );
          }
        }
      } else if (widget.itemToEdit is Bay) {
        final bay = widget.itemToEdit as Bay;
        multiplyingFactorController.text =
            bay.multiplyingFactor?.toString() ?? '';
        selectedBayType = bay.bayType;
        selectedVoltageLevel = bay.voltageLevel;
        debugPrint(
          'DEBUG: _AddEditHierarchyItemFormState: Editing Bay, type: $selectedBayType, voltage: $selectedVoltageLevel',
        );
      } else if (widget.itemToEdit is Substation) {
        Substation substation = widget.itemToEdit as Substation;
        substationAddressController.text =
            substation.address ?? ''; // Substation specific address
        voltageLevelController.text = substation.voltageLevel ?? '';
        typeController.text = substation.type ?? '';
        sasMakeController.text = substation.sasMake ?? '';
        commissioningDate = substation.commissioningDate;
        selectedVoltageLevel = substation.voltageLevel;
        selectedOperation =
            substation.operation; // Initialize from existing data
        if (selectedOperation == 'SAS') {
          _animationController.forward(); // Show SAS Make field if SAS
        }
        selectedStatus = substation.status;
        statusDescriptionController.text = substation.statusDescription ?? '';
        debugPrint(
          'DEBUG: _AddEditHierarchyItemFormState: Editing Substation, voltage: $selectedVoltageLevel, type: ${substation.type}, operation: ${substation.operation}',
        );

        if (substation.subdivisionId != null) {
          String? derivedCompanyId = await _findCompanyIdForSubdivision(
            substation.subdivisionId!,
          );
          if (derivedCompanyId != null) {
            bottomSheetSelectedCompany = derivedCompanyId;
            String? derivedState = await _findStateNameForCompany(
              derivedCompanyId,
            );
            if (mounted) {
              setState(() {
                bottomSheetSelectedState = derivedState;
              });
              debugPrint(
                'DEBUG: _AddEditHierarchyItemFormState: Derived company and state for Substation: $bottomSheetSelectedCompany, $bottomSheetSelectedState',
              );
            }
          }
        }

        if (substation.cityId != null) {
          selectedCityId = double.tryParse(substation.cityId!);
          final appState = Provider.of<AppStateData>(context, listen: false);
          final city = appState.allCityModels.firstWhere(
            (c) => c.id == selectedCityId,
            orElse: () => CityModel(id: -1, name: '', stateId: -1),
          );
          if (city.id != -1) {
            selectedCityName = city.name;
            debugPrint(
              'DEBUG: _AddEditHierarchyItemFormState: Selected city for Substation: $selectedCityName (ID: $selectedCityId)',
            );
          }
        }
      }
    } else {
      debugPrint('DEBUG: _AddEditHierarchyItemFormState: Adding new item.');
      // For new items, pre-select parent if available from widget.parentId
      if (widget.parentCollectionName == 'appscreenstates') {
        bottomSheetSelectedState = widget.parentId;
        debugPrint(
          'DEBUG: _AddEditHierarchyItemFormState: Pre-selected state from parentId: $bottomSheetSelectedState',
        );
      } else if (widget.parentCollectionName == 'companys') {
        // Corrected
        bottomSheetSelectedCompany = widget.parentId;
        debugPrint(
          'DEBUG: _AddEditHierarchyItemFormState: Pre-selected company from parentId: $bottomSheetSelectedCompany',
        );
        if (bottomSheetSelectedCompany != null) {
          String? derivedState = await _findStateNameForCompany(
            bottomSheetSelectedCompany!,
          );
          if (mounted) {
            setState(() {
              bottomSheetSelectedState = derivedState;
            });
            debugPrint(
              'DEBUG: _AddEditHierarchyItemFormState: Derived state for new item: $bottomSheetSelectedState',
            );
          }
        }
      } else if (widget.parentCollectionName == 'subdivisions' &&
          widget.parentId != null) {
        String? derivedCompanyId = await _findCompanyIdForSubdivision(
          widget.parentId!,
        );
        if (derivedCompanyId != null) {
          bottomSheetSelectedCompany = derivedCompanyId;
          String? derivedState = await _findStateNameForCompany(
            derivedCompanyId,
          );
          if (mounted) {
            setState(() {
              bottomSheetSelectedState = derivedState;
            });
            debugPrint(
              'DEBUG: _AddEditHierarchyItemFormState: Derived company and state for new item: $bottomSheetSelectedCompany, $bottomSheetSelectedState',
            );
          }
        }
      }
      selectedOperation = 'Manual'; // Default to Manual for new substations
      selectedStatus = 'Working'; // Default to Working for new substations
    }
  }

  Future<String?> _findStateNameForCompany(String companyId) async {
    debugPrint(
      'DEBUG: _AddEditHierarchyItemFormState: _findStateNameForCompany called for companyId: $companyId',
    );
    try {
      DocumentSnapshot companyDoc = await FirebaseFirestore.instance
          .collection('companys') // Corrected
          .doc(companyId)
          .get();
      debugPrint(
        'DEBUG: _AddEditHierarchyItemFormState: Company doc exists: ${companyDoc.exists}, data: ${companyDoc.data()}',
      );
      if (companyDoc.exists && companyDoc.data() != null) {
        return (companyDoc.data() as Map<String, dynamic>)['stateId'];
      }
    } catch (e) {
      debugPrint(
        "ERROR: _AddEditHierarchyItemFormState: Error finding state for company $companyId: $e",
      );
    }
    return null;
  }

  Future<String?> _findCompanyIdForSubdivision(String subdivisionId) async {
    debugPrint(
      'DEBUG: _AddEditHierarchyItemFormState: _findCompanyIdForSubdivision called for subdivisionId: $subdivisionId',
    );
    try {
      DocumentSnapshot subdivisionDoc = await FirebaseFirestore.instance
          .collection('subdivisions')
          .doc(subdivisionId)
          .get();
      debugPrint(
        'DEBUG: _AddEditHierarchyItemFormState: Subdivision doc exists: ${subdivisionDoc.exists}, data: ${subdivisionDoc.data()}',
      );
      if (subdivisionDoc.exists && subdivisionDoc.data() != null) {
        String? divisionId =
            (subdivisionDoc.data() as Map<String, dynamic>)['divisionId'];
        debugPrint(
          'DEBUG: _AddEditHierarchyItemFormState: Derived divisionId: $divisionId',
        );
        if (divisionId != null) {
          DocumentSnapshot divisionDoc = await FirebaseFirestore.instance
              .collection('divisions')
              .doc(divisionId)
              .get();
          debugPrint(
            'DEBUG: _AddEditHierarchyItemFormState: Division doc exists: ${divisionDoc.exists}, data: ${divisionDoc.data()}',
          );
          if (divisionDoc.exists && divisionDoc.data() != null) {
            String? circleId =
                (divisionDoc.data() as Map<String, dynamic>)['circleId'];
            debugPrint(
              'DEBUG: _AddEditHierarchyItemFormState: Derived circleId: $circleId',
            );
            if (circleId != null) {
              DocumentSnapshot circleDoc = await FirebaseFirestore.instance
                  .collection('circles')
                  .doc(circleId)
                  .get();
              debugPrint(
                'DEBUG: _AddEditHierarchyItemFormState: Circle doc exists: ${circleDoc.exists}, data: ${circleDoc.data()}',
              );
              if (circleDoc.exists && circleDoc.data() != null) {
                return (circleDoc.data() as Map<String, dynamic>)['companyId'];
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint(
        "ERROR: _AddEditHierarchyItemFormState: Error finding company for subdivision $subdivisionId: $e",
      );
    }
    return null;
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
                  // Updated Text for 'Add New State'
                  isEditing
                      ? 'Edit ${widget.itemType}'
                      : widget.itemType == 'AppScreenState'
                      ? 'Add New State' // Specific text for adding states
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
                      // Conditional input for AppScreenState
                      if (widget.itemType == 'AppScreenState')
                        DropdownSearch<String>(
                          selectedItem: bottomSheetSelectedState,
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
                            debugPrint(
                              'DEBUG: DropdownSearch: Fetching states for filter: "$filter"',
                            );
                            final appState = Provider.of<AppStateData>(
                              context,
                              listen: false,
                            );
                            // Get existing states in Firestore to filter out already added states
                            final existingFirestoreStates =
                                await FirebaseFirestore.instance
                                    .collection('appscreenstates')
                                    .get()
                                    .then(
                                      (snapshot) => snapshot.docs
                                          .map((doc) => doc.id)
                                          .toSet(),
                                    ); // Assuming doc.id is the state name
                            debugPrint(
                              'DEBUG: DropdownSearch: Found ${existingFirestoreStates.length} existing Firestore states.',
                            );

                            // Filter available states by search query and exclude already added states
                            final filteredStates = appState.states
                                .where(
                                  (stateName) =>
                                      stateName.toLowerCase().contains(
                                        filter.toLowerCase(),
                                      ) &&
                                      !existingFirestoreStates.contains(
                                        stateName,
                                      ),
                                )
                                .toList();
                            debugPrint(
                              'DEBUG: DropdownSearch: Returning ${filteredStates.length} filtered states.',
                            );
                            return filteredStates;
                          },
                          dropdownDecoratorProps: DropDownDecoratorProps(
                            dropdownSearchDecoration: InputDecoration(
                              labelText: 'Select State',
                              hintText: 'Choose a state to add',
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
                                  'Search or select a state from the list',
                            ),
                          ),
                          onChanged: (String? newValue) {
                            setState(() {
                              bottomSheetSelectedState = newValue;
                              nameController.text =
                                  newValue ??
                                  ''; // Set nameController for form submission
                              debugPrint(
                                'DEBUG: DropdownSearch: Selected state: $newValue',
                              );
                            });
                          },
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please select a state';
                            }
                            return null;
                          },
                        ),
                      // General name field for other hierarchy items
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

                      // Start of conditional fields for various item types
                      // Fields for Company, Zone, Substation (parent state selection)
                      if (widget.itemType == 'Company' ||
                          widget.itemType == 'Substation' ||
                          widget.itemType == 'Zone') ...[
                        const SizedBox(height: 16),
                        // This dropdown is for selecting the PARENT state (from already added states in Firestore)
                        StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('appscreenstates')
                              .orderBy('name')
                              .snapshots(),
                          builder: (context, snapshot) {
                            debugPrint(
                              'DEBUG: Parent State Dropdown: StreamBuilder status: ${snapshot.connectionState}, hasError: ${snapshot.hasError}, hasData: ${snapshot.hasData}',
                            );
                            if (snapshot.hasError) {
                              debugPrint(
                                'ERROR: Parent State Dropdown: ${snapshot.error}',
                              );
                              return Text(
                                'Error loading states: ${snapshot.error}',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.error,
                                  fontSize: 11,
                                ),
                              );
                            }
                            if (!snapshot.hasData ||
                                snapshot.data!.docs.isEmpty) {
                              debugPrint(
                                'DEBUG: Parent State Dropdown: No states found or data not yet available. Docs count: ${snapshot.hasData ? snapshot.data!.docs.length : "N/A"}',
                              );
                              return const Text(
                                'No states found in hierarchy. Please add states first.',
                              );
                            }
                            final statesInHierarchy = snapshot.data!.docs
                                .map((doc) => AppScreenState.fromFirestore(doc))
                                .toList();
                            debugPrint(
                              'DEBUG: Parent State Dropdown: Loaded ${statesInHierarchy.length} states from Firestore.',
                            );
                            return DropdownButtonFormField<String>(
                              value: bottomSheetSelectedState,
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
                              items: statesInHierarchy.map((stateItem) {
                                return DropdownMenuItem<String>(
                                  value: stateItem
                                      .id, // Use the Firestore document ID (state name in this case)
                                  child: Text(
                                    stateItem.name,
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodyMedium,
                                  ),
                                );
                              }).toList(),
                              onChanged: (String? newValue) {
                                setState(() {
                                  bottomSheetSelectedState = newValue;
                                  selectedCityId = null;
                                  selectedCityName = null;
                                  bottomSheetSelectedCompany = null;
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
                            );
                          },
                        ),
                      ],

                      // Company selection for Zone and Substation
                      if (widget.itemType == 'Zone' ||
                          widget.itemType == 'Substation') ...[
                        const SizedBox(height: 16),
                        StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('companys') // Corrected to 'companys'
                              .where(
                                'stateId',
                                isEqualTo: bottomSheetSelectedState,
                              )
                              .orderBy('name')
                              .snapshots(),
                          builder: (context, snapshot) {
                            debugPrint(
                              'DEBUG: Company Dropdown: StreamBuilder status: ${snapshot.connectionState}, hasError: ${snapshot.hasError}, hasData: ${snapshot.hasData}, stateIdFilter: $bottomSheetSelectedState',
                            );
                            if (snapshot.hasError) {
                              debugPrint(
                                'ERROR: Company Dropdown: ${snapshot.error}',
                              );
                              return Text(
                                'Error loading companies: ${snapshot.error}',
                              );
                            }
                            if (!snapshot.hasData ||
                                snapshot.data!.docs.isEmpty) {
                              debugPrint(
                                'DEBUG: Company Dropdown: No companies found or data not yet available. Docs count: ${snapshot.hasData ? snapshot.data!.docs.length : "N/A"}',
                              );
                              return const Text(
                                'No companies available for the selected state.',
                              );
                            }
                            final companies = snapshot.data!.docs
                                .map((doc) => Company.fromFirestore(doc))
                                .toList();
                            debugPrint(
                              'DEBUG: Company Dropdown: Loaded ${companies.length} companies from Firestore.',
                            );
                            return DropdownButtonFormField<String>(
                              value: bottomSheetSelectedCompany,
                              decoration: InputDecoration(
                                labelText: 'Select Company',
                                prefixIcon: Icon(
                                  Icons.business,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                                helperText: 'Choose a company',
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
                              onChanged: (String? newValue) {
                                setState(() {
                                  bottomSheetSelectedCompany = newValue;
                                  debugPrint(
                                    'DEBUG: Company selected: $newValue',
                                  );
                                });
                              },
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please select a company';
                                }
                                return null;
                              },
                            );
                          },
                        ),
                      ],

                      // Bay-specific fields
                      if (widget.itemType == 'Bay') ...[
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          value: selectedBayType,
                          decoration: InputDecoration(
                            labelText: 'Bay Type',
                            prefixIcon: Icon(
                              Icons.category,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            helperText: 'Select the type of bay',
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
                          items: bayTypes.map((String value) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Text(value),
                            );
                          }).toList(),
                          onChanged: (String? newValue) {
                            setState(() {
                              selectedBayType = newValue;
                              debugPrint('DEBUG: Bay Type selected: $newValue');
                            });
                          },
                          validator: (value) =>
                              value == null ? 'Please select a bay type' : null,
                        ),
                        const SizedBox(height: 16),
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
                                'DEBUG: Voltage Level selected: $newValue',
                              );
                            });
                          },
                          validator: (value) => value == null
                              ? 'Please select a voltage level'
                              : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: multiplyingFactorController,
                          decoration: InputDecoration(
                            labelText: 'Multiplying Factor (MF)',
                            prefixIcon: Icon(
                              Icons.clear,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            helperText: 'Optional numerical value',
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
                          keyboardType: TextInputType.number,
                          validator: (value) {
                            if (value != null &&
                                value.isNotEmpty &&
                                double.tryParse(value) == null) {
                              return 'Please enter a valid number for MF';
                            }
                            return null;
                          },
                        ),
                      ],

                      // Substation-specific fields
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
                            if (widget.itemType == 'Substation' &&
                                value == null) {
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
                            if (widget.itemType == 'Substation' &&
                                value == null) {
                              return 'Please select a type';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // OPERATION DROPDOWN (Replacing SwitchListTile)
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
                              // Hide/show sasMakeController based on selection
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
                            if (widget.itemType == 'Substation' &&
                                value == null) {
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
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: Theme.of(context).colorScheme.primary,
                                  width: 2,
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
                        // Date of Commissioning - Made Mandatory with updated typography
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
                            // Validator for Date of Commissioning
                            // This validator will show only if the form is already attempting to validate
                            // and the date is null. The manual check before submission in onPressed
                            // handles the initial mandatory requirement.
                            if (commissioningDate == null &&
                                (_formKey.currentState?.validate() == true &&
                                    !isEditing))
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
                              ? Provider.of<AppStateData>(
                                  context,
                                  listen: false,
                                ).allCityModels.firstWhere(
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
                            debugPrint(
                              'DEBUG: City Dropdown: Fetching cities for filter: "$filter", selectedState: $bottomSheetSelectedState',
                            );
                            if (bottomSheetSelectedState == null) {
                              _showSnackBar(
                                'Please select a state first.',
                                isError: true,
                              );
                              debugPrint(
                                'ERROR: City Dropdown: State not selected.',
                              );
                              return [];
                            }
                            final cities = Provider.of<AppStateData>(
                              context,
                              listen: false,
                            ).getCitiesForStateName(bottomSheetSelectedState!);
                            final filteredCities = cities
                                .where(
                                  (city) => city.name.toLowerCase().contains(
                                    filter.toLowerCase(),
                                  ),
                                )
                                .toList();
                            debugPrint(
                              'DEBUG: City Dropdown: Returning ${filteredCities.length} filtered cities.',
                            );
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
                            if (widget.itemType == 'Substation' &&
                                selectedCityId == null) {
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

                      // General address field for all non-AppScreenState items (Company, Zone, Circle, Division, Subdivision, Bay)
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
                      // These fields will be hidden for AppScreenState
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
                        TextFormField(
                          controller: contactPersonController,
                          decoration: InputDecoration(
                            labelText: 'Contact Person Name (Optional)',
                            prefixIcon: Icon(
                              Icons.person,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            helperText: 'Name of contact',
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
                        // Only show description for AppScreenState, or for other types as a generic description
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
                          // Explicitly trigger validation for the date picker if it's mandatory
                          if (widget.itemType == 'Substation' &&
                              commissioningDate == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Date of Commissioning is mandatory.',
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onError,
                                      ),
                                ),
                                backgroundColor: Theme.of(
                                  context,
                                ).colorScheme.error,
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                margin: const EdgeInsets.all(16),
                                duration: const Duration(seconds: 3),
                                elevation: 4,
                              ),
                            );
                          }
                          return;
                        }

                        // Validate commissioningDate for Substation as it's now mandatory
                        if (widget.itemType == 'Substation' &&
                            commissioningDate == null) {
                          _showSnackBar(
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
                          // Add the general address field
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
                          // When adding a new state, use the selected state name as docId
                          docToUseId = nameController
                              .text; // nameController now holds the selected state name
                          data['name'] = nameController.text;
                          debugPrint(
                            'DEBUG: Add/Edit form: AppScreenState logic - docId: $docToUseId',
                          );
                        } else if (widget.parentCollectionName != null &&
                            widget.parentId != null) {
                          final parentIdKey =
                              '${widget.parentCollectionName!.substring(0, widget.parentCollectionName!.length - 1)}Id';
                          data[parentIdKey] = widget.parentId;
                          debugPrint(
                            'DEBUG: Add/Edit form: Parent ID added - $parentIdKey: ${widget.parentId}',
                          );
                        }

                        if (widget.itemType == 'Company') {
                          data['stateId'] = bottomSheetSelectedState;
                          debugPrint(
                            'DEBUG: Add/Edit form: Company logic - stateId: $bottomSheetSelectedState',
                          );
                        } else if (widget.itemType == 'Zone') {
                          data['companyId'] = bottomSheetSelectedCompany;
                          debugPrint(
                            'DEBUG: Add/Edit form: Zone logic - companyId: $bottomSheetSelectedCompany',
                          );
                        } else if (widget.itemType == 'Bay') {
                          data['bayType'] = selectedBayType;
                          data['voltageLevel'] = selectedVoltageLevel;
                          data['multiplyingFactor'] = double.tryParse(
                            multiplyingFactorController.text,
                          );
                          debugPrint(
                            'DEBUG: Add/Edit form: Bay logic - bayType: $selectedBayType, voltage: $selectedVoltageLevel, MF: ${data['multiplyingFactor']}',
                          );
                        } else if (widget.itemType == 'Substation') {
                          // Substation address is already handled above in the general 'address' field
                          data['cityId'] = selectedCityId?.toString();
                          data['voltageLevel'] = selectedVoltageLevel;
                          data['type'] = typeController.text.isEmpty
                              ? null
                              : typeController.text;
                          data['operation'] =
                              selectedOperation; // Use dropdown value
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
    // This is already a debug tool, no extra debugPrint needed for itself
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        backgroundColor: isError
            ? Theme.of(context).colorScheme.error
            : Theme.of(context).colorScheme.primary.withOpacity(0.9),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
        elevation: 4,
      ),
    );
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
      _showSnackBar('Error: User not logged in.', isError: true);
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
        _showSnackBar('$collectionName added successfully!');
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
            'createdBy': currentUser.uid, // Keep creator info
            'createdAt':
                FieldValue.serverTimestamp(), // Update timestamp on modification
          },
          SetOptions(merge: true), // Merge existing fields with new data
        );
        _showSnackBar('$collectionName updated successfully!');
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
      _showSnackBar(
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

  void _showSnackBar(String message, {bool isError = false}) {
    // This is already a debug tool, no extra debugPrint needed for itself
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        backgroundColor: isError
            ? Theme.of(context).colorScheme.error
            : Theme.of(context).colorScheme.primary.withOpacity(0.9),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
        elevation: 4,
      ),
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
      case 'Substation':
        return 'bays';
      default:
        return ''; // No children
    }
  }

  // Helper to determine the parent ID field name for the next collection
  String _getParentIdFieldName(String currentItemType) {
    switch (currentItemType) {
      case 'Company': // Companies have stateId as parent
        return 'stateId';
      case 'Zone': // Zones have companyId as parent
        return 'companyId';
      case 'Circle': // Circles have zoneId as parent
        return 'zoneId';
      case 'Division': // Divisions have circleId as parent
        return 'circleId';
      case 'Subdivision': // Subdivisions have divisionId as parent
        return 'divisionId';
      case 'Substation': // Substations have subdivisionId as parent
        return 'subdivisionId';
      case 'Bay': // Bays have substationId as parent
        return 'substationId';
      default:
        return ''; // AppScreenState is top-level, no parentIdField for its children
    }
  }

  // Recursive function to check for children
  Future<bool> _hasChildren(String collectionName, String parentId) async {
    // Get the next level's collection name
    final nextCollectionName = _getNextCollectionName(
      collectionName.replaceAll('s', ''), // e.g., 'companys' -> 'company'
    );

    if (nextCollectionName.isEmpty) {
      debugPrint(
        'DEBUG: _hasChildren: No further collections for $collectionName. No children to check.',
      );
      return false; // No more levels down, so no children from here
    }

    // Determine the field name for the parent ID in the child collection
    String parentIdFieldName;
    switch (collectionName) {
      case 'appscreenstates':
        parentIdFieldName = 'stateId';
        break;
      case 'companys':
        parentIdFieldName = 'companyId';
        break;
      case 'zones':
        parentIdFieldName = 'zoneId';
        break;
      case 'circles':
        parentIdFieldName = 'circleId';
        break;
      case 'divisions':
        parentIdFieldName = 'divisionId';
        break;
      case 'subdivisions':
        parentIdFieldName = 'subdivisionId';
        break;
      case 'substations':
        parentIdFieldName = 'substationId';
        break;
      default:
        debugPrint(
          'WARNING: _hasChildren: Unrecognized collection: $collectionName. Assuming no children check available.',
        );
        return false;
    }

    final querySnapshot = await FirebaseFirestore.instance
        .collection(nextCollectionName)
        .where(parentIdFieldName, isEqualTo: parentId)
        .limit(1) // Just need to know if at least one exists
        .get();

    debugPrint(
      'DEBUG: _hasChildren: Checking $nextCollectionName for parent $parentIdFieldName=$parentId. Found ${querySnapshot.docs.length} children.',
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

              final hasChildren = snapshot.data ?? false;
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
                    true; // Default to true to keep button disabled
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
                            _showSnackBar('$name deleted successfully!');
                            debugPrint(
                              'DEBUG: Delete dialog: Item $name deleted successfully.',
                            );
                            if (context.mounted) {
                              Navigator.of(context).pop();
                            }
                          } catch (e) {
                            _showSnackBar(
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
    String? parentIdField,
    String? parentId,
    String? stateIdFilter,
    String? companyIdFilter,
    String nextLevelItemType = '',
  }) {
    debugPrint(
      'DEBUG: _buildHierarchyList: Building list for collection: ${collection.id}',
    );
    debugPrint(
      'DEBUG: _buildHierarchyList: Filters - parentIdField: $parentIdField, parentId: $parentId, stateIdFilter: $stateIdFilter, companyIdFilter: $companyIdFilter',
    );

    Query query = collection;

    // Apply state filter for Companies
    if (collection.id == 'companys' && stateIdFilter != null) {
      // Corrected
      query = query.where('stateId', isEqualTo: stateIdFilter);
      debugPrint(
        'DEBUG: _buildHierarchyList: Applying stateId filter: $stateIdFilter',
      );
    }

    // Apply company filter for Zones
    if (collection.id == 'zones' && companyIdFilter != null) {
      query = query.where('companyId', isEqualTo: companyIdFilter);
      debugPrint(
        'DEBUG: _buildHierarchyList: Applying companyId filter: $companyIdFilter',
      );
    }

    if (parentIdField != null && parentId != null) {
      query = query.where(parentIdField, isEqualTo: parentId);
      debugPrint(
        'DEBUG: _buildHierarchyList: Applying parentId filter: $parentIdField = $parentId',
      );
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
                  // Action buttons for the current item
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16.0,
                      vertical: 8.0,
                    ),
                    child: Wrap(
                      alignment: WrapAlignment
                          .end, // Changed alignment for better button flow
                      spacing: 12.0,
                      runSpacing: 8.0,
                      children: [
                        // Edit button (for the current item)
                        ElevatedButton.icon(
                          onPressed: () {
                            debugPrint(
                              'DEBUG: Edit button pressed for item: ${item.name} (Type: ${item.runtimeType})',
                            );
                            // Determine itemType string for the _showAddBottomSheet
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
                            } else if (item is Bay) {
                              currentItemTypeString = 'Bay';
                            } else {
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
                        // Add Child button (if applicable)
                        if (nextLevelItemType.isNotEmpty)
                          ElevatedButton.icon(
                            onPressed: () {
                              debugPrint(
                                'DEBUG: Add child button pressed for item: ${item.name}, nextLevel: $nextLevelItemType',
                              );
                              _showAddBottomSheet(
                                itemType: nextLevelItemType,
                                parentId: item.id,
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
                        // Delete button (for the current item)
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
                  if (collection.id ==
                      'appscreenstates') // Check if it's a state item
                    _buildHierarchyList<Company>(
                      FirebaseFirestore.instance.collection(
                        'companys',
                      ), // Corrected to 'companys'

                      Company.fromFirestore,
                      stateIdFilter: item.id,
                      nextLevelItemType: 'Zone',
                    ),
                  if (collection.id ==
                      'companys') // Check if it's a company item
                    _buildHierarchyList<Zone>(
                      FirebaseFirestore.instance.collection(
                        'zones',
                      ), // Corrected to 'companys'

                      Zone.fromFirestore,
                      parentIdField: 'companyId',
                      companyIdFilter: item.id,
                      nextLevelItemType: 'Circle',
                    ),
                  if (nextLevelItemType == 'Circle' && item is Zone)
                    _buildHierarchyList<Circle>(
                      FirebaseFirestore.instance.collection('circles'),
                      Circle.fromFirestore,
                      parentIdField: 'zoneId',
                      parentId: item.id,
                      nextLevelItemType: 'Division',
                    ),
                  if (nextLevelItemType == 'Division' && item is Circle)
                    _buildHierarchyList<Division>(
                      FirebaseFirestore.instance.collection('divisions'),
                      Division.fromFirestore,
                      parentIdField: 'circleId',
                      parentId: item.id,
                      nextLevelItemType: 'Subdivision',
                    ),
                  if (nextLevelItemType == 'Subdivision' && item is Division)
                    _buildHierarchyList<Subdivision>(
                      FirebaseFirestore.instance.collection('subdivisions'),
                      Subdivision.fromFirestore,
                      parentIdField: 'divisionId',
                      parentId: item.id,
                      nextLevelItemType: 'Substation',
                    ),
                  if (nextLevelItemType == 'Substation' && item is Subdivision)
                    _buildHierarchyList<Substation>(
                      FirebaseFirestore.instance.collection('substations'),
                      Substation.fromFirestore,
                      parentIdField: 'subdivisionId',
                      parentId: item.id,
                      nextLevelItemType: 'Bay',
                    ),
                  if (nextLevelItemType == 'Bay' && item is Substation)
                    _buildHierarchyList<Bay>(
                      FirebaseFirestore.instance.collection('bays'),
                      Bay.fromFirestore,
                      parentIdField: 'substationId',
                      parentId: item.id,
                      nextLevelItemType: '', // No further levels below Bay
                    ),
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
    // Changed parameter name to nullContext to avoid conflict
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
                            .collection(
                              'appscreenstates',
                            ) // Corrected collection name
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
                                    // Action buttons for the current state (Edit, Add Company, Delete)
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16.0,
                                        vertical: 8.0,
                                      ),
                                      child: Wrap(
                                        alignment: WrapAlignment
                                            .start, // Changed alignment for better button flow
                                        spacing: 12.0,
                                        runSpacing: 8.0,
                                        children: [
                                          // Edit State button
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
                                          // Add Company button
                                          ElevatedButton.icon(
                                            onPressed: () {
                                              debugPrint(
                                                'DEBUG: Add Company button pressed under state: ${stateItem.name}',
                                              );
                                              _showAddBottomSheet(
                                                itemType: 'Company',
                                                parentId: stateItem.id,
                                                parentName: stateItem.name,
                                                parentCollectionName:
                                                    'appscreenstates', // Parent is 'appscreenstates' for 'Company'
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
                                          // Delete State button
                                          ElevatedButton.icon(
                                            onPressed: () {
                                              debugPrint(
                                                'DEBUG: Delete State button pressed for: ${stateItem.name}',
                                              );
                                              _confirmDelete(
                                                'appscreenstates',
                                                stateItem.id,
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
                                      ), // Corrected to 'companys'
                                      Company.fromFirestore,
                                      stateIdFilter: stateItem
                                          .id, // Filter companies by this state's ID
                                      nextLevelItemType: 'Zone',
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
