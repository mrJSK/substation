import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import '../../models/reading_models.dart';
import '../../models/user_model.dart';
import '../../utils/snackbar_utils.dart';
import '../../widgets/reading_field_widgets.dart';

class BayReadingAssignmentScreen extends StatefulWidget {
  final String bayId;
  final String bayName;
  final AppUser currentUser;

  const BayReadingAssignmentScreen({
    Key? key,
    required this.bayId,
    required this.bayName,
    required this.currentUser,
  }) : super(key: key);

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
  String? _selectedTemplateId;

  String? _existingAssignmentId;
  DateTime? _readingStartDate;

  final List<Map<String, dynamic>> _instanceReadingFields = [];

  final Map<String, TextEditingController> _textFieldControllers = {};
  final Map<String, bool> _booleanFieldValues = {};
  final Map<String, DateTime?> _dateFieldValues = {};
  final Map<String, String?> _dropdownFieldValues = {};
  final Map<String, TextEditingController> _booleanDescriptionControllers = {};
  final Map<String, List<String>> _groupOptions = {};

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
      final bayDoc = await FirebaseFirestore.instance
          .collection('bays')
          .doc(widget.bayId)
          .get();
      if (!bayDoc.exists) {
        if (!mounted) return;
        SnackBarUtils.showSnackBar(
          context,
          'Error: Bay not found.',
          isError: true,
        );
        Navigator.of(context).pop();
        return;
      }
      _bayType = (bayDoc.data() as Map<String, dynamic>)['bayType'] as String?;

      final templatesSnapshot = await FirebaseFirestore.instance
          .collection('readingTemplates')
          .where('bayType', isEqualTo: _bayType)
          .where('isActive', isEqualTo: true)
          .orderBy('createdAt', descending: true)
          .get();

      _availableReadingTemplates = templatesSnapshot.docs
          .map((doc) => ReadingTemplate.fromFirestore(doc))
          .toList();

      final existingAssignmentSnapshot = await FirebaseFirestore.instance
          .collection('bayReadingAssignments')
          .where('bayId', isEqualTo: widget.bayId)
          .limit(1)
          .get();

      if (existingAssignmentSnapshot.docs.isNotEmpty) {
        final existingDoc = existingAssignmentSnapshot.docs.first;
        _existingAssignmentId = existingDoc.id;
        final assignedData = existingDoc.data() as Map<String, dynamic>;

        if (assignedData.containsKey('readingStartDate') &&
            assignedData['readingStartDate'] != null) {
          _readingStartDate = (assignedData['readingStartDate'] as Timestamp)
              .toDate();
        } else {
          _readingStartDate = DateTime.now();
        }
        final existingTemplateId = assignedData['templateId'] as String?;
        if (existingTemplateId != null) {
          _selectedTemplateId = existingTemplateId;
          try {
            _selectedTemplate = _availableReadingTemplates.firstWhere(
              (t) => t.id == existingTemplateId,
            );
          } catch (_) {
            if (_availableReadingTemplates.isNotEmpty) {
              _selectedTemplate = _availableReadingTemplates.first;
              _selectedTemplateId = _selectedTemplate!.id;
            } else {
              _selectedTemplate = null;
              _selectedTemplateId = null;
            }
          }
        }
        final List assignedFieldsRaw =
            assignedData['assignedFields'] as List? ?? [];
        _instanceReadingFields
          ..clear()
          ..addAll(assignedFieldsRaw.map((e) => Map<String, dynamic>.from(e)));

        _initializeFieldControllers();
      } else {
        _readingStartDate = DateTime.now();
        if (_availableReadingTemplates.isNotEmpty) {
          _selectedTemplate = _availableReadingTemplates.first;
          _selectedTemplateId = _selectedTemplate!.id;
          _loadTemplateFields(_selectedTemplate!);
          await _autoFillPreviousReadings();
        }
      }

