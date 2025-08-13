// lib/services/user_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';

class UserService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // ==================== USER CRUD OPERATIONS ====================

  /// Create a new user in Firestore
  static Future<void> createUser(AppUser user) async {
    try {
      await _firestore
          .collection('users')
          .doc(user.uid)
          .set(user.toFirestore(), SetOptions(merge: false));
    } catch (e) {
      throw Exception('Failed to create user: $e');
    }
  }

  /// Update an existing user
  static Future<void> updateUser(AppUser user) async {
    try {
      await _firestore
          .collection('users')
          .doc(user.uid)
          .set(user.toFirestore(), SetOptions(merge: true));
    } catch (e) {
      throw Exception('Failed to update user: $e');
    }
  }

  /// Get a user by UID
  static Future<AppUser?> getUser(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        return AppUser.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get user: $e');
    }
  }

  /// Get current authenticated user
  static Future<AppUser?> getCurrentUser() async {
    try {
      final firebaseUser = _auth.currentUser;
      if (firebaseUser == null) return null;

      return await getUser(firebaseUser.uid);
    } catch (e) {
      throw Exception('Failed to get current user: $e');
    }
  }

  /// Delete a user
  static Future<void> deleteUser(String uid) async {
    try {
      await _firestore.collection('users').doc(uid).delete();
    } catch (e) {
      throw Exception('Failed to delete user: $e');
    }
  }

  // ==================== USER QUERIES ====================

  /// Get users by role
  static Future<List<AppUser>> getUsersByRole(
    UserRole role, {
    int? limit,
  }) async {
    try {
      Query query = _firestore
          .collection('users')
          .where('role', isEqualTo: role.toString().split('.').last)
          .orderBy('name');

      if (limit != null) {
        query = query.limit(limit);
      }

      final snapshot = await query.get();
      return snapshot.docs.map((doc) => AppUser.fromFirestore(doc)).toList();
    } catch (e) {
      throw Exception('Failed to get users by role: $e');
    }
  }

  /// Get users by designation
  static Future<List<AppUser>> getUsersByDesignation(
    Designation designation, {
    int? limit,
  }) async {
    try {
      Query query = _firestore
          .collection('users')
          .where(
            'designation',
            isEqualTo: designation.toString().split('.').last,
          )
          .orderBy('name');

      if (limit != null) {
        query = query.limit(limit);
      }

      final snapshot = await query.get();
      return snapshot.docs.map((doc) => AppUser.fromFirestore(doc)).toList();
    } catch (e) {
      throw Exception('Failed to get users by designation: $e');
    }
  }

  /// Get users by hierarchy level
  static Future<List<AppUser>> getUsersByHierarchy({
    String? companyId,
    String? stateId,
    String? zoneId,
    String? circleId,
    String? divisionId,
    String? subdivisionId,
    String? substationId,
    int? limit,
  }) async {
    try {
      Query query = _firestore.collection('users');

      if (companyId != null) {
        query = query.where('companyId', isEqualTo: companyId);
      }
      if (stateId != null) {
        query = query.where('stateId', isEqualTo: stateId);
      }
      if (zoneId != null) {
        query = query.where('zoneId', isEqualTo: zoneId);
      }
      if (circleId != null) {
        query = query.where('circleId', isEqualTo: circleId);
      }
      if (divisionId != null) {
        query = query.where('divisionId', isEqualTo: divisionId);
      }
      if (subdivisionId != null) {
        query = query.where('subdivisionId', isEqualTo: subdivisionId);
      }
      if (substationId != null) {
        query = query.where('substationId', isEqualTo: substationId);
      }

      query = query.orderBy('name');

      if (limit != null) {
        query = query.limit(limit);
      }

      final snapshot = await query.get();
      return snapshot.docs.map((doc) => AppUser.fromFirestore(doc)).toList();
    } catch (e) {
      throw Exception('Failed to get users by hierarchy: $e');
    }
  }

  /// Search users by name, email, or mobile
  static Future<List<AppUser>> searchUsers(
    String searchTerm, {
    int? limit,
  }) async {
    try {
      final searchTermLower = searchTerm.toLowerCase();

      // Search by name (using array-contains for partial matching)
      final nameQuery = _firestore
          .collection('users')
          .orderBy('name')
          .startAt([searchTermLower])
          .endAt([searchTermLower + '\uf8ff']);

      // Search by email
      final emailQuery = _firestore
          .collection('users')
          .where('email', isGreaterThanOrEqualTo: searchTermLower)
          .where('email', isLessThanOrEqualTo: searchTermLower + '\uf8ff');

      // Search by mobile
      final mobileQuery = _firestore
          .collection('users')
          .where('mobile', isGreaterThanOrEqualTo: searchTerm)
          .where('mobile', isLessThanOrEqualTo: searchTerm + '\uf8ff');

      // Execute searches in parallel
      final results = await Future.wait([
        nameQuery.get(),
        emailQuery.get(),
        mobileQuery.get(),
      ]);

      // Combine and deduplicate results
      Set<String> seenUids = {};
      List<AppUser> allUsers = [];

      for (final snapshot in results) {
        for (final doc in snapshot.docs) {
          if (!seenUids.contains(doc.id)) {
            seenUids.add(doc.id);
            allUsers.add(AppUser.fromFirestore(doc));
          }
        }
      }

      // Sort by name and apply limit
      allUsers.sort((a, b) => a.name.compareTo(b.name));

      if (limit != null && allUsers.length > limit) {
        allUsers = allUsers.take(limit).toList();
      }

      return allUsers;
    } catch (e) {
      throw Exception('Failed to search users: $e');
    }
  }

  /// Get pending approval users
  static Future<List<AppUser>> getPendingUsers({int? limit}) async {
    try {
      Query query = _firestore
          .collection('users')
          .where('approved', isEqualTo: false)
          .orderBy('createdAt', descending: true);

      if (limit != null) {
        query = query.limit(limit);
      }

      final snapshot = await query.get();
      return snapshot.docs.map((doc) => AppUser.fromFirestore(doc)).toList();
    } catch (e) {
      throw Exception('Failed to get pending users: $e');
    }
  }

  /// Get users with incomplete profiles
  static Future<List<AppUser>> getIncompleteProfiles({int? limit}) async {
    try {
      Query query = _firestore
          .collection('users')
          .where('profileCompleted', isEqualTo: false)
          .orderBy('createdAt', descending: true);

      if (limit != null) {
        query = query.limit(limit);
      }

      final snapshot = await query.get();
      return snapshot.docs.map((doc) => AppUser.fromFirestore(doc)).toList();
    } catch (e) {
      throw Exception('Failed to get incomplete profiles: $e');
    }
  }

  // ==================== USER APPROVAL AND ROLE MANAGEMENT ====================

  /// Approve a user and assign role
  static Future<void> approveUser(
    String uid,
    UserRole role, {
    Map<String, String>? assignedLevels,
  }) async {
    try {
      await _firestore.collection('users').doc(uid).update({
        'approved': true,
        'role': role.toString().split('.').last,
        'assignedLevels': assignedLevels,
        'updatedAt': Timestamp.now(),
      });
    } catch (e) {
      throw Exception('Failed to approve user: $e');
    }
  }

  /// Update user role
  static Future<void> updateUserRole(
    String uid,
    UserRole role, {
    Map<String, String>? assignedLevels,
  }) async {
    try {
      final updateData = {
        'role': role.toString().split('.').last,
        'updatedAt': Timestamp.now(),
      };

      if (assignedLevels != null) {
        updateData['assignedLevels'] = assignedLevels;
      }

      await _firestore.collection('users').doc(uid).update(updateData);
    } catch (e) {
      throw Exception('Failed to update user role: $e');
    }
  }

  /// Suspend/Unsuspend user
  static Future<void> toggleUserSuspension(String uid, bool suspend) async {
    try {
      await _firestore.collection('users').doc(uid).update({
        'approved': !suspend,
        'updatedAt': Timestamp.now(),
      });
    } catch (e) {
      throw Exception('Failed to toggle user suspension: $e');
    }
  }

  // ==================== PROFILE OPERATIONS ====================

  /// Update user profile completion status
  static Future<void> markProfileComplete(String uid) async {
    try {
      await _firestore.collection('users').doc(uid).update({
        'profileCompleted': true,
        'updatedAt': Timestamp.now(),
      });
    } catch (e) {
      throw Exception('Failed to mark profile complete: $e');
    }
  }

  /// Update user's posting information
  static Future<void> updateUserPosting(
    String uid, {
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
  }) async {
    try {
      final updateData = <String, dynamic>{'updatedAt': Timestamp.now()};

      if (companyId != null) updateData['companyId'] = companyId;
      if (companyName != null) updateData['companyName'] = companyName;
      if (stateId != null) updateData['stateId'] = stateId;
      if (stateName != null) updateData['stateName'] = stateName;
      if (zoneId != null) updateData['zoneId'] = zoneId;
      if (zoneName != null) updateData['zoneName'] = zoneName;
      if (circleId != null) updateData['circleId'] = circleId;
      if (circleName != null) updateData['circleName'] = circleName;
      if (divisionId != null) updateData['divisionId'] = divisionId;
      if (divisionName != null) updateData['divisionName'] = divisionName;
      if (subdivisionId != null) updateData['subdivisionId'] = subdivisionId;
      if (subdivisionName != null)
        updateData['subdivisionName'] = subdivisionName;
      if (substationId != null) updateData['substationId'] = substationId;
      if (substationName != null) updateData['substationName'] = substationName;

      await _firestore.collection('users').doc(uid).update(updateData);
    } catch (e) {
      throw Exception('Failed to update user posting: $e');
    }
  }

  // ==================== HIERARCHY HELPERS ====================

  /// Get hierarchy names by IDs
  static Future<Map<String, String>> getHierarchyNames({
    String? companyId,
    String? stateId,
    String? zoneId,
    String? circleId,
    String? divisionId,
    String? subdivisionId,
    String? substationId,
  }) async {
    try {
      Map<String, String> names = {};

      if (companyId != null) {
        final doc = await _firestore
            .collection('companies')
            .doc(companyId)
            .get();
        if (doc.exists) names['companyName'] = doc['name'];
      }

      if (stateId != null) {
        final doc = await _firestore.collection('states').doc(stateId).get();
        if (doc.exists) names['stateName'] = doc['name'];
      }

      if (zoneId != null) {
        final doc = await _firestore.collection('zones').doc(zoneId).get();
        if (doc.exists) names['zoneName'] = doc['name'];
      }

      if (circleId != null) {
        final doc = await _firestore.collection('circles').doc(circleId).get();
        if (doc.exists) names['circleName'] = doc['name'];
      }

      if (divisionId != null) {
        final doc = await _firestore
            .collection('divisions')
            .doc(divisionId)
            .get();
        if (doc.exists) names['divisionName'] = doc['name'];
      }

      if (subdivisionId != null) {
        final doc = await _firestore
            .collection('subdivisions')
            .doc(subdivisionId)
            .get();
        if (doc.exists) names['subdivisionName'] = doc['name'];
      }

      if (substationId != null) {
        final doc = await _firestore
            .collection('substations')
            .doc(substationId)
            .get();
        if (doc.exists) names['substationName'] = doc['name'];
      }

      return names;
    } catch (e) {
      throw Exception('Failed to get hierarchy names: $e');
    }
  }

  // ==================== STATISTICS ====================

  /// Get user statistics
  static Future<Map<String, int>> getUserStatistics() async {
    try {
      final totalQuery = _firestore.collection('users');
      final approvedQuery = _firestore
          .collection('users')
          .where('approved', isEqualTo: true);
      final pendingQuery = _firestore
          .collection('users')
          .where('approved', isEqualTo: false);
      final incompleteQuery = _firestore
          .collection('users')
          .where('profileCompleted', isEqualTo: false);

      final results = await Future.wait([
        totalQuery.count().get(),
        approvedQuery.count().get(),
        pendingQuery.count().get(),
        incompleteQuery.count().get(),
      ]);

      return {
        'total': results[0].count ?? 0,
        'approved': results[1].count ?? 0,
        'pending': results[2].count ?? 0,
        'incomplete': results[3].count ?? 0,
      };
    } catch (e) {
      throw Exception('Failed to get user statistics: $e');
    }
  }

  /// Get role distribution
  static Future<Map<String, int>> getRoleDistribution() async {
    try {
      Map<String, int> distribution = {};

      for (final role in UserRole.values) {
        final query = _firestore
            .collection('users')
            .where('role', isEqualTo: role.toString().split('.').last);

        final snapshot = await query.count().get();
        distribution[role.toString().split('.').last] = snapshot.count ?? 0;
      }

      return distribution;
    } catch (e) {
      throw Exception('Failed to get role distribution: $e');
    }
  }

  /// Get designation distribution
  static Future<Map<String, int>> getDesignationDistribution() async {
    try {
      Map<String, int> distribution = {};

      for (final designation in Designation.values) {
        final query = _firestore
            .collection('users')
            .where(
              'designation',
              isEqualTo: designation.toString().split('.').last,
            );

        final snapshot = await query.count().get();
        distribution[designation.toString().split('.').last] =
            snapshot.count ?? 0;
      }

      return distribution;
    } catch (e) {
      throw Exception('Failed to get designation distribution: $e');
    }
  }

  // ==================== BULK OPERATIONS ====================

  /// Bulk approve users
  static Future<void> bulkApproveUsers(List<String> uids, UserRole role) async {
    try {
      final batch = _firestore.batch();

      for (final uid in uids) {
        final userRef = _firestore.collection('users').doc(uid);
        batch.update(userRef, {
          'approved': true,
          'role': role.toString().split('.').last,
          'updatedAt': Timestamp.now(),
        });
      }

      await batch.commit();
    } catch (e) {
      throw Exception('Failed to bulk approve users: $e');
    }
  }

  /// Bulk update user roles
  static Future<void> bulkUpdateRoles(Map<String, UserRole> userRoles) async {
    try {
      final batch = _firestore.batch();

      userRoles.forEach((uid, role) {
        final userRef = _firestore.collection('users').doc(uid);
        batch.update(userRef, {
          'role': role.toString().split('.').last,
          'updatedAt': Timestamp.now(),
        });
      });

      await batch.commit();
    } catch (e) {
      throw Exception('Failed to bulk update roles: $e');
    }
  }

  // ==================== STREAM SUBSCRIPTIONS ====================

  /// Stream users by role
  static Stream<List<AppUser>> streamUsersByRole(UserRole role) {
    return _firestore
        .collection('users')
        .where('role', isEqualTo: role.toString().split('.').last)
        .orderBy('name')
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => AppUser.fromFirestore(doc)).toList(),
        );
  }

  /// Stream pending users
  static Stream<List<AppUser>> streamPendingUsers() {
    return _firestore
        .collection('users')
        .where('approved', isEqualTo: false)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => AppUser.fromFirestore(doc)).toList(),
        );
  }

  /// Stream user by UID
  static Stream<AppUser?> streamUser(String uid) {
    return _firestore
        .collection('users')
        .doc(uid)
        .snapshots()
        .map((doc) => doc.exists ? AppUser.fromFirestore(doc) : null);
  }

  // ==================== VALIDATION HELPERS ====================

  /// Check if email already exists
  static Future<bool> isEmailExists(String email) async {
    try {
      final query = await _firestore
          .collection('users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      return query.docs.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  /// Check if mobile number already exists
  static Future<bool> isMobileExists(String mobile) async {
    try {
      final query = await _firestore
          .collection('users')
          .where('mobile', isEqualTo: mobile)
          .limit(1)
          .get();

      return query.docs.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  /// Check if SAP ID already exists
  static Future<bool> isSapIdExists(String sapId) async {
    try {
      final query = await _firestore
          .collection('users')
          .where('sapId', isEqualTo: sapId)
          .limit(1)
          .get();

      return query.docs.isNotEmpty;
    } catch (e) {
      return false;
    }
  }
}
