import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';
import 'dart:math';

import '../../../core/models/certificate_model.dart';
import '../../../core/models/document_model.dart';
import '../../../core/services/logger_service.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/services/system_interaction_service.dart';
import '../providers/ca_providers.dart';
import '../presentation/pages/ca_dashboard.dart';

// Use the main CertificateTemplate from core models
export '../../../core/models/certificate_model.dart' show CertificateTemplate;

class CAService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final NotificationService _notificationService = NotificationService();
  final SystemInteractionService _interactionService =
      SystemInteractionService();
  final _uuid = const Uuid();

  String? get _currentUserId => _auth.currentUser?.uid;

  Future<CAStats> getCAStats() async {
    try {
      if (_currentUserId == null) {
        throw Exception('User not authenticated');
      }

      final certificatesQuery = await _firestore
          .collection('certificates')
          .where('issuerId', isEqualTo: _currentUserId)
          .get();

      final pendingDocsQuery = await _firestore
          .collection('documents')
          .where('status', isEqualTo: 'pending')
          .get();

      final totalDocsQuery = await _firestore.collection('documents').get();

      final usersQuery = await _firestore
          .collection('users')
          .where('status', isEqualTo: 'active')
          .get();

      return CAStats(
        totalCertificatesIssued: certificatesQuery.docs.length,
        pendingDocuments: pendingDocsQuery.docs.length,
        totalDocuments: totalDocsQuery.docs.length,
        activeUsers: usersQuery.docs.length,
      );
    } catch (error, stackTrace) {
      LoggerService.error('Failed to get CA stats',
          error: error, stackTrace: stackTrace);
      rethrow;
    }
  }

  Future<String> createCertificate({
    required String title,
    required String recipientName,
    required String recipientEmail,
    required String description,
    required CertificateType type,
    required DateTime issuedAt,
    String? templateId,
    Map<String, dynamic> customFields = const {},
  }) async {
    try {
      if (_currentUserId == null) {
        throw Exception('User not authenticated');
      }

      LoggerService.info('CA creating certificate: $title for $recipientEmail');

      // Validate inputs
      if (title.trim().isEmpty ||
          recipientName.trim().isEmpty ||
          recipientEmail.trim().isEmpty) {
        throw Exception('Required fields cannot be empty');
      }

      // Get current user data to verify CA permissions
      final currentUserDoc =
          await _firestore.collection('users').doc(_currentUserId).get();
      if (!currentUserDoc.exists) {
        throw Exception('User data not found');
      }

      final userData = currentUserDoc.data()!;
      final userType = userData['userType'] as String?;
      final userStatus = userData['status'] as String?;

      // Verify user has CA permissions
      if (userType != 'ca' && userType != 'admin') {
        throw Exception('User does not have CA permissions');
      }
      if (userStatus != 'active') {
        throw Exception('User account is not active');
      }

      final certificateId = _uuid.v4();
      final verificationCode = _generateVerificationCode();
      final verificationId = _uuid.v4();

      // Get default template if none specified
      final actualTemplateId = templateId ?? await _getDefaultTemplateId();

      // Get organization info
      final organizationName =
          userData['organizationName'] ?? 'Certificate Authority';
      final issuerName = userData['displayName'] ??
          _auth.currentUser?.displayName ??
          'Unknown CA';

      final certificate = CertificateModel(
        id: certificateId,
        templateId: actualTemplateId,
        issuerId: _currentUserId!,
        issuerName: issuerName,
        recipientId: await _getOrCreateRecipientId(recipientEmail),
        recipientName: recipientName,
        recipientEmail: recipientEmail,
        organizationId: _currentUserId!,
        organizationName: organizationName,
        verificationCode: verificationCode,
        title: title,
        description: description,
        type: type,
        issuedAt: issuedAt,
        expiresAt: _calculateExpiryDate(type, issuedAt),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        status: CertificateStatus.issued,
        verificationId: verificationId,
        qrCode: _generateQRCode(verificationCode),
        hash: _generateCertificateHash(certificateId, verificationCode),
        metadata: {
          'version': '1.0',
          'issuerSignature': await _generateDigitalSignature(certificateId),
          'templateId': actualTemplateId,
          'customFields': customFields,
          'issuerType': userType,
          'verificationUrl':
              'https://upm-digital-certificates.web.app/verify?id=$certificateId&code=$verificationCode',
        },
        // Initialize counters
        shareCount: 0,
        verificationCount: 0,
        accessCount: 0,
        shareTokens: [],
      );

      // Use transaction to ensure data consistency
      await _firestore.runTransaction((transaction) async {
        // Set certificate
        transaction.set(
          _firestore.collection('certificates').doc(certificateId),
          certificate.toFirestore(),
        );
      });

      // ✅ 使用系统交互服务处理证书发放通知
      await _interactionService.handleCertificateIssued(
        certificateId: certificateId,
        certificateTitle: title,
        caId: _currentUserId!,
        caName: issuerName,
        recipientEmail: recipientEmail,
        recipientId: certificate.recipientId,
        certificateData: certificate.toFirestore(),
      );

      await _logCAActivity(
        action: 'certificate_created',
        description: 'Created certificate: $title for $recipientName',
        metadata: {
          'certificateId': certificateId,
          'recipientEmail': recipientEmail,
          'type': type.name,
          'status': 'issued',
        },
      );

      // Send email notification (non-blocking)
      _sendCertificateNotification(certificate).catchError((e) {
        LoggerService.error('Failed to send certificate notification',
            error: e);
      });

      LoggerService.info(
          'Certificate created successfully by CA: $certificateId');
      return certificateId;
    } catch (error, stackTrace) {
      LoggerService.error('Failed to create certificate',
          error: error, stackTrace: stackTrace);
      rethrow;
    }
  }

  Future<void> saveCertificateDraft({
    required String title,
    required String recipientName,
    required String recipientEmail,
    required String description,
    required CertificateType type,
    String? templateId,
    Map<String, dynamic> customFields = const {},
  }) async {
    try {
      if (_currentUserId == null) {
        throw Exception('User not authenticated');
      }

      final draftId = _uuid.v4();

      await _firestore.collection('certificate_drafts').doc(draftId).set({
        'id': draftId,
        'title': title,
        'recipientName': recipientName,
        'recipientEmail': recipientEmail,
        'description': description,
        'type': type.name,
        'issuerId': _currentUserId,
        'templateId': templateId ?? await _getDefaultTemplateId(),
        'customFields': customFields,
        'createdAt': Timestamp.fromDate(DateTime.now()),
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });

      await _logCAActivity(
        action: 'draft_saved',
        description: 'Saved certificate draft: $title',
        metadata: {
          'draftId': draftId,
          'recipientEmail': recipientEmail,
        },
      );

      LoggerService.info('Certificate draft saved successfully: $draftId');
    } catch (error, stackTrace) {
      LoggerService.error('Failed to save certificate draft',
          error: error, stackTrace: stackTrace);
      rethrow;
    }
  }

  Future<List<DocumentModel>> getPendingDocuments() async {
    try {
      if (_currentUserId == null) {
        throw Exception('User not authenticated');
      }

      final querySnapshot = await _firestore
          .collection('documents')
          .where('status', isEqualTo: DocumentStatus.pending.name)
          .orderBy('uploadedAt', descending: true)
          .limit(50)
          .get();

      return querySnapshot.docs
          .map((doc) => DocumentModel.fromFirestore(doc))
          .toList();
    } catch (error, stackTrace) {
      LoggerService.error('Failed to get pending documents',
          error: error, stackTrace: stackTrace);
      return [];
    }
  }

  Future<void> approveDocument(String documentId, String comments) async {
    try {
      if (_currentUserId == null) {
        throw Exception('User not authenticated');
      }

      await _firestore.collection('documents').doc(documentId).update({
        'status': DocumentStatus.verified.name,
        'reviewedBy': _currentUserId,
        'reviewedAt': Timestamp.fromDate(DateTime.now()),
        'reviewComments': comments,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });

      await _logCAActivity(
        action: 'document_approved',
        description: 'Approved document: $documentId',
        metadata: {
          'documentId': documentId,
          'comments': comments,
        },
      );

      LoggerService.info('Document approved: $documentId');
    } catch (error, stackTrace) {
      LoggerService.error('Failed to approve document',
          error: error, stackTrace: stackTrace);
      rethrow;
    }
  }

  Future<void> rejectDocument(String documentId, String reason) async {
    try {
      if (_currentUserId == null) {
        throw Exception('User not authenticated');
      }

      await _firestore.collection('documents').doc(documentId).update({
        'status': DocumentStatus.rejected.name,
        'reviewedBy': _currentUserId,
        'reviewedAt': Timestamp.fromDate(DateTime.now()),
        'rejectionReason': reason,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });

      await _logCAActivity(
        action: 'document_rejected',
        description: 'Rejected document: $documentId',
        metadata: {
          'documentId': documentId,
          'reason': reason,
        },
      );

      LoggerService.info('Document rejected: $documentId');
    } catch (error, stackTrace) {
      LoggerService.error('Failed to reject document',
          error: error, stackTrace: stackTrace);
      rethrow;
    }
  }

  Future<CASettingsModel> getCASettings() async {
    try {
      if (_currentUserId == null) {
        throw Exception('User not authenticated');
      }

      final doc =
          await _firestore.collection('ca_settings').doc(_currentUserId).get();

      if (doc.exists) {
        return CASettingsModel.fromFirestore(doc);
      } else {
        return const CASettingsModel(
          organizationName: 'Certificate Authority',
          contactEmail: '',
          contactPhone: '',
          address: '',
        );
      }
    } catch (error, stackTrace) {
      LoggerService.error('Failed to get CA settings',
          error: error, stackTrace: stackTrace);
      rethrow;
    }
  }

  Future<void> updateCASettings(CASettingsModel settings) async {
    try {
      if (_currentUserId == null) {
        throw Exception('User not authenticated');
      }

      await _firestore
          .collection('ca_settings')
          .doc(_currentUserId)
          .set(settings.toFirestore());

      await _logCAActivity(
        action: 'settings_updated',
        description: 'Updated CA settings',
        metadata: settings.toFirestore(),
      );

      LoggerService.info('CA settings updated successfully');
    } catch (error, stackTrace) {
      LoggerService.error('Failed to update CA settings',
          error: error, stackTrace: stackTrace);
      rethrow;
    }
  }

  Future<void> revokeCertificate(String certificateId, String reason) async {
    try {
      if (_currentUserId == null) {
        throw Exception('User not authenticated');
      }

      await _firestore.collection('certificates').doc(certificateId).update({
        'status': CertificateStatus.revoked.name,
        'revokedAt': Timestamp.fromDate(DateTime.now()),
        'revokedBy': _currentUserId,
        'revocationReason': reason,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });

      await _logCAActivity(
        action: 'certificate_revoked',
        description: 'Revoked certificate: $certificateId',
        metadata: {
          'certificateId': certificateId,
          'reason': reason,
        },
      );

      LoggerService.info('Certificate revoked successfully: $certificateId');
    } catch (error, stackTrace) {
      LoggerService.error('Failed to revoke certificate',
          error: error, stackTrace: stackTrace);
      rethrow;
    }
  }

  Future<List<CertificateTemplate>> getCertificateTemplates() async {
    try {
      final templatesQuery = await _firestore
          .collection('certificate_templates')
          .where('isActive', isEqualTo: true)
          .orderBy('name')
          .get();

      return templatesQuery.docs
          .map((doc) => CertificateTemplate.fromFirestore(doc))
          .toList();
    } catch (error, stackTrace) {
      LoggerService.error('Failed to get certificate templates',
          error: error, stackTrace: stackTrace);
      rethrow;
    }
  }

  Future<void> uploadCertificateTemplate({
    required String name,
    required String description,
    required String templateUrl,
    Map<String, dynamic> fields = const {},
  }) async {
    try {
      if (_currentUserId == null) {
        throw Exception('User not authenticated');
      }

      final templateId = _uuid.v4();

      await _firestore.collection('certificate_templates').doc(templateId).set({
        'id': templateId,
        'name': name,
        'description': description,
        'templateUrl': templateUrl,
        'fields': fields,
        'createdBy': _currentUserId,
        'createdAt': Timestamp.fromDate(DateTime.now()),
        'isActive': true,
      });

      await _logCAActivity(
        action: 'template_uploaded',
        description: 'Uploaded certificate template: $name',
        metadata: {
          'templateId': templateId,
          'templateName': name,
        },
      );

      LoggerService.info(
          'Certificate template uploaded successfully: $templateId');
    } catch (error, stackTrace) {
      LoggerService.error('Failed to upload certificate template',
          error: error, stackTrace: stackTrace);
      rethrow;
    }
  }

  String _generateVerificationCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random();
    return List.generate(8, (index) => chars[random.nextInt(chars.length)])
        .join();
  }

  String _generateQRCode(String verificationCode) {
    return 'QR_${verificationCode}_${DateTime.now().millisecondsSinceEpoch}';
  }

  String _generateCertificateHash(
      String certificateId, String verificationCode) {
    final content =
        '$certificateId-$verificationCode-${DateTime.now().millisecondsSinceEpoch}';
    return content.hashCode.abs().toString();
  }

  Future<String> _getOrCreateRecipientId(String email) async {
    try {
      // First check if user exists with this email
      final userQuery = await _firestore
          .collection('users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (userQuery.docs.isNotEmpty) {
        return userQuery.docs.first.id;
      } else {
        // Create a new user with basic recipient role
        final recipientId = _uuid.v4();
        final recipientName =
            email.split('@').first; // Use email prefix as display name

        await _firestore.collection('users').doc(recipientId).set({
          'id': recipientId,
          'uid': recipientId,
          'email': email,
          'displayName': recipientName,
          'photoURL': null,
          'role': 'recipient',
          'userType': 'user',
          'status': 'active',
          'canCreateCertificates': false,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'createdBy': _currentUserId,
          'metadata': {
            'createdByCertificate': true,
            'source': 'certificate_issuance',
          },
        });

        LoggerService.info('Created new recipient user for email: $email');
        return recipientId;
      }
    } catch (error) {
      LoggerService.error('Failed to get or create recipient ID', error: error);
      // Return a UUID as fallback
      return _uuid.v4();
    }
  }

  DateTime? _calculateExpiryDate(CertificateType type, DateTime issuedAt) {
    switch (type) {
      case CertificateType.academic:
        return null;
      case CertificateType.professional:
        return issuedAt.add(const Duration(days: 365 * 3));
      case CertificateType.completion:
        return null;
      case CertificateType.achievement:
        return null;
      case CertificateType.participation:
        return null;
      default:
        return issuedAt.add(const Duration(days: 365));
    }
  }

  Future<String> _generateDigitalSignature(String certificateId) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final issuer = _auth.currentUser?.uid ?? 'unknown';
    final content = '$certificateId-$issuer-$timestamp';

    return content.hashCode.abs().toString();
  }

  Future<void> _sendCertificateNotification(
      CertificateModel certificate) async {
    try {
      await _notificationService.sendCertificateIssuedNotification(
        recipientEmail: certificate.recipientEmail,
        certificateTitle: certificate.title,
        issuerName: certificate.issuerName,
        verificationCode: certificate.verificationCode,
      );
    } catch (error) {
      LoggerService.error('Failed to send certificate notification',
          error: error);
    }
  }

  /// Get default template ID or create one if none exists
  Future<String> _getDefaultTemplateId() async {
    try {
      // Check if there's a system default template
      final systemDefaultQuery = await _firestore
          .collection('certificate_templates')
          .where('isDefault', isEqualTo: true)
          .where('isActive', isEqualTo: true)
          .limit(1)
          .get();

      if (systemDefaultQuery.docs.isNotEmpty) {
        return systemDefaultQuery.docs.first.id;
      }

      // If no system default, get the first available template
      final anyTemplateQuery = await _firestore
          .collection('certificate_templates')
          .where('isActive', isEqualTo: true)
          .limit(1)
          .get();

      if (anyTemplateQuery.docs.isNotEmpty) {
        return anyTemplateQuery.docs.first.id;
      }

      // If no templates exist, create a basic default template
      final defaultTemplateId = await _createDefaultTemplate();
      return defaultTemplateId;
    } catch (error) {
      LoggerService.error('Failed to get default template ID', error: error);
      // Return a fallback template ID
      return 'fallback_template';
    }
  }

  /// Create a basic default template if none exists
  Future<String> _createDefaultTemplate() async {
    try {
      final templateId = 'default_${_uuid.v4()}';

      await _firestore.collection('certificate_templates').doc(templateId).set({
        'id': templateId,
        'name': 'Default Certificate Template',
        'description': 'Basic certificate template for general use',
        'templateUrl': 'assets/templates/default_certificate_template.png',
        'fields': {
          'title': 'Certificate Title',
          'recipientName': 'Recipient Name',
          'description': 'Certificate Description',
          'issuedDate': 'Issue Date',
          'issuerName': 'Issuer Name',
        },
        'isDefault': true,
        'isActive': true,
        'createdBy': 'system',
        'createdAt': FieldValue.serverTimestamp(),
      });

      LoggerService.info('Created default certificate template: $templateId');
      return templateId;
    } catch (error) {
      LoggerService.error('Failed to create default template', error: error);
      return 'fallback_template';
    }
  }

  Future<void> _logCAActivity({
    required String action,
    required String description,
    Map<String, dynamic> metadata = const {},
  }) async {
    try {
      if (_currentUserId == null) return;

      final activity = CAActivity(
        id: _uuid.v4(),
        caId: _currentUserId!,
        action: action,
        description: description,
        timestamp: DateTime.now(),
        metadata: metadata,
      );

      await _firestore
          .collection('ca_activities')
          .doc(activity.id)
          .set(activity.toFirestore());
    } catch (error) {
      LoggerService.error('Failed to log CA activity', error: error);
    }
  }
}

// CertificateTemplate class definition removed - using the one from core/models/certificate_model.dart
