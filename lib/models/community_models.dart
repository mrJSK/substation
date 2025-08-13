// lib/models/community_models.dart

import 'package:cloud_firestore/cloud_firestore.dart';

// ==================== KNOWLEDGE HUB MODELS ====================

class KnowledgePost {
  final String? id;
  final String title;
  final String content;
  final String summary;
  final String authorId;
  final String authorName;
  final String authorDesignation;
  final String category;
  final List<String> tags;
  final List<PostAttachment> attachments;
  final PostStatus status;
  final String? approvedBy;
  final String? approvedByName;
  final String? rejectionReason;
  final Timestamp createdAt;
  final Timestamp? updatedAt;
  final Timestamp? approvedAt;
  final PostMetrics metrics;
  final PostElectricalData? electricalData;
  final PostVisibility visibility;
  final bool isPinned;
  final bool allowComments;
  final int priority;

  KnowledgePost({
    this.id,
    required this.title,
    required this.content,
    required this.summary,
    required this.authorId,
    required this.authorName,
    required this.authorDesignation,
    required this.category,
    this.tags = const [],
    this.attachments = const [],
    this.status = PostStatus.draft,
    this.approvedBy,
    this.approvedByName,
    this.rejectionReason,
    required this.createdAt,
    this.updatedAt,
    this.approvedAt,
    required this.metrics,
    this.electricalData,
    this.visibility = PostVisibility.public,
    this.isPinned = false,
    this.allowComments = true,
    this.priority = 2,
  });

  factory KnowledgePost.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return KnowledgePost(
      id: doc.id,
      title: data['title'] ?? '',
      content: data['content'] ?? '',
      summary: data['summary'] ?? '',
      authorId: data['authorId'] ?? '',
      authorName: data['authorName'] ?? '',
      authorDesignation: data['authorDesignation'] ?? '',
      category: data['category'] ?? '',
      tags: List<String>.from(data['tags'] ?? []),
      attachments:
          (data['attachments'] as List?)
              ?.map((e) => PostAttachment.fromMap(e))
              .toList() ??
          [],
      status: PostStatus.values.firstWhere(
        (e) => e.toString().split('.').last == (data['status'] ?? 'draft'),
        orElse: () => PostStatus.draft,
      ),
      approvedBy: data['approvedBy'],
      approvedByName: data['approvedByName'],
      rejectionReason: data['rejectionReason'],
      createdAt: data['createdAt'] ?? Timestamp.now(),
      updatedAt: data['updatedAt'],
      approvedAt: data['approvedAt'],
      metrics: PostMetrics.fromMap(data['metrics'] ?? {}),
      electricalData: data['electricalData'] != null
          ? PostElectricalData.fromMap(data['electricalData'])
          : null,
      visibility: PostVisibility.values.firstWhere(
        (e) => e.toString().split('.').last == (data['visibility'] ?? 'public'),
        orElse: () => PostVisibility.public,
      ),
      isPinned: data['isPinned'] ?? false,
      allowComments: data['allowComments'] ?? true,
      priority: data['priority'] ?? 2,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'content': content,
      'summary': summary,
      'authorId': authorId,
      'authorName': authorName,
      'authorDesignation': authorDesignation,
      'category': category,
      'tags': tags,
      'attachments': attachments.map((e) => e.toMap()).toList(),
      'status': status.toString().split('.').last,
      'approvedBy': approvedBy,
      'approvedByName': approvedByName,
      'rejectionReason': rejectionReason,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'approvedAt': approvedAt,
      'metrics': metrics.toMap(),
      'electricalData': electricalData?.toMap(),
      'visibility': visibility.toString().split('.').last,
      'isPinned': isPinned,
      'allowComments': allowComments,
      'priority': priority,
    };
  }

  KnowledgePost copyWith({
    String? id,
    String? title,
    String? content,
    String? summary,
    String? authorId,
    String? authorName,
    String? authorDesignation,
    String? category,
    List<String>? tags,
    List<PostAttachment>? attachments,
    PostStatus? status,
    String? approvedBy,
    String? approvedByName,
    String? rejectionReason,
    Timestamp? createdAt,
    Timestamp? updatedAt,
    Timestamp? approvedAt,
    PostMetrics? metrics,
    PostElectricalData? electricalData,
    PostVisibility? visibility,
    bool? isPinned,
    bool? allowComments,
    int? priority,
  }) {
    return KnowledgePost(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      summary: summary ?? this.summary,
      authorId: authorId ?? this.authorId,
      authorName: authorName ?? this.authorName,
      authorDesignation: authorDesignation ?? this.authorDesignation,
      category: category ?? this.category,
      tags: tags ?? this.tags,
      attachments: attachments ?? this.attachments,
      status: status ?? this.status,
      approvedBy: approvedBy ?? this.approvedBy,
      approvedByName: approvedByName ?? this.approvedByName,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      approvedAt: approvedAt ?? this.approvedAt,
      metrics: metrics ?? this.metrics,
      electricalData: electricalData ?? this.electricalData,
      visibility: visibility ?? this.visibility,
      isPinned: isPinned ?? this.isPinned,
      allowComments: allowComments ?? this.allowComments,
      priority: priority ?? this.priority,
    );
  }
}

