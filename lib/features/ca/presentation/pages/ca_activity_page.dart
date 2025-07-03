import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../providers/ca_providers.dart';

class CAActivityPage extends ConsumerStatefulWidget {
  const CAActivityPage({super.key});

  @override
  ConsumerState<CAActivityPage> createState() => _CAActivityPageState();
}

class _CAActivityPageState extends ConsumerState<CAActivityPage> {
  final ScrollController _scrollController = ScrollController();
  String? _selectedFilter;
  
  @override
  Widget build(BuildContext context) {
    final activitiesAsync = ref.watch(caActivityProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Activity Log'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list),
            onSelected: (value) {
              setState(() {
                _selectedFilter = value == 'all' ? null : value;
              });
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'all',
                child: Text('All Activities'),
              ),
              const PopupMenuItem(
                value: 'certificate_created',
                child: Text('Certificates Created'),
              ),
              const PopupMenuItem(
                value: 'document_approved',
                child: Text('Documents Approved'),
              ),
              const PopupMenuItem(
                value: 'document_rejected',
                child: Text('Documents Rejected'),
              ),
              const PopupMenuItem(
                value: 'certificate_revoked',
                child: Text('Certificates Revoked'),
              ),
            ],
          ),
        ],
      ),
      body: activitiesAsync.when(
        data: (activities) {
          final filteredActivities = _selectedFilter == null
              ? activities
              : activities.where((a) => a.action == _selectedFilter).toList();

          if (filteredActivities.isEmpty) {
            return _buildEmptyState();
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(caActivityProvider);
            },
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(AppTheme.spacingM),
              itemCount: filteredActivities.length,
              itemBuilder: (context, index) {
                final activity = filteredActivities[index];
                return _buildActivityCard(activity, index);
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => _buildErrorState(error.toString()),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.history,
            size: 80,
            color: AppTheme.textSecondary.withValues(alpha: 0.5),
          ),
          const SizedBox(height: AppTheme.spacingL),
          Text(
            'No Activities Found',
            style: AppTheme.titleLarge.copyWith(
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: AppTheme.spacingS),
          Text(
            _selectedFilter != null
                ? 'No activities match the selected filter'
                : 'Your activity log is empty',
            style: AppTheme.bodyMedium.copyWith(
              color: AppTheme.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
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
            'Error loading activities',
            style: AppTheme.titleLarge.copyWith(
              color: AppTheme.errorColor,
            ),
          ),
          const SizedBox(height: AppTheme.spacingS),
          Text(
            error,
            style: AppTheme.bodySmall.copyWith(
              color: AppTheme.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppTheme.spacingL),
          ElevatedButton(
            onPressed: () => ref.invalidate(caActivityProvider),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityCard(CAActivity activity, int index) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppTheme.spacingM),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor:
              _getActivityColor(activity.action).withValues(alpha: 0.2),
          child: Icon(
            _getActivityIcon(activity.action),
            color: _getActivityColor(activity.action),
            size: 20,
          ),
        ),
        title: Text(
          activity.description,
          style: AppTheme.titleSmall,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              _formatActivityAction(activity.action),
              style: AppTheme.bodySmall.copyWith(
                color: _getActivityColor(activity.action),
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              _formatDateTime(activity.timestamp),
              style: AppTheme.bodySmall.copyWith(
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
        trailing: activity.metadata.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.info_outline),
                onPressed: () => _showActivityDetails(activity),
              )
            : null,
      ),
    );
  }

  void _showActivityDetails(CAActivity activity) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_formatActivityAction(activity.action)),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Description',
                style: AppTheme.titleSmall.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(activity.description),
              const SizedBox(height: AppTheme.spacingM),
              Text(
                'Timestamp',
                style: AppTheme.titleSmall.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(_formatDateTime(activity.timestamp)),
              if (activity.metadata.isNotEmpty) ...[
                const SizedBox(height: AppTheme.spacingM),
                Text(
                  'Additional Details',
                  style: AppTheme.titleSmall.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                ...activity.metadata.entries.map((entry) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${entry.key}: ',
                        style: AppTheme.bodySmall.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          entry.value.toString(),
                          style: AppTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                )),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Color _getActivityColor(String action) {
    switch (action) {
      case 'certificate_created':
      case 'document_approved':
        return AppTheme.successColor;
      case 'document_rejected':
      case 'certificate_revoked':
        return AppTheme.errorColor;
      case 'draft_saved':
      case 'settings_updated':
        return AppTheme.infoColor;
      default:
        return AppTheme.primaryColor;
    }
  }

  IconData _getActivityIcon(String action) {
    switch (action) {
      case 'certificate_created':
        return Icons.verified;
      case 'document_approved':
        return Icons.check_circle;
      case 'document_rejected':
        return Icons.cancel;
      case 'certificate_revoked':
        return Icons.block;
      case 'draft_saved':
        return Icons.save;
      case 'settings_updated':
        return Icons.settings;
      case 'template_uploaded':
        return Icons.upload;
      case 'pdf_generated':
        return Icons.picture_as_pdf;
      default:
        return Icons.history;
    }
  }

  String _formatActivityAction(String action) {
    return action
        .split('_')
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        if (difference.inMinutes == 0) {
          return 'Just now';
        }
        return '${difference.inMinutes} minutes ago';
      }
      return '${difference.inHours} hours ago';
    } else if (difference.inDays == 1) {
      return 'Yesterday at ${DateFormat('HH:mm').format(dateTime)}';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return DateFormat('MMM dd, yyyy HH:mm').format(dateTime);
    }
  }
} 
