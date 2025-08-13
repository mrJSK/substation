// lib/services/notification_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../models/community_models.dart';
import '../models/user_model.dart';
import '../models/notification_model.dart';

class NotificationService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  // ==================== COMMUNITY NOTIFICATION METHODS ====================

  // Send notification when post approval status changes
  static Future<void> sendPostApprovalNotification(
    KnowledgePost post,
    bool approved,
  ) async {
    try {
      final notification = AppNotification(
        id: null,
        userId: post.authorId,
        title: approved ? 'Post Approved! 🎉' : 'Post Needs Revision 📝',
        message: approved
            ? 'Your post "${post.title}" has been approved and is now live!'
            : 'Your post "${post.title}" needs revision. ${post.rejectionReason ?? "Please check the feedback."}',
        type: NotificationType.postApproval,
        data: {
          'postId': post.id,
          'postTitle': post.title,
          'approved': approved,
          'approvedBy': post.approvedByName,
          'rejectionReason': post.rejectionReason,
        },
        isRead: false,
        createdAt: Timestamp.now(),
      );

      await _createNotification(notification);

      // Send push notification
      await _sendPushNotification(
        userId: post.authorId,
        title: notification.title,
        body: notification.message,
        data: notification.data ?? {},
      );
    } catch (e) {
      print('Error sending post approval notification: $e');
    }
  }

  // Send notification when someone comments on a post
  static Future<void> sendCommentNotification(PostComment comment) async {
    try {
      // Get the post to notify the author
      final postDoc = await _firestore
          .collection('community_posts')
          .doc(comment.postId)
          .get();
      if (!postDoc.exists) return;

      final post = KnowledgePost.fromFirestore(postDoc);

      // Don't notify if commenting on own post
      if (post.authorId == comment.authorId) return;

      final notification = AppNotification(
        id: null,
        userId: post.authorId,
        title: 'New Comment 💬',
        message: '${comment.authorName} commented on your post "${post.title}"',
        type: NotificationType.comment,
        data: {
          'postId': comment.postId,
          'commentId': comment.id,
          'postTitle': post.title,
          'commenterName': comment.authorName,
          'commentContent': comment.content.length > 100
              ? comment.content.substring(0, 100) + '...'
              : comment.content,
        },
        isRead: false,
        createdAt: Timestamp.now(),
      );

      await _createNotification(notification);
      await _sendPushNotification(
        userId: post.authorId,
        title: notification.title,
        body: notification.message,
        data: notification.data ?? {},
      );

      // Also notify mentioned users
      await _notifyMentionedUsers(comment);
    } catch (e) {
      print('Error sending comment notification: $e');
    }
  }

  // Send notification when a post needs approval
  static Future<void> sendApprovalRequestNotification(
    String postId,
    List<String> approverIds,
  ) async {
    try {
      final postDoc = await _firestore
          .collection('community_posts')
          .doc(postId)
          .get();
      if (!postDoc.exists) return;

      final post = KnowledgePost.fromFirestore(postDoc);

      for (String approverId in approverIds) {
        final notification = AppNotification(
          id: null,
          userId: approverId,
          title: 'New Post Approval Request 📋',
          message: '${post.authorName} submitted "${post.title}" for approval',
          type: NotificationType.approvalRequest,
          data: {
            'postId': postId,
            'postTitle': post.title,
            'authorName': post.authorName,
            'category': post.category,
          },
          isRead: false,
          createdAt: Timestamp.now(),
        );

        await _createNotification(notification);
        await _sendPushNotification(
          userId: approverId,
          title: notification.title,
          body: notification.message,
          data: notification.data ?? {},
        );
      }
    } catch (e) {
      print('Error sending approval request notification: $e');
    }
  }

  // Send notification when contact verification status changes
  static Future<void> sendContactVerificationNotification(
    ProfessionalContact contact,
    bool verified,
  ) async {
    try {
      final notification = AppNotification(
        id: null,
        userId: contact.addedBy,
        title: verified
            ? 'Contact Verified! ✅'
            : 'Contact Verification Needed 📋',
        message: verified
            ? 'Contact "${contact.name}" has been verified and is now visible to all users!'
            : 'Contact "${contact.name}" needs additional verification.',
        type: NotificationType.contactVerification,
        data: {
          'contactId': contact.id,
          'contactName': contact.name,
          'verified': verified,
          'verifiedBy': contact.verifiedByName,
        },
        isRead: false,
        createdAt: Timestamp.now(),
      );

      await _createNotification(notification);
      await _sendPushNotification(
        userId: contact.addedBy,
        title: notification.title,
        body: notification.message,
        data: notification.data ?? {},
      );
    } catch (e) {
      print('Error sending contact verification notification: $e');
    }
  }

  // Send notification when contact needs verification
  static Future<void> sendVerificationRequestNotification(
    String contactId,
    List<String> verifierIds,
  ) async {
    try {
      final contactDoc = await _firestore
          .collection('professional_contacts')
          .doc(contactId)
          .get();
      if (!contactDoc.exists) return;

      final contact = ProfessionalContact.fromFirestore(contactDoc);

      for (String verifierId in verifierIds) {
        final notification = AppNotification(
          id: null,
          userId: verifierId,
          title: 'New Contact Verification Request 🔍',
          message:
              'New ${contact.contactType.toString().split('.').last} "${contact.name}" needs verification',
          type: NotificationType.verificationRequest,
          data: {
            'contactId': contactId,
            'contactName': contact.name,
            'contactType': contact.contactType.toString(),
            'department': contact.department,
          },
          isRead: false,
          createdAt: Timestamp.now(),
        );

        await _createNotification(notification);
        await _sendPushNotification(
          userId: verifierId,
          title: notification.title,
          body: notification.message,
          data: notification.data ?? {},
        );
      }
    } catch (e) {
      print('Error sending verification request notification: $e');
    }
  }

  // Send notification when someone gets a new review
  static Future<void> sendNewReviewNotification(
    ContactReview review,
    String contactOwnerId,
  ) async {
    try {
      final notification = AppNotification(
        id: null,
        userId: contactOwnerId,
        title: 'New Review Received! ⭐',
        message:
            '${review.reviewerName} rated your contact ${review.rating.toStringAsFixed(1)} stars',
        type: NotificationType.newReview,
        data: {
          'contactId': review.contactId,
          'reviewId': review.id,
          'rating': review.rating,
          'reviewerName': review.reviewerName,
          'projectType': review.projectType,
        },
        isRead: false,
        createdAt: Timestamp.now(),
      );

      await _createNotification(notification);
      await _sendPushNotification(
        userId: contactOwnerId,
        title: notification.title,
        body: notification.message,
        data: notification.data ?? {},
      );
    } catch (e) {
      print('Error sending new review notification: $e');
    }
  }

  // Send notification when a post becomes trending
  static Future<void> sendTrendingPostNotification(KnowledgePost post) async {
    try {
      final notification = AppNotification(
        id: null,
        userId: post.authorId,
        title: 'Your Post is Trending! 🔥',
        message: 'Your post "${post.title}" is now trending in the community!',
        type: NotificationType.trending,
        data: {
          'postId': post.id,
          'postTitle': post.title,
          'views': post.metrics.views,
          'likes': post.metrics.likes,
        },
        isRead: false,
        createdAt: Timestamp.now(),
      );

      await _createNotification(notification);
      await _sendPushNotification(
        userId: post.authorId,
        title: notification.title,
        body: notification.message,
        data: notification.data ?? {},
      );
    } catch (e) {
      print('Error sending trending notification: $e');
    }
  }

  // Send weekly digest notification
  static Future<void> sendWeeklyDigestNotification(
    String userId,
    Map<String, dynamic> digestData,
  ) async {
    try {
      final notification = AppNotification(
        id: null,
        userId: userId,
        title: 'Weekly Community Digest 📊',
        message: 'See what\'s new in your community this week!',
        type: NotificationType.weeklyDigest,
        data: {
          'newPosts': digestData['newPosts'] ?? 0,
          'trendingPosts': digestData['trendingPosts'] ?? [],
          'newContacts': digestData['newContacts'] ?? 0,
          'yourPostsViews': digestData['yourPostsViews'] ?? 0,
        },
        isRead: false,
        createdAt: Timestamp.now(),
      );

      await _createNotification(notification);
      await _sendPushNotification(
        userId: userId,
        title: notification.title,
        body: notification.message,
        data: notification.data ?? {},
      );
    } catch (e) {
      print('Error sending weekly digest notification: $e');
    }
  }

  // Send notification when someone likes your post
  static Future<void> sendPostLikedNotification(
    String postId,
    String likedByUserId,
    String likedByUserName,
  ) async {
    try {
      final postDoc = await _firestore
          .collection('community_posts')
          .doc(postId)
          .get();
      if (!postDoc.exists) return;

      final post = KnowledgePost.fromFirestore(postDoc);

      // Don't notify if liking own post
      if (post.authorId == likedByUserId) return;

      // Check if user wants like notifications
      final userPrefs = await _getUserNotificationPreferences(post.authorId);
      if (userPrefs['notifyOnLikes'] == false) return;

      final notification = AppNotification(
        id: null,
        userId: post.authorId,
        title: 'Someone liked your post! 👍',
        message: '$likedByUserName liked your post "${post.title}"',
        type: NotificationType.postLiked,
        data: {
          'postId': postId,
          'postTitle': post.title,
          'likedBy': likedByUserName,
          'totalLikes': post.metrics.likes + 1,
        },
        isRead: false,
        createdAt: Timestamp.now(),
      );

      await _createNotification(notification);
      // Don't send push notification for likes to avoid spam
    } catch (e) {
      print('Error sending post liked notification: $e');
    }
  }

  // ==================== HELPER METHODS ====================

  // Create notification in database
  static Future<void> _createNotification(AppNotification notification) async {
    try {
      await _firestore
          .collection('notifications')
          .add(notification.toFirestore());
    } catch (e) {
      print('Error creating notification: $e');
    }
  }

  // Send push notification
  static Future<void> _sendPushNotification({
    required String userId,
    required String title,
    required String body,
    required Map<String, dynamic> data,
  }) async {
    try {
      // Get user's FCM token
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) return;

      final userData = userDoc.data() as Map<String, dynamic>;
      final fcmToken = userData['fcmToken'] as String?;

      if (fcmToken == null) return;

      // Check notification preferences
      final prefs = await _getUserNotificationPreferences(userId);
      if (prefs['pushNotificationsEnabled'] == false) return;

      // Send the push notification
      // Note: You'll need to implement the actual FCM sending logic
      // This is typically done through your backend server or using Firebase Admin SDK

      print('Sending push notification to $userId: $title');
    } catch (e) {
      print('Error sending push notification: $e');
    }
  }

  // Notify mentioned users in comments
  static Future<void> _notifyMentionedUsers(PostComment comment) async {
    try {
      for (String mentionedUserId in comment.mentions) {
        if (mentionedUserId == comment.authorId) continue; // Don't notify self

        final notification = AppNotification(
          id: null,
          userId: mentionedUserId,
          title: 'You were mentioned! 👥',
          message: '${comment.authorName} mentioned you in a comment',
          type: NotificationType.mention,
          data: {
            'postId': comment.postId,
            'commentId': comment.id,
            'mentionedBy': comment.authorName,
            'commentContent': comment.content.length > 100
                ? comment.content.substring(0, 100) + '...'
                : comment.content,
          },
          isRead: false,
          createdAt: Timestamp.now(),
        );

        await _createNotification(notification);
        await _sendPushNotification(
          userId: mentionedUserId,
          title: notification.title,
          body: notification.message,
          data: notification.data ?? {},
        );
      }
    } catch (e) {
      print('Error notifying mentioned users: $e');
    }
  }

  // Get user notification preferences
  static Future<Map<String, dynamic>> _getUserNotificationPreferences(
    String userId,
  ) async {
    try {
      final doc = await _firestore
          .collection('notification_preferences')
          .doc(userId)
          .get();
      if (doc.exists) {
        return doc.data() as Map<String, dynamic>;
      }

      // Return default preferences
      return {
        'pushNotificationsEnabled': true,
        'notifyOnLikes': false,
        'notifyOnComments': true,
        'notifyOnMentions': true,
        'notifyOnApprovals': true,
        'notifyOnTrending': true,
        'weeklyDigest': true,
      };
    } catch (e) {
      print('Error getting notification preferences: $e');
      return {};
    }
  }

  // ==================== BATCH NOTIFICATION METHODS ====================

  // Send notifications to multiple users (for announcements)
  static Future<void> sendBulkNotification({
    required List<String> userIds,
    required String title,
    required String message,
    required NotificationType type,
    Map<String, dynamic>? data,
  }) async {
    try {
      final batch = _firestore.batch();

      for (String userId in userIds) {
        final notification = AppNotification(
          id: null,
          userId: userId,
          title: title,
          message: message,
          type: type,
          data: data,
          isRead: false,
          createdAt: Timestamp.now(),
        );

        final docRef = _firestore.collection('notifications').doc();
        batch.set(docRef, notification.toFirestore());
      }

      await batch.commit();

      // Send push notifications (implement rate limiting if needed)
      for (String userId in userIds) {
        await _sendPushNotification(
          userId: userId,
          title: title,
          body: message,
          data: data ?? {},
        );
      }
    } catch (e) {
      print('Error sending bulk notification: $e');
    }
  }

  // Send notification to all users in a specific role
  static Future<void> sendRoleBasedNotification({
    required UserRole role,
    required String title,
    required String message,
    required NotificationType type,
    Map<String, dynamic>? data,
  }) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .where('role', isEqualTo: role.toString())
          .get();

      final userIds = snapshot.docs.map((doc) => doc.id).toList();

      await sendBulkNotification(
        userIds: userIds,
        title: title,
        message: message,
        type: type,
        data: data,
      );
    } catch (e) {
      print('Error sending role-based notification: $e');
    }
  }

  // ==================== NOTIFICATION CLEANUP ====================

  // Clean up old notifications (call this periodically)
  static Future<void> cleanupOldNotifications({int daysOld = 30}) async {
    try {
      final cutoffDate = DateTime.now().subtract(Duration(days: daysOld));
      final snapshot = await _firestore
          .collection('notifications')
          .where('createdAt', isLessThan: Timestamp.fromDate(cutoffDate))
          .get();

      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
      print('Cleaned up ${snapshot.docs.length} old notifications');
    } catch (e) {
      print('Error cleaning up notifications: $e');
    }
  }
}
