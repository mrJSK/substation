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
  final String bayId;
  final DateTime readingDate;
  final String frequency; // 'hourly', 'daily', etc.
  final int? readingHour; // Only for hourly readings
  final AppUser currentUser;
  // This parameter is used by SubstationUserDashboardScreen but not required by BayReadingsOverviewScreen
  // Making it optional allows calls without it to compile.
  final String initialFrequencyFilter;

  const LogsheetEntryScreen({
    super.key,
    required this.substationId,
    required this.substationName,
    required this.bayId,
    required this.readingDate,
    required this.frequency,
    this.readingHour,
    required this.currentUser,
    this.initialFrequencyFilter = 'hourly', // Default value, making it optional
  });

  @override
  State<LogsheetEntryScreen> createState() => _LogsheetEntryScreenState();
}

class _LogsheetEntryScreenState extends State<LogsheetEntryScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  bool _isLoading = true;
  bool _isSaving = false;

  Bay? _currentBay; // The bay object for display
  DocumentSnapshot?
  _bayReadingAssignmentDoc; // The actual Firestore document for the assignment
  LogsheetEntry?
  _existingLogsheetEntry; // If an entry for this slot already exists

  List<ReadingField> _filteredReadingFields = [];

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
      // 1. Fetch current bay details for display
      final bayDoc = await FirebaseFirestore.instance
          .collection('bays')
          .doc(widget.bayId)
          .get();
      if (bayDoc.exists) {
        _currentBay = Bay.fromFirestore(bayDoc);
      } else {
        if (mounted) {
          SnackBarUtils.showSnackBar(
            context,
            'Error: Bay not found.',
            isError: true,
          );
          Navigator.of(context).pop();
        }
        return;
      }

      // 2. Fetch the bay's reading assignment
      final assignmentSnapshot = await FirebaseFirestore.instance
          .collection('bayReadingAssignments')
          .where('bayId', isEqualTo: widget.bayId)
          .limit(1)
          .get();

      if (assignmentSnapshot.docs.isNotEmpty) {
        _bayReadingAssignmentDoc = assignmentSnapshot.docs.first;
        final assignedFieldsData =
            (_bayReadingAssignmentDoc!.data()
                    as Map<String, dynamic>)['assignedFields']
                as List<dynamic>;

        final List<ReadingField> allAssignedReadingFields = assignedFieldsData
            .map(
              (fieldMap) =>
                  ReadingField.fromMap(fieldMap as Map<String, dynamic>),
            )
            .toList();

        // Filter fields by the specific frequency for this screen
        _filteredReadingFields = allAssignedReadingFields
            .where(
              (field) =>
                  field.frequency.toString().split('.').last ==
                  widget.frequency,
            )
            .toList();

        // 3. Attempt to fetch an existing logsheet entry for this exact slot
        Query logsheetQuery = FirebaseFirestore.instance
            .collection('logsheetEntries')
            .where('bayId', isEqualTo: widget.bayId)
            .where('frequency', isEqualTo: widget.frequency);

        DateTime queryStartTimestamp;
        DateTime queryEndTimestamp;

        if (widget.frequency == 'hourly' && widget.readingHour != null) {
          queryStartTimestamp = DateTime(
            widget.readingDate.year,
            widget.readingDate.month,
            widget.readingDate.day,
            widget.readingHour!,
          );
          queryEndTimestamp = DateTime(
            widget.readingDate.year,
            widget.readingDate.month,
            widget.readingDate.day,
            widget.readingHour!,
            59,
            59,
            999,
          );
        } else {
          // For daily or other frequencies, use the start of the selected day
          queryStartTimestamp = DateTime(
            widget.readingDate.year,
            widget.readingDate.month,
            widget.readingDate.day,
          );
          queryEndTimestamp = DateTime(
            widget.readingDate.year,
            widget.readingDate.month,
            widget.readingDate.day,
            23,
            59,
            59,
            999,
          );
        }

        logsheetQuery = logsheetQuery
            .where(
              'readingTimestamp',
              isGreaterThanOrEqualTo: Timestamp.fromDate(queryStartTimestamp),
            )
            .where(
              'readingTimestamp',
              isLessThanOrEqualTo: Timestamp.fromDate(queryEndTimestamp),
            );

        final existingLogsheetSnapshot = await logsheetQuery.limit(1).get();

        if (existingLogsheetSnapshot.docs.isNotEmpty) {
          _existingLogsheetEntry = LogsheetEntry.fromFirestore(
            existingLogsheetSnapshot.docs.first,
          );
        }

        // Initialize controllers with existing data or empty
        _initializeReadingFieldControllers(
          _filteredReadingFields,
          _existingLogsheetEntry,
        );
      } else {
        if (mounted) {
          SnackBarUtils.showSnackBar(
            context,
            'No reading template assigned to this bay. Cannot enter readings.',
            isError: true,
          );
          Navigator.of(context).pop();
        }
      }
    } catch (e) {
      print("Error initializing logsheet entry screen: $e");
      if (mounted) {
        SnackBarUtils.showSnackBar(
          context,
          'Failed to load details: $e',
          isError: true,
        );
        Navigator.of(context).pop();
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _initializeReadingFieldControllers(
    List<ReadingField> fields,
    LogsheetEntry? existingEntry,
  ) {
    // Dispose old controllers
    _readingTextFieldControllers.forEach(
      (key, controller) => controller.dispose(),
    );
    _readingBooleanDescriptionControllers.forEach(
      (key, controller) => controller.dispose(),
    );

    _readingTextFieldControllers.clear();
    _readingBooleanFieldValues.clear();
    _readingDateFieldValues.clear();
    _readingDropdownFieldValues.clear();
    _readingBooleanDescriptionControllers.clear();

    final Map<String, dynamic> initialValues = existingEntry?.values ?? {};

    for (var field in fields) {
      final String fieldName = field.name;
      final String dataType = field.dataType.toString().split('.').last;
      final dynamic storedValue = initialValues[fieldName];

      if (dataType == 'text' || dataType == 'number') {
        _readingTextFieldControllers[fieldName] = TextEditingController(
          text: storedValue?.toString() ?? '',
        );
      } else if (dataType == 'boolean') {
        _readingBooleanFieldValues[fieldName] =
            (storedValue is Map && storedValue.containsKey('value'))
            ? (storedValue['value'] as bool? ?? false)
            : false;
        _readingBooleanDescriptionControllers[fieldName] =
            TextEditingController(
              text:
                  (storedValue is Map &&
                      storedValue.containsKey('description_remarks'))
                  ? (storedValue['description_remarks']?.toString() ?? '')
                  : '',
            );
      } else if (dataType == 'date') {
        _readingDateFieldValues[fieldName] = (storedValue is Timestamp)
            ? storedValue.toDate()
            : null;
      } else if (dataType == 'dropdown') {
        _readingDropdownFieldValues[fieldName] = storedValue?.toString();
      }
    }
  }

  Future<void> _saveLogsheetEntry() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (_currentBay == null || _bayReadingAssignmentDoc == null) {
      SnackBarUtils.showSnackBar(
        context,
        'Missing bay or assignment data.',
        isError: true,
      );
      return;
    }
    if (_filteredReadingFields.isEmpty) {
      SnackBarUtils.showSnackBar(
        context,
        'No reading fields to save for this slot.',
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

      // Determine the exact timestamp for the logsheet entry
      DateTime entryTimestamp;
      if (widget.frequency == 'hourly' && widget.readingHour != null) {
        entryTimestamp = DateTime(
          widget.readingDate.year,
          widget.readingDate.month,
          widget.readingDate.day,
          widget.readingHour!,
        );
      } else {
        // For daily or other frequencies, use the start of the selected day
        entryTimestamp = DateTime(
          widget.readingDate.year,
          widget.readingDate.month,
          widget.readingDate.day,
        );
      }

      final logsheetData = LogsheetEntry(
        bayId: widget.bayId,
        templateId: _bayReadingAssignmentDoc!.id,
        readingTimestamp: Timestamp.fromDate(entryTimestamp),
        recordedBy: widget.currentUser.uid,
        recordedAt: Timestamp.now(),
        values: recordedValues,
        frequency: widget.frequency, // Save frequency with the logsheet entry
        readingHour: widget
            .readingHour, // Save hour with the logsheet entry if applicable
      );

      if (_existingLogsheetEntry == null) {
        await FirebaseFirestore.instance
            .collection('logsheetEntries')
            .add(logsheetData.toFirestore());
        if (mounted) {
          SnackBarUtils.showSnackBar(
            context,
            'Logsheet entry saved successfully!',
          );
          Navigator.of(context).pop(); // Go back to overview after saving
        }
      } else {
        await FirebaseFirestore.instance
            .collection('logsheetEntries')
            .doc(_existingLogsheetEntry!.id)
            .update(logsheetData.toFirestore());
        if (mounted) {
          SnackBarUtils.showSnackBar(
            context,
            'Logsheet entry updated successfully!',
          );
          Navigator.of(context).pop(); // Go back to overview after updating
        }
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

    // Determine if fields should be read-only
    final bool isReadOnly =
        _existingLogsheetEntry != null &&
        widget.currentUser.role == UserRole.substationUser;

    final inputDecoration = InputDecoration(
      labelText: fieldName + (isMandatory ? ' *' : ''),
      border: const OutlineInputBorder(),
      suffixText: unit,
      filled: isReadOnly, // Fill background if read-only
      fillColor: isReadOnly
          ? Colors.grey.shade100
          : Theme.of(context).inputDecorationTheme.fillColor,
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
          readOnly: isReadOnly, // Apply read-only
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
          readOnly: isReadOnly, // Apply read-only
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
              onChanged: isReadOnly
                  ? null
                  : (value) {
                      // Disable onChanged if read-only
                      setState(() {
                        _readingBooleanFieldValues[fieldName] = value;
                      });
                    },
              secondary: Icon(Icons.check_box),
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
                  readOnly: isReadOnly, // Apply read-only
                  decoration: inputDecoration.copyWith(
                    labelText: 'Description / Remarks (Optional)',
                    filled: isReadOnly,
                    fillColor: isReadOnly
                        ? Colors.grey.shade100
                        : Theme.of(context).inputDecorationTheme.fillColor,
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
          onTap: isReadOnly
              ? null
              : () async {
                  // Disable onTap if read-only
                  final DateTime? picked = await showDatePicker(
                    context: context,
                    initialDate:
                        _readingDateFieldValues[fieldName] ?? DateTime.now(),
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
          onChanged: isReadOnly
              ? null
              : (value) {
                  // Disable onChanged if read-only
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
      child: AbsorbPointer(
        absorbing:
            isReadOnly, // Absorb pointers for the whole field if read-only
        child: fieldWidget,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    String titleText = "Enter Readings";
    if (_currentBay != null) {
      titleText =
          "${_currentBay!.name} (${StringExtension(widget.frequency).capitalize()}";
      if (widget.frequency == 'hourly' && widget.readingHour != null) {
        titleText += " - ${widget.readingHour!.toString().padLeft(2, '0')}:00)";
      } else {
        titleText += ")";
      }
    }

    final bool isSubstationUserViewingSaved =
        _existingLogsheetEntry != null &&
        widget.currentUser.role == UserRole.substationUser;

    return Scaffold(
      appBar: AppBar(
        title: Text(titleText),
      ), // Added AppBar back for this screen
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
                      'Substation: ${widget.substationName}', // Substation context
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 16),
                    ListTile(
                      title: Text(
                        'Reading Date: ${DateFormat('yyyy-MM-dd').format(widget.readingDate)}',
                      ),
                      trailing: const Icon(Icons.calendar_today),
                      onTap: () {
                        /* Date is passed, not selected here */
                      },
                    ),
                    const SizedBox(height: 24),
                    if (_filteredReadingFields.isEmpty)
                      Center(
                        child: Text(
                          'No ${widget.frequency.toLowerCase()} reading fields defined for this slot.',
                          style: TextStyle(
                            fontStyle: FontStyle.italic,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      )
                    else
                      ..._filteredReadingFields.map((field) {
                        return _buildReadingFieldInput(field);
                      }).toList(),
                    const SizedBox(height: 32),
                    if (!isSubstationUserViewingSaved) // Hide save button if substation user viewing saved
                      Center(
                        child: _isSaving
                            ? const CircularProgressIndicator()
                            : ElevatedButton.icon(
                                onPressed: _saveLogsheetEntry,
                                icon: const Icon(Icons.save),
                                label: Text(
                                  _existingLogsheetEntry == null
                                      ? 'Save Logsheet Entry'
                                      : 'Update Logsheet Entry',
                                ),
                                style: ElevatedButton.styleFrom(
                                  minimumSize: const Size(double.infinity, 50),
                                ),
                              ),
                      ),
                    if (isSubstationUserViewingSaved) // Message for substation users viewing saved data
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Text(
                            'Readings are saved and cannot be modified by Substation Users.',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  fontStyle: FontStyle.italic,
                                  color: Colors.grey.shade700,
                                ),
                          ),
                        ),
                      ),
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
