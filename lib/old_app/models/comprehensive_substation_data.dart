// lib/models/comprehensive_substation_data.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'enhanced_bay_data.dart';
import 'logsheet_models.dart';
import 'tripping_shutdown_model.dart';
import 'hierarchy_models.dart';

class ComprehensiveSubstationData {
  // Core substation info
  final Substation substation;

  // All bays with embedded data
  final List<EnhancedBayData> bays;

  // Recent tripping events (last 30 days)
  final List<TrippingShutdownEntry> recentTrippingEvents;

  // Cached statistics
  final SubstationStatistics statistics;

  // Hierarchy information (denormalized for quick access)
  final HierarchyContext hierarchyContext;

  // Cache metadata
  final DateTime lastFullRefresh;
  final Map<String, DateTime> lastPartialUpdates;

  ComprehensiveSubstationData({
    required this.substation,
    this.bays = const [],
    this.recentTrippingEvents = const [],
    required this.statistics,
    required this.hierarchyContext,
    DateTime? lastFullRefresh,
    this.lastPartialUpdates = const {},
  }) : lastFullRefresh = lastFullRefresh ?? DateTime.now();

  // Factory constructor for Firestore deserialization
  factory ComprehensiveSubstationData.fromFirestore(Map<String, dynamic> data) {
    final substation = Substation.fromFirestore(
      data['substation'] as DocumentSnapshot<Object?>,
    );

    final baysData = data['bays'] as List<dynamic>? ?? [];
    final bays = baysData
        .map((e) => EnhancedBayData.fromFirestore(e as Map<String, dynamic>))
        .toList();

    final recentEventsData =
        data['recentTrippingEvents'] as List<dynamic>? ?? [];
    final recentEvents = recentEventsData
        .map(
          (e) => TrippingShutdownEntry.fromFirestore(
            e as DocumentSnapshot<Object?>,
          ),
        )
        .toList();

    final statistics = SubstationStatistics.fromFirestore(
      data['statistics'] as Map<String, dynamic>,
    );
    final hierarchyContext = HierarchyContext.fromFirestore(
      data['hierarchyContext'] as Map<String, dynamic>,
    );

    DateTime lastRefresh;
    if (data['lastFullRefresh'] is Timestamp) {
      lastRefresh = (data['lastFullRefresh'] as Timestamp).toDate();
    } else {
      lastRefresh = DateTime.now();
    }

    final partialUpdatesData =
        data['lastPartialUpdates'] as Map<String, dynamic>? ?? {};
    final partialUpdates = <String, DateTime>{};
    partialUpdatesData.forEach((key, value) {
      if (value is Timestamp) {
        partialUpdates[key] = value.toDate();
      }
    });

    return ComprehensiveSubstationData(
      substation: substation,
      bays: bays,
      recentTrippingEvents: recentEvents,
      statistics: statistics,
      hierarchyContext: hierarchyContext,
      lastFullRefresh: lastRefresh,
      lastPartialUpdates: partialUpdates,
    );
  }

  // Quick access methods
  String get id => substation.id;
  String get name => substation.name;

  List<EnhancedBayData> getBaysByType(String bayType) {
    return bays.where((bay) => bay.bayType == bayType).toList();
  }

  List<EnhancedBayData> getBaysWithReadings(String frequency) {
    return bays.where((bay) => bay.hasReadingsFor(frequency)).toList();
  }

  EnhancedBayData? getBayById(String bayId) {
    try {
      return bays.firstWhere((bay) => bay.id == bayId);
    } catch (e) {
      return null;
    }
  }

  List<LogsheetEntry> getReadingsForDate(
    DateTime date,
    String frequency, {
    int? hour,
  }) {
    final entries = <LogsheetEntry>[];
    for (var bay in bays) {
      final entry = bay.getReading(date, frequency, hour: hour);
      if (entry != null) entries.add(entry);
    }
    return entries;
  }

  List<TrippingShutdownEntry> getTrippingEventsForDate(DateTime date) {
    return recentTrippingEvents.where((event) {
      final eventDate = event.startTime.toDate();
      return eventDate.year == date.year &&
          eventDate.month == date.month &&
          eventDate.day == date.day;
    }).toList();
  }

