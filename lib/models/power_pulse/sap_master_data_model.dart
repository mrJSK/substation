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
    try {
      final data = doc.data() as Map<String, dynamic>?;

      if (data == null) {
        throw Exception('Document data is null');
      }

      return MasterData(
        id: doc.id,
        type: MasterDataType.values.firstWhere(
          (e) => e.toString().split('.').last == data['type'],
          orElse: () => MasterDataType.vendor,
        ),
        attributes: Map<String, dynamic>.from(data['attributes'] ?? {}),
        lastUpdatedOn: data['lastUpdatedOn'] as Timestamp? ?? Timestamp.now(),
      );
    } catch (e) {
      print('Error converting Firestore document to MasterData: $e');
      // Return a default object in case of error
      return MasterData(
        id: doc.id,
        type: MasterDataType.vendor,
        attributes: {},
        lastUpdatedOn: Timestamp.now(),
      );
    }
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
    try {
      switch (type) {
        case MasterDataType.vendor:
          return attributes['NAME 1.']?.toString() ??
              attributes['Vendor']?.toString() ??
              'Unnamed Vendor';
        case MasterDataType.material:
          return attributes['Mat.Desc']?.toString() ??
              attributes['Material']?.toString() ??
              'Unnamed Material';
        case MasterDataType.service:
          return attributes['Service Short Text']?.toString() ??
              attributes['Activity number']?.toString() ??
              'Unnamed Service';
      }
    } catch (e) {
      print('Error getting display name: $e');
      return 'Unknown';
    }
  }

  // Get secondary display info for list view
  String getSecondaryInfo() {
    try {
      switch (type) {
        case MasterDataType.vendor:
          return attributes['City']?.toString() ??
              attributes['District']?.toString() ??
              'Unknown Location';
        case MasterDataType.material:
          return attributes['Mat.Grp Desc']?.toString() ??
              attributes['Mat.Grp']?.toString() ??
              'Unknown Group';
        case MasterDataType.service:
          return attributes['Mat/Srv Group Desc.']?.toString() ??
              attributes['Service Short Text']?.toString() ??
              'Unknown Group';
      }
    } catch (e) {
      print('Error getting secondary info: $e');
      return 'Unknown';
    }
  }

  // Get all searchable text for filtering
  String getSearchableText() {
    final searchableFields = <String>[];

    searchableFields.add(getDisplayName().toLowerCase());
    searchableFields.add(getSecondaryInfo().toLowerCase());
    searchableFields.add(id.toLowerCase());

    // Add specific fields based on type
    switch (type) {
      case MasterDataType.vendor:
        searchableFields.addAll([
          attributes['Vendor']?.toString().toLowerCase() ?? '',
          attributes['PAN']?.toString().toLowerCase() ?? '',
          attributes['GST']?.toString().toLowerCase() ?? '',
        ]);
        break;
      case MasterDataType.material:
        searchableFields.addAll([
          attributes['Material']?.toString().toLowerCase() ?? '',
          attributes['Mat.Typ']?.toString().toLowerCase() ?? '',
        ]);
        break;
      case MasterDataType.service:
        searchableFields.addAll([
          attributes['Activity number']?.toString().toLowerCase() ?? '',
        ]);
        break;
    }

    return searchableFields.where((s) => s.isNotEmpty).join(' ');
  }
}
