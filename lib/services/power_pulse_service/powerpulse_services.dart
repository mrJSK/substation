import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:io';

import '../../models/hierarchy_models.dart';
import '../../models/power_pulse/powerpulse_models.dart';
import '../../models/user_model.dart';

class PowerPulseServiceException implements Exception {
  final String message;
  PowerPulseServiceException(this.message);
  @override
  String toString() => 'PowerPulseServiceException: $message';
}

class AuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static Stream<User?> get authStateChanges => _auth.authStateChanges();
  static User? get currentUser => _auth.currentUser;
  static Future<UserCredential> signInAnonymously() async {
    try {
      return await _auth.signInAnonymously();
    } catch (e) {
      throw PowerPulseServiceException('Failed to sign in anonymously: $e');
    }
  }

  static Future<UserCredential> signInWithGoogle() async {
    throw UnimplementedError('Implement Google sign-in');
  }

  static Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (e) {
      throw PowerPulseServiceException('Failed to sign out: $e');
    }
  }

  static Future<AppUser?> getCurrentAppUser() async {
    final user = currentUser;
    if (user == null) return null;
    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (doc.exists) return AppUser.fromFirestore(doc);
      return null;
    } catch (e) {
      throw PowerPulseServiceException('Error getting current app user: $e');
    }
  }

  static Future<void> createOrUpdateUserProfile({
    required String uid,
    required String name,
    String? email,
    String? cugNumber,
  }) async {
    try {
      await _firestore.collection('users').doc(uid).set({
        'name': name,
        'email': email ?? currentUser?.email,
        'cugNumber': cugNumber ?? '',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'profileCompleted': true,
      }, SetOptions(merge: true));
    } catch (e) {
      throw PowerPulseServiceException('Failed to update user profile: $e');
    }
  }
}

