import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:animate_do/animate_do.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/models/user_model.dart';
import '../../../auth/providers/auth_providers.dart';
import '../../providers/ca_providers.dart';
import '../../../../core/services/logger_service.dart';

// 实时活动提供者 - 修复获取模板创建活动，使用正确的ca_activities集合
final caRecentActivitiesProvider =
    StreamProvider<List<Map<String, dynamic>>>((ref) {
  final currentUser = ref.watch(currentUserProvider).value;
  if (currentUser == null || (!currentUser.isCA && !currentUser.isAdmin)) {
    return Stream.value([]);
  }

  // Use simpler query to avoid composite index requirement
  // Filter and sort on client side for now
  return FirebaseFirestore.instance
      .collection('ca_activities')
      .where('caId', isEqualTo: currentUser.id)
      .limit(20) // Get more records and filter client-side
      .snapshots()
      .map((snapshot) {
    final activities = snapshot.docs
        .map((doc) => {
              'id': doc.id,
              ...doc.data(),
            })
        .toList();

    // Sort by timestamp on client side
    activities.sort((a, b) {
      final timestampA = a['timestamp'];
      final timestampB = b['timestamp'];

      if (timestampA == null && timestampB == null) return 0;
      if (timestampA == null) return 1;
      if (timestampB == null) return -1;

      try {
        DateTime dateA;
        DateTime dateB;

        if (timestampA is Timestamp) {
          dateA = timestampA.toDate();
        } else if (timestampA is String) {
          dateA = DateTime.parse(timestampA);
        } else {
          return 1;
        }

        if (timestampB is Timestamp) {
          dateB = timestampB.toDate();
        } else if (timestampB is String) {
          dateB = DateTime.parse(timestampB);
        } else {
          return -1;
        }

        return dateB.compareTo(dateA); // Descending order
      } catch (e) {
        return 0;
      }
    });

    // Return only the latest 5 activities
    return activities.take(5).toList();
  });
});

// 实时待处理文档提供者
final caPendingDocumentsProvider =
    StreamProvider<List<Map<String, dynamic>>>((ref) {
  return FirebaseFirestore.instance
      .collection('documents')
      .where('status', isEqualTo: 'pending') // 🔄 修正状态匹配
      .orderBy('uploadedAt', descending: true)
      .limit(5)
      .snapshots()
      .map((snapshot) => snapshot.docs
          .map((doc) => {
                'id': doc.id,
                ...doc.data(),
              })
          .toList());
});

class CADashboard extends ConsumerStatefulWidget {
  const CADashboard({super.key});

  @override
  ConsumerState<CADashboard> createState() => _CADashboardState();
}

