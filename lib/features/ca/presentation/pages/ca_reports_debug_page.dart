import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/services/logger_service.dart';
import '../../../auth/providers/auth_providers.dart';

class CAReportsDebugPage extends ConsumerStatefulWidget {
  const CAReportsDebugPage({super.key});

  @override
  ConsumerState<CAReportsDebugPage> createState() => _CAReportsDebugPageState();
}

class _CAReportsDebugPageState extends ConsumerState<CAReportsDebugPage> {
  Map<String, dynamic> debugData = {};
  bool isLoading = true;
  String? error;
  String? currentUserId;

  @override
  void initState() {
    super.initState();
    _loadDebugData();
  }

  Future<void> _loadDebugData() async {
    try {
      setState(() {
        isLoading = true;
        error = null;
      });

      final currentUser = ref.read(currentUserProvider).value;
      if (currentUser == null) {
        throw Exception('No authenticated user');
      }

      currentUserId = currentUser.id;
      LoggerService.info('🔍 DEBUG: Current CA user ID: $currentUserId');

      final debugResult = <String, dynamic>{
        'currentUser': {
          'id': currentUser.id,
          'email': currentUser.email,
          'displayName': currentUser.displayName,
          'role': currentUser.role.name,
        },
      };

      // 1. 检查 certificate_templates 集合
      final templatesSnapshot = await FirebaseFirestore.instance
          .collection('certificate_templates')
          .get();

      LoggerService.info(
          '🔍 Total certificate_templates: ${templatesSnapshot.docs.length}');

      final allTemplates = templatesSnapshot.docs
          .map((doc) => {
                'id': doc.id,
                ...doc.data(),
              })
          .toList();

      final userTemplates = allTemplates.where((template) {
        final createdBy = template['createdBy'] as String?;
        return createdBy == currentUserId;
      }).toList();

      debugResult['certificateTemplates'] = {
        'total': allTemplates.length,
        'byCurrentUser': userTemplates.length,
        'allTemplates': allTemplates.take(5).toList(),
        'userTemplates': userTemplates.take(5).toList(),
      };

      // 2. 检查 documents 集合
      final documentsSnapshot =
          await FirebaseFirestore.instance.collection('documents').get();

      LoggerService.info(
          '🔍 Total documents: ${documentsSnapshot.docs.length}');

      final allDocuments = documentsSnapshot.docs
          .map((doc) => {
                'id': doc.id,
                ...doc.data(),
              })
          .toList();

      final verifiedDocuments = allDocuments.where((doc) {
        final status = doc['status'] as String?;
        return status == 'verified';
      }).toList();

      debugResult['documents'] = {
        'total': allDocuments.length,
        'verified': verifiedDocuments.length,
        'allDocuments': allDocuments.take(5).toList(),
        'verifiedDocuments': verifiedDocuments.take(5).toList(),
      };

      // 3. 检查 template_reviews 集合
      final reviewsSnapshot =
          await FirebaseFirestore.instance.collection('template_reviews').get();

      LoggerService.info(
          '🔍 Total template_reviews: ${reviewsSnapshot.docs.length}');

      final allReviews = reviewsSnapshot.docs
          .map((doc) => {
                'id': doc.id,
                ...doc.data(),
              })
          .toList();

      final clientReviews = allReviews.where((review) {
        final reviewerRole = review['reviewerRole'] as String?;
        return reviewerRole == 'client';
      }).toList();

      debugResult['templateReviews'] = {
        'total': allReviews.length,
        'clientReviewsCount': clientReviews.length,
        'allReviews': allReviews.take(5).toList(),
        'clientReviews': clientReviews.take(5).toList(),
      };

      // 4. 检查 certificates 集合
      final certificatesSnapshot =
          await FirebaseFirestore.instance.collection('certificates').get();

      LoggerService.info(
          '🔍 Total certificates: ${certificatesSnapshot.docs.length}');

      final allCertificates = certificatesSnapshot.docs
          .map((doc) => {
                'id': doc.id,
                ...doc.data(),
              })
          .toList();

      final userCertificates = allCertificates.where((cert) {
        final issuerId = cert['issuerId'] as String?;
        return issuerId == currentUserId;
      }).toList();

      debugResult['certificates'] = {
        'total': allCertificates.length,
        'byCurrentUser': userCertificates.length,
        'allCertificates': allCertificates.take(5).toList(),
        'userCertificates': userCertificates.take(5).toList(),
      };

      setState(() {
        debugData = debugResult;
        isLoading = false;
      });

      LoggerService.info('✅ Debug data loaded successfully');
    } catch (e, stackTrace) {
      LoggerService.error('Failed to load debug data',
          error: e, stackTrace: stackTrace);
      setState(() {
        error = e.toString();
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('CA Reports Debug'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDebugData,
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error, color: Colors.red, size: 48),
                      const SizedBox(height: 16),
                      Text('Error: $error'),
                      ElevatedButton(
                        onPressed: _loadDebugData,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildCurrentUserCard(),
                      const SizedBox(height: 16),
                      _buildDataSummaryCard(),
                      const SizedBox(height: 16),
                      _buildTemplatesSection(),
                      const SizedBox(height: 16),
                      _buildDocumentsSection(),
                      const SizedBox(height: 16),
                      _buildReviewsSection(),
                      const SizedBox(height: 16),
                      _buildCertificatesSection(),
                    ],
                  ),
                ),
    );
  }

