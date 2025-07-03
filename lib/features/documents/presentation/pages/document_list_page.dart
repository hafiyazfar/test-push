import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:animate_do/animate_do.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/models/document_model.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/services/logger_service.dart';
import '../../../../core/providers/unified_data_providers.dart';
import '../../../dashboard/services/activity_service.dart';
import '../widgets/document_card.dart';
import '../widgets/document_filter_dialog.dart';

class DocumentListPage extends ConsumerStatefulWidget {
  const DocumentListPage({super.key});

  @override
  ConsumerState<DocumentListPage> createState() => _DocumentListPageState();
}

class _DocumentListPageState extends ConsumerState<DocumentListPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ActivityService _activityService = ActivityService();

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedFilter = 'all';
  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text;
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Documents',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _showFilterDialog,
            icon: const Icon(Icons.filter_list),
            tooltip: 'Filter Documents',
          ),
          IconButton(
            onPressed: () => context.go('/documents/upload'),
            icon: const Icon(Icons.upload_file),
            tooltip: 'Upload Document',
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(AppTheme.spacingM),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search documents...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchQuery = '';
                          });
                        },
                        icon: const Icon(Icons.clear),
                      )
                    : null,
                filled: true,
                fillColor: AppTheme.surfaceColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),

          // Documents List - Use Unified Provider
          Expanded(
            child: _buildDocumentsList(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/documents/upload'),
        icon: const Icon(Icons.add),
        label: const Text('Upload Document'),
        backgroundColor: AppTheme.primaryColor,
      ),
    );
  }

  Widget _buildDocumentsList() {
    final documentsAsync = ref.watch(unifiedDocumentsProvider);

    return documentsAsync.when(
      data: (documentsData) {
        LoggerService.info('📄 Documents loaded: ${documentsData.length}');

        // Convert raw data to DocumentModel objects
        final documents = documentsData
            .map((data) {
              try {
                return DocumentModel.fromMap(data);
              } catch (e) {
                LoggerService.warning(
                    '⚠️ Failed to parse document: ${data['id']}',
                    error: e);
                return null;
              }
            })
            .where((doc) => doc != null)
            .cast<DocumentModel>()
            .toList();

        final filteredDocuments = _filterDocuments(documents);

        if (filteredDocuments.isEmpty) {
          return _buildEmptyState();
        }

        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(unifiedDocumentsProvider);
            await Future.delayed(const Duration(milliseconds: 500));
          },
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: filteredDocuments.length,
            itemBuilder: (context, index) {
              final document = filteredDocuments[index];
              return FadeInUp(
                duration: Duration(milliseconds: 300 + (index * 100)),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: DocumentCard(
                    document: document,
                    onTap: () => _viewDocument(document),
                    onDelete: () => _deleteDocument(document),
                  ),
                ),
              );
            },
          ),
        );
      },
      loading: () => const Center(
        child: CircularProgressIndicator(),
      ),
      error: (error, stack) {
        LoggerService.error('❌ Failed to load documents', error: error);
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                size: 64,
                color: AppTheme.errorColor,
              ),
              const SizedBox(height: 16),
              Text(
                'Failed to load documents',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                error.toString(),
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => ref.invalidate(unifiedDocumentsProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          FadeInUp(
            duration: const Duration(milliseconds: 600),
            child: const Icon(
              Icons.folder_open,
              size: 120,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 24),
          FadeInUp(
            duration: const Duration(milliseconds: 800),
            child: Text(
              _searchQuery.isNotEmpty || _selectedFilter != 'all'
                  ? 'No documents match your criteria'
                  : 'No documents yet',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
            ),
          ),
          const SizedBox(height: 8),
          FadeInUp(
            duration: const Duration(milliseconds: 1000),
            child: Text(
              _searchQuery.isNotEmpty || _selectedFilter != 'all'
                  ? 'Try adjusting your search or filter'
                  : 'Upload your first document to get started',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 32),
          if (_searchQuery.isEmpty && _selectedFilter == 'all')
            FadeInUp(
              duration: const Duration(milliseconds: 1200),
              child: ElevatedButton.icon(
                onPressed: () => context.push('/documents/upload'),
                icon: const Icon(Icons.upload_file),
                label: const Text('Upload Document'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: AppTheme.textOnPrimary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  List<DocumentModel> _filterDocuments(List<DocumentModel> documents) {
    return documents.where((document) {
      // Search filter
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        if (!document.name.toLowerCase().contains(query) &&
            !document.description.toLowerCase().contains(query)) {
          return false;
        }
      }

      // Status filter
      switch (_selectedFilter) {
        case 'uploaded':
          return document.status == DocumentStatus.uploaded;
        case 'verified':
          return document.status == DocumentStatus.verified;
        case 'pending':
          return document.status == DocumentStatus.pendingVerification;
        case 'rejected':
          return document.status == DocumentStatus.rejected;
        default:
          return true;
      }
    }).toList();
  }

  void _viewDocument(DocumentModel document) {
    context.push('/documents/view/${document.id}');
  }

  Future<void> _deleteDocument(DocumentModel document) async {
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Delete Document'),
          content: Text('Are you sure you want to delete "${document.name}"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(foregroundColor: AppTheme.errorColor),
              child: const Text('Delete'),
            ),
          ],
        ),
      );

      if (confirmed != true) return;

      // Delete from Firebase
      await _firestore
          .collection(AppConfig.documentsCollection)
          .doc(document.id)
          .delete();

      // No need to manually update local state -
      // the unified provider will automatically refresh via Firebase listeners

      // Log activity
      await _activityService.logDocumentActivity(
        action: 'document_deleted',
        documentId: document.id,
        details: 'Document "${document.name}" deleted',
        metadata: {
          'document_name': document.name,
          'file_type': document.type.name,
        },
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Document "${document.name}" deleted'),
            backgroundColor: AppTheme.successColor,
          ),
        );
      }

      LoggerService.info('Document deleted: ${document.id}');
    } catch (e, stackTrace) {
      LoggerService.error('Failed to delete document',
          error: e, stackTrace: stackTrace);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete document: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => DocumentFilterDialog(
        selectedFilter: _selectedFilter,
        onFilterChanged: (filter) {
          setState(() {
            _selectedFilter = filter;
          });
        },
      ),
    );
  }
}
