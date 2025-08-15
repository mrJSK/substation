// lib/models/powerpulse_models.dart
import 'package:cloud_firestore/cloud_firestore.dart';

/// ---------------------------------------------------------------------------
/// Post Scope Model
/// ---------------------------------------------------------------------------
enum ScopeType { public, zone }

class PostScope {
  final ScopeType type;
  final String? zoneId;
  final String? zoneName; // Denormalized for display

  PostScope({required this.type, this.zoneId, this.zoneName});

  factory PostScope.public() => PostScope(type: ScopeType.public);

  factory PostScope.zone(String zoneId, String zoneName) =>
      PostScope(type: ScopeType.zone, zoneId: zoneId, zoneName: zoneName);

  factory PostScope.fromMap(Map<String, dynamic> map) {
    final typeStr = map['type'] as String? ?? 'public';
    final type = typeStr == 'zone' ? ScopeType.zone : ScopeType.public;

    return PostScope(
      type: type,
      zoneId: map['zoneId'],
      zoneName: map['zoneName'],
    );
  }

  Map<String, dynamic> toMap() {
    return {'type': type.name, 'zoneId': zoneId, 'zoneName': zoneName};
  }

  String get displayName {
    switch (type) {
      case ScopeType.public:
        return 'Public • All Zones';
      case ScopeType.zone:
        return zoneName ?? 'Zone';
    }
  }

  bool get isPublic => type == ScopeType.public;
  bool get isZone => type == ScopeType.zone;
}

/// ---------------------------------------------------------------------------
/// Post Model
/// ---------------------------------------------------------------------------
class Post {
  final String id;
  final String authorId;
  final String title;
  final Map<String, dynamic> bodyDelta; // Quill Delta JSON
  final String bodyPlain; // Plain text for search/snippets
  final PostScope scope;
  final int score;
  final int commentCount;
  final Timestamp createdAt;
  final Timestamp? updatedAt;
  final String? imageUrl; // Optional header image

  // Cached author info (denormalized for performance)
  final String? authorName;
  final String? authorDesignation;

  Post({
    required this.id,
    required this.authorId,
    required this.title,
    required this.bodyDelta,
    required this.bodyPlain,
    required this.scope,
    this.score = 0,
    this.commentCount = 0,
    required this.createdAt,
    this.updatedAt,
    this.imageUrl,
    this.authorName,
    this.authorDesignation,
  });

  factory Post.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return Post(
      id: doc.id,
      authorId: data['authorId'] ?? '',
      title: data['title'] ?? '',
      bodyDelta: Map<String, dynamic>.from(data['bodyDelta'] ?? {}),
      bodyPlain: data['bodyPlain'] ?? '',
      scope: PostScope.fromMap(data['scope'] ?? {}),
      score: data['score'] ?? 0,
      commentCount: data['commentCount'] ?? 0,
      createdAt: data['createdAt'] ?? Timestamp.now(),
      updatedAt: data['updatedAt'],
      imageUrl: data['imageUrl'],
      authorName: data['authorName'],
      authorDesignation: data['authorDesignation'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'authorId': authorId,
      'title': title,
      'bodyDelta': bodyDelta,
      'bodyPlain': bodyPlain,
      'scope': scope.toMap(),
      'score': score,
      'commentCount': commentCount,
      'createdAt': createdAt,
      'updatedAt': updatedAt ?? Timestamp.now(),
      'imageUrl': imageUrl,
      'authorName': authorName,
      'authorDesignation': authorDesignation,
    };
  }

  Post copyWith({
    String? id,
    String? authorId,
    String? title,
    Map<String, dynamic>? bodyDelta,
    String? bodyPlain,
    PostScope? scope,
    int? score,
    int? commentCount,
    Timestamp? createdAt,
    Timestamp? updatedAt,
    String? imageUrl,
    String? authorName,
    String? authorDesignation,
  }) {
    return Post(
      id: id ?? this.id,
      authorId: authorId ?? this.authorId,
      title: title ?? this.title,
      bodyDelta: bodyDelta ?? this.bodyDelta,
      bodyPlain: bodyPlain ?? this.bodyPlain,
      scope: scope ?? this.scope,
      score: score ?? this.score,
      commentCount: commentCount ?? this.commentCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      imageUrl: imageUrl ?? this.imageUrl,
      authorName: authorName ?? this.authorName,
      authorDesignation: authorDesignation ?? this.authorDesignation,
    );
  }

  // Getters for UI
  String get readingTime {
    final wordCount = bodyPlain.split(' ').length;
    final minutes = (wordCount / 200).ceil(); // ~200 words per minute
    return '${minutes} min read';
  }

