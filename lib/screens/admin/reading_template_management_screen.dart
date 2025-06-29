// lib/screens/admin/reading_template_management_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/reading_models.dart'; // Import the new reading models
import '../../models/bay_model.dart'; // To get list of bay types
import '../../utils/snackbar_utils.dart'; // Ensure you have this utility

enum ReadingTemplateViewMode { list, form }

class ReadingTemplateManagementScreen extends StatefulWidget {
  const ReadingTemplateManagementScreen({super.key});

  @override
  State<ReadingTemplateManagementScreen> createState() =>
      _ReadingTemplateManagementScreenState();
}

class _ReadingTemplateManagementScreenState
    extends State<ReadingTemplateManagementScreen> {
  ReadingTemplateViewMode _viewMode = ReadingTemplateViewMode.list;
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  ReadingTemplate? _templateToEdit;
  List<ReadingTemplate> _templates = [];
  bool _isLoading = true;
  bool _isSaving = false;

  String? _selectedBayType; // For the template's bay type
  List<Map<String, dynamic>> _templateReadingFields = [];

  final List<String> _dataTypes = ReadingFieldDataType.values
      .map((e) => e.toString().split('.').last)
      .toList();
  final List<String> _frequencies = ReadingFrequency.values
      .map((e) => e.toString().split('.').last)
      .toList();

  // List of available bay types from bay_model.dart
  final List<String> _bayTypes = [
    'Transformer',
    'Line',
    'Feeder',
    'Capacitor Bank',
    'Reactor',
    'Bus Coupler',
  ];

  @override
  void initState() {
    super.initState();
    _fetchReadingTemplates();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _fetchReadingTemplates() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('readingTemplates')
          .orderBy('bayType')
          .get();
      setState(() {
        _templates = snapshot.docs
            .map((doc) => ReadingTemplate.fromFirestore(doc))
            .toList();
        _isLoading = false;
      });
    } catch (e) {
      print("Error fetching reading templates: $e");
      if (mounted) {
        SnackBarUtils.showSnackBar(
          context,
          'Failed to load reading templates: $e',
          isError: true,
        );
      }
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showListView() {
    setState(() {
      _viewMode = ReadingTemplateViewMode.list;
      _templateToEdit = null;
      _selectedBayType = null;
      _templateReadingFields = [];
    });
    _fetchReadingTemplates(); // Refresh list after returning
  }

  void _showFormForNew() {
    setState(() {
      _viewMode = ReadingTemplateViewMode.form;
      _templateToEdit = null;
      _selectedBayType = null; // Reset for new template
      _templateReadingFields = [];
    });
  }

  void _showFormForEdit(ReadingTemplate template) {
    setState(() {
      _viewMode = ReadingTemplateViewMode.form;
      _templateToEdit = template;
      _selectedBayType = template.bayType;
      _templateReadingFields = template.readingFields
          .map((field) => field.toMap())
          .toList();
    });
  }

  void _addReadingField(List<Map<String, dynamic>> targetList) {
    setState(() {
      targetList.add({
        'name': '',
        'dataType': ReadingFieldDataType.text.toString().split('.').last,
        'unit': '',
        'options': [],
        'isMandatory': false,
        'frequency': ReadingFrequency.daily
            .toString()
            .split('.')
            .last, // Default frequency
        'description_remarks': '', // For boolean
      });
    });
  }

  void _removeReadingField(List<Map<String, dynamic>> targetList, int index) {
    setState(() {
      targetList.removeAt(index);
    });
  }

  Future<void> _saveTemplate() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedBayType == null || _selectedBayType!.isEmpty) {
      SnackBarUtils.showSnackBar(
        context,
        'Please select a Bay Type for the template.',
        isError: true,
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      if (mounted) {
        SnackBarUtils.showSnackBar(
          context,
          'Error: User not logged in.',
          isError: true,
        );
      }
      setState(() {
        _isSaving = false;
      });
      return;
    }

    try {
      final List<ReadingField> readingFields = _templateReadingFields
          .map((fieldMap) => ReadingField.fromMap(fieldMap))
          .toList();

      final ReadingTemplate newTemplate = ReadingTemplate(
        bayType: _selectedBayType!,
        readingFields: readingFields,
        createdBy: currentUser.uid,
        createdAt: Timestamp.now(),
      );

      if (_templateToEdit == null) {
        // Add new template
        await FirebaseFirestore.instance
            .collection('readingTemplates')
            .add(newTemplate.toFirestore());
        if (mounted) {
          SnackBarUtils.showSnackBar(
            context,
            'Reading template added successfully!',
          );
        }
      } else {
        // Update existing template
        await FirebaseFirestore.instance
            .collection('readingTemplates')
            .doc(_templateToEdit!.id)
            .update(newTemplate.toFirestore());
        if (mounted) {
          SnackBarUtils.showSnackBar(
            context,
            'Reading template updated successfully!',
          );
        }
      }
      _showListView(); // Go back to list view and refresh
    } catch (e) {
      print("Error saving reading template: $e");
      if (mounted) {
        SnackBarUtils.showSnackBar(
          context,
          'Failed to save template: $e',
          isError: true,
        );
      }
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  Future<void> _deleteTemplate(String? templateId) async {
    if (templateId == null) return;

    final bool confirm =
        await showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Confirm Deletion'),
              content: const Text(
                'Are you sure you want to delete this reading template? This action cannot be undone.',
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  child: const Text('Delete'),
                ),
              ],
            );
          },
        ) ??
        false;

    if (confirm) {
      try {
        await FirebaseFirestore.instance
            .collection('readingTemplates')
            .doc(templateId)
            .delete();
        if (mounted) {
          SnackBarUtils.showSnackBar(
            context,
            'Reading template deleted successfully!',
          );
        }
        _fetchReadingTemplates(); // Refresh list
      } catch (e) {
        print("Error deleting template: $e");
        if (mounted) {
          SnackBarUtils.showSnackBar(
            context,
            'Failed to delete template: $e',
            isError: true,
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _viewMode == ReadingTemplateViewMode.list
              ? 'Reading Templates'
              : (_templateToEdit == null
                    ? 'Define New Reading Template'
                    : 'Edit Reading Template'),
        ),
        leading: _viewMode == ReadingTemplateViewMode.form
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: _showListView,
              )
            : null,
      ),
      body: _viewMode == ReadingTemplateViewMode.list
          ? _buildListView()
          : _buildFormView(),
      floatingActionButton: _viewMode == ReadingTemplateViewMode.list
          ? FloatingActionButton.extended(
              onPressed: _showFormForNew,
              label: const Text('Add New Template'),
              icon: const Icon(Icons.add),
            )
          : null,
    );
  }

  Widget _buildListView() {
    return _templates.isEmpty
        ? const Center(
            child: Text(
              'No reading templates defined yet. Tap "+" to add one.',
            ),
          )
        : ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _templates.length,
            itemBuilder: (context, index) {
              final template = _templates[index];
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 8),
                elevation: 3,
                child: ListTile(
                  title: Text(template.bayType),
                  subtitle: Text(
                    '${template.readingFields.length} reading fields defined',
                  ),
                  trailing: PopupMenuButton<String>(
                    onSelected: (String result) {
                      if (result == 'edit') {
                        _showFormForEdit(template);
                      } else if (result == 'delete') {
                        _deleteTemplate(template.id);
                      }
                    },
                    itemBuilder: (BuildContext context) =>
                        <PopupMenuEntry<String>>[
                          const PopupMenuItem<String>(
                            value: 'edit',
                            child: ListTile(
                              leading: Icon(Icons.edit),
                              title: Text('Edit'),
                            ),
                          ),
                          PopupMenuItem<String>(
                            value: 'delete',
                            child: ListTile(
                              leading: Icon(
                                Icons.delete,
                                color: Theme.of(context).colorScheme.error,
                              ),
                              title: Text(
                                'Delete',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.error,
                                ),
                              ),
                            ),
                          ),
                        ],
                  ),
                ),
              );
            },
          );
  }

  Widget _buildFormView() {
    final colorScheme = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<String>(
              value: _selectedBayType,
              decoration: InputDecoration(
                labelText: 'Applies to Bay Type',
                hintText: 'e.g., Transformer, Feeder',
                prefixIcon: Icon(Icons.category, color: colorScheme.primary),
                border: const OutlineInputBorder(),
              ),
              items: _bayTypes.map((String type) {
                return DropdownMenuItem<String>(value: type, child: Text(type));
              }).toList(),
              onChanged: (String? newValue) =>
                  setState(() => _selectedBayType = newValue!),
              validator: (value) =>
                  value == null ? 'Please select a bay type' : null,
            ),
            const SizedBox(height: 20),

            _buildReadingFieldsSection(
              'Reading Fields',
              _templateReadingFields,
              colorScheme,
              Icons.list_alt,
            ),
            const SizedBox(height: 30),
            ElevatedButton.icon(
              onPressed: _isSaving ? null : _saveTemplate,
              icon: _isSaving
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(_templateToEdit == null ? Icons.add : Icons.save),
              label: Text(
                _templateToEdit == null ? 'Add Template' : 'Update Template',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: colorScheme.primary,
                foregroundColor: colorScheme.onPrimary,
                minimumSize: const Size(double.infinity, 50),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReadingFieldsSection(
    String title,
    List<Map<String, dynamic>> fieldsList,
    ColorScheme colorScheme,
    IconData icon,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: colorScheme.primary),
            const SizedBox(width: 8),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
          ],
        ),
        const SizedBox(height: 10),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: fieldsList.length,
          itemBuilder: (context, index) {
            final field = fieldsList[index];
            return Card(
              margin: const EdgeInsets.symmetric(vertical: 8.0),
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      initialValue: field['name'] as String,
                      decoration: const InputDecoration(
                        labelText: 'Reading Field Name',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (value) => field['name'] = value,
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? 'Field name required'
                          : null,
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      value: field['dataType'] as String,
                      decoration: const InputDecoration(
                        labelText: 'Data Type',
                        border: OutlineInputBorder(),
                      ),
                      items: _dataTypes
                          .map(
                            (type) => DropdownMenuItem(
                              value: type,
                              child: Text(type),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        setState(() {
                          field['dataType'] = value!;
                          // Reset options/unit/description when data type changes
                          if (value != 'dropdown') {
                            field['options'] = [];
                          }
                          if (value != 'number') {
                            field['unit'] = '';
                          }
                          if (value != 'boolean') {
                            field['description_remarks'] = '';
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      value: field['frequency'] as String,
                      decoration: const InputDecoration(
                        labelText: 'Reading Frequency',
                        border: OutlineInputBorder(),
                      ),
                      items: _frequencies
                          .map(
                            (freq) => DropdownMenuItem(
                              value: freq,
                              child: Text(freq),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        setState(() {
                          field['frequency'] = value!;
                        });
                      },
                    ),
                    const SizedBox(height: 10),
                    if (field['dataType'] == 'dropdown')
                      TextFormField(
                        initialValue: (field['options'] as List<dynamic>?)
                            ?.join(','),
                        decoration: const InputDecoration(
                          labelText: 'Options (comma-separated)',
                          border: OutlineInputBorder(),
                          hintText: 'e.g., Option1, Option2, Option3',
                        ),
                        onChanged: (value) => field['options'] = value
                            .split(',')
                            .map((e) => e.trim())
                            .where((e) => e.isNotEmpty)
                            .toList(),
                      ),
                    if (field['dataType'] == 'number')
                      TextFormField(
                        initialValue: field['unit'] as String,
                        decoration: const InputDecoration(
                          labelText: 'Unit (e.g., V, A, kW)',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (value) => field['unit'] = value,
                      ),
                    if (field['dataType'] == 'boolean')
                      TextFormField(
                        initialValue: field['description_remarks'] as String,
                        decoration: const InputDecoration(
                          labelText: 'Description / Remarks (Optional)',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (value) =>
                            field['description_remarks'] = value,
                        maxLines: 2,
                      ),
                    CheckboxListTile(
                      title: const Text('Mandatory'),
                      value: field['isMandatory'] as bool,
                      onChanged: (value) =>
                          setState(() => field['isMandatory'] = value!),
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: IconButton(
                        icon: Icon(
                          Icons.remove_circle_outline,
                          color: colorScheme.error,
                        ),
                        onPressed: () => _removeReadingField(fieldsList, index),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        ElevatedButton.icon(
          onPressed: () => _addReadingField(fieldsList),
          icon: const Icon(Icons.add),
          label: const Text('Add Reading Field'),
        ),
      ],
    );
  }
}
