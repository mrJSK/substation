import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../equipment_icons/capacitor_bank_icon.dart';
import '../../models/bay_model.dart';
import '../../models/reading_models.dart';
import '../../models/logsheet_models.dart';
import '../../models/user_model.dart';
import '../../models/enhanced_bay_data.dart';
import '../../services/comprehensive_cache_service.dart';
import '../../utils/snackbar_utils.dart';
import '../../equipment_icons/energy_meter_icon.dart';
import '../../equipment_icons/feeder_icon.dart';
import '../../equipment_icons/circuit_breaker_icon.dart';

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
  final Map<String, dynamic>? autoPopulateData;

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
    this.autoPopulateData,
  });

  @override
  State<LogsheetEntryScreen> createState() => _LogsheetEntryScreenState();
}

class _LogsheetEntryScreenState extends State<LogsheetEntryScreen>
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final ComprehensiveCacheService _cache = ComprehensiveCacheService();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  bool _isLoading = true;
  bool _isSaving = false;
  late AnimationController _animationController;

  // 🔧 FIX: Add reading state tracking
  bool _hasExistingReading = false;
  bool _isReadOnlyDueToExistingReading = false;

  Bay? _currentBay;
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

  // 🔧 FIX: Check permission to modify existing readings
  bool _canModifyExistingReading() {
    return [
      UserRole.admin,
      UserRole.subdivisionManager,
      UserRole.divisionManager,
      UserRole.circleManager,
      UserRole.zoneManager,
    ].contains(widget.currentUser.role);
  }

  Future<void> _initializeScreenData() async {
    setState(() => _isLoading = true);

    try {
      // ✅ USE CACHE - No Firebase queries!
      if (!_cache.isInitialized) {
        throw Exception('Cache not initialized - please restart the app');
      }

      // Get bay data from cache
      final bayData = _cache.getBayById(widget.bayId);
      if (bayData == null) {
        throw Exception('Bay not found in cache');
      }

      _currentBay = bayData.bay;

      // Get reading fields for this frequency
      _filteredReadingFields = bayData.getReadingFields(
        widget.frequency,
        mandatoryOnly: false,
      );

      // Get existing reading from cache
      _existingLogsheetEntry = bayData.getReading(
        widget.readingDate,
        widget.frequency,
        hour: widget.readingHour,
      );

      // 🔧 FIX: Set reading state
      _hasExistingReading = _existingLogsheetEntry != null;

      // 🔧 FIX: Determine if should be read-only
      _isReadOnlyDueToExistingReading =
          _hasExistingReading &&
          !_canModifyExistingReading() &&
          !widget.forceReadOnly;

      print(
        '📊 Reading exists: $_hasExistingReading, Read-only: $_isReadOnlyDueToExistingReading',
      );

      // Get previous reading for auto-populate from cache
      final previousDate = _calculatePreviousDate();
      _previousLogsheetEntry = bayData.getReading(
        previousDate,
        widget.frequency,
        hour: widget.readingHour,
      );

      // Check if this is first data entry
      _isFirstDataEntryForThisBayFrequency =
          _existingLogsheetEntry == null && _previousLogsheetEntry == null;

      _initializeReadingFieldControllers();

      print('✅ Loaded logsheet data from cache for bay: ${_currentBay!.name}');
    } catch (e) {
      print("Error initializing screen data: $e");
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
        setState(() => _isLoading = false);
      }
    }
  }

  DateTime _calculatePreviousDate() {
    if (widget.frequency == 'daily') {
      return widget.readingDate.subtract(const Duration(days: 1));
    } else if (widget.frequency == 'monthly') {
      return DateTime(
        widget.readingDate.year,
        widget.readingDate.month - 1,
        widget.readingDate.day,
      );
    } else {
      if (widget.readingHour != null && widget.readingHour! > 0) {
        return DateTime(
          widget.readingDate.year,
          widget.readingDate.month,
          widget.readingDate.day,
          widget.readingHour! - 1,
        );
      } else if (widget.readingHour == 0) {
        return DateTime(
          widget.readingDate.year,
          widget.readingDate.month,
          widget.readingDate.day - 1,
          23,
        );
      } else {
        return widget.readingDate.subtract(const Duration(days: 1));
      }
    }
  }

  void _initializeReadingFieldControllers() {
    // Dispose existing controllers
    _readingTextFieldControllers.forEach(
      (key, controller) => controller.dispose(),
    );
    _readingBooleanDescriptionControllers.forEach(
      (key, controller) => controller.dispose(),
    );

    // Clear all maps
    _readingTextFieldControllers.clear();
    _readingBooleanFieldValues.clear();
    _readingDateFieldValues.clear();
    _readingDropdownFieldValues.clear();
    _readingBooleanDescriptionControllers.clear();

    final Map<String, dynamic> existingValues =
        _existingLogsheetEntry?.values ?? {};
    final Map<String, dynamic> previousValues =
        _previousLogsheetEntry?.values ?? {};
    final Map<String, dynamic> autoPopulateMap = widget.autoPopulateData ?? {};

    for (var field in _filteredReadingFields) {
      final fieldName = field.name;
      final dataType = field.dataType.toString().split('.').last;

      dynamic value = existingValues[fieldName];

      // Auto-populate logic for new entries
      if (_existingLogsheetEntry == null) {
        if (fieldName.startsWith('Previous Day Reading')) {
          if (autoPopulateMap.containsKey(fieldName)) {
            value = autoPopulateMap[fieldName];
          } else if (previousValues.containsKey(
            fieldName.replaceFirst('Previous Day', 'Current Day'),
          )) {
            value =
                previousValues[fieldName.replaceFirst(
                  'Previous Day',
                  'Current Day',
                )];
          }
        } else if (fieldName.startsWith('Previous Month Reading')) {
          if (previousValues.containsKey(
            fieldName.replaceFirst('Previous Month', 'Current Month'),
          )) {
            value =
                previousValues[fieldName.replaceFirst(
                  'Previous Month',
                  'Current Month',
                )];
          }
        }
      }

      // Initialize controllers based on data type
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

  // 🔧 FIX: Enhanced save method with better error handling and cache sync
  Future<void> _saveLogsheetEntry() async {
    if (!_formKey.currentState!.validate()) return;

    if (_currentBay == null) {
      SnackBarUtils.showSnackBar(context, 'Missing bay data.', isError: true);
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

    // 🔧 FIX: Prevent saving if reading already exists and user doesn't have permission
    if (_hasExistingReading && !_canModifyExistingReading()) {
      SnackBarUtils.showSnackBar(
        context,
        'Reading already exists and cannot be modified.',
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
        templateId: 'CACHE_TEMPLATE', // Using cache-based template ID
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
        // Create new entry
        print('🔄 Saving new entry for bay: ${widget.bayId}');

        final docRef = await FirebaseFirestore.instance
            .collection('logsheetEntries')
            .add(logsheetData.toFirestore());

        // ✅ UPDATE CACHE
        final savedEntry = logsheetData.copyWith(id: docRef.id);
        _cache.updateBayReading(widget.bayId, savedEntry);

        // 🔧 FIX: Force cache refresh to ensure consistency
        await _cache.refreshBayData(widget.bayId);

        print('✅ Entry saved and cache updated');

        if (mounted) {
          SnackBarUtils.showSnackBar(context, 'Reading saved successfully!');
          Navigator.of(
            context,
          ).pop(true); // Return true to indicate data was saved
        }
      } else {
        // Update existing entry
        print('🔄 Updating existing entry for bay: ${widget.bayId}');

        await FirebaseFirestore.instance
            .collection('logsheetEntries')
            .doc(_existingLogsheetEntry!.id)
            .update(logsheetData.toFirestore());

        // ✅ UPDATE CACHE
        final updatedEntry = logsheetData.copyWith(
          id: _existingLogsheetEntry!.id,
        );
        _cache.updateBayReading(widget.bayId, updatedEntry);

        // 🔧 FIX: Force cache refresh to ensure consistency
        await _cache.refreshBayData(widget.bayId);

        print('✅ Entry updated and cache refreshed');

        if (mounted) {
          SnackBarUtils.showSnackBar(context, 'Reading updated successfully!');
          Navigator.of(
            context,
          ).pop(true); // Return true to indicate data was saved
        }
      }
    } catch (e) {
      print("❌ Error saving logsheet entry: $e");
      if (mounted) {
        SnackBarUtils.showSnackBar(
          context,
          'Failed to save reading: $e',
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<String?> _showModificationReasonDialog() async {
    if (widget.currentUser.role != UserRole.subdivisionManager ||
        _existingLogsheetEntry == null)
      return "Initial Entry";

    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    TextEditingController reasonController = TextEditingController();

    return await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: isDarkMode
            ? const Color(0xFF2C2C2E)
            : theme.colorScheme.surface,
        title: Text(
          'Reason for Modification',
          style: TextStyle(
            fontFamily: 'Roboto',
            fontWeight: FontWeight.w600,
            color: isDarkMode ? Colors.white : theme.colorScheme.onSurface,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: reasonController,
              style: TextStyle(
                color: isDarkMode ? Colors.white : Colors.black87,
              ),
              decoration: InputDecoration(
                hintText: 'Enter reason for modification...',
                hintStyle: TextStyle(
                  color: isDarkMode
                      ? Colors.white.withOpacity(0.5)
                      : Colors.grey,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                filled: true,
                fillColor: isDarkMode
                    ? const Color(0xFF3C3C3E)
                    : theme.colorScheme.primary.withOpacity(0.05),
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
                color: isDarkMode
                    ? Colors.white.withOpacity(0.7)
                    : theme.colorScheme.onSurface,
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
    final isDarkMode = theme.brightness == Brightness.dark;
    final String fieldName = field.name;
    final String dataType = field.dataType.toString().split('.').last;

    bool isMandatory = field.isMandatory;
    final bool isPreviousReadingField =
        fieldName.startsWith('Previous Day Reading') ||
        fieldName.startsWith('Previous Month Reading');

    if (isPreviousReadingField && _isFirstDataEntryForThisBayFrequency) {
      isMandatory = false;
    }

    // 🔧 FIX: Updated read-only logic
    final bool isReadOnly =
        widget.forceReadOnly ||
        _isReadOnlyDueToExistingReading ||
        (widget.currentUser.role == UserRole.substationUser &&
            _existingLogsheetEntry != null) ||
        (isPreviousReadingField &&
            _existingLogsheetEntry == null &&
            _previousLogsheetEntry != null);

    final String? unit = field.unit;
    final List<String>? options = field.options?.cast<String>();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF2C2C2E) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: isDarkMode
                ? Colors.black.withOpacity(0.3)
                : Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
        // 🔧 FIX: Add border for read-only fields
        border: isReadOnly
            ? Border.all(color: Colors.grey.withOpacity(0.3), width: 1)
            : null,
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
          isDarkMode,
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
    bool isDarkMode,
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
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          fieldName + (isMandatory ? ' *' : ''),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: isDarkMode ? Colors.white : Colors.black87,
                          ),
                        ),
                      ),
                      // 🔧 FIX: Add read-only indicator
                      if (isReadOnly)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Read Only',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _readingTextFieldControllers.putIfAbsent(
                      fieldName,
                      () => TextEditingController(),
                    ),
                    readOnly: isReadOnly,
                    style: TextStyle(
                      color: isDarkMode ? Colors.white : Colors.black87,
                    ),
                    decoration: InputDecoration(
                      hintText: isReadOnly
                          ? 'Value saved'
                          : 'Enter ${fieldName.toLowerCase()}',
                      hintStyle: TextStyle(
                        color: isDarkMode
                            ? Colors.white.withOpacity(0.5)
                            : Colors.grey,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      filled: true,
                      fillColor: isReadOnly
                          ? (isDarkMode
                                ? const Color(0xFF3C3C3E)
                                : Colors.grey.shade100)
                          : (isDarkMode
                                ? const Color(0xFF3C3C3E)
                                : theme.colorScheme.primary.withOpacity(0.05)),
                      suffixText: unit,
                      prefixIcon: isReadOnly
                          ? Icon(
                              Icons.lock,
                              color: Colors.grey.shade600,
                              size: 16,
                            )
                          : null,
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
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          fieldName + (isMandatory ? ' *' : ''),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: isDarkMode ? Colors.white : Colors.black87,
                          ),
                        ),
                      ),
                      if (isReadOnly)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Read Only',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _readingTextFieldControllers.putIfAbsent(
                      fieldName,
                      () => TextEditingController(),
                    ),
                    readOnly: isReadOnly,
                    style: TextStyle(
                      color: isDarkMode ? Colors.white : Colors.black87,
                    ),
                    decoration: InputDecoration(
                      hintText: isReadOnly
                          ? 'Value saved'
                          : unit != null && unit.isNotEmpty
                          ? 'Enter value in $unit'
                          : 'Enter numerical value',
                      hintStyle: TextStyle(
                        color: isDarkMode
                            ? Colors.white.withOpacity(0.5)
                            : Colors.grey,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      filled: true,
                      fillColor: isReadOnly
                          ? (isDarkMode
                                ? const Color(0xFF3C3C3E)
                                : Colors.grey.shade100)
                          : (isDarkMode
                                ? const Color(0xFF3C3C3E)
                                : theme.colorScheme.primary.withOpacity(0.05)),
                      suffixText: unit,
                      prefixIcon: isReadOnly
                          ? Icon(
                              Icons.lock,
                              color: Colors.grey.shade600,
                              size: 16,
                            )
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
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              fieldName + (isMandatory ? ' *' : ''),
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: isDarkMode
                                    ? Colors.white
                                    : Colors.black87,
                              ),
                            ),
                          ),
                          if (isReadOnly)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.grey.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'Read Only',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey.shade600,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                        ],
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
                style: TextStyle(
                  color: isDarkMode ? Colors.white : Colors.black87,
                ),
                decoration: InputDecoration(
                  labelText: 'Description / Remarks (Optional)',
                  labelStyle: TextStyle(
                    color: isDarkMode
                        ? Colors.white.withOpacity(0.7)
                        : Colors.grey.shade700,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  filled: true,
                  fillColor: isDarkMode
                      ? const Color(0xFF3C3C3E)
                      : theme.colorScheme.primary.withOpacity(0.05),
                  prefixIcon: Icon(
                    isReadOnly ? Icons.lock : Icons.description,
                    color: isReadOnly ? Colors.grey : Colors.purple[700],
                    size: 16,
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
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          fieldName + (isMandatory ? ' *' : ''),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: isDarkMode ? Colors.white : Colors.black87,
                          ),
                        ),
                      ),
                      if (isReadOnly)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Read Only',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    currentDate == null
                        ? 'Select Date'
                        : DateFormat('yyyy-MM-dd').format(currentDate),
                    style: TextStyle(
                      fontSize: 14,
                      color: isDarkMode
                          ? Colors.white.withOpacity(0.6)
                          : theme.colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(
                isReadOnly ? Icons.lock : Icons.arrow_forward_ios,
                size: 16,
                color: isReadOnly
                    ? Colors.grey.shade600
                    : (isDarkMode ? Colors.white : Colors.black87),
              ),
              onPressed: isReadOnly
                  ? null
                  : () async {
                      final DateTime? picked = await showDatePicker(
                        context: context,
                        initialDate: currentDate ?? DateTime.now(),
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2101),
                        builder: (context, child) {
                          return Theme(
                            data: theme.copyWith(
                              colorScheme: theme.colorScheme.copyWith(
                                surface: isDarkMode
                                    ? const Color(0xFF2C2C2E)
                                    : Colors.white,
                                onSurface: isDarkMode
                                    ? Colors.white
                                    : Colors.black87,
                              ),
                              dialogBackgroundColor: isDarkMode
                                  ? const Color(0xFF2C2C2E)
                                  : Colors.white,
                            ),
                            child: child!,
                          );
                        },
                      );
                      if (picked != null) {
                        setState(
                          () => _readingDateFieldValues[fieldName] = picked,
                        );
                      }
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
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          fieldName + (isMandatory ? ' *' : ''),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: isDarkMode ? Colors.white : Colors.black87,
                          ),
                        ),
                      ),
                      if (isReadOnly)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Read Only',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: _readingDropdownFieldValues[fieldName],
                    dropdownColor: isDarkMode
                        ? const Color(0xFF2C2C2E)
                        : Colors.white,
                    style: TextStyle(
                      color: isDarkMode ? Colors.white : Colors.black,
                    ),
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      filled: true,
                      fillColor: isReadOnly
                          ? (isDarkMode
                                ? const Color(0xFF3C3C3E)
                                : Colors.grey.shade100)
                          : (isDarkMode
                                ? const Color(0xFF3C3C3E)
                                : theme.colorScheme.primary.withOpacity(0.05)),
                      prefixIcon: isReadOnly
                          ? Icon(
                              Icons.lock,
                              color: Colors.grey.shade600,
                              size: 16,
                            )
                          : null,
                    ),
                    items: options!
                        .map(
                          (option) => DropdownMenuItem<String>(
                            value: option,
                            child: Text(
                              option,
                              style: TextStyle(
                                color: isDarkMode ? Colors.white : Colors.black,
                              ),
                            ),
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
        fieldWidget = Text(
          'Unsupported data type: $dataType for $fieldName',
          style: TextStyle(color: isDarkMode ? Colors.white : Colors.black87),
        );
    }

    return fieldWidget;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin

    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    String slotTitle = DateFormat('dd.MMM.yyyy').format(widget.readingDate);
    if (widget.frequency == 'hourly' && widget.readingHour != null) {
      slotTitle += ' - ${widget.readingHour!.toString().padLeft(2, '0')}:00 Hr';
    } else if (widget.frequency == 'daily') {
      slotTitle += ' - Daily Reading';
    }

    // 🔧 FIX: Updated read-only logic
    final bool isReadOnlyView =
        widget.forceReadOnly ||
        _isReadOnlyDueToExistingReading ||
        (widget.currentUser.role == UserRole.substationUser &&
            _existingLogsheetEntry != null);

    return Scaffold(
      backgroundColor: isDarkMode
          ? const Color(0xFF1C1C1E)
          : const Color(0xFFFAFAFA),
      appBar: AppBar(
        backgroundColor: isDarkMode ? const Color(0xFF2C2C2E) : Colors.white,
        elevation: 0,
        title: Text(
          // 🔧 FIX: Dynamic title based on reading state
          _hasExistingReading
              ? 'View Reading Details'
              : _currentBay?.name ?? 'Reading Entry',
          style: TextStyle(
            color: isDarkMode ? Colors.white : theme.colorScheme.onSurface,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: isDarkMode ? Colors.white : theme.colorScheme.onSurface,
          ),
          onPressed: () => Navigator.pop(context, false),
        ),
        actions: [
          // 🔧 FIX: Enhanced status indicators
          if (_hasExistingReading)
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
                    'Completed',
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
          ? Center(
              child: Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: isDarkMode ? const Color(0xFF2C2C2E) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: isDarkMode
                          ? Colors.black.withOpacity(0.3)
                          : Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(
                      color: theme.colorScheme.primary,
                      strokeWidth: 3,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Loading from cache...',
                      style: TextStyle(
                        fontSize: 16,
                        color: isDarkMode ? Colors.white : Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
            )
          : Column(
              children: [
                // 🔧 FIX: Add warning banner for existing readings
                if (_hasExistingReading)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.green.shade700),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Reading Already Recorded',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.green.shade700,
                                ),
                              ),
                              if (_existingLogsheetEntry != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  'Recorded on ${DateFormat('dd MMM yyyy, HH:mm').format(_existingLogsheetEntry!.recordedAt.toDate())}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.green.shade600,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                // Header
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  margin: EdgeInsets.fromLTRB(
                    16,
                    _hasExistingReading ? 0 : 16,
                    16,
                    16,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isDarkMode
                          ? [
                              theme.colorScheme.primary.withOpacity(0.2),
                              theme.colorScheme.secondary.withOpacity(0.2),
                            ]
                          : [
                              theme.colorScheme.primaryContainer.withOpacity(
                                0.3,
                              ),
                              theme.colorScheme.secondaryContainer.withOpacity(
                                0.3,
                              ),
                            ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
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
                                    color: isDarkMode
                                        ? Colors.white.withOpacity(0.7)
                                        : theme.colorScheme.onSurface
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
                            color: isDarkMode
                                ? const Color(0xFF2C2C2E)
                                : Colors.white,
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
                                  color: isDarkMode
                                      ? Colors.white.withOpacity(0.4)
                                      : Colors.grey.shade400,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No Reading Fields Available',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    color: isDarkMode
                                        ? Colors.white.withOpacity(0.6)
                                        : Colors.grey.shade600,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'No ${widget.frequency.toLowerCase()} reading fields are defined for this slot.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: isDarkMode
                                        ? Colors.white.withOpacity(0.5)
                                        : Colors.grey.shade600,
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
                                1,
                            itemBuilder: (context, index) {
                              if (index == _filteredReadingFields.length) {
                                if (isReadOnlyView && !_hasExistingReading) {
                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: isDarkMode
                                          ? Colors.blue.shade800.withOpacity(
                                              0.3,
                                            )
                                          : Colors.blue.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: Colors.blue.withOpacity(0.3),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.info_outline,
                                          color: isDarkMode
                                              ? Colors.blue.shade300
                                              : Colors.blue.shade700,
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
                                              color: isDarkMode
                                                  ? Colors.blue.shade300
                                                  : Colors.blue.shade700,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                } else {
                                  return const SizedBox(height: 100);
                                }
                              } else if (index ==
                                  _filteredReadingFields.length + 1) {
                                return const SizedBox(height: 100);
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
      // 🔧 FIX: Don't show save button for existing readings unless user has permission
      floatingActionButton:
          !isReadOnlyView &&
              !_isReadOnlyDueToExistingReading &&
              _filteredReadingFields.isNotEmpty
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
                    ? 'Save Reading'
                    : 'Update Reading',
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
