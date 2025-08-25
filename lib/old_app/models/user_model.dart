// lib/models/user_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';

// Define the roles for clarity and type safety
enum UserRole {
  admin,
  superAdmin,
  stateManager,
  companyManager,
  zoneManager,
  circleManager,
  divisionManager,
  subdivisionManager,
  substationUser,
  pending,
}

// Define designation enum for standardization
enum Designation {
  director,
  chiefEngineer,
  superintendingEngineer,
  executiveEngineer,
  assistantEngineerSDO,
  juniorEngineer,
  technician,
}

class AppUser {
  final String uid;
  final String email;
  final String name;
  final String cugNumber; // This should never be null
  final String? personalNumber;
  final Designation designation;
  final UserRole role;
  final bool approved;

  // Hierarchy information
  final String? companyId;
  final String? companyName;
  final String? stateId;
  final String? stateName;
  final String? zoneId;
  final String? zoneName;
  final String? circleId;
  final String? circleName;
  final String? divisionId;
  final String? divisionName;
  final String? subdivisionId;
  final String? subdivisionName;
  final String? substationId;
  final String? substationName;

  // Optional fields
  final String? sapId;
  final String? highestEducation;
  final String? college;
  final String? personalEmail;

  // Profile metadata
  final Timestamp? createdAt;
  final Timestamp? updatedAt;
  final bool profileCompleted;

  // Assigned levels for access control
  final Map? assignedLevels;

  AppUser({
    required this.uid,
    required this.email,
    required this.name,
    required this.cugNumber,
    this.personalNumber,
    required this.designation,
    this.role = UserRole.pending,
    this.approved = false,
    this.companyId,
    this.companyName,
    this.stateId,
    this.stateName,
    this.zoneId,
    this.zoneName,
    this.circleId,
    this.circleName,
    this.divisionId,
    this.divisionName,
    this.subdivisionId,
    this.subdivisionName,
    this.substationId,
    this.substationName,
    this.sapId,
    this.highestEducation,
    this.college,
    this.personalEmail,
    this.createdAt,
    this.updatedAt,
    this.profileCompleted = false,
    this.assignedLevels,
  });

  // FIXED: Better null handling in fromFirestore
  factory AppUser.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map;

    // CRITICAL FIX: Ensure cugNumber is never null
    String cugNumberValue = '';
    if (data['cugNumber'] != null && data['cugNumber'].toString().isNotEmpty) {
      cugNumberValue = data['cugNumber'].toString();
    } else if (data['mobile'] != null && data['mobile'].toString().isNotEmpty) {
      cugNumberValue = data['mobile'].toString();
    } else {
      // Fallback to empty string if both are null
      cugNumberValue = '';
    }

