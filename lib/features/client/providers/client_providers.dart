import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/services/logger_service.dart';
import '../../auth/providers/auth_providers.dart';

// Client Dashboard Statistics Provider
final clientDashboardStatsProvider = StreamProvider<Map<String, int>>((ref) {
  final currentUser = ref.watch(currentUserProvider).value;
  if (currentUser == null ||
      (!currentUser.isClientType && !currentUser.isAdmin)) {
    return Stream.value({});
  }

  return FirebaseFirestore.instance
      .collection('template_reviews')
      .where('reviewedBy', isEqualTo: currentUser.id)
      .snapshots()
      .map((snapshot) {
    final reviews = snapshot.docs;
    final today = DateTime.now();
    final startOfMonth = DateTime(today.year, today.month, 1);

    int pending = 0;
    int approvedThisMonth = 0;
    int rejected = 0;
    int total = reviews.length;

    for (final doc in reviews) {
      final data = doc.data();
      final action = data['action'] as String? ?? '';
      final reviewedAt = (data['reviewedAt'] as Timestamp?)?.toDate();

      switch (action) {
        case 'approved':
          if (reviewedAt != null && reviewedAt.isAfter(startOfMonth)) {
            approvedThisMonth++;
          }
          break;
        case 'rejected':
          rejected++;
          break;
        case 'pending':
          pending++;
          break;
      }
    }

    return {
      'pending': pending,
      'approvedThisMonth': approvedThisMonth,
      'rejected': rejected,
      'total': total,
    };
  });
});

// Pending Templates Provider
final pendingTemplatesProvider =
    StreamProvider<List<Map<String, dynamic>>>((ref) {
  return FirebaseFirestore.instance
      .collection('certificate_templates')
      .where('status', isEqualTo: 'pending_client_review')
      .orderBy('createdAt', descending: true)
      .limit(10)
      .snapshots()
      .map((snapshot) => snapshot.docs
          .map((doc) => {
                'id': doc.id,
                ...doc.data(),
              })
          .toList());
});

// Client Review Activities Provider
final clientReviewActivitiesProvider =
    StreamProvider<List<Map<String, dynamic>>>((ref) {
  final currentUser = ref.watch(currentUserProvider).value;
  if (currentUser == null) {
    return Stream.value([]);
  }

  return FirebaseFirestore.instance
      .collection('template_reviews')
      .where('reviewedBy', isEqualTo: currentUser.id)
      .orderBy('reviewedAt', descending: true)
      .limit(10)
      .snapshots()
      .map((snapshot) => snapshot.docs
          .map((doc) => {
                'id': doc.id,
                ...doc.data(),
              })
          .toList());
});

// Client Template Review History Provider
final clientReviewHistoryProvider =
    StreamProvider<List<Map<String, dynamic>>>((ref) {
  final currentUser = ref.watch(currentUserProvider).value;
  if (currentUser == null) {
    return Stream.value([]);
  }

  return FirebaseFirestore.instance
      .collection('template_reviews')
      .where('reviewedBy', isEqualTo: currentUser.id)
      .orderBy('reviewedAt', descending: true)
      .snapshots()
      .map((snapshot) => snapshot.docs
          .map((doc) => {
                'id': doc.id,
                ...doc.data(),
              })
          .toList());
});

// Client Reports Data Provider
final clientReportsDataProvider =
    FutureProvider<Map<String, dynamic>>((ref) async {
  final currentUser = ref.watch(currentUserProvider).value;
  if (currentUser == null) {
    return {};
  }

  try {
    // Get all user review records
    final reviewsSnapshot = await FirebaseFirestore.instance
        .collection('template_reviews')
        .where('reviewedBy', isEqualTo: currentUser.id)
        .get();

    final reviews = reviewsSnapshot.docs;

    // Statistical data
    Map<String, int> monthlyStats = {};
    Map<String, int> actionStats = {};
    List<Map<String, dynamic>> recentReviews = [];

    for (final doc in reviews) {
      final data = doc.data();
      final action = data['action'] as String? ?? 'unknown';
      final reviewedAt = (data['reviewedAt'] as Timestamp?)?.toDate();

      // Monthly statistics
      if (reviewedAt != null) {
        final monthKey =
            '${reviewedAt.year}-${reviewedAt.month.toString().padLeft(2, '0')}';
        monthlyStats[monthKey] = (monthlyStats[monthKey] ?? 0) + 1;
      }

      // Action statistics
      actionStats[action] = (actionStats[action] ?? 0) + 1;

      // Recent review records
      if (recentReviews.length < 20) {
        recentReviews.add({
          'id': doc.id,
          ...data,
        });
      }
    }

    return {
      'totalReviews': reviews.length,
      'monthlyStats': monthlyStats,
      'actionStats': actionStats,
      'recentReviews': recentReviews,
    };
  } catch (e) {
    LoggerService.error('Failed to load client reports data', error: e);
    return {};
  }
});

// Template Review Action Provider
final templateReviewActionProvider =
    StateNotifierProvider<TemplateReviewNotifier, TemplateReviewState>((ref) {
  return TemplateReviewNotifier();
});

