// lib/screens/create_report_template_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/app_state_data.dart'; // Ensure this path is correct
import '../models/bay_model.dart'; // Ensure this path is correct
import '../models/reading_models.dart'; // Ensure this path is correct
import '../models/report_template_model.dart'; // Import ReportTemplate model
import '../utils/snackbar_utils.dart'; // Ensure this path is correct for SnackbarUtils

class CreateReportTemplateScreen extends StatefulWidget {
  static const routeName = '/create-report-template';

  const CreateReportTemplateScreen({super.key});

  @override
  State<CreateReportTemplateScreen> createState() =>
      _CreateReportTemplateScreenState();
}

class _CreateReportTemplateScreenState
    extends State<CreateReportTemplateScreen> {
  final _templateNameController = TextEditingController();
  List<Bay> _availableBays = [];
  List<ReadingTemplate> _allReadingTemplates = []; // Store all templates
  List<ReadingField> _filteredReadingFields =
      []; // Fields shown based on selected bays

  List<String> _selectedBayIds = [];
  List<String> _selectedReadingFieldNames =
      []; // Changed to use field names (ReadingField.name)
  ReportFrequency _selectedFrequency = ReportFrequency.daily;
  List<CustomReportColumn> _customColumns = [];

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchInitialData();
  }

  @override
  void dispose() {
    _templateNameController.dispose();
    super.dispose();
  }

  Future<void> _fetchInitialData() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final appState = Provider.of<AppStateData>(context, listen: false);
      final substationId = appState.selectedSubstation?.id;

      if (substationId == null) {
        if (mounted) {
          SnackBarUtils.showSnackBar(
            context,
            'No substation selected. Please select a substation from the dashboard first.',
          );
        }
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // Fetch Bays for the selected substation
      final bayDocs = await FirebaseFirestore.instance
          .collection('bays')
          .where('substationId', isEqualTo: substationId)
          .get();
      _availableBays = bayDocs.docs
          .map((doc) => Bay.fromFirestore(doc))
          .toList();
      _availableBays.sort(
        (a, b) => a.name.compareTo(b.name),
      ); // Sort bays by name

      // Fetch all Reading Templates
      final readingTemplateDocs = await FirebaseFirestore.instance
          .collection('readingTemplates')
          .get();
      _allReadingTemplates = readingTemplateDocs.docs
          .map((doc) => ReadingTemplate.fromFirestore(doc))
          .toList();

      // No initial filtering needed here, it happens when bays are selected.
      // _filterReadingFields(); // This will be called on bay selection
    } catch (e) {
      if (mounted) {
        SnackBarUtils.showSnackBar(context, 'Error loading data: $e');
      }
      print('Error loading data for CreateReportTemplateScreen: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // New method to filter reading fields based on selected bays' types
  void _filterReadingFields() {
    Set<String> selectedBayTypes = {};
    for (String bayId in _selectedBayIds) {
      // Find the Bay object corresponding to the selected ID
      final bay = _availableBays.firstWhere(
        (b) => b.id == bayId,
        orElse: () => Bay(
          id: '',
          name: 'Unknown',
          substationId: '',
          bayType: 'Unknown',
          voltageLevel: '',
          createdBy: '',
          createdAt: Timestamp.now(),
        ), // Provide a default or handle error
      );
      if (bay.bayType.isNotEmpty && bay.bayType != 'Unknown') {
        // Ensure valid bayType
        selectedBayTypes.add(bay.bayType);
      }
    }

    Set<ReadingField> uniqueFilteredFields = {};
    for (var template in _allReadingTemplates) {
      // Check if this template's singular bayType matches any of the selected bay types
      if (selectedBayTypes.contains(template.bayType)) {
        for (var field in template.readingFields) {
          if (field.name.isNotEmpty && field.dataType != null) {
            uniqueFilteredFields.add(field);
          }
        }
      }
    }
    _filteredReadingFields = uniqueFilteredFields.toList();
    _filteredReadingFields.sort((a, b) => a.name.compareTo(b.name));

    // Deselect any reading fields that are no longer available
    _selectedReadingFieldNames.removeWhere(
      (fieldName) =>
          !_filteredReadingFields.any((field) => field.name == fieldName),
    );

    // Deselect any custom columns whose base or secondary fields are no longer available
    _customColumns.removeWhere((column) {
      bool baseFieldExists = _filteredReadingFields.any(
        (field) => field.name == column.baseReadingFieldId,
      );
      bool secondaryFieldExists = true; // Assume true if no secondary field
      if (column.secondaryReadingFieldId != null) {
        secondaryFieldExists = _filteredReadingFields.any(
          (field) => field.name == column.secondaryReadingFieldId,
        );
      }
      return !baseFieldExists || !secondaryFieldExists;
    });

    setState(() {}); // Trigger rebuild to update UI with filtered fields
  }

  void _addCustomColumn() {
    showDialog(
      context: context,
      builder: (ctx) => AddCustomColumnDialog(
        availableReadingFields: _filteredReadingFields, // Pass filtered fields
        onAdd: (column) {
          setState(() {
            _customColumns.add(column);
          });
        },
      ),
    );
  }

  Future<void> _saveReportTemplate() async {
    if (_templateNameController.text.trim().isEmpty) {
      SnackBarUtils.showSnackBar(context, 'Please enter a template name.');
      return;
    }
    if (_selectedBayIds.isEmpty) {
      SnackBarUtils.showSnackBar(context, 'Please select at least one Bay.');
      return;
    }
    if (_selectedReadingFieldNames.isEmpty && _customColumns.isEmpty) {
      SnackBarUtils.showSnackBar(
        context,
        'Please select at least one Reading Field or define a Custom Column.',
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final appState = Provider.of<AppStateData>(context, listen: false);
      final currentUser = appState.currentUser;
      final substationId = appState.selectedSubstation?.id;

      if (currentUser == null || substationId == null) {
        if (mounted) {
          SnackBarUtils.showSnackBar(
            context,
            'User or Substation not selected. Please log in again or select a substation.',
          );
        }
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // Collect selected bay types based on selected bays
      Set<String> selectedBayTypes = {};
      for (String bayId in _selectedBayIds) {
        final bay = _availableBays.firstWhere((b) => b.id == bayId);
        selectedBayTypes.add(bay.bayType);
      }
      List<String> selectedBayTypeIds = selectedBayTypes.toList();

      final newTemplate = ReportTemplate(
        templateName: _templateNameController.text.trim(),
        createdByUid: currentUser.uid,
        substationId: substationId,
        selectedBayIds: _selectedBayIds,
        selectedBayTypeIds: selectedBayTypeIds,
        selectedReadingFieldIds: _selectedReadingFieldNames,
        frequency: _selectedFrequency,
        customColumns: _customColumns,
      );

      await FirebaseFirestore.instance
          .collection('reportTemplates')
          .add(newTemplate.toMap());
      if (mounted) {
        SnackBarUtils.showSnackBar(
          context,
          'Report template saved successfully!',
        );
        Navigator.of(context).pop(); // Go back to dashboard
      }
    } catch (e) {
      if (mounted) {
        SnackBarUtils.showSnackBar(context, 'Error saving template: $e');
      }
      print('Error saving template: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Report Template')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _templateNameController,
                    decoration: const InputDecoration(
                      labelText: 'Report Template Name',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Select Bays:',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  _availableBays.isEmpty
                      ? const Text(
                          'No bays available for the selected substation.',
                          style: TextStyle(fontStyle: FontStyle.italic),
                        )
                      : Wrap(
                          spacing: 8.0,
                          runSpacing: 4.0,
                          children: _availableBays.map((bay) {
                            final isSelected = _selectedBayIds.contains(bay.id);
                            return FilterChip(
                              label: Text('${bay.name} (${bay.bayType})'),
                              selected: isSelected,
                              onSelected: (selected) {
                                setState(() {
                                  if (bay.id != null) {
                                    if (selected) {
                                      _selectedBayIds.add(bay.id!);
                                    } else {
                                      _selectedBayIds.remove(bay.id!);
                                    }
                                    _filterReadingFields();
                                  }
                                });
                              },
                            );
                          }).toList(),
                        ),
                  const SizedBox(height: 20),
                  Text(
                    'Select Reading Fields:',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  _selectedBayIds.isEmpty
                      ? const Text(
                          'Select one or more bays to see available reading fields.',
                          style: TextStyle(fontStyle: FontStyle.italic),
                        )
                      : _filteredReadingFields.isEmpty
                      ? const Text(
                          'No reading fields available for the selected bay types.',
                          style: TextStyle(fontStyle: FontStyle.italic),
                        )
                      : Wrap(
                          spacing: 8.0,
                          runSpacing: 4.0,
                          children: _filteredReadingFields.map((field) {
                            final isSelected = _selectedReadingFieldNames
                                .contains(field.name);
                            return FilterChip(
                              label: Text(
                                '${field.name} ${field.unit != null && field.unit!.isNotEmpty ? '(${field.unit})' : ''}',
                              ),
                              selected: isSelected,
                              onSelected: (selected) {
                                setState(() {
                                  if (field.name.isNotEmpty) {
                                    if (selected) {
                                      _selectedReadingFieldNames.add(
                                        field.name,
                                      );
                                    } else {
                                      _selectedReadingFieldNames.remove(
                                        field.name,
                                      );
                                    }
                                  }
                                });
                              },
                            );
                          }).toList(),
                        ),
                  const SizedBox(height: 20),
                  Text(
                    'Select Report Frequency:',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  // REVISED FIX FOR OVERFLOW: Use a Column of RadioListTiles if space is tight,
                  // or adjust padding if they must be in a row.
                  // For a fixed number of items and potentially long labels,
                  // allowing them to stack or wrap is best.
                  Wrap(
                    // Using Wrap allows them to flow to the next line
                    spacing: 8.0, // Horizontal spacing between chips/tiles
                    runSpacing:
                        4.0, // Vertical spacing between lines of chips/tiles
                    children: ReportFrequency.values.map((freq) {
                      // Skip 'onDemand' for frequency selection in UI if not desired
                      if (freq == ReportFrequency.onDemand) {
                        return const SizedBox.shrink(); // Hides the "onDemand" radio button
                      }
                      return SizedBox(
                        // Wrap each RadioListTile in SizedBox or IntrinsicWidth to control its size
                        width: 120, // Give it a fixed width, adjust as needed
                        child: RadioListTile<ReportFrequency>(
                          title: Text(
                            freq.toShortString().capitalize(),
                            maxLines:
                                1, // Ensure title doesn't wrap within the RadioListTile
                            overflow: TextOverflow
                                .ellipsis, // Add ellipsis if still too long (last resort)
                          ),
                          value: freq,
                          groupValue: _selectedFrequency,
                          onChanged: (ReportFrequency? value) {
                            setState(() {
                              _selectedFrequency = value!;
                            });
                          },
                          dense: true, // Make the tile more compact
                          contentPadding: EdgeInsets
                              .zero, // Remove internal padding if needed
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Custom Columns:',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      // FIX FOR OVERFLOW for the button:
                      Expanded(
                        // Use Expanded to give the button flexible space
                        child: Align(
                          // Align the button to the right if there's extra space
                          alignment: Alignment.centerRight,
                          child: ElevatedButton.icon(
                            onPressed:
                                _selectedBayIds.isEmpty ||
                                    _filteredReadingFields.isEmpty
                                ? null
                                : _addCustomColumn,
                            icon: const Icon(Icons.add),
                            label: const Text('Add Custom Column'),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_customColumns.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8.0),
                      child: Text('No custom columns added yet.'),
                    ),
                  ..._customColumns.asMap().entries.map((entry) {
                    final index = entry.key;
                    final col = entry.value;

                    final baseFieldDisplay = _filteredReadingFields.firstWhere(
                      (field) => field.name == col.baseReadingFieldId,
                      orElse: () => ReadingField(
                        name: '${col.baseReadingFieldId} (N/A)',
                        dataType: ReadingFieldDataType.text,
                      ),
                    );
                    final secondaryFieldDisplay =
                        col.secondaryReadingFieldId != null
                        ? _filteredReadingFields.firstWhere(
                            (field) =>
                                field.name == col.secondaryReadingFieldId,
                            orElse: () => ReadingField(
                              name: '${col.secondaryReadingFieldId} (N/A)',
                              dataType: ReadingFieldDataType.text,
                            ),
                          )
                        : null;

                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Name: ${col.columnName}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text('Base Field: ${baseFieldDisplay.name}'),
                                  if (secondaryFieldDisplay != null)
                                    Text(
                                      'Secondary Field: ${secondaryFieldDisplay.name}',
                                    ),
                                  Text(
                                    'Operation: ${col.operation.toShortString().capitalize()}',
                                  ),
                                  if (col.operandValue != null &&
                                      col.operandValue!.isNotEmpty)
                                    Text('Operand Value: ${col.operandValue}'),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () {
                                setState(() {
                                  _customColumns.removeAt(index);
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                  const SizedBox(height: 30),
                  Center(
                    child: ElevatedButton(
                      onPressed: _saveReportTemplate,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 40,
                          vertical: 15,
                        ),
                      ),
                      child: const Text('Save Report Template'),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

// Helper extension for capitalizing strings
extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return '';
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}

// Dialog for adding a custom column
class AddCustomColumnDialog extends StatefulWidget {
  final List<ReadingField> availableReadingFields;
  final Function(CustomReportColumn) onAdd;

  const AddCustomColumnDialog({
    super.key,
    required this.availableReadingFields,
    required this.onAdd,
  });

  @override
  State<AddCustomColumnDialog> createState() => _AddCustomColumnDialogState();
}

class _AddCustomColumnDialogState extends State<AddCustomColumnDialog> {
  final _columnNameController = TextEditingController();
  ReadingField? _selectedBaseField;
  ReadingField? _selectedSecondaryField;
  MathOperation _selectedOperation = MathOperation.none;
  final _operandValueController = TextEditingController();

  @override
  void dispose() {
    _columnNameController.dispose();
    _operandValueController.dispose();
    super.dispose();
  }

  bool _showSecondaryField() {
    return _selectedOperation == MathOperation.add ||
        _selectedOperation == MathOperation.subtract ||
        _selectedOperation == MathOperation.multiply ||
        _selectedOperation == MathOperation.divide;
  }

  bool _showOperandValue() {
    return (_selectedOperation != MathOperation.max &&
            _selectedOperation != MathOperation.min &&
            _selectedOperation != MathOperation.sum &&
            _selectedOperation != MathOperation.average &&
            _selectedOperation != MathOperation.none) &&
        _selectedSecondaryField == null;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Custom Column'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _columnNameController,
              decoration: const InputDecoration(labelText: 'Column Name'),
            ),
            const SizedBox(height: 15),
            DropdownButtonFormField<ReadingField>(
              value: _selectedBaseField,
              hint: const Text('Select Base Reading Field'),
              onChanged: (field) {
                setState(() {
                  _selectedBaseField = field;
                  if (_showSecondaryField() &&
                      _selectedSecondaryField != null &&
                      _selectedSecondaryField == _selectedBaseField) {
                    _selectedSecondaryField = null;
                  }
                });
              },
              items: widget.availableReadingFields.map((field) {
                return DropdownMenuItem(
                  value: field,
                  child: Text(
                    '${field.name} ${field.unit != null && field.unit!.isNotEmpty ? '(${field.unit})' : ''}',
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 15),
            DropdownButtonFormField<MathOperation>(
              value: _selectedOperation,
              decoration: const InputDecoration(labelText: 'Operation'),
              onChanged: (op) {
                setState(() {
                  _selectedOperation = op!;
                  if (!_showSecondaryField()) {
                    _selectedSecondaryField = null;
                  }
                  if (!_showOperandValue()) {
                    _operandValueController.clear();
                  }
                });
              },
              items: MathOperation.values.map((op) {
                return DropdownMenuItem(
                  value: op,
                  child: Text(op.toShortString().capitalize()),
                );
              }).toList(),
            ),
            if (_showSecondaryField()) ...[
              const SizedBox(height: 15),
              DropdownButtonFormField<ReadingField>(
                value: _selectedSecondaryField,
                hint: const Text('Select Secondary Reading Field'),
                onChanged: (field) {
                  setState(() {
                    _selectedSecondaryField = field;
                  });
                },
                items: widget.availableReadingFields
                    .where((field) => field != _selectedBaseField)
                    .map((field) {
                      return DropdownMenuItem(
                        value: field,
                        child: Text(
                          '${field.name} ${field.unit != null && field.unit!.isNotEmpty ? '(${field.unit})' : ''}',
                        ),
                      );
                    })
                    .toList(),
              ),
            ],
            if (_showOperandValue()) ...[
              const SizedBox(height: 15),
              TextField(
                controller: _operandValueController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Operand Value (e.g., 50 for + 50)',
                  hintText: 'Enter a number for constant operations',
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_columnNameController.text.trim().isEmpty) {
              SnackBarUtils.showSnackBar(
                context,
                'Column name cannot be empty.',
              );
              return;
            }
            if (_selectedBaseField == null) {
              SnackBarUtils.showSnackBar(
                context,
                'Please select a base reading field.',
              );
              return;
            }
            if (_showSecondaryField() && _selectedSecondaryField == null) {
              SnackBarUtils.showSnackBar(
                context,
                'Please select a secondary reading field for the operation.',
              );
              return;
            }

            if (_showOperandValue() &&
                _operandValueController.text.trim().isEmpty) {
              SnackBarUtils.showSnackBar(
                context,
                'Please enter an operand value.',
              );
              return;
            }

            if (_selectedBaseField!.dataType != ReadingFieldDataType.number &&
                (_selectedOperation != MathOperation.none &&
                    _selectedOperation != MathOperation.max &&
                    _selectedOperation != MathOperation.min &&
                    _selectedOperation != MathOperation.sum &&
                    _selectedOperation != MathOperation.average)) {
              SnackBarUtils.showSnackBar(
                context,
                'Base field must be a number type for the selected operation.',
              );
              return;
            }
            if (_selectedSecondaryField != null &&
                _selectedSecondaryField!.dataType !=
                    ReadingFieldDataType.number) {
              SnackBarUtils.showSnackBar(
                context,
                'Secondary field must be a number type for the selected operation.',
              );
              return;
            }

            widget.onAdd(
              CustomReportColumn(
                columnName: _columnNameController.text.trim(),
                baseReadingFieldId: _selectedBaseField!.name,
                secondaryReadingFieldId: _selectedSecondaryField?.name,
                operation: _selectedOperation,
                operandValue: _operandValueController.text.trim().isEmpty
                    ? null
                    : _operandValueController.text.trim(),
              ),
            );
            Navigator.of(context).pop();
          },
          child: const Text('Add'),
        ),
      ],
    );
  }
}
