import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../models/reading_models.dart';
import '../../models/user_model.dart';
import '../../utils/snackbar_utils.dart';

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
  final Map<String, List<String>> _groupOptions =
      {}; // For group type dropdown options

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
      // Fetch bay information
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

      // Fetch available templates
      final templatesSnapshot = await FirebaseFirestore.instance
          .collection('readingTemplates')
          .where('bayType', isEqualTo: _bayType)
          .where('isActive', isEqualTo: true) // Only fetch active templates
          .orderBy('createdAt', descending: true)
          .get();
      _availableReadingTemplates = templatesSnapshot.docs
          .map((doc) => ReadingTemplate.fromFirestore(doc))
          .toList();

      // Check for existing assignment
      final existingAssignmentSnapshot = await FirebaseFirestore.instance
          .collection('bayReadingAssignments')
          .where('bayId', isEqualTo: widget.bayId)
          .limit(1)
          .get();

      if (existingAssignmentSnapshot.docs.isNotEmpty) {
        final existingDoc = existingAssignmentSnapshot.docs.first;
        _existingAssignmentId = existingDoc.id;
        final assignedData = existingDoc.data();

        // Set reading start date
        if (assignedData.containsKey('readingStartDate') &&
            assignedData['readingStartDate'] != null) {
          _readingStartDate = (assignedData['readingStartDate'] as Timestamp)
              .toDate();
        } else {
          _readingStartDate = DateTime.now();
        }

        // Set selected template
        final existingTemplateId = assignedData['templateId'] as String?;
        if (existingTemplateId != null) {
          _selectedTemplate = _availableReadingTemplates.firstWhere(
            (template) => template.id == existingTemplateId,
            orElse: () => _availableReadingTemplates.isNotEmpty
                ? _availableReadingTemplates.first
                : ReadingTemplate(
                    bayType: _bayType!,
                    readingFields: [],
                    createdBy: widget.currentUser.uid,
                    createdAt: Timestamp.now(),
                  ),
          );
        }

        // Load assigned fields
        final List<dynamic> assignedFieldsRaw =
            assignedData['assignedFields'] as List? ?? [];
        _instanceReadingFields.addAll(
          assignedFieldsRaw.map((e) => Map<String, dynamic>.from(e)).toList(),
        );
        _initializeFieldControllers();
      } else {
        // New assignment
        _readingStartDate = DateTime.now();
        if (_availableReadingTemplates.isNotEmpty) {
          _selectedTemplate = _availableReadingTemplates.first;
          _loadTemplateFields(_selectedTemplate!);
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

  void _loadTemplateFields(ReadingTemplate template) {
    _instanceReadingFields.clear();
    for (var field in template.readingFields) {
      _addFieldToInstance(field, null);
    }
    _initializeFieldControllers();
  }

  void _addFieldToInstance(ReadingField field, String? parentGroupName) {
    Map<String, dynamic> fieldMap = field.toMap();
    if (parentGroupName != null) {
      fieldMap['groupName'] = parentGroupName;
    }
    _instanceReadingFields.add(fieldMap);

    // If this is a group field, add its nested fields
    if (field.dataType == ReadingFieldDataType.group && field.hasNestedFields) {
      for (var nestedField in field.nestedFields!) {
        _addFieldToInstance(nestedField, field.name);
      }
    }
  }

  void _initializeFieldControllers() {
    _textFieldControllers.clear();
    _booleanFieldValues.clear();
    _dateFieldValues.clear();
    _dropdownFieldValues.clear();
    _booleanDescriptionControllers.clear();
    _groupOptions.clear();

    for (var fieldMap in _instanceReadingFields) {
      final String fieldName = fieldMap['name'] as String;
      final String dataType = fieldMap['dataType'] as String;

      switch (dataType) {
        case 'text':
        case 'number':
          _textFieldControllers[fieldName] = TextEditingController(
            text: fieldMap['value']?.toString() ?? '',
          );
          break;
        case 'boolean':
          _booleanFieldValues[fieldName] = fieldMap['value'] as bool? ?? false;
          _booleanDescriptionControllers[fieldName] = TextEditingController(
            text: fieldMap['description_remarks']?.toString() ?? '',
          );
          break;
        case 'date':
          _dateFieldValues[fieldName] = fieldMap['value'] != null
              ? (fieldMap['value'] as Timestamp).toDate()
              : null;
          break;
        case 'dropdown':
          _dropdownFieldValues[fieldName] = fieldMap['value']?.toString();
          break;
        case 'group':
          final List<String> options = List<String>.from(
            fieldMap['options'] ?? [],
          );
          _groupOptions[fieldName] = options;
          _dropdownFieldValues[fieldName] = fieldMap['value']?.toString();
          break;
      }
    }
  }

  void _onTemplateSelected(ReadingTemplate? template) {
    if (template == null) return;
    setState(() {
      _selectedTemplate = template;
      _clearAllControllers();
      _loadTemplateFields(template);
    });
  }

  void _clearAllControllers() {
    _textFieldControllers.forEach((key, controller) => controller.dispose());
    _booleanDescriptionControllers.forEach(
      (key, controller) => controller.dispose(),
    );
    _textFieldControllers.clear();
    _booleanFieldValues.clear();
    _dateFieldValues.clear();
    _dropdownFieldValues.clear();
    _booleanDescriptionControllers.clear();
    _groupOptions.clear();
  }

  void _addInstanceReadingField() {
    setState(() {
      final newField = {
        'name': '',
        'dataType': ReadingFieldDataType.text.toString().split('.').last,
        'unit': '',
        'options': <String>[],
        'isMandatory': false,
        'frequency': ReadingFrequency.daily.toString().split('.').last,
        'description_remarks': '',
        'nestedFields': null,
        'groupName': null,
      };
      _instanceReadingFields.add(newField);
    });
  }

  void _removeInstanceReadingField(int index) {
    if (index < 0 || index >= _instanceReadingFields.length) return;

    setState(() {
      final fieldName = _instanceReadingFields[index]['name'] as String;
      _instanceReadingFields.removeAt(index);

      // Clean up controllers
      _textFieldControllers.remove(fieldName)?.dispose();
      _booleanFieldValues.remove(fieldName);
      _dateFieldValues.remove(fieldName);
      _dropdownFieldValues.remove(fieldName);
      _booleanDescriptionControllers.remove(fieldName)?.dispose();
      _groupOptions.remove(fieldName);
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

        if (fieldName.trim().isEmpty) continue; // Skip empty field names

        Map<String, dynamic> currentFieldData = Map.from(fieldMap);

        // Set field values based on data type
        switch (dataType) {
          case 'text':
          case 'number':
            final value = _textFieldControllers[fieldName]?.text.trim();
            currentFieldData['value'] = value;
            break;
          case 'boolean':
            currentFieldData['value'] = _booleanFieldValues[fieldName] ?? false;
            currentFieldData['description_remarks'] =
                _booleanDescriptionControllers[fieldName]?.text.trim();
            break;
          case 'date':
            currentFieldData['value'] = _dateFieldValues[fieldName] != null
                ? Timestamp.fromDate(_dateFieldValues[fieldName]!)
                : null;
            break;
          case 'dropdown':
          case 'group':
            currentFieldData['value'] = _dropdownFieldValues[fieldName];
            break;
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
        'isActive': true,
        'totalFields': finalAssignedFields.length,
      };

      if (_existingAssignmentId == null) {
        // Create new assignment
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
        // Update existing assignment
        assignmentData['updatedAt'] = FieldValue.serverTimestamp();
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
              onPrimary: Theme.of(context).colorScheme.onPrimary,
              surface: Theme.of(context).colorScheme.surface,
              onSurface: Theme.of(context).colorScheme.onSurface,
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
    if (picked != null && picked != _readingStartDate) {
      setState(() => _readingStartDate = picked);
    }
  }

  Future<void> _selectDateForField(String fieldName) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _dateFieldValues[fieldName] ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _dateFieldValues[fieldName] = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: isDarkMode ? Colors.grey[900] : Colors.grey[50],
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
              const SizedBox(height: 16),
              Text(
                'Loading assignment data...',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: isDarkMode ? Colors.white70 : Colors.grey[700],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: isDarkMode ? Colors.grey[900] : Colors.grey,
      appBar: _buildAppBar(theme, isDarkMode),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeaderSection(theme, isDarkMode),
                  const SizedBox(height: 16),
                  _buildDateSelector(theme, isDarkMode),
                  const SizedBox(height: 16),
                  _buildTemplateSelector(theme, isDarkMode),
                  if (_selectedTemplate != null) ...[
                    const SizedBox(height: 16),
                    _buildFieldsSection(theme, isDarkMode),
                  ],
                  const SizedBox(
                    height: 80,
                  ), // Space for floating action button
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: _buildActionButton(theme, isDarkMode),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  PreferredSizeWidget _buildAppBar(ThemeData theme, bool isDarkMode) {
    return AppBar(
      backgroundColor: isDarkMode ? Colors.grey[900] : Colors.grey[50],
      elevation: 0,
      leading: IconButton(
        icon: Icon(Icons.arrow_back_ios, color: theme.colorScheme.primary),
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Reading Assignment',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: isDarkMode ? Colors.white : Colors.grey[900],
            ),
          ),
          Text(
            widget.bayName,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: theme.colorScheme.primary,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Divider(
          height: 1,
          color: isDarkMode ? Colors.grey[700] : Colors.grey[200],
        ),
      ),
    );
  }

  Widget _buildHeaderSection(ThemeData theme, bool isDarkMode) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDarkMode ? Colors.grey[850] : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDarkMode ? Colors.grey[700]! : Colors.grey!,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.electrical_services,
                color: theme.colorScheme.primary,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Bay Information',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: isDarkMode ? Colors.white : Colors.grey[900],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Type: ${_bayType ?? 'Unknown'}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: isDarkMode ? Colors.white70 : Colors.grey[700],
                    ),
                  ),
                ],
              ),
            ),
            if (_existingAssignmentId != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: theme.colorScheme.secondary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Updating',
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.secondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateSelector(ThemeData theme, bool isDarkMode) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: GestureDetector(
        onTap: () => _selectReadingStartDate(context),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDarkMode ? Colors.grey[850] : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDarkMode ? Colors.grey[700]! : Colors.grey!,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.secondary.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.calendar_today,
                  color: theme.colorScheme.secondary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Reading Start Date',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: isDarkMode ? Colors.white : Colors.grey[900],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      DateFormat(
                        'EEEE, MMM dd, yyyy',
                      ).format(_readingStartDate ?? DateTime.now()),
                      style: TextStyle(
                        fontSize: 14,
                        color: theme.colorScheme.secondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.edit_calendar,
                color: theme.colorScheme.primary,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTemplateSelector(ThemeData theme, bool isDarkMode) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDarkMode ? Colors.grey[850] : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDarkMode ? Colors.grey[700]! : Colors.grey!,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.tertiary.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.description,
                    color: theme.colorScheme.tertiary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Reading Template',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: isDarkMode ? Colors.white : Colors.grey[900],
                    ),
                  ),
                ),
                if (_availableReadingTemplates.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${_availableReadingTemplates.length} available',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (_availableReadingTemplates.isEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.error.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.warning_amber,
                      color: theme.colorScheme.error,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'No reading templates available for "${_bayType ?? 'this bay type'}". Create templates in Admin Dashboard.',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: theme.colorScheme.error,
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
                  labelStyle: TextStyle(
                    color: isDarkMode ? Colors.white70 : Colors.grey[700],
                    fontSize: 14,
                  ),
                  prefixIcon: Icon(
                    Icons.list_alt,
                    color: theme.colorScheme.primary,
                    size: 20,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: isDarkMode ? Colors.grey[700]! : Colors.grey!,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: isDarkMode ? Colors.grey[700]! : Colors.grey!,
                    ),
                  ),
                  filled: true,
                  fillColor: isDarkMode ? Colors.grey : Colors.grey,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                ),
                dropdownColor: isDarkMode ? Colors.grey[850] : Colors.white,
                isExpanded: true,
                items: _availableReadingTemplates.map((template) {
                  return DropdownMenuItem(
                    value: template,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${template.bayType} - ${template.totalFieldCount} fields',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: isDarkMode ? Colors.white : Colors.grey[900],
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (template.description != null &&
                            template.description!.isNotEmpty)
                          Text(
                            template.description!,
                            style: TextStyle(
                              fontSize: 12,
                              color: isDarkMode
                                  ? Colors.white70
                                  : Colors.grey[600],
                            ),
                            overflow: TextOverflow.ellipsis,
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
      ),
    );
  }

  Widget _buildFieldsSection(ThemeData theme, bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.grey[850] : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDarkMode ? Colors.grey[700]! : Colors.grey!,
        ),
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
                    color: theme.colorScheme.primary.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.settings,
                    color: theme.colorScheme.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Reading Fields Configuration',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: isDarkMode ? Colors.white : Colors.grey[900],
                    ),
                  ),
                ),
                if (_instanceReadingFields.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${_instanceReadingFields.length} field${_instanceReadingFields.length == 1 ? '' : 's'}',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            if (_instanceReadingFields.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDarkMode ? Colors.grey[800] : Colors.grey,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.inbox,
                      size: 48,
                      color: isDarkMode ? Colors.grey[600] : Colors.grey[400],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'No fields configured',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: isDarkMode ? Colors.grey[400] : Colors.grey,
                      ),
                    ),
                    Text(
                      'Select a template or add custom fields',
                      style: TextStyle(
                        fontSize: 14,
                        color: isDarkMode ? Colors.grey[500] : Colors.grey,
                      ),
                    ),
                  ],
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _instanceReadingFields.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 16),
                itemBuilder: (context, index) {
                  return AnimatedSize(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    child: _buildReadingFieldDefinitionInput(
                      _instanceReadingFields[index],
                      index,
                      theme,
                      isDarkMode,
                    ),
                  );
                },
              ),
            if (widget.currentUser.role == UserRole.admin ||
                widget.currentUser.role == UserRole.subdivisionManager) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _addInstanceReadingField,
                  icon: Icon(
                    Icons.add_circle_outline,
                    color: theme.colorScheme.primary,
                    size: 20,
                  ),
                  label: Text(
                    'Add Custom Field',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    side: BorderSide(color: theme.colorScheme.primary),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    backgroundColor: theme.colorScheme.primary.withOpacity(
                      0.05,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildReadingFieldDefinitionInput(
    Map<String, dynamic> fieldDef,
    int index,
    ThemeData theme,
    bool isDarkMode,
  ) {
    final String currentFieldName = fieldDef['name'] as String;
    final String currentDataType = fieldDef['dataType'] as String;
    final bool currentIsMandatory = fieldDef['isMandatory'] as bool;
    final String currentUnit = fieldDef['unit'] as String? ?? '';
    final List<String> currentOptions = List.from(fieldDef['options'] ?? []);
    final String currentFrequency = fieldDef['frequency'] as String;
    final String? groupName = fieldDef['groupName'] as String?;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.grey[800] : Colors.grey,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDarkMode ? Colors.grey! : Colors.grey!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: _getDataTypeColor(
                    currentDataType,
                    theme,
                  ).withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _getDataTypeIcon(currentDataType),
                  color: _getDataTypeColor(currentDataType, theme),
                  size: 16,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      currentFieldName.isNotEmpty
                          ? currentFieldName
                          : 'Unnamed Field',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isDarkMode ? Colors.white : Colors.grey[900],
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (groupName != null && groupName.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(top: 4),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.secondary.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Group: $groupName',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.secondary,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (currentIsMandatory)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.error.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Required',
                    style: TextStyle(
                      fontSize: 10,
                      color: theme.colorScheme.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: () => _removeInstanceReadingField(index),
                icon: Icon(
                  Icons.delete_outline,
                  color: theme.colorScheme.error,
                  size: 18,
                ),
                style: IconButton.styleFrom(
                  backgroundColor: theme.colorScheme.error.withOpacity(0.05),
                  minimumSize: const Size(32, 32),
                  padding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Field Name Input
          TextFormField(
            initialValue: currentFieldName,
            decoration: InputDecoration(
              labelText: 'Field Name *',
              labelStyle: TextStyle(
                color: isDarkMode ? Colors.white70 : Colors.grey[700],
                fontSize: 14,
              ),
              prefixIcon: Icon(
                Icons.edit,
                color: theme.colorScheme.primary,
                size: 18,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                  color: isDarkMode ? Colors.grey[700]! : Colors.grey!,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                  color: isDarkMode ? Colors.grey[700]! : Colors.grey!,
                ),
              ),
              filled: true,
              fillColor: isDarkMode ? Colors.grey : Colors.white,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 16,
              ),
            ),
            style: TextStyle(
              fontSize: 14,
              color: isDarkMode ? Colors.white : Colors.grey[900],
            ),
            onChanged: (value) {
              setState(() {
                final oldName = fieldDef['name'];
                fieldDef['name'] = value;

                // Update controller keys if needed
                if (_textFieldControllers.containsKey(oldName)) {
                  final controller = _textFieldControllers.remove(oldName);
                  if (controller != null) {
                    _textFieldControllers[value] = controller;
                  }
                }
                if (_booleanDescriptionControllers.containsKey(oldName)) {
                  final controller = _booleanDescriptionControllers.remove(
                    oldName,
                  );
                  if (controller != null) {
                    _booleanDescriptionControllers[value] = controller;
                  }
                }
              });
            },
            validator: (value) => value == null || value.trim().isEmpty
                ? 'Field name is required'
                : null,
          ),

          const SizedBox(height: 12),

          // Data Type and Frequency Row
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: currentDataType,
                  decoration: InputDecoration(
                    labelText: 'Data Type',
                    labelStyle: TextStyle(
                      color: isDarkMode ? Colors.white70 : Colors.grey[700],
                      fontSize: 14,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: isDarkMode ? Colors.grey[700]! : Colors.grey!,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: isDarkMode ? Colors.grey[700]! : Colors.grey!,
                      ),
                    ),
                    filled: true,
                    fillColor: isDarkMode ? Colors.grey[850] : Colors.white,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 16,
                    ),
                  ),
                  dropdownColor: isDarkMode ? Colors.grey[850] : Colors.white,
                  isExpanded: true,
                  items: _dataTypes.map((type) {
                    return DropdownMenuItem(
                      value: type,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _getDataTypeIcon(type),
                            size: 16,
                            color: _getDataTypeColor(type, theme),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              type,
                              style: TextStyle(
                                fontSize: 14,
                                color: isDarkMode
                                    ? Colors.white
                                    : Colors.grey[900],
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      fieldDef['dataType'] = value!;
                      fieldDef['options'] = <String>[];
                      fieldDef['unit'] = '';
                      fieldDef['description_remarks'] = '';

                      // Clear old controllers
                      final fieldName = fieldDef['name'] as String;
                      _textFieldControllers.remove(fieldName)?.dispose();
                      _booleanDescriptionControllers
                          .remove(fieldName)
                          ?.dispose();
                      _booleanFieldValues.remove(fieldName);
                      _dateFieldValues.remove(fieldName);
                      _dropdownFieldValues.remove(fieldName);
                      _groupOptions.remove(fieldName);

                      // Initialize new controllers based on type
                      _initializeFieldController(fieldName, value);
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
                    labelStyle: TextStyle(
                      color: isDarkMode ? Colors.white70 : Colors.grey[700],
                      fontSize: 14,
                    ),
                    prefixIcon: Icon(
                      Icons.schedule,
                      color: theme.colorScheme.primary,
                      size: 18,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: isDarkMode ? Colors.grey[700]! : Colors.grey!,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: isDarkMode ? Colors.grey[700]! : Colors.grey!,
                      ),
                    ),
                    filled: true,
                    fillColor: isDarkMode ? Colors.grey[850] : Colors.white,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 16,
                    ),
                  ),
                  dropdownColor: isDarkMode ? Colors.grey[850] : Colors.white,
                  isExpanded: true,
                  items: _frequencies.map((freq) {
                    return DropdownMenuItem(
                      value: freq,
                      child: Text(
                        freq,
                        style: TextStyle(
                          fontSize: 14,
                          color: isDarkMode ? Colors.white : Colors.grey[900],
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  onChanged: (value) =>
                      setState(() => fieldDef['frequency'] = value!),
                ),
              ),
            ],
          ),

          // Type-specific inputs
          if (currentDataType == 'dropdown' || currentDataType == 'group') ...[
            const SizedBox(height: 12),
            TextFormField(
              initialValue: currentOptions.join(', '),
              decoration: InputDecoration(
                labelText: 'Options (comma-separated) *',
                labelStyle: TextStyle(
                  color: isDarkMode ? Colors.white70 : Colors.grey[700],
                  fontSize: 14,
                ),
                hintText: 'Option1, Option2, Option3',
                hintStyle: TextStyle(
                  color: isDarkMode ? Colors.white60 : Colors.grey[500],
                ),
                prefixIcon: Icon(
                  Icons.list,
                  color: theme.colorScheme.primary,
                  size: 18,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: isDarkMode ? Colors.grey[700]! : Colors.grey!,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: isDarkMode ? Colors.grey[700]! : Colors.grey!,
                  ),
                ),
                filled: true,
                fillColor: isDarkMode ? Colors.grey : Colors.white,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 16,
                ),
              ),
              style: TextStyle(
                fontSize: 14,
                color: isDarkMode ? Colors.white : Colors.grey[900],
              ),
              onChanged: (value) {
                final options = value
                    .split(',')
                    .map((e) => e.trim())
                    .where((e) => e.isNotEmpty)
                    .toList();
                setState(() {
                  fieldDef['options'] = options;
                  if (currentDataType == 'group') {
                    _groupOptions[currentFieldName] = options;
                  }
                });
              },
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Options are required for ${currentDataType} fields';
                }
                final options = value
                    .split(',')
                    .map((e) => e.trim())
                    .where((e) => e.isNotEmpty)
                    .toList();
                return options.isEmpty
                    ? 'At least one option is required'
                    : null;
              },
            ),
          ],

          if (currentDataType == 'number') ...[
            const SizedBox(height: 12),
            TextFormField(
              initialValue: currentUnit,
              decoration: InputDecoration(
                labelText: 'Unit (e.g., V, A, kW, °C)',
                labelStyle: TextStyle(
                  color: isDarkMode ? Colors.white70 : Colors.grey[700],
                  fontSize: 14,
                ),
                prefixIcon: Icon(
                  Icons.straighten,
                  color: theme.colorScheme.primary,
                  size: 18,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: isDarkMode ? Colors.grey[700]! : Colors.grey!,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: isDarkMode ? Colors.grey[700]! : Colors.grey!,
                  ),
                ),
                filled: true,
                fillColor: isDarkMode ? Colors.grey : Colors.white,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 16,
                ),
              ),
              style: TextStyle(
                fontSize: 14,
                color: isDarkMode ? Colors.white : Colors.grey[900],
              ),
              onChanged: (value) => fieldDef['unit'] = value,
            ),
          ],

          if (currentDataType == 'boolean') ...[
            const SizedBox(height: 12),
            TextFormField(
              initialValue: fieldDef['description_remarks']?.toString() ?? '',
              decoration: InputDecoration(
                labelText: 'Description/Remarks',
                labelStyle: TextStyle(
                  color: isDarkMode ? Colors.white70 : Colors.grey[700],
                  fontSize: 14,
                ),
                hintText: 'Additional context for this boolean field',
                prefixIcon: Icon(
                  Icons.notes,
                  color: theme.colorScheme.primary,
                  size: 18,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: isDarkMode ? Colors.grey[700]! : Colors.grey!,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: isDarkMode ? Colors.grey[700]! : Colors.grey!,
                  ),
                ),
                filled: true,
                fillColor: isDarkMode ? Colors.grey : Colors.white,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 16,
                ),
              ),
              style: TextStyle(
                fontSize: 14,
                color: isDarkMode ? Colors.white : Colors.grey[900],
              ),
              maxLines: 2,
              onChanged: (value) => fieldDef['description_remarks'] = value,
            ),
          ],

          const SizedBox(height: 12),

          // Mandatory checkbox
          Theme(
            data: theme.copyWith(
              checkboxTheme: CheckboxThemeData(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
                checkColor: WidgetStateProperty.all(Colors.white),
                fillColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    return theme.colorScheme.primary;
                  }
                  return isDarkMode ? Colors.grey[700] : Colors.grey;
                }),
              ),
            ),
            child: CheckboxListTile(
              title: Text(
                'Mandatory Field',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: isDarkMode ? Colors.white : Colors.grey[900],
                ),
              ),
              subtitle: Text(
                'Users must provide a value for this field',
                style: TextStyle(
                  fontSize: 12,
                  color: isDarkMode ? Colors.white60 : Colors.grey[600],
                ),
              ),
              value: currentIsMandatory,
              onChanged: (value) =>
                  setState(() => fieldDef['isMandatory'] = value!),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              dense: true,
            ),
          ),

          // Current field value display/input based on type
          _buildFieldValueInput(fieldDef, theme, isDarkMode),
        ],
      ),
    );
  }

  Widget _buildFieldValueInput(
    Map<String, dynamic> fieldDef,
    ThemeData theme,
    bool isDarkMode,
  ) {
    final String fieldName = fieldDef['name'] as String;
    final String dataType = fieldDef['dataType'] as String;

    if (fieldName.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.colorScheme.primary.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.edit_note, size: 16, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                'Current Value',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildFieldValueWidget(
            fieldName,
            dataType,
            fieldDef,
            theme,
            isDarkMode,
          ),
        ],
      ),
    );
  }

  Widget _buildFieldValueWidget(
    String fieldName,
    String dataType,
    Map<String, dynamic> fieldDef,
    ThemeData theme,
    bool isDarkMode,
  ) {
    switch (dataType) {
      case 'text':
        return TextFormField(
          controller: _textFieldControllers[fieldName],
          decoration: InputDecoration(
            hintText: 'Enter text value',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 8,
            ),
            isDense: true,
          ),
          style: const TextStyle(fontSize: 14),
        );

      case 'number':
        final unit = fieldDef['unit'] as String? ?? '';
        return TextFormField(
          controller: _textFieldControllers[fieldName],
          decoration: InputDecoration(
            hintText: 'Enter numeric value',
            suffixText: unit.isNotEmpty ? unit : null,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 8,
            ),
            isDense: true,
          ),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: const TextStyle(fontSize: 14),
          validator: (value) {
            if (fieldDef['isMandatory'] == true &&
                (value == null || value.trim().isEmpty)) {
              return 'This field is required';
            }
            if (value != null &&
                value.isNotEmpty &&
                double.tryParse(value) == null) {
              return 'Please enter a valid number';
            }
            return null;
          },
        );

      case 'boolean':
        return Column(
          children: [
            SwitchListTile(
              title: Text(
                _booleanFieldValues[fieldName] == true ? 'Yes' : 'No',
                style: const TextStyle(fontSize: 14),
              ),
              value: _booleanFieldValues[fieldName] ?? false,
              onChanged: (value) =>
                  setState(() => _booleanFieldValues[fieldName] = value),
              contentPadding: EdgeInsets.zero,
              dense: true,
            ),
            if (_booleanDescriptionControllers[fieldName] != null)
              TextFormField(
                controller: _booleanDescriptionControllers[fieldName],
                decoration: InputDecoration(
                  hintText: 'Add description/remarks',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  isDense: true,
                ),
                style: const TextStyle(fontSize: 14),
                maxLines: 2,
              ),
          ],
        );

      case 'date':
        final currentDate = _dateFieldValues[fieldName];
        return GestureDetector(
          onTap: () => _selectDateForField(fieldName),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.calendar_today,
                  size: 16,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  currentDate != null
                      ? DateFormat('MMM dd, yyyy').format(currentDate)
                      : 'Select date',
                  style: TextStyle(
                    fontSize: 14,
                    color: currentDate != null
                        ? (isDarkMode ? Colors.white : Colors.black)
                        : Colors.grey[600],
                  ),
                ),
                const Spacer(),
                Icon(Icons.arrow_drop_down, color: Colors.grey[600]),
              ],
            ),
          ),
        );

      case 'dropdown':
      case 'group':
        final options = List<String>.from(fieldDef['options'] ?? []);
        if (options.isEmpty) {
          return Text(
            'No options configured',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
              fontStyle: FontStyle.italic,
            ),
          );
        }
        return DropdownButtonFormField<String>(
          value: _dropdownFieldValues[fieldName],
          decoration: InputDecoration(
            hintText: 'Select option',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 8,
            ),
            isDense: true,
          ),
          isExpanded: true,
          items: options.map((option) {
            return DropdownMenuItem(
              value: option,
              child: Text(option, style: const TextStyle(fontSize: 14)),
            );
          }).toList(),
          onChanged: (value) =>
              setState(() => _dropdownFieldValues[fieldName] = value),
          validator: (value) {
            if (fieldDef['isMandatory'] == true && value == null) {
              return 'Please select an option';
            }
            return null;
          },
        );

      default:
        return const Text(
          'Unsupported field type',
          style: TextStyle(fontSize: 14),
        );
    }
  }

  void _initializeFieldController(String fieldName, String dataType) {
    switch (dataType) {
      case 'text':
      case 'number':
        _textFieldControllers[fieldName] = TextEditingController();
        break;
      case 'boolean':
        _booleanFieldValues[fieldName] = false;
        _booleanDescriptionControllers[fieldName] = TextEditingController();
        break;
      case 'date':
        _dateFieldValues[fieldName] = null;
        break;
      case 'dropdown':
      case 'group':
        _dropdownFieldValues[fieldName] = null;
        break;
    }
  }

  Widget _buildActionButton(ThemeData theme, bool isDarkMode) {
    final bool canSave = _selectedTemplate != null && !_isSaving;

    return FloatingActionButton.extended(
      onPressed: canSave ? _saveAssignment : null,
      backgroundColor: canSave ? theme.colorScheme.primary : Colors.grey[400],
      elevation: canSave ? 2 : 0,
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_isSaving)
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
          else
            Icon(
              _existingAssignmentId == null ? Icons.save : Icons.update,
              size: 20,
            ),
          const SizedBox(width: 8),
          Text(
            _isSaving
                ? 'Saving...'
                : (_existingAssignmentId == null
                      ? 'Save Assignment'
                      : 'Update Assignment'),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  Color _getDataTypeColor(String dataType, ThemeData theme) {
    switch (dataType) {
      case 'text':
        return theme.colorScheme.primary;
      case 'number':
        return theme.colorScheme.secondary;
      case 'boolean':
        return Colors.orange;
      case 'date':
        return theme.colorScheme.tertiary;
      case 'dropdown':
        return Colors.teal;
      case 'group':
        return Colors.purple;
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
      case 'group':
        return Icons.group_work;
      default:
        return Icons.help;
    }
  }
}
