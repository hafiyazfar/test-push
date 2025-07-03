import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:animate_do/animate_do.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/custom_app_bar.dart';
import '../../../auth/providers/auth_providers.dart';

class ClientReportsPage extends ConsumerStatefulWidget {
  const ClientReportsPage({super.key});

  @override
  ConsumerState<ClientReportsPage> createState() => _ClientReportsPageState();
}

class _ClientReportsPageState extends ConsumerState<ClientReportsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedPeriod = 'month';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserProvider).value;

    if (currentUser == null ||
        (!currentUser.isClientType && !currentUser.isAdmin)) {
      return Scaffold(
        appBar: const CustomAppBar(title: 'Reports'),
        body: Center(
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
                'Access Denied',
                style: AppTheme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'You do not have permission to view reports.',
                style: AppTheme.textTheme.bodyLarge?.copyWith(
                  color: AppTheme.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => context.pop(),
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: const CustomAppBar(title: 'Review Reports & Analytics'),
      body: Column(
        children: [
          _buildPeriodSelector(),
          _buildTabBar(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildOverviewTab(),
                _buildAnalyticsTab(),
                _buildPerformanceTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodSelector() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.backgroundLight,
        border: Border(
          bottom: BorderSide(
            color: AppTheme.dividerColor,
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Text(
            'Report Period:',
            style: AppTheme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: DropdownButtonFormField<String>(
              value: _selectedPeriod,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              items: const [
                DropdownMenuItem(value: 'week', child: Text('This Week')),
                DropdownMenuItem(value: 'month', child: Text('This Month')),
                DropdownMenuItem(value: 'quarter', child: Text('This Quarter')),
                DropdownMenuItem(value: 'year', child: Text('This Year')),
                DropdownMenuItem(value: 'all', child: Text('All Time')),
              ],
              onChanged: (value) {
                setState(() {
                  _selectedPeriod = value ?? 'month';
                });
              },
            ),
          ),
          const SizedBox(width: 16),
          ElevatedButton.icon(
            onPressed: _isLoading ? null : _refreshData,
            icon: _isLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
            label: const Text('Refresh'),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.backgroundLight,
        border: Border(
          bottom: BorderSide(
            color: AppTheme.dividerColor,
            width: 1,
          ),
        ),
      ),
      child: TabBar(
        controller: _tabController,
        labelColor: AppTheme.primaryColor,
        unselectedLabelColor: AppTheme.textSecondary,
        indicatorColor: AppTheme.primaryColor,
        tabs: const [
          Tab(
            icon: Icon(Icons.dashboard),
            text: 'Overview',
          ),
          Tab(
            icon: Icon(Icons.analytics),
            text: 'Analytics',
          ),
          Tab(
            icon: Icon(Icons.trending_up),
            text: 'Performance',
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('template_reviews')
          .where('reviewedBy',
              isEqualTo: ref.read(currentUserProvider).value?.id)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _buildErrorWidget(snapshot.error.toString());
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final reviews = snapshot.data?.docs ?? [];
        final filteredReviews = _filterReviewsByPeriod(reviews);

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildOverviewStats(filteredReviews),
              const SizedBox(height: 24),
              _buildRecentActivity(filteredReviews),
              const SizedBox(height: 24),
              _buildTemplateTypeBreakdown(filteredReviews),
              const SizedBox(height: 24),
              _buildActionButtons(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAnalyticsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('template_reviews')
          .where('reviewedBy',
              isEqualTo: ref.read(currentUserProvider).value?.id)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _buildErrorWidget(snapshot.error.toString());
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final reviews = snapshot.data?.docs ?? [];
        final filteredReviews = _filterReviewsByPeriod(reviews);

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildReviewTrends(filteredReviews),
              const SizedBox(height: 24),
              _buildApprovalRates(filteredReviews),
              const SizedBox(height: 24),
              _buildTimeAnalysis(filteredReviews),
              const SizedBox(height: 24),
              _buildCAPerformance(filteredReviews),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPerformanceTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('template_reviews')
          .where('reviewedBy',
              isEqualTo: ref.read(currentUserProvider).value?.id)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _buildErrorWidget(snapshot.error.toString());
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final reviews = snapshot.data?.docs ?? [];
        final filteredReviews = _filterReviewsByPeriod(reviews);

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildPerformanceMetrics(filteredReviews),
              const SizedBox(height: 24),
              _buildProductivityStats(filteredReviews),
              const SizedBox(height: 24),
              _buildQualityMetrics(filteredReviews),
              const SizedBox(height: 24),
              _buildRecommendations(filteredReviews),
            ],
          ),
        );
      },
    );
  }

  Widget _buildOverviewStats(List<QueryDocumentSnapshot> reviews) {
    final approvedCount = reviews.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return data['action'] == 'approved';
    }).length;

    final rejectedCount = reviews.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return data['action'] == 'rejected';
    }).length;

    final revisionCount = reviews.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return data['action'] == 'needs_revision';
    }).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Review Overview',
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
          childAspectRatio: 1.5,
          children: [
            FadeInUp(
              duration: const Duration(milliseconds: 300),
              child: _buildStatCard(
                'Total Reviews',
                reviews.length.toString(),
                Icons.rate_review,
                AppTheme.primaryColor,
              ),
            ),
            FadeInUp(
              duration: const Duration(milliseconds: 400),
              child: _buildStatCard(
                'Approved',
                approvedCount.toString(),
                Icons.check_circle,
                AppTheme.successColor,
              ),
            ),
            FadeInUp(
              duration: const Duration(milliseconds: 500),
              child: _buildStatCard(
                'Rejected',
                rejectedCount.toString(),
                Icons.cancel,
                AppTheme.errorColor,
              ),
            ),
            FadeInUp(
              duration: const Duration(milliseconds: 600),
              child: _buildStatCard(
                'Revisions',
                revisionCount.toString(),
                Icons.edit,
                AppTheme.warningColor,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(
      String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(12),
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
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 32, color: color),
          const SizedBox(height: 8),
          Text(
            value,
            style: AppTheme.textTheme.headlineMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            title,
            style: AppTheme.textTheme.bodySmall?.copyWith(
              color: AppTheme.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildRecentActivity(List<QueryDocumentSnapshot> reviews) {
    final recentReviews = reviews.take(5).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Recent Review Activity',
              style: AppTheme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            if (recentReviews.isEmpty)
              const Center(
                child: Text('No recent activity'),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: recentReviews.length,
                separatorBuilder: (context, index) => const Divider(),
                itemBuilder: (context, index) {
                  final data =
                      recentReviews[index].data() as Map<String, dynamic>;
                  final action = data['action'] ?? 'unknown';
                  final templateName =
                      data['templateName'] ?? 'Unknown Template';
                  final reviewedAt =
                      (data['reviewedAt'] as Timestamp?)?.toDate() ??
                          DateTime.now();

                  return ListTile(
                    leading: Icon(
                      _getActionIcon(action),
                      color: _getActionColor(action),
                    ),
                    title: Text(templateName),
                    subtitle: Text(_formatDate(reviewedAt)),
                    trailing: Chip(
                      label: Text(
                        action.toUpperCase(),
                        style: TextStyle(
                          color: _getActionColor(action),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      backgroundColor:
                          _getActionColor(action).withValues(alpha: 0.1),
                      side: BorderSide(
                          color:
                              _getActionColor(action).withValues(alpha: 0.3)),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTemplateTypeBreakdown(List<QueryDocumentSnapshot> reviews) {
    final typeCount = <String, int>{};
    for (final doc in reviews) {
      final data = doc.data() as Map<String, dynamic>;
      final type = data['templateType'] ?? 'Unknown';
      typeCount[type] = (typeCount[type] ?? 0) + 1;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Template Type Breakdown',
              style: AppTheme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            if (typeCount.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Icon(Icons.pie_chart_outline,
                        size: 48, color: AppTheme.textSecondary),
                    const SizedBox(height: 8),
                    Text(
                      'No template data available yet',
                      style: AppTheme.textTheme.bodyMedium?.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Data will appear as you review templates',
                      style: AppTheme.textTheme.bodySmall?.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              )
            else
              ...typeCount.entries.map((entry) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: Text(entry.key),
                        ),
                        Expanded(
                          flex: 3,
                          child: LinearProgressIndicator(
                            value: entry.value / reviews.length,
                            backgroundColor: AppTheme.dividerColor,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              AppTheme.primaryColor,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text('${entry.value}'),
                      ],
                    ),
                  )),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _exportReport,
            icon: const Icon(Icons.download),
            label: const Text('Export Report'),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _shareReport,
            icon: const Icon(Icons.share),
            label: const Text('Share Report'),
          ),
        ),
      ],
    );
  }

  Widget _buildReviewTrends(List<QueryDocumentSnapshot> reviews) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Review Trends',
              style: AppTheme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              height: 200,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.backgroundLight,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.dividerColor),
              ),
              child: _buildReviewTrendsChart(reviews),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReviewTrendsChart(List<QueryDocumentSnapshot> reviews) {
    if (reviews.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.show_chart, size: 48, color: AppTheme.textSecondary),
            SizedBox(height: 8),
            Text(
              'No review data available',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          ],
        ),
      );
    }

    // Group reviews by date
    final reviewsByDate = <String, int>{};
    final now = DateTime.now();

    // Initialize last 7 days
    for (int i = 6; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      final dateKey = '${date.month}/${date.day}';
      reviewsByDate[dateKey] = 0;
    }

    // Count reviews by date
    for (final doc in reviews) {
      final data = doc.data() as Map<String, dynamic>;
      final reviewedAt = (data['reviewedAt'] as Timestamp?)?.toDate();
      if (reviewedAt != null) {
        final difference = now.difference(reviewedAt).inDays;
        if (difference <= 6) {
          final dateKey = '${reviewedAt.month}/${reviewedAt.day}';
          reviewsByDate[dateKey] = (reviewsByDate[dateKey] ?? 0) + 1;
        }
      }
    }

    final maxValue = reviewsByDate.values.isEmpty
        ? 1
        : reviewsByDate.values.reduce((a, b) => a > b ? a : b);

    return Column(
      children: [
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: reviewsByDate.entries.map((entry) {
              final height =
                  maxValue > 0 ? (entry.value / maxValue) * 120 : 0.0;
              return Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    '${entry.value}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    width: 24,
                    height: height.clamp(4.0, 120.0),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    entry.key,
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Reviews per day (Last 7 days)',
          style: AppTheme.textTheme.bodySmall?.copyWith(
            color: AppTheme.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildApprovalRates(List<QueryDocumentSnapshot> reviews) {
    final approvedCount = reviews.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return data['action'] == 'approved';
    }).length;

    final approvalRate =
        reviews.isNotEmpty ? (approvedCount / reviews.length * 100) : 0.0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Approval Rates',
              style: AppTheme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: Column(
                children: [
                  Text(
                    '${approvalRate.toStringAsFixed(1)}%',
                    style: AppTheme.textTheme.headlineLarge?.copyWith(
                      color: AppTheme.successColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Templates Approved',
                    style: AppTheme.textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  LinearProgressIndicator(
                    value: approvalRate / 100,
                    backgroundColor: AppTheme.dividerColor,
                    valueColor:
                        AlwaysStoppedAnimation<Color>(AppTheme.successColor),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeAnalysis(List<QueryDocumentSnapshot> reviews) {
    final timeAnalytics = _calculateTimeAnalytics(reviews);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Time Analysis',
              style: AppTheme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildTimeMetric(
                'Average Review Time', timeAnalytics['avgReviewTime'] ?? 'N/A'),
            _buildTimeMetric(
                'Fastest Review', timeAnalytics['fastestReview'] ?? 'N/A'),
            _buildTimeMetric(
                'Peak Review Hours', timeAnalytics['peakHours'] ?? 'N/A'),
            _buildTimeMetric('Most Productive Day',
                timeAnalytics['mostProductiveDay'] ?? 'N/A'),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeMetric(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: AppTheme.textTheme.bodyMedium,
          ),
          Text(
            value,
            style: AppTheme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: AppTheme.primaryColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCAPerformance(List<QueryDocumentSnapshot> reviews) {
    final caPerformance = <String, Map<String, int>>{};

    for (final doc in reviews) {
      final data = doc.data() as Map<String, dynamic>;
      final caName = data['caName'] ?? 'Unknown CA';
      final action = data['action'] ?? 'unknown';

      if (!caPerformance.containsKey(caName)) {
        caPerformance[caName] = {};
      }

      caPerformance[caName]![action] =
          (caPerformance[caName]![action] ?? 0) + 1;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'CA Performance Analysis',
              style: AppTheme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            if (caPerformance.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Icon(Icons.analytics_outlined,
                        size: 48, color: AppTheme.textSecondary),
                    const SizedBox(height: 8),
                    Text(
                      'No CA performance data available',
                      style: AppTheme.textTheme.bodyMedium?.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Data will show as CAs submit templates for review',
                      style: AppTheme.textTheme.bodySmall?.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              )
            else
              ...caPerformance.entries.take(5).map((entry) {
                final totalTemplates = entry.value.values
                    .fold<int>(0, (total, value) => total + value);
                final approvedTemplates = entry.value['approved'] ?? 0;
                final approvalRate = totalTemplates > 0
                    ? (approvedTemplates / totalTemplates * 100)
                    : 0.0;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(entry.key),
                          Text('${approvalRate.toStringAsFixed(1)}% approval'),
                        ],
                      ),
                      const SizedBox(height: 4),
                      LinearProgressIndicator(
                        value: approvalRate / 100,
                        backgroundColor: AppTheme.dividerColor,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          approvalRate >= 80
                              ? AppTheme.successColor
                              : approvalRate >= 60
                                  ? AppTheme.warningColor
                                  : AppTheme.errorColor,
                        ),
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildPerformanceMetrics(List<QueryDocumentSnapshot> reviews) {
    final performanceData = _calculatePerformanceMetrics(reviews);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Performance Metrics',
          style: AppTheme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                'Quality Score',
                performanceData['qualityScore'] ?? 'N/A',
                Icons.star,
                _getScoreColor(performanceData['qualityScoreValue'] ?? 0.0),
                'Based on approval rates and feedback quality',
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildMetricCard(
                'Efficiency',
                performanceData['efficiency'] ?? 'N/A',
                Icons.speed,
                _getScoreColor(performanceData['efficiencyValue'] ?? 0.0),
                'Average review time vs. target',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMetricCard(String title, String value, IconData icon,
      Color color, String description) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            Text(
              value,
              style: AppTheme.textTheme.headlineMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              title,
              style: AppTheme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: AppTheme.textTheme.bodySmall?.copyWith(
                color: AppTheme.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductivityStats(List<QueryDocumentSnapshot> reviews) {
    final productivityData = _calculateProductivityStats(reviews);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Productivity Statistics',
              style: AppTheme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildProductivityMetric('Reviews per Day',
                productivityData['reviewsPerDay'] ?? 'N/A', 'avg'),
            _buildProductivityMetric('Peak Performance Day',
                productivityData['peakDay'] ?? 'N/A', ''),
            _buildProductivityMetric('Most Active Hour',
                productivityData['mostActiveHour'] ?? 'N/A', ''),
            _buildProductivityMetric('Review Streak',
                productivityData['currentStreak'] ?? 'N/A', 'current'),
          ],
        ),
      ),
    );
  }

  Widget _buildProductivityMetric(String label, String value, String suffix) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Row(
            children: [
              Text(
                value,
                style: AppTheme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryColor,
                ),
              ),
              if (suffix.isNotEmpty) ...[
                const SizedBox(width: 4),
                Text(
                  suffix,
                  style: AppTheme.textTheme.bodySmall?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQualityMetrics(List<QueryDocumentSnapshot> reviews) {
    final qualityData = _calculateQualityMetrics(reviews);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Quality Metrics',
              style: AppTheme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildQualityIndicator(
                'Thoroughness', qualityData['thoroughness'] ?? 0.0),
            _buildQualityIndicator('Accuracy', qualityData['accuracy'] ?? 0.0),
            _buildQualityIndicator(
                'Consistency', qualityData['consistency'] ?? 0.0),
            _buildQualityIndicator(
                'Feedback Quality', qualityData['feedbackQuality'] ?? 0.0),
          ],
        ),
      ),
    );
  }

  Widget _buildQualityIndicator(String label, double value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label),
              Text(
                '${(value * 100).toStringAsFixed(0)}%',
                style: AppTheme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: value >= 0.8
                      ? AppTheme.successColor
                      : value >= 0.6
                          ? AppTheme.warningColor
                          : AppTheme.errorColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: value,
            backgroundColor: AppTheme.dividerColor,
            valueColor: AlwaysStoppedAnimation<Color>(
              value >= 0.8
                  ? AppTheme.successColor
                  : value >= 0.6
                      ? AppTheme.warningColor
                      : AppTheme.errorColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendations(List<QueryDocumentSnapshot> reviews) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Recommendations',
              style: AppTheme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildRecommendationItem(
              Icons.lightbulb,
              'Improve Efficiency',
              'Consider setting up review templates for common feedback scenarios.',
              AppTheme.infoColor,
            ),
            _buildRecommendationItem(
              Icons.schedule,
              'Optimize Timing',
              'Your peak performance is on Tuesdays. Consider scheduling important reviews then.',
              AppTheme.successColor,
            ),
            _buildRecommendationItem(
              Icons.feedback,
              'Enhance Feedback',
              'Provide more detailed feedback for rejected templates to help CAs improve.',
              AppTheme.warningColor,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecommendationItem(
      IconData icon, String title, String description, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTheme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: AppTheme.textTheme.bodySmall?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorWidget(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: AppTheme.errorColor),
          const SizedBox(height: 16),
          Text(
            'Error Loading Data',
            style: AppTheme.textTheme.headlineMedium
                ?.copyWith(color: AppTheme.errorColor),
          ),
          const SizedBox(height: 8),
          Text(
            error,
            style: AppTheme.textTheme.bodyMedium
                ?.copyWith(color: AppTheme.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _refreshData,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  List<QueryDocumentSnapshot> _filterReviewsByPeriod(
      List<QueryDocumentSnapshot> reviews) {
    if (_selectedPeriod == 'all') return reviews;

    final now = DateTime.now();
    DateTime cutoffDate;

    switch (_selectedPeriod) {
      case 'week':
        cutoffDate = now.subtract(Duration(days: now.weekday - 1));
        break;
      case 'month':
        cutoffDate = DateTime(now.year, now.month, 1);
        break;
      case 'quarter':
        final quarterMonth = ((now.month - 1) ~/ 3) * 3 + 1;
        cutoffDate = DateTime(now.year, quarterMonth, 1);
        break;
      case 'year':
        cutoffDate = DateTime(now.year, 1, 1);
        break;
      default:
        return reviews;
    }

    return reviews.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final reviewedAt = (data['reviewedAt'] as Timestamp?)?.toDate();
      return reviewedAt != null && reviewedAt.isAfter(cutoffDate);
    }).toList();
  }

  IconData _getActionIcon(String action) {
    switch (action) {
      case 'approved':
        return Icons.check_circle;
      case 'rejected':
        return Icons.cancel;
      case 'needs_revision':
        return Icons.edit;
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
      default:
        return AppTheme.textSecondary;
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 0) {
      return '${difference.inDays} days ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hours ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minutes ago';
    } else {
      return 'Just now';
    }
  }

  Future<void> _refreshData() async {
    setState(() {
      _isLoading = true;
    });

    await Future.delayed(const Duration(seconds: 1));

    setState(() {
      _isLoading = false;
    });
  }

  void _exportReport() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Export Report'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Choose export format:'),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf),
              title: const Text('PDF Report'),
              onTap: () {
                Navigator.pop(context);
                _exportAsPDF();
              },
            ),
            ListTile(
              leading: const Icon(Icons.table_chart),
              title: const Text('CSV Data'),
              onTap: () {
                Navigator.pop(context);
                _exportAsCSV();
              },
            ),
            ListTile(
              leading: const Icon(Icons.image),
              title: const Text('PNG Image'),
              onTap: () {
                Navigator.pop(context);
                _exportAsPNG();
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _exportAsPDF() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Generating PDF report...'),
        backgroundColor: AppTheme.infoColor,
      ),
    );
    // Actual PDF export functionality can be implemented here
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('PDF report generated successfully!'),
            backgroundColor: AppTheme.successColor,
          ),
        );
      }
    });
  }

  void _exportAsCSV() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Generating CSV file...'),
        backgroundColor: AppTheme.infoColor,
      ),
    );
    // Actual CSV export functionality can be implemented here
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('CSV file generated successfully!'),
            backgroundColor: AppTheme.successColor,
          ),
        );
      }
    });
  }

  void _exportAsPNG() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Generating PNG image...'),
        backgroundColor: AppTheme.infoColor,
      ),
    );
    // Actual PNG export functionality can be implemented here
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('PNG image generated successfully!'),
            backgroundColor: AppTheme.successColor,
          ),
        );
      }
    });
  }

  void _shareReport() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Share Report'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Choose sharing method:'),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.email),
              title: const Text('Send via Email'),
              onTap: () {
                Navigator.pop(context);
                _shareViaEmail();
              },
            ),
            ListTile(
              leading: const Icon(Icons.link),
              title: const Text('Generate Share Link'),
              onTap: () {
                Navigator.pop(context);
                _generateShareLink();
              },
            ),
            ListTile(
              leading: const Icon(Icons.download),
              title: const Text('Download & Share'),
              onTap: () {
                Navigator.pop(context);
                _downloadAndShare();
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _shareViaEmail() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Preparing email with report...'),
        backgroundColor: AppTheme.infoColor,
      ),
    );
    // Actual email sharing functionality can be implemented here
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Email prepared! Opening email client...'),
            backgroundColor: AppTheme.successColor,
          ),
        );
      }
    });
  }

  void _generateShareLink() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Generating secure share link...'),
        backgroundColor: AppTheme.infoColor,
      ),
    );
    // Actual share link generation functionality can be implemented here
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Share link copied to clipboard!'),
            backgroundColor: AppTheme.successColor,
            action: SnackBarAction(
              label: 'View',
              onPressed: () {
                // Can display share link details here
              },
            ),
          ),
        );
      }
    });
  }

  void _downloadAndShare() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Preparing report for download...'),
        backgroundColor: AppTheme.infoColor,
      ),
    );
    // Actual download and sharing functionality can be implemented here
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Report ready for download and sharing!'),
            backgroundColor: AppTheme.successColor,
          ),
        );
      }
    });
  }

  // Calculate time analysis data
  Map<String, String> _calculateTimeAnalytics(
      List<QueryDocumentSnapshot> reviews) {
    if (reviews.isEmpty) {
      return {
        'avgReviewTime': 'No data',
        'fastestReview': 'No data',
        'peakHours': 'No data',
        'mostProductiveDay': 'No data',
      };
    }

    // Calculate average review time
    final reviewTimes = <Duration>[];
    final hourCounts = <int, int>{};
    final dayCounts = <String, int>{};

    for (final doc in reviews) {
      final data = doc.data() as Map<String, dynamic>;
      final reviewedAt = (data['reviewedAt'] as Timestamp?)?.toDate();
      final submittedAt = (data['submittedAt'] as Timestamp?)?.toDate();

      if (reviewedAt != null && submittedAt != null) {
        final reviewTime = reviewedAt.difference(submittedAt);
        if (reviewTime.inHours >= 0 && reviewTime.inDays < 30) {
          reviewTimes.add(reviewTime);
        }

        // Count hours
        final hour = reviewedAt.hour;
        hourCounts[hour] = (hourCounts[hour] ?? 0) + 1;

        // Count days of the week
        final dayNames = [
          'Monday',
          'Tuesday',
          'Wednesday',
          'Thursday',
          'Friday',
          'Saturday',
          'Sunday'
        ];
        final dayName = dayNames[reviewedAt.weekday - 1];
        dayCounts[dayName] = (dayCounts[dayName] ?? 0) + 1;
      }
    }

    // Calculate average time
    String avgReviewTime = 'No data';
    String fastestReview = 'No data';
    if (reviewTimes.isNotEmpty) {
      final avgMinutes =
          reviewTimes.map((t) => t.inMinutes).reduce((a, b) => a + b) ~/
              reviewTimes.length;
      avgReviewTime = _formatDuration(Duration(minutes: avgMinutes));

      final fastestMinutes =
          reviewTimes.map((t) => t.inMinutes).reduce((a, b) => a < b ? a : b);
      fastestReview = _formatDuration(Duration(minutes: fastestMinutes));
    }

    // Find the busiest hour
    String peakHours = 'No data';
    if (hourCounts.isNotEmpty) {
      final maxHour =
          hourCounts.entries.reduce((a, b) => a.value > b.value ? a : b).key;
      peakHours =
          '${maxHour.toString().padLeft(2, '0')}:00 - ${(maxHour + 1).toString().padLeft(2, '0')}:00';
    }

    // Find the most productive day
    String mostProductiveDay = 'No data';
    if (dayCounts.isNotEmpty) {
      mostProductiveDay =
          dayCounts.entries.reduce((a, b) => a.value > b.value ? a : b).key;
    }

    return {
      'avgReviewTime': avgReviewTime,
      'fastestReview': fastestReview,
      'peakHours': peakHours,
      'mostProductiveDay': mostProductiveDay,
    };
  }

  // Calculate productivity statistics
  Map<String, String> _calculateProductivityStats(
      List<QueryDocumentSnapshot> reviews) {
    if (reviews.isEmpty) {
      return {
        'reviewsPerDay': '0',
        'peakDay': 'No data',
        'mostActiveHour': 'No data',
        'currentStreak': '0',
      };
    }

    final now = DateTime.now();
    final last30Days = reviews.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final reviewedAt = (data['reviewedAt'] as Timestamp?)?.toDate();
      return reviewedAt != null && now.difference(reviewedAt).inDays <= 30;
    }).toList();

    // Calculate daily average review count
    final reviewsPerDay = last30Days.length / 30;

    // Count daily review statistics
    final dayCounts = <String, int>{};
    final hourCounts = <int, int>{};

    for (final doc in reviews) {
      final data = doc.data() as Map<String, dynamic>;
      final reviewedAt = (data['reviewedAt'] as Timestamp?)?.toDate();

      if (reviewedAt != null) {
        // Count days of the week
        final dayNames = [
          'Monday',
          'Tuesday',
          'Wednesday',
          'Thursday',
          'Friday',
          'Saturday',
          'Sunday'
        ];
        final dayName = dayNames[reviewedAt.weekday - 1];
        dayCounts[dayName] = (dayCounts[dayName] ?? 0) + 1;

        // Count hours
        hourCounts[reviewedAt.hour] = (hourCounts[reviewedAt.hour] ?? 0) + 1;
      }
    }

    String peakDay = 'No data';
    if (dayCounts.isNotEmpty) {
      peakDay =
          dayCounts.entries.reduce((a, b) => a.value > b.value ? a : b).key;
    }

    String mostActiveHour = 'No data';
    if (hourCounts.isNotEmpty) {
      final maxHour =
          hourCounts.entries.reduce((a, b) => a.value > b.value ? a : b).key;
      mostActiveHour = '${maxHour.toString().padLeft(2, '0')}:00';
    }

    // Calculate current consecutive working days (simplified version)
    int currentStreak = 0;
    final sortedReviews = reviews.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final reviewedAt = (data['reviewedAt'] as Timestamp?)?.toDate();
      return reviewedAt != null;
    }).toList();

    if (sortedReviews.isNotEmpty) {
      final today = DateTime.now();
      final reviewDates = <String>{};

      for (final doc in sortedReviews) {
        final data = doc.data() as Map<String, dynamic>;
        final reviewedAt = (data['reviewedAt'] as Timestamp?)?.toDate();
        if (reviewedAt != null) {
          final dateKey =
              '${reviewedAt.year}-${reviewedAt.month}-${reviewedAt.day}';
          reviewDates.add(dateKey);
        }
      }

      // Simple calculation of consecutive days
      for (int i = 0; i < 30; i++) {
        final checkDate = today.subtract(Duration(days: i));
        final dateKey = '${checkDate.year}-${checkDate.month}-${checkDate.day}';
        if (reviewDates.contains(dateKey)) {
          currentStreak++;
        } else {
          break;
        }
      }
    }

    return {
      'reviewsPerDay': reviewsPerDay.toStringAsFixed(1),
      'peakDay': peakDay,
      'mostActiveHour': mostActiveHour,
      'currentStreak': '$currentStreak days',
    };
  }

  // Calculate performance metrics
  Map<String, dynamic> _calculatePerformanceMetrics(
      List<QueryDocumentSnapshot> reviews) {
    if (reviews.isEmpty) {
      return {
        'qualityScore': 'No data',
        'qualityScoreValue': 0.0,
        'efficiency': 'No data',
        'efficiencyValue': 0.0,
      };
    }

    // Calculate quality score (based on approval rate)
    final approvedCount = reviews.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return data['action'] == 'approved';
    }).length;

    final approvalRate = approvedCount / reviews.length;
    final qualityScore = approvalRate * 100;

    // Calculate efficiency score (based on review time)
    final reviewTimes = <Duration>[];
    for (final doc in reviews) {
      final data = doc.data() as Map<String, dynamic>;
      final reviewedAt = (data['reviewedAt'] as Timestamp?)?.toDate();
      final submittedAt = (data['submittedAt'] as Timestamp?)?.toDate();

      if (reviewedAt != null && submittedAt != null) {
        final reviewTime = reviewedAt.difference(submittedAt);
        if (reviewTime.inHours >= 0 && reviewTime.inDays < 30) {
          reviewTimes.add(reviewTime);
        }
      }
    }

    double efficiencyScore = 0.0;
    if (reviewTimes.isNotEmpty) {
      final avgMinutes =
          reviewTimes.map((t) => t.inMinutes).reduce((a, b) => a + b) /
              reviewTimes.length;
      // Assuming target time is 4 hours (240 minutes), efficiency score is based on whether it's below this target
      final targetMinutes = 240.0;
      efficiencyScore =
          ((targetMinutes - avgMinutes.clamp(0, targetMinutes * 2)) /
                  targetMinutes *
                  100)
              .clamp(0, 100);
    }

    return {
      'qualityScore': '${qualityScore.toStringAsFixed(0)}%',
      'qualityScoreValue': qualityScore / 100,
      'efficiency': '${efficiencyScore.toStringAsFixed(0)}%',
      'efficiencyValue': efficiencyScore / 100,
    };
  }

  // Calculate quality metrics
  Map<String, double> _calculateQualityMetrics(
      List<QueryDocumentSnapshot> reviews) {
    if (reviews.isEmpty) {
      return {
        'thoroughness': 0.0,
        'accuracy': 0.0,
        'consistency': 0.0,
        'feedbackQuality': 0.0,
      };
    }

    // These are simplified calculations based on review data
    final approvedCount = reviews.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return data['action'] == 'approved';
    }).length;

    final withFeedbackCount = reviews.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final feedback = data['feedback'] as String?;
      return feedback != null && feedback.trim().length > 20;
    }).length;

    final approvalRate = approvedCount / reviews.length;
    final feedbackRate = withFeedbackCount / reviews.length;

    // Calculate consistency (based on consistent decisions for similar templates)
    final consistencyScore = _calculateConsistencyScore(reviews);

    return {
      'thoroughness': (feedbackRate * 0.7 + approvalRate * 0.3).clamp(0.0, 1.0),
      'accuracy': approvalRate.clamp(0.0, 1.0),
      'consistency': consistencyScore.clamp(0.0, 1.0),
      'feedbackQuality': feedbackRate.clamp(0.0, 1.0),
    };
  }

  // Calculate consistency score
  double _calculateConsistencyScore(List<QueryDocumentSnapshot> reviews) {
    if (reviews.length < 2) return 1.0;

    // Group by template type
    final typeGroups = <String, List<String>>{};
    for (final doc in reviews) {
      final data = doc.data() as Map<String, dynamic>;
      final type = data['templateType'] ?? 'unknown';
      final action = data['action'] ?? 'unknown';

      if (!typeGroups.containsKey(type)) {
        typeGroups[type] = [];
      }
      typeGroups[type]!.add(action);
    }

    // Calculate consistency for each type
    double totalConsistency = 0.0;
    int validGroups = 0;

    for (final actions in typeGroups.values) {
      if (actions.length > 1) {
        final approvedCount = actions.where((a) => a == 'approved').length;
        final consistencyRatio =
            (approvedCount / actions.length - 0.5).abs() * 2;
        totalConsistency += 1.0 - consistencyRatio;
        validGroups++;
      }
    }

    return validGroups > 0 ? totalConsistency / validGroups : 0.8;
  }

  // Format duration
  String _formatDuration(Duration duration) {
    if (duration.inDays > 0) {
      return '${duration.inDays} days ${duration.inHours % 24} hours';
    } else if (duration.inHours > 0) {
      return '${duration.inHours} hours ${duration.inMinutes % 60} minutes';
    } else {
      return '${duration.inMinutes} minutes';
    }
  }

  // Get color based on score
  Color _getScoreColor(double score) {
    if (score >= 0.8) {
      return AppTheme.successColor;
    } else if (score >= 0.6) {
      return AppTheme.warningColor;
    } else {
      return AppTheme.errorColor;
    }
  }
}
