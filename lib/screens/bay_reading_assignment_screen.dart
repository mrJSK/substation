// lib/screens/bay_reading_assignment_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../models/reading_models.dart';
import '../models/bay_model.dart'; // Import Bay model to get bay type
import '../models/user_model.dart'; // Import AppUser model to check roles
import '../utils/snackbar_utils.dart';

class BayReadingAssignmentScreen extends StatefulWidget {
  final String bayId;
  final String bayName;
  final AppUser currentUser; // Pass the current user for role-based logic

  const BayReadingAssignmentScreen({
    super.key,
    required this.bayId,
    required this.bayName,
    required this.currentUser,
  });

  @override
  State<BayReadingAssignmentScreen> createState() =>
      _BayReadingAssignmentScreenState();
}

class _BayReadingAssignmentScreenState
    extends State<BayReadingAssignmentScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  bool _isLoading = true;
  bool _isSaving = false;
  String?
  _bayType; // The type of the current bay (e.g., 'Transformer', 'Feeder')
  List<ReadingTemplate> _availableReadingTemplates = [];
  ReadingTemplate? _selectedTemplate;
  String?
  _existingAssignmentId; // Firestore document ID if an assignment already exists

  // NEW: State variable for the reading start date
  DateTime? _readingStartDate;

  // List to hold the effective reading fields for this bay (template fields + user-added fields)
  // This is the working list for the UI.
  final List<Map<String, dynamic>> _instanceReadingFields = [];

  // Controllers/Values for the dynamic fields in _instanceReadingFields
  final Map<String, TextEditingController> _textFieldControllers = {};
  final Map<String, bool> _booleanFieldValues = {};
  final Map<String, DateTime?> _dateFieldValues = {};
  final Map<String, String?> _dropdownFieldValues = {};
  final Map<String, TextEditingController> _booleanDescriptionControllers = {};

  final List<String> _dataTypes = ReadingFieldDataType.values
      .map((e) => e.toString().split('.').last)
      .toList();
  final List<String> _frequencies = ReadingFrequency.values
      .map((e) => e.toString().split('.').last)
      .toList();

  @override
  void initState() {
    super.initState();
    _initializeScreenData();
  }

  @override
  void dispose() {
    _textFieldControllers.forEach((key, controller) => controller.dispose());
    _booleanDescriptionControllers.forEach(
      (key, controller) => controller.dispose(),
    );
    super.dispose();
  }

  Future<void> _initializeScreenData() async {
    setState(() {
      _isLoading = true;
    });
    try {
      // 1. Fetch bay details to get its type
      final bayDoc = await FirebaseFirestore.instance
          .collection('bays')
          .doc(widget.bayId)
          .get();
      if (bayDoc.exists) {
        _bayType = (bayDoc.data() as Map<String, dynamic>)['bayType'];
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

      // 2. Fetch all available reading templates for the specific bay type
      final templatesSnapshot = await FirebaseFirestore.instance
          .collection('readingTemplates')
          .where('bayType', isEqualTo: _bayType)
          .orderBy('createdAt', descending: true) // Order to show latest first
          .get();
      _availableReadingTemplates = templatesSnapshot.docs
          .map((doc) => ReadingTemplate.fromFirestore(doc))
          .toList();

      // 3. Fetch existing assignment for this bay
      final existingAssignmentSnapshot = await FirebaseFirestore.instance
          .collection('bayReadingAssignments')
          .where('bayId', isEqualTo: widget.bayId)
          .limit(1)
          .get();

      if (existingAssignmentSnapshot.docs.isNotEmpty) {
        final existingDoc = existingAssignmentSnapshot.docs.first;
        _existingAssignmentId = existingDoc.id;
        final assignedData = existingDoc.data();

        // Load the reading start date if it exists
        if (assignedData.containsKey('readingStartDate') &&
            assignedData['readingStartDate'] != null) {
          _readingStartDate = (assignedData['readingStartDate'] as Timestamp)
              .toDate();
        } else {
          _readingStartDate = DateTime.now(); // Default to today if not set
        }

        // Reconstruct the _selectedTemplate and _instanceReadingFields
        final existingTemplateId = assignedData['templateId'] as String?;
        if (existingTemplateId != null) {
          _selectedTemplate = _availableReadingTemplates.firstWhere(
            (template) => template.id == existingTemplateId,
            orElse: () => _availableReadingTemplates.first, // Fallback
          );
        }

        // Populate _instanceReadingFields from the 'assignedFields' in Firestore
        final List<dynamic> assignedFieldsRaw =
            assignedData['assignedFields'] as List? ?? [];
        _instanceReadingFields.addAll(
          assignedFieldsRaw.map((e) => Map<String, dynamic>.from(e)).toList(),
        );

        // Initialize controllers and values from loaded fields
        _initializeFieldControllers();
      } else {
        // Default start date for new assignments
        _readingStartDate = DateTime.now();
        if (_availableReadingTemplates.isNotEmpty) {
          // If no existing assignment, pre-select the first available template
          _selectedTemplate = _availableReadingTemplates.first;
          _instanceReadingFields.addAll(
            _selectedTemplate!.readingFields.map((e) => e.toMap()).toList(),
          );
          _initializeFieldControllers();
        }
      }
    } catch (e) {
      print("Error loading bay reading assignment screen data: $e");
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

  void _initializeFieldControllers() {
    _textFieldControllers.clear();
    _booleanFieldValues.clear();
    _dateFieldValues.clear();
    _dropdownFieldValues.clear();
    _booleanDescriptionControllers.clear();

    for (var fieldMap in _instanceReadingFields) {
      final String fieldName = fieldMap['name'] as String;
      final String dataType = fieldMap['dataType'] as String;

      if (dataType == 'text' || dataType == 'number') {
        _textFieldControllers[fieldName] = TextEditingController(
          text: fieldMap['value']?.toString() ?? '',
        );
      } else if (dataType == 'boolean') {
        _booleanFieldValues[fieldName] = fieldMap['value'] as bool? ?? false;
        _booleanDescriptionControllers[fieldName] = TextEditingController(
          text: fieldMap['description_remarks']?.toString() ?? '',
        );
      } else if (dataType == 'date') {
        _dateFieldValues[fieldName] = (fieldMap['value'] as Timestamp?)
            ?.toDate();
      } else if (dataType == 'dropdown') {
        _dropdownFieldValues[fieldName] = fieldMap['value']?.toString();
      }
    }
  }

  void _onTemplateSelected(ReadingTemplate? template) {
    if (template == null) return;
    setState(() {
      _selectedTemplate = template;
      _instanceReadingFields.clear();
      _textFieldControllers.clear();
      _booleanFieldValues.clear();
      _dateFieldValues.clear();
      _dropdownFieldValues.clear();
      _booleanDescriptionControllers.clear();

      // Add fields from the newly selected template
      for (var field in template.readingFields) {
        _instanceReadingFields.add(field.toMap());
      }

      _initializeFieldControllers();
    });
  }

  void _addInstanceReadingField() {
    setState(() {
      _instanceReadingFields.add({
        'name': '',
        'dataType': ReadingFieldDataType.text.toString().split('.').last,
        'unit': '',
        'options': [],
        'isMandatory': false,
        'frequency': ReadingFrequency.daily.toString().split('.').last,
        'description_remarks': '', // For boolean
      });
    });
  }

  void _removeInstanceReadingField(int index) {
    setState(() {
      final fieldName = _instanceReadingFields[index]['name'];
      _instanceReadingFields.removeAt(index);

      // Dispose controllers/clear values for removed fields
      _textFieldControllers.remove(fieldName)?.dispose();
      _booleanFieldValues.remove(fieldName);
      _dateFieldValues.remove(fieldName);
      _dropdownFieldValues.remove(fieldName);
      _booleanDescriptionControllers.remove(fieldName)?.dispose();
    });
  }

  Future<void> _saveAssignment() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedTemplate == null) {
      SnackBarUtils.showSnackBar(
        context,
        'Please select a reading template.',
        isError: true,
      );
      return;
    }

    if (_readingStartDate == null) {
      SnackBarUtils.showSnackBar(
        context,
        'Please select a reading start date.',
        isError: true,
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      // Prepare the 'assignedFields' list with current values from UI
      final List<Map<String, dynamic>> finalAssignedFields = [];
      for (var fieldMap in _instanceReadingFields) {
        final String fieldName = fieldMap['name'] as String;
        final String dataType = fieldMap['dataType'] as String;

        // Clone the field map to avoid modifying the original list directly
        Map<String, dynamic> currentFieldData = Map.from(fieldMap);

        // Assign current UI values based on data type
        if (dataType == 'text' || dataType == 'number') {
          currentFieldData['value'] = _textFieldControllers[fieldName]?.text
              .trim();
        } else if (dataType == 'boolean') {
          currentFieldData['value'] = _booleanFieldValues[fieldName];
          currentFieldData['description_remarks'] =
              _booleanDescriptionControllers[fieldName]?.text.trim();
        } else if (dataType == 'date') {
          currentFieldData['value'] = _dateFieldValues[fieldName] != null
              ? Timestamp.fromDate(_dateFieldValues[fieldName]!)
              : null;
        } else if (dataType == 'dropdown') {
          currentFieldData['value'] = _dropdownFieldValues[fieldName];
        }

        finalAssignedFields.add(currentFieldData);
      }

      // Create or update the BayReadingAssignment document
      final Map<String, dynamic> assignmentData = {
        'bayId': widget.bayId,
        'bayType': _bayType, // Store bay type for easier querying
        'templateId': _selectedTemplate!.id!,
        'assignedFields': finalAssignedFields,
        'readingStartDate': Timestamp.fromDate(
          _readingStartDate!,
        ), // Save the start date
        'recordedBy': widget.currentUser.uid, // The user making the assignment
        'recordedAt': FieldValue.serverTimestamp(),
      };

      if (_existingAssignmentId == null) {
        await FirebaseFirestore.instance
            .collection('bayReadingAssignments')
            .add(assignmentData);
        if (mounted) {
          SnackBarUtils.showSnackBar(
            context,
            'Reading template assigned successfully!',
          );
        }
      } else {
        await FirebaseFirestore.instance
            .collection('bayReadingAssignments')
            .doc(_existingAssignmentId)
            .update(assignmentData);
        if (mounted) {
          SnackBarUtils.showSnackBar(
            context,
            'Reading assignment updated successfully!',
          );
        }
      }

      if (mounted) {
        Navigator.of(context).pop(); // Go back after saving
      }
    } catch (e) {
      print("Error saving bay reading assignment: $e");
      if (mounted) {
        SnackBarUtils.showSnackBar(
          context,
          'Failed to save assignment: $e',
          isError: true,
        );
      }
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  Widget _buildFieldInputForAssignment({
    required String fieldName,
    required String dataType,
    String? unit,
    List<String>? options,
    bool isMandatory = false,
    String frequency = '',
    String? initialDescriptionRemarks,
    bool isUserAdded =
        false, // Flag to differentiate template fields from user-added
  }) {
    // Determine which controller map to use based on isUserAdded flag
    final Map<String, TextEditingController> currentTextFieldControllers =
        _textFieldControllers;
    final Map<String, bool> currentBooleanFieldValues = _booleanFieldValues;
    final Map<String, DateTime?> currentDateFieldValues = _dateFieldValues;
    final Map<String, String?> currentDropdownFieldValues =
        _dropdownFieldValues;
    final Map<String, TextEditingController>
    currentBooleanDescriptionControllers = _booleanDescriptionControllers;

    final inputDecoration = InputDecoration(
      labelText: fieldName + (isMandatory ? ' *' : ''),
      border: const OutlineInputBorder(),
      suffixText: unit,
      hintText: (dataType == 'number' && unit != null && unit.isNotEmpty)
          ? 'Enter value in $unit'
          : null,
    );

    // Common validator for all field types
    String? Function(String?)? commonValidator;
    if (isMandatory) {
      commonValidator = (value) {
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
          controller: currentTextFieldControllers.putIfAbsent(
            fieldName,
            () => TextEditingController(),
          ),
          decoration: inputDecoration,
          validator: commonValidator,
        );
        break;
      case 'number':
        fieldWidget = TextFormField(
          controller: currentTextFieldControllers.putIfAbsent(
            fieldName,
            () => TextEditingController(),
          ),
          decoration: inputDecoration.copyWith(suffixText: unit),
          keyboardType: TextInputType.number,
          validator: (value) {
            if (commonValidator != null && commonValidator(value) != null) {
              return commonValidator(value);
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
              value: currentBooleanFieldValues.putIfAbsent(
                fieldName,
                () => false,
              ),
              onChanged: (value) {
                setState(() {
                  currentBooleanFieldValues[fieldName] = value;
                });
              },
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
            ),
            if (currentBooleanFieldValues[fieldName]!) // Show description only if true
              Padding(
                padding: const EdgeInsets.only(
                  left: 16.0,
                  right: 16.0,
                  bottom: 8.0,
                ),
                child: TextFormField(
                  controller: currentBooleanDescriptionControllers.putIfAbsent(
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
                (currentDateFieldValues[fieldName] == null
                    ? 'Select Date'
                    : DateFormat(
                        'yyyy-MM-dd',
                      ).format(currentDateFieldValues[fieldName]!)),
          ),
          trailing: const Icon(Icons.calendar_today),
          onTap: () async {
            final DateTime? picked = await showDatePicker(
              context: context,
              initialDate: currentDateFieldValues[fieldName] ?? DateTime.now(),
              firstDate: DateTime(2000),
              lastDate: DateTime(2101),
            );
            if (picked != null) {
              setState(() {
                currentDateFieldValues[fieldName] = picked;
              });
            }
          },
        );
        break;
      case 'dropdown':
        fieldWidget = DropdownButtonFormField<String>(
          value: currentDropdownFieldValues[fieldName],
          decoration: inputDecoration,
          items: options!.map((option) {
            return DropdownMenuItem(value: option, child: Text(option));
          }).toList(),
          onChanged: (value) {
            setState(() {
              currentDropdownFieldValues[fieldName] = value;
            });
          },
          validator: commonValidator,
        );
        break;
      default:
        fieldWidget = Text('Unsupported data type: $dataType for $fieldName');
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Display the actual input widget
          fieldWidget,
          if (isUserAdded &&
              widget.currentUser.role == UserRole.subdivisionManager)
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                icon: Icon(
                  Icons.remove_circle_outline,
                  color: Theme.of(context).colorScheme.error,
                ),
                onPressed: () {
                  // Find the index of this field to remove it from _instanceReadingFields
                  final fieldIndex = _instanceReadingFields.indexWhere(
                    (element) => element['name'] == fieldName,
                  );
                  if (fieldIndex != -1) {
                    _removeInstanceReadingField(fieldIndex);
                  }
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildReadingFieldDefinitionInput(
    Map<String, dynamic> fieldDef,
    int index,
  ) {
    final String currentFieldName = fieldDef['name'] as String;
    final String currentDataType = fieldDef['dataType'] as String;
    final bool currentIsMandatory = fieldDef['isMandatory'] as bool;
    final String currentUnit = fieldDef['unit'] as String? ?? '';
    final List<String> currentOptions = List.from(fieldDef['options'] ?? []);
    final String currentFrequency = fieldDef['frequency'] as String;
    final String currentDescriptionRemarks =
        fieldDef['description_remarks'] as String? ?? '';

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextFormField(
              initialValue: currentFieldName,
              decoration: const InputDecoration(
                labelText: 'Field Name',
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                setState(() {
                  fieldDef['name'] = value;
                  if (_textFieldControllers.containsKey(currentFieldName)) {
                    _textFieldControllers[value] = _textFieldControllers.remove(
                      currentFieldName,
                    )!;
                  }
                  if (_booleanDescriptionControllers.containsKey(
                    currentFieldName,
                  )) {
                    _booleanDescriptionControllers[value] =
                        _booleanDescriptionControllers.remove(
                          currentFieldName,
                        )!;
                  }
                });
              },
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Field name required'
                  : null,
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: currentDataType,
              decoration: const InputDecoration(
                labelText: 'Data Type',
                border: OutlineInputBorder(),
              ),
              items: _dataTypes.map((type) {
                return DropdownMenuItem(value: type, child: Text(type));
              }).toList(),
              onChanged: (value) {
                setState(() {
                  fieldDef['dataType'] = value!;
                  fieldDef['options'] = [];
                  fieldDef['unit'] = '';
                  fieldDef['description_remarks'] = '';
                });
              },
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: currentFrequency,
              decoration: const InputDecoration(
                labelText: 'Reading Frequency',
                border: OutlineInputBorder(),
              ),
              items: _frequencies.map((freq) {
                return DropdownMenuItem(value: freq, child: Text(freq));
              }).toList(),
              onChanged: (value) {
                setState(() {
                  fieldDef['frequency'] = value!;
                });
              },
            ),
            const SizedBox(height: 10),
            if (currentDataType == 'dropdown')
              TextFormField(
                initialValue: currentOptions.join(','),
                decoration: const InputDecoration(
                  labelText: 'Options (comma-separated)',
                  hintText: 'e.g., Option1, Option2',
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) => fieldDef['options'] = value
                    .split(',')
                    .map((e) => e.trim())
                    .where((e) => e.isNotEmpty)
                    .toList(),
              ),
            if (currentDataType == 'number')
              TextFormField(
                initialValue: currentUnit,
                decoration: const InputDecoration(
                  labelText: 'Unit (e.g., V, A, kW)',
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) => fieldDef['unit'] = value,
              ),
            if (currentDataType == 'boolean')
              TextFormField(
                initialValue: currentDescriptionRemarks,
                decoration: const InputDecoration(
                  labelText: 'Description / Remarks for Boolean (Optional)',
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) => fieldDef['description_remarks'] = value,
                maxLines: 2,
              ),
            CheckboxListTile(
              title: const Text('Mandatory'),
              value: currentIsMandatory,
              onChanged: (value) {
                setState(() {
                  fieldDef['isMandatory'] = value!;
                });
              },
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
            ),
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                icon: Icon(
                  Icons.delete_forever,
                  color: Theme.of(context).colorScheme.error,
                ),
                onPressed: () => _removeInstanceReadingField(index),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectReadingStartDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _readingStartDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null && picked != _readingStartDate) {
      setState(() {
        _readingStartDate = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenHeight = MediaQuery.of(context).size.height;

    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Assign Readings to Bay: ${widget.bayName}'),
        elevation: 0,
      ),
      body: GestureDetector(
        onTap: () =>
            FocusScope.of(context).unfocus(), // Dismiss keyboard on tap
        child: SingleChildScrollView(
          padding: EdgeInsets.all(screenHeight * 0.02),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Bay Type: ${_bayType ?? 'N/A'}',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                ListTile(
                  title: Text(
                    'Reading Start Date: ${DateFormat('dd-MM-yyyy').format(_readingStartDate ?? DateTime.now())}',
                  ),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () => _selectReadingStartDate(context),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(color: Colors.grey.shade300),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Select Reading Template',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                if (_availableReadingTemplates.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Center(
                      child: Text(
                        'No reading templates defined for "${_bayType ?? 'this bay type'}". Please define them in Admin Dashboard > Reading Templates.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontStyle: FontStyle.italic,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ),
                  )
                else
                  DropdownButtonFormField<ReadingTemplate>(
                    value: _selectedTemplate,
                    decoration: const InputDecoration(
                      labelText: 'Choose Reading Template',
                      prefixIcon: Icon(Icons.description),
                      border: OutlineInputBorder(),
                    ),
                    items: _availableReadingTemplates.map((template) {
                      return DropdownMenuItem(
                        value: template,
                        child: Text(
                          template.bayType +
                              (template.id != null
                                  ? ' (${template.id!.substring(0, 4)}...)'
                                  : ''),
                        ),
                      );
                    }).toList(),
                    onChanged: _onTemplateSelected,
                    validator: (value) =>
                        value == null ? 'Please select a template' : null,
                  ),
                const SizedBox(height: 24),
                if (_selectedTemplate != null) ...[
                  Text(
                    'Configured Reading Fields',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _instanceReadingFields.length,
                    itemBuilder: (context, index) {
                      final field = _instanceReadingFields[index];
                      return AnimatedOpacity(
                        opacity: 1.0,
                        duration: const Duration(milliseconds: 300),
                        child: _buildReadingFieldDefinitionInput(field, index),
                      );
                    },
                  ),
                  if (widget.currentUser.role == UserRole.admin ||
                      widget.currentUser.role == UserRole.subdivisionManager)
                    ElevatedButton.icon(
                      onPressed: _addInstanceReadingField,
                      icon: const Icon(Icons.add),
                      label: const Text('Add Additional Reading Field'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.secondary,
                        foregroundColor: theme.colorScheme.onSecondary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  const SizedBox(height: 32),
                ],
                Center(
                  child: _isSaving
                      ? const CircularProgressIndicator()
                      : ElevatedButton.icon(
                          onPressed: _selectedTemplate != null
                              ? _saveAssignment
                              : null,
                          icon: const Icon(Icons.save),
                          label: Text(
                            _existingAssignmentId == null
                                ? 'Save Assignment'
                                : 'Update Assignment',
                          ),
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 50),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 2,
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
