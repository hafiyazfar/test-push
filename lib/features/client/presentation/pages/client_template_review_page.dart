import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:animate_do/animate_do.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/custom_app_bar.dart';
import '../../../../core/services/logger_service.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../core/providers/unified_data_providers.dart';
import '../../../../core/models/certificate_model.dart';
import '../../../auth/providers/auth_providers.dart';
import 'package:uuid/uuid.dart';
import 'dart:math';

// ✅ Use unified data providers
// No more duplicate definitions, use unifiedPendingTemplatesProvider from unified_data_providers.dart

// Provider for client review statistics
final clientReviewStatsProvider = StreamProvider<Map<String, int>>((ref) {
  final userId = ref.watch(currentUserProvider).value?.id;
  if (userId == null) return Stream.value({});

  return FirebaseFirestore.instance
      .collection('template_reviews')
      .where('reviewedBy', isEqualTo: userId)
      .snapshots()
      .map((snapshot) {
    final reviews = snapshot.docs;
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);

    int pending = 0;
    int approvedToday = 0;
    int rejected = 0;
    int approved = 0;

    for (final doc in reviews) {
      final data = doc.data();
      final action = data['action'] as String? ?? '';
      final reviewedAt = (data['reviewedAt'] as Timestamp?)?.toDate();

      if (action == 'approved') approved++;
      if (action == 'rejected') rejected++;
      if (action == 'pending') pending++;

      if (reviewedAt != null &&
          reviewedAt.isAfter(startOfDay) &&
          action == 'approved') {
        approvedToday++;
      }
    }

    return {
      'pending': pending,
      'approvedToday': approvedToday,
      'approved': approved,
      'rejected': rejected,
      'total': reviews.length,
    };
  });
});

class ClientTemplateReviewPage extends ConsumerStatefulWidget {
  const ClientTemplateReviewPage({super.key});

  @override
  ConsumerState<ClientTemplateReviewPage> createState() =>
      _ClientTemplateReviewPageState();
}

