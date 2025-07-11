// lib/models/user_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

// Define the roles for clarity and type safety
enum UserRole {
  admin,
  zoneManager,
  circleManager,
  divisionManager,
  subdivisionManager,
  substationUser,
  pending, // For users awaiting admin approval after sign-up
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
      email: data['email'] ?? '',
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
}
