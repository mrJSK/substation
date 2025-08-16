// lib/models/power_pulse/powerpulse_models.dart

import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

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

  Map<String, dynamic> toJson() => toMap();
  factory PostScope.fromJson(Map<String, dynamic> json) =>
      PostScope.fromMap(json);

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
/// Flair Model
/// ---------------------------------------------------------------------------
class Flair {
  final String name;
  final String? emoji;

  Flair({required this.name, this.emoji});

  Map<String, dynamic> toJson() => {'name': name, 'emoji': emoji};

  factory Flair.fromJson(Map<String, dynamic> json) =>
      Flair(name: json['name'] ?? '', emoji: json['emoji']);
}

/// ---------------------------------------------------------------------------
/// Content Block Models (for post content structure) - Enhanced
/// ---------------------------------------------------------------------------
enum ContentBlockType {
  heading,
  subHeading,
  paragraph,
  bulletedList,
  numberedList,
  image,
  link,
  file,
  flowchart, // Added for flowchart support
}

class ContentBlock {
  final ContentBlockType type;
  String text;
  List<String> listItems;
  File? file;
  String? url;
  Map<String, dynamic>? flowchartData; // Added for flowchart JSON

  ContentBlock({
    required this.type,
    this.text = '',
    this.listItems = const [],
    this.file,
    this.url,
    this.flowchartData,
  });

  factory ContentBlock.paragraph(String text) {
    return ContentBlock(type: ContentBlockType.paragraph, text: text);
  }

  factory ContentBlock.flowchart(Map<String, dynamic> data) {
    return ContentBlock(
      type: ContentBlockType.flowchart,
      flowchartData: data,
      text: data['title']?.toString() ?? 'Flowchart',
    );
  }

  // ✅ Enhanced fromJson with better error handling
  factory ContentBlock.fromJson(Map<String, dynamic> json) {
    try {
      final typeIndex = json['type'] as int? ?? 0;
      if (typeIndex >= ContentBlockType.values.length) {
        throw FormatException('Invalid content block type: $typeIndex');
      }

      final type = ContentBlockType.values[typeIndex];

      return ContentBlock(
        type: type,
        text: json['text']?.toString() ?? '',
        listItems: json['listItems'] != null
            ? List<String>.from(json['listItems'])
            : [],
        url: json['url']?.toString(),
        file: json['filePath'] != null
            ? File(json['filePath'].toString())
            : null,
        flowchartData: json['flowchartData'] != null
            ? Map<String, dynamic>.from(json['flowchartData'])
            : null,
      );
    } catch (e) {
      debugPrint('Error parsing ContentBlock: $e, JSON: $json');
      // Return a safe fallback
      return ContentBlock(
        type: ContentBlockType.paragraph,
        text: json['text']?.toString() ?? 'Error loading content',
      );
    }
  }

  // ✅ Enhanced toJson with comprehensive data
  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{'type': type.index, 'text': text};

    if (listItems.isNotEmpty) {
      json['listItems'] = listItems;
    }

    if (url != null && url!.isNotEmpty) {
      json['url'] = url;
    }

    if (file != null) {
      json['filePath'] = file!.path;
    }

    if (flowchartData != null && flowchartData!.isNotEmpty) {
      json['flowchartData'] = flowchartData;
    }

    return json;
  }

  // ✅ Enhanced word count calculation
  int get wordCount {
    switch (type) {
      case ContentBlockType.heading:
      case ContentBlockType.subHeading:
      case ContentBlockType.paragraph:
      case ContentBlockType.link:
        return _countWords(text);

      case ContentBlockType.bulletedList:
      case ContentBlockType.numberedList:
        return listItems.fold(0, (sum, item) => sum + _countWords(item));

      case ContentBlockType.flowchart:
        // Count words in flowchart title and description
        int count = 0;
        if (flowchartData != null) {
          count += _countWords(flowchartData!['title']?.toString() ?? '');
          count += _countWords(flowchartData!['description']?.toString() ?? '');
        }
        return count;

      case ContentBlockType.image:
      case ContentBlockType.file:
        return 0; // Media doesn't contribute to reading time
    }
  }

  int _countWords(String text) =>
      text.split(RegExp(r'\s+')).where((word) => word.trim().isNotEmpty).length;

  @override
  String toString() =>
      'ContentBlock(type: $type, text: ${text.length > 50 ? '${text.substring(0, 50)}...' : text})';
}

