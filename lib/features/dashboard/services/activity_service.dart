import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/config/app_config.dart';
import '../../../core/services/logger_service.dart';

class ActivityService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Log user activity
  Future<void> logActivity({
    required String action,
    required String details,
    String? targetId,
    String? targetType,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      await _firestore.collection(AppConfig.accessLogsCollection).add({
        'userId': user.uid,
        'userEmail': user.email,
        'action': action,
        'details': details,
        'targetId': targetId,
        'targetType': targetType,
        'metadata': metadata ?? {},
        'timestamp': FieldValue.serverTimestamp(),
        'ipAddress': null, // Will be filled by backend function when available
        'userAgent': null, // Will be filled by backend function when available
      });

      LoggerService.info('Activity logged: $action by ${user.email}');
    } catch (e) {
      LoggerService.error('Failed to log activity', error: e);
    }
  }

  // Get recent activities for a user
  Future<List<Map<String, dynamic>>> getRecentActivities({
    String? userId,
    int limit = 20,
  }) async {
    try {
      userId ??= _auth.currentUser?.uid;
      if (userId == null) return [];

      final snapshot = await _firestore
          .collection(AppConfig.accessLogsCollection)
          .where('userId', isEqualTo: userId)
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'action': data['action'] ?? 'Unknown Action',
          'details': data['details'] ?? '',
          'timestamp': data['timestamp'] as Timestamp?,
          'targetType': data['targetType'],
          'targetId': data['targetId'],
          'metadata': data['metadata'] ?? {},
        };
      }).toList();
    } catch (e) {
      LoggerService.error('Failed to get recent activities', error: e);
      return [];
    }
  }

  // Get system-wide recent activities (admin only)
  Future<List<Map<String, dynamic>>> getSystemActivities({
    int limit = 50,
    String? userId,
    String? action,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      Query query = _firestore
          .collection(AppConfig.accessLogsCollection)
          .orderBy('timestamp', descending: true);

      // Apply filters
      if (userId != null) {
        query = query.where('userId', isEqualTo: userId);
      }

      if (action != null) {
        query = query.where('action', isEqualTo: action);
      }

      if (startDate != null) {
        query = query.where('timestamp',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startDate));
      }

      if (endDate != null) {
        query = query.where('timestamp',
            isLessThanOrEqualTo: Timestamp.fromDate(endDate));
      }

      query = query.limit(limit);

      final snapshot = await query.get();

      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'id': doc.id,
          ...data,
        };
      }).toList();
    } catch (e, stackTrace) {
      LoggerService.error('Failed to get system activities',
          error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  // Get user activity statistics
  Future<Map<String, dynamic>> getUserActivityStats({
    String? userId,
    int days = 30,
  }) async {
    try {
      userId ??= _auth.currentUser?.uid;
      if (userId == null) return {};

      final since = DateTime.now().subtract(Duration(days: days));

      final snapshot = await _firestore
          .collection(AppConfig.accessLogsCollection)
          .where('userId', isEqualTo: userId)
          .where('timestamp', isGreaterThan: Timestamp.fromDate(since))
          .get();

      final activities = snapshot.docs.map((doc) => doc.data()).toList();

      // Group by action type
      final actionCounts = <String, int>{};
      final dailyActivity = <String, int>{};

      for (final activity in activities) {
        final action = activity['action'] as String? ?? 'unknown';
        actionCounts[action] = (actionCounts[action] ?? 0) + 1;

        final timestamp = (activity['timestamp'] as Timestamp?)?.toDate();
        if (timestamp != null) {
          final dateKey =
              '${timestamp.year}-${timestamp.month.toString().padLeft(2, '0')}-${timestamp.day.toString().padLeft(2, '0')}';
          dailyActivity[dateKey] = (dailyActivity[dateKey] ?? 0) + 1;
        }
      }

      return {
        'totalActivities': activities.length,
        'actionBreakdown': actionCounts,
        'dailyActivity': dailyActivity,
        'averagePerDay': activities.length / days,
        'period': {
          'days': days,
          'from': since.toIso8601String(),
          'to': DateTime.now().toIso8601String(),
        },
      };
    } catch (e) {
      LoggerService.error('Failed to get user activity stats', error: e);
      return {};
    }
  }

  // Get formatted recent activities for UI display
  Future<List<Map<String, dynamic>>> getFormattedRecentActivities({
    String? userId,
    int limit = 10,
  }) async {
    try {
      final activities =
          await getRecentActivities(userId: userId, limit: limit);

      return activities.map((activity) {
        final timestamp = activity['timestamp'] as Timestamp?;
        final action = activity['action'] as String;
        final details = activity['details'] as String;

        return {
          'title': _formatActivityTitle(action),
          'subtitle': details,
          'time': timestamp != null
              ? _formatRelativeTime(timestamp.toDate())
              : 'Unknown time',
          'icon': _getActivityIcon(action),
          'color': _getActivityColor(action),
        };
      }).toList();
    } catch (e) {
      LoggerService.error('Failed to get formatted activities', error: e);
      return [];
    }
  }

  // Log specific activity types
  Future<void> logCertificateActivity({
    required String action,
    required String certificateId,
    String? details,
    Map<String, dynamic>? metadata,
  }) async {
    await logActivity(
      action: action,
      details: details ?? 'Certificate $action',
      targetId: certificateId,
      targetType: 'certificate',
      metadata: metadata,
    );
  }

  Future<void> logDocumentActivity({
    required String action,
    required String documentId,
    String? details,
    Map<String, dynamic>? metadata,
  }) async {
    await logActivity(
      action: action,
      details: details ?? 'Document $action',
      targetId: documentId,
      targetType: 'document',
      metadata: metadata,
    );
  }

  Future<void> logUserActivity({
    required String action,
    String? targetUserId,
    String? details,
    Map<String, dynamic>? metadata,
  }) async {
    await logActivity(
      action: action,
      details: details ?? 'User $action',
      targetId: targetUserId,
      targetType: 'user',
      metadata: metadata,
    );
  }

  Future<void> logAuthActivity({
    required String action,
    String? details,
  }) async {
    await logActivity(
      action: action,
      details: details ?? 'Authentication $action',
      targetType: 'auth',
    );
  }

  // Clean up old activity logs
  Future<void> cleanupOldActivities({int retentionDays = 180}) async {
    try {
      final cutoffDate = DateTime.now().subtract(Duration(days: retentionDays));

      final snapshot = await _firestore
          .collection(AppConfig.accessLogsCollection)
          .where('timestamp', isLessThan: Timestamp.fromDate(cutoffDate))
          .get();

      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
      LoggerService.info(
          'Cleaned up ${snapshot.docs.length} old activity logs');
    } catch (e) {
      LoggerService.error('Failed to cleanup old activities', error: e);
    }
  }

  // Helper methods for formatting
  String _formatActivityTitle(String action) {
    switch (action.toLowerCase()) {
      case 'login':
        return 'Signed In';
      case 'logout':
        return 'Signed Out';
      case 'create_certificate':
        return 'Created Certificate';
      case 'issue_certificate':
        return 'Issued Certificate';
      case 'revoke_certificate':
        return 'Revoked Certificate';
      case 'download_certificate':
        return 'Downloaded Certificate';
      case 'share_certificate':
        return 'Shared Certificate';
      case 'upload_document':
        return 'Uploaded Document';
      case 'verify_document':
        return 'Verified Document';
      case 'update_profile':
        return 'Updated Profile';
      case 'change_password':
        return 'Changed Password';
      case 'view_document':
        return 'Viewed Document';
      case 'delete_document':
        return 'Deleted Document';
      default:
        return action
            .split('_')
            .map((word) => word[0].toUpperCase() + word.substring(1))
            .join(' ');
    }
  }

  String _formatRelativeTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }

  String _getActivityIcon(String action) {
    switch (action.toLowerCase()) {
      case 'login':
      case 'logout':
        return 'login';
      case 'create_certificate':
      case 'issue_certificate':
        return 'certificate';
      case 'revoke_certificate':
        return 'block';
      case 'download_certificate':
        return 'download';
      case 'share_certificate':
        return 'share';
      case 'upload_document':
        return 'upload';
      case 'verify_document':
        return 'verified';
      case 'update_profile':
        return 'person';
      case 'view_document':
        return 'visibility';
      case 'delete_document':
        return 'delete';
      default:
        return 'info';
    }
  }

  String _getActivityColor(String action) {
    switch (action.toLowerCase()) {
      case 'login':
        return 'success';
      case 'logout':
        return 'info';
      case 'create_certificate':
      case 'issue_certificate':
        return 'primary';
      case 'revoke_certificate':
      case 'delete_document':
        return 'error';
      case 'download_certificate':
      case 'share_certificate':
        return 'info';
      case 'upload_document':
      case 'verify_document':
        return 'success';
      case 'update_profile':
        return 'warning';
      default:
        return 'primary';
    }
  }

  // Get real-time activity stream for admin dashboard
  Stream<List<Map<String, dynamic>>> getActivityStream({int limit = 20}) {
    return _firestore
        .collection(AppConfig.accessLogsCollection)
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'userId': data['userId'],
          'userEmail': data['userEmail'],
          'action': data['action'],
          'details': data['details'],
          'timestamp': data['timestamp'] as Timestamp?,
          'targetType': data['targetType'],
        };
      }).toList();
    });
  }

  // Get activity trends for analytics
  Future<Map<String, dynamic>> getActivityTrends({int days = 30}) async {
    try {
      final since = DateTime.now().subtract(Duration(days: days));

      final snapshot = await _firestore
          .collection(AppConfig.accessLogsCollection)
          .where('timestamp', isGreaterThan: Timestamp.fromDate(since))
          .get();

      final activities = snapshot.docs.map((doc) => doc.data()).toList();

      // Calculate trends
      final dailyTrends = <String, Map<String, int>>{};

      // Initialize daily trends
      for (int i = 0; i < days; i++) {
        final date = DateTime.now().subtract(Duration(days: i));
        final dateKey =
            '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
        dailyTrends[dateKey] = {};
      }

      // Populate trends
      for (final activity in activities) {
        final timestamp = (activity['timestamp'] as Timestamp?)?.toDate();
        final action = activity['action'] as String? ?? 'unknown';

        if (timestamp != null) {
          final dateKey =
              '${timestamp.year}-${timestamp.month.toString().padLeft(2, '0')}-${timestamp.day.toString().padLeft(2, '0')}';

          if (dailyTrends.containsKey(dateKey)) {
            dailyTrends[dateKey]![action] =
                (dailyTrends[dateKey]![action] ?? 0) + 1;
          }
        }
      }

      return {
        'dailyTrends': dailyTrends,
        'totalActivities': activities.length,
        'period': days,
        'generatedAt': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      LoggerService.error('Failed to get activity trends', error: e);
      return {};
    }
  }
}
