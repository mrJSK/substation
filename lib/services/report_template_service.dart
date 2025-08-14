// lib/services/report_template_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/report_template_models.dart';
import '../models/user_model.dart';

class ReportTemplateService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<String> createTemplate(ReportTemplate template) async {
    try {
      final docRef = await _firestore
          .collection('reportTemplates')
          .add(template.toMap());
      return docRef.id;
    } catch (e) {
      throw Exception('Failed to create template: $e');
    }
  }

  Future<void> updateTemplate(ReportTemplate template) async {
    try {
      await _firestore
          .collection('reportTemplates')
          .doc(template.id)
          .update(template.toMap());
    } catch (e) {
      throw Exception('Failed to update template: $e');
    }
  }

  Future<void> deleteTemplate(String templateId) async {
    try {
      await _firestore.collection('reportTemplates').doc(templateId).delete();
    } catch (e) {
      throw Exception('Failed to delete template: $e');
    }
  }

  Future<ReportTemplate> getTemplate(String templateId) async {
    try {
      final doc = await _firestore
          .collection('reportTemplates')
          .doc(templateId)
          .get();

      if (!doc.exists) {
        throw Exception('Template not found');
      }

      return ReportTemplate.fromFirestore(doc);
    } catch (e) {
      throw Exception('Failed to get template: $e');
    }
  }

  Future<List<ReportTemplate>> getUserTemplates(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('reportTemplates')
          .where('createdBy', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => ReportTemplate.fromFirestore(doc))
          .toList();
    } catch (e) {
      throw Exception('Failed to get user templates: $e');
    }
  }

  Future<List<ReportTemplate>> getSharedTemplates(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('reportTemplates')
          .where('sharedWith', arrayContains: userId)
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => ReportTemplate.fromFirestore(doc))
          .toList();
    } catch (e) {
      throw Exception('Failed to get shared templates: $e');
    }
  }

  Future<List<ReportTemplate>> getPublicTemplates() async {
    try {
      final snapshot = await _firestore
          .collection('reportTemplates')
          .where('isPublic', isEqualTo: true)
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => ReportTemplate.fromFirestore(doc))
          .toList();
    } catch (e) {
      throw Exception('Failed to get public templates: $e');
    }
  }

  Future<void> shareTemplate(String templateId, List<String> userIds) async {
    try {
      await _firestore.collection('reportTemplates').doc(templateId).update({
        'sharedWith': FieldValue.arrayUnion(userIds),
      });
    } catch (e) {
      throw Exception('Failed to share template: $e');
    }
  }

  Future<void> unshareTemplate(String templateId, List<String> userIds) async {
    try {
      await _firestore.collection('reportTemplates').doc(templateId).update({
        'sharedWith': FieldValue.arrayRemove(userIds),
      });
    } catch (e) {
      throw Exception('Failed to unshare template: $e');
    }
  }

  Future<ReportTemplate> duplicateTemplate(
    String templateId,
    String newName,
    String userId,
  ) async {
    try {
      final originalTemplate = await getTemplate(templateId);

      final duplicatedTemplate = originalTemplate.copyWith(
        id: '',
        name: newName,
        createdAt: DateTime.now(),
        createdBy: userId,
        isPublic: false,
        sharedWith: [],
      );

      final newTemplateId = await createTemplate(duplicatedTemplate);
      return duplicatedTemplate.copyWith(id: newTemplateId);
    } catch (e) {
      throw Exception('Failed to duplicate template: $e');
    }
  }

  Stream<List<ReportTemplate>> watchUserTemplates(String userId) {
    return _firestore
        .collection('reportTemplates')
        .where('createdBy', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => ReportTemplate.fromFirestore(doc))
              .toList(),
        );
  }
}