/// ---------------------------------------------------------------------------
/// Post Model - Enhanced
/// ---------------------------------------------------------------------------
class Post {
  final String id;
  final String authorId;
  final String title;
  final String bodyDelta; // Rich text editor JSON
  final String bodyPlain; // JSON serialized ContentBlocks
  final String excerpt; // Summary for previews (made required)
  final PostScope scope;
  final Flair? flair;
  final int score;
  final int commentCount;
  final Timestamp createdAt;
  final Timestamp? updatedAt;
  final String? imageUrl; // Optional header image
  final String? authorName;
  final String? authorDesignation;
  final String readingTime; // Field for Firestore and caching

  Post({
    required this.id,
    required this.authorId,
    required this.title,
    required this.bodyDelta,
    required this.bodyPlain,
    required this.excerpt, // ✅ Make required
    required this.scope,
    this.flair,
    this.score = 0,
    this.commentCount = 0,
    required this.createdAt,
    this.updatedAt,
    this.imageUrl,
    this.authorName,
    this.authorDesignation,
    required this.readingTime,
  });

  // ✅ New method to get parsed content blocks
  List<ContentBlock> get contentBlocks {
    if (bodyPlain.isEmpty) return [];

    if (_isValidJson(bodyPlain)) {
      try {
        final json = jsonDecode(bodyPlain) as List<dynamic>;
        return json
            .map((e) => ContentBlock.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (e) {
        debugPrint('Failed to parse content blocks: $e');
        return [ContentBlock.paragraph(bodyPlain)];
      }
    } else {
      // Legacy support - convert plain text to paragraph block
      return [ContentBlock.paragraph(bodyPlain)];
    }
  }

  // ✅ Helper method to calculate reading time from content blocks
  String get calculatedReadingTime {
    int wordCount = contentBlocks.fold(
      0,
      (sum, block) => sum + block.wordCount,
    );

    // Add words from excerpt if content blocks are empty
    if (wordCount == 0 && excerpt.isNotEmpty) {
      wordCount = excerpt
          .split(RegExp(r'\s+'))
          .where((w) => w.isNotEmpty)
          .length;
    }

    final minutes = (wordCount / 200).ceil(); // ~200 words per minute
    return minutes == 0 ? '1 min read' : '$minutes min read';
  }

  // ✅ Updated factory methods
  factory Post.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Post(
      id: doc.id,
      authorId: data['authorId'] ?? '',
      title: data['title'] ?? '',
      bodyDelta: data['bodyDelta'] ?? '',
      bodyPlain: data['bodyPlain'] ?? '',
      excerpt: data['excerpt']?.toString() ?? '', // ✅ Handle excerpt properly
      scope: PostScope.fromMap(data['scope'] ?? {}),
      flair: data['flair'] != null ? Flair.fromJson(data['flair']) : null,
      score: data['score']?.toInt() ?? 0,
      commentCount: data['commentCount']?.toInt() ?? 0,
      createdAt: data['createdAt'] ?? Timestamp.now(),
      updatedAt: data['updatedAt'],
      imageUrl: data['imageUrl'],
      authorName: data['authorName'],
      authorDesignation: data['authorDesignation'],
      readingTime: data['readingTime'] ?? '1 min read',
    );
  }

  factory Post.fromJson(Map<String, dynamic> json) {
    return Post(
      id: json['id'] ?? '',
      authorId: json['authorId'] ?? '',
      title: json['title'] ?? '',
      bodyDelta: _ensureString(json['bodyDelta']),
      bodyPlain: _ensureString(json['bodyPlain']),
      excerpt: json['excerpt']?.toString() ?? '', // ✅ Handle excerpt
      scope: PostScope.fromJson(json['scope'] ?? {}),
      flair: json['flair'] != null ? Flair.fromJson(json['flair']) : null,
      score: json['score']?.toInt() ?? 0,
      commentCount: json['commentCount']?.toInt() ?? 0,
      createdAt: json['createdAt'] != null
          ? Timestamp.fromMillisecondsSinceEpoch(json['createdAt'])
          : Timestamp.now(),
      updatedAt: json['updatedAt'] != null
          ? Timestamp.fromMillisecondsSinceEpoch(json['updatedAt'])
          : null,
      imageUrl: json['imageUrl'],
      authorName: json['authorName'],
      authorDesignation: json['authorDesignation'],
      readingTime: json['readingTime'] ?? '1 min read',
    );
  }

  // ✅ Helper method to ensure string type
  static String _ensureString(dynamic value) {
    if (value == null) return '';
    if (value is String) return value;
    if (value is List || value is Map) return jsonEncode(value);
    return value.toString();
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'authorId': authorId,
      'title': title,
      'bodyDelta': bodyDelta,
      'bodyPlain': bodyPlain,
      'excerpt': excerpt,
      'scope': scope.toJson(),
      'flair': flair?.toJson(),
      'score': score,
      'commentCount': commentCount,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt?.millisecondsSinceEpoch,
      'imageUrl': imageUrl,
      'authorName': authorName,
      'authorDesignation': authorDesignation,
      'readingTime': readingTime,
    };
  }

