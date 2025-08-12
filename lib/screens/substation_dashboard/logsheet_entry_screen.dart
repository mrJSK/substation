import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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

// Enhanced Equipment Icon Widget matching BayReadingsStatusScreen style
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
      case 'transformer':
        child = Icon(Icons.electrical_services, size: size, color: color);
        break;
      case 'feeder':
        child = Icon(Icons.power, size: size, color: color);
        break;
      case 'line':
        child = Icon(Icons.power_input, size: size, color: color);
        break;
      case 'busbar':
        child = Icon(Icons.horizontal_rule, size: size, color: color);
        break;
      case 'capacitor bank':
        child = Icon(Icons.battery_charging_full, size: size, color: color);
        break;
      case 'reactor':
        child = Icon(Icons.device_hub, size: size, color: color);
        break;
      default:
        child = Icon(Icons.electrical_services, size: size, color: color);
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

  // Enhanced reading field input to match BayReadingsStatusScreen style
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

    // Container styling matching BayReadingsStatusScreen
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: _buildFieldWidget(
          field,
          theme,
          fieldName,
          dataType,
          isMandatory,
          isReadOnly,
          unit,
          options,
        ),
      ),
    );
  }

  Widget _buildFieldWidget(
    ReadingField field,
    ThemeData theme,
    String fieldName,
    String dataType,
    bool isMandatory,
    bool isReadOnly,
    String? unit,
    List<String>? options,
  ) {
    String? Function(String?)? validator;
    if (isMandatory && !isReadOnly) {
      validator = (value) => (value == null || value.trim().isEmpty)
          ? '$fieldName is mandatory'
          : null;
    }

    Widget fieldWidget;
    switch (dataType) {
      case 'text':
        fieldWidget = Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: (isReadOnly ? Colors.grey : theme.colorScheme.primary)
                    .withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: _EquipmentIcon(
                type: _currentBay?.bayType ?? dataType,
                color: isReadOnly ? Colors.grey : theme.colorScheme.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    fieldName + (isMandatory ? ' *' : ''),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _readingTextFieldControllers.putIfAbsent(
                      fieldName,
                      () => TextEditingController(),
                    ),
                    readOnly: isReadOnly,
                    decoration: InputDecoration(
                      hintText: 'Enter ${fieldName.toLowerCase()}',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      filled: true,
                      fillColor: isReadOnly
                          ? Colors.grey.shade100
                          : theme.colorScheme.primary.withOpacity(0.05),
                      suffixText: unit,
                    ),
                    validator: validator,
                  ),
                ],
              ),
            ),
          ],
        );
        break;
      case 'number':
        fieldWidget = Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: (isReadOnly ? Colors.grey : theme.colorScheme.primary)
                    .withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: _EquipmentIcon(
                type: _currentBay?.bayType ?? dataType,
                color: isReadOnly ? Colors.grey : theme.colorScheme.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    fieldName + (isMandatory ? ' *' : ''),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _readingTextFieldControllers.putIfAbsent(
                      fieldName,
                      () => TextEditingController(),
                    ),
                    readOnly: isReadOnly,
                    decoration: InputDecoration(
                      hintText: unit != null && unit.isNotEmpty
                          ? 'Enter value in $unit'
                          : 'Enter numerical value',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      filled: true,
                      fillColor: isReadOnly
                          ? Colors.grey.shade100
                          : theme.colorScheme.primary.withOpacity(0.05),
                      suffixText: unit,
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (validator != null && validator(value) != null)
                        return validator(value);
                      if (value!.isNotEmpty && double.tryParse(value) == null)
                        return 'Enter a valid number for $fieldName';
                      return null;
                    },
                  ),
                ],
              ),
            ),
          ],
        );
        break;
      case 'boolean':
        fieldWidget = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: (isReadOnly ? Colors.grey : Colors.purple[700]!)
                        .withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    _readingBooleanFieldValues.putIfAbsent(
                          fieldName,
                          () => false,
                        )
                        ? Icons.check_circle
                        : Icons.cancel,
                    color: isReadOnly ? Colors.grey : Colors.purple[700],
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fieldName + (isMandatory ? ' *' : ''),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: _readingBooleanFieldValues[fieldName]!
                                  ? Colors.green
                                  : Colors.red,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _readingBooleanFieldValues[fieldName]!
                                ? 'Yes'
                                : 'No',
                            style: TextStyle(
                              fontSize: 12,
                              color: _readingBooleanFieldValues[fieldName]!
                                  ? Colors.green
                                  : Colors.red,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: _readingBooleanFieldValues.putIfAbsent(
                    fieldName,
                    () => false,
                  ),
                  onChanged: isReadOnly
                      ? null
                      : (value) => setState(
                          () => _readingBooleanFieldValues[fieldName] = value,
                        ),
                ),
              ],
            ),
            if (_readingBooleanFieldValues[fieldName]!) ...[
              const SizedBox(height: 12),
              TextFormField(
                controller: _readingBooleanDescriptionControllers.putIfAbsent(
                  fieldName,
                  () => TextEditingController(),
                ),
                readOnly: isReadOnly,
                decoration: InputDecoration(
                  labelText: 'Description / Remarks (Optional)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  filled: true,
                  fillColor: theme.colorScheme.primary.withOpacity(0.05),
                  prefixIcon: Icon(
                    Icons.description,
                    color: isReadOnly ? Colors.grey : Colors.purple[700],
                  ),
                ),
                maxLines: 2,
              ),
            ],
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
        fieldWidget = Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: (isReadOnly ? Colors.grey : theme.colorScheme.primary)
                    .withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.calendar_today,
                color: isReadOnly ? Colors.grey : theme.colorScheme.primary,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    fieldName + (isMandatory ? ' *' : ''),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    currentDate == null
                        ? 'Select Date'
                        : DateFormat('yyyy-MM-dd').format(currentDate),
                    style: TextStyle(
                      fontSize: 14,
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.arrow_forward_ios, size: 16),
              onPressed: isReadOnly
                  ? null
                  : () async {
                      final DateTime? picked = await showDatePicker(
                        context: context,
                        initialDate: currentDate ?? DateTime.now(),
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2101),
                      );
                      if (picked != null)
                        setState(
                          () => _readingDateFieldValues[fieldName] = picked,
                        );
                    },
            ),
          ],
        );
        break;
      case 'dropdown':
        fieldWidget = Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: (isReadOnly ? Colors.grey : theme.colorScheme.primary)
                    .withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.arrow_drop_down,
                color: isReadOnly ? Colors.grey : theme.colorScheme.primary,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    fieldName + (isMandatory ? ' *' : ''),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: _readingDropdownFieldValues[fieldName],
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      filled: true,
                      fillColor: isReadOnly
                          ? Colors.grey.shade100
                          : theme.colorScheme.primary.withOpacity(0.05),
                    ),
                    items: options!
                        .map(
                          (option) => DropdownMenuItem(
                            value: option,
                            child: Text(option),
                          ),
                        )
                        .toList(),
                    onChanged: isReadOnly
                        ? null
                        : (value) => setState(
                            () =>
                                _readingDropdownFieldValues[fieldName] = value,
                          ),
                    validator: validator,
                  ),
                ],
              ),
            ),
          ],
        );
        break;
      default:
        fieldWidget = Text('Unsupported data type: $dataType for $fieldName');
    }
    return fieldWidget;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    String slotTitle = DateFormat('dd.MMM.yyyy').format(widget.readingDate);
    if (widget.frequency == 'hourly' && widget.readingHour != null) {
      slotTitle += ' - ${widget.readingHour!.toString().padLeft(2, '0')}:00 Hr';
    } else if (widget.frequency == 'daily') {
      slotTitle += ' - Daily Reading';
    }

    final bool isReadOnlyView =
        widget.forceReadOnly ||
        (widget.currentUser.role == UserRole.substationUser &&
            _existingLogsheetEntry != null);

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          _currentBay?.name ?? 'Reading Entry',
          style: TextStyle(
            color: theme.colorScheme.onSurface,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: theme.colorScheme.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_existingLogsheetEntry != null)
            Container(
              margin: const EdgeInsets.only(right: 16, top: 8, bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.2),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.green.withOpacity(0.5)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.check_circle,
                    size: 16,
                    color: Colors.green.shade700,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Saved',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.green.shade700,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Header matching BayReadingsStatusScreen style
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: theme.colorScheme.primary.withOpacity(0.3),
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: _EquipmentIcon(
                              type: _currentBay?.bayType ?? 'default',
                              color: theme.colorScheme.primary,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  slotTitle,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  widget.substationName,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: theme.colorScheme.onSurface
                                        .withOpacity(0.7),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (_currentBay?.multiplyingFactor != null) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: theme.colorScheme.outline.withOpacity(0.2),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.calculate,
                                color: theme.colorScheme.secondary,
                                size: 16,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Multiplying Factor: ${_currentBay!.multiplyingFactor}',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: theme.colorScheme.secondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                // Content
                Expanded(
                  child: _filteredReadingFields.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  size: 64,
                                  color: Colors.grey.shade400,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No Reading Fields Available',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'No ${widget.frequency.toLowerCase()} reading fields are defined for this slot.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : Form(
                          key: _formKey,
                          child: ListView.builder(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16.0,
                            ),
                            itemCount:
                                _filteredReadingFields.length +
                                (isReadOnlyView ? 1 : 0) +
                                1, // +1 for bottom padding
                            itemBuilder: (context, index) {
                              if (index == _filteredReadingFields.length) {
                                if (isReadOnlyView) {
                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: Colors.blue.withOpacity(0.3),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.info_outline,
                                          color: Colors.blue.shade700,
                                          size: 20,
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            widget.forceReadOnly
                                                ? 'Viewing saved readings.'
                                                : 'Readings are saved and cannot be modified by Substation Users.',
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: Colors.blue.shade700,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                } else {
                                  return const SizedBox(
                                    height: 100,
                                  ); // Bottom padding
                                }
                              } else if (index ==
                                  _filteredReadingFields.length + 1) {
                                return const SizedBox(
                                  height: 100,
                                ); // Bottom padding
                              }

                              return _buildReadingFieldInput(
                                _filteredReadingFields[index],
                              );
                            },
                          ),
                        ),
                ),
              ],
            ),
      floatingActionButton: !isReadOnlyView && _filteredReadingFields.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: _isSaving ? null : _saveLogsheetEntry,
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: theme.colorScheme.onPrimary,
              elevation: 4,
              icon: _isSaving
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: theme.colorScheme.onPrimary,
                      ),
                    )
                  : const Icon(Icons.save),
              label: Text(
                _isSaving
                    ? 'Saving...'
                    : _existingLogsheetEntry == null
                    ? 'Save Entry'
                    : 'Update Entry',
                style: const TextStyle(fontWeight: FontWeight.w500),
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
