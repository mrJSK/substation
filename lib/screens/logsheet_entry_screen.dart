// lib/screens/logsheet_entry_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../models/bay_model.dart';
import '../models/reading_models.dart';
import '../models/logsheet_models.dart';
import '../models/user_model.dart';
import '../utils/snackbar_utils.dart';

class LogsheetEntryScreen extends StatefulWidget {
  final String substationId;
  final String substationName;
  final String bayId;
  final DateTime readingDate;
  final String frequency;
  final int? readingHour; // Keep this field definition
  final AppUser currentUser;

  const LogsheetEntryScreen({
    super.key,
    required this.substationId,
    required this.substationName,
    required this.bayId,
    required this.readingDate,
    required this.frequency,
    this.readingHour, // Use this named parameter: 'readingHour'
    required this.currentUser,
    int? selectedHour,
    // REMOVE THIS LINE: int? selectedHour, // This was the redundant parameter causing the error
  });

  @override
  State<LogsheetEntryScreen> createState() => _LogsheetEntryScreenState();
}

class _LogsheetEntryScreenState extends State<LogsheetEntryScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  bool _isLoading = true;
  bool _isSaving = false;

  Bay? _currentBay;
  DocumentSnapshot? _bayReadingAssignmentDoc;
  LogsheetEntry? _existingLogsheetEntry;
  LogsheetEntry?
  _previousLogsheetEntry; // Added to store previous day's logsheet

  List<ReadingField> _filteredReadingFields = [];

  final Map<String, TextEditingController> _readingTextFieldControllers = {};
  final Map<String, bool> _readingBooleanFieldValues = {};
  final Map<String, DateTime?> _readingDateFieldValues = {};
  final Map<String, String?> _readingDropdownFieldValues = {};
  final Map<String, TextEditingController>
  _readingBooleanDescriptionControllers = {};

  bool _isFirstDataEntryForThisBayFrequency =
      false; // NEW: Flag for first entry

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

        _filteredReadingFields = allAssignedReadingFields
            .where(
              (field) =>
                  field.frequency.toString().split('.').last ==
                  widget.frequency,
            )
            .toList();

        await _fetchAndInitializeLogsheetEntries(); // This will determine _isFirstDataEntryForThisBayFrequency
      } else {
        _filteredReadingFields = [];
        // If no assignment, it's implicitly the first "entry" if we were to allow it.
        // But for readings, an assignment must exist.
        _isFirstDataEntryForThisBayFrequency = true;
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
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _fetchAndInitializeLogsheetEntries() async {
    _existingLogsheetEntry = await _getLogsheetForDate(widget.readingDate);

    // Determine the previous date based on frequency
    DateTime queryPreviousDate;
    if (widget.frequency == 'daily') {
      queryPreviousDate = widget.readingDate.subtract(const Duration(days: 1));
    } else if (widget.frequency == 'monthly') {
      queryPreviousDate = DateTime(
        widget.readingDate.year,
        widget.readingDate.month - 1,
        widget.readingDate.day,
      );
    } else {
      // For hourly, previous reading from the same day, previous hour
      if (widget.readingHour != null && widget.readingHour! > 0) {
        queryPreviousDate = DateTime(
          widget.readingDate.year,
          widget.readingDate.month,
          widget.readingDate.day,
          widget.readingHour! - 1,
        );
      } else if (widget.readingHour == 0) {
        // If 00 hour, previous is 23 hour of previous day
        queryPreviousDate = DateTime(
          widget.readingDate.year,
          widget.readingDate.month,
          widget.readingDate.day - 1,
          23,
        );
      } else {
        // Fallback for unexpected hourly scenario
        queryPreviousDate = widget.readingDate.subtract(
          const Duration(days: 1),
        );
      }
    }

    _previousLogsheetEntry = await _getLogsheetForDate(queryPreviousDate);

    // Determine if this is the first data entry for this bay/frequency combination
    _isFirstDataEntryForThisBayFrequency =
        _existingLogsheetEntry == null && _previousLogsheetEntry == null;

    _initializeReadingFieldControllers();
  }

  Future<LogsheetEntry?> _getLogsheetForDate(DateTime date) async {
    Query logsheetQuery = FirebaseFirestore.instance
        .collection('logsheetEntries')
        .where('bayId', isEqualTo: widget.bayId)
        .where('frequency', isEqualTo: widget.frequency);

    DateTime start, end;
    if (widget.frequency == 'hourly' && widget.readingHour != null) {
      start = DateTime(date.year, date.month, date.day, widget.readingHour!);
      end = start
          .add(const Duration(hours: 1))
          .subtract(const Duration(milliseconds: 1)); // End of the hour
    } else {
      // Daily or Monthly
      start = DateTime(date.year, date.month, date.day);
      end = DateTime(date.year, date.month, date.day, 23, 59, 59, 999);
    }

    logsheetQuery = logsheetQuery
        .where(
          'readingTimestamp',
          isGreaterThanOrEqualTo: Timestamp.fromDate(start),
        )
        .where(
          'readingTimestamp',
          isLessThanOrEqualTo: Timestamp.fromDate(end),
        );

    final snapshot = await logsheetQuery.limit(1).get();
    if (snapshot.docs.isNotEmpty) {
      return LogsheetEntry.fromFirestore(snapshot.docs.first);
    }
    return null;
  }

  void _initializeReadingFieldControllers() {
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

    final Map<String, dynamic> existingValues =
        _existingLogsheetEntry?.values ?? {};
    final Map<String, dynamic> previousValues =
        _previousLogsheetEntry?.values ?? {};

    for (var field in _filteredReadingFields) {
      final fieldName = field.name;
      final dataType = field.dataType.toString().split('.').last;
      dynamic value = existingValues[fieldName];

      // Auto-fill logic for "Previous Day/Month Reading"
      if (_existingLogsheetEntry == null) {
        // Only pre-fill if it's a new entry (not editing an existing one)
        if (fieldName.startsWith('Previous Day Reading') &&
            previousValues.containsKey(
              fieldName.replaceFirst('Previous Day', 'Current Day'),
            )) {
          value =
              previousValues[fieldName.replaceFirst(
                'Previous Day',
                'Current Day',
              )];
        } else if (fieldName.startsWith('Previous Month Reading') &&
            previousValues.containsKey(
              fieldName.replaceFirst('Previous Month', 'Current Month'),
            )) {
          value =
              previousValues[fieldName.replaceFirst(
                'Previous Month',
                'Current Month',
              )];
        }
      }

      if (dataType == 'text' || dataType == 'number') {
        _readingTextFieldControllers[fieldName] = TextEditingController(
          text: value?.toString() ?? '',
        );
      } else if (dataType == 'boolean') {
        _readingBooleanFieldValues[fieldName] =
            (value is Map && value.containsKey('value'))
            ? (value['value'] as bool? ?? false)
            : false;
        _readingBooleanDescriptionControllers[fieldName] =
            TextEditingController(
              text: (value is Map && value.containsKey('description_remarks'))
                  ? (value['description_remarks']?.toString() ?? '')
                  : '',
            );
      } else if (dataType == 'date') {
        _readingDateFieldValues[fieldName] = (value is Timestamp)
            ? value.toDate()
            : null;
      } else if (dataType == 'dropdown') {
        _readingDropdownFieldValues[fieldName] = value?.toString();
      }
    }
  }

  Future<void> _saveLogsheetEntry() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (_currentBay == null ||
        (_bayReadingAssignmentDoc == null &&
            _filteredReadingFields.any(
              (field) => !field.name.contains('Reading'),
            ))) {
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

    final String modificationReason =
        await _showModificationReasonDialog() ?? "";
    if (widget.currentUser.role == UserRole.subdivisionManager &&
        _existingLogsheetEntry != null &&
        modificationReason.isEmpty) {
      SnackBarUtils.showSnackBar(
        context,
        'A reason is required to modify an existing reading.',
        isError: true,
      );
      setState(() => _isSaving = false);
      return;
    }

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

      DateTime entryTimestamp;
      if (widget.frequency == 'hourly' && widget.readingHour != null) {
        entryTimestamp = DateTime(
          widget.readingDate.year,
          widget.readingDate.month,
          widget.readingDate.day,
          widget.readingHour!,
        );
      } else {
        entryTimestamp = DateTime(
          widget.readingDate.year,
          widget.readingDate.month,
          widget.readingDate.day,
        );
      }

      final logsheetData = LogsheetEntry(
        bayId: widget.bayId,
        templateId: _bayReadingAssignmentDoc?.id ?? 'HARDCODED_ENERGY_ACCOUNT',
        readingTimestamp: Timestamp.fromDate(entryTimestamp),
        recordedBy: widget.currentUser.uid,
        recordedAt: Timestamp.now(),
        values: recordedValues,
        frequency: widget.frequency,
        readingHour: widget.readingHour,
        substationId: widget.substationId,
        modificationReason: modificationReason,
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
          Navigator.of(context).pop();
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
          Navigator.of(context).pop();
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

  Future<String?> _showModificationReasonDialog() async {
    if (widget.currentUser.role != UserRole.subdivisionManager ||
        _existingLogsheetEntry == null) {
      return "Initial Entry";
    }

    TextEditingController reasonController = TextEditingController();
    return await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reason for Modification'),
        content: TextField(
          controller: reasonController,
          decoration: const InputDecoration(hintText: "Enter reason..."),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(reasonController.text),
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }

  Widget _buildReadingFieldInput(ReadingField field) {
    final String fieldName = field.name;
    final String dataType = field.dataType.toString().split('.').last;
    bool isMandatory = field.isMandatory; // Can be overridden

    // NEW: Conditional mandatory logic for "Previous Day/Month Reading"
    final bool isPreviousReadingField =
        fieldName.startsWith('Previous Day Reading') ||
        fieldName.startsWith('Previous Month Reading');

    if (isPreviousReadingField && _isFirstDataEntryForThisBayFrequency) {
      isMandatory = false; // Make optional for the first entry
    }

    final String? unit = field.unit;
    final List<String>? options = field.options;
    final String? initialDescriptionRemarks = field.descriptionRemarks;

    // Determine if the field should be read-only (e.g., Substation User viewing saved, or Previous Reading field)
    final bool isReadOnly =
        (widget.currentUser.role == UserRole.substationUser &&
            _existingLogsheetEntry != null) ||
        (isPreviousReadingField &&
            _existingLogsheetEntry == null &&
            _previousLogsheetEntry !=
                null); // If it's a new entry, and previous logsheet exists, previous reading field is read-only

    final inputDecoration = InputDecoration(
      labelText: fieldName + (isMandatory ? ' *' : ''),
      border: const OutlineInputBorder(),
      suffixText: unit,
      filled: isReadOnly,
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
    } else {
      validator = null; // Ensure validator is null if not mandatory
    }

    Widget fieldWidget;
    switch (dataType) {
      case 'text':
        fieldWidget = TextFormField(
          controller: _readingTextFieldControllers.putIfAbsent(
            fieldName,
            () => TextEditingController(),
          ),
          readOnly: isReadOnly,
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
          readOnly: isReadOnly,
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
                      setState(() {
                        _readingBooleanFieldValues[fieldName] = value;
                      });
                    },
              secondary: const Icon(Icons.check_box),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
            ),
            if (_readingBooleanFieldValues[fieldName]!)
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
                  readOnly: isReadOnly,
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
            // NEW: Display validation error for boolean if mandatory and not true
            if (isMandatory &&
                !_readingBooleanFieldValues[fieldName]! &&
                _formKey.currentState?.validate() ==
                    false) // Simplified check for validation trigger
              Padding(
                padding: const EdgeInsets.only(left: 48.0, top: 4.0),
                child: Text(
                  '$fieldName is mandatory',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontSize: 12,
                  ),
                ),
              ),
          ],
        );
        break;
      case 'date':
        // Corrected initialization of currentDate
        final DateTime?
        currentDate = _readingDateFieldValues.putIfAbsent(fieldName, () {
          if (_readingDateFieldValues.containsKey(fieldName)) {
            return _readingDateFieldValues[fieldName];
          }
          if (field.isMandatory && _existingLogsheetEntry == null) {
            return widget
                .readingDate; // Default to current reading date for new mandatory date fields
          }
          return null; // Otherwise null
        });

        fieldWidget = ListTile(
          title: Text(
            fieldName +
                (isMandatory ? ' *' : '') +
                ': ' +
                (currentDate == null
                    ? 'Select Date'
                    : DateFormat('yyyy-MM-dd').format(currentDate)),
          ),
          trailing: const Icon(Icons.calendar_today),
          onTap: isReadOnly
              ? null
              : () async {
                  final DateTime? picked = await showDatePicker(
                    context: context,
                    initialDate: currentDate ?? DateTime.now(),
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
      child: AbsorbPointer(absorbing: isReadOnly, child: fieldWidget),
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
      appBar: AppBar(title: Text(titleText)),
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
                      'Substation: ${widget.substationName}',
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
                    const SizedBox(height: 16),
                    if (_currentBay?.multiplyingFactor != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 24.0),
                        child: Center(
                          child: Chip(
                            label: Text(
                              'Multiplying Factor (MF): ${_currentBay!.multiplyingFactor}',
                            ),
                            backgroundColor: Theme.of(
                              context,
                            ).colorScheme.secondaryContainer,
                          ),
                        ),
                      ),
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
                    if (!isSubstationUserViewingSaved)
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
                    if (isSubstationUserViewingSaved)
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

extension StringExtension on String {
  String capitalize() {
    if (isEmpty) {
      return this;
    }
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}
