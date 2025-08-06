import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../equipment_icons/capacitor_bank_icon.dart';
import '../../models/bay_model.dart';
import '../../models/reading_models.dart';
import '../../models/logsheet_models.dart';
import '../../models/user_model.dart';
import '../../utils/snackbar_utils.dart';
import '../../equipment_icons/energy_meter_icon.dart';
import '../../equipment_icons/feeder_icon.dart';
import '../../equipment_icons/circuit_breaker_icon.dart';

// Widget to render equipment icons based on field or bay type
class _EquipmentIcon extends StatelessWidget {
  final String type;
  final double size;
  final Color color;

  const _EquipmentIcon({
    required this.type,
    this.size = 24.0,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    Widget child;
    final Size iconSize = Size(size, size);

    switch (type.toLowerCase()) {
      case 'operations':
        child = CustomPaint(
          painter: FeederIconPainter(
            color: color,
            equipmentSize: iconSize,
            symbolSize: iconSize,
          ),
          size: iconSize,
        );
        break;
      case 'energy':
        child = CustomPaint(
          painter: EnergyMeterIconPainter(
            color: color,
            equipmentSize: iconSize,
            symbolSize: iconSize,
          ),
          size: iconSize,
        );
        break;
      case 'tripping':
        child = CustomPaint(
          painter: CircuitBreakerIconPainter(
            color: color,
            equipmentSize: iconSize,
            symbolSize: iconSize,
          ),
          size: iconSize,
        );
        break;
      case 'assets':
        child = CustomPaint(
          painter: CapacitorBankIconPainter(
            color: color,
            equipmentSize: iconSize,
            symbolSize: iconSize,
          ),
          size: iconSize,
        );
        break;
      case 'sld':
        child = Icon(Icons.electrical_services, size: size, color: color);
        break;
      default:
        child = Icon(Icons.device_unknown, size: size, color: color);
    }

    return SizedBox(width: size, height: size, child: child);
  }
}

class LogsheetEntryScreen extends StatefulWidget {
  final String substationId;
  final String substationName;
  final String bayId;
  final DateTime readingDate;
  final String frequency;
  final int? readingHour;
  final AppUser currentUser;
  final bool forceReadOnly;

  const LogsheetEntryScreen({
    super.key,
    required this.substationId,
    required this.substationName,
    required this.bayId,
    required this.readingDate,
    required this.frequency,
    this.readingHour,
    required this.currentUser,
    this.forceReadOnly = false,
    int? selectedHour,
  });

  @override
  State<LogsheetEntryScreen> createState() => _LogsheetEntryScreenState();
}

class _LogsheetEntryScreenState extends State<LogsheetEntryScreen>
    with SingleTickerProviderStateMixin {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  bool _isLoading = true;
  bool _isSaving = false;
  late AnimationController _animationController;

  Bay? _currentBay;
  DocumentSnapshot? _bayReadingAssignmentDoc;
  LogsheetEntry? _existingLogsheetEntry;
  LogsheetEntry? _previousLogsheetEntry;

  List<ReadingField> _filteredReadingFields = [];
  final Map<String, TextEditingController> _readingTextFieldControllers = {};
  final Map<String, bool> _readingBooleanFieldValues = {};
  final Map<String, DateTime?> _readingDateFieldValues = {};
  final Map<String, String?> _readingDropdownFieldValues = {};
  final Map<String, TextEditingController>
  _readingBooleanDescriptionControllers = {};

  bool _isFirstDataEntryForThisBayFrequency = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _initializeScreenData();
    _animationController.forward();
  }