  Map<String, dynamic> toFirestore() {
    return {
      'authorId': authorId,
      'title': title,
      'bodyDelta': bodyDelta,
      'bodyPlain': bodyPlain,
      'excerpt': excerpt.trim(),
      'scope': scope.toMap(),
      'flair': flair?.toJson(),
      'score': score,
      'commentCount': commentCount,
      'createdAt': createdAt,
      'updatedAt': updatedAt ?? Timestamp.now(),
      'imageUrl': imageUrl,
      'authorName': authorName,
      'authorDesignation': authorDesignation,
      'readingTime': readingTime,
    };
  }

  Post copyWith({
    String? id,
    String? authorId,
    String? title,
    String? bodyDelta,
    String? bodyPlain,
    String? excerpt,
    PostScope? scope,
    Flair? flair,
    int? score,
    int? commentCount,
    Timestamp? createdAt,
    Timestamp? updatedAt,
    String? imageUrl,
    String? authorName,
    String? authorDesignation,
    String? readingTime,
  }) {
    return Post(
      id: id ?? this.id,
      authorId: authorId ?? this.authorId,
      title: title ?? this.title,
      bodyDelta: bodyDelta ?? this.bodyDelta,
      bodyPlain: bodyPlain ?? this.bodyPlain,
      excerpt: excerpt ?? this.excerpt,
      scope: scope ?? this.scope,
      flair: flair ?? this.flair,
      score: score ?? this.score,
      commentCount: commentCount ?? this.commentCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      imageUrl: imageUrl ?? this.imageUrl,
      authorName: authorName ?? this.authorName,
      authorDesignation: authorDesignation ?? this.authorDesignation,
      readingTime: readingTime ?? this.readingTime,
    );
  }

  String get displayExcerpt {
    if (excerpt.trim().isNotEmpty) {
      return excerpt.length > 200
          ? '${excerpt.substring(0, 200).trim()}...'
          : excerpt.trim();
    }

    return _generateExcerptFromContent();
  }

  bool _isValidJson(String str) {
    str = str.trim();
    return (str.startsWith('[') && str.endsWith(']')) ||
        (str.startsWith('{') && str.endsWith('}'));
  }

  String _generateExcerptFromContent() {
    if (bodyPlain.isEmpty) return 'No content available';

    if (_isValidJson(bodyPlain)) {
      try {
        final json = jsonDecode(bodyPlain) as List;
        return _extractTextFromBlocks(json);
      } catch (e) {
        return _truncatePlainText(bodyPlain);
      }
    }

    return _truncatePlainText(bodyPlain);
  }

