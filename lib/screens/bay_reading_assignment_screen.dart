import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../models/reading_models.dart';
import '../models/bay_model.dart';
import '../models/user_model.dart';
import '../utils/snackbar_utils.dart';

class BayReadingAssignmentScreen extends StatefulWidget {
  final String bayId;
  final String bayName;
  final AppUser currentUser;

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

class _BayReadingAssignmentScreenState extends State<BayReadingAssignmentScreen>
    with TickerProviderStateMixin {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  bool _isLoading = true;
  bool _isSaving = false;
  String? _bayType;
  List<ReadingTemplate> _availableReadingTemplates = [];
  ReadingTemplate? _selectedTemplate;
  String? _existingAssignmentId;
  DateTime? _readingStartDate;

  final List<Map<String, dynamic>> _instanceReadingFields = [];
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
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _initializeScreenData();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _textFieldControllers.forEach((key, controller) => controller.dispose());
    _booleanDescriptionControllers.forEach(
      (key, controller) => controller.dispose(),
    );
    super.dispose();
  }

  Future<void> _initializeScreenData() async {
    setState(() => _isLoading = true);

    try {
      // Bay details
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

      // Reading templates
      final templatesSnapshot = await FirebaseFirestore.instance
          .collection('readingTemplates')
          .where('bayType', isEqualTo: _bayType)
          .orderBy('createdAt', descending: true)
          .get();
      _availableReadingTemplates = templatesSnapshot.docs
          .map((doc) => ReadingTemplate.fromFirestore(doc))
          .toList();

      // Existing assignment
      final existingAssignmentSnapshot = await FirebaseFirestore.instance
          .collection('bayReadingAssignments')
          .where('bayId', isEqualTo: widget.bayId)
          .limit(1)
          .get();

      if (existingAssignmentSnapshot.docs.isNotEmpty) {
        final existingDoc = existingAssignmentSnapshot.docs.first;
        _existingAssignmentId = existingDoc.id;
        final assignedData = existingDoc.data();

        if (assignedData.containsKey('readingStartDate') &&
            assignedData['readingStartDate'] != null) {
          _readingStartDate = (assignedData['readingStartDate'] as Timestamp)
              .toDate();
        } else {
          _readingStartDate = DateTime.now();
        }

        final existingTemplateId = assignedData['templateId'] as String?;
        if (existingTemplateId != null) {
          _selectedTemplate = _availableReadingTemplates.firstWhere(
            (template) => template.id == existingTemplateId,
            orElse: () => _availableReadingTemplates.first,
          );
        }

        final List<dynamic> assignedFieldsRaw =
            assignedData['assignedFields'] as List? ?? [];
        _instanceReadingFields.addAll(
          assignedFieldsRaw.map((e) => Map<String, dynamic>.from(e)).toList(),
        );

        _initializeFieldControllers();
      } else {
        _readingStartDate = DateTime.now();
        if (_availableReadingTemplates.isNotEmpty) {
          _selectedTemplate = _availableReadingTemplates.first;
          _instanceReadingFields.addAll(
            _selectedTemplate!.readingFields.map((e) => e.toMap()).toList(),
          );
          _initializeFieldControllers();
        }
      }

      _animationController.forward();
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
      setState(() => _isLoading = false);
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
        'description_remarks': '',
      });
    });
  }

  void _removeInstanceReadingField(int index) {
    setState(() {
      final fieldName = _instanceReadingFields[index]['name'];
      _instanceReadingFields.removeAt(index);

      _textFieldControllers.remove(fieldName)?.dispose();
      _booleanFieldValues.remove(fieldName);
      _dateFieldValues.remove(fieldName);
      _dropdownFieldValues.remove(fieldName);
      _booleanDescriptionControllers.remove(fieldName)?.dispose();
    });
  }

  Future<void> _saveAssignment() async {
    if (!_formKey.currentState!.validate()) return;

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

    setState(() => _isSaving = true);

    try {
      final List<Map<String, dynamic>> finalAssignedFields = [];
      for (var fieldMap in _instanceReadingFields) {
        final String fieldName = fieldMap['name'] as String;
        final String dataType = fieldMap['dataType'] as String;

        Map<String, dynamic> currentFieldData = Map.from(fieldMap);

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

      final Map<String, dynamic> assignmentData = {
        'bayId': widget.bayId,
        'bayType': _bayType,
        'templateId': _selectedTemplate!.id!,
        'assignedFields': finalAssignedFields,
        'readingStartDate': Timestamp.fromDate(_readingStartDate!),
        'recordedBy': widget.currentUser.uid,
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

      if (mounted) Navigator.of(context).pop();
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
      setState(() => _isSaving = false);
    }
  }

  Future<void> _selectReadingStartDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _readingStartDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: Theme.of(context).colorScheme.primary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _readingStartDate) {
      setState(() => _readingStartDate = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8F9FA),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(
                  theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Loading assignment data...',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Reading Assignment',
              style: TextStyle(
                color: theme.colorScheme.onSurface,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              widget.bayName,
              style: TextStyle(
                color: theme.colorScheme.primary,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: theme.colorScheme.onSurface),
          onPressed: () => Navigator.of(context).pop(),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: Colors.grey.shade200),
        ),
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _buildHeaderSection(theme)),
            SliverToBoxAdapter(child: _buildDateSelector(theme)),
            SliverToBoxAdapter(child: _buildTemplateSelector(theme)),
            if (_selectedTemplate != null)
              SliverToBoxAdapter(child: _buildFieldsSection(theme)),
            SliverToBoxAdapter(child: _buildActionButtons(theme)),
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderSection(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primary.withOpacity(0.1),
            theme.colorScheme.primary.withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.primary.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.electrical_services,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Bay Information',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Type: ${_bayType ?? 'Unknown'}',
                  style: TextStyle(
                    fontSize: 14,
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateSelector(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(20),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: theme.colorScheme.secondary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            Icons.calendar_today,
            color: theme.colorScheme.secondary,
            size: 20,
          ),
        ),
        title: Text(
          'Reading Start Date',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurface,
          ),
        ),
        subtitle: Text(
          DateFormat(
            'EEEE, MMM dd, yyyy',
          ).format(_readingStartDate ?? DateTime.now()),
          style: TextStyle(
            fontSize: 14,
            color: theme.colorScheme.secondary,
            fontWeight: FontWeight.w500,
          ),
        ),
        trailing: Icon(Icons.edit_calendar, color: theme.colorScheme.primary),
        onTap: () => _selectReadingStartDate(context),
      ),
    );
  }

  Widget _buildTemplateSelector(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.purple.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.description,
                  color: Colors.purple,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Reading Template',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_availableReadingTemplates.isEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber, color: Colors.orange),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'No reading templates available for "${_bayType ?? 'this bay type'}". Please create templates in Admin Dashboard.',
                      style: const TextStyle(
                        color: Colors.orange,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            DropdownButtonFormField<ReadingTemplate>(
              value: _selectedTemplate,
              decoration: InputDecoration(
                labelText: 'Select Template',
                prefixIcon: const Icon(Icons.list_alt),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
              items: _availableReadingTemplates.map((template) {
                return DropdownMenuItem(
                  value: template,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        template.bayType,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      if (template.id != null)
                        Text(
                          'ID: ${template.id!.substring(0, 8)}...',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                    ],
                  ),
                );
              }).toList(),
              onChanged: _onTemplateSelected,
              validator: (value) =>
                  value == null ? 'Please select a template' : null,
            ),
        ],
      ),
    );
  }

  Widget _buildFieldsSection(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.settings,
                    color: Colors.blue,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Reading Fields Configuration',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _instanceReadingFields.length,
              itemBuilder: (context, index) {
                final field = _instanceReadingFields[index];
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.only(bottom: 16),
                  child: _buildReadingFieldDefinitionInput(field, index),
                );
              },
            ),
            if (widget.currentUser.role == UserRole.admin ||
                widget.currentUser.role == UserRole.subdivisionManager)
              Container(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _addInstanceReadingField,
                  icon: const Icon(Icons.add_circle_outline),
                  label: const Text('Add Custom Field'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    side: BorderSide(color: theme.colorScheme.primary),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildReadingFieldDefinitionInput(
    Map<String, dynamic> fieldDef,
    int index,
  ) {
    final theme = Theme.of(context);
    final String currentFieldName = fieldDef['name'] as String;
    final String currentDataType = fieldDef['dataType'] as String;
    final bool currentIsMandatory = fieldDef['isMandatory'] as bool;
    final String currentUnit = fieldDef['unit'] as String? ?? '';
    final List<String> currentOptions = List.from(fieldDef['options'] ?? []);
    final String currentFrequency = fieldDef['frequency'] as String;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: _getDataTypeColor(currentDataType).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(
                  _getDataTypeIcon(currentDataType),
                  color: _getDataTypeColor(currentDataType),
                  size: 16,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  currentFieldName.isNotEmpty
                      ? currentFieldName
                      : 'Unnamed Field',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (currentIsMandatory)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Required',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.red,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          TextFormField(
            initialValue: currentFieldName,
            decoration: InputDecoration(
              labelText: 'Field Name',
              prefixIcon: const Icon(Icons.edit, size: 20),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              filled: true,
              fillColor: Colors.white,
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
                      _booleanDescriptionControllers.remove(currentFieldName)!;
                }
              });
            },
            validator: (value) => value == null || value.trim().isEmpty
                ? 'Field name required'
                : null,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: currentDataType,
                  decoration: InputDecoration(
                    labelText: 'Data Type',
                    prefixIcon: Icon(
                      _getDataTypeIcon(currentDataType),
                      size: 20,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  items: _dataTypes.map((type) {
                    return DropdownMenuItem(
                      value: type,
                      child: Row(
                        children: [
                          Icon(
                            _getDataTypeIcon(type),
                            size: 16,
                            color: _getDataTypeColor(type),
                          ),
                          const SizedBox(width: 8),
                          Text(type),
                        ],
                      ),
                    );
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
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: currentFrequency,
                  decoration: InputDecoration(
                    labelText: 'Frequency',
                    prefixIcon: const Icon(Icons.schedule, size: 20),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  items: _frequencies.map((freq) {
                    return DropdownMenuItem(value: freq, child: Text(freq));
                  }).toList(),
                  onChanged: (value) =>
                      setState(() => fieldDef['frequency'] = value!),
                ),
              ),
            ],
          ),
          if (currentDataType == 'dropdown') ...[
            const SizedBox(height: 12),
            TextFormField(
              initialValue: currentOptions.join(', '),
              decoration: InputDecoration(
                labelText: 'Options (comma-separated)',
                hintText: 'Option1, Option2, Option3',
                prefixIcon: const Icon(Icons.list, size: 20),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                filled: true,
                fillColor: Colors.white,
              ),
              onChanged: (value) => fieldDef['options'] = value
                  .split(',')
                  .map((e) => e.trim())
                  .where((e) => e.isNotEmpty)
                  .toList(),
            ),
          ],
          if (currentDataType == 'number') ...[
            const SizedBox(height: 12),
            TextFormField(
              initialValue: currentUnit,
              decoration: InputDecoration(
                labelText: 'Unit (e.g., V, A, kW)',
                prefixIcon: const Icon(Icons.straighten, size: 20),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                filled: true,
                fillColor: Colors.white,
              ),
              onChanged: (value) => fieldDef['unit'] = value,
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: CheckboxListTile(
                  title: const Text('Mandatory Field'),
                  value: currentIsMandatory,
                  onChanged: (value) =>
                      setState(() => fieldDef['isMandatory'] = value!),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                ),
              ),
              IconButton(
                onPressed: () => _removeInstanceReadingField(index),
                icon: Icon(
                  Icons.delete_outline,
                  color: theme.colorScheme.error,
                ),
                style: IconButton.styleFrom(
                  backgroundColor: theme.colorScheme.error.withOpacity(0.1),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.all(20),
      child: Column(
        children: [
          if (_isSaving)
            Container(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Saving assignment...',
                    style: TextStyle(
                      fontSize: 16,
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            )
          else
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: _selectedTemplate != null ? _saveAssignment : null,
                icon: Icon(
                  _existingAssignmentId == null ? Icons.save : Icons.update,
                  size: 24,
                ),
                label: Text(
                  _existingAssignmentId == null
                      ? 'Save Assignment'
                      : 'Update Assignment',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 2,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Color _getDataTypeColor(String dataType) {
    switch (dataType) {
      case 'text':
        return Colors.blue;
      case 'number':
        return Colors.green;
      case 'boolean':
        return Colors.orange;
      case 'date':
        return Colors.purple;
      case 'dropdown':
        return Colors.teal;
      default:
        return Colors.grey;
    }
  }

  IconData _getDataTypeIcon(String dataType) {
    switch (dataType) {
      case 'text':
        return Icons.text_fields;
      case 'number':
        return Icons.numbers;
      case 'boolean':
        return Icons.toggle_on;
      case 'date':
        return Icons.calendar_today;
      case 'dropdown':
        return Icons.arrow_drop_down_circle;
      default:
        return Icons.help;
    }
  }
}