  Widget _buildCurrentUserCard() {
    final userData = debugData['currentUser'] as Map<String, dynamic>?;
    if (userData == null) return const SizedBox();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Current User Info',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text('ID: ${userData['id']}'),
            Text('Email: ${userData['email']}'),
            Text('Name: ${userData['displayName']}'),
            Text('Role: ${userData['role']}'),
          ],
        ),
      ),
    );
  }

  Widget _buildDataSummaryCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Data Summary',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            _buildSummaryRow(
                'Certificate Templates',
                debugData['certificateTemplates']?['total'] ?? 0,
                debugData['certificateTemplates']?['byCurrentUser'] ?? 0),
            _buildSummaryRow('Documents', debugData['documents']?['total'] ?? 0,
                debugData['documents']?['verified'] ?? 0),
            _buildSummaryRow(
                'Template Reviews',
                debugData['templateReviews']?['total'] ?? 0,
                debugData['templateReviews']?['clientReviewsCount'] ?? 0),
            _buildSummaryRow(
                'Certificates',
                debugData['certificates']?['total'] ?? 0,
                debugData['certificates']?['byCurrentUser'] ?? 0),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, int total, int filtered) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text('Total: $total, Filtered: $filtered'),
        ],
      ),
    );
  }

  Widget _buildTemplatesSection() {
    final templatesData =
        debugData['certificateTemplates'] as Map<String, dynamic>?;
    if (templatesData == null) return const SizedBox();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Certificate Templates (${templatesData['byCurrentUser']}/${templatesData['total']})',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (templatesData['userTemplates']?.isEmpty ?? true)
              const Text('No templates found for current user',
                  style:
                      TextStyle(color: Colors.red, fontWeight: FontWeight.bold))
            else
              ...(templatesData['userTemplates'] as List)
                  .map((template) => _buildDataCard(template, 'Template')),
            const SizedBox(height: 16),
            const Text('Sample All Templates:',
                style: TextStyle(fontWeight: FontWeight.bold)),
            ...(templatesData['allTemplates'] as List)
                .take(3)
                .map((template) => _buildDataCard(template, 'Template')),
          ],
        ),
      ),
    );
  }

  Widget _buildDocumentsSection() {
    final documentsData = debugData['documents'] as Map<String, dynamic>?;
    if (documentsData == null) return const SizedBox();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Documents (${documentsData['verified']}/${documentsData['total']} verified)',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (documentsData['verifiedDocuments']?.isEmpty ?? true)
              const Text('No verified documents found',
                  style: TextStyle(
                      color: Colors.orange, fontWeight: FontWeight.bold))
            else
              ...(documentsData['verifiedDocuments'] as List)
                  .map((doc) => _buildDataCard(doc, 'Document')),
          ],
        ),
      ),
    );
  }

  Widget _buildReviewsSection() {
    final reviewsData = debugData['templateReviews'] as Map<String, dynamic>?;
    if (reviewsData == null) return const SizedBox();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Template Reviews (${reviewsData['clientReviews']}/${reviewsData['total']} client reviews)',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (reviewsData['clientReviews']?.isEmpty ?? true)
              const Text('No client reviews found',
                  style: TextStyle(
                      color: Colors.orange, fontWeight: FontWeight.bold))
            else
              ...(reviewsData['clientReviews'] as List)
                  .map((review) => _buildDataCard(review, 'Review')),
          ],
        ),
      ),
    );
  }

  Widget _buildCertificatesSection() {
    final certificatesData = debugData['certificates'] as Map<String, dynamic>?;
    if (certificatesData == null) return const SizedBox();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Certificates (${certificatesData['byCurrentUser']}/${certificatesData['total']} by current user)',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (certificatesData['userCertificates']?.isEmpty ?? true)
              const Text('No certificates found by current user',
                  style: TextStyle(
                      color: Colors.orange, fontWeight: FontWeight.bold))
            else
              ...(certificatesData['userCertificates'] as List)
                  .map((cert) => _buildDataCard(cert, 'Certificate')),
          ],
        ),
      ),
    );
  }

  Widget _buildDataCard(Map<String, dynamic> data, String type) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$type ID: ${data['id']}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          if (data['name'] != null) Text('Name: ${data['name']}'),
          if (data['title'] != null) Text('Title: ${data['title']}'),
          if (data['status'] != null) Text('Status: ${data['status']}'),
          if (data['createdBy'] != null)
            Text('Created By: ${data['createdBy']}'),
          if (data['issuerId'] != null) Text('Issuer ID: ${data['issuerId']}'),
          if (data['action'] != null) Text('Action: ${data['action']}'),
          if (data['reviewerRole'] != null)
            Text('Reviewer Role: ${data['reviewerRole']}'),
          if (data['createdAt'] != null)
            Builder(
              builder: (context) {
                final createdAt = data['createdAt'] is Timestamp
                    ? (data['createdAt'] as Timestamp).toDate()
                    : data['createdAt'];
                return Text('Created: $createdAt');
              },
            ),
        ],
      ),
    );
  }
}
