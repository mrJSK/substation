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

    final recentEvents = eventsSnapshot.docs
        .map((doc) => TrippingShutdownEntry.fromFirestore(doc))
        .toList();

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
    }
  }

  void clearCache() {
    _substationData = null;
    _currentSubstationId = null;
    _currentUserId = null;
    print('🗑️ Cache cleared');
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