  String get excerpt {
    return bodyPlain.length > 200
        ? '${bodyPlain.substring(0, 200)}...'
        : bodyPlain;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Post && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// ---------------------------------------------------------------------------
/// Comment Model
/// ---------------------------------------------------------------------------
class Comment {
  final String id;
  final String postId;
  final String authorId;
  final Map<String, dynamic> bodyDelta; // Simplified Quill for comments
  final String bodyPlain;
  final String? parentId; // For threading (optional in MVP)
  final Timestamp createdAt;

  // Cached author info
  final String? authorName;
  final String? authorDesignation;

  Comment({
    required this.id,
    required this.postId,
    required this.authorId,
    required this.bodyDelta,
    required this.bodyPlain,
    this.parentId,
    required this.createdAt,
    this.authorName,
    this.authorDesignation,
  });

  factory Comment.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return Comment(
      id: doc.id,
      postId: data['postId'] ?? '',
      authorId: data['authorId'] ?? '',
      bodyDelta: Map<String, dynamic>.from(data['bodyDelta'] ?? {}),
      bodyPlain: data['bodyPlain'] ?? '',
      parentId: data['parentId'],
      createdAt: data['createdAt'] ?? Timestamp.now(),
      authorName: data['authorName'],
      authorDesignation: data['authorDesignation'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'postId': postId,
      'authorId': authorId,
      'bodyDelta': bodyDelta,
      'bodyPlain': bodyPlain,
      'parentId': parentId,
      'createdAt': createdAt,
      'authorName': authorName,
      'authorDesignation': authorDesignation,
    };
  }

  Comment copyWith({
    String? id,
    String? postId,
    String? authorId,
    Map<String, dynamic>? bodyDelta,
    String? bodyPlain,
    String? parentId,
    Timestamp? createdAt,
    String? authorName,
    String? authorDesignation,
  }) {
    return Comment(
      id: id ?? this.id,
      postId: postId ?? this.postId,
      authorId: authorId ?? this.authorId,
      bodyDelta: bodyDelta ?? this.bodyDelta,
      bodyPlain: bodyPlain ?? this.bodyPlain,
      parentId: parentId ?? this.parentId,
      createdAt: createdAt ?? this.createdAt,
      authorName: authorName ?? this.authorName,
      authorDesignation: authorDesignation ?? this.authorDesignation,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Comment && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// ---------------------------------------------------------------------------
/// Vote Model
/// ---------------------------------------------------------------------------
class Vote {
  final String id; // Format: "${postId}_${userId}"
  final String postId;
  final String userId;
  final int value; // 1 for upvote, -1 for downvote
  final Timestamp createdAt;

  Vote({
    required this.id,
    required this.postId,
    required this.userId,
    required this.value,
    required this.createdAt,
  });

  factory Vote.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return Vote(
      id: doc.id,
      postId: data['postId'] ?? '',
      userId: data['userId'] ?? '',
      value: data['value'] ?? 0,
      createdAt: data['createdAt'] ?? Timestamp.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'postId': postId,
      'userId': userId,
      'value': value,
      'createdAt': createdAt,
    };
  }

  Vote copyWith({
    String? id,
    String? postId,
    String? userId,
    int? value,
    Timestamp? createdAt,
  }) {
    return Vote(
      id: id ?? this.id,
      postId: postId ?? this.postId,
      userId: userId ?? this.userId,
      value: value ?? this.value,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  static String generateId(String postId, String userId) {
    return '${postId}_$userId';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Vote && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// ---------------------------------------------------------------------------
/// Feed Item Model (for UI display)
/// ---------------------------------------------------------------------------
class FeedItem {
  final Post post;
  final bool isLiked;
  final Vote? userVote;

  FeedItem({required this.post, this.isLiked = false, this.userVote});

  FeedItem copyWith({Post? post, bool? isLiked, Vote? userVote}) {
    return FeedItem(
      post: post ?? this.post,
      isLiked: isLiked ?? this.isLiked,
      userVote: userVote ?? this.userVote,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FeedItem &&
          runtimeType == other.runtimeType &&
          post == other.post;

  @override
  int get hashCode => post.hashCode;
}

/// ---------------------------------------------------------------------------
/// Create Post Input Model
/// ---------------------------------------------------------------------------
class CreatePostInput {
  final String title;
  final Map<String, dynamic> bodyDelta;
  final String bodyPlain;
  final PostScope scope;
  final String? imageUrl;

  CreatePostInput({
    required this.title,
    required this.bodyDelta,
    required this.bodyPlain,
    required this.scope,
    this.imageUrl,
  });

  bool get isValid => title.trim().isNotEmpty && bodyPlain.trim().isNotEmpty;
}

/// ---------------------------------------------------------------------------
/// Create Comment Input Model
/// ---------------------------------------------------------------------------
class CreateCommentInput {
  final String postId;
  final Map<String, dynamic> bodyDelta;
  final String bodyPlain;
  final String? parentId;

  CreateCommentInput({
    required this.postId,
    required this.bodyDelta,
    required this.bodyPlain,
    this.parentId,
  });

  bool get isValid => bodyPlain.trim().isNotEmpty;
}
