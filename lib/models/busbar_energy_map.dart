// lib/models/busbar_energy_map.dart
import 'package:cloud_firestore/cloud_firestore.dart';

enum EnergyContributionType {
  busImport, // Bay's energy adds to busbar's total import
  busExport, // Bay's energy adds to busbar's total export
  none, // Bay's energy does not contribute to this busbar's abstract
}

/// ✅ NEW: Configuration type to distinguish between busbar and substation mappings
enum ConfigurationType {
  busbarMapping, // Bay-to-busbar energy mapping
  substationMapping, // Busbar-to-substation energy mapping
}

/// Stores the user-defined mapping for how a specific bay contributes to a busbar's energy abstract,
/// OR how a busbar contributes to substation's energy abstract.
class BusbarEnergyMap {
  final String id; // Document ID
  final String substationId;
  final String busbarId; // For substation config, this will be 'SUBSTATION'
  final String
  connectedBayId; // Bay ID for busbar config, Busbar ID for substation config
  final EnergyContributionType importContribution; // How Import contributes
  final EnergyContributionType exportContribution; // How Export contributes
  final DateTime lastModified;
  final String modifiedBy;

  // ✅ NEW: Configuration type field
  final ConfigurationType configurationType;

  BusbarEnergyMap({
    required this.id,
    required this.substationId,
    required this.busbarId,
    required this.connectedBayId,
    this.importContribution = EnergyContributionType.none,
    this.exportContribution = EnergyContributionType.none,
    required this.lastModified,
    required this.modifiedBy,
    this.configurationType =
        ConfigurationType.busbarMapping, // ✅ NEW: Default to busbar mapping
  });

  factory BusbarEnergyMap.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

    return BusbarEnergyMap(
      id: doc.id,
      substationId: data['substationId'] ?? '',
      busbarId: data['busbarId'] ?? '',
      connectedBayId: data['connectedBayId'] ?? '',
      importContribution: EnergyContributionType.values.firstWhere(
        (e) =>
            e.toString().split('.').last ==
            (data['importContribution'] ?? 'none'),
        orElse: () => EnergyContributionType.none,
      ),
      exportContribution: EnergyContributionType.values.firstWhere(
        (e) =>
            e.toString().split('.').last ==
            (data['exportContribution'] ?? 'none'),
        orElse: () => EnergyContributionType.none,
      ),
      lastModified:
          (data['lastModified'] as Timestamp?)?.toDate() ?? DateTime.now(),
      modifiedBy: data['modifiedBy'] ?? '',
      // ✅ NEW: Read configuration type, default to busbar mapping for backward compatibility
      configurationType: ConfigurationType.values.firstWhere(
        (e) =>
            e.toString().split('.').last ==
            (data['configurationType'] ?? 'busbarMapping'),
        orElse: () => ConfigurationType.busbarMapping,
      ),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'substationId': substationId,
      'busbarId': busbarId,
      'connectedBayId': connectedBayId,
      'importContribution': importContribution.toString().split('.').last,
      'exportContribution': exportContribution.toString().split('.').last,
      'lastModified': Timestamp.fromDate(lastModified),
      'modifiedBy': modifiedBy,
      // ✅ NEW: Save configuration type
      'configurationType': configurationType.toString().split('.').last,
    };
  }

  BusbarEnergyMap copyWith({
    String? id,
    String? substationId,
    String? busbarId,
    String? connectedBayId,
    EnergyContributionType? importContribution,
    EnergyContributionType? exportContribution,
    DateTime? lastModified,
    String? modifiedBy,
    ConfigurationType? configurationType, // ✅ NEW
  }) {
    return BusbarEnergyMap(
      id: id ?? this.id,
      substationId: substationId ?? this.substationId,
      busbarId: busbarId ?? this.busbarId,
      connectedBayId: connectedBayId ?? this.connectedBayId,
      importContribution: importContribution ?? this.importContribution,
      exportContribution: exportContribution ?? this.exportContribution,
      lastModified: lastModified ?? this.lastModified,
      modifiedBy: modifiedBy ?? this.modifiedBy,
      configurationType: configurationType ?? this.configurationType, // ✅ NEW
    );
  }

  // ✅ NEW: Factory for creating busbar-to-bay mapping
  factory BusbarEnergyMap.forBusbar({
    required String substationId,
    required String busbarId,
    required String connectedBayId,
    required String modifiedBy,
    EnergyContributionType importContribution = EnergyContributionType.none,
    EnergyContributionType exportContribution = EnergyContributionType.none,
  }) {
    return BusbarEnergyMap(
      id: '',
      substationId: substationId,
      busbarId: busbarId,
      connectedBayId: connectedBayId,
      importContribution: importContribution,
      exportContribution: exportContribution,
      lastModified: DateTime.now(),
      modifiedBy: modifiedBy,
      configurationType: ConfigurationType.busbarMapping,
    );
  }

  // ✅ NEW: Factory for creating substation abstract mapping
  factory BusbarEnergyMap.forSubstation({
    required String substationId,
    required String busbarId, // The actual busbar ID
    required String modifiedBy,
    EnergyContributionType importContribution =
        EnergyContributionType.busImport,
    EnergyContributionType exportContribution =
        EnergyContributionType.busExport,
  }) {
    return BusbarEnergyMap(
      id: '',
      substationId: substationId,
      busbarId: 'SUBSTATION', // Special identifier for substation mappings
      connectedBayId: busbarId, // Store the actual busbar ID here
      importContribution: importContribution,
      exportContribution: exportContribution,
      lastModified: DateTime.now(),
      modifiedBy: modifiedBy,
      configurationType: ConfigurationType.substationMapping,
    );
  }

  // ✅ NEW: Check if this is a substation-level mapping
  bool get isSubstationMapping =>
      configurationType == ConfigurationType.substationMapping;

  // ✅ NEW: Check if this is a busbar-level mapping
  bool get isBusbarMapping =>
      configurationType == ConfigurationType.busbarMapping;

  // ✅ NEW: Get the actual busbar ID for substation mappings
  String get actualBusbarId => isSubstationMapping ? connectedBayId : busbarId;

  // ✅ NEW: Get the actual connected component ID
  String get actualConnectedId =>
      isSubstationMapping ? connectedBayId : connectedBayId;

  // ✅ NEW: Get mapping description
  String get mappingDescription {
    if (isSubstationMapping) {
      return 'Busbar → Substation Abstract';
    } else {
      return 'Bay → Busbar Abstract';
    }
  }

  @override
  String toString() {
    return 'BusbarEnergyMap(id: $id, type: $configurationType, busbarId: $busbarId, connectedBayId: $connectedBayId, imp: $importContribution, exp: $exportContribution)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is BusbarEnergyMap &&
        other.id == id &&
        other.substationId == substationId &&
        other.busbarId == busbarId &&
        other.connectedBayId == connectedBayId &&
        other.configurationType == configurationType;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        substationId.hashCode ^
        busbarId.hashCode ^
        connectedBayId.hashCode ^
        configurationType.hashCode;
  }
}
