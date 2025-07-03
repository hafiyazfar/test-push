import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:animate_do/animate_do.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/models/user_model.dart';
import '../../../auth/providers/auth_providers.dart';
import '../../../certificates/providers/certificate_providers.dart';
import '../../services/activity_service.dart';
import '../../../support/presentation/pages/help_support_page.dart';

class DashboardHomePage extends ConsumerStatefulWidget {
  const DashboardHomePage({super.key});

  @override
  ConsumerState<DashboardHomePage> createState() => _DashboardHomePageState();
}

class _DashboardHomePageState extends ConsumerState<DashboardHomePage>
    with AutomaticKeepAliveClientMixin {
  final ActivityService _activityService = ActivityService();

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final authState = ref.watch(authStateProvider);
    final currentUser = ref.watch(currentUserProvider);

    return Scaffold(
      body: currentUser.when(
        data: (user) {
          if (user == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.person_off,
                    size: 64,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: AppTheme.spacingS),
                  const Text('No user data available'),
                  const SizedBox(height: AppTheme.spacingS),
                  Text(
                    'Firebase Auth: ${authState.value?.email ?? 'Not logged in'}',
                    style: AppTheme.bodySmall.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppTheme.spacingS),
                  Text(
                    'Please try logging out and logging back in',
                    style: AppTheme.bodySmall.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppTheme.spacingL),
                  ElevatedButton(
                    onPressed: () => context.go('/login'),
                    child: const Text('Go to Login'),
                  ),
                  const SizedBox(height: AppTheme.spacingS),
                  ElevatedButton(
                    onPressed: () {
                      ref.invalidate(currentUserProvider);
                    },
                    child: const Text('Refresh User Data'),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(currentUserProvider);
            },
            child: CustomScrollView(
              slivers: [
                _buildAppBar(user),
                SliverPadding(
                  padding: const EdgeInsets.all(AppTheme.spacingL),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      _buildWelcomeCard(user),
                      const SizedBox(height: AppTheme.spacingL),
                      _buildStatsSection(user),
                      const SizedBox(height: AppTheme.spacingL),
                      _buildQuickActions(user),
                      const SizedBox(height: AppTheme.spacingL),
                      _buildRecentActivity(user),
                      const SizedBox(height: AppTheme.spacingXXL),
                    ]),
                  ),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                size: 64,
                color: AppTheme.errorColor,
              ),
              const SizedBox(height: AppTheme.spacingM),
              Text(
                'Error loading user data',
                style: AppTheme.titleLarge.copyWith(
                  color: AppTheme.errorColor,
                ),
              ),
              const SizedBox(height: AppTheme.spacingS),
              Text(
                error.toString(),
                style: AppTheme.bodyMedium.copyWith(
                  color: AppTheme.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppTheme.spacingL),
              ElevatedButton(
                onPressed: () {
                  ref.invalidate(currentUserProvider);
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar(UserModel user) {
    return SliverAppBar(
      expandedHeight: 120,
      floating: false,
      pinned: true,
      backgroundColor: AppTheme.primaryColor,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: AppTheme.primaryGradient,
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.spacingL),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  FadeInLeft(
                    child: Text(
                      'Welcome back,',
                      style: AppTheme.bodyLarge.copyWith(
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                  ),
                  FadeInRight(
                    delay: const Duration(milliseconds: 200),
                    child: Text(
                      user.displayName,
                      style: AppTheme.headlineMedium.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
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
        IconButton(
          onPressed: () {
            // Show notifications
          },
          icon: Stack(
            children: [
              const Icon(Icons.notifications_outlined, color: Colors.white),
              Positioned(
                right: 0,
                top: 0,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: AppTheme.errorColor,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: () {
            context.go('/profile');
          },
          icon: CircleAvatar(
            radius: 16,
            backgroundColor: Colors.white.withValues(alpha: 0.2),
            child: user.photoURL != null
                ? ClipOval(
                    child: Image.network(
                      user.photoURL!,
                      width: 32,
                      height: 32,
                      fit: BoxFit.cover,
                    ),
                  )
                : Text(
                    user.displayName.isNotEmpty
                        ? user.displayName[0].toUpperCase()
                        : 'U',
                    style: AppTheme.bodyMedium.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ),
        const SizedBox(width: AppTheme.spacingS),
      ],
    );
  }

  Widget _buildWelcomeCard(UserModel user) {
    return FadeInUp(
      child: Container(
        padding: const EdgeInsets.all(AppTheme.spacingL),
        decoration: BoxDecoration(
          gradient: AppTheme.cardGradient,
          borderRadius: AppTheme.largeRadius,
          boxShadow: AppTheme.cardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppTheme.spacingS),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.1),
                    borderRadius: AppTheme.mediumRadius,
                  ),
                  child: Icon(
                    _getRoleIcon(user.role),
                    color: AppTheme.primaryColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: AppTheme.spacingM),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.roleDisplayName,
                        style: AppTheme.titleMedium.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        _getRoleDescription(user.role),
                        style: AppTheme.bodySmall.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spacingS,
                    vertical: AppTheme.spacingXS,
                  ),
                  decoration: BoxDecoration(
                    color: user.status == UserStatus.active
                        ? AppTheme.successColor.withValues(alpha: 0.1)
                        : AppTheme.warningColor.withValues(alpha: 0.1),
                    borderRadius: AppTheme.smallRadius,
                  ),
                  child: Text(
                    user.statusDisplayName,
                    style: AppTheme.bodySmall.copyWith(
                      color: user.status == UserStatus.active
                          ? AppTheme.successColor
                          : AppTheme.warningColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            if (user.lastLoginAt != null) ...[
              const SizedBox(height: AppTheme.spacingM),
              Text(
                'Last login: ${_formatDate(user.lastLoginAt!)}',
                style: AppTheme.bodySmall.copyWith(
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatsSection(UserModel user) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FadeInLeft(
          child: Text(
            'Overview',
            style: AppTheme.headlineSmall.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: AppTheme.spacingM),
        FadeInUp(
          delay: const Duration(milliseconds: 200),
          child: Consumer(
            builder: (context, ref, child) {
              final certificateStats = ref.watch(certificateStatsProvider);

              return certificateStats.when(
                data: (stats) => Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        title: 'Certificates',
                        value: stats.totalCertificates.toString(),
                        icon: Icons.description_outlined,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                    const SizedBox(width: AppTheme.spacingM),
                    Expanded(
                      child: _buildStatCard(
                        title: 'Documents',
                        value: stats.totalDocuments?.toString() ?? '0',
                        icon: Icons.folder_outlined,
                        color: AppTheme.secondaryColor,
                      ),
                    ),
                  ],
                ),
                loading: () => Row(
                  children: [
                    Expanded(
                      child: _buildLoadingStatCard(),
                    ),
                    const SizedBox(width: AppTheme.spacingM),
                    Expanded(
                      child: _buildLoadingStatCard(),
                    ),
                  ],
                ),
                error: (error, stack) => Row(
                  children: [
                    Expanded(
                      child: _buildErrorStatCard('Error'),
                    ),
                    const SizedBox(width: AppTheme.spacingM),
                    Expanded(
                      child: _buildErrorStatCard('Error'),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: AppTheme.spacingM),
        FadeInUp(
          delay: const Duration(milliseconds: 400),
          child: Consumer(
            builder: (context, ref, child) {
              final certificateStats = ref.watch(certificateStatsProvider);

              return certificateStats.when(
                data: (stats) => Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        title:
                            (user.isCA || user.isAdmin) ? 'Issued' : 'Shared',
                        value: (user.isCA || user.isAdmin)
                            ? stats.issuedCertificates.toString()
                            : stats.sharedCertificates.toString(),
                        icon: (user.isCA || user.isAdmin)
                            ? Icons.verified_outlined
                            : Icons.share_outlined,
                        color: AppTheme.infoColor,
                      ),
                    ),
                    const SizedBox(width: AppTheme.spacingM),
                    Expanded(
                      child: _buildStatCard(
                        title: 'Pending',
                        value: stats.pendingCertificates.toString(),
                        icon: Icons.pending_outlined,
                        color: AppTheme.warningColor,
                      ),
                    ),
                  ],
                ),
                loading: () => Row(
                  children: [
                    Expanded(
                      child: _buildLoadingStatCard(),
                    ),
                    const SizedBox(width: AppTheme.spacingM),
                    Expanded(
                      child: _buildLoadingStatCard(),
                    ),
                  ],
                ),
                error: (error, stack) => Row(
                  children: [
                    Expanded(
                      child: _buildErrorStatCard('Error'),
                    ),
                    const SizedBox(width: AppTheme.spacingM),
                    Expanded(
                      child: _buildErrorStatCard('Error'),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingL),
      decoration: BoxDecoration(
        color: AppTheme.backgroundLight,
        borderRadius: AppTheme.mediumRadius,
        border: Border.all(color: AppTheme.dividerColor.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            offset: const Offset(0, 2),
            blurRadius: 4,
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: AppTheme.mediumRadius,
            ),
            child: Icon(
              icon,
              color: color,
              size: 24,
            ),
          ),
          const SizedBox(height: AppTheme.spacingM),
          Text(
            value,
            style: AppTheme.headlineMedium.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: AppTheme.spacingXS),
          Text(
            title,
            style: AppTheme.bodySmall.copyWith(
              color: AppTheme.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(UserModel user) {
    final actions = _getQuickActions(user);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FadeInLeft(
          child: Text(
            'Quick Actions',
            style: AppTheme.headlineSmall.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: AppTheme.spacingM),
        FadeInUp(
          delay: const Duration(milliseconds: 200),
          child: Wrap(
            spacing: AppTheme.spacingM,
            runSpacing: AppTheme.spacingM,
            children:
                actions.map((action) => _buildActionCard(action)).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildActionCard(QuickAction action) {
    return SizedBox(
      width: (MediaQuery.of(context).size.width - AppTheme.spacingL * 3) / 2,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: action.onTap,
          borderRadius: AppTheme.mediumRadius,
          child: Container(
            constraints:
                const BoxConstraints(minHeight: 120), // Fixed minimum height
            padding: const EdgeInsets.all(AppTheme.spacingM), // Reduced padding
            decoration: BoxDecoration(
              color: action.color.withValues(alpha: 0.1),
              borderRadius: AppTheme.mediumRadius,
              border: Border.all(
                color: action.color.withValues(alpha: 0.2),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min, // Prevent overflow
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  action.icon,
                  color: action.color,
                  size: 28, // Slightly smaller icon
                ),
                const SizedBox(height: AppTheme.spacingS),
                Flexible(
                  // Wrap text in Flexible
                  child: Text(
                    action.title,
                    style: AppTheme.titleSmall.copyWith(
                      // Smaller title style
                      fontWeight: FontWeight.w600,
                      color: action.color,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: AppTheme.spacingXS),
                Flexible(
                  // Wrap subtitle in Flexible
                  child: Text(
                    action.subtitle,
                    style: AppTheme.bodySmall.copyWith(
                      color: AppTheme.textSecondary,
                      fontSize: 11, // Smaller font size
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRecentActivity(UserModel user) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FadeInLeft(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent Activity',
                style: AppTheme.headlineSmall.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextButton(
                onPressed: () {
                  // Navigate to full activity log
                },
                child: const Text('View All'),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppTheme.spacingM),
        FadeInUp(
          delay: const Duration(milliseconds: 200),
          child: Consumer(
            builder: (context, ref, child) {
              return FutureBuilder<List<Map<String, dynamic>>>(
                future: _activityService.getRecentActivities(limit: 3),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Container(
                      height: 200,
                      decoration: BoxDecoration(
                        color: AppTheme.backgroundLight,
                        borderRadius: AppTheme.mediumRadius,
                        border: Border.all(
                            color:
                                AppTheme.dividerColor.withValues(alpha: 0.5)),
                      ),
                      child: const Center(
                        child: CircularProgressIndicator(),
                      ),
                    );
                  }

                  if (snapshot.hasError) {
                    return Container(
                      height: 200,
                      decoration: BoxDecoration(
                        color: AppTheme.backgroundLight,
                        borderRadius: AppTheme.mediumRadius,
                        border: Border.all(
                            color:
                                AppTheme.dividerColor.withValues(alpha: 0.5)),
                      ),
                      child: const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.error_outline,
                                color: AppTheme.errorColor),
                            SizedBox(height: 8),
                            Text('Failed to load activities'),
                          ],
                        ),
                      ),
                    );
                  }

                  final activities = snapshot.data ?? [];

                  if (activities.isEmpty) {
                    return Container(
                      decoration: BoxDecoration(
                        color: AppTheme.backgroundLight,
                        borderRadius: AppTheme.mediumRadius,
                        border: Border.all(
                            color:
                                AppTheme.dividerColor.withValues(alpha: 0.5)),
                      ),
                      child: const Padding(
                        padding: EdgeInsets.all(AppTheme.spacingL),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(Icons.hourglass_empty,
                                  color: AppTheme.textSecondary, size: 32),
                              SizedBox(height: AppTheme.spacingS),
                              Text(
                                'No recent activity',
                                style: TextStyle(color: AppTheme.textSecondary),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }

                  return Container(
                    decoration: BoxDecoration(
                      color: AppTheme.backgroundLight,
                      borderRadius: AppTheme.mediumRadius,
                      border: Border.all(
                          color: AppTheme.dividerColor.withValues(alpha: 0.5)),
                    ),
                    child: Column(
                      children: activities.asMap().entries.map((entry) {
                        final index = entry.key;
                        final activity = entry.value;

                        return Column(
                          children: [
                            _buildActivityItemFromData(activity),
                            if (index < activities.length - 1)
                              const Divider(height: 1),
                          ],
                        );
                      }).toList(),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildActivityItemFromData(Map<String, dynamic> activity) {
    // Extract activity information
    final action = activity['action'] ?? 'Unknown Action';
    final details = activity['details'] ?? 'No details available';
    final timestamp = activity['createdAt'];

    // Determine icon and color based on action type
    IconData icon;
    Color color;
    String title;

    if (action.contains('certificate')) {
      if (action.contains('issued') || action.contains('created')) {
        icon = Icons.verified_outlined;
        color = AppTheme.successColor;
        title = 'Certificate Issued';
      } else if (action.contains('approved')) {
        icon = Icons.check_circle_outlined;
        color = AppTheme.primaryColor;
        title = 'Certificate Approved';
      } else if (action.contains('downloaded')) {
        icon = Icons.download_outlined;
        color = AppTheme.infoColor;
        title = 'Certificate Downloaded';
      } else {
        icon = Icons.description_outlined;
        color = AppTheme.primaryColor;
        title = 'Certificate Updated';
      }
    } else if (action.contains('document')) {
      if (action.contains('uploaded')) {
        icon = Icons.upload_outlined;
        color = AppTheme.infoColor;
        title = 'Document Uploaded';
      } else if (action.contains('verified')) {
        icon = Icons.verified_user_outlined;
        color = AppTheme.successColor;
        title = 'Document Verified';
      } else if (action.contains('downloaded')) {
        icon = Icons.download_outlined;
        color = AppTheme.secondaryColor;
        title = 'Document Downloaded';
      } else {
        icon = Icons.folder_outlined;
        color = AppTheme.secondaryColor;
        title = 'Document Updated';
      }
    } else if (action.contains('user')) {
      icon = Icons.person_outlined;
      color = AppTheme.warningColor;
      title = 'User Activity';
    } else {
      icon = Icons.info_outlined;
      color = AppTheme.textSecondary;
      title = 'System Activity';
    }

    // Format timestamp
    String timeStr = 'Unknown time';
    if (timestamp != null) {
      try {
        DateTime activityTime;
        if (timestamp is DateTime) {
          activityTime = timestamp;
        } else if (timestamp is String) {
          activityTime = DateTime.parse(timestamp);
        } else {
          activityTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
        }
        timeStr = _formatDate(activityTime);
      } catch (e) {
        timeStr = 'Recently';
      }
    }

    return Padding(
      padding: const EdgeInsets.all(AppTheme.spacingM),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: AppTheme.mediumRadius,
            ),
            child: Icon(
              icon,
              color: color,
              size: 20,
            ),
          ),
          const SizedBox(width: AppTheme.spacingM),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTheme.bodyMedium.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  details,
                  style: AppTheme.bodySmall.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Text(
            timeStr,
            style: AppTheme.bodySmall.copyWith(
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  List<QuickAction> _getQuickActions(UserModel user) {
    switch (user.role) {
      case UserRole.systemAdmin:
        return [
          QuickAction(
            icon: Icons.group_add_outlined,
            title: 'Manage Users',
            subtitle: 'Add or edit users',
            color: AppTheme.primaryColor,
            onTap: () => context.go('/admin/users'),
          ),
          QuickAction(
            icon: Icons.add_circle_outline,
            title: 'New Certificate',
            subtitle: 'Create certificate',
            color: AppTheme.secondaryColor,
            onTap: () => context.go('/certificates/create'),
          ),
          QuickAction(
            icon: Icons.analytics_outlined,
            title: 'System Reports',
            subtitle: 'View analytics',
            color: AppTheme.infoColor,
            onTap: () => context.go('/admin'),
          ),
          QuickAction(
            icon: Icons.settings_outlined,
            title: 'Settings',
            subtitle: 'System config',
            color: AppTheme.warningColor,
            onTap: () => context.go('/admin/settings'),
          ),
        ];

      case UserRole.certificateAuthority:
        return [
          QuickAction(
            icon: Icons.add_circle_outline,
            title: 'Issue Certificate',
            subtitle: 'Create new certificate',
            color: AppTheme.primaryColor,
            onTap: () => context.go('/certificates/create'),
          ),
          QuickAction(
            icon: Icons.pending_actions_outlined,
            title: 'Pending Approvals',
            subtitle: 'Review requests',
            color: AppTheme.warningColor,
            onTap: () => context.go('/admin'),
          ),
          QuickAction(
            icon: Icons.verified_user_outlined,
            title: 'Verify Documents',
            subtitle: 'Document verification',
            color: AppTheme.successColor,
            onTap: () => context.go('/documents'),
          ),
          QuickAction(
            icon: Icons.history_outlined,
            title: 'Issue History',
            subtitle: 'View past issuances',
            color: AppTheme.infoColor,
            onTap: () => context.go('/certificates'),
          ),
        ];

      default:
        return [
          QuickAction(
            icon: Icons.upload_outlined,
            title: 'Upload Document',
            subtitle: 'Add new document',
            color: AppTheme.primaryColor,
            onTap: () => context.go('/documents/upload'),
          ),
          QuickAction(
            icon: Icons.share_outlined,
            title: 'Share Certificate',
            subtitle: 'Generate share link',
            color: AppTheme.secondaryColor,
            onTap: () => context.go('/certificates'),
          ),
          QuickAction(
            icon: Icons.download_outlined,
            title: 'Download',
            subtitle: 'Export documents',
            color: AppTheme.infoColor,
            onTap: () => context.go('/certificates'),
          ),
          QuickAction(
            icon: Icons.support_outlined,
            title: 'Help & Support',
            subtitle: 'Get assistance',
            color: AppTheme.warningColor,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const HelpSupportPage(),
                ),
              );
            },
          ),
        ];
    }
  }

  IconData _getRoleIcon(UserRole role) {
    switch (role) {
      case UserRole.systemAdmin:
        return Icons.admin_panel_settings_outlined;
      case UserRole.certificateAuthority:
        return Icons.verified_user_outlined;
      case UserRole.client:
        return Icons.business_outlined;
      case UserRole.recipient:
        return Icons.person_outline;
      case UserRole.viewer:
        return Icons.visibility_outlined;
    }
  }

  String _getRoleDescription(UserRole role) {
    switch (role) {
      case UserRole.systemAdmin:
        return 'Full system access and management';
      case UserRole.certificateAuthority:
        return 'Issue and manage digital certificates';
      case UserRole.client:
        return 'Request and approve certificates';
      case UserRole.recipient:
        return 'Receive and manage certificates';
      case UserRole.viewer:
        return 'View shared certificates';
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

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

  Widget _buildLoadingStatCard() {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingL),
      decoration: BoxDecoration(
        color: AppTheme.backgroundLight,
        borderRadius: AppTheme.mediumRadius,
        border: Border.all(color: AppTheme.dividerColor.withValues(alpha: 0.5)),
      ),
      child: const Column(
        children: [
          CircularProgressIndicator(),
          SizedBox(height: AppTheme.spacingM),
          Text('Loading...'),
        ],
      ),
    );
  }

  Widget _buildErrorStatCard(String message) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingL),
      decoration: BoxDecoration(
        color: AppTheme.backgroundLight,
        borderRadius: AppTheme.mediumRadius,
        border: Border.all(color: AppTheme.errorColor.withValues(alpha: 0.5)),
      ),
      child: Column(
        children: [
          const Icon(Icons.error, color: AppTheme.errorColor),
          const SizedBox(height: AppTheme.spacingS),
          Text(message, style: const TextStyle(color: AppTheme.errorColor)),
        ],
      ),
    );
  }
}

class QuickAction {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const QuickAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });
}
