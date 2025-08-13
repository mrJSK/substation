// lib/models/notification_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class AppNotification {
  final String? id;
  final String userId;
  final String title;
  final String message;
  final NotificationType type;
  final Map<String, dynamic>? data;
  final bool isRead;
  final NotificationPriority priority;
  final Timestamp createdAt;
  final Timestamp? readAt;
  final String? actionUrl; // Deep link for navigation
  final String? imageUrl; // Optional image for rich notifications
  final Timestamp? expiresAt; // Auto-delete after this time

  AppNotification({
    this.id,
    required this.userId,
    required this.title,
    required this.message,
    required this.type,
    this.data,
    this.isRead = false,
    this.priority = NotificationPriority.normal,
    required this.createdAt,
    this.readAt,
    this.actionUrl,
    this.imageUrl,
    this.expiresAt,
  });

  factory AppNotification.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AppNotification(
      id: doc.id,
      userId: data['userId'] ?? '',
      title: data['title'] ?? '',
      message: data['message'] ?? '',
      type: NotificationType.values.firstWhere(
        (e) => e.toString() == data['type'],
        orElse: () => NotificationType.general,
      ),
      data: data['data'] != null
          ? Map<String, dynamic>.from(data['data'])
          : null,
      isRead: data['isRead'] ?? false,
      priority: NotificationPriority.values.firstWhere(
        (e) => e.toString() == data['priority'],
        orElse: () => NotificationPriority.normal,
      ),
      createdAt: data['createdAt'] ?? Timestamp.now(),
      readAt: data['readAt'],
      actionUrl: data['actionUrl'],
      imageUrl: data['imageUrl'],
      expiresAt: data['expiresAt'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'title': title,
      'message': message,
      'type': type.toString(),
      'data': data,
      'isRead': isRead,
      'priority': priority.toString(),
      'createdAt': createdAt,
      'readAt': readAt,
      'actionUrl': actionUrl,
      'imageUrl': imageUrl,
      'expiresAt': expiresAt,
    };
  }

  // Create a copy with updated fields
  AppNotification copyWith({
    String? id,
    String? userId,
    String? title,
    String? message,
    NotificationType? type,
    Map<String, dynamic>? data,
    bool? isRead,
    NotificationPriority? priority,
    Timestamp? createdAt,
    Timestamp? readAt,
    String? actionUrl,
    String? imageUrl,
    Timestamp? expiresAt,
  }) {
    return AppNotification(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      message: message ?? this.message,
      type: type ?? this.type,
      data: data ?? this.data,
      isRead: isRead ?? this.isRead,
      priority: priority ?? this.priority,
      createdAt: createdAt ?? this.createdAt,
      readAt: readAt ?? this.readAt,
      actionUrl: actionUrl ?? this.actionUrl,
      imageUrl: imageUrl ?? this.imageUrl,
      expiresAt: expiresAt ?? this.expiresAt,
    );
  }

  // Mark notification as read
  AppNotification markAsRead() {
    return copyWith(isRead: true, readAt: Timestamp.now());
  }

  // Check if notification is expired
  bool get isExpired {
    if (expiresAt == null) return false;
    return DateTime.now().isAfter(expiresAt!.toDate());
  }

  // Get time ago string
  String get timeAgo {
    final now = DateTime.now();
    final notificationTime = createdAt.toDate();
    final difference = now.difference(notificationTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${(difference.inDays / 7).floor()}w ago';
    }
  }

  // Get icon based on notification type
  String get iconName {
    switch (type) {
      case NotificationType.postApproval:
        return 'check_circle';
      case NotificationType.comment:
        return 'comment';
      case NotificationType.mention:
        return 'alternate_email';
      case NotificationType.postLiked:
        return 'thumb_up';
      case NotificationType.approvalRequest:
        return 'approval';
      case NotificationType.contactVerification:
        return 'verified_user';
      case NotificationType.verificationRequest:
        return 'fact_check';
      case NotificationType.newReview:
        return 'star';
      case NotificationType.trending:
        return 'trending_up';
      case NotificationType.weeklyDigest:
        return 'insights';
      case NotificationType.reminder:
        return 'schedule';
      case NotificationType.alert:
        return 'warning';
      case NotificationType.maintenance:
        return 'build';
      case NotificationType.emergency:
        return 'emergency';
      case NotificationType.general:
      default:
        return 'notifications';
    }
  }

  // Get color based on notification type and priority
  String get colorHex {
    if (priority == NotificationPriority.urgent) {
      return '#F44336'; // Red
    } else if (priority == NotificationPriority.high) {
      return '#FF9800'; // Orange
    }

    switch (type) {
      case NotificationType.postApproval:
        return '#4CAF50'; // Green
      case NotificationType.comment:
      case NotificationType.mention:
        return '#2196F3'; // Blue
      case NotificationType.postLiked:
        return '#E91E63'; // Pink
      case NotificationType.trending:
        return '#FF5722'; // Deep Orange
      case NotificationType.emergency:
        return '#F44336'; // Red
      case NotificationType.maintenance:
        return '#FF9800'; // Orange
      default:
        return '#757575'; // Grey
    }
  }
}

