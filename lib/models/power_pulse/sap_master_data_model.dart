import 'package:cloud_firestore/cloud_firestore.dart';

enum MasterDataType { vendor, material, service }

class MasterData {
  final String id;
  final MasterDataType type;
  final Map<String, dynamic> attributes;
  final Timestamp lastUpdatedOn;

  MasterData({
    required this.id,
    required this.type,
    required this.attributes,
    required this.lastUpdatedOn,
  });

  // Convert Firestore document to MasterData
  factory MasterData.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return MasterData(
      id: doc.id,
      type: MasterDataType.values.firstWhere(
        (e) => e.toString().split('.').last == data['type'],
        orElse: () => MasterDataType.vendor,
      ),
      attributes: Map<String, dynamic>.from(data['attributes'] ?? {}),
      lastUpdatedOn: data['lastUpdatedOn'] as Timestamp,
    );
  }

  // Convert MasterData to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'type': type.toString().split('.').last,
      'attributes': attributes,
      'lastUpdatedOn': lastUpdatedOn,
    };
  }

  // Get display name for search and list view
  String getDisplayName() {
    switch (type) {
      case MasterDataType.vendor:
        return attributes['NAME 1.']?.toString() ?? 'Unnamed Vendor';
      case MasterDataType.material:
        return attributes['Mat.Desc']?.toString() ?? 'Unnamed Material';
      case MasterDataType.service:
        return attributes['Service Short Text']?.toString() ??
            'Unnamed Service';
    }
  }

  // Get secondary display info for list view
  String getSecondaryInfo() {
    switch (type) {
      case MasterDataType.vendor:
        return attributes['City']?.toString() ?? 'Unknown City';
      case MasterDataType.material:
        return attributes['Mat.Grp Desc']?.toString() ?? 'Unknown Group';
      case MasterDataType.service:
        return attributes['Mat/Srv Group Desc.']?.toString() ?? 'Unknown Group';
    }
  }
}
