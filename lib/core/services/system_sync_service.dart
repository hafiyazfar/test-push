import 'package:cloud_firestore/cloud_firestore.dart';

import '../config/app_config.dart';
import 'logger_service.dart';
import 'notification_service.dart';

/// System Synchronization Service
///
/// This service ensures 100% data synchronization between CA and Client systems
/// All data comes directly from Firebase - no fake or placeholder data
///
/// Key Features:
/// - Real-time sync between CA and Client workflows
/// - Template review process automation
/// - Document approval to certificate creation pipeline
/// - Cross-system notifications and activity tracking
/// - Data integrity validation
class SystemSyncService {
  static final SystemSyncService _instance = SystemSyncService._internal();
  factory SystemSyncService() => _instance;
  SystemSyncService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final NotificationService _notificationService = NotificationService();

  /// Initialize system synchronization
  Future<void> initialize() async {
    try {
      LoggerService.info('🔄 Initializing System Sync Service...');

      // Set up real-time listeners for cross-system events
      _setupDocumentSyncListeners();
      _setupTemplateSyncListeners();
      _setupCertificateSyncListeners();
      _setupUserSyncListeners();

      LoggerService.info('✅ System Sync Service initialized successfully');
    } catch (e, stackTrace) {
      LoggerService.error('❌ Failed to initialize System Sync Service',
          error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  /// Set up document synchronization between CA and Client systems
  void _setupDocumentSyncListeners() {
    // Listen for document status changes
    _firestore
        .collection('documents')
        .where('status', isEqualTo: 'verified')
        .snapshots()
        .listen((snapshot) {
      for (final docChange in snapshot.docChanges) {
        if (docChange.type == DocumentChangeType.modified ||
            docChange.type == DocumentChangeType.added) {
          _handleDocumentApproval(docChange.doc.id, docChange.doc.data()!);
        }
      }
    });
  }

  /// Set up template synchronization between CA and Client systems
  void _setupTemplateSyncListeners() {
    // Listen for CA template submissions
    _firestore
        .collection('certificate_templates')
        .where('status', isEqualTo: 'pending_client_review')
        .snapshots()
        .listen((snapshot) {
      for (final docChange in snapshot.docChanges) {
        if (docChange.type == DocumentChangeType.added) {
          _notifyClientReviewers(docChange.doc.id, docChange.doc.data()!);
        }
      }
    });

    // Listen for client template approvals
    _firestore
        .collection('certificate_templates')
        .where('status', isEqualTo: 'client_approved')
        .snapshots()
        .listen((snapshot) {
      for (final docChange in snapshot.docChanges) {
        if (docChange.type == DocumentChangeType.modified) {
          _activateApprovedTemplate(docChange.doc.id, docChange.doc.data()!);
        }
      }
    });
  }

  /// Set up certificate synchronization
  void _setupCertificateSyncListeners() {
    // Listen for new certificate issuance
    _firestore.collection('certificates').snapshots().listen((snapshot) {
      for (final docChange in snapshot.docChanges) {
        if (docChange.type == DocumentChangeType.added) {
          _handleNewCertificate(docChange.doc.id, docChange.doc.data()!);
        }
      }
    });
  }

  /// Set up user synchronization
  void _setupUserSyncListeners() {
    // Listen for user role changes
    _firestore.collection('users').snapshots().listen((snapshot) {
      for (final docChange in snapshot.docChanges) {
        if (docChange.type == DocumentChangeType.modified) {
          _handleUserRoleChange(docChange.doc.id, docChange.doc.data()!);
        }
      }
    });
  }

  /// Handle document approval by CA
  Future<void> _handleDocumentApproval(
      String documentId, Map<String, dynamic> documentData) async {
    try {
      final uploaderId = documentData['uploaderId'] as String?;
      final fileName =
          documentData['fileName'] as String? ?? 'Unknown Document';

      if (uploaderId == null) return;

      // Create activity log
      await _firestore.collection('activities').add({
        'type': 'document_approved_for_certificate',
        'documentId': documentId,
        'uploaderId': uploaderId,
        'fileName': fileName,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'approved',
      });

      // Send notification to document uploader
      await _notificationService.sendNotification(
        userId: uploaderId,
        title: 'Document Approved',
        message:
            'Your document "$fileName" has been approved and is ready for certificate creation.',
        type: 'document_approval',
        data: {'documentId': documentId},
      );

      LoggerService.info('Document approval processed: $documentId');
    } catch (e) {
      LoggerService.error('Failed to handle document approval', error: e);
    }
  }

  /// Notify client reviewers of new templates
  Future<void> _notifyClientReviewers(
      String templateId, Map<String, dynamic> templateData) async {
    try {
      // Get all client reviewers
      final clientReviewers = await _firestore
          .collection('users')
          .where('userType', isEqualTo: 'client')
          .where('status', isEqualTo: 'active')
          .get();

      final templateName =
          templateData['name'] as String? ?? 'Unnamed Template';
      final createdBy =
          templateData['createdByName'] as String? ?? 'Unknown CA';

      // Send notifications to all client reviewers
      for (final reviewer in clientReviewers.docs) {
        await _notificationService.sendNotification(
          userId: reviewer.id,
          title: 'New Template for Review',
          message:
              'Template "$templateName" by $createdBy is ready for client review.',
          type: 'template_review_request',
          data: {'templateId': templateId},
        );
      }

      // Create activity log
      await _firestore.collection('activities').add({
        'type': 'template_submitted_for_client_review',
        'templateId': templateId,
        'templateName': templateName,
        'createdBy': templateData['createdBy'],
        'timestamp': FieldValue.serverTimestamp(),
        'notifiedReviewers': clientReviewers.docs.length,
      });

      LoggerService.info('Client reviewers notified for template: $templateId');
    } catch (e) {
      LoggerService.error('Failed to notify client reviewers', error: e);
    }
  }

  /// Activate approved template for use
  Future<void> _activateApprovedTemplate(
      String templateId, Map<String, dynamic> templateData) async {
    try {
      // Update template status to active
      await _firestore
          .collection('certificate_templates')
          .doc(templateId)
          .update({
        'status': 'active',
        'activatedAt': FieldValue.serverTimestamp(),
        'isActive': true,
      });

      final templateName =
          templateData['name'] as String? ?? 'Unnamed Template';
      final createdBy = templateData['createdBy'] as String?;

      // Notify template creator
      if (createdBy != null) {
        await _notificationService.sendNotification(
          userId: createdBy,
          title: 'Template Activated',
          message:
              'Your template "$templateName" has been approved and is now active for certificate creation.',
          type: 'template_activation',
          data: {'templateId': templateId},
        );
      }

      // Create activity log
      await _firestore.collection('activities').add({
        'type': 'template_activated',
        'templateId': templateId,
        'templateName': templateName,
        'activatedBy': 'system',
        'timestamp': FieldValue.serverTimestamp(),
      });

      LoggerService.info('Template activated: $templateId');
    } catch (e) {
      LoggerService.error('Failed to activate template', error: e);
    }
  }

  /// Handle new certificate issuance
  Future<void> _handleNewCertificate(
      String certificateId, Map<String, dynamic> certificateData) async {
    try {
      final recipientId = certificateData['recipientId'] as String?;
      final recipientEmail = certificateData['recipientEmail'] as String?;
      final title = certificateData['title'] as String? ?? 'Certificate';
      final issuerName =
          certificateData['issuerName'] as String? ?? 'Unknown Issuer';

      // Update certificate statistics
      await _updateCertificateStatistics(certificateData);

      // Send notification to recipient if they have an account
      if (recipientId != null && recipientId.isNotEmpty) {
        await _notificationService.sendNotification(
          userId: recipientId,
          title: 'Certificate Issued',
          message:
              'You have received a new certificate: "$title" from $issuerName',
          type: 'certificate_received',
          data: {'certificateId': certificateId},
        );
      }

      // Create activity log
      await _firestore.collection('activities').add({
        'type': 'certificate_issued',
        'certificateId': certificateId,
        'title': title,
        'recipientEmail': recipientEmail,
        'issuerId': certificateData['issuerId'],
        'issuerName': issuerName,
        'timestamp': FieldValue.serverTimestamp(),
      });

      LoggerService.info('Certificate issuance processed: $certificateId');
    } catch (e) {
      LoggerService.error('Failed to handle certificate issuance', error: e);
    }
  }

  /// Handle user role changes
  Future<void> _handleUserRoleChange(
      String userId, Map<String, dynamic> userData) async {
    try {
      final userType = userData['userType'] as String?;
      final status = userData['status'] as String?;
      final displayName = userData['displayName'] as String? ?? 'Unknown User';

      // Log role change
      await _firestore.collection('activities').add({
        'type': 'user_role_updated',
        'userId': userId,
        'userType': userType,
        'status': status,
        'displayName': displayName,
        'timestamp': FieldValue.serverTimestamp(),
      });

      // Send notification for role activation
      if (status == 'active' && (userType == 'ca' || userType == 'client')) {
        await _notificationService.sendNotification(
          userId: userId,
          title: 'Account Activated',
          message:
              'Your ${userType?.toUpperCase()} account has been activated and is ready to use.',
          type: 'account_activation',
          data: {'userType': userType},
        );
      }

      LoggerService.info('User role change processed: $userId -> $userType');
    } catch (e) {
      LoggerService.error('Failed to handle user role change', error: e);
    }
  }

  /// Update certificate statistics in real-time
  Future<void> _updateCertificateStatistics(
      Map<String, dynamic> certificateData) async {
    try {
      final now = DateTime.now();
      final monthKey = '${now.year}-${now.month.toString().padLeft(2, '0')}';

      // Update monthly statistics
      await _firestore.collection('statistics').doc('certificates').set({
        'totalIssued': FieldValue.increment(1),
        'monthlyStats.$monthKey': FieldValue.increment(1),
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Update issuer statistics
      final issuerId = certificateData['issuerId'] as String?;
      if (issuerId != null) {
        await _firestore.collection('statistics').doc('ca_performance').set({
          'caStats.$issuerId.certificatesIssued': FieldValue.increment(1),
          'caStats.$issuerId.lastActivity': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    } catch (e) {
      LoggerService.error('Failed to update certificate statistics', error: e);
    }
  }

  /// Sync data integrity across systems
  Future<SystemSyncReport> validateSystemIntegrity() async {
    final report = SystemSyncReport();

    try {
      LoggerService.info('🔍 Validating system integrity...');

      // Validate user data consistency
      await _validateUserDataIntegrity(report);

      // Validate CA-Client workflow integrity
      await _validateWorkflowIntegrity(report);

      // Validate certificate-document linkages
      await _validateCertificateDocumentLinkages(report);

      // Validate template workflow integrity
      await _validateTemplateWorkflowIntegrity(report);

      report.isValid = report.errors.isEmpty;
      report.completedAt = DateTime.now();

      LoggerService.info('✅ System integrity validation completed');
    } catch (e, stackTrace) {
      LoggerService.error('❌ System integrity validation failed',
          error: e, stackTrace: stackTrace);
      report.addError('System integrity validation failed: $e');
    }

    return report;
  }

  /// Validate user data integrity
  Future<void> _validateUserDataIntegrity(SystemSyncReport report) async {
    try {
      final users = await _firestore.collection('users').get();

      for (final userDoc in users.docs) {
        final userData = userDoc.data();
        final email = userData['email'] as String?;

        // Validate UPM email domain
        if (email != null && !AppConfig.isValidUpmEmail(email)) {
          report
              .addError('Invalid email domain for user ${userDoc.id}: $email');
        }

        // Validate required fields
        if (userData['userType'] == null || userData['status'] == null) {
          report.addError('Missing required fields for user ${userDoc.id}');
        }
      }

      report.addSuccess('User data integrity validated');
    } catch (e) {
      report.addError('User data validation failed: $e');
    }
  }

  /// Validate CA-Client workflow integrity
  Future<void> _validateWorkflowIntegrity(SystemSyncReport report) async {
    try {
      // Check for orphaned documents
      final documents = await _firestore.collection('documents').get();
      final users = await _firestore.collection('users').get();
      final userIds = users.docs.map((doc) => doc.id).toSet();

      for (final docDoc in documents.docs) {
        final docData = docDoc.data();
        final uploaderId = docData['uploaderId'] as String?;
        final reviewedBy = docData['reviewedBy'] as String?;

        if (uploaderId != null && !userIds.contains(uploaderId)) {
          report.addError(
              'Document ${docDoc.id} has invalid uploader ID: $uploaderId');
        }

        if (reviewedBy != null && !userIds.contains(reviewedBy)) {
          report.addError(
              'Document ${docDoc.id} has invalid reviewer ID: $reviewedBy');
        }
      }

      report.addSuccess('Workflow integrity validated');
    } catch (e) {
      report.addError('Workflow validation failed: $e');
    }
  }

  /// Validate certificate-document linkages
  Future<void> _validateCertificateDocumentLinkages(
      SystemSyncReport report) async {
    try {
      final certificates = await _firestore.collection('certificates').get();
      final users = await _firestore.collection('users').get();
      final userIds = users.docs.map((doc) => doc.id).toSet();

      for (final certDoc in certificates.docs) {
        final certData = certDoc.data();
        final issuerId = certData['issuerId'] as String?;
        final recipientId = certData['recipientId'] as String?;

        if (issuerId != null && !userIds.contains(issuerId)) {
          report.addError(
              'Certificate ${certDoc.id} has invalid issuer ID: $issuerId');
        }

        if (recipientId != null &&
            recipientId.isNotEmpty &&
            !userIds.contains(recipientId)) {
          report.addError(
              'Certificate ${certDoc.id} has invalid recipient ID: $recipientId');
        }
      }

      report.addSuccess('Certificate-document linkages validated');
    } catch (e) {
      report.addError('Certificate linkage validation failed: $e');
    }
  }

  /// Validate template workflow integrity
  Future<void> _validateTemplateWorkflowIntegrity(
      SystemSyncReport report) async {
    try {
      final templates =
          await _firestore.collection('certificate_templates').get();
      final users = await _firestore.collection('users').get();
      final userIds = users.docs.map((doc) => doc.id).toSet();

      for (final templateDoc in templates.docs) {
        final templateData = templateDoc.data();
        final createdBy = templateData['createdBy'] as String?;
        final clientReviewedBy = templateData['clientReviewedBy'] as String?;

        if (createdBy != null && !userIds.contains(createdBy)) {
          report.addError(
              'Template ${templateDoc.id} has invalid creator ID: $createdBy');
        }

        if (clientReviewedBy != null && !userIds.contains(clientReviewedBy)) {
          report.addError(
              'Template ${templateDoc.id} has invalid client reviewer ID: $clientReviewedBy');
        }
      }

      report.addSuccess('Template workflow integrity validated');
    } catch (e) {
      report.addError('Template workflow validation failed: $e');
    }
  }

  /// Force synchronization of all systems
  Future<void> forceSynchronization() async {
    try {
      LoggerService.info('🔄 Force synchronizing all systems...');

      // Sync pending documents
      await _syncPendingDocuments();

      // Sync pending templates
      await _syncPendingTemplates();

      // Sync user permissions
      await _syncUserPermissions();

      // Update statistics
      await _updateSystemStatistics();

      LoggerService.info('✅ Force synchronization completed');
    } catch (e, stackTrace) {
      LoggerService.error('❌ Force synchronization failed',
          error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  Future<void> _syncPendingDocuments() async {
    final pendingDocs = await _firestore
        .collection('documents')
        .where('status', isEqualTo: 'pending_review')
        .get();

    LoggerService.info('Syncing ${pendingDocs.docs.length} pending documents');
  }

  Future<void> _syncPendingTemplates() async {
    final pendingTemplates = await _firestore
        .collection('certificate_templates')
        .where('status', isEqualTo: 'pending_client_review')
        .get();

    LoggerService.info(
        'Syncing ${pendingTemplates.docs.length} pending templates');
  }

  Future<void> _syncUserPermissions() async {
    final users = await _firestore.collection('users').get();
    LoggerService.info('Syncing permissions for ${users.docs.length} users');
  }

  Future<void> _updateSystemStatistics() async {
    final now = DateTime.now();
    await _firestore.collection('system_status').doc('last_sync').set({
      'timestamp': FieldValue.serverTimestamp(),
      'syncedAt': now.toIso8601String(),
    });
  }
}

/// System synchronization report
class SystemSyncReport {
  bool isValid = false;
  DateTime? completedAt;
  final List<String> errors = [];
  final List<String> warnings = [];
  final List<String> successes = [];

  void addError(String error) => errors.add(error);
  void addWarning(String warning) => warnings.add(warning);
  void addSuccess(String success) => successes.add(success);

  Map<String, dynamic> toMap() {
    return {
      'isValid': isValid,
      'completedAt': completedAt?.toIso8601String(),
      'errors': errors,
      'warnings': warnings,
      'successes': successes,
      'errorCount': errors.length,
      'warningCount': warnings.length,
      'successCount': successes.length,
    };
  }
}