class PostService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static Future<SharedPreferences> get _prefs async =>
      await SharedPreferences.getInstance();
  static const String _collection = 'posts';

  static Future<String> createPost(CreatePostInput input) async {
    final user = AuthService.currentUser;
    if (user == null)
      throw PowerPulseServiceException('User not authenticated');
    final appUser = await AuthService.getCurrentAppUser();
    final now = Timestamp.now();
    final readingTime = _calculateReadingTimeFromBlocks(input.contentBlocks);

    final postDataForFirestore = {
      'authorId': user.uid,
      'title': input.title.trim(),
      'bodyDelta': input.bodyDelta,
      'bodyPlain': input.serializedContentBlocks,
      'excerpt': input.excerpt.trim(),
      'scope': input.scope.toMap(),
      'score': 0,
      'commentCount': 0,
      'flair': input.flair?.toJson(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'imageUrl': input.imageUrl,
      'authorName': appUser?.name ?? user.displayName ?? 'Anonymous',
      'authorDesignation': appUser?.designationDisplayName,
      'readingTime': readingTime,
    };

    try {
      final docRef = await _firestore
          .collection(_collection)
          .add(postDataForFirestore);

      final cacheData = {
        'id': docRef.id,
        'authorId': user.uid,
        'title': input.title.trim(),
        'bodyDelta': input.bodyDelta,
        'bodyPlain': input.serializedContentBlocks,
        'excerpt': input.excerpt.trim(),
        'scope': input.scope.toMap(),
        'score': 0,
        'commentCount': 0,
        'flair': input.flair?.toJson(),
        'createdAt': now.millisecondsSinceEpoch,
        'updatedAt': now.millisecondsSinceEpoch,
        'imageUrl': input.imageUrl,
        'authorName': appUser?.name ?? user.displayName ?? 'Anonymous',
        'authorDesignation': appUser?.designationDisplayName,
        'readingTime': readingTime,
      };

      final prefs = await _prefs;
      await prefs.setString('post_${docRef.id}', jsonEncode(cacheData));
      await AnalyticsService.logPostCreated(
        docRef.id,
        input.scope.type.toString().split('.').last,
        flair: input.flair?.name,
      );
      return docRef.id;
    } catch (e) {
      throw PowerPulseServiceException('Failed to create post: $e');
    }
  }

  static Future<void> updatePost(String postId, CreatePostInput input) async {
    final user = AuthService.currentUser;
    if (user == null)
      throw PowerPulseServiceException('User not authenticated');
    final postDoc = _firestore.collection(_collection).doc(postId);
    final postSnapshot = await postDoc.get();
    if (!postSnapshot.exists)
      throw PowerPulseServiceException('Post not found');
    final existingPost = Post.fromFirestore(postSnapshot);
    if (existingPost.authorId != user.uid) {
      throw PowerPulseServiceException(
        'User is not authorized to update this post',
      );
    }
    final appUser = await AuthService.getCurrentAppUser();
    final readingTime = _calculateReadingTimeFromBlocks(input.contentBlocks);
    final now = Timestamp.now();

    final updateDataForFirestore = {
      'title': input.title.trim(),
      'bodyDelta': input.bodyDelta,
      'bodyPlain': input.serializedContentBlocks,
      'excerpt': input.excerpt.trim(),
      'scope': input.scope.toMap(),
      'flair': input.flair?.toJson(),
      'updatedAt': FieldValue.serverTimestamp(),
      'authorName': appUser?.name ?? user.displayName ?? 'Anonymous',
      'authorDesignation': appUser?.designationDisplayName,
      'readingTime': readingTime,
    };

    if (input.imageUrl != existingPost.imageUrl) {
      updateDataForFirestore['imageUrl'] = input.imageUrl;
      if (existingPost.imageUrl != null && input.imageUrl != null) {
        try {
          await StorageService.deleteImage(existingPost.imageUrl!);
        } catch (e) {}
      }
    }

    try {
      await postDoc.update(updateDataForFirestore);

      final cacheData = {
        'id': postId,
        'authorId': existingPost.authorId,
        'title': input.title.trim(),
        'bodyDelta': input.bodyDelta,
        'bodyPlain': input.serializedContentBlocks,
        'excerpt': input.excerpt.trim(),
        'scope': input.scope.toMap(),
        'score': existingPost.score,
        'commentCount': existingPost.commentCount,
        'flair': input.flair?.toJson(),
        'createdAt': existingPost.createdAt.millisecondsSinceEpoch,
        'updatedAt': now.millisecondsSinceEpoch,
        'imageUrl': input.imageUrl,
        'authorName': appUser?.name ?? user.displayName ?? 'Anonymous',
        'authorDesignation': appUser?.designationDisplayName,
        'readingTime': readingTime,
      };
      final prefs = await _prefs;
      await prefs.setString('post_$postId', jsonEncode(cacheData));
    } catch (e) {
      throw PowerPulseServiceException('Failed to update post: $e');
    }
  }

  static String _calculateReadingTimeFromBlocks(List<ContentBlock> blocks) {
    final wordCount = blocks.fold(0, (sum, block) => sum + block.wordCount);
    final minutes = (wordCount / 200).ceil();
    return minutes == 0 ? '1 min read' : '$minutes min read';
  }

  static String _calculateReadingTime(String text) {
    final wordCount = text.split(RegExp(r'\s+')).length;
    final minutes = (wordCount / 200).ceil();
    return minutes == 0 ? '1 min read' : '$minutes min read';
  }

  static Stream<List<Post>> streamPublicPosts({int limit = 20}) {
    return _firestore
        .collection(_collection)
        .where('scope.type', isEqualTo: 'public')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .asyncMap((snapshot) async {
          final prefs = await _prefs;
          return snapshot.docs.map((doc) {
            final post = Post.fromFirestore(doc);
            final cacheData = _createCacheSafePostDataFromDoc(doc, post);
            prefs.setString('post_${doc.id}', jsonEncode(cacheData));
            return post;
          }).toList();
        });
  }

  static Stream<List<Post>> streamZonePosts(String zoneId, {int limit = 20}) {
    return _firestore
        .collection(_collection)
        .where('scope.type', isEqualTo: 'zone')
        .where('scope.zoneId', isEqualTo: zoneId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .asyncMap((snapshot) async {
          final prefs = await _prefs;
          return snapshot.docs.map((doc) {
            final post = Post.fromFirestore(doc);
            final cacheData = _createCacheSafePostDataFromDoc(doc, post);
            prefs.setString('post_${doc.id}', jsonEncode(cacheData));
            return post;
          }).toList();
        });
  }

  static Stream<List<Post>> streamTopPosts({int limit = 20, String? zoneId}) {
    Query<Map<String, dynamic>> query = _firestore.collection(_collection);
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
        .asyncMap((snapshot) async {
          final prefs = await _prefs;
          return snapshot.docs.map((doc) {
            final post = Post.fromFirestore(doc);
            final cacheData = _createCacheSafePostDataFromDoc(doc, post);
            prefs.setString('post_${doc.id}', jsonEncode(cacheData));
            return post;
          }).toList();
        });
  }

  static Map<String, dynamic> _createCacheSafePostDataFromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
    Post post,
  ) {
    final data = doc.data()!;
    final cache = <String, dynamic>{};
    data.forEach((key, value) {
      if (value is Timestamp) {
        cache[key] = value.millisecondsSinceEpoch;
      } else {
        cache[key] = value;
      }
    });
    cache['id'] = doc.id;
    cache['bodyDelta'] = cache['bodyDelta']?.toString() ?? '';
    cache['bodyPlain'] = cache['bodyPlain']?.toString() ?? '';
    cache['excerpt'] = cache['excerpt']?.toString() ?? '';
    cache['readingTime'] = cache['readingTime']?.toString() ?? '1 min read';
    return cache;
  }

  static Future<Post?> getPost(String postId) async {
    try {
      final prefs = await _prefs;
      final cachedPost = prefs.getString('post_$postId');
      if (cachedPost != null) {
        try {
          return Post.fromJson(jsonDecode(cachedPost) as Map<String, dynamic>);
        } catch (e) {}
      }
      final doc = await _firestore.collection(_collection).doc(postId).get();
      if (doc.exists) {
        final post = Post.fromFirestore(doc);
        final cacheData = _createCacheSafePostDataFromDoc(doc, post);
        await prefs.setString('post_$postId', jsonEncode(cacheData));
        return post;
      }
      return null;
    } catch (e) {
      throw PowerPulseServiceException('Error getting post: $e');
    }
  }

  static Stream<Post?> streamPost(String postId) {
    return _firestore.collection(_collection).doc(postId).snapshots().asyncMap((
      doc,
    ) async {
      if (doc.exists) {
        final post = Post.fromFirestore(doc);
        final prefs = await _prefs;
        final cacheData = _createCacheSafePostDataFromDoc(doc, post);
        await prefs.setString('post_$postId', jsonEncode(cacheData));
        return post;
      }
      return null;
    });
  }

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
        .asyncMap((snapshot) async {
          final prefs = await _prefs;
          return snapshot.docs.map((doc) {
            final post = Post.fromFirestore(doc);
            final cacheData = _createCacheSafePostDataFromDoc(doc, post);
            prefs.setString('post_${doc.id}', jsonEncode(cacheData));
            return post;
          }).toList();
        });
  }

  static Future<List<Post>> searchPosts(String query, {int limit = 20}) async {
    if (query.trim().isEmpty) return [];
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .where('title', isGreaterThanOrEqualTo: query)
          .where('title', isLessThan: query + 'z')
          .orderBy('title')
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();
      final prefs = await _prefs;
      return snapshot.docs.map((doc) {
        final post = Post.fromFirestore(doc);
        final cacheData = _createCacheSafePostDataFromDoc(doc, post);
        prefs.setString('post_${doc.id}', jsonEncode(cacheData));
        return post;
      }).toList();
    } catch (e) {
      throw PowerPulseServiceException('Error searching posts: $e');
    }
  }

  static Future<void> deletePost(String postId) async {
    final user = AuthService.currentUser;
    if (user == null)
      throw PowerPulseServiceException('User not authenticated');
    final post = await getPost(postId);
    if (post == null) throw PowerPulseServiceException('Post not found');
    if (post.authorId != user.uid)
      throw PowerPulseServiceException('Not authorized to delete this post');
    try {
      final batch = _firestore.batch();
      batch.delete(_firestore.collection(_collection).doc(postId));
      if (post.imageUrl != null)
        await StorageService.deleteImage(post.imageUrl!);
      await batch.commit();
      final prefs = await _prefs;
      await prefs.remove('post_$postId');
    } catch (e) {
      throw PowerPulseServiceException('Failed to delete post: $e');
    }
  }

  static Stream<List<Comment>> streamComments(String postId, {int limit = 50}) {
    return _firestore
        .collection('comments')
        .where('postId', isEqualTo: postId)
        .orderBy('createdAt', descending: false)
        .limit(limit)
        .snapshots()
        .asyncMap((snapshot) async {
          final prefs = await _prefs;
          return snapshot.docs.map((doc) {
            final comment = Comment.fromFirestore(doc);
            final cacheData = _createCacheSafeCommentData(doc, comment);
            prefs.setString('comment_${doc.id}', jsonEncode(cacheData));
            return comment;
          }).toList();
        });
  }

  static Map<String, dynamic> _createCacheSafeCommentData(
    DocumentSnapshot<Map<String, dynamic>> doc,
    Comment comment,
  ) {
    final data = doc.data()!;
    final cache = <String, dynamic>{};
    data.forEach((key, value) {
      if (value is Timestamp) {
        cache[key] = value.millisecondsSinceEpoch;
      } else {
        cache[key] = value;
      }
    });
    cache['id'] = doc.id;
    cache['bodyDelta'] = cache['bodyDelta']?.toString() ?? '';
    cache['bodyPlain'] = cache['bodyPlain']?.toString() ?? '';
    return cache;
  }
}

