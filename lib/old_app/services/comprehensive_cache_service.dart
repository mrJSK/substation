// lib/services/comprehensive_cache_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/bay_model.dart';
import '../models/comprehensive_substation_data.dart';
import '../models/enhanced_bay_data.dart';
import '../models/hierarchy_models.dart';
import '../models/logsheet_models.dart';
import '../models/reading_models.dart';
import '../models/tripping_shutdown_model.dart';
import '../models/user_model.dart';

class ComprehensiveCacheService {
  static final ComprehensiveCacheService _instance =
      ComprehensiveCacheService._internal();
  factory ComprehensiveCacheService() => _instance;
  ComprehensiveCacheService._internal();

  // Single source of truth
  ComprehensiveSubstationData? _substationData;
  String? _currentSubstationId;
  String? _currentUserId;

  // Cache control
  static const Duration fullRefreshInterval = Duration(hours: 1);
  static const Duration partialRefreshInterval = Duration(minutes: 30);

  bool get isInitialized => _substationData != null;

  ComprehensiveSubstationData? get substationData => _substationData;

  // Main initialization method - Called once per app session
  Future<void> initializeForUser(AppUser user) async {
    final substationId = _getSubstationIdForUser(user);
    if (substationId == null) {
      throw Exception('No substation assigned to user');
    }

    // Only reload if different substation or cache is stale
    if (_shouldFullRefresh(substationId, user.uid)) {
      await _performFullRefresh(substationId, user.uid);
    }
  }

  bool _shouldFullRefresh(String substationId, String userId) {
    if (_substationData == null) return true;
    if (_currentSubstationId != substationId) return true;
    if (_currentUserId != userId) return true;

    final timeSinceLastRefresh = DateTime.now().difference(
      _substationData!.lastFullRefresh,
    );
    return timeSinceLastRefresh > fullRefreshInterval;
  }

  Future<void> _performFullRefresh(String substationId, String userId) async {
    print('🚀 Starting comprehensive data load for substation: $substationId');

    try {
      // Always build from separate collections for now
      // The comprehensive collection would be an optimization for later
      _substationData = await _buildComprehensiveData(substationId);

      _currentSubstationId = substationId;
      _currentUserId = userId;

      print(
        '✅ Loaded comprehensive data: ${_substationData!.bays.length} bays, '
        '${_substationData!.recentTrippingEvents.length} events',
      );
    } catch (e) {
      print('❌ Error loading comprehensive data: $e');
      rethrow;
    }
  }

  // Build comprehensive data from separate collections
  Future<ComprehensiveSubstationData> _buildComprehensiveData(
    String substationId,
  ) async {
    print('📦 Building comprehensive data from separate collections...');

    // Load substation
    final substationDoc = await FirebaseFirestore.instance
        .collection('substations')
        .doc(substationId)
        .get();

    if (!substationDoc.exists) {
      throw Exception('Substation not found: $substationId');
    }

    final substation = Substation.fromFirestore(substationDoc);

    // Load bays
    final baysSnapshot = await FirebaseFirestore.instance
        .collection('bays')
        .where('substationId', isEqualTo: substationId)
        .orderBy('name')
        .get();

    final List<EnhancedBayData> enhancedBays = [];

    for (var bayDoc in baysSnapshot.docs) {
      final bay = Bay.fromFirestore(bayDoc);

      // Load assignments for this bay
      final assignmentsSnapshot = await FirebaseFirestore.instance
          .collection('bayReadingAssignments')
          .where('bayId', isEqualTo: bay.id)
          .limit(1)
          .get();

      List<ReadingField> readingFields = [];
      if (assignmentsSnapshot.docs.isNotEmpty) {
        final assignedFieldsData =
            assignmentsSnapshot.docs.first.data()['assignedFields'] as List;
        readingFields = assignedFieldsData
            .map(
              (fieldMap) =>
                  ReadingField.fromMap(fieldMap as Map<String, dynamic>),
            )
            .toList();
      }

      // Load recent readings (last 7 days)
      final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));
      final readingsSnapshot = await FirebaseFirestore.instance
          .collection('logsheetEntries')
          .where('bayId', isEqualTo: bay.id)
          .where(
            'readingTimestamp',
            isGreaterThanOrEqualTo: Timestamp.fromDate(sevenDaysAgo),
          )
          .get();