      _animationController.forward();
    } catch (e) {
      if (!mounted) return;
      SnackBarUtils.showSnackBar(
        context,
        'Failed to load data: $e',
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _loadTemplateFields(ReadingTemplate template) {
    _instanceReadingFields.clear();
    for (final field in template.readingFields) {
      _addFieldToInstance(field, null);
    }
    _initializeFieldControllers();
  }

  void _addFieldToInstance(ReadingField field, String? parentGroupName) {
    final Map<String, dynamic> fieldMap = field.toMap();

    if (parentGroupName != null) {
      fieldMap['groupName'] = parentGroupName;
    }

    fieldMap['isPreviousReading'] = field.name.toLowerCase().contains(
      'previous',
    );
    fieldMap['isCurrentReading'] = field.name.toLowerCase().contains('current');
    fieldMap['autoFilled'] = false;
    fieldMap['readingStartDate'] = _readingStartDate;

    if (fieldMap['isPreviousReading'] == true) {
      final currentFieldName = field.name
          .replaceAll('previous', 'current')
          .replaceAll('Previous', 'Current');
      fieldMap['linkedCurrentField'] = currentFieldName;
    } else if (fieldMap['isCurrentReading'] == true) {
      final previousFieldName = field.name
          .replaceAll('current', 'previous')
          .replaceAll('Current', 'Previous');
      fieldMap['linkedPreviousField'] = previousFieldName;
    }

    _instanceReadingFields.add(fieldMap);

    if (field.dataType == ReadingFieldDataType.group && field.hasNestedFields) {
      for (final nestedField in field.nestedFields!) {
        _addFieldToInstance(nestedField, field.name);
      }
    }
  }

  Future<void> _autoFillPreviousReadings() async {
    if (_readingStartDate == null) return;

    final DateTime today = DateTime.now();
    final DateTime startDate = DateTime(
      _readingStartDate!.year,
      _readingStartDate!.month,
      _readingStartDate!.day,
    );
    final DateTime currentDate = DateTime(today.year, today.month, today.day);
    if (!currentDate.isAfter(startDate)) return;

    try {
      final DateTime yesterday = currentDate.subtract(const Duration(days: 1));
      final QuerySnapshot yesterdayReadings = await FirebaseFirestore.instance
          .collection('bayReadings')
          .where('bayId', isEqualTo: widget.bayId)
          .where('readingDate', isEqualTo: Timestamp.fromDate(yesterday))
          .limit(1)
          .get();

      if (yesterdayReadings.docs.isEmpty) return;
      final Map<String, dynamic> yesterdayData =
          yesterdayReadings.docs.first.data() as Map<String, dynamic>;
      final List yesterdayFields = (yesterdayData['readings'] ?? []) as List;

      for (final fieldMap in _instanceReadingFields) {
        final String fieldName = fieldMap['name'] as String;
        final bool isPrevious = fieldMap['isPreviousReading'] as bool? ?? false;

        if (!isPrevious) continue;
        final String? linkedCurrentField =
            fieldMap['linkedCurrentField'] as String?;
        if (linkedCurrentField == null) continue;

        final dynamic yesterdayCurrentReading = yesterdayFields.firstWhere(
          (e) => (e as Map)['name'] == linkedCurrentField,
          orElse: () => null,
        );
        if (yesterdayCurrentReading == null) continue;

        final String dataType = fieldMap['dataType'] as String;
        final dynamic value = (yesterdayCurrentReading as Map)['value'];

        switch (dataType) {
          case 'text':
          case 'number':
            if (_textFieldControllers.containsKey(fieldName)) {
              _textFieldControllers[fieldName]?.text = value?.toString() ?? '';
            }
            break;
          case 'boolean':
            _booleanFieldValues[fieldName] = value as bool? ?? false;
            break;
          case 'date':
            if (value != null) {
              _dateFieldValues[fieldName] = (value as Timestamp).toDate();
            }
            break;
          case 'dropdown':
          case 'group':
            _dropdownFieldValues[fieldName] = value?.toString();
            break;
        }
        fieldMap['autoFilled'] = true;
        fieldMap['value'] = value;
      }

      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Error auto-filling previous readings: $e');
    }
  }

  void _initializeFieldControllers() {
    _textFieldControllers.clear();
    _booleanFieldValues.clear();
    _dateFieldValues.clear();
    _dropdownFieldValues.clear();
    _booleanDescriptionControllers.clear();
    _groupOptions.clear();

    for (final fieldMap in _instanceReadingFields) {
      final String fieldName = fieldMap['name'] as String? ?? '';
      final String dataType = fieldMap['dataType'] as String? ?? 'text';
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
          _dropdownFieldValues[fieldName] = null;
          break;
        case 'group':
          final List options = List.from(fieldMap['options'] ?? []);
          _groupOptions[fieldName] = options.map((e) => e.toString()).toList();
          _dropdownFieldValues[fieldName] = null;
          break;
      }
    }
  }

  void _onTemplateSelected(String? templateId) {
    if (templateId == null) return;
    final selectedTemplate = _availableReadingTemplates.firstWhere(
      (t) => t.id == templateId,
    );
    setState(() {
      _selectedTemplateId = templateId;
      _selectedTemplate = selectedTemplate;
      _clearAllControllers();
      _loadTemplateFields(selectedTemplate);
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
      _instanceReadingFields.add({
        'name': '',
        'dataType': ReadingFieldDataType.text.toString().split('.').last,
        'unit': '',
        'options': <String>[],
        'isMandatory': false,
        'frequency': ReadingFrequency.daily.toString().split('.').last,
        'description_remarks': '',
        'nestedFields': null,
        'groupName': null,
        'isPreviousReading': false,
        'isCurrentReading': false,
        'autoFilled': false,
        'linkedCurrentField': null,
        'linkedPreviousField': null,
      });
    });
  }

  void _addInstanceGroupField() {
    setState(() {
      _instanceReadingFields.add({
        'name': '',
        'dataType': ReadingFieldDataType.group.toString().split('.').last,
        'unit': '',
        'options': <String>[],
        'isMandatory': false,
        'frequency': ReadingFrequency.daily.toString().split('.').last,
        'description_remarks': '',
        'nestedFields': <Map<String, dynamic>>[],
        'groupName': null,
        'isPreviousReading': false,
        'isCurrentReading': false,
        'autoFilled': false,
        'linkedCurrentField': null,
        'linkedPreviousField': null,
      });
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
      for (final fieldMap in _instanceReadingFields) {
        final String fieldName = (fieldMap['name'] as String?)?.trim() ?? '';
        if (fieldName.isEmpty) continue;

        final Map<String, dynamic> current = Map<String, dynamic>.from(
          fieldMap,
        );

        current.remove('value');
        current.remove('autoFilled');
        current.remove('readingStartDate');
        current.remove('isPreviousReading');
        current.remove('isCurrentReading');
        current.remove('linkedCurrentField');
        current.remove('linkedPreviousField');

        finalAssignedFields.add(current);
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

      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        SnackBarUtils.showSnackBar(
          context,
          'Failed to save assignment: $e',
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _selectReadingStartDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _readingStartDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        final theme = Theme.of(context);
        return Theme(
          data: theme.copyWith(
            colorScheme: theme.colorScheme.copyWith(
              primary: theme.colorScheme.primary,
              onPrimary: theme.colorScheme.onPrimary,
              surface: theme.colorScheme.surface,
              onSurface: theme.colorScheme.onSurface,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: theme.colorScheme.primary,
              ),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _readingStartDate) {
      setState(() {
        _readingStartDate = picked;
      });
      await _autoFillPreviousReadings();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    if (_isLoading) {
      return Scaffold(
        backgroundColor: isDarkMode
            ? const Color(0xFF1C1C1E)
            : const Color(0xFFFAFAFA),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation(theme.colorScheme.primary),
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
      backgroundColor: isDarkMode
          ? const Color(0xFF1C1C1E)
          : const Color(0xFFFAFAFA),
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
                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: _buildActionButton(theme),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  PreferredSizeWidget _buildAppBar(ThemeData theme, bool isDarkMode) {
    return AppBar(
      backgroundColor: isDarkMode
          ? const Color(0xFF1C1C1E)
          : const Color(0xFFFAFAFA),
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
          color: isDarkMode ? Colors.grey[700] : Colors.grey,
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
          color: isDarkMode ? const Color(0xFF2C2C2E) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: isDarkMode
                  ? Colors.black.withOpacity(0.3)
                  : Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
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
    final DateTime today = DateTime.now();
    final DateTime? startDate = _readingStartDate;
    final bool isStartDate =
        startDate != null &&
        DateTime(today.year, today.month, today.day).isAtSameMomentAs(
          DateTime(startDate.year, startDate.month, startDate.day),
        );

    return FadeTransition(
      opacity: _fadeAnimation,
      child: GestureDetector(
        onTap: () => _selectReadingStartDate(context),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDarkMode ? const Color(0xFF2C2C2E) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: isDarkMode
                    ? Colors.black.withOpacity(0.3)
                    : Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
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
              if (!isStartDate)
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.orange.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.auto_awesome,
                        size: 16,
                        color: Colors.orange,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Previous readings will be auto-filled from previous day\'s current readings',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.orange[700],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
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
          color: isDarkMode ? const Color(0xFF2C2C2E) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: isDarkMode
                  ? Colors.black.withOpacity(0.3)
                  : Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
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
              DropdownButtonFormField<String>(
                value: _selectedTemplateId,
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
                      color: isDarkMode ? Colors.grey : Colors.grey,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: isDarkMode ? Colors.grey : Colors.grey,
                    ),
                  ),
                  filled: true,
                  fillColor: isDarkMode
                      ? const Color(0xFF3C3C3E)
                      : Colors.grey[50],
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                ),
                dropdownColor: isDarkMode
                    ? const Color(0xFF2C2C2E)
                    : Colors.white,
                isExpanded: true,
                items: _availableReadingTemplates.map((template) {
                  return DropdownMenuItem<String>(
                    value: template.id,
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
                        if ((template.description ?? '').isNotEmpty)
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
        color: isDarkMode ? const Color(0xFF2C2C2E) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: isDarkMode
                ? Colors.black.withOpacity(0.3)
                : Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
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
            FieldListWidget(
              fields: _instanceReadingFields,
              isEditable: true,
              dataTypes: _dataTypes,
              frequencies: _frequencies,
              onFieldsChanged: (updated) {
                setState(() {
                  _instanceReadingFields
                    ..clear()
                    ..addAll(updated.map((e) => Map<String, dynamic>.from(e)));
                });
              },
              onAddField: _addInstanceReadingField,
              onAddGroupField: _addInstanceGroupField,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(ThemeData theme) {
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
                valueColor: AlwaysStoppedAnimation(Colors.white),
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
}