class CommentService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static Future<SharedPreferences> get _prefs async =>
      await SharedPreferences.getInstance();
  static const String _collection = 'comments';

  static Future<String> addComment(CreateCommentInput input) async {
    final user = AuthService.currentUser;
    if (user == null)
      throw PowerPulseServiceException('User not authenticated');
    final appUser = await AuthService.getCurrentAppUser();
    final now = Timestamp.now();
    final commentData = {
      'postId': input.postId,
      'authorId': user.uid,
      'bodyDelta': input.bodyDelta,
      'bodyPlain': input.bodyPlain.trim(),
      'parentId': input.parentId,
      'score': 0,
      'createdAt': FieldValue.serverTimestamp(),
      'authorName': appUser?.name ?? user.displayName ?? 'Anonymous',
      'authorDesignation': appUser?.designationDisplayName,
    };
    try {
      final batch = _firestore.batch();
      final commentRef = _firestore.collection(_collection).doc();
      batch.set(commentRef, commentData);
      batch.update(_firestore.collection('posts').doc(input.postId), {
        'commentCount': FieldValue.increment(1),
      });
      await batch.commit();
      final cacheData = {
        'id': commentRef.id,
        'postId': input.postId,
        'authorId': user.uid,
        'bodyDelta': input.bodyDelta,
        'bodyPlain': input.bodyPlain.trim(),
        'parentId': input.parentId,
        'score': 0,
        'createdAt': now.millisecondsSinceEpoch,
        'authorName': appUser?.name ?? user.displayName ?? 'Anonymous',
        'authorDesignation': appUser?.designationDisplayName,
      };
      final prefs = await _prefs;
      await prefs.setString('comment_${commentRef.id}', jsonEncode(cacheData));
      await AnalyticsService.logComment(input.postId);
      return commentRef.id;
    } catch (e) {
      throw PowerPulseServiceException('Failed to add comment: $e');
    }
  }

  static Future<Comment?> getComment(String commentId) async {
    try {
      final prefs = await _prefs;
      final cachedComment = prefs.getString('comment_$commentId');
      if (cachedComment != null) {
        try {
          return Comment.fromJson(
            jsonDecode(cachedComment) as Map<String, dynamic>,
          );
        } catch (e) {}
      }
      final doc = await _firestore.collection(_collection).doc(commentId).get();
      if (doc.exists) {
        final comment = Comment.fromFirestore(doc);
        final cacheData = PostService._createCacheSafeCommentData(doc, comment);
        await prefs.setString('comment_$commentId', jsonEncode(cacheData));
        return comment;
      }
      return null;
    } catch (e) {
      throw PowerPulseServiceException('Error getting comment: $e');
    }
  }

  static Future<void> deleteComment(String commentId) async {
    final user = AuthService.currentUser;
    if (user == null)
      throw PowerPulseServiceException('User not authenticated');
    final comment = await getComment(commentId);
    if (comment == null) throw PowerPulseServiceException('Comment not found');
    if (comment.authorId != user.uid)
      throw PowerPulseServiceException('Not authorized to delete this comment');
    try {
      final batch = _firestore.batch();
      batch.delete(_firestore.collection(_collection).doc(commentId));
      batch.update(_firestore.collection('posts').doc(comment.postId), {
        'commentCount': FieldValue.increment(-1),
      });
      await batch.commit();
      final prefs = await _prefs;
      await prefs.remove('comment_$commentId');
    } catch (e) {
      throw PowerPulseServiceException('Failed to delete comment: $e');
    }
  }
}

