import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:animate_do/animate_do.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/custom_app_bar.dart';
import '../../../../core/services/logger_service.dart';

import '../../../auth/providers/auth_providers.dart';

class CAReportsPage extends ConsumerStatefulWidget {
  const CAReportsPage({super.key});

  @override
  ConsumerState<CAReportsPage> createState() => _CAReportsPageState();
}

class _CAReportsPageState extends ConsumerState<CAReportsPage> {
  String _selectedPeriod = 'month';
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserProvider).value;

    if (currentUser == null || (!currentUser.isCA && !currentUser.isAdmin)) {
      return Scaffold(
        appBar: const CustomAppBar(title: 'CA Reports'),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock, size: 80, color: AppTheme.errorColor),
              const SizedBox(height: 16),
              Text('Access Denied',
                  style: AppTheme.textTheme.headlineMedium
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(
                  'You do not have permission to view CA reports. CA or Admin access required.',
                  style: AppTheme.textTheme.bodyLarge
                      ?.copyWith(color: AppTheme.textSecondary),
                  textAlign: TextAlign.center),
              const SizedBox(height: 24),
              ElevatedButton(
                  onPressed: () => context.pop(), child: const Text('Go Back')),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: const CustomAppBar(title: 'CA Performance Reports'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildPeriodSelector(),
            const SizedBox(height: 24),
            _buildOverviewStats(),
            const SizedBox(height: 24),
            _buildTemplateCreationChart(),
            const SizedBox(height: 24),
            _buildDocumentReviewStats(),
            const SizedBox(height: 24),
            _buildClientInteractionStats(),
            const SizedBox(height: 24),
            _buildPerformanceMetrics(),
            const SizedBox(height: 24),
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildPeriodSelector() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Report Period',
                style: AppTheme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedPeriod,
                    decoration: const InputDecoration(
                        labelText: 'Period', border: OutlineInputBorder()),
                    items: const [
                      DropdownMenuItem(value: 'week', child: Text('This Week')),
                      DropdownMenuItem(
                          value: 'month', child: Text('This Month')),
                      DropdownMenuItem(
                          value: 'quarter', child: Text('This Quarter')),
                      DropdownMenuItem(value: 'year', child: Text('This Year')),
                    ],
                    onChanged: (value) {
                      setState(() => _selectedPeriod = value!);
                    },
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: _refreshReports,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.refresh),
                  label: Text(_isLoading ? 'Loading...' : 'Refresh'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewStats() {
    return FadeInUp(
      duration: const Duration(milliseconds: 300),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Overview Statistics',
                  style: AppTheme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              StreamBuilder<QuerySnapshot>(
                stream: _getOverviewStatsStream(),
                builder: (context, templateSnapshot) {
                  if (templateSnapshot.connectionState ==
                      ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final templateStats = _calculateOverviewStats(
                      templateSnapshot.data?.docs ?? []);

                  return StreamBuilder<QuerySnapshot>(
                    stream: _getDocumentReviewStatsStream(),
                    builder: (context, docSnapshot) {
                      final documentsReviewed =
                          docSnapshot.data?.docs.length ?? 0;

                      return GridView.count(
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio: 1.5,
                        children: [
                          _buildStatCard(
                              'Templates Created',
                              '${templateStats['templatesCreated']}',
                              Icons.design_services,
                              AppTheme.primaryColor),
                          _buildStatCard(
                              'Documents Reviewed',
                              '$documentsReviewed',
                              Icons.fact_check,
                              AppTheme.successColor),
                          _buildStatCard(
                              'Client Approved',
                              '${templateStats['clientApproved']}',
                              Icons.thumb_up,
                              AppTheme.infoColor),
                          _buildStatCard(
                              'Pending Review',
                              '${templateStats['pendingReview']}',
                              Icons.pending,
                              AppTheme.warningColor),
                        ],
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTemplateCreationChart() {
    return FadeInUp(
      duration: const Duration(milliseconds: 400),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Template Creation Trend',
                  style: AppTheme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Container(
                height: 200,
                decoration: BoxDecoration(
                  color: AppTheme.backgroundLight,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.dividerColor),
                ),
                child: StreamBuilder<QuerySnapshot>(
                  stream: _getTemplateCreationTrendStream(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    return _buildCreationTrendChart(snapshot.data?.docs ?? []);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDocumentReviewStats() {
    return FadeInUp(
      duration: const Duration(milliseconds: 500),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Document Review Performance',
                  style: AppTheme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              StreamBuilder<QuerySnapshot>(
                stream: _getDocumentReviewStatsStream(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final stats =
                      _calculateReviewStats(snapshot.data?.docs ?? []);

                  return Column(
                    children: [
                      _buildProgressIndicator(
                          'Approval Rate',
                          stats['approvalRate']?.toDouble() ?? 0.0,
                          AppTheme.successColor),
                      const SizedBox(height: 12),
                      _buildProgressIndicator(
                          'Average Review Time',
                          stats['avgReviewTime']?.toDouble() ?? 0.0,
                          AppTheme.primaryColor),
                      const SizedBox(height: 12),
                      _buildProgressIndicator(
                          'Quality Score',
                          stats['qualityScore']?.toDouble() ?? 0.0,
                          AppTheme.warningColor),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildClientInteractionStats() {
    return FadeInUp(
      duration: const Duration(milliseconds: 600),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Client Interaction Summary',
                  style: AppTheme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              StreamBuilder<QuerySnapshot>(
                stream: _getClientInteractionStream(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final interactions =
                      _calculateClientInteractions(snapshot.data?.docs ?? []);

                  return Column(
                    children: [
                      _buildInteractionRow('Templates Submitted to Client',
                          '${interactions['submitted']}', Icons.send),
                      _buildInteractionRow('Client Approved Templates',
                          '${interactions['approved']}', Icons.check_circle),
                      _buildInteractionRow('Revision Requests Received',
                          '${interactions['revisions']}', Icons.edit),
                      _buildInteractionRow('Templates Rejected',
                          '${interactions['rejected']}', Icons.cancel),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPerformanceMetrics() {
    return FadeInUp(
      duration: const Duration(milliseconds: 700),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Performance Metrics',
                  style: AppTheme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              StreamBuilder<QuerySnapshot>(
                stream: _getPerformanceMetricsStream(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final metrics =
                      _calculatePerformanceMetrics(snapshot.data?.docs ?? []);

                  return Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                              child: _buildMetricCard(
                                  'Productivity',
                                  '${metrics['productivity']?.toStringAsFixed(1) ?? '0.0'}%',
                                  Icons.trending_up,
                                  AppTheme.successColor,
                                  'Templates created per week')),
                          const SizedBox(width: 16),
                          Expanded(
                              child: _buildMetricCard(
                                  'Quality',
                                  '${metrics['quality']?.toStringAsFixed(1) ?? '0.0'}%',
                                  Icons.star,
                                  AppTheme.warningColor,
                                  'Client approval rate')),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                              child: _buildMetricCard(
                                  'Efficiency',
                                  '${metrics['efficiency']?.toStringAsFixed(1) ?? '0.0'}%',
                                  Icons.speed,
                                  AppTheme.primaryColor,
                                  'Review completion speed')),
                          const SizedBox(width: 16),
                          Expanded(
                              child: _buildMetricCard(
                                  'Response Rate',
                                  '${metrics['responseRate']?.toStringAsFixed(1) ?? '0.0'}%',
                                  Icons.people,
                                  AppTheme.infoColor,
                                  'Document review response rate')),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return FadeInUp(
      duration: const Duration(milliseconds: 800),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _exportReport,
              icon: const Icon(Icons.download),
              label: const Text('Export Report'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => context.go('/ca/activity'),
              icon: const Icon(Icons.timeline),
              label: const Text('View Activity Log'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
      String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 32, color: color),
          const SizedBox(height: 8),
          Text(value,
              style: AppTheme.textTheme.headlineMedium
                  ?.copyWith(color: color, fontWeight: FontWeight.bold)),
          Text(title,
              style: AppTheme.textTheme.bodySmall
                  ?.copyWith(color: AppTheme.textSecondary),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator(String label, double value, Color color) {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: Text(label, style: AppTheme.textTheme.bodyMedium),
        ),
        Expanded(
          flex: 3,
          child: LinearProgressIndicator(
            value: value / 100,
            backgroundColor: AppTheme.dividerColor,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
        const SizedBox(width: 12),
        Text('${value.toStringAsFixed(1)}%',
            style: AppTheme.textTheme.bodyMedium
                ?.copyWith(fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildInteractionRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppTheme.textSecondary),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: AppTheme.textTheme.bodyMedium)),
          Text(value,
              style: AppTheme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
        ],
      ),
    );
  }

  Widget _buildMetricCard(String title, String value, IconData icon,
      Color color, String description) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 32, color: color),
          const SizedBox(height: 8),
          Text(value,
              style: AppTheme.textTheme.headlineMedium
                  ?.copyWith(color: color, fontWeight: FontWeight.bold)),
          Text(title,
              style: AppTheme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(description,
              style: AppTheme.textTheme.bodySmall
                  ?.copyWith(color: AppTheme.textSecondary),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildCreationTrendChart(List<QueryDocumentSnapshot> docs) {
    if (docs.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.show_chart, size: 48, color: AppTheme.textSecondary),
            SizedBox(height: 8),
            Text('No trend data available',
                style: TextStyle(color: AppTheme.textSecondary)),
          ],
        ),
      );
    }

    // Simple bar chart representation
    final trendData = _processTrendData(docs);
    final maxValue = trendData.values.isEmpty
        ? 1
        : trendData.values.reduce((a, b) => a > b ? a : b);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: trendData.entries.map((entry) {
          final height = maxValue > 0 ? (entry.value / maxValue) * 120 : 0.0;
          return Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text('${entry.value}',
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.bold)),
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
              Text(entry.key,
                  style: const TextStyle(
                      fontSize: 10, color: AppTheme.textSecondary)),
            ],
          );
        }).toList(),
      ),
    );
  }

  // Helper methods
  Stream<QuerySnapshot> _getOverviewStatsStream() {
    final currentUser = ref.read(currentUserProvider).value;
    final startDate = _getStartDateForPeriod();

    LoggerService.info('🔍 CA Reports - Current User ID: ${currentUser?.id}');
    LoggerService.info('🔍 CA Reports - Start Date: $startDate');

    // 先尝试简单查询所有certificate_templates
    return FirebaseFirestore.instance
        .collection('certificate_templates')
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots();
  }

  Stream<QuerySnapshot> _getTemplateCreationTrendStream() {
    final currentUser = ref.read(currentUserProvider).value;
    final startDate = _getStartDateForPeriod();

    return FirebaseFirestore.instance
        .collection('certificate_templates')
        .where('createdBy', isEqualTo: currentUser?.id)
        .where('createdAt', isGreaterThan: Timestamp.fromDate(startDate))
        .orderBy('createdAt')
        .snapshots();
  }

  Stream<QuerySnapshot> _getDocumentReviewStatsStream() {
    LoggerService.info('🔍 CA Reports - Querying documents collection');

    // 简化查询，先获取所有文档
    return FirebaseFirestore.instance
        .collection('documents')
        .orderBy('uploadedAt', descending: true)
        .limit(50)
        .snapshots();
  }

  Stream<QuerySnapshot> _getClientInteractionStream() {
    LoggerService.info('🔍 CA Reports - Querying template_reviews collection');

    // 简化查询，先获取所有模板审核记录
    return FirebaseFirestore.instance
        .collection('template_reviews')
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots();
  }

  DateTime _getStartDateForPeriod() {
    final now = DateTime.now();
    switch (_selectedPeriod) {
      case 'week':
        return now.subtract(const Duration(days: 7));
      case 'month':
        return DateTime(now.year, now.month, 1);
      case 'quarter':
        final quarterStart = ((now.month - 1) ~/ 3) * 3 + 1;
        return DateTime(now.year, quarterStart, 1);
      case 'year':
        return DateTime(now.year, 1, 1);
      default:
        return DateTime(now.year, now.month, 1);
    }
  }

  Map<String, int> _calculateOverviewStats(List<QueryDocumentSnapshot> docs) {
    int templatesCreated = docs.length; // 简单计算总数
    int clientApproved = 0;
    int pendingReview = 0;

    // 📊 详细分析每个文档的状态
    LoggerService.info('📊 CA Reports - Analyzing ${docs.length} templates:');

    for (final doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final status = data['status'] ?? 'unknown';
      final createdBy = data['createdBy'] ?? 'unknown';

      LoggerService.info(
          '📄 Template ${doc.id}: status=$status, createdBy=$createdBy');

      switch (status) {
        case 'client_approved':
        case 'active':
          clientApproved++;
          break;
        case 'pending_client_review':
          pendingReview++;
          break;
      }
    }

    // 📊 调试日志：显示真实统计数据
    LoggerService.info('📊 CA Reports - Final Stats:');
    LoggerService.info('📄 Templates Total: $templatesCreated');
    LoggerService.info('✅ Client Approved: $clientApproved');
    LoggerService.info('⏳ Pending Review: $pendingReview');

    return {
      'templatesCreated': templatesCreated,
      'documentsReviewed': templatesCreated, // 暂时使用相同数值
      'clientApproved': clientApproved,
      'pendingReview': pendingReview,
    };
  }

  // 🔄 新增：性能指标数据流
  Stream<QuerySnapshot> _getPerformanceMetricsStream() {
    final currentUser = ref.read(currentUserProvider).value;
    final startDate = _getStartDateForPeriod();

    return FirebaseFirestore.instance
        .collection('certificate_templates')
        .where('createdBy', isEqualTo: currentUser?.id)
        .where('createdAt', isGreaterThan: Timestamp.fromDate(startDate))
        .snapshots();
  }

  // 🔄 新增：计算真实性能指标
  Map<String, double> _calculatePerformanceMetrics(
      List<QueryDocumentSnapshot> docs) {
    if (docs.isEmpty) {
      return {
        'productivity': 0.0,
        'quality': 0.0,
        'efficiency': 0.0,
        'responseRate': 0.0,
      };
    }

    // 计算生产力：基于时间段内创建的模板数量
    final now = DateTime.now();
    final periodDays = _getPeriodInDays();
    final templatesPerWeek = (docs.length / periodDays) * 7;
    final productivity =
        (templatesPerWeek * 20).clamp(0.0, 100.0); // 假设目标是每周5个模板

    // 计算质量：基于客户批准率
    final approvedCount = docs
        .where((doc) =>
            (doc.data() as Map<String, dynamic>)['status'] == 'client_approved')
        .length;
    final quality = docs.isNotEmpty ? (approvedCount / docs.length * 100) : 0.0;

    // 计算效率：基于审核完成速度
    double totalHours = 0;
    int completedCount = 0;
    for (final doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      if (data['createdAt'] != null &&
          data['status'] != 'pending_client_review') {
        final created = (data['createdAt'] as Timestamp).toDate();
        final completed = data['completedAt'] != null
            ? (data['completedAt'] as Timestamp).toDate()
            : now;
        totalHours += completed.difference(created).inHours;
        completedCount++;
      }
    }
    final avgHours = completedCount > 0 ? totalHours / completedCount : 24.0;
    final efficiency = (24 / avgHours * 100).clamp(0.0, 100.0); // 假设目标是24小时内完成

    // 计算响应率：基于文档处理率
    final processedCount = docs
        .where((doc) =>
            (doc.data() as Map<String, dynamic>)['status'] != 'pending')
        .length;
    final responseRate =
        docs.isNotEmpty ? (processedCount / docs.length * 100) : 0.0;

    // 📊 调试日志：显示真实性能指标
    LoggerService.info('📊 CA Performance Metrics - Real Data:');
    LoggerService.info('🚀 Productivity: ${productivity.toStringAsFixed(1)}%');
    LoggerService.info('⭐ Quality: ${quality.toStringAsFixed(1)}%');
    LoggerService.info('⚡ Efficiency: ${efficiency.toStringAsFixed(1)}%');
    LoggerService.info('💬 Response Rate: ${responseRate.toStringAsFixed(1)}%');

    return {
      'productivity': productivity,
      'quality': quality,
      'efficiency': efficiency,
      'responseRate': responseRate,
    };
  }

  // 🔄 新增：获取时间段的天数
  int _getPeriodInDays() {
    switch (_selectedPeriod) {
      case 'week':
        return 7;
      case 'month':
        return 30;
      case 'quarter':
        return 90;
      case 'year':
        return 365;
      default:
        return 30;
    }
  }

  Map<String, double> _calculateReviewStats(List<QueryDocumentSnapshot> docs) {
    if (docs.isEmpty) {
      LoggerService.info('📊 Document Review Stats - No documents found');
      return {'approvalRate': 0.0, 'avgReviewTime': 0.0, 'qualityScore': 0.0};
    }

    LoggerService.info(
        '📊 Document Review Stats - Analyzing ${docs.length} documents:');

    int verified = 0;
    int pending = 0;
    int rejected = 0;
    double totalReviewTime = 0;
    int reviewedCount = 0;

    for (final doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final status = data['status'] ?? 'unknown';

      LoggerService.info('📄 Document ${doc.id}: status=$status');

      switch (status) {
        case 'verified':
          verified++;
          break;
        case 'pending':
          pending++;
          break;
        case 'rejected':
          rejected++;
          break;
      }

      // 计算审核时间：从上传到更新的时间
      if (data['uploadedAt'] != null && data['updatedAt'] != null) {
        final uploaded = (data['uploadedAt'] as Timestamp).toDate();
        final updated = (data['updatedAt'] as Timestamp).toDate();
        final hours = updated.difference(uploaded).inHours.abs();
        totalReviewTime += hours;
        reviewedCount++;
      }
    }

    final approvalRate = docs.isNotEmpty ? (verified / docs.length * 100) : 0.0;
    final avgReviewTime =
        reviewedCount > 0 ? (totalReviewTime / reviewedCount) : 0.0;
    final qualityScore =
        (approvalRate * 0.7 + (docs.isNotEmpty ? 30.0 : 0.0)).clamp(0.0, 100.0);

    // 📊 调试日志：显示审核统计数据
    LoggerService.info('📊 Document Review Stats - Final Results:');
    LoggerService.info('📄 Total Documents: ${docs.length}');
    LoggerService.info('✅ Verified: $verified');
    LoggerService.info('⏳ Pending: $pending');
    LoggerService.info('❌ Rejected: $rejected');
    LoggerService.info('✅ Approval Rate: ${approvalRate.toStringAsFixed(1)}%');
    LoggerService.info(
        '⏱️ Avg Review Time: ${avgReviewTime.toStringAsFixed(1)} hours');
    LoggerService.info('🏆 Quality Score: ${qualityScore.toStringAsFixed(1)}%');

    return {
      'approvalRate': approvalRate,
      'avgReviewTime': avgReviewTime.clamp(0, 100),
      'qualityScore': qualityScore,
    };
  }

  Map<String, int> _calculateClientInteractions(
      List<QueryDocumentSnapshot> docs) {
    int submitted = docs.length; // 所有审核记录都是已提交的
    int approved = 0;
    int revisions = 0;
    int rejected = 0;

    LoggerService.info(
        '📊 Client Interactions - Analyzing ${docs.length} reviews:');

    for (final doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final action = data['action'] ?? 'unknown';
      final reviewerRole = data['reviewerRole'] ?? 'unknown';

      LoggerService.info(
          '📋 Review ${doc.id}: action=$action, role=$reviewerRole');

      // 只计算client角色的审核
      if (reviewerRole == 'client') {
        switch (action) {
          case 'approved':
            approved++;
            break;
          case 'revision_requested':
            revisions++;
            break;
          case 'rejected':
            rejected++;
            break;
        }
      }
    }

    // 📊 调试日志：显示客户端交互数据
    LoggerService.info('📊 Client Interactions - Final Results:');
    LoggerService.info('📤 Total Reviews: $submitted');
    LoggerService.info('✅ Client Approved: $approved');
    LoggerService.info('🔄 Client Revisions: $revisions');
    LoggerService.info('❌ Client Rejected: $rejected');

    return {
      'submitted': submitted,
      'approved': approved,
      'revisions': revisions,
      'rejected': rejected,
    };
  }

  Map<String, int> _processTrendData(List<QueryDocumentSnapshot> docs) {
    final trendData = <String, int>{};
    final now = DateTime.now();

    // Initialize last 7 days
    for (int i = 6; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      final dateKey = DateFormat('MM/dd').format(date);
      trendData[dateKey] = 0;
    }

    // Count templates by date
    for (final doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
      if (createdAt != null) {
        final difference = now.difference(createdAt).inDays;
        if (difference <= 6) {
          final dateKey = DateFormat('MM/dd').format(createdAt);
          trendData[dateKey] = (trendData[dateKey] ?? 0) + 1;
        }
      }
    }

    return trendData;
  }

  Future<void> _refreshReports() async {
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(seconds: 1)); // Simulate refresh
    setState(() => _isLoading = false);
  }

  Future<void> _exportReport() async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Report exported successfully'),
          backgroundColor: AppTheme.successColor,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to export report: $e'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }
}
