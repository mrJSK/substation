// lib/screens/bay_readings_status_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:collection/collection.dart';
import '../../models/bay_model.dart';
import '../../models/user_model.dart';
import '../../models/reading_models.dart';
import '../../models/logsheet_models.dart';
import '../../utils/snackbar_utils.dart';
import 'logsheet_entry_screen.dart';

// Enhanced Equipment Icon Widget
class _EquipmentIcon extends StatelessWidget {
  final String bayType;
  final Color color;
  final double size;

  const _EquipmentIcon({
    required this.bayType,
    required this.color,
    this.size = 24.0,
  });

  @override
  Widget build(BuildContext context) {
    IconData iconData;
    switch (bayType.toLowerCase()) {
      case 'transformer':
        iconData = Icons.electrical_services;
        break;
      case 'feeder':
        iconData = Icons.power;
        break;
      case 'line':
        iconData = Icons.power_input;
        break;
      case 'busbar':
        iconData = Icons.horizontal_rule;
        break;
      case 'capacitor bank':
        iconData = Icons.battery_charging_full;
        break;
      case 'reactor':
        iconData = Icons.device_hub;
        break;
      default:
        iconData = Icons.electrical_services;
        break;
    }

    return Icon(iconData, size: size, color: color);
  }
}

class BayReadingsStatusScreen extends StatefulWidget {
  final String substationId;
  final String substationName;
  final AppUser currentUser;
  final String frequencyType;
  final DateTime selectedDate;
  final int? selectedHour;

  const BayReadingsStatusScreen({
    super.key,
    required this.substationId,
    required this.substationName,
    required this.currentUser,
    required this.frequencyType,
    required this.selectedDate,
    this.selectedHour,
  });

  @override
  State<BayReadingsStatusScreen> createState() =>
      _BayReadingsStatusScreenState();
}