class VoteService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collection = 'votes';

  static Future<void> setVote({
    String? postId,
    String? commentId,
    required int value,
  }) async {
    final user = AuthService.currentUser;
    if (user == null)
      throw PowerPulseServiceException('User not authenticated');
    if (postId == null && commentId == null)
      throw PowerPulseServiceException(
        'Either postId or commentId must be provided',
      );
    final voteId = postId != null
        ? Vote.generateId(postId: postId, userId: user.uid)
        : Vote.generateId(commentId: commentId!, userId: user.uid);
    final parentId = postId ?? commentId!;
    final parentCollection = postId != null ? 'posts' : 'comments';
    try {
      final batch = _firestore.batch();
      if (value == 0) {
        batch.delete(_firestore.collection(_collection).doc(voteId));
      } else {
        final voteData = {
          if (postId != null) 'postId': postId,
          if (commentId != null) 'commentId': commentId,
          'userId': user.uid,
          'value': value,
          'createdAt': FieldValue.serverTimestamp(),
        };
        batch.set(_firestore.collection(_collection).doc(voteId), voteData);
      }
      final currentVote = await getUserVote(
        postId: postId,
        commentId: commentId,
      );
      final scoreDelta = value - (currentVote?.value ?? 0);
      batch.update(_firestore.collection(parentCollection).doc(parentId), {
        'score': FieldValue.increment(scoreDelta),
      });
      await batch.commit();
      await AnalyticsService.logVote(parentId, value);
    } catch (e) {
      throw PowerPulseServiceException('Failed to set vote: $e');
    }
  }

  static Future<Vote?> getUserVote({String? postId, String? commentId}) async {
    final user = AuthService.currentUser;
    if (user == null) return null;
    if (postId == null && commentId == null) return null;
    try {
      final voteId = postId != null
          ? Vote.generateId(postId: postId, userId: user.uid)
          : Vote.generateId(commentId: commentId!, userId: user.uid);
      final doc = await _firestore.collection(_collection).doc(voteId).get();
      if (doc.exists) {
        return Vote.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      throw PowerPulseServiceException('Error getting user vote: $e');
    }
  }

  static Stream<Vote?> streamUserVote({String? postId, String? commentId}) {
    final user = AuthService.currentUser;
    if (user == null) return Stream.value(null);
    if (postId == null && commentId == null) return Stream.value(null);
    final voteId = postId != null
        ? Vote.generateId(postId: postId, userId: user.uid)
        : Vote.generateId(commentId: commentId!, userId: user.uid);
    return _firestore
        .collection(_collection)
        .doc(voteId)
        .snapshots()
        .map((doc) => doc.exists ? Vote.fromFirestore(doc) : null);
  }
}

