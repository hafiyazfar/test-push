import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:animate_do/animate_do.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/services/logger_service.dart';
import '../../../auth/providers/auth_providers.dart';

// Client Dashboard statistics provider
final clientDashboardStatsProvider = StreamProvider<Map<String, int>>((ref) {
  final userId = ref.watch(currentUserProvider).value?.id;
  if (userId == null) {
    return Stream.value({});
  }

  return FirebaseFirestore.instance
      .collection('template_reviews')
      .where('reviewedBy', isEqualTo: userId)
      .snapshots()
      .map((snapshot) {
    final reviews = snapshot.docs;
    final now = DateTime.now();
    final thisMonth = DateTime(now.year, now.month, 1);

    final pendingCount = reviews.where((doc) {
      final data = doc.data();
      return data['status'] == 'pending';
    }).length;

    final approvedThisMonth = reviews.where((doc) {
      final data = doc.data();
      final reviewedAt = (data['reviewedAt'] as Timestamp?)?.toDate();
      return data['action'] == 'approved' &&
          reviewedAt != null &&
          reviewedAt.isAfter(thisMonth);
    }).length;

    final rejectedCount = reviews.where((doc) {
      final data = doc.data();
      return data['action'] == 'rejected';
    }).length;

    return {
      'pending': pendingCount,
      'approvedThisMonth': approvedThisMonth,
      'rejected': rejectedCount,
      'total': reviews.length,
    };
  });
});

// Pending templates provider
final pendingTemplatesProvider =
    StreamProvider<List<Map<String, dynamic>>>((ref) {
  return FirebaseFirestore.instance
      .collection('certificate_templates')
      .where('status', isEqualTo: 'pending_client_review')
      .orderBy('createdAt', descending: true)
      .limit(5) // Only take the latest 5
      .snapshots()
      .map((snapshot) => snapshot.docs
          .map((doc) => {
                'id': doc.id,
                ...doc.data(),
              })
          .toList());
});

// Recent activities provider
final recentActivitiesProvider =
    StreamProvider<List<Map<String, dynamic>>>((ref) {
  final userId = ref.watch(currentUserProvider).value?.id;
  if (userId == null) {
    return Stream.value([]);
  }

  return FirebaseFirestore.instance
      .collection('template_reviews')
      .where('reviewedBy', isEqualTo: userId)
      .orderBy('reviewedAt', descending: true)
      .limit(5)
      .snapshots()
      .map((snapshot) => snapshot.docs
          .map((doc) => {
                'id': doc.id,
                ...doc.data(),
              })
          .toList());
});

class ClientDashboard extends ConsumerStatefulWidget {
  const ClientDashboard({super.key});

  @override
  ConsumerState<ClientDashboard> createState() => _ClientDashboardState();
}