class PostAttachment {
  final String fileName;
  final String fileUrl;
  final String fileType;
  final int fileSizeBytes;
  final Timestamp uploadedAt;
  final String? description;

  PostAttachment({
    required this.fileName,
    required this.fileUrl,
    required this.fileType,
    required this.fileSizeBytes,
    required this.uploadedAt,
    this.description,
  });

  factory PostAttachment.fromMap(Map<String, dynamic> map) {
    return PostAttachment(
      fileName: map['fileName'] ?? '',
      fileUrl: map['fileUrl'] ?? '',
      fileType: map['fileType'] ?? '',
      fileSizeBytes: map['fileSizeBytes'] ?? 0,
      uploadedAt: map['uploadedAt'] ?? Timestamp.now(),
      description: map['description'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'fileName': fileName,
      'fileUrl': fileUrl,
      'fileType': fileType,
      'fileSizeBytes': fileSizeBytes,
      'uploadedAt': uploadedAt,
      'description': description,
    };
  }

  PostAttachment copyWith({
    String? fileName,
    String? fileUrl,
    String? fileType,
    int? fileSizeBytes,
    Timestamp? uploadedAt,
    String? description,
  }) {
    return PostAttachment(
      fileName: fileName ?? this.fileName,
      fileUrl: fileUrl ?? this.fileUrl,
      fileType: fileType ?? this.fileType,
      fileSizeBytes: fileSizeBytes ?? this.fileSizeBytes,
      uploadedAt: uploadedAt ?? this.uploadedAt,
      description: description ?? this.description,
    );
  }
}

class PostMetrics {
  final int views;
  final int likes;
  final int dislikes;
  final int comments;
  final int shares;
  final int bookmarks;
  final double helpfulnessRating;
  final int helpfulnessVotes;
  final Timestamp? lastViewed;
  final List<String> likedBy;

  PostMetrics({
    this.views = 0,
    this.likes = 0,
    this.dislikes = 0,
    this.comments = 0,
    this.shares = 0,
    this.bookmarks = 0,
    this.helpfulnessRating = 0.0,
    this.helpfulnessVotes = 0,
    this.lastViewed,
    this.likedBy = const [],
  });

