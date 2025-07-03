import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

import '../models/user_model.dart';
import 'logger_service.dart';
import 'notification_service.dart';

/// 🔄 **系统交互服务** - 确保各角色间实时交互
class SystemInteractionService {
  static final SystemInteractionService _instance =
      SystemInteractionService._internal();
  factory SystemInteractionService() => _instance;
  SystemInteractionService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final NotificationService _notificationService = NotificationService();
  final Uuid _uuid = const Uuid();

  // =============================================================================
  // CA -> CLIENT INTERACTIONS (模板审核流程)
  // =============================================================================

  /// CA创建模板，自动通知Client审核
  Future<void> handleTemplateCreated({
    required String templateId,
    required String templateName,
    required String caId,
    required String caName,
    Map<String, dynamic>? templateData,
  }) async {
    try {
      LoggerService.info('🔄 Processing template creation: $templateId');

      // 1. 记录系统交互
      await _recordSystemInteraction(
        type: 'template_created',
        fromRole: 'ca',
        toRole: 'client',
        entityId: templateId,
        data: {
          'templateName': templateName,
          'caId': caId,
          'caName': caName,
          'action': 'awaiting_client_review',
        },
      );

      // 2. 获取所有active的Client用户
      final clientUsers = await _firestore
          .collection('users')
          .where('userType', isEqualTo: 'client')
          .where('status', isEqualTo: 'active')
          .get();

      // 3. 为每个Client创建通知
      final batch = _firestore.batch();
      for (final clientDoc in clientUsers.docs) {
        final notificationRef = _firestore.collection('notifications').doc();
        batch.set(notificationRef, {
          'userId': clientDoc.id,
          'type': 'template_review_required',
          'title': 'New Template Awaiting Review',
          'message':
              'A new certificate template "$templateName" from $caName requires your review.',
          'templateId': templateId,
          'caId': caId,
          'caName': caName,
          'priority': 'normal',
          'read': false,
          'createdAt': FieldValue.serverTimestamp(),
          'data': {
            'templateName': templateName,
            'redirectTo': '/client/template-review',
          },
        });
      }
      await batch.commit();

      LoggerService.info(
          '✅ Template creation interaction processed: $templateId');
    } catch (e) {
      LoggerService.error('❌ Failed to handle template creation', error: e);
      rethrow;
    }
  }