class _ClientDashboardState extends ConsumerState<ClientDashboard>
    with TickerProviderStateMixin {
  late AnimationController _refreshAnimationController;

  @override
  void initState() {
    super.initState();
    _refreshAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _refreshAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider).value;
    final statsAsync = ref.watch(clientDashboardStatsProvider);
    final pendingTemplatesAsync = ref.watch(pendingTemplatesProvider);
    final recentActivitiesAsync = ref.watch(recentActivitiesProvider);

    // 🚀 Important: Only check Client-related permissions when actually accessing Client pages
    final currentLocation =
        GoRouter.of(context).routerDelegate.currentConfiguration.uri.path;
    final isAccessingClientPages = currentLocation.startsWith('/client/');

    if (kDebugMode) {
      LoggerService.debug(
          'Client Dashboard build - currentLocation: $currentLocation, isAccessingClientPages: $isAccessingClientPages');
    }

    if (isAccessingClientPages &&
        (user == null || (!user.isClientType && !user.isAdmin))) {
      return Scaffold(
        body: Center(
          child: Semantics(
            label: 'Unauthorized access message',
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.lock,
                  size: 80,
                  color: AppTheme.errorColor,
                ),
                const SizedBox(height: 16),
                Text(
                  'Unauthorized Access',
                  style: AppTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'You do not have permission to access this page.',
                  style: AppTheme.bodyLarge.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: RefreshIndicator(
        onRefresh: () async {
          _refreshAnimationController.forward().then((_) {
            _refreshAnimationController.reset();
          });

          // Refresh all data
          ref.invalidate(clientDashboardStatsProvider);
          ref.invalidate(pendingTemplatesProvider);
          ref.invalidate(recentActivitiesProvider);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with Animation
              Semantics(
                header: true,
                label: 'Client Dashboard',
                child: FadeInDown(
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: Colors.blue[100],
                        child: Icon(
                          Icons.verified_outlined,
                          size: 28,
                          color: Colors.blue[600],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Client',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[800],
                            ),
                          ),
                          Text(
                            'Review and approve CA-created certificate templates',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // Statistics Overview with Animation
              Semantics(
                label: 'Certificate approval statistics overview',
                child: FadeInUp(
                  delay: const Duration(milliseconds: 200),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Certificate Approval Overview',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[800],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Real-time statistics data
                      statsAsync.when(
                        data: (stats) => _buildStatCards(stats),
                        loading: () => _buildLoadingStats(),
                        error: (error, stack) => _buildErrorStats(),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // Quick Actions with Animation
              Semantics(
                label: 'Quick action buttons section',
                child: FadeInUp(
                  delay: const Duration(milliseconds: 400),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Quick Actions',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[800],
                        ),
                      ),
                      const SizedBox(height: 16),
                      GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: 2,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio: 1.5,
                        children: [
                          _buildActionCard(
                            title: 'Review Templates',
                            subtitle: 'Review CA-created certificate templates',
                            icon: Icons.rate_review,
                            color: Colors.blue,
                            onTap: () => context.go('/client/template-review'),
                          ),
                          _buildActionCard(
                            title: 'Approval History',
                            subtitle: 'View your approval/rejection history',
                            icon: Icons.history,
                            color: Colors.purple,
                            onTap: () => context.go('/client/review-history'),
                          ),
                          _buildActionCard(
                            title: 'Review Reports',
                            subtitle: 'View detailed review statistics',
                            icon: Icons.bar_chart,
                            color: Colors.orange,
                            onTap: () => context.go('/client/reports'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // Pending CA Templates with Animation
              FadeInUp(
                delay: const Duration(milliseconds: 600),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pending CA-Created Templates',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[800],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Semantics(
                      label: 'Pending templates list',
                      child: pendingTemplatesAsync.when(
                        data: (templates) =>
                            _buildPendingTemplatesList(templates),
                        loading: () => _buildLoadingTemplates(),
                        error: (error, stack) =>
                            _buildErrorWidget('Failed to load templates'),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Recent Activity with Animation
              FadeInUp(
                delay: const Duration(milliseconds: 800),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Recent Review Activity',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[800],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Semantics(
                      label: 'Recent activity list',
                      child: recentActivitiesAsync.when(
                        data: (activities) => _buildRecentActivity(activities),
                        loading: () => _buildLoadingActivity(),
                        error: (error, stack) =>
                            _buildErrorWidget('Failed to load activities'),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCards(Map<String, int> stats) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                title: 'Pending Templates',
                value: '${stats['pending'] ?? 0}',
                icon: Icons.pending_actions,
                color: Colors.orange,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildStatCard(
                title: 'Approved This Month',
                value: '${stats['approvedThisMonth'] ?? 0}',
                icon: Icons.check_circle,
                color: Colors.green,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                title: 'Rejected Templates',
                value: '${stats['rejected'] ?? 0}',
                icon: Icons.cancel,
                color: Colors.red,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildStatCard(
                title: 'Total Reviewed',
                value: '${stats['total'] ?? 0}',
                icon: Icons.analytics,
                color: Colors.blue,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLoadingStats() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _buildLoadingCard()),
            const SizedBox(width: 16),
            Expanded(child: _buildLoadingCard()),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: _buildLoadingCard()),
            const SizedBox(width: 16),
            Expanded(child: _buildLoadingCard()),
          ],
        ),
      ],
    );
  }

  Widget _buildLoadingCard() {
    return Container(
      height: 100,
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusM),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            offset: const Offset(0, 2),
            blurRadius: 8,
          ),
        ],
      ),
      child: const Center(
        child: CircularProgressIndicator(),
      ),
    );
  }

  Widget _buildErrorStats() {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusM),
        border: Border.all(color: AppTheme.errorColor.withValues(alpha: 0.3)),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, color: AppTheme.errorColor, size: 32),
            const SizedBox(height: 8),
            Text(
              'Failed to load statistics',
              style: AppTheme.bodyMedium.copyWith(color: AppTheme.errorColor),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => ref.invalidate(clientDashboardStatsProvider),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16), // Reduce padding
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusM),
        border: Border.all(
          color: color.withValues(alpha: 0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            offset: const Offset(0, 2),
            blurRadius: 8,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min, // Let Column adapt to content height
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.all(8), // Reduce icon container padding
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppTheme.radiusS),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 18, // Reduce icon size
                ),
              ),
              const Spacer(),
              Flexible(
                // Use Flexible to let value text adapt
                child: Text(
                  value,
                  style: AppTheme.headlineMedium.copyWith(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 20, // Reduce font size
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8), // Reduce spacing
          Text(
            title,
            style: AppTheme.bodyMedium.copyWith(
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w500,
              fontSize: 13, // Reduce font size
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusM),
      child: Container(
        padding: const EdgeInsets.all(16), // Reduce padding
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(AppTheme.radiusM),
          border: Border.all(
            color: color.withValues(alpha: 0.2),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              offset: const Offset(0, 2),
              blurRadius: 8,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize:
              MainAxisSize.min, // Important: Let Column adapt to content height
          children: [
            Container(
              padding: const EdgeInsets.all(8), // Reduce icon container padding
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppTheme.radiusS),
              ),
              child: Icon(
                icon,
                color: color,
                size: 20, // Reduce icon size
              ),
            ),
            const SizedBox(height: 12), // Reduce spacing
            Flexible(
              // Use Flexible to let text adapt
              child: Text(
                title,
                style: AppTheme.titleSmall.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 14, // Reduce font size
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 4), // Reduce spacing
            Flexible(
              // Use Flexible to let text adapt
              child: Text(
                subtitle,
                style: AppTheme.bodySmall.copyWith(
                  color: AppTheme.textSecondary,
                  fontSize: 12, // Reduce font size
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPendingTemplatesList(List<Map<String, dynamic>> templates) {
    if (templates.isEmpty) {
      return Container(
        height: 120,
        decoration: BoxDecoration(
          color: AppTheme.backgroundLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppTheme.dividerColor.withValues(alpha: 0.5),
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.check_circle, color: AppTheme.successColor, size: 32),
              const SizedBox(height: 8),
              Text(
                'No pending templates',
                style:
                    AppTheme.bodyMedium.copyWith(color: AppTheme.textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      height: 120,
      decoration: BoxDecoration(
        color: AppTheme.backgroundLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.dividerColor.withValues(alpha: 0.5),
        ),
      ),
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: templates.length,
        itemBuilder: (context, index) {
          final template = templates[index];
          final createdAt = template['createdAt'] as Timestamp?;
          final createdBy = template['createdBy'] ?? 'Unknown CA';
          final name = template['name'] ?? 'Unnamed Template';

          return ListTile(
            leading:
                const Icon(Icons.description, color: AppTheme.primaryColor),
            title: Text(name),
            subtitle: Text(
              'Created by: $createdBy • ${_formatTimestamp(createdAt)}',
            ),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () => context.go('/client/template-review'),
          );
        },
      ),
    );
  }

  Widget _buildLoadingTemplates() {
    return Container(
      height: 120,
      decoration: BoxDecoration(
        color: AppTheme.backgroundLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.dividerColor.withValues(alpha: 0.5),
        ),
      ),
      child: const Center(
        child: CircularProgressIndicator(),
      ),
    );
  }

  Widget _buildErrorWidget(String message) {
    return Container(
      height: 120,
      decoration: BoxDecoration(
        color: AppTheme.backgroundLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.errorColor.withValues(alpha: 0.5),
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, color: AppTheme.errorColor, size: 32),
            const SizedBox(height: 8),
            Text(
              message,
              style: AppTheme.bodyMedium.copyWith(color: AppTheme.errorColor),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => ref.invalidate(pendingTemplatesProvider),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentActivity(List<Map<String, dynamic>> activities) {
    if (activities.isEmpty) {
      return Container(
        height: 200,
        decoration: BoxDecoration(
          color: AppTheme.backgroundLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppTheme.dividerColor.withValues(alpha: 0.5),
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.history, color: AppTheme.textSecondary, size: 32),
              const SizedBox(height: 8),
              Text(
                'No recent activity',
                style:
                    AppTheme.bodyMedium.copyWith(color: AppTheme.textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: AppTheme.backgroundLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.dividerColor.withValues(alpha: 0.5),
        ),
      ),
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: activities.length,
        itemBuilder: (context, index) {
          final activity = activities[index];
          final action = activity['action'] ?? 'Unknown action';
          final templateName = activity['templateName'] ?? 'Unknown template';
          final reviewedAt = activity['reviewedAt'] as Timestamp?;
          final icon = _getActionIcon(action);
          final color = _getActionColor(action);

          return ListTile(
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: color,
                size: 20,
              ),
            ),
            title: Text(
              '${_getActionDisplayText(action)} $templateName',
              style: const TextStyle(fontSize: 14),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              _formatTimestamp(reviewedAt),
              style: const TextStyle(fontSize: 12),
            ),
          );
        },
      ),
    );
  }

  Widget _buildLoadingActivity() {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: AppTheme.backgroundLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.dividerColor.withValues(alpha: 0.5),
        ),
      ),
      child: const Center(
        child: CircularProgressIndicator(),
      ),
    );
  }

  // Helper methods
  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return 'Unknown time';

    final date = timestamp.toDate();
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes} minutes ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} hours ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  IconData _getActionIcon(String action) {
    switch (action) {
      case 'approved':
        return Icons.check_circle;
      case 'rejected':
        return Icons.cancel;
      case 'needs_revision':
        return Icons.edit;
      case 'verified':
        return Icons.verified;
      default:
        return Icons.help;
    }
  }

  Color _getActionColor(String action) {
    switch (action) {
      case 'approved':
        return AppTheme.successColor;
      case 'rejected':
        return AppTheme.errorColor;
      case 'needs_revision':
        return AppTheme.warningColor;
      case 'verified':
        return AppTheme.infoColor;
      default:
        return AppTheme.textSecondary;
    }
  }

  String _getActionDisplayText(String action) {
    switch (action) {
      case 'approved':
        return 'Approved';
      case 'rejected':
        return 'Rejected';
      case 'needs_revision':
        return 'Requested revision for';
      case 'verified':
        return 'Verified authenticity of';
      default:
        return 'Reviewed';
    }
  }
}
