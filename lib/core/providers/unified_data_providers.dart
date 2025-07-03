import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/user_model.dart';
import '../services/logger_service.dart';
import '../../features/auth/providers/auth_providers.dart';

// =============================================================================
// UNIFIED CERTIFICATE PROVIDERS
// =============================================================================

/// 🔄 统一的待处理模板提供者 - 所有角色使用相同数据源
final unifiedPendingTemplatesProvider =
    StreamProvider<List<Map<String, dynamic>>>((ref) {
  return FirebaseFirestore.instance
      .collection('certificate_templates')
      .where('status', isEqualTo: 'pending_client_review')
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((snapshot) => snapshot.docs.map((doc) {
            final data = doc.data();
            return <String, dynamic>{
              'id': doc.id,
              ...data,
            };
          }).toList());
});

/// 🔄 统一的活跃模板提供者
final unifiedActiveTemplatesProvider =
    StreamProvider<List<Map<String, dynamic>>>((ref) {
  return FirebaseFirestore.instance
      .collection('certificate_templates')
      .where('status', isEqualTo: 'active')
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((snapshot) => snapshot.docs.map((doc) {
            final data = doc.data();
            return <String, dynamic>{
              'id': doc.id,
              ...data,
            };
          }).toList());
});

/// 🔄 统一的证书提供者 - 基于用户角色返回相应数据
final unifiedCertificatesProvider =
    StreamProvider<List<Map<String, dynamic>>>((ref) {
  final currentUser = ref.watch(currentUserProvider).value;

  if (currentUser == null) {
    return Stream.value(<Map<String, dynamic>>[]);
  }

  Query query = FirebaseFirestore.instance.collection('certificates');

  // 根据用户角色过滤数据
  switch (currentUser.role) {
    case UserRole.systemAdmin:
      // Admin 可以看到所有证书
      break;
    case UserRole.certificateAuthority:
      // CA 只能看到自己发放的证书
      query = query.where('issuerId', isEqualTo: currentUser.id);
      break;
    case UserRole.client:
      // Client 可以看到所在组织的证书
      if (currentUser.organizationId != null) {
        query = query.where('organizationId',
            isEqualTo: currentUser.organizationId);
      } else {
        return Stream.value(<Map<String, dynamic>>[]);
      }
      break;
    case UserRole.recipient:
      // Recipient 只能看到自己的证书
      query = query.where('recipientId', isEqualTo: currentUser.id);
      break;
    case UserRole.viewer:
      // Viewer 只能看到公开的证书
      query = query.where('isPublic', isEqualTo: true);
      break;
  }

  return query
      .orderBy('createdAt', descending: true)
      .limit(50)
      .snapshots()
      .map((snapshot) => snapshot.docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>?;
            return <String, dynamic>{
              'id': doc.id,
              if (data != null) ...data,
            };
          }).toList());
});

/// 🔄 统一的文档提供者
final unifiedDocumentsProvider =
    StreamProvider<List<Map<String, dynamic>>>((ref) {
  final currentUser = ref.watch(currentUserProvider).value;

  if (currentUser == null) {
    LoggerService.info('📄 No current user for documents query');
    return Stream.value(<Map<String, dynamic>>[]);
  }

  // 🔍 DEBUG: Log current user details
  LoggerService.info(
      '📄 Documents query for user: ${currentUser.email} (role: ${currentUser.role.name}, id: ${currentUser.id})');

  Query query = FirebaseFirestore.instance.collection('documents');

  // 根据用户角色过滤数据
  switch (currentUser.role) {
    case UserRole.systemAdmin:
      // Admin 可以看到所有文档
      LoggerService.info('📄 Admin query: all documents');
      break;
    case UserRole.certificateAuthority:
      // CA 可以看到需要审核的文档
      query = query.where('status', whereIn: ['pending', 'under_review']);
      LoggerService.info('📄 CA query: status in [pending, under_review]');
      break;
    case UserRole.client:
      // Client 可以看到与自己相关的文档
      query = query.where('uploaderId', isEqualTo: currentUser.id);
      LoggerService.info('📄 Client query: uploaderId == ${currentUser.id}');
      break;
    case UserRole.recipient:
      // Recipient 可以看到自己上传的文档
      query = query.where('uploaderId', isEqualTo: currentUser.id);
      LoggerService.info('📄 Recipient query: uploaderId == ${currentUser.id}');
      break;
    case UserRole.viewer:
      // Viewer 只能看到公开的文档
      query = query.where('isPublic', isEqualTo: true);
      LoggerService.info('📄 Viewer query: isPublic == true');
      break;
  }

  return query
      .orderBy('uploadedAt', descending: true)
      .limit(50)
      .snapshots()
      .map((snapshot) {
    // 🔍 DEBUG: Log query results
    LoggerService.info('📄 Query returned ${snapshot.docs.length} documents');

    final documents = snapshot.docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>?;
      final result = <String, dynamic>{
        'id': doc.id,
        if (data != null) ...data,
      };

      // 🔍 DEBUG: Log first few documents
      if (snapshot.docs.indexOf(doc) < 3) {
        LoggerService.info(
            '📄 Document ${doc.id}: name=${data?['name']}, uploaderId=${data?['uploaderId']}, status=${data?['status']}');
      }

      return result;
    }).toList();

    return documents;
  });
});

