import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/user_model.dart';
import '../../models/enhanced_bay_data.dart';
import '../../services/comprehensive_cache_service.dart';
import '../../utils/snackbar_utils.dart';
import 'logsheet_entry_screen.dart';

class SubstationUserEnergyTab extends StatefulWidget {
  final String substationId;
  final String substationName;
  final AppUser currentUser;
  final DateTime selectedDate;

  const SubstationUserEnergyTab({
    super.key,
    required this.substationId,
    required this.substationName,
    required this.currentUser,
    required this.selectedDate,
  });

  @override
  State<SubstationUserEnergyTab> createState() =>
      _SubstationUserEnergyTabState();
}

class _SubstationUserEnergyTabState extends State<SubstationUserEnergyTab>
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final ComprehensiveCacheService _cache = ComprehensiveCacheService();

  bool _isLoading = true;
  bool _isDailyReadingAvailable = false;
  List<EnhancedBayData> _baysWithDailyAssignments = [];
  bool _hasAnyBaysWithReadings = false;
  late AnimationController _animationController;

  // 🔧 FIX: Enhanced state tracking
  Map<String, bool> _bayCompletionStatus = {};
  Map<String, bool> _bayEnergyCompletionStatus = {};
  Map<String, int> _bayMandatoryFieldsCount = {};
  Map<String, Map<String, dynamic>> _bayLastReadings = {};
  bool _cacheHealthy = false;
  String? _cacheError;

  static const List<String> REQUIRED_ENERGY_FIELDS = [
    'Current Day Reading (Import)',
    'Previous Day Reading (Import)',
    'Current Day Reading (Export)',
    'Previous Day Reading (Export)',
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _loadEnergyData();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(SubstationUserEnergyTab oldWidget) {
    super.didUpdateWidget(oldWidget);

    final bool shouldReload =
        oldWidget.substationId != widget.substationId ||
        !DateUtils.isSameDay(oldWidget.selectedDate, widget.selectedDate);

    if (shouldReload) {
      _loadEnergyData();
    }
  }

  // 🔧 FIX: Enhanced data loading with better error handling
  Future<void> _loadEnergyData() async {
    if (widget.substationId.isEmpty) {
      setState(() {
        _isLoading = false;
        _isDailyReadingAvailable = false;
        _hasAnyBaysWithReadings = false;
        _cacheHealthy = false;
        _cacheError = 'No substation selected';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _cacheError = null;
    });

    try {
      if (!_cache.isInitialized) {
        throw Exception('Cache not initialized - please restart the app');
      }

      // 🔧 FIX: Validate cache health before proceeding
      if (!_cache.validateCache()) {
        throw Exception('Cache validation failed - data may be stale');
      }

      _baysWithDailyAssignments = _cache.getBaysWithReadings('daily');
      _hasAnyBaysWithReadings = _baysWithDailyAssignments.isNotEmpty;
      _cacheHealthy = true;

      if (!_hasAnyBaysWithReadings) {
        setState(() {
          _isLoading = false;
          _isDailyReadingAvailable = false;
        });
        return;
      }

      // 🔧 FIX: Enhanced availability check
      final DateTime now = DateTime.now();
      final bool isToday = DateUtils.isSameDay(widget.selectedDate, now);
      final bool isFutureDate = widget.selectedDate.isAfter(now);

      // Don't allow readings for future dates
      if (isFutureDate) {
        setState(() {
          _isDailyReadingAvailable = false;
          _cacheError = 'Cannot enter readings for future dates';
        });
        return;
      }

      // Daily readings are available after 8 AM for today, always available for past dates
      _isDailyReadingAvailable = !isToday || now.hour >= 8;

      if (_isDailyReadingAvailable) {
        _checkDailyReadingCompletion();
        _loadLastReadingsForAutoPopulate();
      }

      _animationController.forward();

      print(
        '✅ Energy tab loaded ${_baysWithDailyAssignments.length} bays from cache',
      );
    } catch (e) {
      print('❌ Error loading energy data from cache: $e');
      setState(() {
        _cacheHealthy = false;
        _cacheError = e.toString();
      });

      if (mounted) {
        SnackBarUtils.showSnackBar(
          context,
          'Error loading energy data: $e',
          isError: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // 🔧 FIX: Enhanced completion checking with validation
  void _checkDailyReadingCompletion() {
    _bayCompletionStatus.clear();
    _bayEnergyCompletionStatus.clear();
    _bayMandatoryFieldsCount.clear();

    for (var bayData in _baysWithDailyAssignments) {
      final mandatoryFields = bayData.getReadingFields(
        'daily',
        mandatoryOnly: true,
      );
      _bayMandatoryFieldsCount[bayData.id] = mandatoryFields.length;

      final entry = bayData.getReading(widget.selectedDate, 'daily');
      bool isComplete = entry != null;
      bool hasEnergyReadings = false;

      if (isComplete) {
        // Validate energy fields more thoroughly
        hasEnergyReadings = REQUIRED_ENERGY_FIELDS.every((fieldName) {
          final value = entry.values[fieldName];
          if (value == null) return false;
          final stringValue = value.toString().trim();
          if (stringValue.isEmpty) return false;
          final numValue = double.tryParse(stringValue);
          return numValue != null && numValue >= 0;
        });

        // Additional validation: ensure import/export values are logical
        if (hasEnergyReadings) {
          final currentImport = double.tryParse(
            entry.values['Current Day Reading (Import)']?.toString() ?? '',
          );
          final previousImport = double.tryParse(
            entry.values['Previous Day Reading (Import)']?.toString() ?? '',
          );
          final currentExport = double.tryParse(
            entry.values['Current Day Reading (Export)']?.toString() ?? '',
          );
          final previousExport = double.tryParse(
            entry.values['Previous Day Reading (Export)']?.toString() ?? '',
          );

          // Validate that current readings are not less than previous readings (unless meter reset)
          if (currentImport != null &&
              previousImport != null &&
              currentImport < previousImport) {
            print(
              '⚠️ Warning: Current import reading less than previous for bay ${bayData.name}',
            );
          }
          if (currentExport != null &&
              previousExport != null &&
              currentExport < previousExport) {
            print(
              '⚠️ Warning: Current export reading less than previous for bay ${bayData.name}',
            );
          }
        }
      }

      _bayCompletionStatus[bayData.id] = isComplete;
      _bayEnergyCompletionStatus[bayData.id] = hasEnergyReadings;
    }
  }

  // 🔧 FIX: Enhanced auto-populate with error handling
  void _loadLastReadingsForAutoPopulate() {
    _bayLastReadings.clear();

    final previousDay = widget.selectedDate.subtract(const Duration(days: 1));

    for (var bayData in _baysWithDailyAssignments) {
      try {
        final yesterdayEntry = bayData.getReading(previousDay, 'daily');
        if (yesterdayEntry != null) {
          final importReading =
              yesterdayEntry.values['Current Day Reading (Import)'];
          final exportReading =
              yesterdayEntry.values['Current Day Reading (Export)'];

          // Only add if both readings are valid numbers
          if (importReading != null && exportReading != null) {
            final importValue = double.tryParse(importReading.toString());
            final exportValue = double.tryParse(exportReading.toString());

            if (importValue != null && exportValue != null) {
              _bayLastReadings[bayData.id] = {
                'Previous Day Reading (Import)': importReading,
                'Previous Day Reading (Export)': exportReading,
                'lastReadingDate': DateFormat(
                  'dd-MMM-yyyy',
                ).format(previousDay),
                'validatedValues': true,
              };
            }
          }
        }
      } catch (e) {
        print('❌ Error loading auto-populate data for bay ${bayData.name}: $e');
      }
    }
  }

  // 🔧 FIX: Enhanced refresh with cache synchronization
  Future<void> _refreshBayStatus(String bayId) async {
    try {
      // Force refresh the specific bay data
      await _cache.refreshBayData(bayId);

      final bayData = _cache.getBayById(bayId);
      if (bayData == null) {
        print('⚠️ Bay data not found after refresh: $bayId');
        return;
      }

      final entry = bayData.getReading(widget.selectedDate, 'daily');
      bool isComplete = entry != null;
      bool hasEnergyReadings = false;

      if (isComplete) {
        hasEnergyReadings = REQUIRED_ENERGY_FIELDS.every((fieldName) {
          final value = entry.values[fieldName];
          if (value == null) return false;
          final stringValue = value.toString().trim();
          if (stringValue.isEmpty) return false;
          final numValue = double.tryParse(stringValue);
          return numValue != null && numValue >= 0;
        });
      }

      setState(() {
        _bayCompletionStatus[bayId] = isComplete;
        _bayEnergyCompletionStatus[bayId] = hasEnergyReadings;
      });

      print(
        '✅ Bay status refreshed: $bayId - Complete: $isComplete, Energy: $hasEnergyReadings',
      );
    } catch (e) {
      print('❌ Error refreshing bay status: $e');
    }
  }

  // 🔧 FIX: Enhanced validation with detailed feedback
  Future<bool> validateEnergyDataForCalculation() async {
    final List<String> incompleteBays = [];
    final List<String> invalidDataBays = [];

    for (var bayData in _baysWithDailyAssignments) {
      final hasEnergyReadings = _bayEnergyCompletionStatus[bayData.id] ?? false;

      if (!hasEnergyReadings) {
        incompleteBays.add(bayData.name);
      } else {
        // Additional validation for data integrity
        final entry = bayData.getReading(widget.selectedDate, 'daily');
        if (entry != null) {
          final currentImport = double.tryParse(
            entry.values['Current Day Reading (Import)']?.toString() ?? '',
          );
          final previousImport = double.tryParse(
            entry.values['Previous Day Reading (Import)']?.toString() ?? '',
          );

          if (currentImport != null && previousImport != null) {
            final consumption = currentImport - previousImport;
            // Flag unusually high consumption (>10000 units per day) for review
            if (consumption > 10000) {
              invalidDataBays.add(
                '${bayData.name} (High consumption: ${consumption.toStringAsFixed(2)})',
              );
            }
          }
        }
      }
    }

    if (incompleteBays.isNotEmpty) {
      SnackBarUtils.showSnackBar(
        context,
        'Energy calculation incomplete. Missing readings: ${incompleteBays.join(', ')}',
        isError: true,
      );
      return false;
    }

    if (invalidDataBays.isNotEmpty) {
      // Show warning but don't prevent calculation
      SnackBarUtils.showSnackBar(
        context,
        'Warning: Unusual readings detected: ${invalidDataBays.join(', ')}',
        isError: false,
      );
    }

    SnackBarUtils.showSnackBar(
      context,
      'All energy readings validated and ready for calculation!',
    );
    return true;
  }

  // 🔧 FIX: Enhanced bay card with better status indicators
  Widget _buildBayCard(EnhancedBayData bayData, int index) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final bool isComplete = _bayCompletionStatus[bayData.id] ?? false;
    final bool hasEnergyReadings =
        _bayEnergyCompletionStatus[bayData.id] ?? false;
    final int mandatoryFields = _bayMandatoryFieldsCount[bayData.id] ?? 0;
    final bool hasLastReading = _bayLastReadings.containsKey(bayData.id);

    // 🔧 FIX: Check if reading already exists to prevent duplicate entry
    final bool hasExistingReading = _cache.hasReadingForDate(
      bayData.id,
      widget.selectedDate,
      'daily',
    );

    Color statusColor = hasEnergyReadings
        ? Colors.green
        : (isComplete ? Colors.blue : Colors.orange);
    IconData statusIcon = hasEnergyReadings
        ? Icons.check_circle
        : (isComplete ? Icons.assignment_turned_in : Icons.pending);
    String statusText = hasEnergyReadings
        ? 'Energy Complete'
        : (isComplete ? 'Basic Complete' : 'Pending');

    // Override for existing readings
    if (hasExistingReading && !hasEnergyReadings) {
      statusColor = Colors.amber;
      statusIcon = Icons.warning;
      statusText = 'Needs Review';
    }

    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return SlideTransition(
          position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
              .animate(
                CurvedAnimation(
                  parent: _animationController,
                  curve: Interval(index * 0.1, 1.0, curve: Curves.easeOut),
                ),
              ),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
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
              border: Border.all(
                color: statusColor.withOpacity(0.3),
                width: hasExistingReading ? 2 : 1,
              ),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: _isDailyReadingAvailable
                    ? () {
                        // 🔧 FIX: Handle existing readings appropriately
                        if (hasExistingReading &&
                            !_canModifyExistingReading()) {
                          _showReadingExistsDialog(bayData);
                        } else {
                          _navigateToReadingEntry(bayData);
                        }
                      }
                    : null,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              _getBayTypeIcon(bayData.bayType),
                              color: statusColor,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  bayData.name,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: isDarkMode
                                        ? Colors.white
                                        : Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Voltage Level: ${bayData.voltageLevel}',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: isDarkMode
                                        ? Colors.white.withOpacity(0.6)
                                        : theme.colorScheme.onSurface
                                              .withOpacity(0.6),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.assignment,
                                      size: 16,
                                      color: isDarkMode
                                          ? Colors.white.withOpacity(0.6)
                                          : theme.colorScheme.onSurface
                                                .withOpacity(0.6),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '$mandatoryFields mandatory fields',
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
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: statusColor.withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(statusIcon, size: 14, color: statusColor),
                                const SizedBox(width: 4),
                                Text(
                                  statusText,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: statusColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (_isDailyReadingAvailable) ...[
                            const SizedBox(width: 12),
                            Icon(
                              hasExistingReading
                                  ? Icons.visibility
                                  : Icons.arrow_forward_ios,
                              color: theme.colorScheme.primary,
                              size: 16,
                            ),
                          ],
                        ],
                      ),

                      // 🔧 FIX: Enhanced status indicators
                      if (hasExistingReading) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.green.withOpacity(0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.check_circle,
                                size: 16,
                                color: Colors.green.shade700,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  hasEnergyReadings
                                      ? 'Reading completed with all energy values'
                                      : 'Basic reading completed - energy values may need review',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.green.shade700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ] else if (hasLastReading && !isComplete) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isDarkMode
                                ? Colors.blue.shade800.withOpacity(0.3)
                                : Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isDarkMode
                                  ? Colors.blue.shade400
                                  : Colors.blue.shade200,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.auto_awesome,
                                size: 16,
                                color: isDarkMode
                                    ? Colors.blue.shade300
                                    : Colors.blue.shade700,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Previous readings will be auto-populated from ${_bayLastReadings[bayData.id]!['lastReadingDate']}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDarkMode
                                        ? Colors.blue.shade300
                                        : Colors.blue.shade700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
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

  // 🔧 FIX: Show dialog for existing readings
  Future<void> _showReadingExistsDialog(EnhancedBayData bayData) async {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: isDarkMode ? const Color(0xFF2C2C2E) : Colors.white,
        title: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 24),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Reading Already Exists',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: isDarkMode ? Colors.white : Colors.black87,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'A reading for ${bayData.name} has already been recorded for ${DateFormat('dd MMM yyyy').format(widget.selectedDate)}.',
              style: TextStyle(
                fontSize: 14,
                color: isDarkMode
                    ? Colors.white.withOpacity(0.8)
                    : Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'You can view the reading details.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: isDarkMode ? Colors.white70 : Colors.grey.shade600,
              ),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _navigateToReadingEntry(bayData, forceReadOnly: true);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: theme.colorScheme.onPrimary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            icon: Icon(Icons.visibility, size: 18),
            label: Text('View Details'),
          ),
        ],
      ),
    );
  }

  // 🔧 FIX: Centralized navigation logic
  void _navigateToReadingEntry(
    EnhancedBayData bayData, {
    bool forceReadOnly = false,
  }) {
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (context) => LogsheetEntryScreen(
              substationId: widget.substationId,
              substationName: widget.substationName,
              bayId: bayData.id,
              readingDate: widget.selectedDate,
              frequency: 'daily',
              readingHour: null,
              currentUser: widget.currentUser,
              forceReadOnly: forceReadOnly,
              autoPopulateData: _bayLastReadings[bayData.id],
            ),
          ),
        )
        .then((result) {
          if (result == true) {
            _refreshBayStatus(bayData.id);
          }
        });
  }

  IconData _getBayTypeIcon(String bayType) {
    switch (bayType.toLowerCase()) {
      case 'transformer':
        return Icons.electrical_services;
      case 'feeder':
        return Icons.power;
      case 'line':
        return Icons.power_input;
      case 'busbar':
        return Icons.horizontal_rule;
      case 'capacitor bank':
        return Icons.battery_charging_full;
      case 'reactor':
        return Icons.device_hub;
      default:
        return Icons.electrical_services;
    }
  }

  // 🔧 FIX: Enhanced header with better status tracking
  Widget _buildHeader() {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final int completedBays = _bayCompletionStatus.values
        .where((status) => status)
        .length;
    final int energyCompleteBays = _bayEnergyCompletionStatus.values
        .where((status) => status)
        .length;
    final int totalBays = _baysWithDailyAssignments.length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode
            ? theme.colorScheme.secondary.withOpacity(0.2)
            : theme.colorScheme.secondaryContainer.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.secondary.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.secondary.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.electrical_services,
                  color: theme.colorScheme.secondary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Daily Energy Readings',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.secondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      DateFormat(
                        'EEEE, dd MMMM yyyy',
                      ).format(widget.selectedDate),
                      style: TextStyle(
                        fontSize: 14,
                        color: isDarkMode
                            ? Colors.white.withOpacity(0.7)
                            : theme.colorScheme.onSurface.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
              if (_cacheHealthy)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.offline_bolt, size: 10, color: Colors.green),
                      const SizedBox(width: 2),
                      Text(
                        'LIVE',
                        style: TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.w600,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          if (_isDailyReadingAvailable && totalBays > 0) ...[
            const SizedBox(height: 16),
            // FIX: Combined single progress indicator instead of two
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDarkMode ? const Color(0xFF3C3C3E) : Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: energyCompleteBays == totalBays
                      ? Colors.green.withOpacity(0.3)
                      : theme.colorScheme.primary.withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    energyCompleteBays == totalBays
                        ? Icons.check_circle
                        : Icons.analytics,
                    color: energyCompleteBays == totalBays
                        ? Colors.green
                        : theme.colorScheme.primary,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Energy Progress: $energyCompleteBays of $totalBays bays',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: energyCompleteBays == totalBays
                          ? Colors.green
                          : theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: LinearProgressIndicator(
                      value: totalBays > 0 ? energyCompleteBays / totalBays : 0,
                      backgroundColor: isDarkMode
                          ? Colors.grey.shade700
                          : Colors.grey.shade200,
                      valueColor: AlwaysStoppedAnimation(
                        energyCompleteBays == totalBays
                            ? Colors.green
                            : theme.colorScheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (energyCompleteBays == totalBays && totalBays > 0) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: validateEnergyDataForCalculation,
                  icon: const Icon(Icons.check_circle, size: 20),
                  label: const Text('Validate Energy Data for Calculation'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ] else if (!_isDailyReadingAvailable) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.schedule, color: Colors.orange, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Readings will be available after 08:00 AM IST',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.orange.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    if (widget.substationId.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.location_off,
                size: 64,
                color: isDarkMode
                    ? Colors.white.withOpacity(0.4)
                    : Colors.grey.shade400,
              ),
              const SizedBox(height: 16),
              Text(
                'No Substation Selected',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: isDarkMode
                      ? Colors.white.withOpacity(0.6)
                      : Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_isLoading) {
      return Center(
        child: Card(
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          color: isDarkMode ? const Color(0xFF2C2C2E) : Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(32),
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
        ),
      );
    }

    // FIX: Use SingleChildScrollView to make entire content scrollable
    return SingleChildScrollView(
      child: Column(
        children: [
          _buildHeader(),
          // FIX: Use shrinkWrap and remove Expanded to prevent nested scroll conflicts
          !_hasAnyBaysWithReadings
              ? Padding(
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
                        'No Daily Reading Assignments',
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
                        'No bays have been assigned daily reading templates in this substation.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: isDarkMode
                              ? Colors.white.withOpacity(0.6)
                              : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                )
              : !_isDailyReadingAvailable
              ? Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.access_time_filled,
                        size: 64,
                        color: Colors.orange.shade400,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Daily Energy Readings Unavailable',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.orange.shade700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _cacheError ??
                            'Daily readings will be available after 08:00 AM IST.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: isDarkMode
                              ? Colors.white.withOpacity(0.6)
                              : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  shrinkWrap: true, // FIX: Allow ListView to size itself
                  physics:
                      const NeverScrollableScrollPhysics(), // FIX: Disable internal scrolling
                  padding: const EdgeInsets.only(bottom: 16),
                  itemCount: _baysWithDailyAssignments.length,
                  itemBuilder: (context, index) {
                    return _buildBayCard(
                      _baysWithDailyAssignments[index],
                      index,
                    );
                  },
                ),
        ],
      ),
    );
  }
}
