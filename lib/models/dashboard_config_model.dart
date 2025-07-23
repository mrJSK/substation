// lib/models/dashboard_config_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents the configurable settings for a user's dashboard.
/// Each user can have a unique configuration for their dashboard tabs.
class DashboardConfig {
  final String userId;
  final Map<String, OperationsTabConfig> operationsTab;
  final Map<String, TrippingShutdownTabConfig> trippingShutdownTab;
  final Map<String, EnergyTabConfig> energyTab;
  final Map<String, AssetTabConfig> assetTab;

  DashboardConfig({
    required this.userId,
    this.operationsTab = const {},
    this.trippingShutdownTab = const {},
    this.energyTab = const {},
    this.assetTab = const {},
  });

  /// Factory constructor to create a DashboardConfig from a Firestore DocumentSnapshot.
  factory DashboardConfig.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return DashboardConfig(
      userId: doc.id, // The document ID is the userId
      operationsTab:
          (data['operationsTab'] as Map<String, dynamic>?)?.map(
            (key, value) => MapEntry(key, OperationsTabConfig.fromMap(value)),
          ) ??
          {},
      trippingShutdownTab:
          (data['trippingShutdownTab'] as Map<String, dynamic>?)?.map(
            (key, value) =>
                MapEntry(key, TrippingShutdownTabConfig.fromMap(value)),
          ) ??
          {},
      energyTab:
          (data['energyTab'] as Map<String, dynamic>?)?.map(
            (key, value) => MapEntry(key, EnergyTabConfig.fromMap(value)),
          ) ??
          {},
      assetTab:
          (data['assetTab'] as Map<String, dynamic>?)?.map(
            (key, value) => MapEntry(key, AssetTabConfig.fromMap(value)),
          ) ??
          {},
    );
  }

  /// Converts this DashboardConfig instance into a Map for Firestore storage.
  Map<String, dynamic> toMap() {
    return {
      'operationsTab': operationsTab.map(
        (key, value) => MapEntry(key, value.toMap()),
      ),
      'trippingShutdownTab': trippingShutdownTab.map(
        (key, value) => MapEntry(key, value.toMap()),
      ),
      'energyTab': energyTab.map((key, value) => MapEntry(key, value.toMap())),
      'assetTab': assetTab.map((key, value) => MapEntry(key, value.toMap())),
    };
  }

  /// Creates a new DashboardConfig instance with updated operations tab configuration.
  DashboardConfig copyWith({
    Map<String, OperationsTabConfig>? operationsTab,
    Map<String, TrippingShutdownTabConfig>? trippingShutdownTab,
    Map<String, EnergyTabConfig>? energyTab,
    Map<String, AssetTabConfig>? assetTab,
  }) {
    return DashboardConfig(
      userId: userId,
      operationsTab: operationsTab ?? this.operationsTab,
      trippingShutdownTab: trippingShutdownTab ?? this.trippingShutdownTab,
      energyTab: energyTab ?? this.energyTab,
      assetTab: assetTab ?? this.assetTab,
    );
  }
}

/// Configuration for the Operations Tab.
class OperationsTabConfig {
  final List<String> selectedBayIds;
  final Map<String, List<String>>
  selectedReadingFieldIds; // {bayId: [fieldId1, fieldId2]}
  final List<String>
  displayOrder; // Order of bayIds or a combination of bayId-fieldId

  OperationsTabConfig({
    this.selectedBayIds = const [],
    this.selectedReadingFieldIds = const {},
    this.displayOrder = const [],
  });

  /// Factory constructor to create OperationsTabConfig from a Map.
  factory OperationsTabConfig.fromMap(Map<String, dynamic> map) {
    return OperationsTabConfig(
      selectedBayIds: List<String>.from(map['selectedBayIds'] ?? []),
      selectedReadingFieldIds:
          (map['selectedReadingFieldIds'] as Map<String, dynamic>?)?.map(
            (key, value) => MapEntry(key, List<String>.from(value)),
          ) ??
          {},
      displayOrder: List<String>.from(map['displayOrder'] ?? []),
    );
  }

  /// Converts this OperationsTabConfig instance into a Map.
  Map<String, dynamic> toMap() {
    return {
      'selectedBayIds': selectedBayIds,
      'selectedReadingFieldIds': selectedReadingFieldIds,
      'displayOrder': displayOrder,
    };
  }
}

/// Configuration for the Tripping/Shutdown Tab.
class TrippingShutdownTabConfig {
  final List<String> selectedVoltageLevels;
  final List<String> selectedBayTypes; // e.g., 'Transformer', 'Line', 'Feeder'

  TrippingShutdownTabConfig({
    this.selectedVoltageLevels = const [],
    this.selectedBayTypes = const [],
  });

  /// Factory constructor to create TrippingShutdownTabConfig from a Map.
  factory TrippingShutdownTabConfig.fromMap(Map<String, dynamic> map) {
    return TrippingShutdownTabConfig(
      selectedVoltageLevels: List<String>.from(
        map['selectedVoltageLevels'] ?? [],
      ),
      selectedBayTypes: List<String>.from(map['selectedBayTypes'] ?? []),
    );
  }

  /// Converts this TrippingShutdownTabConfig instance into a Map.
  Map<String, dynamic> toMap() {
    return {
      'selectedVoltageLevels': selectedVoltageLevels,
      'selectedBayTypes': selectedBayTypes,
    };
  }
}

/// Configuration for the Energy Tab.
class EnergyTabConfig {
  final List<String> selectedSubstationIds;
  final List<String> selectedVoltageLevels;
  final double? minLossPercentage;
  final double? maxLossPercentage;

  EnergyTabConfig({
    this.selectedSubstationIds = const [],
    this.selectedVoltageLevels = const [],
    this.minLossPercentage,
    this.maxLossPercentage,
  });

  /// Factory constructor to create EnergyTabConfig from a Map.
  factory EnergyTabConfig.fromMap(Map<String, dynamic> map) {
    return EnergyTabConfig(
      selectedSubstationIds: List<String>.from(
        map['selectedSubstationIds'] ?? [],
      ),
      selectedVoltageLevels: List<String>.from(
        map['selectedVoltageLevels'] ?? [],
      ),
      minLossPercentage: (map['minLossPercentage'] as num?)?.toDouble(),
      maxLossPercentage: (map['maxLossPercentage'] as num?)?.toDouble(),
    );
  }

  /// Converts this EnergyTabConfig instance into a Map.
  Map<String, dynamic> toMap() {
    return {
      'selectedSubstationIds': selectedSubstationIds,
      'selectedVoltageLevels': selectedVoltageLevels,
      'minLossPercentage': minLossPercentage,
      'maxLossPercentage': maxLossPercentage,
    };
  }
}

/// Configuration for the Asset Tab.
class AssetTabConfig {
  // No specific configuration needed for assets tab beyond permissions,
  // but keeping it for consistency if future configurations arise.
  AssetTabConfig();

  /// Factory constructor to create AssetTabConfig from a Map.
  factory AssetTabConfig.fromMap(Map<String, dynamic> map) {
    return AssetTabConfig();
  }

  /// Converts this AssetTabConfig instance into a Map.
  Map<String, dynamic> toMap() {
    return {};
  }
}