    return AppUser(
      uid: doc.id,
      email: data['email']?.toString() ?? '',
      name: data['name']?.toString() ?? '',
      cugNumber: cugNumberValue, // Now guaranteed to be non-null
      personalNumber: data['personalNumber']?.toString(),
      designation: Designation.values.firstWhere(
        (e) =>
            e.toString().split('.').last ==
            (data['designation']?.toString() ?? 'technician'),
        orElse: () => Designation.technician,
      ),
      role: UserRole.values.firstWhere(
        (e) =>
            e.toString().split('.').last ==
            (data['role']?.toString() ?? 'pending'),
        orElse: () => UserRole.pending,
      ),
      approved: data['approved'] ?? false,
      companyId: data['companyId']?.toString(),
      companyName: data['companyName']?.toString(),
      stateId: data['stateId']?.toString(),
      stateName: data['stateName']?.toString(),
      zoneId: data['zoneId']?.toString(),
      zoneName: data['zoneName']?.toString(),
      circleId: data['circleId']?.toString(),
      circleName: data['circleName']?.toString(),
      divisionId: data['divisionId']?.toString(),
      divisionName: data['divisionName']?.toString(),
      subdivisionId: data['subdivisionId']?.toString(),
      subdivisionName: data['subdivisionName']?.toString(),
      substationId: data['substationId']?.toString(),
      substationName: data['substationName']?.toString(),
      sapId: data['sapId']?.toString(),
      highestEducation: data['highestEducation']?.toString(),
      college: data['college']?.toString(),
      personalEmail: data['personalEmail']?.toString(),
      createdAt: data['createdAt'] as Timestamp?,
      updatedAt: data['updatedAt'] as Timestamp?,
      profileCompleted: data['profileCompleted'] ?? false,
      assignedLevels: data['assignedLevels'] != null
          ? Map.from(data['assignedLevels'])
          : null,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'email': email,
      'name': name,
      'cugNumber': cugNumber,
      'personalNumber': personalNumber,
      'designation': designation.toString().split('.').last,
      'role': role.toString().split('.').last,
      'approved': approved,
      'companyId': companyId,
      'companyName': companyName,
      'stateId': stateId,
      'stateName': stateName,
      'zoneId': zoneId,
      'zoneName': zoneName,
      'circleId': circleId,
      'circleName': circleName,
      'divisionId': divisionId,
      'divisionName': divisionName,
      'subdivisionId': subdivisionId,
      'subdivisionName': subdivisionName,
      'substationId': substationId,
      'substationName': substationName,
      'sapId': sapId,
      'highestEducation': highestEducation,
      'college': college,
      'personalEmail': personalEmail,
      'createdAt': createdAt,
      'updatedAt': updatedAt ?? Timestamp.now(),
      'profileCompleted': profileCompleted,
      'assignedLevels': assignedLevels,
    };
  }

  AppUser copyWith({
    String? uid,
    String? email,
    String? name,
    String? cugNumber,
    String? personalNumber,
    Designation? designation,
    UserRole? role,
    bool? approved,
    String? companyId,
    String? companyName,
    String? stateId,
    String? stateName,
    String? zoneId,
    String? zoneName,
    String? circleId,
    String? circleName,
    String? divisionId,
    String? divisionName,
    String? subdivisionId,
    String? subdivisionName,
    String? substationId,
    String? substationName,
    String? sapId,
    String? highestEducation,
    String? college,
    String? personalEmail,
    Timestamp? createdAt,
    Timestamp? updatedAt,
    bool? profileCompleted,
    Map? assignedLevels,
  }) {
    return AppUser(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      name: name ?? this.name,
      cugNumber: cugNumber ?? this.cugNumber,
      personalNumber: personalNumber ?? this.personalNumber,
      designation: designation ?? this.designation,
      role: role ?? this.role,
      approved: approved ?? this.approved,
      companyId: companyId ?? this.companyId,
      companyName: companyName ?? this.companyName,
      stateId: stateId ?? this.stateId,
      stateName: stateName ?? this.stateName,
      zoneId: zoneId ?? this.zoneId,
      zoneName: zoneName ?? this.zoneName,
      circleId: circleId ?? this.circleId,
      circleName: circleName ?? this.circleName,
      divisionId: divisionId ?? this.divisionId,
      divisionName: divisionName ?? this.divisionName,
      subdivisionId: subdivisionId ?? this.subdivisionId,
      subdivisionName: subdivisionName ?? this.subdivisionName,
      substationId: substationId ?? this.substationId,
      substationName: substationName ?? this.substationName,
      sapId: sapId ?? this.sapId,
      highestEducation: highestEducation ?? this.highestEducation,
      college: college ?? this.college,
      personalEmail: personalEmail ?? this.personalEmail,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      profileCompleted: profileCompleted ?? this.profileCompleted,
      assignedLevels: assignedLevels ?? this.assignedLevels,
    );
  }

  // Convenience getters
  String get designationDisplayName {
    switch (designation) {
      case Designation.director:
        return 'Director';
      case Designation.chiefEngineer:
        return 'Chief Engineer (CE)';
      case Designation.superintendingEngineer:
        return 'Superintending Engineer (SE)';
      case Designation.executiveEngineer:
        return 'Executive Engineer (EE)';
      case Designation.assistantEngineerSDO:
        return 'Assistant Engineer/SDO (AE/SDO)';
      case Designation.juniorEngineer:
        return 'Junior Engineer (JE)';
      case Designation.technician:
        return 'Technician';
    }
  }

  String get currentPostingDisplay {
    List<String> hierarchy = [];
    if (companyName != null) hierarchy.add(companyName!);
    if (stateName != null) hierarchy.add(stateName!);
    if (zoneName != null) hierarchy.add(zoneName!);
    if (circleName != null) hierarchy.add(circleName!);
    if (divisionName != null) hierarchy.add(divisionName!);
    if (subdivisionName != null) hierarchy.add(subdivisionName!);
    if (substationName != null) hierarchy.add(substationName!);
    return hierarchy.isEmpty ? 'Not assigned' : hierarchy.join(' > ');
  }

  bool get isMandatoryFieldsComplete {
    return name.isNotEmpty &&
        cugNumber.isNotEmpty &&
        (subdivisionName != null || substationName != null);
  }

  // Backward compatibility getter
  @deprecated
  String get mobile => cugNumber;

  String? get primaryHierarchyId {
    switch (role) {
      case UserRole.substationUser:
        return substationId;
      case UserRole.subdivisionManager:
        return subdivisionId;
      case UserRole.divisionManager:
        return divisionId;
      case UserRole.circleManager:
        return circleId;
      case UserRole.zoneManager:
        return zoneId;
      case UserRole.stateManager:
        return stateId;
      case UserRole.companyManager:
        return companyId;
      case UserRole.admin:
      case UserRole.superAdmin:
      default:
        return null;
    }
  }

  String get primaryHierarchyLevel {
    switch (role) {
      case UserRole.substationUser:
        return 'substation';
      case UserRole.subdivisionManager:
        return 'subdivision';
      case UserRole.divisionManager:
        return 'division';
      case UserRole.circleManager:
        return 'circle';
      case UserRole.zoneManager:
        return 'zone';
      case UserRole.stateManager:
        return 'state';
      case UserRole.companyManager:
        return 'company';
      case UserRole.admin:
      case UserRole.superAdmin:
        return 'admin';
      case UserRole.pending:
        return 'pending';
    }
  }

  bool hasAccessTo(String hierarchyType, String hierarchyId) {
    if (role == UserRole.admin || role == UserRole.superAdmin) {
      return true;
    }
    return assignedLevels?[hierarchyType] == hierarchyId;
  }

  bool get isFullyConfigured {
    return approved && isMandatoryFieldsComplete;
  }
}