  /// Client审核模板，通知CA结果
  Future<void> handleTemplateReviewed({
    required String templateId,
    required String templateName,
    required String clientId,
    required String clientName,
    required String caId,
    required String action, // 'approved', 'rejected', 'needs_revision'
    String? comments,
  }) async {
    try {
      LoggerService.info(
          '🔄 Processing template review: $templateId, action: $action');

      // 1. 更新模板状态
      final newStatus = action == 'approved'
          ? 'client_approved'
          : action == 'rejected'
              ? 'client_rejected'
              : 'needs_revision';

      await _firestore
          .collection('certificate_templates')
          .doc(templateId)
          .update({
        'status': newStatus,
        'clientReviewedBy': clientId,
        'clientReviewedAt': FieldValue.serverTimestamp(),
        'clientComments': comments ?? '',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // 2. 记录审核历史
      await _firestore.collection('template_reviews').add({
        'templateId': templateId,
        'templateName': templateName,
        'reviewedBy': clientId,
        'reviewerName': clientName,
        'reviewerRole': 'client',
        'action': action,
        'comments': comments ?? '',
        'reviewedAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 3. 记录系统交互
      await _recordSystemInteraction(
        type: 'template_reviewed',
        fromRole: 'client',
        toRole: 'ca',
        entityId: templateId,
        data: {
          'templateName': templateName,
          'clientId': clientId,
          'clientName': clientName,
          'action': action,
          'comments': comments,
        },
      );

      // 4. 通知CA
      await _notificationService.sendNotification(
        userId: caId,
        title: 'Template Review Completed',
        message:
            'Your template "$templateName" has been $action by $clientName.',
        type: 'template_review_result',
        data: {
          'templateId': templateId,
          'action': action,
          'redirectTo': '/ca/templates',
        },
      );

      // 5. 如果模板被批准，激活它
      if (action == 'approved') {
        await _activateTemplate(templateId, templateName, caId);
      }

      LoggerService.info(
          '✅ Template review interaction processed: $templateId');
    } catch (e) {
      LoggerService.error('❌ Failed to handle template review', error: e);
      rethrow;
    }
  }

  // =============================================================================
  // CA -> RECIPIENT INTERACTIONS (证书发放流程)
  // =============================================================================

  /// CA发放证书，通知Recipient
  Future<void> handleCertificateIssued({
    required String certificateId,
    required String certificateTitle,
    required String caId,
    required String caName,
    required String recipientEmail,
    String? recipientId,
    Map<String, dynamic>? certificateData,
  }) async {
    try {
      LoggerService.info('🔄 Processing certificate issuance: $certificateId');

      // 1. 确保Recipient用户存在
      final actualRecipientId =
          recipientId ?? await _getOrCreateRecipient(recipientEmail);

      // 2. 记录系统交互
      await _recordSystemInteraction(
        type: 'certificate_issued',
        fromRole: 'ca',
        toRole: 'recipient',
        entityId: certificateId,
        data: {
          'certificateTitle': certificateTitle,
          'caId': caId,
          'caName': caName,
          'recipientEmail': recipientEmail,
          'recipientId': actualRecipientId,
        },
      );

      // 3. 通知Recipient
      await _notificationService.sendNotification(
        userId: actualRecipientId,
        title: 'Certificate Received',
        message:
            'You have received a new certificate: "$certificateTitle" from $caName.',
        type: 'certificate_received',
        data: {
          'certificateId': certificateId,
          'redirectTo': '/certificates',
        },
      );

      // 4. 记录活动日志
      await _firestore.collection('activities').add({
        'type': 'certificate_issued',
        'certificateId': certificateId,
        'title': certificateTitle,
        'caId': caId,
        'caName': caName,
        'recipientId': actualRecipientId,
        'recipientEmail': recipientEmail,
        'timestamp': FieldValue.serverTimestamp(),
      });

      LoggerService.info(
          '✅ Certificate issuance interaction processed: $certificateId');
    } catch (e) {
      LoggerService.error('❌ Failed to handle certificate issuance', error: e);
      rethrow;
    }
  }

  // =============================================================================
  // CA -> CLIENT INTERACTIONS (文档审核流程)
  // =============================================================================

  /// 文档上传后，通知CA审核
  Future<void> handleDocumentUploaded({
    required String documentId,
    required String documentName,
    required String uploaderId,
    required String uploaderName,
    required String documentType,
    Map<String, dynamic>? documentData,
  }) async {
    try {
      LoggerService.info(
          '🔄 Processing document upload: $documentId for user: $uploaderId');

      // 1. 获取所有active的CA用户
      final caUsers = await _firestore
          .collection('users')
          .where('userType', isEqualTo: 'ca')
          .where('status', isEqualTo: 'active')
          .get();

      LoggerService.info(
          '📋 Found ${caUsers.docs.length} active CA users to notify');

      // 2. 先查看文档当前状态
      final docSnapshot =
          await _firestore.collection('documents').doc(documentId).get();
      if (docSnapshot.exists) {
        final currentData = docSnapshot.data() as Map<String, dynamic>;
        LoggerService.info(
            '📄 Document current status: ${currentData['status']} -> updating to pending');
        LoggerService.info(
            '📄 Document uploaderId: ${currentData['uploaderId']}');
      } else {
        LoggerService.warning(
            '⚠️ Document $documentId not found in Firestore!');
        return;
      }

      // 3. 更新文档状态为等待CA审核
      await _firestore.collection('documents').doc(documentId).update({
        'status': 'pending', // 设置为pending状态让CA能看到
        'updatedAt': FieldValue.serverTimestamp(),
      });

      LoggerService.info('✅ Document status updated to pending: $documentId');

      // 3. 记录系统交互
      await _recordSystemInteraction(
        type: 'document_uploaded',
        fromRole: 'client', // 或 recipient
        toRole: 'ca',
        entityId: documentId,
        data: {
          'documentName': documentName,
          'uploaderId': uploaderId,
          'uploaderName': uploaderName,
          'documentType': documentType,
        },
      );

      // 4. 为每个CA创建通知
      final batch = _firestore.batch();
      for (final caDoc in caUsers.docs) {
        final notificationRef = _firestore.collection('notifications').doc();
        batch.set(notificationRef, {
          'userId': caDoc.id,
          'type': 'document_review_required',
          'title': 'New Document Awaiting Review',
          'message':
              'A new document "$documentName" from $uploaderName requires your review.',
          'documentId': documentId,
          'uploaderId': uploaderId,
          'uploaderName': uploaderName,
          'priority': 'normal',
          'read': false,
          'createdAt': FieldValue.serverTimestamp(),
          'data': {
            'documentName': documentName,
            'redirectTo': '/ca/document-review',
          },
        });
      }
      await batch.commit();

      LoggerService.info(
          '✅ Document upload interaction processed: $documentId');
    } catch (e) {
      LoggerService.error('❌ Failed to handle document upload', error: e);
      rethrow;
    }
  }

  // =============================================================================
  // ADMIN INTERACTIONS (系统管理)
  // =============================================================================

  /// 处理用户状态变更，通知相关方
  Future<void> handleUserStatusChanged({
    required String userId,
    required String userEmail,
    required String userName,
    required UserStatus oldStatus,
    required UserStatus newStatus,
    required UserType userType,
    String? adminId,
  }) async {
    try {
      LoggerService.info(
          '🔄 Processing user status change: $userId, $oldStatus -> $newStatus');

      // 1. 记录系统交互
      await _recordSystemInteraction(
        type: 'user_status_changed',
        fromRole: 'admin',
        toRole: userType.name,
        entityId: userId,
        data: {
          'userEmail': userEmail,
          'userName': userName,
          'oldStatus': oldStatus.name,
          'newStatus': newStatus.name,
          'userType': userType.name,
          'adminId': adminId,
        },
      );

      // 2. 通知用户状态变更
      await _notificationService.sendNotification(
        userId: userId,
        title: 'Account Status Updated',
        message: 'Your account status has been changed to ${newStatus.name}.',
        type: 'status_update',
        data: {
          'newStatus': newStatus.name,
          'redirectTo': '/profile',
        },
      );

      // 3. 如果是CA或Client被激活，发送欢迎消息
      if (newStatus == UserStatus.active &&
          (userType == UserType.ca || userType == UserType.client)) {
        await _sendWelcomeMessage(userId, userType, userName);
      }

      LoggerService.info('✅ User status change interaction processed: $userId');
    } catch (e) {
      LoggerService.error('❌ Failed to handle user status change', error: e);
      rethrow;
    }
  }

  // =============================================================================
  // PRIVATE HELPER METHODS
  // =============================================================================

  /// 记录系统交互
  Future<void> _recordSystemInteraction({
    required String type,
    required String fromRole,
    required String toRole,
    required String entityId,
    required Map<String, dynamic> data,
  }) async {
    await _firestore.collection('system_interactions').add({
      'id': _uuid.v4(),
      'type': type,
      'fromRole': fromRole,
      'toRole': toRole,
      'entityId': entityId,
      'data': data,
      'timestamp': FieldValue.serverTimestamp(),
      'processed': true,
    });
  }

  /// 获取或创建Recipient用户
  Future<String> _getOrCreateRecipient(String email) async {
    try {
      // 先查找现有用户
      final userQuery = await _firestore
          .collection('users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (userQuery.docs.isNotEmpty) {
        return userQuery.docs.first.id;
      } else {
        // 创建新的Recipient用户
        final recipientId = _uuid.v4();
        final recipientName = email.split('@').first;

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
          'metadata': {
            'createdByCertificate': true,
            'source': 'certificate_issuance',
          },
        });

        LoggerService.info('Created new recipient user: $email');
        return recipientId;
      }
    } catch (e) {
      LoggerService.error('Failed to get or create recipient', error: e);
      rethrow;
    }
  }

  /// 激活模板
  Future<void> _activateTemplate(
      String templateId, String templateName, String caId) async {
    try {
      await _firestore
          .collection('certificate_templates')
          .doc(templateId)
          .update({
        'status': 'active',
        'isActive': true,
        'activatedAt': FieldValue.serverTimestamp(),
      });

      // 通知CA模板已激活
      await _notificationService.sendNotification(
        userId: caId,
        title: 'Template Activated',
        message:
            'Your template "$templateName" is now active and ready for use.',
        type: 'template_activated',
        data: {
          'templateId': templateId,
          'redirectTo': '/ca/templates',
        },
      );

      LoggerService.info('Template activated: $templateId');
    } catch (e) {
      LoggerService.error('Failed to activate template', error: e);
    }
  }

  /// 发送欢迎消息
  Future<void> _sendWelcomeMessage(
      String userId, UserType userType, String userName) async {
    try {
      final String welcomeMessage;
      final String redirectTo;

      switch (userType) {
        case UserType.ca:
          welcomeMessage =
              'Welcome to the Digital Certificate Repository! You can now create certificate templates and issue certificates.';
          redirectTo = '/ca/dashboard';
          break;
        case UserType.client:
          welcomeMessage =
              'Welcome to the Digital Certificate Repository! You can now review certificate templates and manage documents.';
          redirectTo = '/client/dashboard';
          break;
        default:
          return;
      }

      await _notificationService.sendNotification(
        userId: userId,
        title: 'Welcome to Digital Certificate Repository',
        message: welcomeMessage,
        type: 'welcome',
        data: {
          'redirectTo': redirectTo,
        },
      );
    } catch (e) {
      LoggerService.error('Failed to send welcome message', error: e);
    }
  }

  // =============================================================================
  // PUBLIC MONITORING METHODS
  // =============================================================================

  /// 获取系统交互统计
  Future<Map<String, dynamic>> getInteractionStats() async {
    try {
      final interactions = await _firestore
          .collection('system_interactions')
          .orderBy('timestamp', descending: true)
          .limit(100)
          .get();

      final stats = <String, int>{};
      final roleInteractions = <String, int>{};

      for (final doc in interactions.docs) {
        final data = doc.data();
        final type = data['type'] as String? ?? 'unknown';
        final fromRole = data['fromRole'] as String? ?? 'unknown';
        final toRole = data['toRole'] as String? ?? 'unknown';

        stats[type] = (stats[type] ?? 0) + 1;
        roleInteractions['$fromRole->$toRole'] =
            (roleInteractions['$fromRole->$toRole'] ?? 0) + 1;
      }

      return {
        'total': interactions.docs.length,
        'byType': stats,
        'byRoleFlow': roleInteractions,
        'lastUpdate': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      LoggerService.error('Failed to get interaction stats', error: e);
      return {};
    }
  }

  /// 验证系统同步状态
  Future<bool> validateSystemSync() async {
    try {
      // 检查是否有待处理的交互
      final pendingInteractions = await _firestore
          .collection('system_interactions')
          .where('processed', isEqualTo: false)
          .get();

      return pendingInteractions.docs.isEmpty;
    } catch (e) {
      LoggerService.error('Failed to validate system sync', error: e);
      return false;
    }
  }
}