  List<TrippingShutdownEntry> getOpenTrippingEvents() {
    return recentTrippingEvents
        .where((event) => event.status == 'OPEN')
        .toList();
  }

  // Update methods
  ComprehensiveSubstationData updateBayReading(
    String bayId,
    LogsheetEntry entry,
  ) {
    final updatedBays = bays.map((bay) {
      if (bay.id == bayId) {
        return bay.updateReading(entry);
      }
      return bay;
    }).toList();

    final updatedPartialUpdates = Map<String, DateTime>.from(
      lastPartialUpdates,
    );
    updatedPartialUpdates['bay_$bayId'] = DateTime.now();

    return ComprehensiveSubstationData(
      substation: substation,
      bays: updatedBays,
      recentTrippingEvents: recentTrippingEvents,
      statistics: statistics.recalculate(updatedBays, recentTrippingEvents),
      hierarchyContext: hierarchyContext,
      lastFullRefresh: lastFullRefresh,
      lastPartialUpdates: updatedPartialUpdates,
    );
  }

  ComprehensiveSubstationData addTrippingEvent(TrippingShutdownEntry event) {
    final updatedEvents = List<TrippingShutdownEntry>.from(
      recentTrippingEvents,
    );

    // Remove any existing event with the same ID (in case of duplicates)
    updatedEvents.removeWhere((e) => e.id == event.id);

    // Insert at the beginning (most recent first)
    updatedEvents.insert(0, event);

    // Sort by start time (most recent first)
    updatedEvents.sort((a, b) => b.startTime.compareTo(a.startTime));

    // Keep only the most recent 100 events to prevent memory issues
    if (updatedEvents.length > 100) {
      updatedEvents.removeRange(100, updatedEvents.length);
    }

    final updatedPartialUpdates = Map<String, DateTime>.from(
      lastPartialUpdates,
    );
    updatedPartialUpdates['tripping_events'] = DateTime.now();

    return ComprehensiveSubstationData(
      substation: substation,
      bays: bays,
      recentTrippingEvents: updatedEvents,
      statistics: statistics.recalculate(bays, updatedEvents),
      hierarchyContext: hierarchyContext,
      lastFullRefresh: lastFullRefresh,
      lastPartialUpdates: updatedPartialUpdates,
    );
  }

  ComprehensiveSubstationData updateTrippingEvent(TrippingShutdownEntry event) {
    final updatedEvents = recentTrippingEvents.map((existingEvent) {
      return existingEvent.id == event.id ? event : existingEvent;
    }).toList();

    final updatedPartialUpdates = Map<String, DateTime>.from(
      lastPartialUpdates,
    );
    updatedPartialUpdates['tripping_events'] = DateTime.now();

    return ComprehensiveSubstationData(
      substation: substation,
      bays: bays,
      recentTrippingEvents: updatedEvents,
      statistics: statistics.recalculate(bays, updatedEvents),
      hierarchyContext: hierarchyContext,
      lastFullRefresh: lastFullRefresh,
      lastPartialUpdates: updatedPartialUpdates,
    );
  }

  // Copy with method for immutable updates
  ComprehensiveSubstationData copyWith({
    Substation? substation,
    List<EnhancedBayData>? bays,
    List<TrippingShutdownEntry>? recentTrippingEvents,
    SubstationStatistics? statistics,
    HierarchyContext? hierarchyContext,
    DateTime? lastFullRefresh,
    Map<String, DateTime>? lastPartialUpdates,
  }) {
    return ComprehensiveSubstationData(
      substation: substation ?? this.substation,
      bays: bays ?? this.bays,
      recentTrippingEvents: recentTrippingEvents ?? this.recentTrippingEvents,
      statistics: statistics ?? this.statistics,
      hierarchyContext: hierarchyContext ?? this.hierarchyContext,
      lastFullRefresh: lastFullRefresh ?? this.lastFullRefresh,
      lastPartialUpdates: lastPartialUpdates ?? this.lastPartialUpdates,
    );
  }