      final Map<String, LogsheetEntry> recentReadings = {};
      final Map<String, bool> completionStatus = {};

      for (var readingDoc in readingsSnapshot.docs) {
        final entry = LogsheetEntry.fromFirestore(readingDoc);
        final dateKey = _getDateKey(entry.readingTimestamp.toDate());
        recentReadings[dateKey] = entry;

        final completionKey = _getCompletionKey(
          entry.readingTimestamp.toDate(),
          entry.frequency,
          entry.readingHour,
        );
        completionStatus[completionKey] = true;
      }

      enhancedBays.add(
        EnhancedBayData(
          bay: bay,
          readingFields: readingFields,
          recentReadings: recentReadings,
          completionStatus: completionStatus,
        ),
      );
    }

    // Load recent tripping events (last 30 days)
    final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
    final eventsSnapshot = await FirebaseFirestore.instance
        .collection('trippingShutdownEntries')
        .where('substationId', isEqualTo: substationId)
        .where(
          'startTime',
          isGreaterThanOrEqualTo: Timestamp.fromDate(thirtyDaysAgo),
        )
        .orderBy('startTime', descending: true)
        .get();

    // 🔧 FIX: Deduplicate events by ID to prevent counting duplicates
    print('🔍 Event Deduplication Debug:');
    print('   Raw events from Firestore: ${eventsSnapshot.docs.length}');

    final recentEvents = eventsSnapshot.docs
        .map((doc) => TrippingShutdownEntry.fromFirestore(doc))
        .fold<Map<String, TrippingShutdownEntry>>({}, (map, event) {
          // Use event ID as key to ensure uniqueness
          if (event.id != null) {
            map[event.id!] = event;
          }
          return map;
        })
        .values
        .toList();

    // Sort by start time (most recent first)
    recentEvents.sort((a, b) => b.startTime.compareTo(a.startTime));

    print('   Unique events after deduplication: ${recentEvents.length}');

    // Check for duplicates by ID (debug)
    final eventIds = recentEvents.map((e) => e.id).toList();
    final uniqueIds = eventIds.toSet();
    if (eventIds.length != uniqueIds.length) {
      print(
        '⚠️ WARNING: Found ${eventIds.length - uniqueIds.length} duplicate events after deduplication!',
      );
    } else {
      print('✅ No duplicate events found');
    }

    // Calculate statistics
    final statistics = SubstationStatistics(
      totalBays: enhancedBays.length,
      baysWithHourlyReadings: enhancedBays
          .where((b) => b.hasReadingsFor('hourly'))
          .length,
      baysWithDailyReadings: enhancedBays
          .where((b) => b.hasReadingsFor('daily'))
          .length,
      openTrippingEvents: recentEvents.where((e) => e.status == 'OPEN').length,
      totalTrippingEventsLast30Days: recentEvents.length,
    );

    // Build hierarchy context
    final hierarchyContext = HierarchyContext(
      subdivisionName: substation.subdivisionName ?? 'Unknown',
      divisionName: substation.divisionName ?? 'Unknown',
      circleName: substation.circleName ?? 'Unknown',
      zoneName: 'Unknown', // Would need to fetch if not denormalized
      companyName: 'Unknown', // Would need to fetch if not denormalized
    );

    return ComprehensiveSubstationData(
      substation: substation,
      bays: enhancedBays,
      recentTrippingEvents: recentEvents,
      statistics: statistics,
      hierarchyContext: hierarchyContext,
      lastFullRefresh: DateTime.now(),
    );
  }

  // 🔧 FIX: Enhanced deduplication helper method
  List<TrippingShutdownEntry> _deduplicateEventsByID(
    List<TrippingShutdownEntry> events,
  ) {
    final Map<String, TrippingShutdownEntry> uniqueEvents = {};

    for (var event in events) {
      if (event.id != null) {
        uniqueEvents[event.id!] = event;
      }
    }

    return uniqueEvents.values.toList();
  }

  // Quick access methods for screens
  List<EnhancedBayData> getBaysWithReadings(String frequency) {
    return _substationData?.getBaysWithReadings(frequency) ?? [];
  }

  List<LogsheetEntry> getReadingsForDate(
    DateTime date,
    String frequency, {
    int? hour,
  }) {
    return _substationData?.getReadingsForDate(date, frequency, hour: hour) ??
        [];
  }

  List<TrippingShutdownEntry> getTrippingEventsForDate(DateTime date) {
    return _substationData?.getTrippingEventsForDate(date) ?? [];
  }

  List<TrippingShutdownEntry> getOpenTrippingEvents() {
    return _substationData?.getOpenTrippingEvents() ?? [];
  }

  EnhancedBayData? getBayById(String bayId) {
    return _substationData?.getBayById(bayId);
  }

  // 🔧 FIX: Add the missing refreshSubstationData method
  Future<void> refreshSubstationData(String substationId) async {
    try {
      print('🔄 Refreshing substation data for: $substationId');

      // Force refresh for the specific substation
      if (_currentSubstationId == substationId && _currentUserId != null) {
        await _performFullRefresh(substationId, _currentUserId!);
        print('✅ Substation data refreshed successfully');
      } else {
        print(
          '⚠️ Substation ID mismatch or user not set. Current: $_currentSubstationId, Requested: $substationId',
        );
        // Still try to refresh with available data
        if (_currentUserId != null) {
          await _performFullRefresh(substationId, _currentUserId!);
        } else {
          throw Exception('Cannot refresh: No current user ID available');
        }
      }
    } catch (e) {
      print('❌ Error refreshing substation data: $e');
      rethrow;
    }
  }

  // 🔧 FIX: Add method to refresh specific bay data
  Future<void> refreshBayData(String bayId) async {
    if (_substationData == null || _currentSubstationId == null) {
      print('⚠️ Cannot refresh bay data: Cache not initialized');
      return;
    }

    try {
      print('🔄 Refreshing bay data for: $bayId');

      // Find the bay in current cache
      final bayData = getBayById(bayId);
      if (bayData == null) {
        print('⚠️ Bay not found in cache: $bayId');
        return;
      }

      // Reload recent readings for this specific bay (last 7 days)
      final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));
      final readingsSnapshot = await FirebaseFirestore.instance
          .collection('logsheetEntries')
          .where('bayId', isEqualTo: bayId)
          .where(
            'readingTimestamp',
            isGreaterThanOrEqualTo: Timestamp.fromDate(sevenDaysAgo),
          )
          .get();

      final Map<String, LogsheetEntry> recentReadings = {};
      final Map<String, bool> completionStatus = {};

      for (var readingDoc in readingsSnapshot.docs) {
        final entry = LogsheetEntry.fromFirestore(readingDoc);
        final dateKey = _getDateKey(entry.readingTimestamp.toDate());
        recentReadings[dateKey] = entry;

        final completionKey = _getCompletionKey(
          entry.readingTimestamp.toDate(),
          entry.frequency,
          entry.readingHour,
        );
        completionStatus[completionKey] = true;
      }

      // Update the specific bay data in cache
      final updatedBayData = EnhancedBayData(
        bay: bayData.bay,
        readingFields: bayData.readingFields,
        recentReadings: recentReadings,
        completionStatus: completionStatus,
      );

      // Replace the bay data in the cache
      final updatedBays = _substationData!.bays.map((bay) {
        return bay.id == bayId ? updatedBayData : bay;
      }).toList();

      _substationData = ComprehensiveSubstationData(
        substation: _substationData!.substation,
        bays: updatedBays,
        recentTrippingEvents: _substationData!.recentTrippingEvents,
        statistics: _substationData!.statistics,
        hierarchyContext: _substationData!.hierarchyContext,
        lastFullRefresh: _substationData!.lastFullRefresh,
      );

      print('✅ Bay data refreshed successfully for: $bayId');
    } catch (e) {
      print('❌ Error refreshing bay data for $bayId: $e');
      // Don't rethrow, as this is a background operation
    }
  }

  // 🔧 FIX: Add method to check if reading exists
  bool hasReadingForDate(
    String bayId,
    DateTime date,
    String frequency, {
    int? hour,
  }) {
    final bayData = getBayById(bayId);
    if (bayData == null) return false;

    final reading = bayData.getReading(date, frequency, hour: hour);
    return reading != null;
  }

  // 🔧 FIX: Add method to get reading for specific parameters
  LogsheetEntry? getReadingForBay(
    String bayId,
    DateTime date,
    String frequency, {
    int? hour,
  }) {
    final bayData = getBayById(bayId);
    if (bayData == null) return null;

    return bayData.getReading(date, frequency, hour: hour);
  }

  // Update methods (for real-time updates)
  void updateBayReading(String bayId, LogsheetEntry entry) {
    if (_substationData == null) return;

    _substationData = _substationData!.updateBayReading(bayId, entry);
    print('🔄 Updated cache for bay reading: $bayId');
  }

  void addTrippingEvent(TrippingShutdownEntry event) {
    if (_substationData == null) return;

    _substationData = _substationData!.addTrippingEvent(event);
    print('🔄 Added tripping event to cache: ${event.id}');
  }

  void updateTrippingEvent(TrippingShutdownEntry event) {
    if (_substationData == null) return;

    _substationData = _substationData!.updateTrippingEvent(event);
    print('🔄 Updated tripping event in cache: ${event.id}');
  }

  // Force refresh methods
  Future<void> forceRefresh() async {
    if (_currentSubstationId != null && _currentUserId != null) {
      await _performFullRefresh(_currentSubstationId!, _currentUserId!);
      print('🔄 Force refresh completed');
    } else {
      print('⚠️ Cannot force refresh: Missing substation ID or user ID');
    }
  }

  // 🔧 FIX: Enhanced partial refresh method with deduplication
  Future<void> partialRefresh() async {
    if (_substationData == null || _currentSubstationId == null) return;

    try {
      print('🔄 Starting partial refresh...');

      // Refresh tripping events from the last 7 days
      final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));
      final eventsSnapshot = await FirebaseFirestore.instance
          .collection('trippingShutdownEntries')
          .where('substationId', isEqualTo: _currentSubstationId)
          .where(
            'startTime',
            isGreaterThanOrEqualTo: Timestamp.fromDate(sevenDaysAgo),
          )
          .orderBy('startTime', descending: true)
          .get();

      // Merge with existing events and deduplicate
      final newEvents = eventsSnapshot.docs
          .map((doc) => TrippingShutdownEntry.fromFirestore(doc))
          .toList();

      final allEvents = [
        ..._substationData!.recentTrippingEvents,
        ...newEvents,
      ];
      final uniqueEvents = _deduplicateEventsByID(allEvents);

      // Sort by start time and limit to 100 events
      uniqueEvents.sort((a, b) => b.startTime.compareTo(a.startTime));
      if (uniqueEvents.length > 100) {
        uniqueEvents.removeRange(100, uniqueEvents.length);
      }

      // Update cache with deduplicated events
      _substationData = _substationData!.copyWith(
        recentTrippingEvents: uniqueEvents,
      );

      // Only refresh readings from the last 2 days for better performance
      final twoDaysAgo = DateTime.now().subtract(const Duration(days: 2));

      for (var bayData in _substationData!.bays) {
        final readingsSnapshot = await FirebaseFirestore.instance
            .collection('logsheetEntries')
            .where('bayId', isEqualTo: bayData.bay.id)
            .where(
              'readingTimestamp',
              isGreaterThanOrEqualTo: Timestamp.fromDate(twoDaysAgo),
            )
            .get();

        // Update recent readings for this bay
        for (var readingDoc in readingsSnapshot.docs) {
          final entry = LogsheetEntry.fromFirestore(readingDoc);
          updateBayReading(bayData.bay.id, entry);
        }
      }

      print(
        '✅ Partial refresh completed with ${uniqueEvents.length} unique events',
      );
    } catch (e) {
      print('❌ Error during partial refresh: $e');
      // Don't rethrow, fallback to using existing cache
    }
  }

  // 🔧 FIX: Add cache validation method
  bool validateCache() {
    if (_substationData == null) {
      print('❌ Cache validation failed: No data');
      return false;
    }

    // Check if cache is too old
    final timeSinceRefresh = DateTime.now().difference(
      _substationData!.lastFullRefresh,
    );
    if (timeSinceRefresh > Duration(hours: 6)) {
      print(
        '⚠️ Cache validation warning: Data is ${timeSinceRefresh.inHours} hours old',
      );
      return false;
    }

    // 🔧 FIX: Validate that events are properly deduplicated
    final eventIds = _substationData!.recentTrippingEvents
        .map((e) => e.id)
        .toList();
    final uniqueIds = eventIds.toSet();
    if (eventIds.length != uniqueIds.length) {
      print(
        '⚠️ Cache validation warning: Found ${eventIds.length - uniqueIds.length} duplicate events in cache',
      );

      // Auto-fix duplicates in cache
      final deduplicatedEvents = _deduplicateEventsByID(
        _substationData!.recentTrippingEvents,
      );
      _substationData = _substationData!.copyWith(
        recentTrippingEvents: deduplicatedEvents,
      );
      print('✅ Auto-fixed duplicate events in cache');
    }

    print('✅ Cache validation passed');
    return true;
  }

  void clearCache() {
    _substationData = null;
    _currentSubstationId = null;
    _currentUserId = null;
    print('🗑️ Cache cleared');
  }

  // 🔧 FIX: Enhanced method to get cache statistics with deduplication info
  Map<String, dynamic> getCacheStats() {
    if (_substationData == null) {
      return {
        'initialized': false,
        'substationId': null,
        'userId': null,
        'lastRefresh': null,
      };
    }

    // Check for duplicates in current cache
    final eventIds = _substationData!.recentTrippingEvents
        .map((e) => e.id)
        .toList();
    final uniqueIds = eventIds.toSet();
    final duplicateCount = eventIds.length - uniqueIds.length;

    return {
      'initialized': true,
      'substationId': _currentSubstationId,
      'userId': _currentUserId,
      'lastRefresh': _substationData!.lastFullRefresh.toIso8601String(),
      'totalBays': _substationData!.bays.length,
      'totalEvents': _substationData!.recentTrippingEvents.length,
      'duplicateEvents': duplicateCount,
      'cacheAge': DateTime.now()
          .difference(_substationData!.lastFullRefresh)
          .inMinutes,
    };
  }

  // Helper methods
  String? _getSubstationIdForUser(AppUser user) {
    return user.assignedLevels?['substationId'] ?? user.substationId;
  }

  String _getDateKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  String _getCompletionKey(DateTime date, String frequency, int? hour) {
    final dateStr = _getDateKey(date);
    if (frequency == 'hourly' && hour != null) {
      return '${frequency}_${dateStr}_${hour.toString().padLeft(2, '0')}';
    }
    return '${frequency}_$dateStr';
  }
}