  String _extractTextFromBlocks(List blocks) {
    final excerptBuffer = StringBuffer();
    int wordCount = 0;
    const maxWords = 35;

    for (var blockJson in blocks) {
      if (wordCount >= maxWords) break;
      try {
        final block = ContentBlock.fromJson(blockJson as Map<String, dynamic>);
        switch (block.type) {
          case ContentBlockType.heading:
          case ContentBlockType.subHeading:
          case ContentBlockType.paragraph:
            if (block.text.isNotEmpty) {
              final words = block.text.split(RegExp(r'\s+'));
              final wordsToAdd = (maxWords - wordCount).clamp(0, words.length);
              excerptBuffer.write(words.take(wordsToAdd).join(' '));
              wordCount += wordsToAdd;
              if (wordCount < maxWords) excerptBuffer.write(' ');
            }
            break;
          case ContentBlockType.bulletedList:
          case ContentBlockType.numberedList:
            for (var item in block.listItems) {
              if (wordCount >= maxWords) break;
              if (item.trim().isNotEmpty) {
                final words = item.trim().split(RegExp(r'\s+'));
                final wordsToAdd = (maxWords - wordCount).clamp(
                  0,
                  words.length,
                );
                excerptBuffer.write('• ${words.take(wordsToAdd).join(' ')} ');
                wordCount += wordsToAdd;
              }
            }
            break;
          case ContentBlockType.link:
            if (block.text.isNotEmpty && wordCount < maxWords) {
              excerptBuffer.write('🔗 ${block.text} ');
              wordCount += block.text.split(RegExp(r'\s+')).length;
            }
            break;
          case ContentBlockType.image:
            if (wordCount < maxWords) {
              excerptBuffer.write('📷 Image ');
              wordCount += 1;
            }
            break;
          case ContentBlockType.file:
            if (wordCount < maxWords) {
              final fileName = block.text.isNotEmpty
                  ? block.text
                  : 'Attachment';
              excerptBuffer.write('📎 $fileName ');
              wordCount += fileName.split(RegExp(r'\s+')).length;
            }
            break;
          case ContentBlockType.flowchart:
            if (wordCount < maxWords) {
              excerptBuffer.write('📊 Flowchart ');
              wordCount += 1;
            }
            break;
        }
      } catch (e) {
        continue;
      }
    }

    String result = excerptBuffer.toString().trim();
    return result.isEmpty ? 'No readable content available' : result;
  }

