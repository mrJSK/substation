import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/user_model.dart';
import '../../models/enhanced_bay_data.dart';
import '../../services/comprehensive_cache_service.dart';
import '../../utils/snackbar_utils.dart';
import 'logsheet_entry_screen.dart';

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
      case 'battery':
        iconData = Icons.battery_std;
        break;
      case 'bus coupler':
        iconData = Icons.power_settings_new;
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

class _BayReadingsStatusScreenState extends State<BayReadingsStatusScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final ComprehensiveCacheService _cache = ComprehensiveCacheService();
  bool _isLoading = true;
  List<EnhancedBayData> _baysWithAssignments = [];
  Map<String, bool> _bayCompletionStatus = {};

  @override
  void initState() {
    super.initState();
    _loadDataFromCache();
  }

  @override
  void didUpdateWidget(BayReadingsStatusScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (mounted) {
      _calculateCompletionStatuses();
    }
  }

  Future<void> _loadDataFromCache() async {
    setState(() => _isLoading = true);
    try {
      if (!_cache.isInitialized) {
        throw Exception('Cache not initialized - please restart the app');
      }
      _baysWithAssignments = _cache.getBaysWithReadings(widget.frequencyType);
      _calculateCompletionStatuses();
      print(
        '✅ Loaded ${_baysWithAssignments.length} bays from cache for ${widget.frequencyType} readings',
      );
    } catch (e) {
      print("Error loading data from cache: $e");
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

  void _calculateCompletionStatuses() {
    _bayCompletionStatus.clear();
    for (var bayData in _baysWithAssignments) {
      final isComplete = bayData.isComplete(
        widget.selectedDate,
        widget.frequencyType,
        hour: widget.selectedHour,
      );
      _bayCompletionStatus[bayData.id] = isComplete;
    }
  }

  Future<void> _refreshBayStatus(String bayId) async {
    try {
      await _cache.refreshSubstationData(widget.substationId);
      _calculateCompletionStatuses();
      if (mounted) {
        setState(() {});
      }
      print('✅ Bay status refreshed for: $bayId');
    } catch (e) {
      print('❌ Error refreshing bay status: $e');
      _calculateCompletionStatuses();
      if (mounted) {
        setState(() {});
      }
    }
  }

  bool _canModifyExistingReading(AppUser user) {
    return [
      UserRole.admin,
      UserRole.subdivisionManager,
      UserRole.divisionManager,
      UserRole.circleManager,
      UserRole.zoneManager,
    ].contains(user.role);
  }

  Future<void> _showReadingCompletedDialog(EnhancedBayData bayData) async {
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
                'Reading Completed',
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
              'Reading for ${bayData.bay.name} has already been recorded for this ${_getFrequencyLabel()}.',
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
                      _canModifyExistingReading(widget.currentUser)
                          ? 'You can view or modify this reading.'
                          : 'You can only view this reading.',
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
              _navigateToReadingEntry(
                bayData,
                forceReadOnly: !_canModifyExistingReading(widget.currentUser),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: theme.colorScheme.onPrimary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            icon: Icon(
              _canModifyExistingReading(widget.currentUser)
                  ? Icons.edit
                  : Icons.visibility,
              size: 18,
            ),
            label: Text(
              _canModifyExistingReading(widget.currentUser) ? 'Edit' : 'View',
            ),
          ),
        ],
      ),
    );
  }

  String _getFrequencyLabel() {
    switch (widget.frequencyType) {
      case 'hourly':
        return 'hour';
      case 'daily':
        return 'date';
      case 'monthly':
        return 'month';
      default:
        return 'period';
    }
  }

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
              frequency: widget.frequencyType,
              readingHour: widget.selectedHour,
              currentUser: widget.currentUser,
              forceReadOnly: forceReadOnly,
            ),
          ),
        )
        .then((result) {
          if (result == true) {
            print('🔄 Refreshing after reading entry for bay: ${bayData.id}');
            _refreshBayStatus(bayData.id);
          }
        });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    String slotTitle = DateFormat('dd.MMM.yyyy').format(widget.selectedDate);
    if (widget.frequencyType == 'hourly' && widget.selectedHour != null) {
      slotTitle +=
          ' - ${widget.selectedHour!.toString().padLeft(2, '0')}:00 Hr';
    } else if (widget.frequencyType == 'daily') {
      slotTitle += ' - Daily Reading';
    } else if (widget.frequencyType == 'monthly') {
      slotTitle += ' - Monthly Reading';
    }

    int completedBays = _bayCompletionStatus.values
        .where((status) => status)
        .length;
    int totalBays = _baysWithAssignments.length;
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
          onPressed: () => Navigator.pop(context, true),
        ),
        actions: [
          IconButton(
            onPressed: () async {
              try {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Refreshing data...'),
                    duration: Duration(seconds: 1),
                  ),
                );
                await _cache.forceRefresh();
                await _loadDataFromCache();
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Data refreshed successfully!'),
                    backgroundColor: Colors.green,
                    duration: Duration(seconds: 2),
                  ),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Failed to refresh: $e'),
                    backgroundColor: Colors.red,
                    duration: Duration(seconds: 3),
                  ),
                );
              }
            },
            icon: Icon(
              Icons.refresh,
              color: isDarkMode ? Colors.white : Colors.black87,
            ),
            tooltip: 'Refresh Data',
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
                    CircularProgressIndicator(color: theme.colorScheme.primary),
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
                              _getFrequencyIcon(),
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
                Expanded(
                  child: _baysWithAssignments.isEmpty
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
                                    'No bays with ${widget.frequencyType} reading assignments found for ${widget.substationName}. Please assign reading templates to bays in Asset Management.',
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
                          itemCount: _baysWithAssignments.length,
                          itemBuilder: (context, index) {
                            final bayData = _baysWithAssignments[index];
                            final bool isBayComplete =
                                _bayCompletionStatus[bayData.id] ?? false;
                            final int mandatoryFieldsCount = bayData
                                .getReadingFields(
                                  widget.frequencyType,
                                  mandatoryOnly: true,
                                )
                                .length;

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
                                border: isBayComplete
                                    ? Border.all(
                                        color: Colors.green.withOpacity(0.3),
                                        width: 1,
                                      )
                                    : null,
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.all(16),
                                leading: Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color:
                                        (isBayComplete
                                                ? Colors.green
                                                : Colors.red)
                                            .withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color:
                                          (isBayComplete
                                                  ? Colors.green
                                                  : Colors.red)
                                              .withOpacity(0.3),
                                    ),
                                  ),
                                  child: Icon(
                                    isBayComplete
                                        ? Icons.visibility
                                        : Icons.edit,
                                    color: isBayComplete
                                        ? Colors.green
                                        : Colors.red,
                                    size: 24,
                                  ),
                                ),
                                title: Row(
                                  children: [
                                    _EquipmentIcon(
                                      bayType: bayData.bay.bayType,
                                      color: theme.colorScheme.primary,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        bayData.bay.name,
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
                                      '${bayData.bay.voltageLevel} ${bayData.bay.bayType}',
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
                                            color: isBayComplete
                                                ? Colors.green
                                                : Colors.red,
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          isBayComplete
                                              ? 'Reading completed'
                                              : 'Reading pending',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: isBayComplete
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
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (isBayComplete)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.green.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          border: Border.all(
                                            color: Colors.green.withOpacity(
                                              0.3,
                                            ),
                                          ),
                                        ),
                                        child: Text(
                                          'Done',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.green.shade700,
                                          ),
                                        ),
                                      ),
                                    const SizedBox(width: 8),
                                    Icon(
                                      isBayComplete
                                          ? Icons.visibility
                                          : Icons.arrow_forward_ios,
                                      color: theme.colorScheme.primary,
                                      size: 16,
                                    ),
                                  ],
                                ),
                                onTap: () {
                                  if (isBayComplete) {
                                    _showReadingCompletedDialog(bayData);
                                  } else {
                                    _navigateToReadingEntry(bayData);
                                  }
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

  IconData _getFrequencyIcon() {
    switch (widget.frequencyType) {
      case 'hourly':
        return Icons.access_time;
      case 'daily':
        return Icons.calendar_today;
      case 'monthly':
        return Icons.calendar_view_month;
      default:
        return Icons.schedule;
    }
  }
}
