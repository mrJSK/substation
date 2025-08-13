// lib/services/community_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/community_models.dart';
import '../models/user_model.dart';
import 'notification_service.dart';

class CommunityService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseStorage _storage = FirebaseStorage.instance;

  // ==================== KNOWLEDGE HUB SERVICES ====================

  // Create new knowledge post
  static Future<String> createKnowledgePost(KnowledgePost post) async {
    try {
      final docRef = await _firestore
          .collection('community_posts')
          .add(post.toFirestore());

      // If not draft, send for approval
      if (post.status != PostStatus.draft) {
        await _sendForApproval(docRef.id, post);
      }

      return docRef.id;
    } catch (e) {
      throw Exception('Failed to create post: $e');
    }
  }

  /// Increment post view count
  static Future<void> incrementPostViews(String postId) async {
    try {
      await _firestore.collection('knowledge_posts').doc(postId).update({
        'metrics.views': FieldValue.increment(1),
      });
    } catch (e) {
      throw Exception('Failed to increment views: $e');
    }
  }

  /// Like a post
  static Future<void> likePost(String postId, String userId) async {
    try {
      final batch = _firestore.batch();

      // Update the post metrics
      final postRef = _firestore.collection('knowledge_posts').doc(postId);
      batch.update(postRef, {
        'metrics.likes': FieldValue.increment(1),
        'metrics.likedBy': FieldValue.arrayUnion([userId]),
      });

      await batch.commit();
    } catch (e) {
      throw Exception('Failed to like post: $e');
    }
  }

  /// Unlike a post
  static Future<void> unlikePost(String postId, String userId) async {
    try {
      final batch = _firestore.batch();

      // Update the post metrics
      final postRef = _firestore.collection('knowledge_posts').doc(postId);
      batch.update(postRef, {
        'metrics.likes': FieldValue.increment(-1),
        'metrics.likedBy': FieldValue.arrayRemove([userId]),
      });

      await batch.commit();
    } catch (e) {
      throw Exception('Failed to unlike post: $e');
    }
  }

  /// Add a comment to a post
  static Future<void> addPostComment(PostComment comment) async {
    try {
      final batch = _firestore.batch();

      // Add the comment
      final commentRef = _firestore.collection('post_comments').doc();
      batch.set(commentRef, comment.toFirestore());

      // Increment comment count on the post
      final postRef = _firestore
          .collection('knowledge_posts')
          .doc(comment.postId);
      batch.update(postRef, {'metrics.comments': FieldValue.increment(1)});

      await batch.commit();
    } catch (e) {
      throw Exception('Failed to add comment: $e');
    }
  }

  static Future<void> incrementContactViews(String contactId) async {
    try {
      await _firestore
          .collection('professional_contacts')
          .doc(contactId)
          .update({
            'metrics.timesViewed': FieldValue.increment(1),
            'metrics.lastViewed': Timestamp.now(),
          });
    } catch (e) {
      throw Exception('Failed to increment contact views: $e');
    }
  }

  // Update existing knowledge post
  static Future<void> updateKnowledgePost(
    String postId,
    KnowledgePost post,
  ) async {
    try {
      await _firestore
          .collection('community_posts')
          .doc(postId)
          .update(post.toFirestore()..['updatedAt'] = Timestamp.now());
    } catch (e) {
      throw Exception('Failed to update post: $e');
    }
  }

  // Get knowledge post by ID
  static Future<KnowledgePost?> getKnowledgePost(String postId) async {
    try {
      final doc = await _firestore
          .collection('community_posts')
          .doc(postId)
          .get();
      if (doc.exists) {
        // Increment view count
        await _incrementPostViews(postId);
        return KnowledgePost.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get post: $e');
    }
  }

  // Get all approved knowledge posts with pagination
  static Future<List<KnowledgePost>> getApprovedPosts({
    int limit = 20,
    DocumentSnapshot? lastDocument,
    CommunitySearchFilter? filter,
  }) async {
    try {
      Query query = _firestore
          .collection('community_posts')
          .where('status', isEqualTo: PostStatus.approved.toString());

      // Apply filters
      if (filter != null) {
        query = _applyPostFilters(query, filter);
      }

      // Apply sorting
      query = _applySorting(query, filter?.sortBy ?? SortType.latest);

      // Apply pagination
      if (lastDocument != null) {
        query = query.startAfterDocument(lastDocument);
      }

      query = query.limit(limit);

      final snapshot = await query.get();
      return snapshot.docs
          .map((doc) => KnowledgePost.fromFirestore(doc))
          .toList();
    } catch (e) {
      throw Exception('Failed to get posts: $e');
    }
  }

  // Get trending posts
  static Future<List<KnowledgePost>> getTrendingPosts({int limit = 10}) async {
    try {
      final now = DateTime.now();
      final weekAgo = now.subtract(Duration(days: 7));

      final snapshot = await _firestore
          .collection('community_posts')
          .where('status', isEqualTo: PostStatus.approved.toString())
          .where('createdAt', isGreaterThan: Timestamp.fromDate(weekAgo))
          .orderBy('createdAt', descending: true)
          .limit(50) // Get more to calculate trending
          .get();

      final posts = snapshot.docs
          .map((doc) => KnowledgePost.fromFirestore(doc))
          .toList();

      // Calculate trending score and sort
      posts.sort(
        (a, b) =>
            _calculateTrendingScore(b).compareTo(_calculateTrendingScore(a)),
      );

      return posts.take(limit).toList();
    } catch (e) {
      throw Exception('Failed to get trending posts: $e');
    }
  }

  // Get posts by author
  static Future<List<KnowledgePost>> getPostsByAuthor(String authorId) async {
    try {
      final snapshot = await _firestore
          .collection('community_posts')
          .where('authorId', isEqualTo: authorId)
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => KnowledgePost.fromFirestore(doc))
          .toList();
    } catch (e) {
      throw Exception('Failed to get author posts: $e');
    }
  }

  // Get pending posts for approval
  static Future<List<KnowledgePost>> getPendingPosts(String approverId) async {
    try {
      final snapshot = await _firestore
          .collection('community_posts')
          .where('status', isEqualTo: PostStatus.pending.toString())
          .where('approvers', arrayContains: approverId)
          .orderBy('createdAt', descending: false)
          .get();

      return snapshot.docs
          .map((doc) => KnowledgePost.fromFirestore(doc))
          .toList();
    } catch (e) {
      throw Exception('Failed to get pending posts: $e');
    }
  }

  // Approve post
  static Future<void> approvePost(
    String postId,
    String approverId,
    String approverName,
  ) async {
    try {
      await _firestore.collection('community_posts').doc(postId).update({
        'status': PostStatus.approved.toString(),
        'approvedBy': approverId,
        'approvedByName': approverName,
        'approvedAt': Timestamp.now(),
      });

      // Notify author
      final post = await getKnowledgePost(postId);
      if (post != null) {
        await NotificationService.sendPostApprovalNotification(post, true);
      }
    } catch (e) {
      throw Exception('Failed to approve post: $e');
    }
  }

  // Reject post
  static Future<void> rejectPost(
    String postId,
    String approverId,
    String reason,
  ) async {
    try {
      await _firestore.collection('community_posts').doc(postId).update({
        'status': PostStatus.rejected.toString(),
        'approvedBy': approverId,
        'rejectionReason': reason,
        'approvedAt': Timestamp.now(),
      });

      // Notify author
      final post = await getKnowledgePost(postId);
      if (post != null) {
        await NotificationService.sendPostApprovalNotification(post, false);
      }
    } catch (e) {
      throw Exception('Failed to reject post: $e');
    }
  }

  // Like/Unlike post
  static Future<void> togglePostLike(String postId, String userId) async {
    try {
      final likeDoc = _firestore
          .collection('post_likes')
          .doc('${postId}_$userId');
      final likeSnapshot = await likeDoc.get();

      final batch = _firestore.batch();

      if (likeSnapshot.exists) {
        // Unlike
        batch.delete(likeDoc);
        batch.update(_firestore.collection('community_posts').doc(postId), {
          'metrics.likes': FieldValue.increment(-1),
        });
      } else {
        // Like
        batch.set(likeDoc, {
          'postId': postId,
          'userId': userId,
          'createdAt': Timestamp.now(),
        });
        batch.update(_firestore.collection('community_posts').doc(postId), {
          'metrics.likes': FieldValue.increment(1),
        });
      }

      await batch.commit();
    } catch (e) {
      throw Exception('Failed to toggle like: $e');
    }
  }

  // Search posts
  static Future<List<KnowledgePost>> searchPosts(
    String query, {
    CommunitySearchFilter? filter,
  }) async {
    try {
      // Basic text search (you might want to implement Algolia or similar for better search)
      Query firestoreQuery = _firestore
          .collection('community_posts')
          .where('status', isEqualTo: PostStatus.approved.toString());

      if (filter != null) {
        firestoreQuery = _applyPostFilters(firestoreQuery, filter);
      }

      final snapshot = await firestoreQuery.get();
      final posts = snapshot.docs
          .map((doc) => KnowledgePost.fromFirestore(doc))
          .toList();

      // Filter by search query in memory (for better search, use Algolia)
      return posts
          .where(
            (post) =>
                post.title.toLowerCase().contains(query.toLowerCase()) ||
                post.content.toLowerCase().contains(query.toLowerCase()) ||
                post.tags.any(
                  (tag) => tag.toLowerCase().contains(query.toLowerCase()),
                ),
          )
          .toList();
    } catch (e) {
      throw Exception('Failed to search posts: $e');
    }
  }

  // Upload post attachments
  static Future<List<PostAttachment>> uploadPostAttachments(
    List<PlatformFile> files,
  ) async {
    try {
      final List<PostAttachment> attachments = [];

      for (final file in files) {
        final ref = _storage.ref().child(
          'community_posts/${DateTime.now().millisecondsSinceEpoch}_${file.name}',
        );
        final uploadTask = ref.putData(file.bytes!);
        final snapshot = await uploadTask;
        final downloadUrl = await snapshot.ref.getDownloadURL();

        attachments.add(
          PostAttachment(
            fileName: file.name,
            fileUrl: downloadUrl,
            fileType: _getFileType(file.extension ?? ''),
            fileSizeBytes: file.size,
            uploadedAt: Timestamp.now(),
          ),
        );
      }

      return attachments;
    } catch (e) {
      throw Exception('Failed to upload attachments: $e');
    }
  }

  // ==================== PROFESSIONAL DIRECTORY SERVICES ====================

  // Create professional contact
  static Future<String> createProfessionalContact(
    ProfessionalContact contact,
  ) async {
    try {
      final docRef = await _firestore
          .collection('professional_contacts')
          .add(contact.toFirestore());

      // Send for verification if not already verified
      if (!contact.isVerified) {
        await _sendContactForVerification(docRef.id, contact);
      }

      return docRef.id;
    } catch (e) {
      throw Exception('Failed to create contact: $e');
    }
  }

  // Update professional contact
  static Future<void> updateProfessionalContact(
    String contactId,
    ProfessionalContact contact,
  ) async {
    try {
      await _firestore
          .collection('professional_contacts')
          .doc(contactId)
          .update(contact.toFirestore()..['updatedAt'] = Timestamp.now());
    } catch (e) {
      throw Exception('Failed to update contact: $e');
    }
  }

  // Get professional contact by ID
  static Future<ProfessionalContact?> getProfessionalContact(
    String contactId,
  ) async {
    try {
      final doc = await _firestore
          .collection('professional_contacts')
          .doc(contactId)
          .get();
      if (doc.exists) {
        // Increment view count
        await _incrementContactViews(contactId);
        return ProfessionalContact.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get contact: $e');
    }
  }

  // Get all professional contacts with filters
  static Future<List<ProfessionalContact>> getProfessionalContacts({
    int limit = 20,
    DocumentSnapshot? lastDocument,
    CommunitySearchFilter? filter,
  }) async {
    try {
      Query query = _firestore
          .collection('professional_contacts')
          .where('status', isEqualTo: ContactStatus.active.toString());

      // Apply filters
      if (filter != null) {
        query = _applyContactFilters(query, filter);
      }

      // Apply sorting
      query = _applyContactSorting(query, filter?.sortBy ?? SortType.latest);

      // Apply pagination
      if (lastDocument != null) {
        query = query.startAfterDocument(lastDocument);
      }

      query = query.limit(limit);

      final snapshot = await query.get();
      return snapshot.docs
          .map((doc) => ProfessionalContact.fromFirestore(doc))
          .toList();
    } catch (e) {
      throw Exception('Failed to get contacts: $e');
    }
  }

  // Search professional contacts
  static Future<List<ProfessionalContact>> searchContacts(
    String query, {
    CommunitySearchFilter? filter,
  }) async {
    try {
      Query firestoreQuery = _firestore
          .collection('professional_contacts')
          .where('status', isEqualTo: ContactStatus.active.toString());

      if (filter != null) {
        firestoreQuery = _applyContactFilters(firestoreQuery, filter);
      }

      final snapshot = await firestoreQuery.get();
      final contacts = snapshot.docs
          .map((doc) => ProfessionalContact.fromFirestore(doc))
          .toList();

      // Filter by search query in memory
      return contacts
          .where(
            (contact) =>
                contact.name.toLowerCase().contains(query.toLowerCase()) ||
                contact.designation.toLowerCase().contains(
                  query.toLowerCase(),
                ) ||
                contact.department.toLowerCase().contains(
                  query.toLowerCase(),
                ) ||
                contact.specializations.any(
                  (spec) => spec.toLowerCase().contains(query.toLowerCase()),
                ),
          )
          .toList();
    } catch (e) {
      throw Exception('Failed to search contacts: $e');
    }
  }

  // Verify professional contact
  static Future<void> verifyContact(
    String contactId,
    String verifierId,
    String verifierName,
  ) async {
    try {
      await _firestore
          .collection('professional_contacts')
          .doc(contactId)
          .update({
            'isVerified': true,
            'verifiedBy': verifierId,
            'verifiedByName': verifierName,
            'verifiedAt': Timestamp.now(),
          });

      // Notify contact creator
      final contact = await getProfessionalContact(contactId);
      if (contact != null) {
        await NotificationService.sendContactVerificationNotification(
          contact,
          true,
        );
      }
    } catch (e) {
      throw Exception('Failed to verify contact: $e');
    }
  }

  // Add contact review
  static Future<void> addContactReview(ContactReview review) async {
    try {
      await _firestore.collection('contact_reviews').add(review.toFirestore());

      // Update contact metrics
      await _updateContactMetrics(review.contactId);
    } catch (e) {
      throw Exception('Failed to add review: $e');
    }
  }

  // Get contact reviews
  static Future<List<ContactReview>> getContactReviews(String contactId) async {
    try {
      final snapshot = await _firestore
          .collection('contact_reviews')
          .where('contactId', isEqualTo: contactId)
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => ContactReview.fromFirestore(doc))
          .toList();
    } catch (e) {
      throw Exception('Failed to get reviews: $e');
    }
  }

  // ==================== COMMENT SERVICES ====================

  // Add comment to post
  static Future<String> addComment(PostComment comment) async {
    try {
      final docRef = await _firestore
          .collection('post_comments')
          .add(comment.toFirestore());

      // Update post comment count
      await _firestore.collection('community_posts').doc(comment.postId).update(
        {'metrics.comments': FieldValue.increment(1)},
      );

      // Notify post author and mentioned users
      await NotificationService.sendCommentNotification(comment);

      return docRef.id;
    } catch (e) {
      throw Exception('Failed to add comment: $e');
    }
  }

  // Get comments for a post
  static Future<List<PostComment>> getPostComments(String postId) async {
    try {
      final snapshot = await _firestore
          .collection('post_comments')
          .where('postId', isEqualTo: postId)
          .orderBy('createdAt', descending: false)
          .get();

      return snapshot.docs
          .map((doc) => PostComment.fromFirestore(doc))
          .toList();
    } catch (e) {
      throw Exception('Failed to get comments: $e');
    }
  }

  // ==================== HELPER METHODS ====================

  static Query _applyPostFilters(Query query, CommunitySearchFilter filter) {
    if (filter.categories.isNotEmpty) {
      query = query.where('category', whereIn: filter.categories);
    }

    if (filter.voltagelevels.isNotEmpty) {
      query = query.where(
        'electricalData.voltageLevel',
        whereIn: filter.voltagelevels,
      );
    }

    if (filter.equipmentTypes.isNotEmpty) {
      query = query.where(
        'electricalData.equipmentType',
        whereIn: filter.equipmentTypes,
      );
    }

    if (filter.dateRange != null) {
      query = query
          .where(
            'createdAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(
              filter.dateRange!.startDate,
            ),
          )
          .where(
            'createdAt',
            isLessThanOrEqualTo: Timestamp.fromDate(filter.dateRange!.endDate),
          );
    }

    return query;
  }

  static Query _applyContactFilters(Query query, CommunitySearchFilter filter) {
    if (filter.contactType != null) {
      query = query.where(
        'contactType',
        isEqualTo: filter.contactType.toString(),
      );
    }

    if (filter.isVerified != null) {
      query = query.where('isVerified', isEqualTo: filter.isVerified);
    }

    if (filter.voltagelevels.isNotEmpty) {
      query = query.where(
        'electricalExpertise.voltageExpertise',
        arrayContainsAny: filter.voltagelevels,
      );
    }

    return query;
  }

  static Query _applySorting(Query query, SortType sortType) {
    switch (sortType) {
      case SortType.latest:
        return query.orderBy('createdAt', descending: true);
      case SortType.oldest:
        return query.orderBy('createdAt', descending: false);
      case SortType.mostLiked:
        return query.orderBy('metrics.likes', descending: true);
      case SortType.mostViewed:
        return query.orderBy('metrics.views', descending: true);
      default:
        return query.orderBy('createdAt', descending: true);
    }
  }

  static Query _applyContactSorting(Query query, SortType sortType) {
    switch (sortType) {
      case SortType.rating:
        return query.orderBy('metrics.rating', descending: true);
      case SortType.alphabetical:
        return query.orderBy('name', descending: false);
      case SortType.latest:
        return query.orderBy('createdAt', descending: true);
      default:
        return query.orderBy('createdAt', descending: true);
    }
  }

  static double _calculateTrendingScore(KnowledgePost post) {
    final now = DateTime.now();
    final hoursOld = now.difference(post.createdAt.toDate()).inHours;

    // Trending algorithm: (likes + views/10 + comments*2) / (hoursOld + 1)
    final engagementScore =
        post.metrics.likes +
        (post.metrics.views / 10) +
        (post.metrics.comments * 2);
    return engagementScore / (hoursOld + 1);
  }

  static Future<void> _incrementPostViews(String postId) async {
    await _firestore.collection('community_posts').doc(postId).update({
      'metrics.views': FieldValue.increment(1),
      'metrics.lastViewed': Timestamp.now(),
    });
  }

  static Future<void> _incrementContactViews(String contactId) async {
    await _firestore.collection('professional_contacts').doc(contactId).update({
      'metrics.timesViewed': FieldValue.increment(1),
    });
  }

  static Future<void> _sendForApproval(
    String postId,
    KnowledgePost post,
  ) async {
    final approvers = await _getApproversForUser(post.authorId);

    await _firestore.collection('community_posts').doc(postId).update({
      'approvers': approvers,
    });

    // Send notifications to approvers
    await NotificationService.sendApprovalRequestNotification(
      postId,
      approvers,
    );
  }

  static Future<void> _sendContactForVerification(
    String contactId,
    ProfessionalContact contact,
  ) async {
    final verifiers = await _getVerifiersForUser(contact.addedBy);

    await _firestore.collection('professional_contacts').doc(contactId).update({
      'verifiers': verifiers,
    });

    // Send notifications to verifiers
    await NotificationService.sendVerificationRequestNotification(
      contactId,
      verifiers,
    );
  }

  static Future<List<String>> _getApproversForUser(String userId) async {
    // Implementation based on your user hierarchy system
    // Return list of user IDs who can approve posts for this user
    // This would integrate with your existing UserRole system
    return [];
  }

  static Future<List<String>> _getVerifiersForUser(String userId) async {
    // Implementation based on your user hierarchy system
    // Return list of user IDs who can verify contacts for this user
    return [];
  }

  static Future<void> _updateContactMetrics(String contactId) async {
    // Recalculate contact rating and metrics based on reviews
    final reviews = await getContactReviews(contactId);

    if (reviews.isNotEmpty) {
      final avgRating =
          reviews.map((r) => r.rating).reduce((a, b) => a + b) / reviews.length;

      await _firestore
          .collection('professional_contacts')
          .doc(contactId)
          .update({
            'metrics.rating': avgRating,
            'metrics.totalReviews': reviews.length,
          });
    }
  }

  static String _getFileType(String extension) {
    switch (extension.toLowerCase()) {
      case 'pdf':
        return 'pdf';
      case 'doc':
      case 'docx':
        return 'doc';
      case 'xls':
      case 'xlsx':
        return 'excel';
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
        return 'image';
      case 'mp4':
      case 'avi':
      case 'mov':
        return 'video';
      default:
        return 'other';
    }
  }
}