// Client Statistics Provider
final clientStatisticsProvider = FutureProvider<ClientStatistics>((ref) async {
  final currentUser = ref.watch(currentUserProvider).value;
  if (currentUser == null) {
    throw Exception('User not authenticated');
  }

  try {
    // Get template review statistics
    final templatesSnapshot = await FirebaseFirestore.instance
        .collection('certificate_templates')
        .where('reviewedBy', arrayContains: currentUser.id)
        .get();

    // Get review record statistics
    final reviewsSnapshot = await FirebaseFirestore.instance
        .collection('template_reviews')
        .where('reviewedBy', isEqualTo: currentUser.id)
        .get();

    final totalTemplates = templatesSnapshot.docs.length;
    final totalReviews = reviewsSnapshot.docs.length;

    int approvedTemplates = 0;
    int rejectedTemplates = 0;
    int pendingTemplates = 0;

    for (final doc in templatesSnapshot.docs) {
      final status = doc.data()['status'] as String? ?? '';
      switch (status) {
        case 'approved':
          approvedTemplates++;
          break;
        case 'rejected':
          rejectedTemplates++;
          break;
        case 'pending_client_review':
          pendingTemplates++;
          break;
      }
    }

    return ClientStatistics(
      totalTemplatesReviewed: totalTemplates,
      totalReviews: totalReviews,
      approvedTemplates: approvedTemplates,
      rejectedTemplates: rejectedTemplates,
      pendingTemplates: pendingTemplates,
    );
  } catch (e) {
    LoggerService.error('Failed to load client statistics', error: e);
    throw Exception('Failed to load statistics: $e');
  }
});

// State Classes

class TemplateReviewState {
  final bool isLoading;
  final String? error;
  final String? successMessage;
  final String? lastAction;

  const TemplateReviewState({
    this.isLoading = false,
    this.error,
    this.successMessage,
    this.lastAction,
  });

  TemplateReviewState copyWith({
    bool? isLoading,
    String? error,
    String? successMessage,
    String? lastAction,
  }) {
    return TemplateReviewState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      successMessage: successMessage,
      lastAction: lastAction ?? this.lastAction,
    );
  }
}

class TemplateReviewNotifier extends StateNotifier<TemplateReviewState> {
  TemplateReviewNotifier() : super(const TemplateReviewState());

  Future<void> approveTemplate(String templateId, String comments) async {
    try {
      state = state.copyWith(isLoading: true, error: null);

      // Create review record
      await FirebaseFirestore.instance.collection('template_reviews').add({
        'templateId': templateId,
        'action': 'approved',
        'comments': comments,
        'reviewedAt': Timestamp.now(),
        'reviewedBy':
            'current_user_id', // Get from user provider in actual system
      });

      // Update template status
      await FirebaseFirestore.instance
          .collection('certificate_templates')
          .doc(templateId)
          .update({
        'status': 'approved',
        'approvedAt': Timestamp.now(),
        'clientComments': comments,
      });

      state = state.copyWith(
        isLoading: false,
        successMessage: 'Template approved successfully',
        lastAction: 'approved',
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to approve template: $e',
      );
    }
  }

  Future<void> rejectTemplate(String templateId, String reason) async {
    try {
      state = state.copyWith(isLoading: true, error: null);

      // Create review record
      await FirebaseFirestore.instance.collection('template_reviews').add({
        'templateId': templateId,
        'action': 'rejected',
        'reason': reason,
        'reviewedAt': Timestamp.now(),
        'reviewedBy':
            'current_user_id', // Get from user provider in actual system
      });

      // Update template status
      await FirebaseFirestore.instance
          .collection('certificate_templates')
          .doc(templateId)
          .update({
        'status': 'rejected',
        'rejectedAt': Timestamp.now(),
        'rejectionReason': reason,
      });

      state = state.copyWith(
        isLoading: false,
        successMessage: 'Template rejected',
        lastAction: 'rejected',
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to reject template: $e',
      );
    }
  }

  Future<void> requestChanges(String templateId, String changes) async {
    try {
      state = state.copyWith(isLoading: true, error: null);

      // Create review record
      await FirebaseFirestore.instance.collection('template_reviews').add({
        'templateId': templateId,
        'action': 'needs_revision',
        'requestedChanges': changes,
        'reviewedAt': Timestamp.now(),
        'reviewedBy':
            'current_user_id', // Get from user provider in actual system
      });

      // Update template status
      await FirebaseFirestore.instance
          .collection('certificate_templates')
          .doc(templateId)
          .update({
        'status': 'needs_revision',
        'revisionRequestedAt': Timestamp.now(),
        'requestedChanges': changes,
      });

      state = state.copyWith(
        isLoading: false,
        successMessage: 'Revision requested',
        lastAction: 'needs_revision',
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to request changes: $e',
      );
    }
  }

  void clearState() {
    state = const TemplateReviewState();
  }
}

// Data Models

class ClientStatistics {
  final int totalTemplatesReviewed;
  final int totalReviews;
  final int approvedTemplates;
  final int rejectedTemplates;
  final int pendingTemplates;

  const ClientStatistics({
    required this.totalTemplatesReviewed,
    required this.totalReviews,
    required this.approvedTemplates,
    required this.rejectedTemplates,
    required this.pendingTemplates,
  });

  int get completedReviews => approvedTemplates + rejectedTemplates;
  double get approvalRate =>
      completedReviews > 0 ? (approvedTemplates / completedReviews) * 100 : 0;
}
