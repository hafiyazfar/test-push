import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:animate_do/animate_do.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/custom_app_bar.dart';
import '../../../../core/models/document_model.dart';
import '../../../../core/services/logger_service.dart';
import '../../../../core/services/notification_service.dart';
import '../../../auth/providers/auth_providers.dart';

// Provider for real-time pending documents
final pendingDocumentsProvider = StreamProvider<List<DocumentModel>>((ref) {
  return FirebaseFirestore.instance
      .collection('documents')
      .where('status', isEqualTo: 'pending') // 🔄 修正状态匹配
      .orderBy('uploadedAt', descending: true)
      .snapshots()
      .map((snapshot) => snapshot.docs
          .map((doc) => DocumentModel.fromFirestore(doc))
          .toList());
});

// Provider for CA document statistics
final caDocumentStatsProvider = StreamProvider<Map<String, int>>((ref) {
  final userId = ref.watch(currentUserProvider).value?.id;
  if (userId == null) return Stream.value({});

  return FirebaseFirestore.instance
      .collection('documents')
      .snapshots()
      .map((snapshot) {
    final docs = snapshot.docs;
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);

    int pending = 0;
    int reviewedToday = 0;
    int approved = 0;
    int rejected = 0;

    for (final doc in docs) {
      final data = doc.data();
      final status = data['status'] as String? ?? '';
      final reviewedAt = (data['reviewedAt'] as Timestamp?)?.toDate();
      final reviewedBy = data['reviewedBy'] as String?;

      if (status == 'pending') pending++;
      if (status == 'approved') approved++;
      if (status == 'rejected') rejected++;

      if (reviewedBy == userId &&
          reviewedAt != null &&
          reviewedAt.isAfter(startOfDay)) {
        reviewedToday++;
      }
    }

    return {
      'pending': pending,
      'reviewedToday': reviewedToday,
      'approved': approved,
      'rejected': rejected,
    };
  });
});

class CADocumentReviewPage extends ConsumerStatefulWidget {
  const CADocumentReviewPage({super.key});

  @override
  ConsumerState<CADocumentReviewPage> createState() =>
      _CADocumentReviewPageState();
}