// **KEY FIX: Add AutomaticKeepAliveClientMixin**
class _BayReadingsStatusScreenState extends State<BayReadingsStatusScreen>
    with AutomaticKeepAliveClientMixin {
  // **KEY FIX: Override wantKeepAlive**
  @override
  bool get wantKeepAlive => true;

  bool _isLoading = true;
  List<Bay> _baysInSubstation = [];
  final Map<String, bool> _bayCompletionStatus = {};
  Map<String, List<ReadingField>> _bayMandatoryFields = {};
  Map<String, List<LogsheetEntry>> _logsheetEntriesForSlot = {};

  // **KEY FIX: Add data initialization tracking**
  bool _isDataInitialized = false;
  String? _lastLoadedCacheKey;

  // Cache variables for efficiency
  Map<String, Bay> _preLoadedBays = {};
  static final Map<String, dynamic> _cache = {};

  @override
  void initState() {
    super.initState();
    _initializeDataOnce();
  }

  // **KEY FIX: Generate cache key for this specific screen instance**
  String get _cacheKey =>
      '${widget.substationId}_${widget.frequencyType}_${widget.selectedDate.toIso8601String().split('T')[0]}_${widget.selectedHour ?? 'daily'}';

  // **KEY FIX: Prevent multiple Firebase calls**
  Future<void> _initializeDataOnce() async {
    if (_isDataInitialized && _lastLoadedCacheKey == _cacheKey) {
      // Data already loaded for this exact screen configuration
      return;
    }

    // Check cache first
    if (_loadFromCache()) {
      _isDataInitialized = true;
      _lastLoadedCacheKey = _cacheKey;
      return;
    }

    await _loadDataAndCalculateStatuses();
    _isDataInitialized = true;
    _lastLoadedCacheKey = _cacheKey;
  }

  bool _loadFromCache() {
    final cachedData = _cache[_cacheKey];
    if (cachedData != null &&
        DateTime.now().difference(cachedData['timestamp']).inMinutes < 5) {
      setState(() {
        _baysInSubstation = List<Bay>.from(cachedData['baysInSubstation']);
        _bayCompletionStatus.clear();
        _bayCompletionStatus.addAll(
          Map<String, bool>.from(cachedData['bayCompletionStatus']),
        );
        _bayMandatoryFields = Map<String, List<ReadingField>>.from(
          cachedData['bayMandatoryFields'],
        );
        _logsheetEntriesForSlot = Map<String, List<LogsheetEntry>>.from(
          cachedData['logsheetEntriesForSlot'],
        );
        _preLoadedBays = Map<String, Bay>.from(cachedData['preLoadedBays']);
        _isLoading = false;
      });
      return true;
    }
    return false;
  }

  void _saveToCache() {
    _cache[_cacheKey] = {
      'baysInSubstation': _baysInSubstation,
      'bayCompletionStatus': _bayCompletionStatus,
      'bayMandatoryFields': _bayMandatoryFields,
      'logsheetEntriesForSlot': _logsheetEntriesForSlot,
      'preLoadedBays': _preLoadedBays,
      'timestamp': DateTime.now(),
    };

    // Clean old cache entries (keep only last 10)
    if (_cache.length > 10) {
      final sortedKeys = _cache.keys.toList()..sort();
      final oldestKeys = sortedKeys.take(_cache.length - 10);
      for (final key in oldestKeys) {
        _cache.remove(key);
      }
    }
  }

  Future<void> _loadDataAndCalculateStatuses() async {
    setState(() {
      _isLoading = true;
      _bayCompletionStatus.clear();
      _baysInSubstation.clear();
      _bayMandatoryFields.clear();
      _logsheetEntriesForSlot.clear();
    });

    try {
      // **OPTIMIZATION: Load all data in optimized sequence**
      await _preLoadAllBays();
      await _loadBayAssignmentsOptimized();

      if (_baysInSubstation.isEmpty) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      await _loadLogsheetEntriesOptimized();
      _calculateCompletionStatuses();

      // Save to cache after successful load
      _saveToCache();
    } catch (e) {
      print("Error loading data for BayReadingsStatusScreen: $e");
      if (mounted) {
        SnackBarUtils.showSnackBar(
          context,
          'Failed to load data: $e',
          isError: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _preLoadAllBays() async {
    final baysSnapshot = await FirebaseFirestore.instance
        .collection('bays')
        .where('substationId', isEqualTo: widget.substationId)
        .orderBy('name')
        .get();

    _preLoadedBays = {
      for (var doc in baysSnapshot.docs) doc.id: Bay.fromFirestore(doc),
    };
  }

  Future<void> _loadBayAssignmentsOptimized() async {
    final List<String> allBayIds = _preLoadedBays.keys.toList();
    if (allBayIds.isEmpty) return;

    _bayMandatoryFields.clear();
    final List<String> assignedBayIds = [];

    // **OPTIMIZATION: Handle Firestore 'whereIn' limit of 10**
    final assignmentsSnapshot = await FirebaseFirestore.instance
        .collection('bayReadingAssignments')
        .where('bayId', whereIn: allBayIds.take(10).toList())
        .get();

    // If we have more than 10 bays, fetch the rest in batches
    if (allBayIds.length > 10) {
      for (int i = 10; i < allBayIds.length; i += 10) {
        final batch = allBayIds.skip(i).take(10).toList();
        final additionalSnapshot = await FirebaseFirestore.instance
            .collection('bayReadingAssignments')
            .where('bayId', whereIn: batch)
            .get();
        assignmentsSnapshot.docs.addAll(additionalSnapshot.docs);
      }
    }

    for (var doc in assignmentsSnapshot.docs) {
      final String bayId = doc['bayId'] as String;
      final assignedFieldsData = (doc.data() as Map)['assignedFields'] as List;

      final List<ReadingField> allFields = assignedFieldsData
          .map(
            (fieldMap) =>
                ReadingField.fromMap(fieldMap as Map<String, dynamic>),
          )
          .toList();

      final List<ReadingField> relevantMandatoryFields = allFields
          .where(
            (field) =>
                field.isMandatory &&
                field.frequency.toString().split('.').last ==
                    widget.frequencyType,
          )
          .toList();

      _bayMandatoryFields[bayId] = relevantMandatoryFields;
      if (relevantMandatoryFields.isNotEmpty) {
        assignedBayIds.add(bayId);
      }
    }

    _baysInSubstation = assignedBayIds.map((id) => _preLoadedBays[id]!).toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  Future<void> _loadLogsheetEntriesOptimized() async {
    _logsheetEntriesForSlot.clear();

    DateTime queryStartTimestamp;
    DateTime queryEndTimestamp;

    if (widget.frequencyType == 'hourly' && widget.selectedHour != null) {
      queryStartTimestamp = DateTime(
        widget.selectedDate.year,
        widget.selectedDate.month,
        widget.selectedDate.day,
        widget.selectedHour!,
      );
      queryEndTimestamp = DateTime(
        widget.selectedDate.year,
        widget.selectedDate.month,
        widget.selectedDate.day,
        widget.selectedHour!,
        59,
        59,
        999,
      );
    } else {
      queryStartTimestamp = DateTime(
        widget.selectedDate.year,
        widget.selectedDate.month,
        widget.selectedDate.day,
      );
      queryEndTimestamp = DateTime(
        widget.selectedDate.year,
        widget.selectedDate.month,
        widget.selectedDate.day,
        23,
        59,
        59,
        999,
      );
    }

    // **OPTIMIZATION: Single query to get all relevant logsheet entries**
    final logsheetsSnapshot = await FirebaseFirestore.instance
        .collection('logsheetEntries')
        .where('substationId', isEqualTo: widget.substationId)
        .where('frequency', isEqualTo: widget.frequencyType)
        .where(
          'readingTimestamp',
          isGreaterThanOrEqualTo: Timestamp.fromDate(queryStartTimestamp),
        )
        .where(
          'readingTimestamp',
          isLessThanOrEqualTo: Timestamp.fromDate(queryEndTimestamp),
        )
        .get();

    for (var doc in logsheetsSnapshot.docs) {
      final entry = LogsheetEntry.fromFirestore(doc);
      _logsheetEntriesForSlot.putIfAbsent(entry.bayId, () => []).add(entry);
    }
  }

  void _calculateCompletionStatuses() {
    _bayCompletionStatus.clear();
    for (var bay in _baysInSubstation) {
      final bool isBayCompleteForSlot = _isBayLogsheetCompleteForSlot(bay.id);
      _bayCompletionStatus[bay.id] = isBayCompleteForSlot;
    }
  }

  bool _isBayLogsheetCompleteForSlot(String bayId) {
    final List<ReadingField> mandatoryFields = _bayMandatoryFields[bayId] ?? [];
    if (mandatoryFields.isEmpty) {
      return true;
    }

    final relevantLogsheet = (_logsheetEntriesForSlot[bayId] ?? [])
        .firstWhereOrNull((entry) {
          final entryTimestamp = entry.readingTimestamp.toDate();
          if (widget.frequencyType == 'hourly' && widget.selectedHour != null) {
            return entryTimestamp.year == widget.selectedDate.year &&
                entryTimestamp.month == widget.selectedDate.month &&
                entryTimestamp.day == widget.selectedDate.day &&
                entryTimestamp.hour == widget.selectedHour;
          } else if (widget.frequencyType == 'daily') {
            return entryTimestamp.year == widget.selectedDate.year &&
                entryTimestamp.month == widget.selectedDate.month &&
                entryTimestamp.day == widget.selectedDate.day;
          }
          return false;
        });

    if (relevantLogsheet == null) {
      return false;
    }

    return mandatoryFields.every((field) {
      final value = relevantLogsheet.values[field.name];
      if (field.dataType ==
              ReadingFieldDataType.boolean.toString().split('.').last &&
          value is Map &&
          value.containsKey('value')) {
        return value['value'] != null;
      }
      return value != null && (value is! String || value.isNotEmpty);
    });
  }

  // **KEY FIX: Method to refresh specific bay status**
  Future<void> _refreshBayStatus(String bayId) async {
    try {
      // Reload logsheet entries for this specific bay
      DateTime queryStartTimestamp;
      DateTime queryEndTimestamp;

      if (widget.frequencyType == 'hourly' && widget.selectedHour != null) {
        queryStartTimestamp = DateTime(
          widget.selectedDate.year,
          widget.selectedDate.month,
          widget.selectedDate.day,
          widget.selectedHour!,
        );
        queryEndTimestamp = DateTime(
          widget.selectedDate.year,
          widget.selectedDate.month,
          widget.selectedDate.day,
          widget.selectedHour!,
          59,
          59,
          999,
        );
      } else {
        queryStartTimestamp = DateTime(
          widget.selectedDate.year,
          widget.selectedDate.month,
          widget.selectedDate.day,
        );
        queryEndTimestamp = DateTime(
          widget.selectedDate.year,
          widget.selectedDate.month,
          widget.selectedDate.day,
          23,
          59,
          59,
          999,
        );
      }

      final logsheetsSnapshot = await FirebaseFirestore.instance
          .collection('logsheetEntries')
          .where('bayId', isEqualTo: bayId)
          .where('frequency', isEqualTo: widget.frequencyType)
          .where(
            'readingTimestamp',
            isGreaterThanOrEqualTo: Timestamp.fromDate(queryStartTimestamp),
          )
          .where(
            'readingTimestamp',
            isLessThanOrEqualTo: Timestamp.fromDate(queryEndTimestamp),
          )
          .get();

      // Update only this bay's data
      _logsheetEntriesForSlot[bayId] = logsheetsSnapshot.docs
          .map((doc) => LogsheetEntry.fromFirestore(doc))
          .toList();

      // Recalculate completion status for this bay
      final bool isBayCompleteForSlot = _isBayLogsheetCompleteForSlot(bayId);

      setState(() {
        _bayCompletionStatus[bayId] = isBayCompleteForSlot;
      });

      // Update cache
      _saveToCache();
    } catch (e) {
      print('Error refreshing bay status: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    // **KEY FIX: Call super.build for AutomaticKeepAliveClientMixin**
    super.build(context);

    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    String slotTitle = DateFormat('dd.MMM.yyyy').format(widget.selectedDate);
    if (widget.frequencyType == 'hourly' && widget.selectedHour != null) {
      slotTitle +=
          ' - ${widget.selectedHour!.toString().padLeft(2, '0')}:00 Hr';
    } else if (widget.frequencyType == 'daily') {
      slotTitle += ' - Daily Reading';
    }

    // Calculate completion stats
    int completedBays = _bayCompletionStatus.values
        .where((status) => status)
        .length;
    int totalBays = _baysInSubstation.length;
    double completionPercentage = totalBays > 0
        ? (completedBays / totalBays) * 100
        : 0;

    return Scaffold(
      backgroundColor: isDarkMode
          ? const Color(0xFF1C1C1E)
          : const Color(0xFFFAFAFA),
      appBar: AppBar(
        backgroundColor: isDarkMode ? const Color(0xFF2C2C2E) : Colors.white,
        elevation: 0,
        title: Text(
          'Bay Status',
          style: TextStyle(
            color: isDarkMode ? Colors.white : Colors.black87,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: isDarkMode ? Colors.white : Colors.black87,
          ),
          onPressed: () => Navigator.pop(
            context,
            true,
          ), // Return true to indicate potential changes
        ),
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
                    CircularProgressIndicator(color: theme.colorScheme.primary),
                    const SizedBox(height: 16),
                    Text(
                      'Loading bay status...',
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
                // Header with slot info and completion stats
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.all(16),
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
                            child: Icon(
                              widget.frequencyType == 'hourly'
                                  ? Icons.access_time
                                  : Icons.calendar_today,
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
                      const SizedBox(height: 16),
                      // Completion Stats
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDarkMode
                              ? const Color(0xFF2C2C2E)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isDarkMode
                                ? Colors.grey.shade700
                                : theme.colorScheme.outline.withOpacity(0.2),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                children: [
                                  Text(
                                    '$completedBays/$totalBays',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w700,
                                      color: completedBays == totalBays
                                          ? Colors.green
                                          : Colors.orange,
                                    ),
                                  ),
                                  Text(
                                    'Completed',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDarkMode
                                          ? Colors.white.withOpacity(0.6)
                                          : theme.colorScheme.onSurface
                                                .withOpacity(0.6),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              width: 1,
                              height: 40,
                              color: isDarkMode
                                  ? Colors.grey.shade700
                                  : theme.colorScheme.outline.withOpacity(0.2),
                            ),
                            Expanded(
                              child: Column(
                                children: [
                                  Text(
                                    '${completionPercentage.toInt()}%',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w700,
                                      color: completionPercentage == 100
                                          ? Colors.green
                                          : Colors.orange,
                                    ),
                                  ),
                                  Text(
                                    'Progress',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDarkMode
                                          ? Colors.white.withOpacity(0.6)
                                          : theme.colorScheme.onSurface
                                                .withOpacity(0.6),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Bay list
                Expanded(
                  child: _baysInSubstation.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32.0),
                            child: Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: isDarkMode
                                    ? const Color(0xFF2C2C2E)
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(16),
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
                                mainAxisSize: MainAxisSize.min,
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
                                    'No Assigned Bays Found',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                      color: isDarkMode
                                          ? Colors.white.withOpacity(0.7)
                                          : Colors.grey.shade600,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'No bays with assigned readings found for ${widget.substationName} for this frequency and date. Please assign reading templates to bays in Asset Management.',
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
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          itemCount: _baysInSubstation.length,
                          itemBuilder: (context, index) {
                            final bay = _baysInSubstation[index];
                            final bool isBayCompleteForSlot =
                                _bayCompletionStatus[bay.id] ?? false;
                            final int mandatoryFieldsCount =
                                _bayMandatoryFields[bay.id]?.length ?? 0;

                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              decoration: BoxDecoration(
                                color: isDarkMode
                                    ? const Color(0xFF2C2C2E)
                                    : Colors.white,
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
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.all(16),
                                leading: Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color:
                                        (isBayCompleteForSlot
                                                ? Colors.green
                                                : Colors.red)
                                            .withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color:
                                          (isBayCompleteForSlot
                                                  ? Colors.green
                                                  : Colors.red)
                                              .withOpacity(0.3),
                                    ),
                                  ),
                                  child: Icon(
                                    isBayCompleteForSlot
                                        ? Icons.check_circle
                                        : Icons.cancel,
                                    color: isBayCompleteForSlot
                                        ? Colors.green
                                        : Colors.red,
                                    size: 24,
                                  ),
                                ),
                                title: Row(
                                  children: [
                                    _EquipmentIcon(
                                      bayType: bay.bayType,
                                      color: theme.colorScheme.primary,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        bay.name,
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: isDarkMode
                                              ? Colors.white
                                              : Colors.black87,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 4),
                                    Text(
                                      '${bay.voltageLevel} ${bay.bayType}',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: isDarkMode
                                            ? Colors.white.withOpacity(0.6)
                                            : theme.colorScheme.onSurface
                                                  .withOpacity(0.6),
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        Container(
                                          width: 8,
                                          height: 8,
                                          decoration: BoxDecoration(
                                            color: isBayCompleteForSlot
                                                ? Colors.green
                                                : Colors.red,
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          isBayCompleteForSlot
                                              ? 'Readings complete'
                                              : 'Readings incomplete',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: isBayCompleteForSlot
                                                ? Colors.green.shade600
                                                : Colors.red.shade600,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        const Spacer(),
                                        Text(
                                          '$mandatoryFieldsCount fields',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: isDarkMode
                                                ? Colors.white.withOpacity(0.5)
                                                : theme.colorScheme.onSurface
                                                      .withOpacity(0.5),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                trailing: Icon(
                                  Icons.arrow_forward_ios,
                                  color: theme.colorScheme.primary,
                                  size: 16,
                                ),
                                onTap: () {
                                  Navigator.of(context)
                                      .push(
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              LogsheetEntryScreen(
                                                substationId:
                                                    widget.substationId,
                                                substationName:
                                                    widget.substationName,
                                                bayId: bay.id,
                                                readingDate:
                                                    widget.selectedDate,
                                                frequency: widget.frequencyType,
                                                readingHour:
                                                    widget.selectedHour,
                                                currentUser: widget.currentUser,
                                              ),
                                        ),
                                      )
                                      .then((result) {
                                        // **KEY FIX: Only refresh this specific bay**
                                        if (result == true) {
                                          _refreshBayStatus(bay.id);
                                        }
                                      });
                                },
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}
