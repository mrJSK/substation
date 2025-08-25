import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/user_model.dart';
import '../../models/enhanced_bay_data.dart';
import '../../services/comprehensive_cache_service.dart';
import '../../utils/snackbar_utils.dart';
import 'logsheet_entry_screen.dart';

class SubstationUserMonthlyTab extends StatefulWidget {
  final String substationId;
  final String substationName;
  final AppUser currentUser;
  final DateTime selectedDate;

  const SubstationUserMonthlyTab({
    super.key,
    required this.substationId,
    required this.substationName,
    required this.currentUser,
    required this.selectedDate,
  });

  @override
  State<SubstationUserMonthlyTab> createState() =>
      _SubstationUserMonthlyTabState();
}

class _SubstationUserMonthlyTabState extends State<SubstationUserMonthlyTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final ComprehensiveCacheService _cache = ComprehensiveCacheService();
  bool _isLoading = true;

  // Complete data source
  List<EnhancedBayData> _batteryBaysWithMonthly = [];

  // Lazy loading variables
  List<EnhancedBayData> _displayedBatteryBays = [];
  final int _itemsPerPage = 10;
  ScrollController? _scrollController;
  bool _isLoadingMore = false;
  bool _hasMoreItems = true;

  Map<String, bool> _batteryCompletionStatus = {};
  Map<String, int> _batteryCompletedCellsCount = {};
  bool _cacheHealthy = false;
  String? _cacheError;

  @override
  void initState() {
    super.initState();
    _initializeScrollController();
    _loadBatteryMonthlyData();
  }

  @override
  void didUpdateWidget(SubstationUserMonthlyTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    final bool shouldReload =
        oldWidget.substationId != widget.substationId ||
        !DateUtils.isSameDay(oldWidget.selectedDate, widget.selectedDate);

    if (shouldReload) {
      _resetPagination();
      _loadBatteryMonthlyData();
    }
  }

  @override
  void dispose() {
    _scrollController?.dispose();
    super.dispose();
  }

  void _initializeScrollController() {
    _scrollController = ScrollController();
    _scrollController!.addListener(_onScroll);
  }

  void _resetPagination() {
    _displayedBatteryBays.clear();
    _isLoadingMore = false;
    _hasMoreItems = true;
  }

  void _onScroll() {
    if (!_hasMoreItems || _isLoadingMore) return;

    // Trigger load more when within 200 pixels of bottom
    if (_scrollController!.position.pixels >=
        _scrollController!.position.maxScrollExtent - 200) {
      _loadMoreItems();
    }
  }

  Future<void> _loadMoreItems() async {
    if (_isLoadingMore || !_hasMoreItems) return;

    setState(() => _isLoadingMore = true);

    try {
      // Simulate network delay for smooth UX (remove in production if not needed)
      await Future.delayed(const Duration(milliseconds: 300));

      final currentLength = _displayedBatteryBays.length;
      final remainingItems = _batteryBaysWithMonthly.length - currentLength;

      if (remainingItems <= 0) {
        setState(() {
          _hasMoreItems = false;
          _isLoadingMore = false;
        });
        return;
      }

      final itemsToLoad = remainingItems < _itemsPerPage
          ? remainingItems
          : _itemsPerPage;

      final newItems = _batteryBaysWithMonthly
          .skip(currentLength)
          .take(itemsToLoad)
          .toList();

      if (mounted) {
        setState(() {
          _displayedBatteryBays.addAll(newItems);
          _hasMoreItems =
              _displayedBatteryBays.length < _batteryBaysWithMonthly.length;
          _isLoadingMore = false;
        });

        print(
          '✅ Loaded ${newItems.length} more battery bays. Total displayed: ${_displayedBatteryBays.length}',
        );
      }
    } catch (e) {
      print('❌ Error loading more items: $e');
      if (mounted) {
        setState(() => _isLoadingMore = false);
        SnackBarUtils.showSnackBar(
          context,
          'Error loading more batteries: $e',
          isError: true,
        );
      }
    }
  }

  Future<void> _loadBatteryMonthlyData() async {
    setState(() => _isLoading = true);

    try {
      if (!_cache.isInitialized) {
        throw Exception('Cache not initialized - please restart the app');
      }

      _batteryBaysWithMonthly = _cache
          .getBaysWithReadings('monthly')
          .where((bay) => bay.bay.bayType.toLowerCase() == 'battery')
          .toList();

      // Initialize with first page of items
      final initialItemCount = _batteryBaysWithMonthly.length < _itemsPerPage
          ? _batteryBaysWithMonthly.length
          : _itemsPerPage;

      _displayedBatteryBays = _batteryBaysWithMonthly
          .take(initialItemCount)
          .toList();

      _hasMoreItems = _batteryBaysWithMonthly.length > _itemsPerPage;
      _cacheHealthy = true;
      _checkBatteryMonthlyCompletion();

      print(
        '✅ Monthly tab loaded ${_batteryBaysWithMonthly.length} battery bays, displaying ${_displayedBatteryBays.length} initially',
      );
    } catch (e) {
      print('❌ Error loading battery monthly data: $e');
      setState(() {
        _cacheHealthy = false;
        _cacheError = e.toString();
      });

      if (mounted) {
        SnackBarUtils.showSnackBar(
          context,
          'Error loading monthly battery data: $e',
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _checkBatteryMonthlyCompletion() {
    _batteryCompletionStatus.clear();
    _batteryCompletedCellsCount.clear();

    for (var batteryBay in _batteryBaysWithMonthly) {
      final monthlyEntry = batteryBay.getReading(
        widget.selectedDate,
        'monthly',
      );

      int completeCells = 0;
      bool isComplete = false;

      if (monthlyEntry != null) {
        for (int i = 1; i <= 55; i++) {
          final cellData = monthlyEntry.values['Cell $i'];
          if (cellData != null && cellData is Map) {
            final cellNumber = cellData['Cell Number'];
            final cellVoltage = cellData['Cell Voltage'];
            final specificGravity = cellData['Specific Gravity'];

            if (cellNumber != null &&
                cellVoltage != null &&
                specificGravity != null) {
              completeCells++;
            }
          }
        }
        isComplete = completeCells == 55;
      }

      _batteryCompletionStatus[batteryBay.id] = isComplete;
      _batteryCompletedCellsCount[batteryBay.id] = completeCells;
    }
  }

  Future<void> _refreshBatteryStatus(String batteryId) async {
    try {
      await _cache.refreshBayData(batteryId);
      _checkBatteryMonthlyCompletion();
      if (mounted) setState(() {});
      print('✅ Battery monthly status refreshed for: $batteryId');
    } catch (e) {
      print('❌ Error refreshing battery status: $e');
    }
  }

  bool _canEnterMonthlyReadings() {
    final DateTime now = DateTime.now();
    final DateTime selectedMonth = DateTime(
      widget.selectedDate.year,
      widget.selectedDate.month,
      1,
    );
    final DateTime currentMonth = DateTime(now.year, now.month, 1);

    // Monthly readings available ONLY on the 1st of every month
    // For current month: only available if today is the 1st
    // For past months: always available (in case they missed entering on the 1st)
    if (selectedMonth.isAtSameMomentAs(currentMonth)) {
      // Current month - only available on 1st day
      return now.day == 1;
    } else if (selectedMonth.isBefore(currentMonth)) {
      // Past months - always available (for missed entries)
      return true;
    } else {
      // Future months - never available
      return false;
    }
  }

  void _showBatteryCompletedDialog(EnhancedBayData batteryBay) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final completedCells = _batteryCompletedCellsCount[batteryBay.id] ?? 0;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: isDarkMode ? const Color(0xFF2C2C2E) : Colors.white,
        title: Row(
          children: [
            Icon(Icons.battery_std, color: Colors.green, size: 24),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Monthly Reading Status',
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
              'Battery: ${batteryBay.bay.name}',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: isDarkMode ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Cell Progress: $completedCells / 55 cells recorded',
              style: TextStyle(
                fontSize: 14,
                color: isDarkMode
                    ? Colors.white.withOpacity(0.8)
                    : Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: completedCells / 55,
              backgroundColor: Colors.grey.shade300,
              valueColor: AlwaysStoppedAnimation(
                completedCells == 55 ? Colors.green : Colors.orange,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: (completedCells == 55 ? Colors.green : Colors.orange)
                    .withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: (completedCells == 55 ? Colors.green : Colors.orange)
                      .withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    completedCells == 55
                        ? Icons.check_circle
                        : Icons.info_outline,
                    color: completedCells == 55 ? Colors.green : Colors.orange,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      completedCells == 55
                          ? 'All 55 cells have been recorded with Cell Number, Voltage, and Specific Gravity.'
                          : 'Monthly reading in progress. Each cell needs: Cell Number, Cell Voltage, and Specific Gravity.',
                      style: TextStyle(
                        fontSize: 12,
                        color: completedCells == 55
                            ? Colors.green.shade700
                            : Colors.orange.shade700,
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
              'Close',
              style: TextStyle(
                color: isDarkMode ? Colors.white70 : Colors.grey.shade600,
              ),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _navigateToBatteryReading(batteryBay);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: theme.colorScheme.onPrimary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            icon: Icon(
              completedCells == 55 ? Icons.visibility : Icons.edit,
              size: 18,
            ),
            label: Text(
              completedCells == 55 ? 'View Details' : 'Continue Entry',
            ),
          ),
        ],
      ),
    );
  }

  void _navigateToBatteryReading(EnhancedBayData batteryBay) {
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (context) => LogsheetEntryScreen(
              substationId: widget.substationId,
              substationName: widget.substationName,
              bayId: batteryBay.id,
              readingDate: widget.selectedDate,
              frequency: 'monthly',
              readingHour: null,
              currentUser: widget.currentUser,
              forceReadOnly: false,
            ),
          ),
        )
        .then((result) {
          if (result == true) {
            _refreshBatteryStatus(batteryBay.id);
          }
        });
  }

  Widget _buildLoadingIndicator() {
    return Container(
      padding: const EdgeInsets.all(16),
      alignment: Alignment.center,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation(Colors.purple),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'Loading more batteries...',
            style: TextStyle(
              color: Colors.purple,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBatteryCard(EnhancedBayData batteryBay, int index) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final isComplete = _batteryCompletionStatus[batteryBay.id] ?? false;
    final completedCells = _batteryCompletedCellsCount[batteryBay.id] ?? 0;
    final canEnterReadings = _canEnterMonthlyReadings();

    Color statusColor = isComplete
        ? Colors.green
        : (completedCells > 0 ? Colors.orange : Colors.red);
    IconData statusIcon = isComplete ? Icons.battery_std : Icons.battery_alert;
    String statusText = isComplete
        ? 'Complete (55/55)'
        : completedCells > 0
        ? 'Partial ($completedCells/55)'
        : 'Pending (0/55)';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF2C2C2E) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: statusColor.withOpacity(0.3),
          width: isComplete ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDarkMode ? 0.3 : 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: canEnterReadings
              ? () => _showBatteryCompletedDialog(batteryBay)
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
                        border: Border.all(color: statusColor.withOpacity(0.3)),
                      ),
                      child: Icon(statusIcon, color: statusColor, size: 24),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            batteryBay.bay.name,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: isDarkMode ? Colors.white : Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${batteryBay.bay.voltageLevel} Battery Bank',
                            style: TextStyle(
                              fontSize: 14,
                              color: isDarkMode
                                  ? Colors.white.withOpacity(0.6)
                                  : Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: statusColor,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                statusText,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: statusColor,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (canEnterReadings) ...[
                      if (completedCells > 0 && !isComplete) ...[
                        Container(
                          width: 36,
                          height: 36,
                          child: Stack(
                            children: [
                              CircularProgressIndicator(
                                value: completedCells / 55,
                                backgroundColor: Colors.grey.shade300,
                                valueColor: AlwaysStoppedAnimation(statusColor),
                                strokeWidth: 3,
                              ),
                              Center(
                                child: Text(
                                  '$completedCells',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: statusColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                      Icon(
                        isComplete ? Icons.visibility : Icons.arrow_forward_ios,
                        color: theme.colorScheme.primary,
                        size: 16,
                      ),
                    ] else ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Not Available',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                if (completedCells > 0) ...[
                  const SizedBox(height: 12),
                  LinearProgressIndicator(
                    value: completedCells / 55,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation(statusColor),
                    minHeight: 4,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final completedBatteries = _batteryCompletionStatus.values
        .where((c) => c)
        .length;
    final totalBatteries = _batteryBaysWithMonthly.length;
    final canEnterReadings = _canEnterMonthlyReadings();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode
            ? Colors.purple.withOpacity(0.2)
            : Colors.purple.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.purple.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.purple.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.battery_std, color: Colors.purple, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Battery Monthly Cell Readings',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.purple,
                      ),
                    ),
                    Text(
                      DateFormat('MMMM yyyy').format(widget.selectedDate),
                      style: TextStyle(
                        fontSize: 14,
                        color: isDarkMode
                            ? Colors.white.withOpacity(0.7)
                            : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (totalBatteries > 0) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDarkMode ? const Color(0xFF3C3C3E) : Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Column(
                    children: [
                      Text(
                        '$totalBatteries',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.purple,
                        ),
                      ),
                      Text(
                        'Total Batteries',
                        style: TextStyle(fontSize: 10, color: Colors.purple),
                      ),
                    ],
                  ),
                  Column(
                    children: [
                      Text(
                        '${_displayedBatteryBays.length}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                      Text(
                        'Loaded',
                        style: TextStyle(fontSize: 10, color: Colors.blue),
                      ),
                    ],
                  ),
                  Column(
                    children: [
                      Text(
                        '$completedBatteries',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                      Text(
                        'Complete',
                        style: TextStyle(fontSize: 10, color: Colors.green),
                      ),
                    ],
                  ),
                  Column(
                    children: [
                      Text(
                        '55',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange,
                        ),
                      ),
                      Text(
                        'Cells Each',
                        style: TextStyle(fontSize: 10, color: Colors.orange),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
          if (!canEnterReadings) ...[
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
                      'Monthly readings will be available from the 1st of next month',
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

    return Column(
      children: [
        _buildHeader(),
        Expanded(
          child: _isLoading
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: Colors.purple),
                      const SizedBox(height: 16),
                      Text('Loading battery monthly data...'),
                    ],
                  ),
                )
              : _batteryBaysWithMonthly.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.battery_alert,
                          size: 64,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No Battery Monthly Readings',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'No batteries have monthly reading assignments in this substation.',
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
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.only(bottom: 16),
                  itemCount:
                      _displayedBatteryBays.length + (_isLoadingMore ? 1 : 0),
                  itemBuilder: (context, index) {
                    // Show loading indicator at bottom
                    if (index == _displayedBatteryBays.length) {
                      return _buildLoadingIndicator();
                    }

                    return _buildBatteryCard(
                      _displayedBatteryBays[index],
                      index,
                    );
                  },
                ),
        ),
      ],
    );
  }
}
