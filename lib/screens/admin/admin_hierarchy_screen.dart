// lib/screens/admin/admin_hierarchy_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/hierarchy_models.dart';
import '../../models/app_state_data.dart'; // Contains StateModel and CityModel
import 'package:dropdown_search/dropdown_search.dart';
import 'package:provider/provider.dart'; // Required for Consumer and Provider.of
import '../../models/bay_model.dart';

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
  final TextEditingController substationAddressController =
      TextEditingController();
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
  bool isSasOperation = false;
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
    if (widget.itemToEdit != null) {
      nameController.text = widget.itemToEdit!.name;
      descriptionController.text = widget.itemToEdit!.description ?? '';
      landmarkController.text = widget.itemToEdit!.landmark ?? '';
      contactNumberController.text = widget.itemToEdit!.contactNumber ?? '';
      contactPersonController.text = widget.itemToEdit!.contactPerson ?? '';
      selectedContactDesignation = widget.itemToEdit!.contactDesignation;

      if (widget.itemToEdit is AppScreenState) {
        bottomSheetSelectedState = (widget.itemToEdit as AppScreenState).name;
      } else if (widget.itemToEdit is Company) {
        bottomSheetSelectedState = (widget.itemToEdit as Company).stateId;
      } else if (widget.itemToEdit is Zone) {
        bottomSheetSelectedCompany = (widget.itemToEdit as Zone).companyId;
        if (bottomSheetSelectedCompany != null) {
          String? derivedState = await _findStateNameForCompany(
            bottomSheetSelectedCompany!,
          );
          if (mounted) {
            setState(() {
              bottomSheetSelectedState = derivedState;
            });
          }
        }
      } else if (widget.itemToEdit is Bay) {
        final bay = widget.itemToEdit as Bay;
        multiplyingFactorController.text =
            bay.multiplyingFactor?.toString() ?? '';
        selectedBayType = bay.bayType;
        selectedVoltageLevel = bay.voltageLevel;
      } else if (widget.itemToEdit is Substation) {
        Substation substation = widget.itemToEdit as Substation;
        substationAddressController.text = substation.address ?? '';
        voltageLevelController.text = substation.voltageLevel ?? '';
        typeController.text = substation.type ?? '';
        sasMakeController.text = substation.sasMake ?? '';
        commissioningDate = substation.commissioningDate;
        selectedVoltageLevel = substation.voltageLevel;
        isSasOperation = substation.operation == 'SAS';
        selectedStatus = substation.status;
        statusDescriptionController.text = substation.statusDescription ?? '';

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
          }
        }
      }
    } else {
      // For new items, pre-select parent if available from widget.parentId
      if (widget.parentCollectionName == 'appScreenStates') {
        bottomSheetSelectedState = widget.parentId;
      } else if (widget.parentCollectionName == 'companies') {
        bottomSheetSelectedCompany = widget.parentId;
        if (bottomSheetSelectedCompany != null) {
          String? derivedState = await _findStateNameForCompany(
            bottomSheetSelectedCompany!,
          );
          if (mounted) {
            setState(() {
              bottomSheetSelectedState = derivedState;
            });
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
          }
        }
      }
      isSasOperation = false;
      selectedStatus = 'Working';
    }
  }

  Future<String?> _findStateNameForCompany(String companyId) async {
    try {
      DocumentSnapshot companyDoc = await FirebaseFirestore.instance
          .collection('companies')
          .doc(companyId)
          .get();
      if (companyDoc.exists && companyDoc.data() != null) {
        return (companyDoc.data() as Map<String, dynamic>)['stateId'];
      }
    } catch (e) {
      print("Error finding state for company: $e");
    }
    return null;
  }

  Future<String?> _findCompanyIdForSubdivision(String subdivisionId) async {
    try {
      DocumentSnapshot subdivisionDoc = await FirebaseFirestore.instance
          .collection('subdivisions')
          .doc(subdivisionId)
          .get();
      if (subdivisionDoc.exists && subdivisionDoc.data() != null) {
        String? divisionId =
            (subdivisionDoc.data() as Map<String, dynamic>)['divisionId'];
        if (divisionId != null) {
          DocumentSnapshot divisionDoc = await FirebaseFirestore.instance
              .collection('divisions')
              .doc(divisionId)
              .get();
          if (divisionDoc.exists && divisionDoc.data() != null) {
            String? circleId =
                (divisionDoc.data() as Map<String, dynamic>)['circleId'];
            if (circleId != null) {
              DocumentSnapshot circleDoc = await FirebaseFirestore.instance
                  .collection('circles')
                  .doc(circleId)
                  .get();
              if (circleDoc.exists && circleDoc.data() != null) {
                String? zoneId =
                    (circleDoc.data() as Map<String, dynamic>)['zoneId'];
                if (zoneId != null) {
                  DocumentSnapshot zoneDoc = await FirebaseFirestore.instance
                      .collection('zones')
                      .doc(zoneId)
                      .get();
                  if (zoneDoc.exists && zoneDoc.data() != null) {
                    return (zoneDoc.data()
                        as Map<String, dynamic>)['companyId'];
                  }
                }
              }
            }
          }
        }
      }
    } catch (e) {
      print("Error finding company for subdivision: $e");
    }
    return null;
  }

  Future<void> _selectCommissioningDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: commissioningDate?.toDate() ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
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
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isEditing = widget.itemToEdit != null;
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
                            final appState = Provider.of<AppStateData>(
                              context,
                              listen: false,
                            );
                            // Get existing states in Firestore to filter out already added states
                            final existingFirestoreStates =
                                await FirebaseFirestore.instance
                                    .collection('appScreenStates')
                                    .get()
                                    .then(
                                      (snapshot) => snapshot.docs
                                          .map((doc) => doc.id)
                                          .toSet(),
                                    ); // Assuming doc.id is the state name

                            // Filter available states by search query and exclude already added states
                            return appState.states
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
                              borderSide: BorderSide(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurface.withOpacity(0.2),
                              ),
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
                              .collection('appScreenStates')
                              .orderBy('name')
                              .snapshots(),
                          builder: (context, snapshot) {
                            if (snapshot.hasError) {
                              return Text(
                                'Error loading states: ${snapshot.error}',
                              );
                            }
                            if (!snapshot.hasData ||
                                snapshot.data!.docs.isEmpty) {
                              return const Text(
                                'No states found in hierarchy. Please add states first.',
                              );
                            }
                            final statesInHierarchy = snapshot.data!.docs
                                .map((doc) => AppScreenState.fromFirestore(doc))
                                .toList();
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
                              .collection('companies')
                              .where(
                                'stateId',
                                isEqualTo: bottomSheetSelectedState,
                              )
                              .orderBy('name')
                              .snapshots(),
                          builder: (context, snapshot) {
                            if (snapshot.hasError) {
                              return Text(
                                'Error loading companies: ${snapshot.error}',
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
                              borderSide: BorderSide(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurface.withOpacity(0.2),
                              ),
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
                              borderSide: BorderSide(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurface.withOpacity(0.2),
                              ),
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
                              borderSide: BorderSide(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurface.withOpacity(0.2),
                              ),
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
                              borderSide: BorderSide(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurface.withOpacity(0.2),
                              ),
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
                              borderSide: BorderSide(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurface.withOpacity(0.2),
                              ),
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
                        SwitchListTile(
                          title: Text(
                            'Operation: ${isSasOperation ? "SAS" : "Manual"}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          value: isSasOperation,
                          onChanged: (bool value) {
                            setState(() {
                              isSasOperation = value;
                              if (!isSasOperation) {
                                sasMakeController.clear();
                              }
                            });
                          },
                          activeColor: Theme.of(context).colorScheme.primary,
                          secondary: Icon(
                            Icons.settings,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        if (isSasOperation) ...[
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
                                borderSide: BorderSide(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurface.withOpacity(0.2),
                                ),
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
                              if (isSasOperation &&
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
                              borderSide: BorderSide(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurface.withOpacity(0.2),
                              ),
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
                                borderSide: BorderSide(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurface.withOpacity(0.2),
                                ),
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
                        ListTile(
                          title: Text(
                            commissioningDate == null
                                ? 'Select Commissioning Date (Optional)'
                                : 'Commissioning Date: ${commissioningDate!.toDate().toLocal().toString().split(' ')[0]}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          trailing: Icon(
                            Icons.calendar_today,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          onTap: () => _selectCommissioningDate(context),
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
                            if (bottomSheetSelectedState == null) {
                              _showSnackBar(
                                'Please select a state first.',
                                isError: true,
                              );
                              return [];
                            }
                            final cities = Provider.of<AppStateData>(
                              context,
                              listen: false,
                            ).getCitiesForStateName(bottomSheetSelectedState!);
                            return cities
                                .where(
                                  (city) => city.name.toLowerCase().contains(
                                    filter.toLowerCase(),
                                  ),
                                )
                                .toList();
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
                              borderSide: BorderSide(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurface.withOpacity(0.2),
                              ),
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
                              borderSide: BorderSide(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurface.withOpacity(0.2),
                              ),
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
                            });
                          },
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
                              borderSide: BorderSide(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurface.withOpacity(0.2),
                              ),
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
                              borderSide: BorderSide(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurface.withOpacity(0.2),
                              ),
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
                              borderSide: BorderSide(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurface.withOpacity(0.2),
                              ),
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
                              borderSide: BorderSide(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurface.withOpacity(0.2),
                              ),
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
                        };

                        String? docToUseId = isEditing
                            ? widget.itemToEdit!.id
                            : null;

                        if (widget.itemType == 'AppScreenState') {
                          // When adding a new state, use the selected state name as docId
                          docToUseId = nameController
                              .text; // nameController now holds the selected state name
                          data['name'] = nameController.text;
                        } else if (widget.parentCollectionName != null &&
                            widget.parentId != null) {
                          final parentIdKey =
                              '${widget.parentCollectionName!.substring(0, widget.parentCollectionName!.length - 1)}Id';
                          data[parentIdKey] = widget.parentId;
                        }

                        if (widget.itemType == 'Company') {
                          data['stateId'] = bottomSheetSelectedState;
                        } else if (widget.itemType == 'Zone') {
                          data['companyId'] = bottomSheetSelectedCompany;
                        } else if (widget.itemType == 'Bay') {
                          data['bayType'] = selectedBayType;
                          data['voltageLevel'] = selectedVoltageLevel;
                          data['multiplyingFactor'] = double.tryParse(
                            multiplyingFactorController.text,
                          );
                        } else if (widget.itemType == 'Substation') {
                          data['address'] =
                              substationAddressController.text.isEmpty
                              ? null
                              : substationAddressController.text;
                          data['cityId'] = selectedCityId?.toString();
                          data['voltageLevel'] = selectedVoltageLevel;
                          data['type'] = typeController.text.isEmpty
                              ? null
                              : typeController.text;
                          data['operation'] = isSasOperation ? 'SAS' : 'Manual';
                          data['sasMake'] = sasMakeController.text.isEmpty
                              ? null
                              : sasMakeController.text;
                          data['commissioningDate'] = commissioningDate;
                          data['status'] = selectedStatus;
                          data['statusDescription'] =
                              statusDescriptionController.text.isEmpty
                              ? null
                              : statusDescriptionController.text;
                        }

                        widget.onAddItem(
                          '${widget.itemType.toLowerCase()}s',
                          data,
                          _formKey,
                          docToUseId,
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
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _addHierarchyItem(
    String collectionName,
    Map<String, dynamic> data,
    GlobalKey<FormState> formKey,
    String? docId,
  ) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      _showSnackBar('Error: User not logged in.', isError: true);
      return;
    }

    if (!formKey.currentState!.validate()) {
      return;
    }

    try {
      if (docId == null || docId.isEmpty) {
        // For new documents that don't have a pre-defined ID (like AppScreenState name when adding directly)
        await FirebaseFirestore.instance.collection(collectionName).add({
          ...data,
          'createdBy': currentUser.uid,
          'createdAt': FieldValue.serverTimestamp(),
        });
        _showSnackBar('$collectionName added successfully!');
      } else {
        // For documents where the ID is pre-defined (like AppScreenState using state name)
        // or for updating existing documents.
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
      }

      if (context.mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      _showSnackBar(
        'Failed to ${docId == null ? 'add' : 'update'} $collectionName: ${e.toString()}',
        isError: true,
      );
      print(
        'Error ${docId == null ? 'adding' : 'updating'} $collectionName: $e',
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

  void _confirmDelete(String collection, String docId, String name) {
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
          content: Text(
            'Are you sure you want to delete "$name"? This action cannot be undone.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(
                  context,
                ).colorScheme.onSurface.withOpacity(0.6),
              ),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  await FirebaseFirestore.instance
                      .collection(collection)
                      .doc(docId)
                      .delete();
                  _showSnackBar('$name deleted successfully!');
                  if (context.mounted) {
                    Navigator.of(context).pop();
                  }
                } catch (e) {
                  _showSnackBar(
                    'Failed to delete $name: ${e.toString()}',
                    isError: true,
                  );
                  print('Error deleting $name: $e');
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
    Query query = collection;

    // Apply state filter for Companies
    if (collection.id == 'companies' && stateIdFilter != null) {
      query = query.where('stateId', isEqualTo: stateIdFilter);
    }

    // Apply company filter for Zones
    if (collection.id == 'zones' && companyIdFilter != null) {
      query = query.where('companyId', isEqualTo: companyIdFilter);
    }

    if (parentIdField != null && parentId != null) {
      query = query.where(parentIdField, isEqualTo: parentId);
    }

    query = query.orderBy('name');

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
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
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.data!.docs.isEmpty) {
          String emptyMessage = 'No ${collection.id} found here.';
          if (nextLevelItemType.isNotEmpty) {
            emptyMessage += ' Click "Add $nextLevelItemType" to add one.';
          } else if (collection.id == 'appScreenStates') {
            emptyMessage = 'No states found. Click the "+" button to add one.';
          } else {
            emptyMessage += ' Click the "+" button above to add one.';
          }

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

        final items = snapshot.data!.docs
            .map((doc) => fromFirestore(doc))
            .toList();

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
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
                      vertical: 12.0,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (item is Substation) ...[
                          if (item.address != null && item.address!.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8.0),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    Icons.home,
                                    size: 16,
                                    color: Colors.grey.shade600,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      'Substation Address: ${item.address}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurface
                                                .withOpacity(0.8),
                                            fontSize: 11,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          if (item.cityId != null && item.cityId!.isNotEmpty)
                            Builder(
                              builder: (context) {
                                final appState = Provider.of<AppStateData>(
                                  context,
                                  listen: false,
                                );
                                final city = appState.allCityModels.firstWhere(
                                  (c) => c.id == double.tryParse(item.cityId!),
                                  orElse: () =>
                                      CityModel(id: -1, name: '', stateId: -1),
                                );
                                if (city.id != -1) {
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 8.0),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Icon(
                                          Icons.location_city,
                                          size: 16,
                                          color: Colors.grey.shade600,
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            'City: ${city.name}',
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall
                                                ?.copyWith(
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .onSurface
                                                      .withOpacity(0.8),
                                                  fontSize: 11,
                                                ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }
                                return const SizedBox.shrink();
                              },
                            ),
                          if (item.voltageLevel != null &&
                              item.voltageLevel!.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8.0),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    Icons.flash_on,
                                    size: 16,
                                    color: Colors.grey.shade600,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      'Voltage Level: ${item.voltageLevel}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurface
                                                .withOpacity(0.8),
                                            fontSize: 11,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          if (item.type != null && item.type!.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8.0),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    Icons.category,
                                    size: 16,
                                    color: Colors.grey.shade600,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      'Type: ${item.type}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurface
                                                .withOpacity(0.8),
                                            fontSize: 11,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          if (item.operation != null &&
                              item.operation!.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8.0),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    Icons.settings,
                                    size: 16,
                                    color: Colors.grey.shade600,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      'Operation: ${item.operation}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurface
                                                .withOpacity(0.8),
                                            fontSize: 11,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          if (item.sasMake != null && item.sasMake!.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8.0),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    Icons.precision_manufacturing,
                                    size: 16,
                                    color: Colors.grey.shade600,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      'SAS Make: ${item.sasMake}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurface
                                                .withOpacity(0.8),
                                            fontSize: 11,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          if (item.commissioningDate != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8.0),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    Icons.calendar_today,
                                    size: 16,
                                    color: Colors.grey.shade600,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      'Commissioning Date: ${item.commissioningDate!.toDate().toLocal().toString().split(' ')[0]}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurface
                                                .withOpacity(0.8),
                                            fontSize: 11,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          if (item.status != null && item.status!.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8.0),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    Icons.info_outline,
                                    size: 16,
                                    color: Colors.grey.shade600,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      'Status: ${item.status}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurface
                                                .withOpacity(0.8),
                                            fontSize: 11,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          if (item.statusDescription != null &&
                              item.statusDescription!.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8.0),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    Icons.notes,
                                    size: 16,
                                    color: Colors.grey.shade600,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      'Status Description: ${item.statusDescription}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurface
                                                .withOpacity(0.8),
                                            fontSize: 11,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          if (item is Substation &&
                              item.contactDesignation != null &&
                              item.contactDesignation!.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8.0),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    Icons.badge,
                                    size: 16,
                                    color: Colors.grey.shade600,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      'Designation: ${item.contactDesignation}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurface
                                                .withOpacity(0.8),
                                            fontSize: 11,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                        if (item.landmark != null && item.landmark!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.flag,
                                  size: 16,
                                  color: Colors.grey.shade600,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'Landmark: ${item.landmark}',
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurface
                                              .withOpacity(0.8),
                                          fontSize: 11,
                                        ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (item.contactNumber != null &&
                            item.contactNumber!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.phone,
                                  size: 16,
                                  color: Colors.grey.shade600,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'Contact: ${item.contactNumber}',
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurface
                                              .withOpacity(0.8),
                                          fontSize: 11,
                                        ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (item.contactPerson != null &&
                            item.contactPerson!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.person,
                                  size: 16,
                                  color: Colors.grey.shade600,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'Person: ${item.contactPerson}',
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurface
                                              .withOpacity(0.8),
                                          fontSize: 11,
                                        ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16.0,
                      vertical: 8.0,
                    ),
                    child: Wrap(
                      alignment: WrapAlignment.end,
                      spacing: 12.0,
                      runSpacing: 8.0,
                      children: [
                        ElevatedButton(
                          onPressed: () {
                            _showAddBottomSheet(
                              itemType: (T == Zone)
                                  ? 'Zone'
                                  : (T == Circle)
                                  ? 'Circle'
                                  : (T == Division)
                                  ? 'Division'
                                  : (T == Subdivision)
                                  ? 'Subdivision'
                                  : 'Substation',
                              parentId: (item is Circle)
                                  ? (item as Circle).zoneId
                                  : (item is Division)
                                  ? (item as Division).circleId
                                  : (item is Subdivision)
                                  ? (item as Subdivision).divisionId
                                  : (item is Substation)
                                  ? (item as Substation).subdivisionId
                                  : null,
                              parentName: item.name,
                              parentCollectionName: collection.id,
                              itemToEdit: item,
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(
                              context,
                            ).colorScheme.tertiary,
                            foregroundColor: Theme.of(
                              context,
                            ).colorScheme.onTertiary,
                            padding: const EdgeInsets.all(12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 2,
                          ),
                          child: const Icon(Icons.edit),
                        ),
                        if (nextLevelItemType.isNotEmpty)
                          ElevatedButton(
                            onPressed: () {
                              _showAddBottomSheet(
                                itemType: nextLevelItemType,
                                parentId: item.id,
                                parentName: item.name,
                                parentCollectionName: collection.id,
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Theme.of(
                                context,
                              ).colorScheme.secondary,
                              foregroundColor: Theme.of(
                                context,
                              ).colorScheme.onSecondary,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 2,
                            ),
                            child: Text(
                              'Add $nextLevelItemType',
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                          ),
                        ElevatedButton(
                          onPressed: () =>
                              _confirmDelete(collection.id, item.id, item.name),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(
                              context,
                            ).colorScheme.error,
                            foregroundColor: Theme.of(
                              context,
                            ).colorScheme.onError,
                            padding: const EdgeInsets.all(12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 2,
                          ),
                          child: const Icon(Icons.delete_outline),
                        ),
                      ],
                    ),
                  ),
                  if (nextLevelItemType == 'Circle')
                    _buildHierarchyList<Circle>(
                      FirebaseFirestore.instance.collection('circles'),
                      Circle.fromFirestore,
                      parentIdField: 'zoneId',
                      parentId: item.id,
                      nextLevelItemType: 'Division',
                    ),
                  if (nextLevelItemType == 'Division')
                    _buildHierarchyList<Division>(
                      FirebaseFirestore.instance.collection('divisions'),
                      Division.fromFirestore,
                      parentIdField: 'circleId',
                      parentId: item.id,
                      nextLevelItemType: 'Subdivision',
                    ),
                  if (nextLevelItemType == 'Subdivision')
                    _buildHierarchyList<Subdivision>(
                      FirebaseFirestore.instance.collection('subdivisions'),
                      Subdivision.fromFirestore,
                      parentIdField: 'divisionId',
                      parentId: item.id,
                      nextLevelItemType: 'Substation',
                    ),
                  if (nextLevelItemType == 'Substation')
                    _buildHierarchyList<Substation>(
                      FirebaseFirestore.instance.collection('substations'),
                      Substation.fromFirestore,
                      parentIdField: 'subdivisionId',
                      parentId: item.id,
                      nextLevelItemType: 'Bay',
                    ),
                  if (nextLevelItemType == 'Bay')
                    _buildHierarchyList<Bay>(
                      FirebaseFirestore.instance.collection('bays'),
                      Bay.fromFirestore,
                      parentIdField: 'substationId',
                      parentId: item.id,
                      nextLevelItemType: '',
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
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: AppBar(
        title: const Text('Manage Hierarchy'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Theme.of(context).colorScheme.surface,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddBottomSheet(itemType: 'AppScreenState'),
        label: const Text('Add New State'),
        icon: const Icon(Icons.add),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
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
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Consumer<AppStateData>(
                    builder: (context, appState, child) {
                      if (appState.states.isEmpty) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Text(
                              'No states loaded. Please ensure state_sql_command.txt is correct and loaded.',
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

                      return StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('appScreenStates')
                            .orderBy('name')
                            .snapshots(),
                        builder: (context, snapshot) {
                          if (snapshot.hasError) {
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

                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }

                          if (snapshot.data!.docs.isEmpty) {
                            return Center(
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Text(
                                  'No states found. Click "Add New State" to get started!',
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

                          final states = snapshot.data!.docs
                              .map((doc) => AppScreenState.fromFirestore(doc))
                              .toList();
                          states.sort((a, b) => a.name.compareTo(b.name));

                          return ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: states.length,
                            itemBuilder: (context, index) {
                              final stateItem = states.elementAt(index);
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
                                      context,
                                    ).colorScheme.onSurface.withOpacity(0.1),
                                  ),
                                ),
                                child: ExpansionTile(
                                  key: ValueKey('state-${stateItem.id}'),
                                  leading: Icon(
                                    Icons.map,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                    size: 24,
                                  ),
                                  title: Text(
                                    stateItem.name,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(
                                          fontWeight: FontWeight.w600,
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.primary,
                                        ),
                                  ),
                                  children: [
                                    _buildHierarchyList<Company>(
                                      FirebaseFirestore.instance.collection(
                                        'companies',
                                      ),
                                      Company.fromFirestore,
                                      stateIdFilter: stateItem.id,
                                      nextLevelItemType: 'Zone',
                                    ),
                                    const SizedBox(height: 12),
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
