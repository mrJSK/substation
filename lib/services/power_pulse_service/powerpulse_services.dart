// lib/services/powerpulse_services.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';

import '../../models/hierarchy_models.dart';
import '../../models/power_pulse/powerpulse_models.dart';
import '../../models/user_model.dart';

/// ---------------------------------------------------------------------------
/// Authentication Service
/// ---------------------------------------------------------------------------
class AuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Current user stream
  static Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Current user
  static User? get currentUser => _auth.currentUser;

  // Sign in anonymously
  static Future<UserCredential> signInAnonymously() async {
    return await _auth.signInAnonymously();
  }

  // Sign in with Google (implement based on your existing auth flow)
  static Future<UserCredential?> signInWithGoogle() async {
    // Implement Google sign-in based on your existing setup
    throw UnimplementedError('Implement Google sign-in');
  }

  // Sign out
  static Future<void> signOut() async {
    await _auth.signOut();
  }

  // Get current app user
  static Future<AppUser?> getCurrentAppUser() async {
    final user = currentUser;
    if (user == null) return null;

    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (doc.exists) {
        return AppUser.fromFirestore(doc);
      }
    } catch (e) {
      print('Error getting current app user: $e');
    }
    return null;
  }

  // Create or update user profile
  static Future<void> createOrUpdateUserProfile({
    required String uid,
    required String name,
    String? email,
    String? cugNumber,
  }) async {
    await _firestore.collection('users').doc(uid).set({
      'name': name,
      'email': email ?? currentUser?.email,
      'cugNumber': cugNumber ?? '',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'profileCompleted': true,
    }, SetOptions(merge: true));
  }
}

