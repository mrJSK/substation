// lib/models/user_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

// Define the roles for clarity and type safety
enum UserRole {
  admin,
  superAdmin,
  stateManager, // new: state-level manager
  companyManager, // new: company-level user
  zoneManager,
  circleManager,
  divisionManager,
  subdivisionManager,
  substationUser,
  pending,
}

class AppUser {
  final String uid;
  final String email;
  final UserRole role;
  final bool approved;
  // Assigned levels could be a map like {'zoneId': 'zoneABC', 'circleId': 'circleXYZ'}
  // This is for granular access control, ensuring a user only manages what they're assigned.
  final Map<String, String>? assignedLevels;

  AppUser({
    required this.uid,
    required this.email,
    this.role = UserRole.pending, // Default new user to pending
    this.approved = false,
    this.assignedLevels,
  });

  // Factory constructor to create an AppUser from a Firestore DocumentSnapshot
  factory AppUser.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return AppUser(
      uid: doc.id, // The document ID is the user's UID
      // Ensure 'email' field is null-safe. If it's null in Firestore, default to empty string.
      email: (data['email'] as String?) ?? '',
      role: UserRole.values.firstWhere(
        (e) =>
            e.toString().split('.').last ==
            (data['role'] ?? 'pending'), // Default to pending if role not set
        orElse: () => UserRole.pending,
      ),
      approved: data['approved'] ?? false,
      assignedLevels: data['assignedLevels'] is Map
          ? Map<String, String>.from(data['assignedLevels'])
          : null,
    );
  }

  // Method to convert AppUser to a Map for Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'email': email,
      'role': role.toString().split('.').last, // Store enum name as string
      'approved': approved,
      'assignedLevels': assignedLevels,
    };
  }

  // Helper method for creating a modified copy of an AppUser instance
  AppUser copyWith({
    String? uid,
    String? email,
    UserRole? role,
    bool? approved,
    Map<String, String>? assignedLevels,
  }) {
    return AppUser(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      role: role ?? this.role,
      approved: approved ?? this.approved,
      assignedLevels: assignedLevels ?? this.assignedLevels,
    );
  }

  // **ADD THESE GETTERS FOR HIERARCHY ACCESS**

  /// Gets the subdivision ID for subdivision-level users
  String? get subdivisionId => assignedLevels?['subdivisionId'];

  /// Gets the division ID for division-level users
  String? get divisionId => assignedLevels?['divisionId'];

  /// Gets the circle ID for circle-level users
  String? get circleId => assignedLevels?['circleId'];

  /// Gets the zone ID for zone-level users
  String? get zoneId => assignedLevels?['zoneId'];

  /// Gets the state ID for state-level users
  String? get stateId => assignedLevels?['stateId'];

  /// Gets the company ID for company-level users
  String? get companyId => assignedLevels?['companyId'];

  /// Gets the substation ID for substation-level users
  String? get substationId => assignedLevels?['substationId'];

  // **CONVENIENCE GETTERS FOR ROLE-BASED ACCESS**

  /// Returns the appropriate hierarchy ID based on user's role
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
        return null; // Admin users have access to everything
    }
  }

  /// Returns the hierarchy level name for the user's primary role
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

  /// Checks if the user has access to a specific hierarchy level
  bool hasAccessTo(String hierarchyType, String hierarchyId) {
    if (role == UserRole.admin || role == UserRole.superAdmin) {
      return true; // Admin users have access to everything
    }

    return assignedLevels?[hierarchyType] == hierarchyId;
  }

  /// Returns all assigned hierarchy levels as a formatted string
  String get assignedHierarchyDisplay {
    if (assignedLevels == null || assignedLevels!.isEmpty) {
      return 'No assignments';
    }

    return assignedLevels!.entries
        .map((entry) => '${entry.key}: ${entry.value}')
        .join(', ');
  }

  /// Checks if user is approved and has required assignments for their role
  bool get isFullyConfigured {
    if (!approved) return false;

    switch (role) {
      case UserRole.pending:
        return false;
      case UserRole.admin:
      case UserRole.superAdmin:
        return true; // Admin users don't need specific assignments
      case UserRole.substationUser:
        return substationId != null;
      case UserRole.subdivisionManager:
        return subdivisionId != null;
      case UserRole.divisionManager:
        return divisionId != null;
      case UserRole.circleManager:
        return circleId != null;
      case UserRole.zoneManager:
        return zoneId != null;
      case UserRole.stateManager:
        return stateId != null;
      case UserRole.companyManager:
        return companyId != null;
    }
  }
}
