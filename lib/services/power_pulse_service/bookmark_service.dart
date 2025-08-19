// lib/services/bookmark_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/power_pulse/bookmark_models.dart';
import 'powerpulse_services.dart';

class BookmarkService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _listsCollection = 'bookmark_lists';
  static const String _bookmarksCollection = 'bookmarks';

  // Bookmark Lists Management
  static Future<BookmarkList> createList({
    required String name,
    required String description,
    String? color,
  }) async {
    final user = AuthService.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }

    final now = Timestamp.now();
    final listData = {
      'name': name.trim(),
      'description': description.trim(),
      'userId': user.uid,
      'createdAt': now,
      'updatedAt': now,
      'bookmarkCount': 0,
      'color': color,
      'isDefault': false,
    };

    try {
      final docRef = await _firestore
          .collection(_listsCollection)
          .add(listData);
      return BookmarkList(
        id: docRef.id,
        name: name.trim(),
        description: description.trim(),
        userId: user.uid,
        createdAt: now,
        updatedAt: now,
        color: color,
      );
    } catch (e) {
      throw Exception('Failed to create bookmark list: $e');
    }
  }

  static Future<BookmarkList> getOrCreateDefaultList() async {
    final user = AuthService.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }

    // Check if default list exists
    final snapshot = await _firestore
        .collection(_listsCollection)
        .where('userId', isEqualTo: user.uid)
        .where('isDefault', isEqualTo: true)
        .limit(1)
        .get();

    if (snapshot.docs.isNotEmpty) {
      return BookmarkList.fromFirestore(snapshot.docs.first);
    }

    // Create default list
    final now = Timestamp.now();
    final listData = {
      'name': 'Saved',
      'description': 'Your saved posts',
      'userId': user.uid,
      'createdAt': now,
      'updatedAt': now,
      'bookmarkCount': 0,
      'color': '#2196F3', // Blue color
      'isDefault': true,
    };

    final docRef = await _firestore.collection(_listsCollection).add(listData);
    return BookmarkList(
      id: docRef.id,
      name: 'Saved',
      description: 'Your saved posts',
      userId: user.uid,
      createdAt: now,
      updatedAt: now,
      color: '#2196F3',
      isDefault: true,
    );
  }

  static Stream<List<BookmarkList>> streamUserLists() {
    final user = AuthService.currentUser;
    if (user == null) return Stream.value([]);

    return _firestore
        .collection(_listsCollection)
        .where('userId', isEqualTo: user.uid)
        .orderBy('isDefault', descending: true)
        .orderBy('name')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => BookmarkList.fromFirestore(doc))
              .toList(),
        );
  }

  static Future<void> updateList(
    String listId, {
    String? name,
    String? description,
    String? color,
  }) async {
    final updateData = <String, dynamic>{'updatedAt': Timestamp.now()};

    if (name != null) updateData['name'] = name.trim();
    if (description != null) updateData['description'] = description.trim();
    if (color != null) updateData['color'] = color;

    try {
      await _firestore
          .collection(_listsCollection)
          .doc(listId)
          .update(updateData);
    } catch (e) {
      throw Exception('Failed to update list: $e');
    }
  }

  static Future<void> deleteList(String listId) async {
    final user = AuthService.currentUser;
    if (user == null) throw Exception('User not authenticated');

    try {
      // Get the list to check if it's default
      final listDoc = await _firestore
          .collection(_listsCollection)
          .doc(listId)
          .get();
      if (!listDoc.exists) throw Exception('List not found');

      final list = BookmarkList.fromFirestore(listDoc);
      if (list.isDefault) {
        throw Exception('Cannot delete default list');
      }

      final batch = _firestore.batch();

      // Delete all bookmarks in this list
      final bookmarksSnapshot = await _firestore
          .collection(_bookmarksCollection)
          .where('listId', isEqualTo: listId)
          .get();

      for (final doc in bookmarksSnapshot.docs) {
        batch.delete(doc.reference);
      }

      // Delete the list
      batch.delete(_firestore.collection(_listsCollection).doc(listId));

      await batch.commit();
    } catch (e) {
      throw Exception('Failed to delete list: $e');
    }
  }

  // Bookmark Management
  static Future<void> addBookmark({
    required String postId,
    required String listId,
    String? note,
  }) async {
    final user = AuthService.currentUser;
    if (user == null) throw Exception('User not authenticated');

    final bookmarkId = Bookmark.generateId(
      postId: postId,
      userId: user.uid,
      listId: listId,
    );

    try {
      final batch = _firestore.batch();

      // Add bookmark
      final bookmarkData = {
        'postId': postId,
        'userId': user.uid,
        'listId': listId,
        'createdAt': Timestamp.now(),
        'note': note,
      };

      batch.set(
        _firestore.collection(_bookmarksCollection).doc(bookmarkId),
        bookmarkData,
      );

      // Increment bookmark count in list
      batch.update(_firestore.collection(_listsCollection).doc(listId), {
        'bookmarkCount': FieldValue.increment(1),
        'updatedAt': Timestamp.now(),
      });

      await batch.commit();
    } catch (e) {
      throw Exception('Failed to add bookmark: $e');
    }
  }

  static Future<void> removeBookmark({
    required String postId,
    required String listId,
  }) async {
    final user = AuthService.currentUser;
    if (user == null) throw Exception('User not authenticated');

    final bookmarkId = Bookmark.generateId(
      postId: postId,
      userId: user.uid,
      listId: listId,
    );

    try {
      final batch = _firestore.batch();

      // Remove bookmark
      batch.delete(_firestore.collection(_bookmarksCollection).doc(bookmarkId));

      // Decrement bookmark count in list
      batch.update(_firestore.collection(_listsCollection).doc(listId), {
        'bookmarkCount': FieldValue.increment(-1),
        'updatedAt': Timestamp.now(),
      });

      await batch.commit();
    } catch (e) {
      throw Exception('Failed to remove bookmark: $e');
    }
  }

  static Future<bool> isPostBookmarked(String postId) async {
    final user = AuthService.currentUser;
    if (user == null) return false;

    try {
      final snapshot = await _firestore
          .collection(_bookmarksCollection)
          .where('postId', isEqualTo: postId)
          .where('userId', isEqualTo: user.uid)
          .limit(1)
          .get();

      return snapshot.docs.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  static Stream<List<Bookmark>> streamBookmarksInList(String listId) {
    final user = AuthService.currentUser;
    if (user == null) return Stream.value([]);

    return _firestore
        .collection(_bookmarksCollection)
        .where('listId', isEqualTo: listId)
        .where('userId', isEqualTo: user.uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => Bookmark.fromFirestore(doc)).toList(),
        );
  }

  static Future<List<String>> getBookmarkedListIds(String postId) async {
    final user = AuthService.currentUser;
    if (user == null) return [];

    try {
      final snapshot = await _firestore
          .collection(_bookmarksCollection)
          .where('postId', isEqualTo: postId)
          .where('userId', isEqualTo: user.uid)
          .get();

      return snapshot.docs
          .map((doc) => doc.data()['listId'] as String)
          .toList();
    } catch (e) {
      return [];
    }
  }
}
