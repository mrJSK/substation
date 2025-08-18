// lib/models/busbar_energy_map.dart
import 'package:cloud_firestore/cloud_firestore.dart';

enum EnergyContributionType {
  busImport, // Bay's energy adds to busbar's total import
  busExport, // Bay's energy adds to busbar's total export
  none, // Bay's energy does not contribute to this busbar's abstract
}

/// Stores the user-defined mapping for how a specific bay contributes to a busbar's energy abstract.
class BusbarEnergyMap {
  final String id; // Document ID
  final String substationId;
  final String busbarId;
  final String connectedBayId;
  final EnergyContributionType
  importContribution; // How bay's Import contributes to busbar
  final EnergyContributionType
  exportContribution; // How bay's Export contributes to busbar
  final DateTime lastModified;
  final String modifiedBy;

  BusbarEnergyMap({
    required this.id,
    required this.substationId,
    required this.busbarId,
    required this.connectedBayId,
    this.importContribution = EnergyContributionType.none,
    this.exportContribution = EnergyContributionType.none,
    required this.lastModified,
    required this.modifiedBy,
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
    );
  }

  @override
  String toString() {
    return 'BusbarEnergyMap(id: $id, busbarId: $busbarId, connectedBayId: $connectedBayId, imp: $importContribution, exp: $exportContribution)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is BusbarEnergyMap &&
        other.id == id &&
        other.substationId == substationId &&
        other.busbarId == busbarId &&
        other.connectedBayId == connectedBayId;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        substationId.hashCode ^
        busbarId.hashCode ^
        connectedBayId.hashCode;
  }
}