// Notification Types - Extended for community features
enum NotificationType {
  // General notifications
  general,
  reminder,
  alert,
  maintenance,
  emergency,

  // Community Knowledge Hub notifications
  postApproval, // Post approved/rejected
  comment, // New comment on post
  mention, // User mentioned in comment
  postLiked, // Post received a like
  approvalRequest, // Post needs approval
  trending, // Post is trending
  weeklyDigest, // Weekly summary
  // Professional Directory notifications
  contactVerification, // Contact verified/rejected
  verificationRequest, // Contact needs verification
  newReview, // New review received
  // System notifications
  systemUpdate,
  announcement,
  policyUpdate,
}

// Notification Priority Levels
enum NotificationPriority {
  low, // Can be batched, shown later
  normal, // Standard notifications
  high, // Important, show prominently
  urgent, // Critical, show immediately with sound/vibration
}

// Notification Preferences Model
class NotificationPreferences {
  final String userId;
  final bool pushNotificationsEnabled;
  final bool inAppNotificationsEnabled;
  final bool emailNotificationsEnabled;
  final bool soundEnabled;
  final bool vibrationEnabled;
  final String quietHoursStart; // "22:00"
  final String quietHoursEnd; // "07:00"
  final CommunityNotificationPreferences community;
  final SystemNotificationPreferences system;
  final Timestamp? updatedAt;

  NotificationPreferences({
    required this.userId,
    this.pushNotificationsEnabled = true,
    this.inAppNotificationsEnabled = true,
    this.emailNotificationsEnabled = false,
    this.soundEnabled = true,
    this.vibrationEnabled = true,
    this.quietHoursStart = "22:00",
    this.quietHoursEnd = "07:00",
    required this.community,
    required this.system,
    this.updatedAt,
  });

  factory NotificationPreferences.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return NotificationPreferences(
      userId: doc.id,
      pushNotificationsEnabled: data['pushNotificationsEnabled'] ?? true,
      inAppNotificationsEnabled: data['inAppNotificationsEnabled'] ?? true,
      emailNotificationsEnabled: data['emailNotificationsEnabled'] ?? false,
      soundEnabled: data['soundEnabled'] ?? true,
      vibrationEnabled: data['vibrationEnabled'] ?? true,
      quietHoursStart: data['quietHoursStart'] ?? "22:00",
      quietHoursEnd: data['quietHoursEnd'] ?? "07:00",
      community: CommunityNotificationPreferences.fromMap(
        data['community'] ?? {},
      ),
      system: SystemNotificationPreferences.fromMap(data['system'] ?? {}),
      updatedAt: data['updatedAt'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'pushNotificationsEnabled': pushNotificationsEnabled,
      'inAppNotificationsEnabled': inAppNotificationsEnabled,
      'emailNotificationsEnabled': emailNotificationsEnabled,
      'soundEnabled': soundEnabled,
      'vibrationEnabled': vibrationEnabled,
      'quietHoursStart': quietHoursStart,
      'quietHoursEnd': quietHoursEnd,
      'community': community.toMap(),
      'system': system.toMap(),
      'updatedAt': Timestamp.now(),
    };
  }