class HierarchyService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static Future<List<Zone>> getZones() async {
    try {
      final snapshot = await _firestore
          .collection('zones')
          .orderBy('name')
          .get();
      return snapshot.docs.map((doc) => Zone.fromFirestore(doc)).toList();
    } catch (e) {
      throw PowerPulseServiceException('Error getting zones: $e');
    }
  }

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

  static Future<Zone?> getZone(String zoneId) async {
    try {
      final doc = await _firestore.collection('zones').doc(zoneId).get();
      if (doc.exists) {
        return Zone.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      throw PowerPulseServiceException('Error getting zone: $e');
    }
  }

  static Future<List<Circle>> getCirclesByZone(String zoneId) async {
    try {
      final snapshot = await _firestore
          .collection('circles')
          .where('zoneId', isEqualTo: zoneId)
          .orderBy('name')
          .get();
      return snapshot.docs.map((doc) => Circle.fromFirestore(doc)).toList();
    } catch (e) {
      throw PowerPulseServiceException('Error getting circles: $e');
    }
  }

  static Future<List<Division>> getDivisionsByCircle(String circleId) async {
    try {
      final snapshot = await _firestore
          .collection('divisions')
          .where('circleId', isEqualTo: circleId)
          .orderBy('name')
          .get();
      return snapshot.docs.map((doc) => Division.fromFirestore(doc)).toList();
    } catch (e) {
      throw PowerPulseServiceException('Error getting divisions: $e');
    }
  }

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
      throw PowerPulseServiceException('Error getting subdivisions: $e');
    }
  }

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
      throw PowerPulseServiceException('Error getting substations: $e');
    }
  }
}

class StorageService {
  static final FirebaseStorage _storage = FirebaseStorage.instance;
  static Future<String> uploadImage(File imageFile, String folder) async {
    try {
      final user = AuthService.currentUser;
      if (user == null)
        throw PowerPulseServiceException('User not authenticated');
      final fileName =
          '${DateTime.now().millisecondsSinceEpoch}_${imageFile.path.split('/').last}';
      final ref = _storage.ref().child('$folder/${user.uid}/$fileName');
      final uploadTask = ref.putFile(imageFile);
      final snapshot = await uploadTask.whenComplete(() {});
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      throw PowerPulseServiceException('Error uploading image: $e');
    }
  }

  static Future<String> uploadPostImage(File imageFile) async {
    return uploadImage(imageFile, 'posts');
  }

  static Future<void> deleteImage(String imageUrl) async {
    try {
      final ref = _storage.refFromURL(imageUrl);
      await ref.delete();
    } catch (e) {
      throw PowerPulseServiceException('Error deleting image: $e');
    }
  }
}

class AnalyticsService {
  static Future<void> logPostView(String postId) async {}
  static Future<void> logPostCreated(
    String postId,
    String scope, {
    String? flair,
  }) async {}
  static Future<void> logVote(String id, int value) async {}
  static Future<void> logComment(String postId) async {}
}