  String _truncatePlainText(String text) {
    final cleanText = text.trim();
    if (cleanText.isEmpty) return 'No content available';

    final words = cleanText.split(RegExp(r'\s+'));
    return words.length <= 35 ? cleanText : '${words.take(35).join(' ')}...';
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
  final String bodyDelta; // String for Quill Delta JSON
  final String bodyPlain;
  final String? parentId; // For threading
  final int score; // Added for Reddit-like voting
  final Timestamp createdAt;
  final String? authorName;
  final String? authorDesignation;

  Comment({
    required this.id,
    required this.postId,
    required this.authorId,
    required this.bodyDelta,
    required this.bodyPlain,
    this.parentId,
    this.score = 0,
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
      bodyDelta: data['bodyDelta'] ?? '',
      bodyPlain: data['bodyPlain'] ?? '',
      parentId: data['parentId'],
      score: data['score']?.toInt() ?? 0,
      createdAt: data['createdAt'] ?? Timestamp.now(),
      authorName: data['authorName'],
      authorDesignation: data['authorDesignation'],
    );
  }

  factory Comment.fromJson(Map<String, dynamic> json) {
    return Comment(
      id: json['id'] ?? '',
      postId: json['postId'] ?? '',
      authorId: json['authorId'] ?? '',
      bodyDelta: Post._ensureString(json['bodyDelta']),
      bodyPlain: Post._ensureString(json['bodyPlain']),
      parentId: json['parentId'],
      score: json['score']?.toInt() ?? 0,
      createdAt: json['createdAt'] != null
          ? Timestamp.fromMillisecondsSinceEpoch(json['createdAt'])
          : Timestamp.now(),
      authorName: json['authorName'],
      authorDesignation: json['authorDesignation'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'postId': postId,
      'authorId': authorId,
      'bodyDelta': bodyDelta,
      'bodyPlain': bodyPlain,
      'parentId': parentId,
      'score': score,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'authorName': authorName,
      'authorDesignation': authorDesignation,
    };
  }

  Map<String, dynamic> toFirestore() {
    return {
      'postId': postId,
      'authorId': authorId,
      'bodyDelta': bodyDelta,
      'bodyPlain': bodyPlain,
      'parentId': parentId,
      'score': score,
      'createdAt': createdAt,
      'authorName': authorName,
      'authorDesignation': authorDesignation,
    };
  }

  Comment copyWith({
    String? id,
    String? postId,
    String? authorId,
    String? bodyDelta,
    String? bodyPlain,
    String? parentId,
    int? score,
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
      score: score ?? this.score,
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
  final String id; // Format: "${postId/commentId}_${userId}"
  final String? postId;
  final String? commentId; // Added for comment voting
  final String userId;
  final int value; // 1 for upvote, -1 for downvote
  final Timestamp createdAt;

  Vote({
    required this.id,
    this.postId,
    this.commentId,
    required this.userId,
    required this.value,
    required this.createdAt,
  }) {
    if (postId == null && commentId == null) {
      throw ArgumentError('Either postId or commentId must be provided');
    }

    if (postId != null && commentId != null) {
      throw ArgumentError('Only one of postId or commentId can be provided');
    }
  }

  factory Vote.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Vote(
      id: doc.id,
      postId: data['postId'],
      commentId: data['commentId'],
      userId: data['userId'] ?? '',
      value: data['value']?.toInt() ?? 0,
      createdAt: data['createdAt'] ?? Timestamp.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'postId': postId,
      'commentId': commentId,
      'userId': userId,
      'value': value,
      'createdAt': createdAt,
    };
  }

  Vote copyWith({
    String? id,
    String? postId,
    String? commentId,
    String? userId,
    int? value,
    Timestamp? createdAt,
  }) {
    return Vote(
      id: id ?? this.id,
      postId: postId ?? this.postId,
      commentId: commentId ?? this.commentId,
      userId: userId ?? this.userId,
      value: value ?? this.value,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  static String generateId({
    String? postId,
    String? commentId,
    required String userId,
  }) {
    if (postId == null && commentId == null) {
      throw ArgumentError('Either postId or commentId must be provided');
    }

    if (postId != null && commentId != null) {
      throw ArgumentError('Only one of postId or commentId can be provided');
    }

    return postId != null ? '${postId}_$userId' : '${commentId}_$userId';
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
/// Create Post Input Model - Enhanced
/// ---------------------------------------------------------------------------
class CreatePostInput {
  final String title;
  final String bodyDelta; // Rich text editor content (Quill Delta JSON)
  final List<ContentBlock> contentBlocks; // ✅ Structured content blocks
  final String excerpt; // Summary/preview text
  final PostScope scope;
  final Flair? flair;
  final String? imageUrl;

  CreatePostInput({
    required this.title,
    this.bodyDelta = '', // Default empty for now
    required this.contentBlocks, // ✅ Direct content blocks
    required this.excerpt,
    required this.scope,
    this.flair,
    this.imageUrl,
  });

  bool get isValid =>
      title.trim().isNotEmpty &&
      (contentBlocks.isNotEmpty || excerpt.trim().isNotEmpty);

  // Helper method to serialize content blocks
  String get serializedContentBlocks =>
      jsonEncode(contentBlocks.map((block) => block.toJson()).toList());
}

/// ---------------------------------------------------------------------------
/// Create Comment Input Model
/// ---------------------------------------------------------------------------
class CreateCommentInput {
  final String postId;
  final String bodyDelta; // String for Quill Delta JSON
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

/// ---------------------------------------------------------------------------
/// Migration Helper Models
/// ---------------------------------------------------------------------------
class PostMigrationHelper {
  static Future<void> migratePostToStructuredContent(
    String postId,
    String plainTextContent,
  ) async {
    try {
      final contentBlocks = [
        {
          'type': ContentBlockType.paragraph.index,
          'text': plainTextContent,
          'listItems': <String>[],
          'url': null,
          'filePath': null,
          'flowchartData': null,
        },
      ];

      final words = plainTextContent.trim().split(RegExp(r'\s+'));
      final excerpt = words.length > 35
          ? '${words.take(35).join(' ')}...'
          : plainTextContent;

      await FirebaseFirestore.instance.collection('posts').doc(postId).update({
        'bodyPlain': jsonEncode(contentBlocks),
        'excerpt': excerpt.trim(),
        'migrated': true,
        'migratedAt': Timestamp.now(),
      });
    } catch (e) {
      throw Exception('Migration failed for post $postId: $e');
    }
  }

  static bool isLegacyPlainTextPost(String bodyPlain) {
    final trimmed = bodyPlain.trim();
    return !(trimmed.startsWith('[') && trimmed.endsWith(']')) &&
        !(trimmed.startsWith('{') && trimmed.endsWith('}'));
  }
}

/// ---------------------------------------------------------------------------
/// Error Handling Models
/// ---------------------------------------------------------------------------
class PostProcessingException implements Exception {
  final String message;
  final dynamic originalError;

  PostProcessingException(this.message, [this.originalError]);

  @override
  String toString() {
    return 'PostProcessingException: $message${originalError != null ? ' (Original: $originalError)' : ''}';
  }
}

class ContentParsingException implements Exception {
  final String message;
  final String content;
  final dynamic originalError;

  ContentParsingException(this.message, this.content, [this.originalError]);

  @override
  String toString() {
    return 'ContentParsingException: $message for content: ${content.length > 100 ? '${content.substring(0, 100)}...' : content}';
  }
}