  // Check if currently in quiet hours
  bool get isInQuietHours {
    final now = DateTime.now();
    final currentTime =
        "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";

    // Handle quiet hours that span midnight
    if (quietHoursStart.compareTo(quietHoursEnd) > 0) {
      return currentTime.compareTo(quietHoursStart) >= 0 ||
          currentTime.compareTo(quietHoursEnd) <= 0;
    } else {
      return currentTime.compareTo(quietHoursStart) >= 0 &&
          currentTime.compareTo(quietHoursEnd) <= 0;
    }
  }
}

// Community-specific notification preferences
class CommunityNotificationPreferences {
  final bool notifyOnPostApproval;
  final bool notifyOnComments;
  final bool notifyOnMentions;
  final bool notifyOnLikes;
  final bool notifyOnTrending;
  final bool notifyOnContactVerification;
  final bool notifyOnNewReviews;
  final bool weeklyDigest;
  final List<String> followedCategories;
  final List<String> followedTags;
  final List<String> followedAuthors;
  final bool digestOnlyForFollowed; // Only include followed content in digest

  CommunityNotificationPreferences({
    this.notifyOnPostApproval = true,
    this.notifyOnComments = true,
    this.notifyOnMentions = true,
    this.notifyOnLikes = false,
    this.notifyOnTrending = true,
    this.notifyOnContactVerification = true,
    this.notifyOnNewReviews = true,
    this.weeklyDigest = true,
    this.followedCategories = const [],
    this.followedTags = const [],
    this.followedAuthors = const [],
    this.digestOnlyForFollowed = false,
  });

  factory CommunityNotificationPreferences.fromMap(Map<String, dynamic> map) {
    return CommunityNotificationPreferences(
      notifyOnPostApproval: map['notifyOnPostApproval'] ?? true,
      notifyOnComments: map['notifyOnComments'] ?? true,
      notifyOnMentions: map['notifyOnMentions'] ?? true,
      notifyOnLikes: map['notifyOnLikes'] ?? false,
      notifyOnTrending: map['notifyOnTrending'] ?? true,
      notifyOnContactVerification: map['notifyOnContactVerification'] ?? true,
      notifyOnNewReviews: map['notifyOnNewReviews'] ?? true,
      weeklyDigest: map['weeklyDigest'] ?? true,
      followedCategories: List<String>.from(map['followedCategories'] ?? []),
      followedTags: List<String>.from(map['followedTags'] ?? []),
      followedAuthors: List<String>.from(map['followedAuthors'] ?? []),
      digestOnlyForFollowed: map['digestOnlyForFollowed'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'notifyOnPostApproval': notifyOnPostApproval,
      'notifyOnComments': notifyOnComments,
      'notifyOnMentions': notifyOnMentions,
      'notifyOnLikes': notifyOnLikes,
      'notifyOnTrending': notifyOnTrending,
      'notifyOnContactVerification': notifyOnContactVerification,
      'notifyOnNewReviews': notifyOnNewReviews,
      'weeklyDigest': weeklyDigest,
      'followedCategories': followedCategories,
      'followedTags': followedTags,
      'followedAuthors': followedAuthors,
      'digestOnlyForFollowed': digestOnlyForFollowed,
    };
  }
}

// System notification preferences
class SystemNotificationPreferences {
  final bool notifyOnMaintenance;
  final bool notifyOnEmergency;
  final bool notifyOnSystemUpdates;
  final bool notifyOnAnnouncements;
  final bool notifyOnPolicyUpdates;
  final bool notifyOnReminders;

  SystemNotificationPreferences({
    this.notifyOnMaintenance = true,
    this.notifyOnEmergency = true,
    this.notifyOnSystemUpdates = true,
    this.notifyOnAnnouncements = true,
    this.notifyOnPolicyUpdates = true,
    this.notifyOnReminders = true,
  });