class _CADocumentReviewPageState extends ConsumerState<CADocumentReviewPage> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _reviewCommentsController =
      TextEditingController();
  String _searchQuery = '';
  String _selectedType = 'all';
  String _selectedStatus = 'pending';
  bool _isReviewing = false;

  @override
  void dispose() {
    _searchController.dispose();
    _reviewCommentsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserProvider).value;

    if (currentUser == null || (!currentUser.isCA && !currentUser.isAdmin)) {
      return Scaffold(
        appBar: const CustomAppBar(title: 'Document Review'),
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
                'You do not have permission to review documents. CA or Admin access required.',
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
      appBar: const CustomAppBar(title: 'Document Review Center'),
      body: Column(
        children: [
          _buildFilterBar(),
          _buildReviewStats(),
          Expanded(
            child: _buildDocumentsList(),
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
      child: Column(
        children: [
          // Search Bar
          TextFormField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search documents by name, type, or student...',
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
                  value: _selectedType,
                  decoration: const InputDecoration(
                    labelText: 'Document Type',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('All Types')),
                    DropdownMenuItem(
                        value: 'academic', child: Text('Academic Certificate')),
                    DropdownMenuItem(
                        value: 'professional',
                        child: Text('Professional Certificate')),
                    DropdownMenuItem(
                        value: 'completion', child: Text('Course Completion')),
                    DropdownMenuItem(
                        value: 'achievement', child: Text('Achievement')),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedType = value ?? 'all';
                    });
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _selectedStatus,
                  decoration: const InputDecoration(
                    labelText: 'Status',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                        value: 'pending', child: Text('Pending Review')),
                    DropdownMenuItem(
                        value: 'approved', child: Text('Approved')),
                    DropdownMenuItem(
                        value: 'rejected', child: Text('Rejected')),
                    DropdownMenuItem(value: 'all', child: Text('All Status')),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedStatus = value ?? 'pending';
                    });
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReviewStats() {
    final statsAsync = ref.watch(caDocumentStatsProvider);

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
                'Reviewed Today',
                '${stats['reviewedToday'] ?? 0}',
                Icons.today,
                AppTheme.primaryColor,
              ),
            ),
            Container(height: 40, width: 1, color: AppTheme.dividerColor),
            Expanded(
              child: _buildStatItem(
                'Approved',
                '${stats['approved'] ?? 0}',
                Icons.check_circle,
                AppTheme.successColor,
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

  Widget _buildDocumentsList() {
    final documentsAsync = ref.watch(pendingDocumentsProvider);

    return documentsAsync.when(
      data: (documents) {
        // Apply filters
        final filteredDocuments = documents.where((doc) {
          // Search filter
          if (_searchQuery.isNotEmpty) {
            final studentName = doc.metadata.subject ??
                doc.metadata.customFields['studentName']?.toString() ??
                '';
            final searchMatch =
                doc.fileName.toLowerCase().contains(_searchQuery) ||
                    studentName.toLowerCase().contains(_searchQuery) ||
                    doc.type.displayName.toLowerCase().contains(_searchQuery);
            if (!searchMatch) return false;
          }

          // Type filter
          if (_selectedType != 'all' && doc.type.name != _selectedType) {
            return false;
          }

          // Status filter
          if (_selectedStatus != 'all' && doc.status.name != _selectedStatus) {
            return false;
          }

          return true;
        }).toList();

        if (filteredDocuments.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.folder_open,
                  size: 80,
                  color: AppTheme.textSecondary,
                ),
                const SizedBox(height: 16),
                Text(
                  'No Documents Found',
                  style: AppTheme.textTheme.headlineMedium?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'No documents match your current filter criteria.',
                  style: AppTheme.textTheme.bodyLarge?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: filteredDocuments.length,
          itemBuilder: (context, index) {
            final document = filteredDocuments[index];
            return FadeInUp(
              duration: Duration(milliseconds: 300 + (index * 100)),
              child: _buildDocumentCard(document, index),
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
            Text(
              'Error Loading Documents',
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
              onPressed: () => ref.refresh(pendingDocumentsProvider),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDocumentCard(DocumentModel document, int index) {
    final studentName = document.metadata.subject ??
        document.metadata.customFields['studentName']?.toString() ??
        'Unknown Student';
    final institution = document.metadata.institutionName ??
        document.metadata.customFields['institution']?.toString() ??
        'Unknown Institution';
    final course = document.metadata.customFields['course']?.toString();
    final grade = document.metadata.customFields['grade']?.toString();

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _viewDocumentDetails(document),
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
                      color: _getDocumentTypeColor(document.type.name)
                          .withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      _getDocumentTypeIcon(document.type.name),
                      color: _getDocumentTypeColor(document.type.name),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          studentName,
                          style: AppTheme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          institution,
                          style: AppTheme.textTheme.bodyMedium?.copyWith(
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildStatusBadge(document.status),
                ],
              ),
              const SizedBox(height: 12),
              _buildInfoRow(Icons.description, 'File: ${document.fileName}'),
              const SizedBox(height: 4),
              _buildInfoRow(Icons.category,
                  'Type: ${document.type.displayName.toUpperCase()}'),
              if (course != null) ...[
                const SizedBox(height: 4),
                _buildInfoRow(Icons.school, 'Course: $course'),
              ],
              if (grade != null) ...[
                const SizedBox(height: 4),
                _buildInfoRow(Icons.grade, 'Grade: $grade'),
              ],
              const SizedBox(height: 4),
              _buildInfoRow(
                Icons.access_time,
                'Uploaded: ${DateFormat('MMM dd, yyyy').format(document.uploadedAt)}',
              ),
              const SizedBox(height: 12),
              // View Content Button - Always available
              Center(
                child: OutlinedButton.icon(
                  onPressed: () => _viewDocumentContent(document),
                  icon: const Icon(Icons.visibility, size: 18),
                  label: const Text('View Document Content'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primaryColor,
                    side: BorderSide(color: AppTheme.primaryColor),
                  ),
                ),
              ),
              if (document.status == DocumentStatus.pending) ...[
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton.icon(
                      onPressed:
                          _isReviewing ? null : () => _rejectDocument(document),
                      icon: const Icon(Icons.close, size: 18),
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
                          : () => _approveDocument(document),
                      icon: const Icon(Icons.check, size: 18),
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

  Widget _buildStatusBadge(DocumentStatus status) {
    Color color;
    String text;

    switch (status) {
      case DocumentStatus.pending:
        color = AppTheme.warningColor;
        text = 'Pending';
        break;
      case DocumentStatus.verified:
        color = AppTheme.successColor;
        text = 'Approved';
        break;
      case DocumentStatus.rejected:
        color = AppTheme.errorColor;
        text = 'Rejected';
        break;
      default:
        color = Colors.grey;
        text = status.toString().split('.').last;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: AppTheme.bodySmall.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w500,
        ),
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

  Color _getDocumentTypeColor(String type) {
    switch (type.toLowerCase()) {
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

  IconData _getDocumentTypeIcon(String type) {
    switch (type.toLowerCase()) {
      case 'academic':
        return Icons.school;
      case 'professional':
        return Icons.work;
      case 'completion':
        return Icons.check_circle;
      case 'achievement':
        return Icons.emoji_events;
      default:
        return Icons.description;
    }
  }

  void _viewDocumentDetails(DocumentModel document) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _DocumentDetailsSheet(
        document: document,
        onApprove: () => _approveDocument(document),
        onReject: () => _rejectDocument(document),
        onViewContent: () => _viewDocumentContent(document),
        isReviewing: _isReviewing,
      ),
    );
  }

  void _viewDocumentContent(DocumentModel document) {
    // Navigate to the dedicated document viewer page
    context.push('/documents/view/${document.id}');
  }

  Future<void> _approveDocument(DocumentModel document) async {
    setState(() {
      _isReviewing = true;
    });

    try {
      final currentUser = ref.read(currentUserProvider).value!;

      await FirebaseFirestore.instance
          .collection('documents')
          .doc(document.id)
          .update({
        'status': DocumentStatus.verified.name,
        'reviewedBy': currentUser.id,
        'reviewedAt': FieldValue.serverTimestamp(),
        'reviewComments': 'Document approved for certificate creation',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Create CA activity log - Fixed: use ca_activities collection with correct structure
      await FirebaseFirestore.instance.collection('ca_activities').add({
        'caId': currentUser.id,
        'action': 'document_reviewed',
        'description': 'Approved document: ${document.fileName}',
        'timestamp': FieldValue.serverTimestamp(),
        'metadata': {
          'documentId': document.id,
          'documentName': document.fileName,
          'studentName': document.metadata.subject ??
              document.metadata.customFields['studentName'],
          'status': 'approved',
          'reviewAction': 'approved',
        },
      });

      // Send notification to document uploader
      if (document.uploaderId.isNotEmpty) {
        await NotificationService().sendNotification(
          userId: document.uploaderId,
          title: 'Document Approved',
          message:
              'Your document "${document.fileName}" has been approved and is ready for certificate creation.',
          type: 'document_approval',
          data: {'documentId': document.id},
        );
      }

      // 🔄 自动创建模板创建通知给当前CA
      await NotificationService().sendNotification(
        userId: currentUser.id,
        title: 'Document Ready for Template Creation',
        message:
            'Document "${document.fileName}" is now approved and ready for certificate template creation.',
        type: 'template_creation_ready',
        data: {
          'documentId': document.id,
          'redirectTo': '/ca/template-creation',
        },
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Document approved successfully'),
            backgroundColor: AppTheme.successColor,
          ),
        );
      }
    } catch (e) {
      LoggerService.error('Failed to approve document', error: e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to approve document: $e'),
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

  Future<void> _rejectDocument(DocumentModel document) async {
    final reason = await _showRejectDialog();
    if (reason == null || reason.isEmpty) return;

    setState(() {
      _isReviewing = true;
    });

    try {
      final currentUser = ref.read(currentUserProvider).value!;

      await FirebaseFirestore.instance
          .collection('documents')
          .doc(document.id)
          .update({
        'status': DocumentStatus.rejected.name,
        'reviewedBy': currentUser.id,
        'reviewedAt': FieldValue.serverTimestamp(),
        'rejectionReason': reason,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Create CA activity log - Fixed: use ca_activities collection with correct structure
      await FirebaseFirestore.instance.collection('ca_activities').add({
        'caId': currentUser.id,
        'action': 'document_reviewed',
        'description': 'Rejected document: ${document.fileName}',
        'timestamp': FieldValue.serverTimestamp(),
        'metadata': {
          'documentId': document.id,
          'documentName': document.fileName,
          'studentName': document.metadata.subject ??
              document.metadata.customFields['studentName'],
          'status': 'rejected',
          'reviewAction': 'rejected',
          'rejectionReason': reason,
        },
      });

      // Send notification to document uploader
      if (document.uploaderId.isNotEmpty) {
        await NotificationService().sendNotification(
          userId: document.uploaderId,
          title: 'Document Rejected',
          message:
              'Your document "${document.fileName}" has been rejected. Reason: $reason',
          type: 'document_rejection',
          data: {'documentId': document.id, 'reason': reason},
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Document rejected'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } catch (e) {
      LoggerService.error('Failed to reject document', error: e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to reject document: $e'),
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
        title: const Text('Reject Document'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Please provide a reason for rejecting this document:'),
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
            child: const Text('Reject'),
          ),
        ],
      ),
    );
  }
}

// Document details sheet widget
class _DocumentDetailsSheet extends StatelessWidget {
  final DocumentModel document;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final VoidCallback onViewContent;
  final bool isReviewing;

  const _DocumentDetailsSheet({
    required this.document,
    required this.onApprove,
    required this.onReject,
    required this.onViewContent,
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
              'Document Details',
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
                    _buildDetailRow(
                        'Student Name',
                        document.metadata.subject ??
                            document.metadata.customFields['studentName']
                                ?.toString() ??
                            'N/A'),
                    _buildDetailRow(
                        'Institution',
                        document.metadata.institutionName ??
                            document.metadata.customFields['institution']
                                ?.toString() ??
                            'N/A'),
                    _buildDetailRow('File Name', document.fileName),
                    _buildDetailRow('Document Type',
                        document.type.displayName.toUpperCase()),
                    _buildDetailRow('File Size',
                        '${(document.fileSize / 1024 / 1024).toStringAsFixed(2)} MB'),
                    _buildDetailRow(
                        'Upload Date',
                        DateFormat('MMM dd, yyyy HH:mm')
                            .format(document.uploadedAt)),
                    if (document.metadata.customFields['course'] != null)
                      _buildDetailRow('Course',
                          document.metadata.customFields['course'].toString()),
                    if (document.metadata.customFields['grade'] != null)
                      _buildDetailRow('Grade',
                          document.metadata.customFields['grade'].toString()),
                    if (document.metadata.customFields['graduationDate'] !=
                        null)
                      _buildDetailRow(
                          'Graduation Date',
                          document.metadata.customFields['graduationDate']
                              .toString()),
                    const SizedBox(height: 24),
                    // Document Content Preview
                    _buildDocumentPreview(document),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
            // Action buttons
            Column(
              children: [
                // View Content Button - Always available
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      onViewContent();
                    },
                    icon: const Icon(Icons.visibility),
                    label: const Text('View Document Content'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                if (document.status == DocumentStatus.pending) ...[
                  const SizedBox(height: 16),
                  Row(
                    children: [
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
                      const SizedBox(width: 16),
                      Expanded(
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
                          child: const Text('Approve'),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
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

  Widget _buildDocumentPreview(DocumentModel document) {
    return Card(
      elevation: 2,
      child: Container(
        height: 300,
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.dividerColor),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(8),
                  topRight: Radius.circular(8),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _getDocumentIcon(document.mimeType),
                    color: AppTheme.primaryColor,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Document Preview',
                    style: AppTheme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  const Spacer(),
                  Chip(
                    label: Text(
                      document.mimeType.split('/').last.toUpperCase(),
                      style: const TextStyle(fontSize: 10),
                    ),
                    backgroundColor: AppTheme.primaryColor,
                    labelStyle: const TextStyle(color: Colors.white),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ),
            Expanded(
              child: _buildPreviewContent(document),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewContent(DocumentModel document) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _getDocumentIcon(document.mimeType),
            size: 48,
            color: AppTheme.textSecondary,
          ),
          const SizedBox(height: 12),
          Text(
            document.fileName,
            style: AppTheme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          Text(
            _getDocumentTypeDescription(document.mimeType),
            style: AppTheme.textTheme.bodySmall?.copyWith(
              color: AppTheme.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Size: ${_formatFileSize(document.fileSize)}',
            style: AppTheme.textTheme.bodySmall?.copyWith(
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => onViewContent(),
                  icon: const Icon(Icons.visibility, size: 16),
                  label: const Text('View Full'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primaryColor,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _downloadDocument(document),
                  icon: const Icon(Icons.download, size: 16),
                  label: const Text('Download'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.accentColor,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  IconData _getDocumentIcon(String mimeType) {
    switch (mimeType.toLowerCase()) {
      case 'application/pdf':
        return Icons.picture_as_pdf;
      case 'application/msword':
      case 'application/vnd.openxmlformats-officedocument.wordprocessingml.document':
        return Icons.description;
      case 'image/jpeg':
      case 'image/jpg':
      case 'image/png':
        return Icons.image;
      case 'text/plain':
        return Icons.text_snippet;
      default:
        return Icons.insert_drive_file;
    }
  }

  String _getDocumentTypeDescription(String mimeType) {
    switch (mimeType.toLowerCase()) {
      case 'application/pdf':
        return 'PDF Document';
      case 'application/msword':
        return 'Microsoft Word Document';
      case 'application/vnd.openxmlformats-officedocument.wordprocessingml.document':
        return 'Word Document (DOCX)';
      case 'image/jpeg':
      case 'image/jpg':
        return 'JPEG Image';
      case 'image/png':
        return 'PNG Image';
      case 'text/plain':
        return 'Text Document';
      default:
        return 'Document File';
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)}GB';
  }

  void _downloadDocument(DocumentModel document) {
    // Implement download functionality
    // This could navigate to download or trigger a download
    // For now, we'll just show a message
  }
}