  factory PostMetrics.fromMap(Map<String, dynamic> map) {
    return PostMetrics(
      views: map['views'] ?? 0,
      likes: map['likes'] ?? 0,
      dislikes: map['dislikes'] ?? 0,
      comments: map['comments'] ?? 0,
      shares: map['shares'] ?? 0,
      bookmarks: map['bookmarks'] ?? 0,
      helpfulnessRating: (map['helpfulnessRating'] ?? 0.0).toDouble(),
      helpfulnessVotes: map['helpfulnessVotes'] ?? 0,
      lastViewed: map['lastViewed'],
      likedBy: List<String>.from(map['likedBy'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'views': views,
      'likes': likes,
      'dislikes': dislikes,
      'comments': comments,
      'shares': shares,
      'bookmarks': bookmarks,
      'helpfulnessRating': helpfulnessRating,
      'helpfulnessVotes': helpfulnessVotes,
      'lastViewed': lastViewed,
      'likedBy': likedBy,
    };
  }

  PostMetrics copyWith({
    int? views,
    int? likes,
    int? dislikes,
    int? comments,
    int? shares,
    int? bookmarks,
    double? helpfulnessRating,
    int? helpfulnessVotes,
    Timestamp? lastViewed,
    List<String>? likedBy,
  }) {
    return PostMetrics(
      views: views ?? this.views,
      likes: likes ?? this.likes,
      dislikes: dislikes ?? this.dislikes,
      comments: comments ?? this.comments,
      shares: shares ?? this.shares,
      bookmarks: bookmarks ?? this.bookmarks,
      helpfulnessRating: helpfulnessRating ?? this.helpfulnessRating,
      helpfulnessVotes: helpfulnessVotes ?? this.helpfulnessVotes,
      lastViewed: lastViewed ?? this.lastViewed,
      likedBy: likedBy ?? this.likedBy,
    );
  }
}

class PostElectricalData {
  final String? voltageLevel;
  final String? equipmentType;
  final String? substationType;
  final String? substationId;
  final String? bayId;
  final List<String> applicableEquipment;
  final String? procedureType;
  final String? safetyLevel;

  PostElectricalData({
    this.voltageLevel,
    this.equipmentType,
    this.substationType,
    this.substationId,
    this.bayId,
    this.applicableEquipment = const [],
    this.procedureType,
    this.safetyLevel,
  });

  factory PostElectricalData.fromMap(Map<String, dynamic> map) {
    return PostElectricalData(
      voltageLevel: map['voltageLevel'],
      equipmentType: map['equipmentType'],
      substationType: map['substationType'],
      substationId: map['substationId'],
      bayId: map['bayId'],
      applicableEquipment: List<String>.from(map['applicableEquipment'] ?? []),
      procedureType: map['procedureType'],
      safetyLevel: map['safetyLevel'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'voltageLevel': voltageLevel,
      'equipmentType': equipmentType,
      'substationType': substationType,
      'substationId': substationId,
      'bayId': bayId,
      'applicableEquipment': applicableEquipment,
      'procedureType': procedureType,
      'safetyLevel': safetyLevel,
    };
  }

  PostElectricalData copyWith({
    String? voltageLevel,
    String? equipmentType,
    String? substationType,
    String? substationId,
    String? bayId,
    List<String>? applicableEquipment,
    String? procedureType,
    String? safetyLevel,
  }) {
    return PostElectricalData(
      voltageLevel: voltageLevel ?? this.voltageLevel,
      equipmentType: equipmentType ?? this.equipmentType,
      substationType: substationType ?? this.substationType,
      substationId: substationId ?? this.substationId,
      bayId: bayId ?? this.bayId,
      applicableEquipment: applicableEquipment ?? this.applicableEquipment,
      procedureType: procedureType ?? this.procedureType,
      safetyLevel: safetyLevel ?? this.safetyLevel,
    );
  }
}

class PostComment {
  final String? id;
  final String postId;
  final String authorId;
  final String authorName;
  final String authorDesignation;
  final String content;
  final Timestamp createdAt;
  final Timestamp? updatedAt;
  final String? parentCommentId;
  final List<String> mentions;
  final int likes;
  final bool isEdited;
  final bool isHelpful;

  PostComment({
    this.id,
    required this.postId,
    required this.authorId,
    required this.authorName,
    required this.content,
    required this.createdAt,
    this.updatedAt,
    this.parentCommentId,
    this.mentions = const [],
    this.likes = 0,
    this.isEdited = false,
    this.isHelpful = false,
    String? authorDesignation,
  }) : authorDesignation = authorDesignation ?? '';

  String get userName => authorName;
  String get userDesignation => authorDesignation;
  String get userId => authorId;

  factory PostComment.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return PostComment(
      id: doc.id,
      postId: data['postId'] ?? '',
      authorId: data['authorId'] ?? data['userId'] ?? '',
      authorName: data['authorName'] ?? data['userName'] ?? '',
      authorDesignation:
          data['authorDesignation'] ?? data['userDesignation'] ?? '',
      content: data['content'] ?? '',
      createdAt: data['createdAt'] ?? Timestamp.now(),
      updatedAt: data['updatedAt'],
      parentCommentId: data['parentCommentId'],
      mentions: List<String>.from(data['mentions'] ?? []),
      likes: data['likes'] ?? 0,
      isEdited: data['isEdited'] ?? false,
      isHelpful: data['isHelpful'] ?? false,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'postId': postId,
      'authorId': authorId,
      'authorName': authorName,
      'authorDesignation': authorDesignation,
      'content': content,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'parentCommentId': parentCommentId,
      'mentions': mentions,
      'likes': likes,
      'isEdited': isEdited,
      'isHelpful': isHelpful,
    };
  }

  PostComment copyWith({
    String? id,
    String? postId,
    String? authorId,
    String? authorName,
    String? authorDesignation,
    String? content,
    Timestamp? createdAt,
    Timestamp? updatedAt,
    String? parentCommentId,
    List<String>? mentions,
    int? likes,
    bool? isEdited,
    bool? isHelpful,
  }) {
    return PostComment(
      id: id ?? this.id,
      postId: postId ?? this.postId,
      authorId: authorId ?? this.authorId,
      authorName: authorName ?? this.authorName,
      authorDesignation: authorDesignation ?? this.authorDesignation,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      parentCommentId: parentCommentId ?? this.parentCommentId,
      mentions: mentions ?? this.mentions,
      likes: likes ?? this.likes,
      isEdited: isEdited ?? this.isEdited,
      isHelpful: isHelpful ?? this.isHelpful,
    );
  }
}

// ==================== PROFESSIONAL DIRECTORY MODELS ====================

class ProfessionalContact {
  final String? id;
  final String name;
  final String designation;
  final String department;
  final ContactType contactType;
  final List<String> specializations;
  final String? companyName;
  final String phoneNumber;
  final String? alternatePhone;
  final String email;
  final String? alternateEmail;
  final ContactAddress? address;
  final ContactMetrics metrics;
  final List<String> certifications;
  final List<String> serviceAreas;
  final ContactAvailability availability;
  final bool isVerified;
  final String? verifiedBy;
  final String? verifiedByName;
  final Timestamp? verifiedAt;
  final Timestamp createdAt;
  final Timestamp? updatedAt;
  final String addedBy;
  final ContactElectricalExpertise? electricalExpertise;
  final ContactStatus status;
  final String? notes;

  ProfessionalContact({
    this.id,
    required this.name,
    required this.designation,
    required this.department,
    required this.contactType,
    this.specializations = const [],
    this.companyName,
    required this.phoneNumber,
    this.alternatePhone,
    required this.email,
    this.alternateEmail,
    this.address,
    required this.metrics,
    this.certifications = const [],
    this.serviceAreas = const [],
    required this.availability,
    this.isVerified = false,
    this.verifiedBy,
    this.verifiedByName,
    this.verifiedAt,
    required this.createdAt,
    this.updatedAt,
    required this.addedBy,
    this.electricalExpertise,
    this.status = ContactStatus.active,
    this.notes,
  });

  factory ProfessionalContact.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ProfessionalContact(
      id: doc.id,
      name: data['name'] ?? '',
      designation: data['designation'] ?? '',
      department: data['department'] ?? '',
      contactType: ContactType.values.firstWhere(
        (e) => e.toString().split('.').last == (data['contactType'] ?? 'other'),
        orElse: () => ContactType.other,
      ),
      specializations: List<String>.from(data['specializations'] ?? []),
      companyName: data['companyName'],
      phoneNumber: data['phoneNumber'] ?? '',
      alternatePhone: data['alternatePhone'],
      email: data['email'] ?? '',
      alternateEmail: data['alternateEmail'],
      address: data['address'] != null
          ? ContactAddress.fromMap(data['address'])
          : null,
      metrics: ContactMetrics.fromMap(data['metrics'] ?? {}),
      certifications: List<String>.from(data['certifications'] ?? []),
      serviceAreas: List<String>.from(data['serviceAreas'] ?? []),
      availability: ContactAvailability.fromMap(data['availability'] ?? {}),
      isVerified: data['isVerified'] ?? false,
      verifiedBy: data['verifiedBy'],
      verifiedByName: data['verifiedByName'],
      verifiedAt: data['verifiedAt'],
      createdAt: data['createdAt'] ?? Timestamp.now(),
      updatedAt: data['updatedAt'],
      addedBy: data['addedBy'] ?? '',
      electricalExpertise: data['electricalExpertise'] != null
          ? ContactElectricalExpertise.fromMap(data['electricalExpertise'])
          : null,
      status: ContactStatus.values.firstWhere(
        (e) => e.toString().split('.').last == (data['status'] ?? 'active'),
        orElse: () => ContactStatus.active,
      ),
      notes: data['notes'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'designation': designation,
      'department': department,
      'contactType': contactType.toString().split('.').last,
      'specializations': specializations,
      'companyName': companyName,
      'phoneNumber': phoneNumber,
      'alternatePhone': alternatePhone,
      'email': email,
      'alternateEmail': alternateEmail,
      'address': address?.toMap(),
      'metrics': metrics.toMap(),
      'certifications': certifications,
      'serviceAreas': serviceAreas,
      'availability': availability.toMap(),
      'isVerified': isVerified,
      'verifiedBy': verifiedBy,
      'verifiedByName': verifiedByName,
      'verifiedAt': verifiedAt,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'addedBy': addedBy,
      'electricalExpertise': electricalExpertise?.toMap(),
      'status': status.toString().split('.').last,
      'notes': notes,
    };
  }

  ProfessionalContact copyWith({
    String? id,
    String? name,
    String? designation,
    String? department,
    ContactType? contactType,
    List<String>? specializations,
    String? companyName,
    String? phoneNumber,
    String? alternatePhone,
    String? email,
    String? alternateEmail,
    ContactAddress? address,
    ContactMetrics? metrics,
    List<String>? certifications,
    List<String>? serviceAreas,
    ContactAvailability? availability,
    bool? isVerified,
    String? verifiedBy,
    String? verifiedByName,
    Timestamp? verifiedAt,
    Timestamp? createdAt,
    Timestamp? updatedAt,
    String? addedBy,
    ContactElectricalExpertise? electricalExpertise,
    ContactStatus? status,
    String? notes,
  }) {
    return ProfessionalContact(
      id: id ?? this.id,
      name: name ?? this.name,
      designation: designation ?? this.designation,
      department: department ?? this.department,
      contactType: contactType ?? this.contactType,
      specializations: specializations ?? this.specializations,
      companyName: companyName ?? this.companyName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      alternatePhone: alternatePhone ?? this.alternatePhone,
      email: email ?? this.email,
      alternateEmail: alternateEmail ?? this.alternateEmail,
      address: address ?? this.address,
      metrics: metrics ?? this.metrics,
      certifications: certifications ?? this.certifications,
      serviceAreas: serviceAreas ?? this.serviceAreas,
      availability: availability ?? this.availability,
      isVerified: isVerified ?? this.isVerified,
      verifiedBy: verifiedBy ?? this.verifiedBy,
      verifiedByName: verifiedByName ?? this.verifiedByName,
      verifiedAt: verifiedAt ?? this.verifiedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      addedBy: addedBy ?? this.addedBy,
      electricalExpertise: electricalExpertise ?? this.electricalExpertise,
      status: status ?? this.status,
      notes: notes ?? this.notes,
    );
  }
}

class ContactAddress {
  final String street;
  final String city;
  final String state;
  final String pincode;
  final String? landmark;
  final double? latitude;
  final double? longitude;

  ContactAddress({
    required this.street,
    required this.city,
    required this.state,
    required this.pincode,
    this.landmark,
    this.latitude,
    this.longitude,
  });

  factory ContactAddress.fromMap(Map<String, dynamic> map) {
    return ContactAddress(
      street: map['street'] ?? '',
      city: map['city'] ?? '',
      state: map['state'] ?? '',
      pincode: map['pincode'] ?? '',
      landmark: map['landmark'],
      latitude: map['latitude']?.toDouble(),
      longitude: map['longitude']?.toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'street': street,
      'city': city,
      'state': state,
      'pincode': pincode,
      'landmark': landmark,
      'latitude': latitude,
      'longitude': longitude,
    };
  }

  ContactAddress copyWith({
    String? street,
    String? city,
    String? state,
    String? pincode,
    String? landmark,
    double? latitude,
    double? longitude,
  }) {
    return ContactAddress(
      street: street ?? this.street,
      city: city ?? this.city,
      state: state ?? this.state,
      pincode: pincode ?? this.pincode,
      landmark: landmark ?? this.landmark,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
    );
  }
}

class ContactMetrics {
  final double rating;
  final int totalReviews;
  final int totalHires;
  final int responseTime;
  final double completionRate;
  final Timestamp? lastContacted;
  final int timesViewed;

  ContactMetrics({
    this.rating = 0.0,
    this.totalReviews = 0,
    this.totalHires = 0,
    this.responseTime = 0,
    this.completionRate = 0.0,
    this.lastContacted,
    this.timesViewed = 0,
  });

  factory ContactMetrics.fromMap(Map<String, dynamic> map) {
    return ContactMetrics(
      rating: (map['rating'] ?? 0.0).toDouble(),
      totalReviews: map['totalReviews'] ?? 0,
      totalHires: map['totalHires'] ?? 0,
      responseTime: map['responseTime'] ?? 0,
      completionRate: (map['completionRate'] ?? 0.0).toDouble(),
      lastContacted: map['lastContacted'],
      timesViewed: map['timesViewed'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'rating': rating,
      'totalReviews': totalReviews,
      'totalHires': totalHires,
      'responseTime': responseTime,
      'completionRate': completionRate,
      'lastContacted': lastContacted,
      'timesViewed': timesViewed,
    };
  }

  ContactMetrics copyWith({
    double? rating,
    int? totalReviews,
    int? totalHires,
    int? responseTime,
    double? completionRate,
    Timestamp? lastContacted,
    int? timesViewed,
  }) {
    return ContactMetrics(
      rating: rating ?? this.rating,
      totalReviews: totalReviews ?? this.totalReviews,
      totalHires: totalHires ?? this.totalHires,
      responseTime: responseTime ?? this.responseTime,
      completionRate: completionRate ?? this.completionRate,
      lastContacted: lastContacted ?? this.lastContacted,
      timesViewed: timesViewed ?? this.timesViewed,
    );
  }
}

class ContactAvailability {
  final bool isAvailable;
  final List<String> workingDays;
  final String workingHours;
  final bool emergencyAvailable;
  final String? emergencyHours;
  final List<String> holidays;

  ContactAvailability({
    this.isAvailable = true,
    this.workingDays = const [],
    this.workingHours = '',
    this.emergencyAvailable = false,
    this.emergencyHours,
    this.holidays = const [],
  });

  factory ContactAvailability.fromMap(Map<String, dynamic> map) {
    return ContactAvailability(
      isAvailable: map['isAvailable'] ?? true,
      workingDays: List<String>.from(map['workingDays'] ?? []),
      workingHours: map['workingHours'] ?? '',
      emergencyAvailable: map['emergencyAvailable'] ?? false,
      emergencyHours: map['emergencyHours'],
      holidays: List<String>.from(map['holidays'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'isAvailable': isAvailable,
      'workingDays': workingDays,
      'workingHours': workingHours,
      'emergencyAvailable': emergencyAvailable,
      'emergencyHours': emergencyHours,
      'holidays': holidays,
    };
  }

  ContactAvailability copyWith({
    bool? isAvailable,
    List<String>? workingDays,
    String? workingHours,
    bool? emergencyAvailable,
    String? emergencyHours,
    List<String>? holidays,
  }) {
    return ContactAvailability(
      isAvailable: isAvailable ?? this.isAvailable,
      workingDays: workingDays ?? this.workingDays,
      workingHours: workingHours ?? this.workingHours,
      emergencyAvailable: emergencyAvailable ?? this.emergencyAvailable,
      emergencyHours: emergencyHours ?? this.emergencyHours,
      holidays: holidays ?? this.holidays,
    );
  }
}

class ContactElectricalExpertise {
  final List<String> voltageExpertise;
  final List<String> equipmentExpertise;
  final List<String> serviceTypes;
  final int experienceYears;
  final List<String> majorProjects;
  final bool hasGovernmentClearance;
  final String? clearanceLevel;

  ContactElectricalExpertise({
    this.voltageExpertise = const [],
    this.equipmentExpertise = const [],
    this.serviceTypes = const [],
    this.experienceYears = 0,
    this.majorProjects = const [],
    this.hasGovernmentClearance = false,
    this.clearanceLevel,
  });

  factory ContactElectricalExpertise.fromMap(Map<String, dynamic> map) {
    return ContactElectricalExpertise(
      voltageExpertise: List<String>.from(map['voltageExpertise'] ?? []),
      equipmentExpertise: List<String>.from(map['equipmentExpertise'] ?? []),
      serviceTypes: List<String>.from(map['serviceTypes'] ?? []),
      experienceYears: map['experienceYears'] ?? 0,
      majorProjects: List<String>.from(map['majorProjects'] ?? []),
      hasGovernmentClearance: map['hasGovernmentClearance'] ?? false,
      clearanceLevel: map['clearanceLevel'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'voltageExpertise': voltageExpertise,
      'equipmentExpertise': equipmentExpertise,
      'serviceTypes': serviceTypes,
      'experienceYears': experienceYears,
      'majorProjects': majorProjects,
      'hasGovernmentClearance': hasGovernmentClearance,
      'clearanceLevel': clearanceLevel,
    };
  }

  ContactElectricalExpertise copyWith({
    List<String>? voltageExpertise,
    List<String>? equipmentExpertise,
    List<String>? serviceTypes,
    int? experienceYears,
    List<String>? majorProjects,
    bool? hasGovernmentClearance,
    String? clearanceLevel,
  }) {
    return ContactElectricalExpertise(
      voltageExpertise: voltageExpertise ?? this.voltageExpertise,
      equipmentExpertise: equipmentExpertise ?? this.equipmentExpertise,
      serviceTypes: serviceTypes ?? this.serviceTypes,
      experienceYears: experienceYears ?? this.experienceYears,
      majorProjects: majorProjects ?? this.majorProjects,
      hasGovernmentClearance:
          hasGovernmentClearance ?? this.hasGovernmentClearance,
      clearanceLevel: clearanceLevel ?? this.clearanceLevel,
    );
  }
}

class ContactReview {
  final String? id;
  final String contactId;
  final String reviewerId;
  final String reviewerName;
  final double rating;
  final String? review;
  final String projectType;
  final Timestamp createdAt;
  final bool isVerified;
  final List<String> tags;

  ContactReview({
    this.id,
    required this.contactId,
    required this.reviewerId,
    required this.reviewerName,
    required this.rating,
    this.review,
    required this.projectType,
    required this.createdAt,
    this.isVerified = false,
    this.tags = const [],
  });

  factory ContactReview.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ContactReview(
      id: doc.id,
      contactId: data['contactId'] ?? '',
      reviewerId: data['reviewerId'] ?? '',
      reviewerName: data['reviewerName'] ?? '',
      rating: (data['rating'] ?? 0.0).toDouble(),
      review: data['review'],
      projectType: data['projectType'] ?? '',
      createdAt: data['createdAt'] ?? Timestamp.now(),
      isVerified: data['isVerified'] ?? false,
      tags: List<String>.from(data['tags'] ?? []),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'contactId': contactId,
      'reviewerId': reviewerId,
      'reviewerName': reviewerName,
      'rating': rating,
      'review': review,
      'projectType': projectType,
      'createdAt': createdAt,
      'isVerified': isVerified,
      'tags': tags,
    };
  }

  ContactReview copyWith({
    String? id,
    String? contactId,
    String? reviewerId,
    String? reviewerName,
    double? rating,
    String? review,
    String? projectType,
    Timestamp? createdAt,
    bool? isVerified,
    List<String>? tags,
  }) {
    return ContactReview(
      id: id ?? this.id,
      contactId: contactId ?? this.contactId,
      reviewerId: reviewerId ?? this.reviewerId,
      reviewerName: reviewerName ?? this.reviewerName,
      rating: rating ?? this.rating,
      review: review ?? this.review,
      projectType: projectType ?? this.projectType,
      createdAt: createdAt ?? this.createdAt,
      isVerified: isVerified ?? this.isVerified,
      tags: tags ?? this.tags,
    );
  }
}

// ==================== ENUMS ====================

enum PostStatus { draft, pending, approved, rejected, archived }

enum PostVisibility { public, department, circle, zone, private }

enum ContactType {
  vendor,
  engineer,
  technician,
  contractor,
  supplier,
  consultant,
  emergencyService,
  other,
}

enum ContactStatus { active, inactive, blacklisted, pending, suspended }

// ==================== ADDITIONAL UTILITY MODELS ====================

class CommunitySearchFilter {
  final String? keyword;
  final List<String> categories;
  final List<String> tags;
  final List<String> voltagelevels;
  final List<String> equipmentTypes;
  final PostStatus? status;
  final ContactType? contactType;
  final bool? isVerified;
  final DateRange? dateRange;
  final SortType sortBy;
  final int limit;
  final String? zoneId;
  final String? circleId;
  final String? divisionId;
  final String? subdivisionId;

  CommunitySearchFilter({
    this.keyword,
    this.categories = const [],
    this.tags = const [],
    this.voltagelevels = const [],
    this.equipmentTypes = const [],
    this.status,
    this.contactType,
    this.isVerified,
    this.dateRange,
    this.sortBy = SortType.latest,
    this.limit = 20,
    this.zoneId,
    this.circleId,
    this.divisionId,
    this.subdivisionId,
  });
}

class DateRange {
  final DateTime startDate;
  final DateTime endDate;

  DateRange({required this.startDate, required this.endDate});
}

enum SortType {
  latest,
  oldest,
  mostLiked,
  mostViewed,
  trending,
  alphabetical,
  rating,
}