// =============================================================================
// UNIFIED REVIEW AND ACTIVITY PROVIDERS
// =============================================================================

/// 🔄 统一的审核历史提供者
final unifiedReviewHistoryProvider =
    StreamProvider<List<Map<String, dynamic>>>((ref) {
  final currentUser = ref.watch(currentUserProvider).value;

  if (currentUser == null) {
    return Stream.value(<Map<String, dynamic>>[]);
  }

  Query query = FirebaseFirestore.instance.collection('template_reviews');

  // 根据用户角色过滤审核数据
  if (currentUser.isClientType || currentUser.isAdmin) {
    query = query.where('reviewedBy', isEqualTo: currentUser.id);
  } else if (currentUser.isCA) {
    query = query.where('caId', isEqualTo: currentUser.id);
  } else {
    return Stream.value(<Map<String, dynamic>>[]);
  }

  return query
      .orderBy('reviewedAt', descending: true)
      .limit(100)
      .snapshots()
      .map((snapshot) => snapshot.docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>?;
            return <String, dynamic>{
              'id': doc.id,
              if (data != null) ...data,
            };
          }).toList());
});

/// 🔄 统一的活动提供者
final unifiedActivitiesProvider =
    StreamProvider<List<Map<String, dynamic>>>((ref) {
  final currentUser = ref.watch(currentUserProvider).value;

  if (currentUser == null) {
    return Stream.value(<Map<String, dynamic>>[]);
  }

  Query query = FirebaseFirestore.instance.collection('activities');

  // 根据用户角色过滤活动数据
  if (currentUser.isAdmin) {
    // Admin 可以看到所有活动
    // 不添加额外过滤条件
  } else {
    // 其他用户只能看到与自己相关的活动
    query = query.where('userId', isEqualTo: currentUser.id);
  }

  return query
      .orderBy('timestamp', descending: true)
      .limit(50)
      .snapshots()
      .map((snapshot) => snapshot.docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>?;
            return <String, dynamic>{
              'id': doc.id,
              if (data != null) ...data,
            };
          }).toList());
});

/// 🔄 统一的通知提供者
final unifiedNotificationsProvider =
    StreamProvider<List<Map<String, dynamic>>>((ref) {
  final currentUser = ref.watch(currentUserProvider).value;

  if (currentUser == null) {
    return Stream.value(<Map<String, dynamic>>[]);
  }

  return FirebaseFirestore.instance
      .collection('notifications')
      .where('userId', isEqualTo: currentUser.id)
      .orderBy('createdAt', descending: true)
      .limit(50)
      .snapshots()
      .map((snapshot) => snapshot.docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>?;
            return <String, dynamic>{
              'id': doc.id,
              if (data != null) ...data,
            };
          }).toList());
});

// =============================================================================
// UNIFIED STATISTICS PROVIDERS
// =============================================================================