class _CADashboardState extends ConsumerState<CADashboard>
    with TickerProviderStateMixin {
  late AnimationController _refreshAnimationController;

  @override
  void initState() {
    super.initState();
    _refreshAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    // Load CA statistics when dashboard loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(caStatsProvider.notifier).loadStats();
    });
  }

  @override
  void dispose() {
    _refreshAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserProvider);
    final caStats = ref.watch(caStatsProvider);

    return currentUser.when(
      data: (user) {
        if (user == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            context.go('/login');
          });
          return Scaffold(
            backgroundColor: AppTheme.backgroundColor,
            body: Center(
              child: Semantics(
                label: 'Loading user information',
                child: const CircularProgressIndicator(),
              ),
            ),
          );
        }

        // 🚀 重要：只在真正访问CA页面时才检查CA相关权限和状态
        final currentLocation =
            GoRouter.of(context).routerDelegate.currentConfiguration.uri.path;
        final isAccessingCAPages = currentLocation.startsWith('/ca/');

        if (kDebugMode) {
          LoggerService.debug(
              'CA Dashboard build - currentLocation: $currentLocation, isAccessingCAPages: $isAccessingCAPages');
        }

        // Check if user has CA access (only when accessing CA pages)
        if (isAccessingCAPages && !user.isCA && !user.isAdmin) {
          return _buildUnauthorizedPage();
        }

        // Check if CA status is approved (only when accessing CA pages)
        if (isAccessingCAPages &&
            user.isCA &&
            user.status != UserStatus.active) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (user.status == UserStatus.pending) {
              context.go('/pending');
            } else {
              // For suspended or other statuses, redirect to login
              context.go('/login');
            }
          });
          return Scaffold(
            backgroundColor: AppTheme.backgroundColor,
            body: Center(
              child: Semantics(
                label: 'Redirecting to appropriate page',
                child: const CircularProgressIndicator(),
              ),
            ),
          );
        }

        return _buildCADashboard(user, caStats);
      },
      loading: () => Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        body: Center(
          child: Semantics(
            label: 'Loading CA Dashboard',
            child: const CircularProgressIndicator(),
          ),
        ),
      ),
      error: (error, stack) => _buildErrorPage(error.toString()),
    );
  }

  Widget _buildCADashboard(UserModel user, AsyncValue<CAStats> caStats) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            _refreshAnimationController.forward().then((_) {
              _refreshAnimationController.reset();
            });

            await ref.read(caStatsProvider.notifier).loadStats();
            ref.invalidate(caRecentActivitiesProvider);
            ref.invalidate(caPendingDocumentsProvider);
          },
          child: CustomScrollView(
            semanticChildCount:
                4, // Accessibility: Total semantic children count
            slivers: [
              // App Bar
              SliverAppBar(
                expandedHeight: 200,
                floating: false,
                pinned: true,
                backgroundColor: AppTheme.primaryColor,
                flexibleSpace: FlexibleSpaceBar(
                  title: Semantics(
                    header: true,
                    child: Text(
                      'CA Certificate Creation Center',
                      style: AppTheme.textTheme.titleLarge?.copyWith(
                        color: AppTheme.textOnPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  background: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          AppTheme.primaryColor,
                          AppTheme.primaryColor.withValues(alpha: 0.8),
                        ],
                      ),
                    ),
                    child: Center(
                      child: Semantics(
                        label: 'Welcome ${user.displayName}, CA Dashboard',
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(height: 40),
                            BounceInDown(
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(50),
                                ),
                                child: const Icon(
                                  Icons.verified_user,
                                  size: 40,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            FadeInUp(
                              delay: const Duration(milliseconds: 300),
                              child: Text(
                                'Welcome, ${user.displayName}',
                                style: AppTheme.textTheme.titleMedium?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                actions: [
                  RotationTransition(
                    turns: _refreshAnimationController,
                    child: IconButton(
                      icon: const Icon(Icons.refresh),
                      tooltip: 'Refresh dashboard data',
                      onPressed: () async {
                        _refreshAnimationController.forward().then((_) {
                          _refreshAnimationController.reset();
                        });

                        await ref.read(caStatsProvider.notifier).loadStats();
                        ref.invalidate(caRecentActivitiesProvider);
                        ref.invalidate(caPendingDocumentsProvider);
                      },
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.settings),
                    tooltip: 'CA Settings',
                    onPressed: () => context.go('/ca/settings'),
                  ),
                ],
              ),

              // Statistics Cards
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Semantics(
                        header: true,
                        child: Text(
                          'System Statistics',
                          style: AppTheme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      caStats.when(
                        data: (stats) => _buildStatsCards(stats),
                        loading: () => _buildLoadingStatsCards(),
                        error: (error, stack) => _buildErrorStatsCards(),
                      ),
                    ],
                  ),
                ),
              ),

              // Quick Actions
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: _buildQuickActions(),
                ),
              ),

              // Recent Activities & Pending Documents
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _buildRecentActivities()),
                      const SizedBox(width: 16),
                      Expanded(child: _buildPendingDocuments()),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatsCards(CAStats stats) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 1.5,
      children: [
        FadeInUp(
          duration: const Duration(milliseconds: 300),
          child: _buildStatCard(
            icon: Icons.description,
            title: 'Templates Created',
            value: stats.totalCertificatesIssued.toString(),
            color: AppTheme.successColor,
          ),
        ),
        FadeInUp(
          duration: const Duration(milliseconds: 400),
          child: _buildStatCard(
            icon: Icons.pending_actions,
            title: 'Pending Documents',
            value: stats.pendingDocuments.toString(),
            color: AppTheme.warningColor,
          ),
        ),
        FadeInUp(
          duration: const Duration(milliseconds: 500),
          child: _buildStatCard(
            icon: Icons.rate_review,
            title: 'Under Client Review',
            value: stats.totalDocuments.toString(),
            color: AppTheme.infoColor,
          ),
        ),
        FadeInUp(
          duration: const Duration(milliseconds: 600),
          child: _buildStatCard(
            icon: Icons.check_circle,
            title: 'Approved This Month',
            value: stats.activeUsers.toString(),
            color: AppTheme.primaryColor,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Semantics(
      label: '$title: $value',
      child: Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, color: color, size: 24),
                  ),
                  const Spacer(),
                  Text(
                    value,
                    style: AppTheme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: AppTheme.textTheme.bodyMedium?.copyWith(
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingStatsCards() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 1.5,
      children: List.generate(
        4,
        (index) => Card(
          child: Container(
            padding: const EdgeInsets.all(16),
            child: const Center(child: CircularProgressIndicator()),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorStatsCards() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Icon(Icons.error_outline,
                size: 48, color: AppTheme.errorColor),
            const SizedBox(height: 16),
            Text(
              'Failed to load statistics',
              style: AppTheme.textTheme.bodyLarge
                  ?.copyWith(color: AppTheme.errorColor),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () => ref.read(caStatsProvider.notifier).loadStats(),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    return _buildQuickActionsSection();
  }

  Widget _buildRecentActivities() {
    return _buildRecentActivitySection();
  }

  Widget _buildPendingDocuments() {
    return _buildPendingDocumentsSection();
  }

  Widget _buildQuickActionsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: AppTheme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 2,
          children: [
            FadeInUp(
              duration: const Duration(milliseconds: 700),
              child: _buildActionCard(
                icon: Icons.folder_open,
                title: 'Review Documents',
                subtitle: 'Review student uploaded documents',
                onTap: () => context.go('/ca/document-review'),
              ),
            ),
            FadeInUp(
              duration: const Duration(milliseconds: 800),
              child: _buildActionCard(
                icon: Icons.create,
                title: 'Create Templates',
                subtitle: 'Create certificate templates',
                onTap: () => context.go('/ca/template-creation'),
              ),
            ),
            FadeInUp(
              duration: const Duration(milliseconds: 900),
              child: _buildActionCard(
                icon: Icons.send,
                title: 'Submit for Review',
                subtitle: 'Send templates to Client approval',
                onTap: () => context.go('/ca/template-submission'),
              ),
            ),
            FadeInUp(
              duration: const Duration(milliseconds: 1000),
              child: _buildActionCard(
                icon: Icons.analytics,
                title: 'Creation Reports',
                subtitle: 'View template creation statistics',
                onTap: () => context.go('/ca/reports'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Semantics(
      button: true,
      label: '$title: $subtitle',
      child: Card(
        elevation: 2,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    size: 32,
                    color: AppTheme.primaryColor,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        title,
                        style: AppTheme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: AppTheme.textTheme.bodySmall?.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: AppTheme.textSecondary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 真实的Firebase活动数据
  Widget _buildRecentActivitySection() {
    final activitiesAsync = ref.watch(caRecentActivitiesProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Recent Template Creation Activity',
              style: AppTheme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            TextButton(
              onPressed: () => context.go('/ca/activity'),
              child: const Text('View All'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        activitiesAsync.when(
          data: (activities) => _buildActivitiesList(activities),
          loading: () => _buildLoadingActivities(),
          error: (error, stack) => _buildErrorActivities(),
        ),
      ],
    );
  }

  Widget _buildActivitiesList(List<Map<String, dynamic>> activities) {
    if (activities.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Icon(
                Icons.timeline,
                size: 48,
                color: AppTheme.textSecondary,
              ),
              const SizedBox(height: 16),
              Text(
                'No Recent Activities',
                style: AppTheme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Start creating templates to see your activity history here.',
                style: AppTheme.textTheme.bodyMedium?.copyWith(
                  color: AppTheme.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: activities.length,
        separatorBuilder: (context, index) => const Divider(),
        itemBuilder: (context, index) {
          final activity = activities[index];
          final timestamp = _parseTimestamp(activity['timestamp']);
          final description =
              activity['description'] as String? ?? 'Unknown activity';
          final action = activity['action'] as String? ??
              'general'; // Fixed: activityType -> action

          return ListTile(
            leading: CircleAvatar(
              backgroundColor: _getActivityColor(action).withValues(alpha: 0.1),
              child: Icon(
                _getActivityIcon(action),
                color: _getActivityColor(action),
              ),
            ),
            title: Text(description),
            subtitle: Text(
              timestamp != null ? _formatTimestamp(timestamp) : 'Unknown time',
              style: AppTheme.textTheme.bodySmall?.copyWith(
                color: AppTheme.textSecondary,
              ),
            ),
            trailing: const Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: AppTheme.textSecondary,
            ),
          );
        },
      ),
    );
  }

  Widget _buildLoadingActivities() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: List.generate(
            3,
            (index) => const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  CircleAvatar(child: CircularProgressIndicator()),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(height: 16, child: LinearProgressIndicator()),
                        SizedBox(height: 8),
                        SizedBox(height: 12, child: LinearProgressIndicator()),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorActivities() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Icon(Icons.error_outline,
                size: 48, color: AppTheme.errorColor),
            const SizedBox(height: 16),
            Text(
              'Failed to load activities',
              style: AppTheme.textTheme.bodyLarge
                  ?.copyWith(color: AppTheme.errorColor),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => ref.invalidate(caRecentActivitiesProvider),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  // 真实的Firebase待处理文档数据
  Widget _buildPendingDocumentsSection() {
    final documentsAsync = ref.watch(caPendingDocumentsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Pending Document Reviews',
              style: AppTheme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            TextButton(
              onPressed: () => context.go('/ca/document-review'),
              child: const Text('View All'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        documentsAsync.when(
          data: (documents) => _buildDocumentsList(documents),
          loading: () => _buildLoadingDocuments(),
          error: (error, stack) => _buildErrorDocuments(),
        ),
      ],
    );
  }

  Widget _buildDocumentsList(List<Map<String, dynamic>> documents) {
    if (documents.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Icon(
                Icons.inbox,
                size: 48,
                color: AppTheme.textSecondary,
              ),
              const SizedBox(height: 16),
              Text(
                'No Pending Documents',
                style: AppTheme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'All documents have been reviewed.',
                style: AppTheme.textTheme.bodyMedium?.copyWith(
                  color: AppTheme.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: documents.take(5).length,
        separatorBuilder: (context, index) => const Divider(),
        itemBuilder: (context, index) {
          final document = documents[index];
          final fileName =
              document['fileName'] as String? ?? 'Unknown Document';
          final uploaderName =
              document['uploaderName'] as String? ?? 'Unknown User';
          final uploadDate = (document['uploadedAt'] as Timestamp?)?.toDate();

          return ListTile(
            leading: CircleAvatar(
              backgroundColor: AppTheme.warningColor.withValues(alpha: 0.1),
              child: Icon(
                Icons.description,
                color: AppTheme.warningColor,
              ),
            ),
            title: Text(
              fileName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              'Uploaded by $uploaderName${uploadDate != null ? ' • ${_formatTimestamp(uploadDate)}' : ''}',
              style: AppTheme.textTheme.bodySmall?.copyWith(
                color: AppTheme.textSecondary,
              ),
            ),
            trailing: const Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: AppTheme.textSecondary,
            ),
            onTap: () => context.go('/ca/document-review'),
          );
        },
      ),
    );
  }

  Widget _buildLoadingDocuments() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: List.generate(
            3,
            (index) => const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  CircleAvatar(child: CircularProgressIndicator()),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(height: 16, child: LinearProgressIndicator()),
                        SizedBox(height: 8),
                        SizedBox(height: 12, child: LinearProgressIndicator()),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorDocuments() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Icon(Icons.error_outline,
                size: 48, color: AppTheme.errorColor),
            const SizedBox(height: 16),
            Text(
              'Failed to load documents',
              style: AppTheme.textTheme.bodyLarge
                  ?.copyWith(color: AppTheme.errorColor),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => ref.invalidate(caPendingDocumentsProvider),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  // Helper methods
  Color _getActivityColor(String type) {
    switch (type.toLowerCase()) {
      case 'template_created':
        return AppTheme.successColor;
      case 'template_submitted':
        return AppTheme.primaryColor;
      case 'template_approved':
        return AppTheme.infoColor;
      case 'template_rejected':
        return AppTheme.errorColor;
      case 'document_reviewed':
        return AppTheme.warningColor;
      default:
        return AppTheme.textSecondary;
    }
  }

  IconData _getActivityIcon(String type) {
    switch (type.toLowerCase()) {
      case 'template_created':
        return Icons.create;
      case 'template_submitted':
        return Icons.send;
      case 'template_approved':
        return Icons.check_circle;
      case 'template_rejected':
        return Icons.cancel;
      case 'document_reviewed':
        return Icons.rate_review;
      default:
        return Icons.timeline;
    }
  }

  /// Safely parse timestamp from various formats
  DateTime? _parseTimestamp(dynamic timestampValue) {
    if (timestampValue == null) return null;

    try {
      if (timestampValue is Timestamp) {
        return timestampValue.toDate();
      } else if (timestampValue is String) {
        return DateTime.parse(timestampValue);
      } else if (timestampValue is int) {
        return DateTime.fromMillisecondsSinceEpoch(timestampValue);
      }
    } catch (e) {
      LoggerService.error('Failed to parse timestamp: $timestampValue',
          error: e);
    }
    return null;
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''} ago';
    } else {
      return 'Just now';
    }
  }

  Widget _buildUnauthorizedPage() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Unauthorized'),
        backgroundColor: AppTheme.errorColor,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.lock,
              size: 64,
              color: AppTheme.errorColor,
            ),
            const SizedBox(height: 16),
            Text(
              'Unauthorized Access',
              style: AppTheme.textTheme.headlineMedium?.copyWith(
                color: AppTheme.errorColor,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'You do not have permission to access the CA system.',
              style: AppTheme.textTheme.bodyLarge?.copyWith(
                color: AppTheme.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => context.go('/dashboard'),
              child: const Text('Go to Dashboard'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorPage(String error) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Error'),
        backgroundColor: AppTheme.errorColor,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: AppTheme.errorColor,
            ),
            const SizedBox(height: 16),
            Text(
              'Something went wrong',
              style: AppTheme.textTheme.headlineMedium?.copyWith(
                color: AppTheme.errorColor,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              style: AppTheme.textTheme.bodyMedium?.copyWith(
                color: AppTheme.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => context.go('/dashboard'),
              child: const Text('Go to Dashboard'),
            ),
          ],
        ),
      ),
    );
  }
}

// CA Statistics Data Model
class CAStats {
  final int totalCertificatesIssued;
  final int pendingDocuments;
  final int totalDocuments;
  final int activeUsers;

  const CAStats({
    required this.totalCertificatesIssued,
    required this.pendingDocuments,
    required this.totalDocuments,
    required this.activeUsers,
  });
}