  factory SystemNotificationPreferences.fromMap(Map<String, dynamic> map) {
    return SystemNotificationPreferences(
      notifyOnMaintenance: map['notifyOnMaintenance'] ?? true,
      notifyOnEmergency: map['notifyOnEmergency'] ?? true,
      notifyOnSystemUpdates: map['notifyOnSystemUpdates'] ?? true,
      notifyOnAnnouncements: map['notifyOnAnnouncements'] ?? true,
      notifyOnPolicyUpdates: map['notifyOnPolicyUpdates'] ?? true,
      notifyOnReminders: map['notifyOnReminders'] ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'notifyOnMaintenance': notifyOnMaintenance,
      'notifyOnEmergency': notifyOnEmergency,
      'notifyOnSystemUpdates': notifyOnSystemUpdates,
      'notifyOnAnnouncements': notifyOnAnnouncements,
      'notifyOnPolicyUpdates': notifyOnPolicyUpdates,
      'notifyOnReminders': notifyOnReminders,
    };
  }
}

// Notification action model for interactive notifications
class NotificationAction {
  final String id;
  final String title;
  final String? actionUrl;
  final Map<String, dynamic>? actionData;
  final bool dismissOnTap;

  NotificationAction({
    required this.id,
    required this.title,
    this.actionUrl,
    this.actionData,
    this.dismissOnTap = true,
  });

  factory NotificationAction.fromMap(Map<String, dynamic> map) {
    return NotificationAction(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      actionUrl: map['actionUrl'],
      actionData: map['actionData'] != null
          ? Map<String, dynamic>.from(map['actionData'])
          : null,
      dismissOnTap: map['dismissOnTap'] ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'actionUrl': actionUrl,
      'actionData': actionData,
      'dismissOnTap': dismissOnTap,
    };
  }
}

// Batch notification model for sending multiple notifications at once
class BatchNotification {
  final List<String> userIds;
  final String title;
  final String message;
  final NotificationType type;
  final Map<String, dynamic>? data;
  final NotificationPriority priority;
  final List<NotificationAction>? actions;
  final Timestamp? scheduledFor; // For scheduled notifications

  BatchNotification({
    required this.userIds,
    required this.title,
    required this.message,
    required this.type,
    this.data,
    this.priority = NotificationPriority.normal,
    this.actions,
    this.scheduledFor,
  });

  Map<String, dynamic> toMap() {
    return {
      'userIds': userIds,
      'title': title,
      'message': message,
      'type': type.toString(),
      'data': data,
      'priority': priority.toString(),
      'actions': actions?.map((a) => a.toMap()).toList(),
      'scheduledFor': scheduledFor,
    };
  }
}

// Notification statistics model for analytics
class NotificationStats {
  final String userId;
  final int totalReceived;
  final int totalRead;
  final int totalUnread;
  final Map<String, int> typeBreakdown; // NotificationType -> count
  final Map<String, int> priorityBreakdown; // NotificationPriority -> count
  final double readRate; // Percentage of notifications read
  final Timestamp lastCalculated;

  NotificationStats({
    required this.userId,
    required this.totalReceived,
    required this.totalRead,
    required this.totalUnread,
    required this.typeBreakdown,
    required this.priorityBreakdown,
    required this.readRate,
    required this.lastCalculated,
  });

  factory NotificationStats.fromMap(Map<String, dynamic> map) {
    return NotificationStats(
      userId: map['userId'] ?? '',
      totalReceived: map['totalReceived'] ?? 0,
      totalRead: map['totalRead'] ?? 0,
      totalUnread: map['totalUnread'] ?? 0,
      typeBreakdown: Map<String, int>.from(map['typeBreakdown'] ?? {}),
      priorityBreakdown: Map<String, int>.from(map['priorityBreakdown'] ?? {}),
      readRate: (map['readRate'] ?? 0.0).toDouble(),
      lastCalculated: map['lastCalculated'] ?? Timestamp.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'totalReceived': totalReceived,
      'totalRead': totalRead,
      'totalUnread': totalUnread,
      'typeBreakdown': typeBreakdown,
      'priorityBreakdown': priorityBreakdown,
      'readRate': readRate,
      'lastCalculated': lastCalculated,
    };
  }
}