/// 🔄 统一的用户统计提供者
final unifiedUserStatsProvider = StreamProvider<Map<String, int>>((ref) {
  final currentUser = ref.watch(currentUserProvider).value;

  if (currentUser == null) {
    return Stream.value(<String, int>{});
  }

  if (currentUser.isAdmin) {
    // Admin 获取全局统计
    return FirebaseFirestore.instance
        .collection('users')
        .snapshots()
        .map((snapshot) {
      final users = snapshot.docs;
      return <String, int>{
        'total': users.length,
        'active': users.where((u) => u.data()['status'] == 'active').length,
        'pending': users.where((u) => u.data()['status'] == 'pending').length,
        'cas': users.where((u) => u.data()['userType'] == 'ca').length,
        'clients': users.where((u) => u.data()['userType'] == 'client').length,
        'recipients': users.where((u) => u.data()['userType'] == 'user').length,
      };
    });
  } else if (currentUser.isClientType) {
    // Client 获取审核统计
    return FirebaseFirestore.instance
        .collection('template_reviews')
        .where('reviewedBy', isEqualTo: currentUser.id)
        .snapshots()
        .map((snapshot) {
      final reviews = snapshot.docs;
      final now = DateTime.now();
      final thisMonth = DateTime(now.year, now.month, 1);

      return <String, int>{
        'total': reviews.length,
        'approved':
            reviews.where((r) => r.data()['action'] == 'approved').length,
        'rejected':
            reviews.where((r) => r.data()['action'] == 'rejected').length,
        'pending': reviews.where((r) => r.data()['action'] == 'pending').length,
        'thisMonth': reviews.where((r) {
          final reviewedAt = (r.data()['reviewedAt'] as Timestamp?)?.toDate();
          return reviewedAt != null && reviewedAt.isAfter(thisMonth);
        }).length,
      };
    });
  } else if (currentUser.isCA) {
    // CA 获取证书统计
    return FirebaseFirestore.instance
        .collection('certificates')
        .where('issuerId', isEqualTo: currentUser.id)
        .snapshots()
        .map((snapshot) {
      final certs = snapshot.docs;
      return <String, int>{
        'total': certs.length,
        'issued': certs.where((c) => c.data()['status'] == 'issued').length,
        'pending': certs.where((c) => c.data()['status'] == 'pending').length,
        'revoked': certs.where((c) => c.data()['status'] == 'revoked').length,
      };
    });
  } else {
    // Recipients 获取个人统计
    return FirebaseFirestore.instance
        .collection('certificates')
        .where('recipientId', isEqualTo: currentUser.id)
        .snapshots()
        .map((snapshot) {
      final certs = snapshot.docs;
      return <String, int>{
        'total': certs.length,
        'received': certs.where((c) => c.data()['status'] == 'issued').length,
        'pending': certs.where((c) => c.data()['status'] == 'pending').length,
      };
    });
  }
});

// =============================================================================
// CROSS-SYSTEM INTERACTION PROVIDERS
// =============================================================================

/// 🔄 系统交互状态提供者 - 监控各系统间的交互
final systemInteractionProvider = StreamProvider<Map<String, dynamic>>((ref) {
  return FirebaseFirestore.instance
      .collection('system_interactions')
      .orderBy('timestamp', descending: true)
      .limit(10)
      .snapshots()
      .map((snapshot) {
    final interactions = snapshot.docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>?;
      return <String, dynamic>{
        'id': doc.id,
        if (data != null) ...data,
      };
    }).toList();

    // 计算交互统计
    final stats = <String, int>{};
    for (final interaction in interactions) {
      final type = interaction['type'] as String? ?? 'unknown';
      stats[type] = (stats[type] ?? 0) + 1;
    }

    return <String, dynamic>{
      'interactions': interactions,
      'stats': stats,
      'lastUpdate': DateTime.now().toIso8601String(),
    };
  });
});

/// 🔄 数据同步状态提供者
final dataSyncStatusProvider = Provider<Map<String, bool>>((ref) {
  // 监控各个数据源的同步状态
  final templates = ref.watch(unifiedPendingTemplatesProvider);
  final certificates = ref.watch(unifiedCertificatesProvider);
  final documents = ref.watch(unifiedDocumentsProvider);
  final reviews = ref.watch(unifiedReviewHistoryProvider);
  final notifications = ref.watch(unifiedNotificationsProvider);

  return <String, bool>{
    'templates': !templates.isLoading && !templates.hasError,
    'certificates': !certificates.isLoading && !certificates.hasError,
    'documents': !documents.isLoading && !documents.hasError,
    'reviews': !reviews.isLoading && !reviews.hasError,
    'notifications': !notifications.isLoading && !notifications.hasError,
    'allSynced': ![templates, certificates, documents, reviews, notifications]
        .any((provider) => provider.isLoading || provider.hasError),
  };
});
