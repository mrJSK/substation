// lib/models/bookmark_models.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class BookmarkList {
  final String id;
  final String name;
  final String description;
  final String userId;
  final Timestamp createdAt;
  final Timestamp updatedAt;
  final int bookmarkCount;
  final String? color; // For visual distinction
  final bool isDefault; // For default "Saved" list

  BookmarkList({
    required this.id,
    required this.name,
    required this.description,
    required this.userId,
    required this.createdAt,
    required this.updatedAt,
    this.bookmarkCount = 0,
    this.color,
    this.isDefault = false,
  });

  factory BookmarkList.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return BookmarkList(
      id: doc.id,
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      userId: data['userId'] ?? '',
      createdAt: data['createdAt'] ?? Timestamp.now(),
      updatedAt: data['updatedAt'] ?? Timestamp.now(),
      bookmarkCount: data['bookmarkCount']?.toInt() ?? 0,
      color: data['color'],
      isDefault: data['isDefault'] ?? false,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'description': description,
      'userId': userId,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'bookmarkCount': bookmarkCount,
      'color': color,
      'isDefault': isDefault,
    };
  }

  BookmarkList copyWith({
    String? id,
    String? name,
    String? description,
    String? userId,
    Timestamp? createdAt,
    Timestamp? updatedAt,
    int? bookmarkCount,
    String? color,
    bool? isDefault,
  }) {
    return BookmarkList(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      userId: userId ?? this.userId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      bookmarkCount: bookmarkCount ?? this.bookmarkCount,
      color: color ?? this.color,
      isDefault: isDefault ?? this.isDefault,
    );
  }
}

class Bookmark {
  final String id;
  final String postId;
  final String userId;
  final String listId;
  final Timestamp createdAt;
  final String? note; // Optional note for the bookmark

  Bookmark({
    required this.id,
    required this.postId,
    required this.userId,
    required this.listId,
    required this.createdAt,
    this.note,
  });

  factory Bookmark.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Bookmark(
      id: doc.id,
      postId: data['postId'] ?? '',
      userId: data['userId'] ?? '',
      listId: data['listId'] ?? '',
      createdAt: data['createdAt'] ?? Timestamp.now(),
      note: data['note'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'postId': postId,
      'userId': userId,
      'listId': listId,
      'createdAt': createdAt,
      'note': note,
    };
  }

  static String generateId({
    required String postId,
    required String userId,
    required String listId,
  }) {
    return '${postId}_${userId}_$listId';
  }
}
