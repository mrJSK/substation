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

class _AddEditHierarchyItemFormState extends State<_AddEditHierarchyItemForm> {
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
  double? selectedCityId;
  String? selectedCityName;
  String? selectedVoltageLevel;
  String? selectedBayType;
  String? selectedContactDesignation;
  bool isSasOperation = false;
  String? selectedStatus;

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
    super.dispose();
  }

  Future<void> _initializeFormFields() async {
    if (widget.itemToEdit != null) {
      nameController.text = widget.itemToEdit!.name;
      descriptionController.text = widget.itemToEdit!.description ?? '';
      landmarkController.text = widget.itemToEdit!.landmark ?? '';
      contactNumberController.text = widget.itemToEdit!.contactNumber ?? '';
      contactPersonController.text = widget.itemToEdit!.contactPerson ?? '';

      if (widget.itemToEdit is Bay) {
        final bay = widget.itemToEdit as Bay;
        multiplyingFactorController.text =
            bay.multiplyingFactor?.toString() ?? '';
        selectedBayType = bay.bayType;
        selectedVoltageLevel = bay.voltageLevel;
      }

      if (widget.itemToEdit is Zone) {
        bottomSheetSelectedState = (widget.itemToEdit as Zone).stateName;
      }

      if (widget.itemToEdit is Substation) {
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
        selectedContactDesignation = substation.contactDesignation;

        if (substation.subdivisionId != null) {
          String? derivedState = await _findStateNameForSubdivision(
            substation.subdivisionId!,
          );
          if (mounted) {
            setState(() {
              bottomSheetSelectedState = derivedState;
            });
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
      if (widget.itemType == 'Zone' &&
          Provider.of<AppStateData>(context, listen: false).states.isNotEmpty) {
        bottomSheetSelectedState = Provider.of<AppStateData>(
          context,
          listen: false,
        ).states.first;
      } else if (widget.itemType == 'Substation' &&
          widget.parentId != null &&
          widget.parentCollectionName == 'subdivisions') {
        String? derivedState = await _findStateNameForSubdivision(
          widget.parentId!,
        );
        if (mounted) {
          setState(() {
            bottomSheetSelectedState = derivedState;
          });
        }
      }
      isSasOperation = false;
      selectedStatus = 'Working';
    }
  }

  Future<String?> _findStateNameForSubdivision(String subdivisionId) async {
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
                        as Map<String, dynamic>)['stateName'];
                  }
                }
              }
            }
          }
        }
      }
    } catch (e) {
      print("Error finding state for subdivision: $e");
    }
    return null;
  }

  Future<void> _selectCommissioningDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: commissioningDate?.toDate() ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
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
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Container(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                isEditing
                    ? 'Edit ${widget.itemType}'
                    : 'Add New ${widget.itemType}',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              if (widget.parentName != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    'Under: ${widget.parentName}',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ),
              const SizedBox(height: 24),
              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: nameController,
                      decoration: InputDecoration(
                        labelText: '${widget.itemType} Name',
                        prefixIcon: Icon(
                          Icons.edit_note,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        helperText: 'Enter a unique name',
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter a name';
                        }
                        return null;
                      },
                    ),
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
                    if (widget.itemType == 'Substation') ...[
                      const SizedBox(height: 16),
                      Text(
                        'Substation Technical Details',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: Theme.of(context).colorScheme.primary,
                            ),
                      ),
                      const Divider(height: 8),
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
                        ),
                        trailing: const Icon(Icons.calendar_today),
                        onTap: () => _selectCommissioningDate(context),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Substation Location Details',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: Theme.of(context).colorScheme.primary,
                            ),
                      ),
                      const Divider(height: 8),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: bottomSheetSelectedState,
                        decoration: InputDecoration(
                          labelText: 'Select State',
                          prefixIcon: Icon(
                            Icons.map,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          helperText: 'Choose a state',
                        ),
                        isExpanded: true,
                        items: Provider.of<AppStateData>(context, listen: false)
                            .states
                            .map((String state) {
                              return DropdownMenuItem<String>(
                                value: state,
                                child: Text(
                                  state,
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              );
                            })
                            .toList(),
                        onChanged: (String? newValue) {
                          setState(() {
                            bottomSheetSelectedState = newValue;
                            selectedCityId = null;
                            selectedCityName = null;
                          });
                        },
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please select a state';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
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
                            borderRadius: BorderRadius.circular(10),
                          ),
                          searchFieldProps: TextFieldProps(
                            decoration: InputDecoration(
                              labelText: 'Search City',
                              prefixIcon: Icon(
                                Icons.search,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
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
                              borderRadius: BorderRadius.circular(10),
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
                          labelText: 'Substation Address (Specific) (Optional)',
                          prefixIcon: Icon(
                            Icons.location_on,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          helperText: 'Enter detailed address',
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
                    TextFormField(
                      controller: landmarkController,
                      decoration: InputDecoration(
                        labelText: 'Landmark (Optional)',
                        prefixIcon: Icon(
                          Icons.flag,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        helperText: 'Nearby landmark',
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
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: descriptionController,
                      decoration: InputDecoration(
                        labelText: '${widget.itemType} Description (Optional)',
                        prefixIcon: Icon(
                          Icons.description,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        helperText: 'Additional details',
                      ),
                      maxLines: 3,
                    ),
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
                    child: Text(
                      'Cancel',
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
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
                      };

                      if (widget.parentId != null &&
                          widget.parentCollectionName != null) {
                        final parentIdKey =
                            '${widget.parentCollectionName!.substring(0, widget.parentCollectionName!.length - 1)}Id';
                        data[parentIdKey] = widget.parentId;
                      }

                      if (widget.itemType == 'Bay') {
                        data['bayType'] = selectedBayType;
                        data['voltageLevel'] = selectedVoltageLevel;
                        data['multiplyingFactor'] = double.tryParse(
                          multiplyingFactorController.text,
                        );
                      }

                      if (widget.itemType == 'Zone') {
                        data['stateName'] = bottomSheetSelectedState;
                      }

                      if (widget.itemType == 'Substation') {
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
                        data['contactDesignation'] = selectedContactDesignation;
                      }

                      widget.onAddItem(
                        '${widget.itemType.toLowerCase()}s',
                        data,
                        _formKey,
                        isEditing ? widget.itemToEdit!.id : null,
                      );
                    },
                    child: Text(isEditing ? 'Update' : 'Add'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError
            ? Theme.of(context).colorScheme.error
            : Theme.of(context).colorScheme.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }
}

class AdminHierarchyScreen extends StatefulWidget {
  const AdminHierarchyScreen({super.key});

  @override
  State<AdminHierarchyScreen> createState() => _AdminHierarchyScreenState();
}

class _AdminHierarchyScreenState extends State<AdminHierarchyScreen> {
  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
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
      if (docId == null) {
        await FirebaseFirestore.instance.collection(collectionName).add({
          ...data,
          'createdBy': currentUser.uid,
          'createdAt': FieldValue.serverTimestamp(),
        });
        _showSnackBar('$collectionName added successfully!');
      } else {
        await FirebaseFirestore.instance
            .collection(collectionName)
            .doc(docId)
            .update({...data});
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
        borderRadius: BorderRadius.vertical(top: Radius.circular(25.0)),
      ),
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
        content: Text(message),
        backgroundColor: isError
            ? Theme.of(context).colorScheme.error
            : Theme.of(context).colorScheme.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  Widget _buildHierarchyList<T extends HierarchyItem>(
    CollectionReference collection,
    T Function(DocumentSnapshot) fromFirestore, {
    String? parentIdField,
    String? parentId,
    String? stateNameFilter,
    String nextLevelItemType = '',
  }) {
    Query query = collection;
    if (collection.id == 'zones' && stateNameFilter != null) {
      query = query.where('stateName', isEqualTo: stateNameFilter);
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
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.data!.docs.isEmpty) {
          if (parentId != null || stateNameFilter != null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'No ${collection.id} found here. Click the "+" button to add one.',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontStyle: FontStyle.italic,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          } else {
            return const SizedBox.shrink();
          }
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
              elevation: 0,
              margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              child: ExpansionTile(
                key: ValueKey(item.id),
                tilePadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                leading: Icon(
                  Icons.folder,
                  color: Theme.of(context).colorScheme.primary,
                ),
                title: Text(
                  item.name,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                subtitle:
                    item.description != null && item.description!.isNotEmpty
                    ? Text(
                        item.description!,
                        style: TextStyle(color: Colors.grey.shade600),
                      )
                    : null,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16.0,
                      vertical: 8.0,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (item is Substation) ...[
                          if (item.address != null && item.address!.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 4.0),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    Icons.home,
                                    size: 18,
                                    color: Colors.grey.shade600,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Substation Address: ${item.address}',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodySmall,
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
                                    padding: const EdgeInsets.only(bottom: 4.0),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Icon(
                                          Icons.location_city,
                                          size: 18,
                                          color: Colors.grey.shade600,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            'City: ${city.name}',
                                            style: Theme.of(
                                              context,
                                            ).textTheme.bodySmall,
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
                              padding: const EdgeInsets.only(bottom: 4.0),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    Icons.flash_on,
                                    size: 18,
                                    color: Colors.grey.shade600,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Voltage Level: ${item.voltageLevel}',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodySmall,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          if (item.type != null && item.type!.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 4.0),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    Icons.category,
                                    size: 18,
                                    color: Colors.grey.shade600,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Type: ${item.type}',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodySmall,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          if (item.operation != null &&
                              item.operation!.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 4.0),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    Icons.settings,
                                    size: 18,
                                    color: Colors.grey.shade600,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Operation: ${item.operation}',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodySmall,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          if (item.sasMake != null && item.sasMake!.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 4.0),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    Icons.precision_manufacturing,
                                    size: 18,
                                    color: Colors.grey.shade600,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'SAS Make: ${item.sasMake}',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodySmall,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          if (item.commissioningDate != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 4.0),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    Icons.calendar_today,
                                    size: 18,
                                    color: Colors.grey.shade600,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Commissioning Date: ${item.commissioningDate!.toDate().toLocal().toString().split(' ')[0]}',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodySmall,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          if (item.status != null && item.status!.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 4.0),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    Icons.info_outline,
                                    size: 18,
                                    color: Colors.grey.shade600,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Status: ${item.status}',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodySmall,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          if (item.statusDescription != null &&
                              item.statusDescription!.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 4.0),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    Icons.notes,
                                    size: 18,
                                    color: Colors.grey.shade600,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Status Description: ${item.statusDescription}',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodySmall,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          if (item is Substation &&
                              item.contactDesignation != null &&
                              item.contactDesignation!.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 4.0),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    Icons.badge,
                                    size: 18,
                                    color: Colors.grey.shade600,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Designation: ${item.contactDesignation}',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodySmall,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                        if (item.landmark != null && item.landmark!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4.0),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.flag,
                                  size: 18,
                                  color: Colors.grey.shade600,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Landmark: ${item.landmark}',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (item.contactNumber != null &&
                            item.contactNumber!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4.0),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.phone,
                                  size: 18,
                                  color: Colors.grey.shade600,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Contact: ${item.contactNumber}',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (item.contactPerson != null &&
                            item.contactPerson!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4.0),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.person,
                                  size: 18,
                                  color: Colors.grey.shade600,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Person: ${item.contactPerson}',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
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
                      spacing: 8.0,
                      runSpacing: 4.0,
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
                              borderRadius: BorderRadius.circular(8),
                            ),
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
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              textStyle: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(fontWeight: FontWeight.bold),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: Text('Add $nextLevelItemType'),
                          ),
                        ElevatedButton(
                          onPressed: () =>
                              _confirmDelete(collection.id, item.id, item.name),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(
                              context,
                            ).colorScheme.error,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.all(12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
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
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
          content: Text(
            'Are you sure you want to delete "$name"? This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Cancel',
                style: TextStyle(color: Colors.grey.shade700),
              ),
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
              ),
              child: const Text(
                'Delete',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: AppBar(title: const Text('Manage Hierarchy'), centerTitle: true),
      floatingActionButton: FloatingActionButton.extended(
        onPressed:
            Provider.of<AppStateData>(context, listen: false).states.isNotEmpty
            ? () => _showAddBottomSheet(itemType: 'Zone')
            : null,
        label: const Text('Add New Zone'),
        icon: const Icon(Icons.add),
        backgroundColor: Theme.of(context).colorScheme.primary,
      ),
      body: SingleChildScrollView(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Manage Substation Hierarchy',
                  style: Theme.of(context).textTheme.titleLarge,
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
                              color: Colors.grey.shade600,
                              fontStyle: FontStyle.italic,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      );
                    }

                    return StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('zones')
                          .orderBy('stateName')
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return Center(
                            child: Text(
                              'Error: ${snapshot.error}',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
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
                                'No zones found in any state. Click "Add New Zone" to get started!',
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontStyle: FontStyle.italic,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          );
                        }

                        final Set<String> uniqueStatesInZones = {};
                        for (var doc in snapshot.data!.docs) {
                          final data = doc.data() as Map<String, dynamic>;
                          if (data.containsKey('stateName') &&
                              data['stateName'] != null &&
                              data['stateName'].isNotEmpty) {
                            uniqueStatesInZones.add(data['stateName']);
                          }
                        }

                        if (uniqueStatesInZones.isEmpty) {
                          return Center(
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Text(
                                'No zones with state information found. Add a zone with a state!',
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontStyle: FontStyle.italic,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          );
                        }

                        final sortedStates = uniqueStatesInZones.toList()
                          ..sort();

                        return ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: sortedStates.length,
                          itemBuilder: (context, index) {
                            final stateName = sortedStates.elementAt(index);
                            return Card(
                              elevation: 2,
                              margin: const EdgeInsets.symmetric(
                                vertical: 8,
                                horizontal: 0,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: ExpansionTile(
                                key: ValueKey('state-$stateName'),
                                leading: Icon(
                                  Icons.map,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                                title: Text(
                                  stateName,
                                  style: Theme.of(context).textTheme.titleLarge
                                      ?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.primary,
                                      ),
                                ),
                                children: [
                                  _buildHierarchyList<Zone>(
                                    FirebaseFirestore.instance.collection(
                                      'zones',
                                    ),
                                    Zone.fromFirestore,
                                    stateNameFilter: stateName,
                                    nextLevelItemType: 'Circle',
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
    );
  }
}