  @override
  void dispose() {
    _readingTextFieldControllers.forEach(
      (key, controller) => controller.dispose(),
    );
    _readingBooleanDescriptionControllers.forEach(
      (key, controller) => controller.dispose(),
    );
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _initializeScreenData() async {
    setState(() => _isLoading = true);
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
        await _fetchAndInitializeLogsheetEntries();
      } else {
        _filteredReadingFields = [];
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
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchAndInitializeLogsheetEntries() async {
    _existingLogsheetEntry = await _getLogsheetForDate(widget.readingDate);
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
      if (widget.readingHour != null && widget.readingHour! > 0) {
        queryPreviousDate = DateTime(
          widget.readingDate.year,
          widget.readingDate.month,
          widget.readingDate.day,
          widget.readingHour! - 1,
        );
      } else if (widget.readingHour == 0) {
        queryPreviousDate = DateTime(
          widget.readingDate.year,
          widget.readingDate.month,
          widget.readingDate.day - 1,
          23,
        );
      } else {
        queryPreviousDate = widget.readingDate.subtract(
          const Duration(days: 1),
        );
      }
    }
    _previousLogsheetEntry = await _getLogsheetForDate(queryPreviousDate);
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
          .subtract(const Duration(milliseconds: 1));
    } else {
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

      if (_existingLogsheetEntry == null) {
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
    if (!_formKey.currentState!.validate()) return;
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

    setState(() => _isSaving = true);
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
      if (mounted)
        SnackBarUtils.showSnackBar(
          context,
          'Failed to save logsheet: $e',
          isError: true,
        );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<String?> _showModificationReasonDialog() async {
    if (widget.currentUser.role != UserRole.subdivisionManager ||
        _existingLogsheetEntry == null)
      return "Initial Entry";

    final theme = Theme.of(context);
    TextEditingController reasonController = TextEditingController();
    return await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: theme.colorScheme.surface,
        title: Text(
          'Reason for Modification',
          style: TextStyle(
            fontFamily: 'Roboto',
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurface,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: reasonController,
              decoration: InputDecoration(
                hintText: 'Enter reason for modification...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                filled: true,
                fillColor: theme.colorScheme.primary.withOpacity(0.05),
                errorStyle: TextStyle(
                  color: theme.colorScheme.error,
                  fontFamily: 'Roboto',
                ),
              ),
              maxLength: 200,
              maxLines: 3,
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Cancel',
              style: TextStyle(
                fontFamily: 'Roboto',
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(reasonController.text),
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: theme.colorScheme.onPrimary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Submit', style: TextStyle(fontFamily: 'Roboto')),
          ),
        ],
      ),
    );
  }

  Widget _buildReadingFieldInput(ReadingField field) {
    final theme = Theme.of(context);
    final String fieldName = field.name;
    final String dataType = field.dataType.toString().split('.').last;
    bool isMandatory = field.isMandatory;
    final bool isPreviousReadingField =
        fieldName.startsWith('Previous Day Reading') ||
        fieldName.startsWith('Previous Month Reading');
    if (isPreviousReadingField && _isFirstDataEntryForThisBayFrequency)
      isMandatory = false;
    final bool isReadOnly =
        widget.forceReadOnly ||
        (widget.currentUser.role == UserRole.substationUser &&
            _existingLogsheetEntry != null) ||
        (isPreviousReadingField &&
            _existingLogsheetEntry == null &&
            _previousLogsheetEntry != null);
    final String? unit = field.unit;
    final List<String>? options = field.options;

    final inputDecoration = InputDecoration(
      labelText: fieldName + (isMandatory ? ' *' : ''),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      filled: true,
      fillColor: isReadOnly
          ? Colors.grey.shade100
          : theme.colorScheme.primary.withOpacity(0.05),
      suffixText: unit,
      prefixIcon: _EquipmentIcon(
        type: _currentBay?.bayType ?? dataType,
        color: isReadOnly ? Colors.grey : theme.colorScheme.primary,
      ),
      errorStyle: TextStyle(
        color: theme.colorScheme.error,
        fontFamily: 'Roboto',
      ),
    );

    String? Function(String?)? validator;
    if (isMandatory && !isReadOnly) {
      validator = (value) => (value == null || value.trim().isEmpty)
          ? '$fieldName is mandatory'
          : null;
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
            if (validator != null && validator(value) != null)
              return validator(value);
            if (value!.isNotEmpty && double.tryParse(value) == null)
              return 'Enter a valid number for $fieldName';
            return null;
          },
        );
        break;
      case 'boolean':
        fieldWidget = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SwitchListTile(
              title: Text(
                fieldName + (isMandatory ? ' *' : ''),
                style: const TextStyle(fontFamily: 'Roboto'),
              ),
              value: _readingBooleanFieldValues.putIfAbsent(
                fieldName,
                () => false,
              ),
              onChanged: isReadOnly
                  ? null
                  : (value) => setState(
                      () => _readingBooleanFieldValues[fieldName] = value,
                    ),
              secondary: _EquipmentIcon(
                type: 'boolean',
                color: isReadOnly ? Colors.grey : Colors.purple[700]!,
              ),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
            ),
            if (_readingBooleanFieldValues[fieldName]!)
              Padding(
                padding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
                child: TextFormField(
                  controller: _readingBooleanDescriptionControllers.putIfAbsent(
                    fieldName,
                    () => TextEditingController(),
                  ),
                  readOnly: isReadOnly,
                  decoration: inputDecoration.copyWith(
                    labelText: 'Description / Remarks (Optional)',
                    prefixIcon: Icon(
                      Icons.description,
                      color: isReadOnly ? Colors.grey : Colors.purple[700],
                    ),
                  ),
                  maxLines: 2,
                ),
              ),
            if (isMandatory &&
                !isReadOnly &&
                !_readingBooleanFieldValues[fieldName]! &&
                _formKey.currentState?.validate() == false)
              Padding(
                padding: const EdgeInsets.only(left: 48, top: 4),
                child: Text(
                  '$fieldName is mandatory',
                  style: TextStyle(
                    color: theme.colorScheme.error,
                    fontSize: 12,
                    fontFamily: 'Roboto',
                  ),
                ),
              ),
          ],
        );
        break;
      case 'date':
        final DateTime? currentDate = _readingDateFieldValues.putIfAbsent(
          fieldName,
          () => field.isMandatory && _existingLogsheetEntry == null
              ? widget.readingDate
              : null,
        );
        fieldWidget = ListTile(
          leading: Icon(
            Icons.calendar_today,
            color: isReadOnly ? Colors.grey : theme.colorScheme.primary,
          ),
          title: Text(
            fieldName +
                (isMandatory ? ' *' : '') +
                ': ' +
                (currentDate == null
                    ? 'Select Date'
                    : DateFormat('yyyy-MM-dd').format(currentDate)),
            style: const TextStyle(fontFamily: 'Roboto'),
          ),
          trailing: IconButton(
            icon: Icon(
              Icons.clear,
              color: isReadOnly
                  ? Colors.grey
                  : theme.colorScheme.onSurfaceVariant,
            ),
            onPressed: isReadOnly
                ? null
                : () =>
                      setState(() => _readingDateFieldValues[fieldName] = null),
          ),
          onTap: isReadOnly
              ? null
              : () async {
                  final theme = Theme.of(context);
                  final DateTime? picked = await showDatePicker(
                    context: context,
                    initialDate: currentDate ?? DateTime.now(),
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2101),
                    builder: (context, child) => Theme(
                      data: theme.copyWith(
                        colorScheme: theme.colorScheme.copyWith(
                          primary: theme.colorScheme.primary,
                          onPrimary: theme.colorScheme.onPrimary,
                          surface: theme.colorScheme.surface,
                          onSurface: theme.colorScheme.onSurface,
                        ),
                        dialogBackgroundColor: theme.colorScheme.surface,
                      ),
                      child: child!,
                    ),
                  );
                  if (picked != null)
                    setState(() => _readingDateFieldValues[fieldName] = picked);
                },
        );
        break;
      case 'dropdown':
        fieldWidget = DropdownButtonFormField<String>(
          value: _readingDropdownFieldValues[fieldName],
          decoration: inputDecoration,
          items: options!
              .map(
                (option) => DropdownMenuItem(
                  value: option,
                  child: Text(
                    option,
                    style: const TextStyle(fontFamily: 'Roboto'),
                  ),
                ),
              )
              .toList(),
          onChanged: isReadOnly
              ? null
              : (value) => setState(
                  () => _readingDropdownFieldValues[fieldName] = value,
                ),
          validator: validator,
        );
        break;
      default:
        fieldWidget = Text(
          'Unsupported data type: $dataType for $fieldName',
          style: const TextStyle(fontFamily: 'Roboto'),
        );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: AbsorbPointer(absorbing: isReadOnly, child: fieldWidget),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    String titleText = widget.forceReadOnly
        ? "View Readings"
        : "Enter Readings";
    if (_currentBay != null) {
      titleText =
          "${_currentBay!.name} (${StringExtension(widget.frequency).capitalize()}";
      if (widget.frequency == 'hourly' && widget.readingHour != null) {
        titleText += " - ${widget.readingHour!.toString().padLeft(2, '0')}:00)";
      } else {
        titleText += ")";
      }
    }

    final bool isReadOnlyView =
        widget.forceReadOnly ||
        (widget.currentUser.role == UserRole.substationUser &&
            _existingLogsheetEntry != null);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          titleText,
          style: const TextStyle(
            fontFamily: 'Roboto',
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        backgroundColor: theme.colorScheme.surface,
      ),
      body: SafeArea(
        child: _isLoading
            ? Center(
                child: Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Loading readings...',
                          style: TextStyle(
                            fontFamily: 'Roboto',
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            : Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                margin: const EdgeInsets.all(16),
                child: AnimatedCrossFade(
                  firstChild: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _EquipmentIcon(
                            type: _currentBay?.bayType ?? 'default',
                            color: theme.colorScheme.primary,
                            size: 80,
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'No ${widget.frequency.toLowerCase()} reading fields defined for this slot.',
                            style: TextStyle(
                              fontFamily: 'Roboto',
                              fontStyle: FontStyle.italic,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton(
                            onPressed: () => Navigator.of(context).pop(),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: theme.colorScheme.primary,
                              foregroundColor: theme.colorScheme.onPrimary,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text(
                              'Back',
                              style: TextStyle(fontFamily: 'Roboto'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  secondChild: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              _EquipmentIcon(
                                type: _currentBay?.bayType ?? 'default',
                                color: theme.colorScheme.primary,
                                size: 32,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'Substation: ${widget.substationName}',
                                style: TextStyle(
                                  fontFamily: 'Roboto',
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: theme.colorScheme.onSurface,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          ListTile(
                            leading: Icon(
                              Icons.calendar_today,
                              color: theme.colorScheme.primary,
                            ),
                            title: Text(
                              'Reading Date: ${DateFormat('yyyy-MM-dd').format(widget.readingDate)}',
                              style: const TextStyle(fontFamily: 'Roboto'),
                            ),
                          ),
                          const SizedBox(height: 16),
                          if (_currentBay?.multiplyingFactor != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 24),
                              child: Center(
                                child: Chip(
                                  label: Text(
                                    'Multiplying Factor: ${_currentBay!.multiplyingFactor}',
                                    style: const TextStyle(
                                      fontFamily: 'Roboto',
                                    ),
                                  ),
                                  backgroundColor:
                                      theme.colorScheme.secondaryContainer,
                                  side: BorderSide(
                                    color: theme.colorScheme.secondary,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                ),
                              ),
                            ),
                          ..._filteredReadingFields
                              .map((field) => _buildReadingFieldInput(field))
                              .toList(),
                          if (isReadOnlyView)
                            Center(
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Text(
                                  widget.forceReadOnly
                                      ? 'Viewing saved readings.'
                                      : 'Readings are saved and cannot be modified by Substation Users.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontFamily: 'Roboto',
                                    fontStyle: FontStyle.italic,
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  crossFadeState: _filteredReadingFields.isEmpty
                      ? CrossFadeState.showFirst
                      : CrossFadeState.showSecond,
                  duration: const Duration(milliseconds: 300),
                ),
              ),
      ),
      bottomNavigationBar: !isReadOnlyView
          ? Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(12),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: _isSaving
                  ? Center(
                      child: CircularProgressIndicator(
                        color: theme.colorScheme.primary,
                      ),
                    )
                  : ElevatedButton.icon(
                      onPressed: _saveLogsheetEntry,
                      icon: Icon(
                        Icons.save,
                        color: theme.colorScheme.onPrimary,
                      ),
                      label: Text(
                        _existingLogsheetEntry == null
                            ? 'Save Logsheet Entry'
                            : 'Update Logsheet Entry',
                        style: const TextStyle(fontFamily: 'Roboto'),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: theme.colorScheme.onPrimary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        minimumSize: const Size(double.infinity, 50),
                      ),
                    ),
            )
          : null,
    );
  }
}

extension StringExtension on String {
  String capitalize() =>
      isEmpty ? this : "${this[0].toUpperCase()}${substring(1)}";
}
