import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/models/certificate_model.dart';
import '../../../auth/providers/auth_providers.dart';
import '../../../../core/services/logger_service.dart';
import '../widgets/certificate_card.dart';

class CertificatePendingPage extends ConsumerStatefulWidget {
  const CertificatePendingPage({super.key});

  @override
  ConsumerState<CertificatePendingPage> createState() =>
      _CertificatePendingPageState();
}

class _CertificatePendingPageState
    extends ConsumerState<CertificatePendingPage> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

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
        body: Center(
          child: Text('Please log in to view pending certificates'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pending Certificates'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: AppTheme.textOnPrimary,
        elevation: 0,
      ),
      body: _buildBody(currentUser.id),
    );
  }

  Widget _buildBody(String userId) {
    return Column(
      children: [
        _buildSearchBar(),
        Expanded(
          child: _buildPendingCertificatesList(userId),
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingM),
      color: AppTheme.primaryColor.withValues(alpha: 0.1),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search pending certificates...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    setState(() {
                      _searchController.clear();
                      _searchQuery = '';
                    });
                  },
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusL),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.white,
        ),
        onChanged: (value) {
          setState(() {
            _searchQuery = value.toLowerCase();
          });
        },
      ),
    );
  }

  Widget _buildPendingCertificatesList(String userId) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('certificates')
          .where('status', isEqualTo: 'pending')
          .where('recipientId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          LoggerService.error('Error loading pending certificates',
              error: snapshot.error);
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline,
                    size: 48, color: AppTheme.errorColor),
                const SizedBox(height: AppTheme.spacingM),
                Text(
                  'Error loading pending certificates',
                  style:
                      AppTheme.bodyLarge.copyWith(color: AppTheme.errorColor),
                ),
                const SizedBox(height: AppTheme.spacingS),
                Text(
                  snapshot.error.toString(),
                  style: AppTheme.bodySmall
                      .copyWith(color: AppTheme.textSecondary),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        final certificates = snapshot.data?.docs ?? [];

        if (certificates.isEmpty) {
          return _buildEmptyState();
        }

        final filteredCertificates = certificates.where((doc) {
          if (_searchQuery.isEmpty) return true;

          final data = doc.data() as Map<String, dynamic>;
          final title = (data['title'] ?? '').toString().toLowerCase();
          final certificateNumber =
              (data['certificateNumber'] ?? '').toString().toLowerCase();
          final recipientName =
              (data['recipientName'] ?? '').toString().toLowerCase();

          return title.contains(_searchQuery) ||
              certificateNumber.contains(_searchQuery) ||
              recipientName.contains(_searchQuery);
        }).toList();

        if (filteredCertificates.isEmpty) {
          return _buildNoSearchResultsState();
        }

        return ListView.builder(
          padding: const EdgeInsets.all(AppTheme.spacingM),
          itemCount: filteredCertificates.length,
          itemBuilder: (context, index) {
            final doc = filteredCertificates[index];
            final data = doc.data() as Map<String, dynamic>;

            // Convert Firestore data to CertificateModel
            final certificate = CertificateModel(
              id: doc.id,
              templateId: data['templateId'] ?? '',
              title: data['title'] ?? 'Untitled Certificate',
              description: data['description'] ?? '',
              type: CertificateType.values.firstWhere(
                (type) =>
                    type.toString() ==
                    'CertificateType.${data['type'] ?? 'academic'}',
                orElse: () => CertificateType.academic,
              ),
              recipientId: data['recipientId'] ?? '',
              recipientName: data['recipientName'] ?? 'Unknown',
              recipientEmail: data['recipientEmail'] ?? '',
              issuerId: data['issuerId'] ?? '',
              issuerName: data['issuerName'] ?? 'Unknown Issuer',
              organizationId: data['organizationId'] ?? '',
              organizationName: data['organizationName'] ?? '',
              verificationCode:
                  data['verificationCode'] ?? data['certificateNumber'] ?? '',
              verificationId: data['verificationId'] ?? '',
              qrCode: data['qrCode'] ?? '',
              hash: data['hash'] ?? '',
              courseName: data['courseName'] ?? '',
              grade: data['grade'] ?? '',
              issuedAt:
                  (data['issuedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
              expiresAt: data['expiresAt'] != null
                  ? (data['expiresAt'] as Timestamp).toDate()
                  : null,
              status: CertificateStatus.values.firstWhere(
                (status) =>
                    status.toString() ==
                    'CertificateStatus.${data['status'] ?? 'pending'}',
                orElse: () => CertificateStatus.pending,
              ),
              isPublic: data['isPublic'] ?? false,
              tags: List<String>.from(data['tags'] ?? []),
              metadata: Map<String, dynamic>.from(data['metadata'] ?? {}),
              createdAt:
                  (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
              updatedAt:
                  (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
            );

            return Padding(
              padding: const EdgeInsets.only(bottom: AppTheme.spacingM),
              child: CertificateCard(
                certificate: certificate,
                onTap: () {
                  context.push('/certificates/${doc.id}');
                },
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.pending_actions,
            size: 80,
            color: AppTheme.textSecondary.withValues(alpha: 0.5),
          ),
          const SizedBox(height: AppTheme.spacingL),
          Text(
            'No pending certificates',
            style: AppTheme.titleLarge.copyWith(
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: AppTheme.spacingS),
          Text(
            'You don\'t have any certificates awaiting approval',
            style: AppTheme.bodyMedium.copyWith(
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: AppTheme.spacingXL),
          ElevatedButton.icon(
            onPressed: () => context.go('/certificates'),
            icon: const Icon(Icons.arrow_back),
            label: const Text('View All Certificates'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: AppTheme.textOnPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoSearchResultsState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 80,
            color: AppTheme.textSecondary.withValues(alpha: 0.5),
          ),
          const SizedBox(height: AppTheme.spacingL),
          Text(
            'No results found',
            style: AppTheme.titleLarge.copyWith(
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: AppTheme.spacingS),
          Text(
            'Try adjusting your search terms',
            style: AppTheme.bodyMedium.copyWith(
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: AppTheme.spacingXL),
          OutlinedButton.icon(
            onPressed: () {
              setState(() {
                _searchController.clear();
                _searchQuery = '';
              });
            },
            icon: const Icon(Icons.clear),
            label: const Text('Clear Search'),
          ),
        ],
      ),
    );
  }
}