/// ---------------------------------------------------------------------------
/// Post Service
/// ---------------------------------------------------------------------------
class PostService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collection = 'posts';

  // Create a new post
  static Future<String> createPost(CreatePostInput input) async {
    final user = AuthService.currentUser;
    if (user == null) throw Exception('User not authenticated');

    // Get author info
    final appUser = await AuthService.getCurrentAppUser();

    final postData = {
      'authorId': user.uid,
      'title': input.title.trim(),
      'bodyDelta': input.bodyDelta,
      'bodyPlain': input.bodyPlain.trim(),
      'scope': input.scope.toMap(),
      'score': 0,
      'commentCount': 0,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'imageUrl': input.imageUrl,
      'authorName': appUser?.name ?? user.displayName ?? 'Anonymous',
      'authorDesignation': appUser?.designationDisplayName,
    };

    final docRef = await _firestore.collection(_collection).add(postData);
    return docRef.id;
  }

  // Update an existing post
  static Future<void> updatePost(String postId, CreatePostInput input) async {
    final user = AuthService.currentUser;
    if (user == null) throw Exception('User not authenticated');

    final postDoc = _firestore.collection(_collection).doc(postId);
    final postSnapshot = await postDoc.get();
    if (!postSnapshot.exists) throw Exception('Post not found');

    final existingPost = Post.fromFirestore(postSnapshot);
    if (existingPost.authorId != user.uid) {
      throw Exception('User is not authorized to update this post');
    }

    final appUser = await AuthService.getCurrentAppUser();

    final updateData = {
      'title': input.title.trim(),
      'bodyDelta': input.bodyDelta,
      'bodyPlain': input.bodyPlain.trim(),
      'scope': input.scope.toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
      'authorName': appUser?.name ?? user.displayName ?? 'Anonymous',
      'authorDesignation': appUser?.designationDisplayName,
    };

    // Update image URL only if it changed
    if (input.imageUrl != existingPost.imageUrl) {
      updateData['imageUrl'] = input.imageUrl;

      // Delete old image if replacing with new one
      if (existingPost.imageUrl != null && input.imageUrl != null) {
        try {
          await StorageService.deleteImage(existingPost.imageUrl!);
        } catch (e) {
          print('Failed to delete old image: $e');
        }
      }
    }

    await postDoc.update(updateData);
    AnalyticsService.logPostCreated(postId, 'updated');
  }

  // Stream public posts
  static Stream<List<Post>> streamPublicPosts({int limit = 20}) {
    return _firestore
        .collection(_collection)
        .where('scope.type', isEqualTo: 'public')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => Post.fromFirestore(doc)).toList(),
        );
  }

  // Stream zone posts
  static Stream<List<Post>> streamZonePosts(String zoneId, {int limit = 20}) {
    return _firestore
        .collection(_collection)
        .where('scope.type', isEqualTo: 'zone')
        .where('scope.zoneId', isEqualTo: zoneId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => Post.fromFirestore(doc)).toList(),
        );
  }

  // Stream top posts (by score)
  static Stream<List<Post>> streamTopPosts({int limit = 20, String? zoneId}) {
    Query query = _firestore.collection(_collection);

    if (zoneId != null) {
      query = query
          .where('scope.type', isEqualTo: 'zone')
          .where('scope.zoneId', isEqualTo: zoneId);
    } else {
      query = query.where('scope.type', isEqualTo: 'public');
    }

    return query
        .orderBy('score', descending: true)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => Post.fromFirestore(doc)).toList(),
        );
  }

  // Get single post
  static Future<Post?> getPost(String postId) async {
    try {
      final doc = await _firestore.collection(_collection).doc(postId).get();
      if (doc.exists) {
        return Post.fromFirestore(doc);
      }
    } catch (e) {
      print('Error getting post: $e');
    }
    return null;
  }

  // Stream single post (for real-time updates)
  static Stream<Post?> streamPost(String postId) {
    return _firestore
        .collection(_collection)
        .doc(postId)
        .snapshots()
        .map((doc) => doc.exists ? Post.fromFirestore(doc) : null);
  }

  // Get posts by author
  static Stream<List<Post>> streamPostsByAuthor(
    String authorId, {
    int limit = 20,
  }) {
    return _firestore
        .collection(_collection)
        .where('authorId', isEqualTo: authorId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => Post.fromFirestore(doc)).toList(),
        );
  }

  // Search posts by title
  static Future<List<Post>> searchPosts(String query, {int limit = 20}) async {
    if (query.trim().isEmpty) return [];

    try {
      // Simple title-based search (you can enhance with Algolia later)
      final snapshot = await _firestore
          .collection(_collection)
          .where('title', isGreaterThanOrEqualTo: query)
          .where('title', isLessThan: query + 'z')
          .orderBy('title')
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs.map((doc) => Post.fromFirestore(doc)).toList();
    } catch (e) {
      print('Error searching posts: $e');
      return [];
    }
  }

  // Delete post (author only)
  static Future<void> deletePost(String postId) async {
    final user = AuthService.currentUser;
    if (user == null) throw Exception('User not authenticated');

    final post = await getPost(postId);
    if (post == null) throw Exception('Post not found');
    if (post.authorId != user.uid)
      throw Exception('Not authorized to delete this post');

    // Delete associated image if exists
    if (post.imageUrl != null) {
      try {
        await StorageService.deleteImage(post.imageUrl!);
      } catch (e) {
        print('Failed to delete post image: $e');
      }
    }

    await _firestore.collection(_collection).doc(postId).delete();
  }
}

