// lib/models/busbar_energy_map.dart
import 'package:cloud_firestore/cloud_firestore.dart';

// Defines how a connected bay's energy contributes to a busbar's abstract.
enum EnergyContributionType {
  busImport, // Bay's energy adds to busbar's total import
  busExport, // Bay's energy adds to busbar's total export
  none, // Bay's energy does not contribute to this busbar's abstract (default)
}

// Stores the user-defined mapping for how a specific bay contributes to a busbar's energy abstract.
class BusbarEnergyMap {
  final String? id; // Document ID
  final String substationId;
  final String busbarId;
  final String connectedBayId;
  final EnergyContributionType
  importContribution; // How connectedBay's Import contributes to busbar
  final EnergyContributionType
  exportContribution; // How connectedBay's Export contributes to busbar
  final String createdBy;
  final Timestamp createdAt;
  final Timestamp? lastModifiedAt;

  BusbarEnergyMap({
    this.id,
    required this.substationId,
    required this.busbarId,
    required this.connectedBayId,
    this.importContribution = EnergyContributionType.none,
    this.exportContribution = EnergyContributionType.none,
    required this.createdBy,
    required this.createdAt,
    this.lastModifiedAt,
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
      createdBy: data['createdBy'] ?? '',
      createdAt: data['createdAt'] ?? Timestamp.now(),
      lastModifiedAt: data['lastModifiedAt'] as Timestamp?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'substationId': substationId,
      'busbarId': busbarId,
      'connectedBayId': connectedBayId,
      'importContribution': importContribution.toString().split('.').last,
      'exportContribution': exportContribution.toString().split('.').last,
      'createdBy': createdBy,
      'createdAt': createdAt,
      'lastModifiedAt': lastModifiedAt,
    };
  }

  BusbarEnergyMap copyWith({
    String? id,
    String? substationId,
    String? busbarId,
    String? connectedBayId,
    EnergyContributionType? importContribution,
    EnergyContributionType? exportContribution,
    String? createdBy,
    Timestamp? createdAt,
    Timestamp? lastModifiedAt,
  }) {
    return BusbarEnergyMap(
      id: id ?? this.id,
      substationId: substationId ?? this.substationId,
      busbarId: busbarId ?? this.busbarId,
      connectedBayId: connectedBayId ?? this.connectedBayId,
      importContribution: importContribution ?? this.importContribution,
      exportContribution: exportContribution ?? this.exportContribution,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      lastModifiedAt: lastModifiedAt ?? this.lastModifiedAt,
    );
  }
}
