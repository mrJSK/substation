// lib/screens/logsheet_entry_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../models/bay_model.dart';
import '../models/reading_models.dart'; // ReadingTemplate, ReadingField, ReadingFrequency, ReadingFieldDataType
import '../models/logsheet_models.dart'; // LogsheetEntry
import '../models/user_model.dart'; // AppUser
import '../utils/snackbar_utils.dart';

class LogsheetEntryScreen extends StatefulWidget {
  final String substationId;
  final String substationName;
  final AppUser currentUser;
  final String initialFrequencyFilter; // NEW: Added to receive initial tab

  const LogsheetEntryScreen({
    super.key,
    required this.substationId,
    required this.substationName,
    required this.currentUser,
    this.initialFrequencyFilter = 'hourly', // Default value
  });

  @override
  State<LogsheetEntryScreen> createState() => _LogsheetEntryScreenState();
}

class _LogsheetEntryScreenState extends State<LogsheetEntryScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  bool _isLoading = true;
  bool _isSaving = false;

  List<Bay> _baysInSubstation = [];
  Bay? _selectedBay;
  DocumentSnapshot?
  _bayReadingAssignmentDoc; // The actual Firestore document for the assignment

  List<ReadingField> _filteredReadingFields = [];
  late String
  _selectedFrequencyFilter; // Will be initialized from widget.initialFrequencyFilter
  DateTime _readingDate = DateTime.now(); // Date for daily/monthly readings

  // Controllers/Values for the dynamic reading fields
  final Map<String, TextEditingController> _readingTextFieldControllers = {};
  final Map<String, bool> _readingBooleanFieldValues = {};
  final Map<String, DateTime?> _readingDateFieldValues = {};
  final Map<String, String?> _readingDropdownFieldValues = {};
  final Map<String, TextEditingController>
  _readingBooleanDescriptionControllers = {};

  @override
  void initState() {
    super.initState();
    _selectedFrequencyFilter =
        widget.initialFrequencyFilter; // Initialize with passed filter
    _initializeScreenData();
  }

  @override
  void dispose() {
    _readingTextFieldControllers.forEach(
      (key, controller) => controller.dispose(),
    );
    _readingBooleanDescriptionControllers.forEach(
      (key, controller) => controller.dispose(),
    );
    super.dispose();
  }

  Future<void> _initializeScreenData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Fetch all bays for the current substation
      final baysSnapshot = await FirebaseFirestore.instance
          .collection('bays')
          .where('substationId', isEqualTo: widget.substationId)
          .orderBy('name')
          .get();
      _baysInSubstation = baysSnapshot.docs
          .map((doc) => Bay.fromFirestore(doc))
          .toList();

      if (_baysInSubstation.isNotEmpty) {
        // Automatically select the first bay or try to keep a previously selected one
        _selectedBay = _baysInSubstation.first;
        await _fetchBayReadingAssignment(_selectedBay!.id);
      } else {
        if (mounted) {
          SnackBarUtils.showSnackBar(
            context,
            'No bays found for this substation.',
            isError: true,
          );
        }
      }
    } catch (e) {
      print("Error loading logsheet screen data: $e");
      if (mounted) {
        SnackBarUtils.showSnackBar(
          context,
          'Failed to load data: $e',
          isError: true,
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchBayReadingAssignment(String bayId) async {
    setState(() {
      _isLoading = true;
      _filteredReadingFields.clear();
      _readingTextFieldControllers.clear();
      _readingBooleanFieldValues.clear();
      _readingDateFieldValues.clear();
      _readingDropdownFieldValues.clear();
      _readingBooleanDescriptionControllers.clear();
      _bayReadingAssignmentDoc = null; // Clear previous assignment
    });

    try {
      final assignmentSnapshot = await FirebaseFirestore.instance
          .collection('bayReadingAssignments')
          .where('bayId', isEqualTo: bayId)
          .limit(1)
          .get();

      if (assignmentSnapshot.docs.isNotEmpty) {
        _bayReadingAssignmentDoc = assignmentSnapshot.docs.first;
        final assignedFieldsData =
            (_bayReadingAssignmentDoc!.data()
                    as Map<String, dynamic>)['assignedFields']
                as List<dynamic>;

        // Convert raw assigned fields data into ReadingField objects for easier filtering
        final List<ReadingField> allAssignedReadingFields = assignedFieldsData
            .map(
              (fieldMap) =>
                  ReadingField.fromMap(fieldMap as Map<String, dynamic>),
            )
            .toList();

        _filterReadingFieldsByFrequency(
          allAssignedReadingFields,
          _selectedFrequencyFilter,
        );

        // Initialize controllers with potentially existing values (e.g., if editing a logsheet)
        // For a new entry, controllers will be empty.
        _initializeReadingFieldControllers(_filteredReadingFields);
      } else {
        if (mounted) {
          SnackBarUtils.showSnackBar(
            context,
            'No reading template assigned to this bay. Please assign one first.',
            isError: true,
          );
        }
      }
    } catch (e) {
      print("Error fetching bay reading assignment: $e");
      if (mounted) {
        SnackBarUtils.showSnackBar(
          context,
          'Failed to load bay assignment: $e',
          isError: true,
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _filterReadingFieldsByFrequency(
    List<ReadingField> allFields,
    String frequency,
  ) {
    setState(() {
      _filteredReadingFields = allFields
          .where(
            (field) => field.frequency.toString().split('.').last == frequency,
          )
          .toList();
      // Ensure existing controllers are disposed and new ones are initialized
      // (This part is handled by _initializeReadingFieldControllers now)
      _initializeReadingFieldControllers(_filteredReadingFields);
    });
  }

  void _initializeReadingFieldControllers(List<ReadingField> fields) {
    _readingTextFieldControllers.forEach(
      (key, controller) => controller.dispose(),
    ); // Dispose old ones
    _readingBooleanDescriptionControllers.forEach(
      (key, controller) => controller.dispose(),
    ); // Dispose old ones
    _readingTextFieldControllers.clear();
    _readingBooleanFieldValues.clear();
    _readingDateFieldValues.clear();
    _readingDropdownFieldValues.clear();
    _readingBooleanDescriptionControllers.clear();

    for (var field in fields) {
      final String fieldName = field.name;
      final String dataType = field.dataType.toString().split('.').last;

      if (dataType == 'text' || dataType == 'number') {
        _readingTextFieldControllers[fieldName] =
            TextEditingController(); // Initialize empty for new entry
      } else if (dataType == 'boolean') {
        _readingBooleanFieldValues[fieldName] = false; // Default to false
        _readingBooleanDescriptionControllers[fieldName] =
            TextEditingController();
      } else if (dataType == 'date') {
        _readingDateFieldValues[fieldName] = null; // Default to null
      } else if (dataType == 'dropdown') {
        _readingDropdownFieldValues[fieldName] = null; // Default to null
      }
    }
  }

  Future<void> _selectReadingDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _readingDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(), // Readings typically for past/current date
    );
    if (picked != null && picked != _readingDate) {
      setState(() {
        _readingDate = picked;
      });
    }
  }

  Future<void> _saveLogsheetEntry() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (_selectedBay == null || _bayReadingAssignmentDoc == null) {
      SnackBarUtils.showSnackBar(
        context,
        'Please select a bay and ensure it has an assigned template.',
        isError: true,
      );
      return;
    }
    if (_filteredReadingFields.isEmpty) {
      SnackBarUtils.showSnackBar(
        context,
        'No reading fields to save for the selected frequency.',
        isError: true,
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final Map<String, dynamic> recordedValues = {};
      for (var field in _filteredReadingFields) {
        final String fieldName = field.name;
        final String dataType = field.dataType.toString().split('.').last;

        if (dataType == 'text' || dataType == 'number') {
          recordedValues[fieldName] = _readingTextFieldControllers[fieldName]
              ?.text
              .trim();
        } else if (dataType == 'boolean') {
          recordedValues[fieldName] = {
            'value': _readingBooleanFieldValues[fieldName],
            'description_remarks':
                _readingBooleanDescriptionControllers[fieldName]?.text.trim(),
          };
        } else if (dataType == 'date') {
          recordedValues[fieldName] = _readingDateFieldValues[fieldName] != null
              ? Timestamp.fromDate(_readingDateFieldValues[fieldName]!)
              : null;
        } else if (dataType == 'dropdown') {
          recordedValues[fieldName] = _readingDropdownFieldValues[fieldName];
        }
      }

      final newLogsheetEntry = LogsheetEntry(
        bayId: _selectedBay!.id,
        templateId: _bayReadingAssignmentDoc!
            .id, // Use the assignment document ID as templateId for consistency
        readingTimestamp: Timestamp.fromDate(
          _readingDate,
        ), // Date for the reading
        recordedBy: widget.currentUser.uid,
        recordedAt: Timestamp.now(), // When this entry was submitted
        values: recordedValues,
      );

      await FirebaseFirestore.instance
          .collection('logsheetEntries')
          .add(newLogsheetEntry.toFirestore());

      if (mounted) {
        SnackBarUtils.showSnackBar(
          context,
          'Logsheet entry saved successfully!',
        );
        // Optionally, clear form or navigate back
        _formKey.currentState?.reset(); // Reset form fields
        _initializeReadingFieldControllers(
          _filteredReadingFields,
        ); // Clear controller values
      }
    } catch (e) {
      print("Error saving logsheet entry: $e");
      if (mounted) {
        SnackBarUtils.showSnackBar(
          context,
          'Failed to save logsheet: $e',
          isError: true,
        );
      }
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  // Helper to build dynamic input fields
  Widget _buildReadingFieldInput(ReadingField field) {
    final String fieldName = field.name;
    final String dataType = field.dataType.toString().split('.').last;
    final bool isMandatory = field.isMandatory;
    final String? unit = field.unit;
    final List<String>? options = field.options;
    final String? initialDescriptionRemarks =
        field.descriptionRemarks; // For boolean

    final inputDecoration = InputDecoration(
      labelText: fieldName + (isMandatory ? ' *' : ''),
      border: const OutlineInputBorder(),
      suffixText: unit,
    );

    String? Function(String?)? validator;
    if (isMandatory) {
      validator = (value) {
        if (value == null || value.trim().isEmpty) {
          return '$fieldName is mandatory';
        }
        return null;
      };
    }

    Widget fieldWidget;
    switch (dataType) {
      case 'text':
        fieldWidget = TextFormField(
          controller: _readingTextFieldControllers.putIfAbsent(
            fieldName,
            () => TextEditingController(),
          ),
          decoration: inputDecoration,
          validator: validator,
        );
        break;
      case 'number':
        fieldWidget = TextFormField(
          controller: _readingTextFieldControllers.putIfAbsent(
            fieldName,
            () => TextEditingController(),
          ),
          decoration: inputDecoration.copyWith(
            hintText: unit != null && unit.isNotEmpty
                ? 'Enter value in $unit'
                : null,
          ),
          keyboardType: TextInputType.number,
          validator: (value) {
            if (validator != null && validator(value) != null) {
              return validator(value);
            }
            if (value!.isNotEmpty && double.tryParse(value) == null) {
              return 'Enter a valid number for $fieldName';
            }
            return null;
          },
        );
        break;
      case 'boolean':
        fieldWidget = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SwitchListTile(
              title: Text(fieldName + (isMandatory ? ' *' : '')),
              value: _readingBooleanFieldValues.putIfAbsent(
                fieldName,
                () => false,
              ),
              onChanged: (value) {
                setState(() {
                  _readingBooleanFieldValues[fieldName] = value;
                });
              },
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
            ),
            if (_readingBooleanFieldValues[fieldName]!) // Show description only if true
              Padding(
                padding: const EdgeInsets.only(
                  left: 16.0,
                  right: 16.0,
                  bottom: 8.0,
                ),
                child: TextFormField(
                  controller: _readingBooleanDescriptionControllers.putIfAbsent(
                    fieldName,
                    () =>
                        TextEditingController(text: initialDescriptionRemarks),
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Description / Remarks (Optional)',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(
                      vertical: 10.0,
                      horizontal: 12.0,
                    ),
                  ),
                  maxLines: 2,
                ),
              ),
          ],
        );
        break;
      case 'date':
        fieldWidget = ListTile(
          title: Text(
            fieldName +
                (isMandatory ? ' *' : '') +
                ': ' +
                (_readingDateFieldValues[fieldName] == null
                    ? 'Select Date'
                    : DateFormat(
                        'yyyy-MM-dd',
                      ).format(_readingDateFieldValues[fieldName]!)),
          ),
          trailing: const Icon(Icons.calendar_today),
          onTap: () async {
            final DateTime? picked = await showDatePicker(
              context: context,
              initialDate: _readingDateFieldValues[fieldName] ?? DateTime.now(),
              firstDate: DateTime(2000),
              lastDate: DateTime(2101),
            );
            if (picked != null) {
              setState(() {
                _readingDateFieldValues[fieldName] = picked;
              });
            }
          },
        );
        break;
      case 'dropdown':
        fieldWidget = DropdownButtonFormField<String>(
          value: _readingDropdownFieldValues[fieldName],
          decoration: inputDecoration,
          items: options!.map((option) {
            return DropdownMenuItem(value: option, child: Text(option));
          }).toList(),
          onChanged: (value) {
            setState(() {
              _readingDropdownFieldValues[fieldName] = value;
            });
          },
          validator: validator,
        );
        break;
      default:
        fieldWidget = Text('Unsupported data type: $dataType for $fieldName');
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: fieldWidget,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Removed AppBar from here
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Logsheet for ${widget.substationName}', // Retained substation context
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<Bay>(
                      value: _selectedBay,
                      decoration: const InputDecoration(
                        labelText: 'Select Bay',
                        prefixIcon: Icon(Icons.grid_on),
                        border: OutlineInputBorder(),
                      ),
                      items: _baysInSubstation.map((bay) {
                        return DropdownMenuItem<Bay>(
                          value: bay,
                          child: Text(
                            '${bay.name} (${bay.voltageLevel} ${bay.bayType})',
                          ),
                        );
                      }).toList(),
                      onChanged: (newValue) async {
                        setState(() {
                          _selectedBay = newValue;
                          _isLoading =
                              true; // Show loading while fetching new assignment
                        });
                        if (newValue != null) {
                          await _fetchBayReadingAssignment(newValue.id);
                        } else {
                          setState(() {
                            _isLoading = false;
                            _bayReadingAssignmentDoc = null;
                            _filteredReadingFields.clear();
                          });
                        }
                      },
                      validator: (value) =>
                          value == null ? 'Please select a bay' : null,
                    ),
                    const SizedBox(height: 16),
                    ListTile(
                      title: Text(
                        'Reading Date: ${DateFormat('yyyy-MM-dd').format(_readingDate)}',
                      ),
                      trailing: const Icon(Icons.calendar_today),
                      onTap: () => _selectReadingDate(context),
                    ),
                    const SizedBox(height: 24),
                    if (_selectedBay != null &&
                        _bayReadingAssignmentDoc != null) ...[
                      // The SegmentedButton for frequency is no longer needed here,
                      // as the frequency is now determined by the tab from the parent dashboard.
                      Text(
                        'Enter Readings for ${_selectedFrequencyFilter.capitalize()}',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 16),
                      if (_filteredReadingFields.isEmpty)
                        Text(
                          'No ${_selectedFrequencyFilter.toLowerCase()} reading fields defined for this bay.',
                          style: TextStyle(
                            fontStyle: FontStyle.italic,
                            color: Colors.grey.shade600,
                          ),
                        )
                      else
                        ..._filteredReadingFields.map((field) {
                          return _buildReadingFieldInput(field);
                        }).toList(),
                      const SizedBox(height: 32),
                      Center(
                        child: _isSaving
                            ? const CircularProgressIndicator()
                            : ElevatedButton.icon(
                                onPressed: _saveLogsheetEntry,
                                icon: const Icon(Icons.save),
                                label: const Text('Save Logsheet Entry'),
                                style: ElevatedButton.styleFrom(
                                  minimumSize: const Size(double.infinity, 50),
                                ),
                              ),
                      ),
                    ] else if (!_isLoading && _selectedBay != null) ...[
                      Center(
                        child: Text(
                          'No reading template assigned to "${_selectedBay!.name}". Please assign one via "Substation Details" screen.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontStyle: FontStyle.italic,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
    );
  }
}

// Extension to capitalize first letter
extension StringExtension on String {
  String capitalize() {
    if (isEmpty) {
      return this;
    }
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}