/// ---------------------------------------------------------------------------
/// Comment Service
/// ---------------------------------------------------------------------------
class CommentService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collection = 'comments';

  // Add comment
  static Future<String> addComment(CreateCommentInput input) async {
    final user = AuthService.currentUser;
    if (user == null) throw Exception('User not authenticated');

    // Get author info
    final appUser = await AuthService.getCurrentAppUser();

    final commentData = {
      'postId': input.postId,
      'authorId': user.uid,
      'bodyDelta': input.bodyDelta,
      'bodyPlain': input.bodyPlain.trim(),
      'parentId': input.parentId,
      'createdAt': FieldValue.serverTimestamp(),
      'authorName': appUser?.name ?? user.displayName ?? 'Anonymous',
      'authorDesignation': appUser?.designationDisplayName,
    };

    final docRef = await _firestore.collection(_collection).add(commentData);

    // Increment comment count on post
    await _firestore.collection('posts').doc(input.postId).update({
      'commentCount': FieldValue.increment(1),
    });

    return docRef.id;
  }

  // Stream comments for a post
  static Stream<List<Comment>> streamComments(String postId, {int limit = 50}) {
    return _firestore
        .collection(_collection)
        .where('postId', isEqualTo: postId)
        .where('parentId', isNull: true) // Top-level comments only for MVP
        .orderBy('createdAt', descending: false)
        .limit(limit)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => Comment.fromFirestore(doc)).toList(),
        );
  }

  // Get comment by ID
  static Future<Comment?> getComment(String commentId) async {
    try {
      final doc = await _firestore.collection(_collection).doc(commentId).get();
      if (doc.exists) {
        return Comment.fromFirestore(doc);
      }
    } catch (e) {
      print('Error getting comment: $e');
    }
    return null;
  }

  // Delete comment (author only)
  static Future<void> deleteComment(String commentId) async {
    final user = AuthService.currentUser;
    if (user == null) throw Exception('User not authenticated');

    final comment = await getComment(commentId);
    if (comment == null) throw Exception('Comment not found');
    if (comment.authorId != user.uid)
      throw Exception('Not authorized to delete this comment');

    await _firestore.collection(_collection).doc(commentId).delete();

    // Decrement comment count on post
    await _firestore.collection('posts').doc(comment.postId).update({
      'commentCount': FieldValue.increment(-1),
    });
  }
}

/// ---------------------------------------------------------------------------
/// Vote Service
/// ---------------------------------------------------------------------------
class VoteService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collection = 'votes';

  // Set vote (upvote = 1, downvote = -1, remove = 0)
  static Future<void> setVote(String postId, int value) async {
    final user = AuthService.currentUser;
    if (user == null) throw Exception('User not authenticated');

    final voteId = Vote.generateId(postId, user.uid);

    if (value == 0) {
      // Remove vote
      await _firestore.collection(_collection).doc(voteId).delete();
    } else {
      // Set/update vote
      final voteData = {
        'postId': postId,
        'userId': user.uid,
        'value': value,
        'createdAt': FieldValue.serverTimestamp(),
      };

      await _firestore.collection(_collection).doc(voteId).set(voteData);
    }
  }

  // Get user's vote for a post
  static Future<Vote?> getUserVote(String postId) async {
    final user = AuthService.currentUser;
    if (user == null) return null;

    try {
      final voteId = Vote.generateId(postId, user.uid);
      final doc = await _firestore.collection(_collection).doc(voteId).get();
      if (doc.exists) {
        return Vote.fromFirestore(doc);
      }
    } catch (e) {
      print('Error getting user vote: $e');
    }
    return null;
  }

  // Stream user's vote for a post
  static Stream<Vote?> streamUserVote(String postId) {
    final user = AuthService.currentUser;
    if (user == null) return Stream.value(null);

    final voteId = Vote.generateId(postId, user.uid);
    return _firestore
        .collection(_collection)
        .doc(voteId)
        .snapshots()
        .map((doc) => doc.exists ? Vote.fromFirestore(doc) : null);
  }
}