  // Serialization
  Map<String, dynamic> toFirestore() {
    return {
      'substation': substation.toFirestore(),
      'bays': bays.map((b) => b.toFirestore()).toList(),
      'recentTrippingEvents': recentTrippingEvents
          .map((e) => e.toFirestore())
          .toList(),
      'statistics': statistics.toFirestore(),
      'hierarchyContext': hierarchyContext.toFirestore(),
      'lastFullRefresh': Timestamp.fromDate(lastFullRefresh),
      'lastPartialUpdates': lastPartialUpdates.map(
        (key, value) => MapEntry(key, Timestamp.fromDate(value)),
      ),
    };
  }
}

class SubstationStatistics {
  final int totalBays;
  final int baysWithHourlyReadings;
  final int baysWithDailyReadings;
  final int openTrippingEvents;
  final int totalTrippingEventsLast30Days;
  final DateTime calculatedAt;

  SubstationStatistics({
    required this.totalBays,
    required this.baysWithHourlyReadings,
    required this.baysWithDailyReadings,
    required this.openTrippingEvents,
    required this.totalTrippingEventsLast30Days,
    DateTime? calculatedAt,
  }) : calculatedAt = calculatedAt ?? DateTime.now();

  factory SubstationStatistics.fromFirestore(Map<String, dynamic> data) {
    DateTime calculatedAt;
    if (data['calculatedAt'] is Timestamp) {
      calculatedAt = (data['calculatedAt'] as Timestamp).toDate();
    } else {
      calculatedAt = DateTime.now();
    }

    return SubstationStatistics(
      totalBays: data['totalBays'] as int? ?? 0,
      baysWithHourlyReadings: data['baysWithHourlyReadings'] as int? ?? 0,
      baysWithDailyReadings: data['baysWithDailyReadings'] as int? ?? 0,
      openTrippingEvents: data['openTrippingEvents'] as int? ?? 0,
      totalTrippingEventsLast30Days:
          data['totalTrippingEventsLast30Days'] as int? ?? 0,
      calculatedAt: calculatedAt,
    );
  }

  SubstationStatistics recalculate(
    List<EnhancedBayData> bays,
    List<TrippingShutdownEntry> events,
  ) {
    return SubstationStatistics(
      totalBays: bays.length,
      baysWithHourlyReadings: bays
          .where((b) => b.hasReadingsFor('hourly'))
          .length,
      baysWithDailyReadings: bays
          .where((b) => b.hasReadingsFor('daily'))
          .length,
      openTrippingEvents: events.where((e) => e.status == 'OPEN').length,
      totalTrippingEventsLast30Days: events.length,
      calculatedAt: DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'totalBays': totalBays,
      'baysWithHourlyReadings': baysWithHourlyReadings,
      'baysWithDailyReadings': baysWithDailyReadings,
      'openTrippingEvents': openTrippingEvents,
      'totalTrippingEventsLast30Days': totalTrippingEventsLast30Days,
      'calculatedAt': Timestamp.fromDate(calculatedAt),
    };
  }
}

class HierarchyContext {
  final String subdivisionName;
  final String divisionName;
  final String circleName;
  final String zoneName;
  final String companyName;

  HierarchyContext({
    required this.subdivisionName,
    required this.divisionName,
    required this.circleName,
    required this.zoneName,
    required this.companyName,
  });

  factory HierarchyContext.fromFirestore(Map<String, dynamic> data) {
    return HierarchyContext(
      subdivisionName: data['subdivisionName'] as String? ?? 'Unknown',
      divisionName: data['divisionName'] as String? ?? 'Unknown',
      circleName: data['circleName'] as String? ?? 'Unknown',
      zoneName: data['zoneName'] as String? ?? 'Unknown',
      companyName: data['companyName'] as String? ?? 'Unknown',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'subdivisionName': subdivisionName,
      'divisionName': divisionName,
      'circleName': circleName,
      'zoneName': zoneName,
      'companyName': companyName,
    };
  }
}