class _ClientTemplateReviewPageState
    extends ConsumerState<ClientTemplateReviewPage>
    with TickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _reviewCommentsController =
      TextEditingController();
  late AnimationController _refreshAnimationController;
  String _searchQuery = '';
  String _selectedStatus = 'pending_client_review';
  bool _isReviewing = false;

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
    _searchController.dispose();
    _reviewCommentsController.dispose();
    _refreshAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserProvider).value;

    // 🔍 Detailed debug information
    if (kDebugMode) {
      LoggerService.debug('🔵 ClientTemplateReviewPage build() called');
      LoggerService.debug('🔵 Current user: ${currentUser?.email}');
      LoggerService.debug('🔵 User type: ${currentUser?.userType}');
      LoggerService.debug('🔵 User status: ${currentUser?.status}');
      LoggerService.debug('🔵 Is client type: ${currentUser?.isClientType}');
      LoggerService.debug('🔵 Is active: ${currentUser?.isActive}');
      LoggerService.debug('🔵 Is admin: ${currentUser?.isAdmin}');
      LoggerService.debug(
          '🔵 Can access client panel: ${currentUser?.canAccessClientPanel}');
      LoggerService.debug(
          '🔵 Can access path /client/template-review: ${currentUser?.canAccessPath('/client/template-review')}');
      LoggerService.debug(
          '🔵 Permission check result: ${currentUser == null || (!currentUser.isClientType && !currentUser.isAdmin)}');
    }

    if (currentUser == null ||
        (!currentUser.isClientType && !currentUser.isAdmin)) {
      if (kDebugMode) {
        LoggerService.error(
            '🔴 ClientTemplateReviewPage - Access denied, redirecting back');
      }

      return Scaffold(
        appBar: const CustomAppBar(title: 'Certificate Approve Center'),
        body: Center(
          child: Semantics(
            label: 'Access denied for template review',
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
                  'You do not have permission to review templates.',
                  style: AppTheme.textTheme.bodyLarge?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                if (kDebugMode) ...[
                  Container(
                    padding: const EdgeInsets.all(8),
                    margin: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      border: Border.all(color: Colors.red[300]!),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'DEBUG INFO:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.red[700],
                          ),
                        ),
                        Text('User: ${currentUser?.email ?? "null"}'),
                        Text('Type: ${currentUser?.userType ?? "null"}'),
                        Text(
                            'isClient: ${currentUser?.isClientType ?? "null"}'),
                        Text('isAdmin: ${currentUser?.isAdmin ?? "null"}'),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    if (kDebugMode) {
                      LoggerService.debug('🔵 Go to Dashboard button pressed');
                    }
                    context.go('/client/dashboard');
                  },
                  child: const Text('Go to Dashboard'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (kDebugMode) {
      LoggerService.debug(
          '🟢 ClientTemplateReviewPage - Access granted, showing main content');
    }

    return Scaffold(
      appBar: AppBar(
        title: Semantics(
          header: true,
          child: const Text('Certificate Approve Center'),
        ),
        actions: [
          RotationTransition(
            turns: _refreshAnimationController,
            child: Semantics(
              label: 'Refresh templates',
              button: true,
              child: IconButton(
                onPressed: _isReviewing
                    ? null
                    : () async {
                        _refreshAnimationController.forward().then((_) {
                          _refreshAnimationController.reset();
                        });
                        // ignore: unused_result
                        ref.refresh(unifiedPendingTemplatesProvider);
                      },
                icon: const Icon(Icons.refresh),
                tooltip: 'Refresh Templates',
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFilterBar(),
          _buildReviewStats(),
          Expanded(
            child: _buildTemplatesList(),
          ),
        ],
      ),
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
      child: Semantics(
        label: 'Template search and filter controls',
        child: Column(
          children: [
            // Search Bar
            Semantics(
              label: 'Search templates by name, creator, or type',
              child: TextFormField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search templates by name, creator, or type...',
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
            ),
            const SizedBox(height: 12),
            // Status Filter
            Row(
              children: [
                Expanded(
                  child: Semantics(
                    label: 'Filter templates by review status',
                    child: DropdownButtonFormField<String>(
                      value: _selectedStatus,
                      decoration: const InputDecoration(
                        labelText: 'Review Status',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                            value: 'pending_client_review',
                            child: Text('Pending Review')),
                        DropdownMenuItem(
                            value: 'client_approved', child: Text('Approved')),
                        DropdownMenuItem(
                            value: 'client_rejected', child: Text('Rejected')),
                        DropdownMenuItem(
                            value: 'needs_revision',
                            child: Text('Needs Revision')),
                        DropdownMenuItem(
                            value: 'all', child: Text('All Status')),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _selectedStatus = value ?? 'pending_client_review';
                        });
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Semantics(
                  label: 'Refresh template list',
                  button: true,
                  child: ElevatedButton.icon(
                    onPressed: _isReviewing
                        ? null
                        : () {
                            // ignore: unused_result
                            ref.refresh(unifiedPendingTemplatesProvider);
                          },
                    icon: _isReviewing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh),
                    label: const Text('Refresh'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReviewStats() {
    final statsAsync = ref.watch(clientReviewStatsProvider);

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
      child: Semantics(
        label: 'Review statistics summary',
        child: statsAsync.when(
          data: (stats) => Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  'Pending Review',
                  '${stats['pending'] ?? 0}',
                  Icons.pending_actions,
                  AppTheme.warningColor,
                ),
              ),
              Container(height: 40, width: 1, color: AppTheme.dividerColor),
              Expanded(
                child: _buildStatItem(
                  'Approved Today',
                  '${stats['approvedToday'] ?? 0}',
                  Icons.check_circle,
                  AppTheme.successColor,
                ),
              ),
              Container(height: 40, width: 1, color: AppTheme.dividerColor),
              Expanded(
                child: _buildStatItem(
                  'Total Approved',
                  '${stats['approved'] ?? 0}',
                  Icons.verified,
                  AppTheme.primaryColor,
                ),
              ),
              Container(height: 40, width: 1, color: AppTheme.dividerColor),
              Expanded(
                child: _buildStatItem(
                  'Rejected',
                  '${stats['rejected'] ?? 0}',
                  Icons.cancel,
                  AppTheme.errorColor,
                ),
              ),
            ],
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => const Text('Error loading stats'),
        ),
      ),
    );
  }

  Widget _buildStatItem(
      String label, String value, IconData icon, Color color) {
    return Semantics(
      label: '$label: $value',
      child: Column(
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
      ),
    );
  }

  Widget _buildTemplatesList() {
    final templatesAsync = ref.watch(unifiedPendingTemplatesProvider);

    return templatesAsync.when(
      data: (templates) {
        // Apply filters
        final filteredTemplates = templates.where((template) {
          // Search filter
          if (_searchQuery.isNotEmpty) {
            final name = (template['name'] ?? '').toString().toLowerCase();
            final creator =
                (template['createdByName'] ?? '').toString().toLowerCase();
            final type = (template['type'] ?? '').toString().toLowerCase();

            final searchMatch = name.contains(_searchQuery) ||
                creator.contains(_searchQuery) ||
                type.contains(_searchQuery);
            if (!searchMatch) return false;
          }

          // Status filter
          final status = template['status'] ?? 'pending_client_review';
          if (_selectedStatus != 'all' && status != _selectedStatus) {
            return false;
          }

          return true;
        }).toList();

        if (filteredTemplates.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.design_services_outlined,
                  size: 80,
                  color: AppTheme.textSecondary,
                ),
                const SizedBox(height: 16),
                Text(
                  'No Templates Found',
                  style: AppTheme.textTheme.headlineMedium?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'No templates match your current filter criteria.',
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
          onRefresh: () async {
            return ref.refresh(unifiedPendingTemplatesProvider);
          },
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: filteredTemplates.length,
            itemBuilder: (context, index) {
              final template = filteredTemplates[index];
              return FadeInUp(
                duration: Duration(milliseconds: 300 + (index * 100)),
                child: _buildTemplateCard(template, index),
              );
            },
          ),
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
            Text(
              'Error Loading Templates',
              style: AppTheme.textTheme.headlineMedium
                  ?.copyWith(color: AppTheme.errorColor),
            ),
            const SizedBox(height: 8),
            Text(
              error.toString(),
              style: AppTheme.textTheme.bodyMedium
                  ?.copyWith(color: AppTheme.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                // ignore: unused_result
                ref.refresh(unifiedPendingTemplatesProvider);
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTemplateCard(Map<String, dynamic> template, int index) {
    final status = template['status'] ?? 'pending_client_review';
    final createdAt =
        (template['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
    final templateId = template['id'] as String;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _viewTemplateDetails(templateId, template),
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
                      color: _getTemplateTypeColor(template['type'])
                          .withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      _getTemplateTypeIcon(template['type']),
                      color: _getTemplateTypeColor(template['type']),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          template['name'] ?? 'Unnamed Template',
                          style: AppTheme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Created by: ${template['createdByName'] ?? 'Unknown CA'}',
                          style: AppTheme.textTheme.bodyMedium?.copyWith(
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildStatusBadge(status),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                template['description'] ?? 'No description available',
                style: AppTheme.textTheme.bodyMedium,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              _buildInfoRow(
                  Icons.category, 'Type: ${template['type'] ?? 'General'}'),
              const SizedBox(height: 4),
              _buildInfoRow(Icons.access_time,
                  'Created: ${DateFormat('MMM dd, yyyy').format(createdAt)}'),
              if (template['institution'] != null) ...[
                const SizedBox(height: 4),
                _buildInfoRow(
                    Icons.business, 'Institution: ${template['institution']}'),
              ],
              const SizedBox(height: 12),
              if (status == 'pending_client_review') ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _isReviewing
                          ? null
                          : () => _requestRevision(templateId, template),
                      icon: const Icon(Icons.edit, size: 16),
                      label: const Text('Request Changes'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.warningColor,
                        side: BorderSide(color: AppTheme.warningColor),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: _isReviewing
                          ? null
                          : () => _rejectTemplate(templateId, template),
                      icon: const Icon(Icons.close, size: 16),
                      label: const Text('Reject'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.errorColor,
                        side: BorderSide(color: AppTheme.errorColor),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: _isReviewing
                          ? null
                          : () => _approveTemplate(templateId, template),
                      icon: const Icon(Icons.check, size: 16),
                      label: const Text('Approve'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.successColor,
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

  Widget _buildStatusBadge(String status) {
    Color color;
    String text;
    IconData icon;

    switch (status) {
      case 'pending_client_review':
        color = AppTheme.warningColor;
        text = 'Pending Review';
        icon = Icons.pending;
        break;
      case 'client_approved':
        color = AppTheme.successColor;
        text = 'Approved';
        icon = Icons.check_circle;
        break;
      case 'client_rejected':
        color = AppTheme.errorColor;
        text = 'Rejected';
        icon = Icons.cancel;
        break;
      case 'needs_revision':
        color = AppTheme.infoColor;
        text = 'Needs Revision';
        icon = Icons.edit;
        break;
      default:
        color = Colors.grey;
        text = 'Unknown';
        icon = Icons.help;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            text,
            style: AppTheme.bodySmall.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppTheme.textSecondary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: AppTheme.textTheme.bodySmall?.copyWith(
              color: AppTheme.textSecondary,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Color _getTemplateTypeColor(String? type) {
    switch (type?.toLowerCase()) {
      case 'academic':
        return AppTheme.primaryColor;
      case 'professional':
        return AppTheme.accentColor;
      case 'completion':
        return AppTheme.successColor;
      case 'achievement':
        return AppTheme.warningColor;
      default:
        return Colors.grey;
    }
  }

  IconData _getTemplateTypeIcon(String? type) {
    switch (type?.toLowerCase()) {
      case 'academic':
        return Icons.school;
      case 'professional':
        return Icons.work;
      case 'completion':
        return Icons.check_circle;
      case 'achievement':
        return Icons.emoji_events;
      default:
        return Icons.design_services;
    }
  }

  void _viewTemplateDetails(String templateId, Map<String, dynamic> template) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _TemplateDetailsSheet(
        templateId: templateId,
        template: template,
        onApprove: () => _approveTemplate(templateId, template),
        onReject: () => _rejectTemplate(templateId, template),
        onRequestRevision: () => _requestRevision(templateId, template),
        isReviewing: _isReviewing,
      ),
    );
  }

  Future<void> _approveTemplate(
      String templateId, Map<String, dynamic> template) async {
    setState(() {
      _isReviewing = true;
    });

    try {
      final currentUser = ref.read(currentUserProvider).value!;
      final batch = FirebaseFirestore.instance.batch();

      // Update template status
      final templateRef = FirebaseFirestore.instance
          .collection('certificate_templates')
          .doc(templateId);
      batch.update(templateRef, {
        'status': 'client_approved',
        'clientReviewedBy': currentUser.id,
        'clientReviewedAt': FieldValue.serverTimestamp(),
        'clientComments': 'Template approved by client reviewer',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Create review record
      final reviewRef =
          FirebaseFirestore.instance.collection('template_reviews').doc();
      batch.set(reviewRef, {
        'templateId': templateId,
        'templateName': template['name'] ?? 'Unknown Template',
        'reviewedBy': currentUser.id,
        'reviewerName': currentUser.displayName,
        'reviewerRole': 'client',
        'action': 'approved',
        'comments': 'Template meets all requirements and is approved for use',
        'reviewedAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Create activity log
      final activityRef =
          FirebaseFirestore.instance.collection('activities').doc();
      batch.set(activityRef, {
        'type': 'template_approved_by_client',
        'templateId': templateId,
        'templateName': template['name'],
        'reviewerId': currentUser.id,
        'reviewerName': currentUser.displayName,
        'timestamp': FieldValue.serverTimestamp(),
      });

      await batch.commit();

      // 🔄 CRITICAL: After template approval, automatically create Certificate for Recipient
      await _createCertificateFromApprovedTemplate(templateId, template);

      // Send notification to template creator
      if (template['createdBy'] != null) {
        await NotificationService().sendNotification(
          userId: template['createdBy'],
          title: 'Template Approved',
          message:
              'Your template "${template['name']}" has been approved by client review.',
          type: 'template_approval',
          data: {'templateId': templateId},
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Template approved successfully'),
            backgroundColor: AppTheme.successColor,
          ),
        );
      }
    } catch (e) {
      LoggerService.error('Failed to approve template', error: e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to approve template: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } finally {
      setState(() {
        _isReviewing = false;
      });
    }
  }

  Future<void> _rejectTemplate(
      String templateId, Map<String, dynamic> template) async {
    final reason = await _showRejectDialog();
    if (reason == null || reason.isEmpty) return;

    setState(() {
      _isReviewing = true;
    });

    try {
      final currentUser = ref.read(currentUserProvider).value!;
      final batch = FirebaseFirestore.instance.batch();

      // Update template status
      final templateRef = FirebaseFirestore.instance
          .collection('certificate_templates')
          .doc(templateId);
      batch.update(templateRef, {
        'status': 'client_rejected',
        'clientReviewedBy': currentUser.id,
        'clientReviewedAt': FieldValue.serverTimestamp(),
        'clientRejectionReason': reason,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Create review record
      final reviewRef =
          FirebaseFirestore.instance.collection('template_reviews').doc();
      batch.set(reviewRef, {
        'templateId': templateId,
        'templateName': template['name'] ?? 'Unknown Template',
        'reviewedBy': currentUser.id,
        'reviewerName': currentUser.displayName,
        'reviewerRole': 'client',
        'action': 'rejected',
        'comments': reason,
        'reviewedAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Create activity log
      final activityRef =
          FirebaseFirestore.instance.collection('activities').doc();
      batch.set(activityRef, {
        'type': 'template_rejected_by_client',
        'templateId': templateId,
        'templateName': template['name'],
        'reviewerId': currentUser.id,
        'reviewerName': currentUser.displayName,
        'rejectionReason': reason,
        'timestamp': FieldValue.serverTimestamp(),
      });

      await batch.commit();

      // Send notification to template creator
      if (template['createdBy'] != null) {
        await NotificationService().sendNotification(
          userId: template['createdBy'],
          title: 'Template Rejected',
          message:
              'Your template "${template['name']}" has been rejected. Reason: $reason',
          type: 'template_rejection',
          data: {'templateId': templateId, 'reason': reason},
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Template rejected'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } catch (e) {
      LoggerService.error('Failed to reject template', error: e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to reject template: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } finally {
      setState(() {
        _isReviewing = false;
      });
    }
  }

  Future<void> _requestRevision(
      String templateId, Map<String, dynamic> template) async {
    final reason = await _showRevisionDialog();
    if (reason == null || reason.isEmpty) return;

    setState(() {
      _isReviewing = true;
    });

    try {
      final currentUser = ref.read(currentUserProvider).value!;
      final batch = FirebaseFirestore.instance.batch();

      // Update template status
      final templateRef = FirebaseFirestore.instance
          .collection('certificate_templates')
          .doc(templateId);
      batch.update(templateRef, {
        'status': 'needs_revision',
        'clientReviewedBy': currentUser.id,
        'clientReviewedAt': FieldValue.serverTimestamp(),
        'clientRevisionRequests': reason,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Create review record
      final reviewRef =
          FirebaseFirestore.instance.collection('template_reviews').doc();
      batch.set(reviewRef, {
        'templateId': templateId,
        'templateName': template['name'] ?? 'Unknown Template',
        'reviewedBy': currentUser.id,
        'reviewerName': currentUser.displayName,
        'reviewerRole': 'client',
        'action': 'revision_requested',
        'comments': reason,
        'reviewedAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();

      // Send notification to template creator
      if (template['createdBy'] != null) {
        await NotificationService().sendNotification(
          userId: template['createdBy'],
          title: 'Template Revision Requested',
          message:
              'Revision requested for template "${template['name']}". Comments: $reason',
          type: 'template_revision',
          data: {'templateId': templateId, 'comments': reason},
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Revision requested successfully'),
            backgroundColor: AppTheme.infoColor,
          ),
        );
      }
    } catch (e) {
      LoggerService.error('Failed to request revision', error: e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to request revision: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } finally {
      setState(() {
        _isReviewing = false;
      });
    }
  }

  Future<String?> _showRejectDialog() async {
    _reviewCommentsController.clear();

    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Template'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Please provide a reason for rejecting this template:'),
            const SizedBox(height: 16),
            TextField(
              controller: _reviewCommentsController,
              decoration: const InputDecoration(
                hintText: 'Enter rejection reason...',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () =>
                Navigator.pop(context, _reviewCommentsController.text.trim()),
            style:
                ElevatedButton.styleFrom(backgroundColor: AppTheme.errorColor),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
  }

  Future<String?> _showRevisionDialog() async {
    _reviewCommentsController.clear();

    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Request Revision'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Please specify what changes are needed:'),
            const SizedBox(height: 16),
            TextField(
              controller: _reviewCommentsController,
              decoration: const InputDecoration(
                hintText: 'Enter revision requirements...',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () =>
                Navigator.pop(context, _reviewCommentsController.text.trim()),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.warningColor),
            child: const Text('Request Changes'),
          ),
        ],
      ),
    );
  }

  /// Generate verification code
  String _generateVerificationCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random();
    return List.generate(8, (index) => chars[random.nextInt(chars.length)])
        .join();
  }

  /// 🔄 After template approval, automatically create Certificate for Recipient
  Future<void> _createCertificateFromApprovedTemplate(
      String templateId, Map<String, dynamic> template) async {
    try {
      LoggerService.info(
          '🔄 Creating certificate from approved template: $templateId');

      // 1. Get original document information from template
      final documentId = template['basedOnDocumentId'] as String?;
      final studentName = template['studentName'] as String?;
      String? recipientEmail;
      String? recipientName = studentName;

      if (recipientName == null || recipientName.isEmpty) {
        LoggerService.warning(
            '⚠️ Missing recipient information in template: $templateId');
        return;
      }

      // If no original document ID, directly use template data to create certificate
      if (documentId == null || documentId.isEmpty) {
        await _createCertificateWithTemplateData(
            templateId, template, recipientName);
        return;
      }

      // 2. Get document uploader information
      final documentDoc = await FirebaseFirestore.instance
          .collection('documents')
          .doc(documentId)
          .get();

      if (!documentDoc.exists) {
        LoggerService.warning('⚠️ Document not found: $documentId');
        await _createCertificateWithTemplateData(
            templateId, template, recipientName);
        return;
      }

      final documentData = documentDoc.data()!;
      final uploaderId = documentData['uploaderId'] as String?;

      if (uploaderId == null) {
        LoggerService.warning(
            '⚠️ No uploader ID found in document: $documentId');
        await _createCertificateWithTemplateData(
            templateId, template, recipientName);
        return;
      }

      // 3. Get Recipient user information - CRITICAL: Must get email for certificate matching
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uploaderId)
          .get();

      if (userDoc.exists) {
        final userData = userDoc.data()!;
        recipientEmail = userData['email'] as String?;
        recipientName = userData['displayName'] as String? ?? recipientName;

        LoggerService.info(
            '🎯 Found recipient user: email=$recipientEmail, name=$recipientName');
      } else {
        LoggerService.error(
            '❌ CRITICAL: Recipient user not found for uploaderId: $uploaderId');
        // This is a critical error - we cannot create certificate without recipient email
        throw Exception(
            'Cannot create certificate: Recipient user not found for uploaderId: $uploaderId');
      }

      // 🔥 CRITICAL: Ensure we have a valid email - this is essential for recipient to find their certificate
      if (recipientEmail == null || recipientEmail.isEmpty) {
        LoggerService.error(
            '❌ CRITICAL: No email found for recipient user: $uploaderId');
        throw Exception(
            'Cannot create certificate: No email found for recipient user');
      }

      // 4. Directly create certificate data, using known uploaderId as recipientId
      final currentUser = ref.read(currentUserProvider).value!;
      final certificateId = Uuid().v4();
      final verificationCode = _generateVerificationCode();
      final verificationId = Uuid().v4();

      // Parse certificate type
      final certificateTypeString = template['type'] ?? 'completion';
      final certificateType = CertificateType.values.firstWhere(
        (type) => type.name == certificateTypeString,
        orElse: () => CertificateType.completion,
      );

      // Directly create certificate, ensuring correct recipientId is used
      final certificateData = {
        'id': certificateId,
        'templateId': templateId,
        'issuerId': currentUser.id,
        'issuerName': currentUser.displayName.isNotEmpty
            ? currentUser.displayName
            : 'Certificate Authority',
        'recipientId': uploaderId, // 🔥 Direct use of document uploader ID
        'recipientName': recipientName,
        'recipientEmail':
            recipientEmail, // Now guaranteed to be non-null and non-empty
        'organizationId': currentUser.organizationId ?? 'default_org',
        'organizationName':
            currentUser.organizationName ?? 'Certificate Authority',
        'verificationCode': verificationCode,
        'verificationId': verificationId,
        'title': template['name'] ?? 'Certificate',
        'description': template['description'] ?? '',
        'type': certificateType.name,
        'status': 'issued',
        'issuedAt': FieldValue.serverTimestamp(),
        'expiresAt': null, // Academic certificates don't expire
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'qrCode':
            'QR_${verificationCode}_${DateTime.now().millisecondsSinceEpoch}',
        'hash':
            '${certificateId}_${verificationCode}_${DateTime.now().millisecondsSinceEpoch}'
                .hashCode
                .abs()
                .toString(),
        'metadata': {
          'version': '1.0',
          'issuerSignature':
              '${certificateId}_${currentUser.id}_${DateTime.now().millisecondsSinceEpoch}'
                  .hashCode
                  .abs()
                  .toString(),
          'templateId': templateId,
          'institution': template['institution'] ?? '',
          'course': template['course'] ?? '',
          'basedOnDocumentId': documentId,
          'autoCreatedFromTemplate': true,
          'templateApprovedBy': currentUser.id,
          'issuerType': 'client',
          'verificationUrl':
              'https://upm-digital-certificates.web.app/verify?id=$certificateId&code=$verificationCode',
        },
        'shareCount': 0,
        'verificationCount': 0,
        'accessCount': 0,
        'shareTokens': [],
      };

      // Create certificate document with detailed logging
      LoggerService.info(
          '🎯 Creating certificate with data: recipientId=$uploaderId, recipientEmail=$recipientEmail, recipientName=$recipientName');

      await FirebaseFirestore.instance
          .collection('certificates')
          .doc(certificateId)
          .set(certificateData);

      // 6. Record certificate creation activity
      await FirebaseFirestore.instance.collection('activities').add({
        'type': 'certificate_auto_created',
        'certificateId': certificateId,
        'templateId': templateId,
        'recipientId': uploaderId,
        'recipientName': recipientName,
        'recipientEmail': recipientEmail,
        'createdBy': ref.read(currentUserProvider).value?.id,
        'createdByName': ref.read(currentUserProvider).value?.displayName,
        'timestamp': FieldValue.serverTimestamp(),
        'source': 'template_approval',
      });

      LoggerService.info(
          '✅ Certificate created successfully for recipient: $recipientName (ID: $certificateId, Email: $recipientEmail)');
    } catch (e) {
      LoggerService.error(
          'Failed to create certificate from approved template: $templateId',
          error: e);
    }
  }

  /// Use template data to directly create certificate (when original document not found)
  Future<void> _createCertificateWithTemplateData(String templateId,
      Map<String, dynamic> template, String recipientName) async {
    try {
      LoggerService.warning(
          '⚠️ Creating certificate with template data only (no original document): $templateId');

      final currentUser = ref.read(currentUserProvider).value!;
      final certificateId = const Uuid().v4();
      final verificationCode = _generateVerificationCode();
      final verificationId = const Uuid().v4();

      // Parse certificate type
      final certificateTypeString = template['type'] ?? 'completion';
      final certificateType = CertificateType.values.firstWhere(
        (type) => type.name == certificateTypeString,
        orElse: () => CertificateType.completion,
      );

      // 🔄 Try to find recipient by name instead of using pending ID
      String recipientId = 'pending_${const Uuid().v4()}';
      String recipientEmail = 'unknown@example.com';

      // Try to find recipient user by display name as last resort
      try {
        final possibleUsers = await FirebaseFirestore.instance
            .collection('users')
            .where('displayName', isEqualTo: recipientName)
            .limit(1)
            .get();

        if (possibleUsers.docs.isNotEmpty) {
          final userData = possibleUsers.docs.first.data();
          recipientId = possibleUsers.docs.first.id;
          recipientEmail =
              userData['email'] as String? ?? 'unknown@example.com';
          LoggerService.info(
              '🎯 Found recipient by name search: $recipientEmail');
        } else {
          LoggerService.warning(
              '⚠️ Could not find recipient user by name: $recipientName');
        }
      } catch (e) {
        LoggerService.error('Failed to search for recipient by name: $e');
      }

      final certificateData = {
        'id': certificateId,
        'templateId': templateId,
        'issuerId': currentUser.id,
        'issuerName': currentUser.displayName.isNotEmpty
            ? currentUser.displayName
            : 'Certificate Authority',
        'recipientId': recipientId,
        'recipientName': recipientName,
        'recipientEmail': recipientEmail,
        'organizationId': currentUser.organizationId ?? 'default_org',
        'organizationName':
            currentUser.organizationName ?? 'Certificate Authority',
        'verificationCode': verificationCode,
        'verificationId': verificationId,
        'title': template['name'] ?? 'Certificate',
        'description': template['description'] ?? '',
        'type': certificateType.name,
        'status': 'issued',
        'issuedAt': FieldValue.serverTimestamp(),
        'expiresAt': null,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'qrCode':
            'QR_${verificationCode}_${DateTime.now().millisecondsSinceEpoch}',
        'hash':
            '${certificateId}_${verificationCode}_${DateTime.now().millisecondsSinceEpoch}'
                .hashCode
                .abs()
                .toString(),
        'metadata': {
          'version': '1.0',
          'issuerSignature':
              '${certificateId}_${currentUser.id}_${DateTime.now().millisecondsSinceEpoch}'
                  .hashCode
                  .abs()
                  .toString(),
          'templateId': templateId,
          'institution': template['institution'] ?? '',
          'course': template['course'] ?? '',
          'autoCreatedFromTemplate': true,
          'templateApprovedBy': currentUser.id,
          'issuerType': 'client',
          'needsClaiming':
              true, // Mark this certificate as needing to be claimed
          'verificationUrl':
              'https://upm-digital-certificates.web.app/verify?id=$certificateId&code=$verificationCode',
        },
        'shareCount': 0,
        'verificationCount': 0,
        'accessCount': 0,
        'shareTokens': [],
      };

      await FirebaseFirestore.instance
          .collection('certificates')
          .doc(certificateId)
          .set(certificateData);

      // Record creation activity
      await FirebaseFirestore.instance.collection('activities').add({
        'type': 'certificate_auto_created',
        'certificateId': certificateId,
        'templateId': templateId,
        'recipientId': recipientId,
        'recipientName': recipientName,
        'recipientEmail': recipientEmail,
        'createdBy': ref.read(currentUserProvider).value?.id,
        'createdByName': ref.read(currentUserProvider).value?.displayName,
        'timestamp': FieldValue.serverTimestamp(),
        'source': 'template_approval_fallback',
        'needsClaiming': recipientEmail == 'unknown@example.com',
      });

      LoggerService.info(
          '✅ Certificate created with template data for: $recipientName (ID: $certificateId, Email: $recipientEmail)');
    } catch (e) {
      LoggerService.error(
          'Failed to create certificate with template data: $templateId',
          error: e);
    }
  }
}

// Template details sheet widget
class _TemplateDetailsSheet extends StatelessWidget {
  final String templateId;
  final Map<String, dynamic> template;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final VoidCallback onRequestRevision;
  final bool isReviewing;

  const _TemplateDetailsSheet({
    required this.templateId,
    required this.template,
    required this.onApprove,
    required this.onReject,
    required this.onRequestRevision,
    required this.isReviewing,
  });

  @override
  Widget build(BuildContext context) {
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
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),
            // Title
            Text(
              'Template Details',
              style: AppTheme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            // Content
            Expanded(
              child: SingleChildScrollView(
                controller: scrollController,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDetailRow('Template Name', template['name'] ?? 'N/A'),
                    _buildDetailRow('Template Type', template['type'] ?? 'N/A'),
                    _buildDetailRow(
                        'Created By', template['createdByName'] ?? 'N/A'),
                    _buildDetailRow(
                        'Description', template['description'] ?? 'N/A'),
                    if (template['institution'] != null)
                      _buildDetailRow(
                          'Institution', template['institution'].toString()),
                    if (template['course'] != null)
                      _buildDetailRow('Course', template['course'].toString()),
                    _buildDetailRow(
                        'Created Date',
                        template['createdAt'] != null
                            ? DateFormat('MMM dd, yyyy HH:mm').format(
                                (template['createdAt'] as Timestamp).toDate())
                            : 'N/A'),
                    _buildDetailRow('Status', template['status'] ?? 'Unknown'),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
            // Action buttons
            if (template['status'] == 'pending_client_review') ...[
              Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: isReviewing
                              ? null
                              : () {
                                  Navigator.pop(context);
                                  onRequestRevision();
                                },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.warningColor,
                            side: BorderSide(color: AppTheme.warningColor),
                          ),
                          child: const Text('Request Changes'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: isReviewing
                              ? null
                              : () {
                                  Navigator.pop(context);
                                  onReject();
                                },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.errorColor,
                            side: BorderSide(color: AppTheme.errorColor),
                          ),
                          child: const Text('Reject'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: isReviewing
                          ? null
                          : () {
                              Navigator.pop(context);
                              onApprove();
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.successColor,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Approve Template'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: AppTheme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
                color: AppTheme.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: 16),
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
