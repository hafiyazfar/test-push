import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:animate_do/animate_do.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/custom_app_bar.dart';
import '../../../auth/providers/auth_providers.dart';

class ClientReviewHistoryPage extends ConsumerStatefulWidget {
  const ClientReviewHistoryPage({super.key});

  @override
  ConsumerState<ClientReviewHistoryPage> createState() =>
      _ClientReviewHistoryPageState();
}

class _ClientReviewHistoryPageState
    extends ConsumerState<ClientReviewHistoryPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedPeriod = 'all';
  String _selectedAction = 'all';
  bool _isLoading = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserProvider).value;

    if (currentUser == null ||
        (!currentUser.isClientType && !currentUser.isAdmin)) {
      return Scaffold(
        appBar: const CustomAppBar(title: 'History'),
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
                'You do not have permission to view history.',
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
      appBar: AppBar(
        title: const Text('Review History'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
      ),
      body: _buildReviewHistoryTab(),
    );
  }

  Widget _buildFilterBar() {
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
      child: Column(
        children: [
          // Search Bar
          TextFormField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search review records...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: AppTheme.surfaceColor,
            ),
            onChanged: (value) {
              setState(() {
                _searchQuery = value.toLowerCase();
              });
            },
          ),
          const SizedBox(height: 12),
          // Filters
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _selectedPeriod,
                  decoration: const InputDecoration(
                    labelText: 'Time Period',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('All Time')),
                    DropdownMenuItem(value: 'today', child: Text('Today')),
                    DropdownMenuItem(value: 'week', child: Text('This Week')),
                    DropdownMenuItem(value: 'month', child: Text('This Month')),
                    DropdownMenuItem(value: 'year', child: Text('This Year')),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedPeriod = value ?? 'all';
                    });
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _selectedAction,
                  decoration: const InputDecoration(
                    labelText: 'Action Type',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('All Actions')),
                    DropdownMenuItem(
                        value: 'approved', child: Text('Approved')),
                    DropdownMenuItem(
                        value: 'rejected', child: Text('Rejected')),
                    DropdownMenuItem(
                        value: 'needs_revision',
                        child: Text('Requested Revision')),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedAction = value ?? 'all';
                    });
                  },
                ),
              ),
              const SizedBox(width: 12),
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
        ],
      ),
    );
  }

  Widget _buildStatItem(
      String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: AppTheme.textTheme.titleLarge?.copyWith(
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: AppTheme.textTheme.bodySmall?.copyWith(
            color: AppTheme.textSecondary,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildReviewStatsCard() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            offset: const Offset(0, 2),
            blurRadius: 8,
          ),
        ],
      ),
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('template_reviews')
            .where('reviewedBy',
                isEqualTo: ref.read(currentUserProvider).value?.id)
            .snapshots(),
        builder: (context, snapshot) {
          final reviews = snapshot.data?.docs ?? [];
          final today = DateTime.now();
          final startOfWeek = today.subtract(Duration(days: today.weekday - 1));

          final todayReviews = reviews.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final reviewedAt = (data['reviewedAt'] as Timestamp?)?.toDate();
            return reviewedAt != null &&
                reviewedAt.year == today.year &&
                reviewedAt.month == today.month &&
                reviewedAt.day == today.day;
          }).length;

          final weekReviews = reviews.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final reviewedAt = (data['reviewedAt'] as Timestamp?)?.toDate();
            return reviewedAt != null && reviewedAt.isAfter(startOfWeek);
          }).length;

          return Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  'Today',
                  todayReviews.toString(),
                  Icons.today,
                  AppTheme.primaryColor,
                ),
              ),
              Container(
                height: 40,
                width: 1,
                color: AppTheme.dividerColor,
              ),
              Expanded(
                child: _buildStatItem(
                  'This Week',
                  weekReviews.toString(),
                  Icons.date_range,
                  AppTheme.successColor,
                ),
              ),
              Container(
                height: 40,
                width: 1,
                color: AppTheme.dividerColor,
              ),
              Expanded(
                child: _buildStatItem(
                  'Total Reviews',
                  reviews.length.toString(),
                  Icons.assignment_turned_in,
                  AppTheme.infoColor,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildReviewHistoryList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('template_reviews')
          .where('reviewedBy',
              isEqualTo: ref.read(currentUserProvider).value?.id)
          .orderBy('reviewedAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline,
                    size: 64, color: AppTheme.errorColor),
                const SizedBox(height: 16),
                Text(
                  'Error Loading History',
                  style: AppTheme.textTheme.headlineMedium
                      ?.copyWith(color: AppTheme.errorColor),
                ),
                const SizedBox(height: 8),
                Text(
                  snapshot.error.toString(),
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

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final historyItems = snapshot.data?.docs ?? [];

        // Apply filters
        var filteredItems = historyItems.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final templateName =
              (data['templateName'] ?? '').toString().toLowerCase();
          final action = data['action'] ?? '';
          final reviewedAt =
              (data['reviewedAt'] as Timestamp?)?.toDate() ?? DateTime.now();

          final matchesSearch = _searchQuery.isEmpty ||
              templateName.contains(_searchQuery) ||
              (data['templateType'] ?? '')
                  .toString()
                  .toLowerCase()
                  .contains(_searchQuery);

          final matchesAction =
              _selectedAction == 'all' || action == _selectedAction;
          final matchesPeriod = _selectedPeriod == 'all' ||
              _matchesPeriod(reviewedAt, _selectedPeriod);

          return matchesSearch && matchesAction && matchesPeriod;
        }).toList();

        if (filteredItems.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.history_outlined,
                  size: 80,
                  color: AppTheme.textSecondary,
                ),
                const SizedBox(height: 16),
                Text(
                  'No History Records',
                  style: AppTheme.textTheme.headlineMedium?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'No review records match your filter criteria.',
                  style: AppTheme.textTheme.bodyLarge?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: _refreshData,
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: filteredItems.length,
            itemBuilder: (context, index) {
              final doc = filteredItems[index];
              final data = doc.data() as Map<String, dynamic>;
              return FadeInUp(
                duration: Duration(milliseconds: 300 + (index * 100)),
                child: _buildHistoryCard(doc.id, data, index),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildHistoryCard(
      String reviewId, Map<String, dynamic> data, int index) {
    final action = data['action'] ?? 'unknown';
    final reviewedAt =
        (data['reviewedAt'] as Timestamp?)?.toDate() ?? DateTime.now();

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      elevation: 2,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _viewHistoryDetails(reviewId, data),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _getActionColor(action).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      _getActionIcon(action),
                      color: _getActionColor(action),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          data['templateName'] ?? 'Unknown Template',
                          style: AppTheme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Type: ${data['templateType'] ?? 'Unknown'}',
                          style: AppTheme.textTheme.bodyMedium?.copyWith(
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildActionBadge(action),
                ],
              ),
              const SizedBox(height: 12),
              if (data['feedback'] != null &&
                  data['feedback'].toString().isNotEmpty) ...[
                Text(
                  'Feedback: ${data['feedback']}',
                  style: AppTheme.textTheme.bodyMedium,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),
              ],
              if (data['reason'] != null &&
                  data['reason'].toString().isNotEmpty) ...[
                Text(
                  'Reason: ${data['reason']}',
                  style: AppTheme.textTheme.bodyMedium,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),
              ],
              Row(
                children: [
                  Icon(
                    Icons.access_time,
                    size: 16,
                    color: AppTheme.textSecondary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _formatDate(reviewedAt),
                    style: AppTheme.textTheme.bodySmall?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: AppTheme.textSecondary,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionBadge(String action) {
    Color color;
    String text;
    IconData icon;

    switch (action) {
      case 'approved':
        color = AppTheme.successColor;
        text = 'Approved';
        icon = Icons.check_circle;
        break;
      case 'rejected':
        color = AppTheme.errorColor;
        text = 'Rejected';
        icon = Icons.cancel;
        break;
      case 'needs_revision':
        color = AppTheme.warningColor;
        text = 'Revision Requested';
        icon = Icons.edit;
        break;
      default:
        color = AppTheme.textSecondary;
        text = 'Unknown';
        icon = Icons.help;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
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

  bool _matchesPeriod(DateTime date, String period) {
    final now = DateTime.now();
    switch (period) {
      case 'today':
        return date.year == now.year &&
            date.month == now.month &&
            date.day == now.day;
      case 'week':
        final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
        return date.isAfter(startOfWeek);
      case 'month':
        return date.year == now.year && date.month == now.month;
      case 'year':
        return date.year == now.year;
      default:
        return true;
    }
  }

  Future<void> _refreshData() async {
    setState(() {
      _isLoading = true;
    });

    await Future.delayed(const Duration(seconds: 1)); // Simulate network delay

    setState(() {
      _isLoading = false;
    });
  }

  void _viewHistoryDetails(String reviewId, Map<String, dynamic> data) {
    showDialog(
      context: context,
      builder: (context) => _HistoryDetailDialog(
        reviewId: reviewId,
        reviewData: data,
      ),
    );
  }

  Widget _buildReviewHistoryTab() {
    return Column(
      children: [
        _buildFilterBar(),
        _buildReviewStatsCard(),
        Expanded(
          child: _buildReviewHistoryList(),
        ),
      ],
    );
  }
}

class _HistoryDetailDialog extends StatelessWidget {
  final String reviewId;
  final Map<String, dynamic> reviewData;

  const _HistoryDetailDialog({
    required this.reviewId,
    required this.reviewData,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        constraints: const BoxConstraints(
          maxWidth: 600,
          maxHeight: 700,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.history,
                    size: 32,
                    color: AppTheme.primaryColor,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      'Review Details',
                      style: AppTheme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDetailRow('Template Name',
                        reviewData['templateName'] ?? 'Unknown Template'),
                    _buildDetailRow('Template Type',
                        reviewData['templateType'] ?? 'Unknown'),
                    _buildDetailRow(
                        'Action', reviewData['action'] ?? 'Unknown'),
                    _buildDetailRow(
                        'Reviewed At',
                        ((reviewData['reviewedAt'] as Timestamp?)?.toDate() ??
                                DateTime.now())
                            .toString()),
                    if (reviewData['feedback'] != null &&
                        reviewData['feedback'].toString().isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Text(
                        'Feedback',
                        style: AppTheme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        reviewData['feedback'],
                        style: AppTheme.textTheme.bodyMedium,
                      ),
                    ],
                    if (reviewData['reason'] != null &&
                        reviewData['reason'].toString().isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Text(
                        'Reason',
                        style: AppTheme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        reviewData['reason'],
                        style: AppTheme.textTheme.bodyMedium,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppTheme.backgroundLight,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Close'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: AppTheme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: AppTheme.textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}