/// ---------------------------------------------------------------------------
/// Hierarchy Service
/// ---------------------------------------------------------------------------
class HierarchyService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get all zones
  static Future<List<Zone>> getZones() async {
    try {
      final snapshot = await _firestore
          .collection('zones')
          .orderBy('name')
          .get();

      return snapshot.docs.map((doc) => Zone.fromFirestore(doc)).toList();
    } catch (e) {
      print('Error getting zones: $e');
      return [];
    }
  }

  // Stream zones
  static Stream<List<Zone>> streamZones() {
    return _firestore
        .collection('zones')
        .orderBy('name')
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => Zone.fromFirestore(doc)).toList(),
        );
  }

  // Get zone by ID
  static Future<Zone?> getZone(String zoneId) async {
    try {
      final doc = await _firestore.collection('zones').doc(zoneId).get();
      if (doc.exists) {
        return Zone.fromFirestore(doc);
      }
    } catch (e) {
      print('Error getting zone: $e');
    }
    return null;
  }

  // Get circles in a zone
  static Future<List<Circle>> getCirclesByZone(String zoneId) async {
    try {
      final snapshot = await _firestore
          .collection('circles')
          .where('zoneId', isEqualTo: zoneId)
          .orderBy('name')
          .get();

      return snapshot.docs.map((doc) => Circle.fromFirestore(doc)).toList();
    } catch (e) {
      print('Error getting circles: $e');
      return [];
    }
  }

  // Get divisions in a circle
  static Future<List<Division>> getDivisionsByCircle(String circleId) async {
    try {
      final snapshot = await _firestore
          .collection('divisions')
          .where('circleId', isEqualTo: circleId)
          .orderBy('name')
          .get();

      return snapshot.docs.map((doc) => Division.fromFirestore(doc)).toList();
    } catch (e) {
      print('Error getting divisions: $e');
      return [];
    }
  }

  // Get subdivisions in a division
  static Future<List<Subdivision>> getSubdivisionsByDivision(
    String divisionId,
  ) async {
    try {
      final snapshot = await _firestore
          .collection('subdivisions')
          .where('divisionId', isEqualTo: divisionId)
          .orderBy('name')
          .get();

      return snapshot.docs
          .map((doc) => Subdivision.fromFirestore(doc))
          .toList();
    } catch (e) {
      print('Error getting subdivisions: $e');
      return [];
    }
  }

  // Get substations in a subdivision
  static Future<List<Substation>> getSubstationsBySubdivision(
    String subdivisionId,
  ) async {
    try {
      final snapshot = await _firestore
          .collection('substations')
          .where('subdivisionId', isEqualTo: subdivisionId)
          .orderBy('name')
          .get();

      return snapshot.docs.map((doc) => Substation.fromFirestore(doc)).toList();
    } catch (e) {
      print('Error getting substations: $e');
      return [];
    }
  }
}

/// ---------------------------------------------------------------------------
/// Storage Service
/// ---------------------------------------------------------------------------
class StorageService {
  static final FirebaseStorage _storage = FirebaseStorage.instance;

  // Upload image and return download URL
  static Future<String> uploadImage(File imageFile, String folder) async {
    try {
      final user = AuthService.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final fileName =
          '${DateTime.now().millisecondsSinceEpoch}_${imageFile.path.split('/').last}';
      final ref = _storage.ref().child('$folder/${user.uid}/$fileName');

      final uploadTask = ref.putFile(imageFile);
      final snapshot = await uploadTask.whenComplete(() {});

      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      print('Error uploading image: $e');
      rethrow;
    }
  }

  // Upload post header image
  static Future<String> uploadPostImage(File imageFile) async {
    return uploadImage(imageFile, 'posts');
  }

  // Delete image
  static Future<void> deleteImage(String imageUrl) async {
    try {
      final ref = _storage.refFromURL(imageUrl);
      await ref.delete();
    } catch (e) {
      print('Error deleting image: $e');
    }
  }
}

/// ---------------------------------------------------------------------------
/// Analytics Service (Optional)
/// ---------------------------------------------------------------------------
class AnalyticsService {
  // Log post view
  static Future<void> logPostView(String postId) async {
    // Implement analytics tracking (Firebase Analytics, etc.)
    print('Post viewed: $postId');
  }

  // Log post created
  static Future<void> logPostCreated(String postId, String scope) async {
    print('Post created: $postId, scope: $scope');
  }

  // Log vote
  static Future<void> logVote(String postId, int value) async {
    print('Vote: $postId, value: $value');
  }

  // Log comment
  static Future<void> logComment(String postId) async {
    print('Comment added to post: $postId');
  }
}
