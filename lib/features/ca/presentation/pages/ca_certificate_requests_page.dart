import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:animate_do/animate_do.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/models/certificate_request_model.dart';
import '../../../../core/services/logger_service.dart';
import '../../../auth/providers/auth_providers.dart';
import '../../../../core/services/certificate_request_service.dart';

final caRequestsProvider =
    StreamProvider.family<List<CertificateRequestModel>, String>((ref, caId) {
  final service = ref.read(certificateRequestServiceProvider);
  return service.getRequestsForCA(caId);
});

final certificateRequestServiceProvider =
    Provider((ref) => CertificateRequestService());

class CACertificateRequestsPage extends ConsumerStatefulWidget {
  const CACertificateRequestsPage({super.key});

  @override
  ConsumerState<CACertificateRequestsPage> createState() =>
      _CACertificateRequestsPageState();
}

class _CACertificateRequestsPageState
    extends ConsumerState<CACertificateRequestsPage> {
  String _selectedFilter = 'all';
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserProvider).value;

    if (currentUser == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final requestsAsync = ref.watch(caRequestsProvider(currentUser.id));

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        title: const Text('Certificate Requests'),
        elevation: 0,
        backgroundColor: AppTheme.primaryColor,
      ),
      body: Column(
        children: [
          // Search and filter bar
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Search bar
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search requests...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppTheme.dividerColor),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppTheme.dividerColor),
                    ),
                  ),
                  onChanged: (value) {
                    setState(() {});
                  },
                ),
                const SizedBox(height: 16),
                // Filter chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip('All', 'all'),
                      const SizedBox(width: 8),
                      _buildFilterChip('Pending', RequestStatus.submitted.name),
                      const SizedBox(width: 8),
                      _buildFilterChip(
                          'Under Review', RequestStatus.underReview.name),
                      const SizedBox(width: 8),
                      _buildFilterChip('Changes Requested',
                          RequestStatus.changesRequested.name),
                      const SizedBox(width: 8),
                      _buildFilterChip('Approved', RequestStatus.approved.name),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Requests list
          Expanded(
            child: requestsAsync.when(
              data: (requests) {
                final filteredRequests = _filterRequests(requests);

                if (filteredRequests.isEmpty) {
                  return _buildEmptyState();
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filteredRequests.length,
                  itemBuilder: (context, index) {
                    final request = filteredRequests[index];
                    return FadeInUp(
                      duration: Duration(milliseconds: 300 + (index * 100)),
                      child: _buildRequestCard(request),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline,
                        size: 64, color: AppTheme.errorColor),
                    const SizedBox(height: 16),
                    Text('Error loading requests: $error'),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () =>
                          ref.refresh(caRequestsProvider(currentUser.id)),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _selectedFilter == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedFilter = selected ? value : 'all';
        });
      },
      backgroundColor: isSelected ? AppTheme.primaryColor : Colors.grey[200],
      selectedColor: AppTheme.primaryColor,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : AppTheme.textPrimary,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }

  Widget _buildRequestCard(CertificateRequestModel request) {
    final statusColor = _getStatusColor(request.status);
    final statusIcon = _getStatusIcon(request.status);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      child: InkWell(
        onTap: () => _showRequestDetails(request),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(statusIcon, color: statusColor, size: 24),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      request.clientName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  _buildStatusChip(request.status, statusColor),
                ],
              ),
              const SizedBox(height: 12),
              _buildInfoRow(Icons.business, request.organizationName),
              const SizedBox(height: 4),
              _buildInfoRow(Icons.category, request.certificateType),
              const SizedBox(height: 4),
              _buildInfoRow(
                Icons.access_time,
                DateFormat('MMM dd, yyyy').format(request.createdAt),
              ),
              if (request.purpose.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  request.purpose,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              if (request.status == RequestStatus.submitted) ...[
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      onPressed: () => _performReview(request, 'reject', ''),
                      icon: const Icon(Icons.close, size: 18),
                      label: const Text('Reject'),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.red,
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () => _performReview(request, 'approve', ''),
                      icon: const Icon(Icons.check, size: 18),
                      label: const Text('Approve'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(RequestStatus status, Color backgroundColor) {
    Color textColor;

    switch (status) {
      case RequestStatus.draft:
        textColor = Colors.white;
        break;
      case RequestStatus.submitted:
        textColor = Colors.white;
        break;
      case RequestStatus.underReview:
        textColor = Colors.white;
        break;
      case RequestStatus.approved:
        textColor = Colors.white;
        break;
      case RequestStatus.rejected:
        textColor = Colors.white;
        break;
      case RequestStatus.changesRequested:
        textColor = Colors.white;
        break;
      case RequestStatus.issued:
        textColor = Colors.white;
        break;
      case RequestStatus.cancelled:
        textColor = Colors.white;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.displayName,
        style: AppTheme.bodySmall.copyWith(
          color: textColor,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inbox_outlined,
            size: 80,
            color: AppTheme.textSecondary.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'No Requests Found',
            style: AppTheme.titleLarge.copyWith(
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _selectedFilter == 'all'
                ? 'You have no certificate requests at the moment'
                : 'No requests match the selected filter',
            style: AppTheme.bodyMedium.copyWith(
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  List<CertificateRequestModel> _filterRequests(
      List<CertificateRequestModel> requests) {
    return requests.where((request) {
      // Status filter
      if (_selectedFilter != 'all' && request.status.name != _selectedFilter) {
        return false;
      }

      // Search filter
      if (_searchController.text.isNotEmpty) {
        final query = _searchController.text.toLowerCase();
        return request.clientName.toLowerCase().contains(query) ||
            request.organizationName.toLowerCase().contains(query) ||
            request.certificateType.toLowerCase().contains(query);
      }

      return true;
    }).toList();
  }

  void _showRequestDetails(CertificateRequestModel request) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _RequestDetailsSheet(
        request: request,
        onAction: (action, comments) {
          Navigator.pop(context);
          _performReview(request, action, comments);
        },
      ),
    );
  }

  void _performReview(
    CertificateRequestModel request,
    String action,
    String? comments,
  ) async {
    try {
      final service = ref.read(certificateRequestServiceProvider);
      await service.reviewRequest(
        requestId: request.id,
        action: action,
        comments: comments,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Request ${action == 'approve' ? 'approved' : 'rejected'} successfully'),
            backgroundColor: action == 'approve'
                ? AppTheme.successColor
                : AppTheme.errorColor,
          ),
        );
      }
    } catch (e) {
      LoggerService.error('Failed to review request', error: e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to review request: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  Color _getStatusColor(RequestStatus status) {
    switch (status) {
      case RequestStatus.draft:
        return Colors.grey;
      case RequestStatus.submitted:
        return AppTheme.warningColor;
      case RequestStatus.underReview:
        return AppTheme.infoColor;
      case RequestStatus.approved:
        return AppTheme.successColor;
      case RequestStatus.rejected:
        return AppTheme.errorColor;
      case RequestStatus.changesRequested:
        return Colors.orange;
      case RequestStatus.issued:
        return Colors.green;
      case RequestStatus.cancelled:
        return Colors.red;
    }
  }

  IconData _getStatusIcon(RequestStatus status) {
    switch (status) {
      case RequestStatus.draft:
        return Icons.drafts;
      case RequestStatus.submitted:
        return Icons.pending;
      case RequestStatus.underReview:
        return Icons.hourglass_top;
      case RequestStatus.approved:
        return Icons.check_circle;
      case RequestStatus.rejected:
        return Icons.cancel;
      case RequestStatus.changesRequested:
        return Icons.edit;
      case RequestStatus.issued:
        return Icons.verified;
      case RequestStatus.cancelled:
        return Icons.cancel_outlined;
    }
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

// Request details sheet
class _RequestDetailsSheet extends StatelessWidget {
  final CertificateRequestModel request;
  final Function(String action, String? comments) onAction;

  const _RequestDetailsSheet({
    required this.request,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final commentsController = TextEditingController();

    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.dividerColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),
            // Title
            Text(
              'Review Certificate Request',
              style: AppTheme.headlineSmall,
            ),
            const SizedBox(height: 24),
            // Request details
            Expanded(
              child: SingleChildScrollView(
                controller: scrollController,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDetailSection('Request Information', [
                      _buildDetailItem('Title', request.clientName),
                      _buildDetailItem('Type', request.certificateType),
                      _buildDetailItem('Status', request.status.displayName),
                    ]),
                    const SizedBox(height: 24),
                    _buildDetailSection('Client Information', [
                      _buildDetailItem('Name', request.clientName),
                      _buildDetailItem('Email', request.clientEmail),
                      _buildDetailItem(
                          'Organization', request.organizationName),
                    ]),
                    const SizedBox(height: 24),
                    _buildDetailSection('Request Details', [
                      _buildDetailItem('Description', request.description),
                      _buildDetailItem('Purpose', request.purpose),
                    ]),
                    if (request.requestedData.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      _buildDetailSection(
                        'Additional Information',
                        request.requestedData.entries.map((entry) {
                          return _buildDetailItem(
                            _formatFieldName(entry.key),
                            entry.value.toString(),
                          );
                        }).toList(),
                      ),
                    ],
                    if (request.approvalHistory.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      Text(
                        'Approval History',
                        style: AppTheme.titleMedium,
                      ),
                      const SizedBox(height: 12),
                      ...request.approvalHistory
                          .map((record) => _buildHistoryItem(record)),
                    ],
                    const SizedBox(height: 24),
                    // Comments field
                    Text(
                      'Comments',
                      style: AppTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: commentsController,
                      decoration: const InputDecoration(
                        hintText: 'Add comments for the client...',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 3,
                    ),
                  ],
                ),
              ),
            ),
            // Actions
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () =>
                        onAction('request_changes', commentsController.text),
                    child: const Text('Request Changes'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () =>
                        onAction('approve', commentsController.text),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.successColor,
                    ),
                    child: const Text('Approve'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailSection(String title, List<Widget> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: AppTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.backgroundLight,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: items,
          ),
        ),
      ],
    );
  }

  Widget _buildDetailItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: AppTheme.bodyMedium.copyWith(
                color: AppTheme.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: AppTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryItem(ApprovalRecord record) {
    IconData icon;
    Color color;

    switch (record.action) {
      case ApprovalAction.approved:
        icon = Icons.check_circle;
        color = AppTheme.successColor;
        break;
      case ApprovalAction.rejected:
        icon = Icons.cancel;
        color = AppTheme.errorColor;
        break;
      case ApprovalAction.changesRequested:
        icon = Icons.edit;
        color = Colors.orange;
        break;
      case ApprovalAction.assigned:
        icon = Icons.send;
        color = AppTheme.infoColor;
        break;
      case ApprovalAction.forwarded:
        icon = Icons.forward;
        color = AppTheme.primaryColor;
        break;
      case ApprovalAction.infoRequested:
        icon = Icons.info_outline;
        color = Colors.blue;
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: AppTheme.dividerColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${record.reviewerName} - ${record.action.displayName.toUpperCase()}',
                  style: AppTheme.bodyMedium.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (record.comments != null && record.comments!.isNotEmpty)
                  Text(
                    record.comments!,
                    style: AppTheme.bodySmall.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                  ),
                Text(
                  DateFormat('MMM d, y h:mm a').format(record.timestamp),
                  style: AppTheme.bodySmall.copyWith(
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

  String _formatFieldName(String key) {
    return key
        .replaceAllMapped(
          RegExp(r'([A-Z])'),
          (match) => ' ${match.group(0)}',
        )
        .trim()
        .split(' ')
        .map((word) {
      return word.substring(0, 1).toUpperCase() + word.substring(1);
    }).join(' ');
  }
}
