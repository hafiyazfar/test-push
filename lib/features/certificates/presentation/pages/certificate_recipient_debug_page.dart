import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/services/logger_service.dart';
import '../../../../core/models/certificate_model.dart';
import '../../../auth/providers/auth_providers.dart';
import '../../services/certificate_service.dart';

class CertificateRecipientDebugPage extends ConsumerStatefulWidget {
  const CertificateRecipientDebugPage({super.key});

  @override
  ConsumerState<CertificateRecipientDebugPage> createState() =>
      _CertificateRecipientDebugPageState();
}

class _CertificateRecipientDebugPageState
    extends ConsumerState<CertificateRecipientDebugPage> {
  List<Map<String, dynamic>> allCertificates = [];
  List<Map<String, dynamic>> userCertificates = [];
  List<Map<String, dynamic>> allUsers = [];
  List<Map<String, dynamic>> allDocuments = [];
  List<Map<String, dynamic>> recentActivities = [];
  bool isLoading = true;
  String? error;
  String? currentUserId;
  String? currentUserEmail;
  Map<String, dynamic> analysisResults = {};
  bool isTestingEnhancedQuery = false;
  List<Map<String, dynamic>> enhancedQueryResults = [];
  String enhancedQueryLog = '';

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
      currentUserEmail = currentUser.email;

      LoggerService.info('🔍 DEBUG: Current user ID: $currentUserId');
      LoggerService.info('🔍 DEBUG: Current user email: $currentUserEmail');

      // 1. Load all certificates
      final allCertsSnapshot =
          await FirebaseFirestore.instance.collection('certificates').get();

      LoggerService.info(
          '🔍 DEBUG: Found ${allCertsSnapshot.docs.length} total certificates');

      final allCerts = allCertsSnapshot.docs.map((doc) {
        final data = doc.data();
        data['documentId'] = doc.id;
        return data;
      }).toList();

      // 2. Load all users to understand ID mapping
      final usersSnapshot =
          await FirebaseFirestore.instance.collection('users').get();
      final users = usersSnapshot.docs.map((doc) {
        final data = doc.data();
        data['documentId'] = doc.id;
        return data;
      }).toList();

      // 3. Load all documents to trace the flow
      final documentsSnapshot =
          await FirebaseFirestore.instance.collection('documents').get();
      final documents = documentsSnapshot.docs.map((doc) {
        final data = doc.data();
        data['documentId'] = doc.id;
        return data;
      }).toList();

      // 4. Load recent activities
      final activitiesSnapshot = await FirebaseFirestore.instance
          .collection('activities')
          .orderBy('timestamp', descending: true)
          .limit(20)
          .get();
      final activities = activitiesSnapshot.docs.map((doc) {
        final data = doc.data();
        data['documentId'] = doc.id;
        return data;
      }).toList();

      // 5. Analyze certificate matching
      final analysis =
          _analyzeCertificateMatching(allCerts, users, documents, activities);

      // 6. Filter certificates for current user
      final userCerts = allCerts.where((cert) {
        final recipientId = cert['recipientId'] as String?;
        final recipientEmail = cert['recipientEmail'] as String?;

        bool matchesId = recipientId == currentUserId;
        bool matchesEmail = recipientEmail == currentUserEmail;

        LoggerService.info(
            '🔍 Certificate ${cert['documentId']}: recipientId=$recipientId, recipientEmail=$recipientEmail, matchesId=$matchesId, matchesEmail=$matchesEmail');

        return matchesId || matchesEmail;
      }).toList();

      LoggerService.info(
          '🔍 DEBUG: Found ${userCerts.length} certificates for current user');

      setState(() {
        allCertificates = allCerts;
        userCertificates = userCerts;
        allUsers = users;
        allDocuments = documents;
        recentActivities = activities;
        analysisResults = analysis;
        isLoading = false;
      });
    } catch (e, stackTrace) {
      LoggerService.error('Failed to load debug data',
          error: e, stackTrace: stackTrace);
      setState(() {
        error = e.toString();
        isLoading = false;
      });
    }
  }

  Map<String, dynamic> _analyzeCertificateMatching(
    List<Map<String, dynamic>> certificates,
    List<Map<String, dynamic>> users,
    List<Map<String, dynamic>> documents,
    List<Map<String, dynamic>> activities,
  ) {
    final currentUserActivities = activities.where((activity) {
      final type = activity['type'] as String?;
      return type?.contains('certificate') == true ||
          type?.contains('template') == true ||
          type?.contains('document') == true;
    }).toList();

    final documentsUploadedByUser = documents.where((doc) {
      return doc['uploaderId'] == currentUserId;
    }).toList();

    final certificatesWithMatchingMetadata = certificates.where((cert) {
      final metadata = cert['metadata'] as Map<String, dynamic>?;
      if (metadata == null) return false;

      final basedOnDocumentId = metadata['basedOnDocumentId'] as String?;
      if (basedOnDocumentId == null) return false;

      return documentsUploadedByUser
          .any((doc) => doc['documentId'] == basedOnDocumentId);
    }).toList();

    final certificateCreationActivities = activities.where((activity) {
      final type = activity['type'] as String?;
      return type == 'certificate_auto_created' &&
          activity['recipientId'] == currentUserId;
    }).toList();

    return {
      'userDocuments': documentsUploadedByUser.length,
      'userActivities': currentUserActivities.length,
      'certificatesBasedOnUserDocuments':
          certificatesWithMatchingMetadata.length,
      'certificateCreationActivities': certificateCreationActivities.length,
      'userDocumentsList': documentsUploadedByUser.take(5).toList(),
      'userActivitiesList': currentUserActivities.take(10).toList(),
      'certificatesWithMatchingMetadata': certificatesWithMatchingMetadata,
      'certificateCreationActivitiesList': certificateCreationActivities,
    };
  }

  Future<void> _testEnhancedQuery() async {
    try {
      setState(() {
        isTestingEnhancedQuery = true;
        enhancedQueryLog = '';
        enhancedQueryResults = [];
      });

      final currentUser = ref.read(currentUserProvider).value;
      if (currentUser == null) {
        throw Exception('No authenticated user');
      }

      LoggerService.info(
          '🧪 Testing enhanced recipient query for ${currentUser.email}');

      // Clear previous logs
      enhancedQueryLog = '=== Enhanced Query Test & Auto-Fix ===\n';
      enhancedQueryLog += 'User ID: ${currentUser.id}\n';
      enhancedQueryLog += 'User Email: ${currentUser.email}\n';
      enhancedQueryLog += 'User Role: ${currentUser.role}\n\n';

      // 🔥 Step 1: Test direct Firestore queries to see what exists
      enhancedQueryLog += '=== Step 1: Check All Certificates ===\n';
      final allCertsSnapshot = await FirebaseFirestore.instance
          .collection('certificates')
          .limit(10)
          .get();

      enhancedQueryLog +=
          'Total certificates in Firestore: ${allCertsSnapshot.docs.length}\n';

      for (final doc in allCertsSnapshot.docs) {
        final data = doc.data();
        enhancedQueryLog += 'Cert: ${data['title'] ?? 'No title'} | ';
        enhancedQueryLog += 'RecipientId: ${data['recipientId']} | ';
        enhancedQueryLog += 'RecipientEmail: ${data['recipientEmail']}\n';
      }
      enhancedQueryLog += '\n';

      // 🔥 Step 2: Test query by recipientId
      enhancedQueryLog += '=== Step 2: Query by recipientId ===\n';
      final recipientIdQuery = await FirebaseFirestore.instance
          .collection('certificates')
          .where('recipientId', isEqualTo: currentUser.id)
          .get();

      enhancedQueryLog +=
          'Found ${recipientIdQuery.docs.length} certificates by recipientId\n';

      for (final doc in recipientIdQuery.docs) {
        final data = doc.data();
        enhancedQueryLog +=
            'ID Match: ${data['title']} | ${data['recipientId']}\n';
      }
      enhancedQueryLog += '\n';

      // 🔥 Step 3: Test query by recipientEmail
      enhancedQueryLog += '=== Step 3: Query by recipientEmail ===\n';
      final recipientEmailQuery = await FirebaseFirestore.instance
          .collection('certificates')
          .where('recipientEmail', isEqualTo: currentUser.email)
          .get();

      enhancedQueryLog +=
          'Found ${recipientEmailQuery.docs.length} certificates by recipientEmail\n';

      for (final doc in recipientEmailQuery.docs) {
        final data = doc.data();
        enhancedQueryLog +=
            'Email Match: ${data['title']} | ${data['recipientEmail']}\n';
      }
      enhancedQueryLog += '\n';

      // 🔥 Step 4: Test our enhanced service method
      enhancedQueryLog += '=== Step 4: Enhanced Service Method ===\n';
      final certificateService = CertificateService();
      final certificates = await certificateService.getUserCertificates(
        userId: currentUser.id,
        userRole: CertificateUserRole.recipient,
        limit: 50,
      );

      enhancedQueryLog +=
          'Enhanced Query Results: ${certificates.length} certificates\n\n';

      enhancedQueryResults = certificates
          .map((cert) => {
                'documentId': cert.id,
                'title': cert.title,
                'recipientId': cert.recipientId,
                'recipientEmail': cert.recipientEmail,
                'recipientName': cert.recipientName,
                'status': cert.status.name,
                'issuerId': cert.issuerId,
                'issuerName': cert.issuerName,
                'createdAt': cert.createdAt.toIso8601String(),
                'matchesUserId': cert.recipientId == currentUser.id,
                'matchesUserEmail': cert.recipientEmail == currentUser.email,
              })
          .toList();

      for (int i = 0; i < certificates.length; i++) {
        final cert = certificates[i];
        enhancedQueryLog += 'Certificate ${i + 1}:\n';
        enhancedQueryLog += '  Title: ${cert.title}\n';
        enhancedQueryLog += '  Recipient ID: ${cert.recipientId}\n';
        enhancedQueryLog += '  Recipient Email: ${cert.recipientEmail}\n';
        enhancedQueryLog +=
            '  Matches User ID: ${cert.recipientId == currentUser.id}\n';
        enhancedQueryLog +=
            '  Matches User Email: ${cert.recipientEmail == currentUser.email}\n';
        enhancedQueryLog += '  Created: ${cert.createdAt}\n\n';
      }

      // 🔧 Step 5: Auto-fix certificates with missing or incorrect email
      enhancedQueryLog += '=== Step 5: Auto-Fix Missing Emails ===\n';
      int fixedCount = 0;

      try {
        final certificatesNeedingFix = await FirebaseFirestore.instance
            .collection('certificates')
            .where('recipientId', isEqualTo: currentUser.id)
            .get();

        for (final doc in certificatesNeedingFix.docs) {
          final data = doc.data();
          final recipientEmail = data['recipientEmail'] as String?;

          // Fix if email is empty, null, or doesn't match current user's email
          if (recipientEmail == null ||
              recipientEmail.isEmpty ||
              recipientEmail == 'unknown@example.com' ||
              recipientEmail != currentUser.email) {
            try {
              await FirebaseFirestore.instance
                  .collection('certificates')
                  .doc(doc.id)
                  .update({
                'recipientEmail': currentUser.email,
                'updatedAt': FieldValue.serverTimestamp(),
                'metadata.autoFixed': true,
                'metadata.autoFixedAt': FieldValue.serverTimestamp(),
                'metadata.originalEmail': recipientEmail ?? 'none',
              });

              fixedCount++;
              enhancedQueryLog +=
                  'Fixed certificate ${doc.id}: "$recipientEmail" -> "${currentUser.email}"\n';
            } catch (e) {
              enhancedQueryLog += 'Failed to fix certificate ${doc.id}: $e\n';
            }
          }
        }

        enhancedQueryLog +=
            'Auto-fix completed: $fixedCount certificates fixed\n\n';
      } catch (e) {
        enhancedQueryLog += 'Auto-fix failed: $e\n\n';
      }

      // 🔥 Step 6: Re-test enhanced query after auto-fix
      enhancedQueryLog +=
          '=== Step 6: Re-test Enhanced Query (After Auto-Fix) ===\n';
      final certificatesAfterFix = await certificateService.getUserCertificates(
        userId: currentUser.id,
        userRole: CertificateUserRole.recipient,
        limit: 50,
      );

      enhancedQueryLog +=
          'Enhanced Query After Auto-Fix: ${certificatesAfterFix.length} certificates\n\n';

      // 🔥 Step 7: Direct service call comparison
      enhancedQueryLog += '=== Step 7: Direct Service Call ===\n';
      try {
        final directService = CertificateService();
        final directResults = await directService.getUserCertificates(
          userId: currentUser.id,
          userRole: CertificateUserRole.recipient,
        );
        enhancedQueryLog +=
            'Direct service call returned: ${directResults.length} certificates\n';
      } catch (e) {
        enhancedQueryLog += 'Direct service error: $e\n';
      }

      LoggerService.info('✅ Enhanced query test completed successfully');
    } catch (e, stackTrace) {
      LoggerService.error('❌ Enhanced query test failed',
          error: e, stackTrace: stackTrace);
      enhancedQueryLog += 'ERROR: $e\n';
      enhancedQueryLog += 'Stack trace: $stackTrace\n';
    } finally {
      setState(() {
        isTestingEnhancedQuery = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recipient Certificate Debug'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDebugData,
          ),
          // 🆕 Enhanced query test button
          IconButton(
            icon: const Icon(Icons.science),
            onPressed: isTestingEnhancedQuery ? null : _testEnhancedQuery,
            tooltip: 'Test Enhanced Query',
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
                      // 🆕 Enhanced Query Test Section
                      _buildEnhancedQueryTestSection(),
                      const SizedBox(height: 16),
                      _buildUserInfoCard(),
                      const SizedBox(height: 16),
                      _buildAnalysisCard(),
                      const SizedBox(height: 16),
                      _buildSummaryCard(),
                      const SizedBox(height: 16),
                      _buildUserCertificatesSection(),
                      const SizedBox(height: 16),
                      _buildUserDocumentsSection(),
                      const SizedBox(height: 16),
                      _buildRecentActivitiesSection(),
                      const SizedBox(height: 16),
                      _buildAllCertificatesSection(),
                    ],
                  ),
                ),
    );
  }

  // 🆕 Enhanced Query Test Section
  Widget _buildEnhancedQueryTestSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.science, color: Colors.blue),
                const SizedBox(width: 8),
                const Text(
                  'Enhanced Query Test',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: isTestingEnhancedQuery ? null : _testEnhancedQuery,
                  icon: isTestingEnhancedQuery
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.play_arrow),
                  label:
                      Text(isTestingEnhancedQuery ? 'Testing...' : 'Run Test'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'Tests the new enhanced query logic that searches by both recipientId and recipientEmail.',
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
            if (enhancedQueryResults.isNotEmpty ||
                enhancedQueryLog.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Enhanced Query Results (${enhancedQueryResults.length} certificates)',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    if (enhancedQueryResults.isEmpty && !isTestingEnhancedQuery)
                      const Text('No certificates found with enhanced query'),
                    ...enhancedQueryResults
                        .map((cert) => _buildEnhancedQueryResultCard(cert)),
                  ],
                ),
              ),
              if (enhancedQueryLog.isNotEmpty) ...[
                const SizedBox(height: 12),
                ExpansionTile(
                  title: const Text('Query Log Details'),
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.black87,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        enhancedQueryLog,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                          color: Colors.green,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEnhancedQueryResultCard(Map<String, dynamic> cert) {
    final matchesUserId = cert['matchesUserId'] as bool;
    final matchesUserEmail = cert['matchesUserEmail'] as bool;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(
          color: (matchesUserId || matchesUserEmail)
              ? Colors.green
              : Colors.orange,
          width: 2,
        ),
        borderRadius: BorderRadius.circular(8),
        color: (matchesUserId || matchesUserEmail)
            ? Colors.green.withValues(alpha: 0.1)
            : Colors.orange.withValues(alpha: 0.1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            cert['title'] ?? 'No title',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text('Certificate ID: ${cert['documentId']}'),
          Text('Recipient ID: ${cert['recipientId']}'),
          Text('Recipient Email: ${cert['recipientEmail']}'),
          Text('Status: ${cert['status']}'),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(
                matchesUserId ? Icons.check_circle : Icons.cancel,
                color: matchesUserId ? Colors.green : Colors.red,
                size: 16,
              ),
              const SizedBox(width: 4),
              Text('ID Match: $matchesUserId'),
              const SizedBox(width: 16),
              Icon(
                matchesUserEmail ? Icons.check_circle : Icons.cancel,
                color: matchesUserEmail ? Colors.green : Colors.red,
                size: 16,
              ),
              const SizedBox(width: 4),
              Text('Email Match: $matchesUserEmail'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUserInfoCard() {
    return Card(
      color: Colors.blue.shade50,
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
            Text('User ID: $currentUserId'),
            Text('Email: $currentUserEmail'),
            Text('Total Users in System: ${allUsers.length}'),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalysisCard() {
    return Card(
      color: Colors.green.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Flow Analysis',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
                'Documents uploaded by user: ${analysisResults['userDocuments']}'),
            Text(
                'User-related activities: ${analysisResults['userActivities']}'),
            Text(
                'Certificates based on user documents: ${analysisResults['certificatesBasedOnUserDocuments']}'),
            Text(
                'Certificate creation activities: ${analysisResults['certificateCreationActivities']}'),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard() {
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
            Text('Total Certificates: ${allCertificates.length}'),
            Text('User\'s Certificates: ${userCertificates.length}'),
            Text('Total Documents: ${allDocuments.length}'),
            Text('Recent Activities: ${recentActivities.length}'),
          ],
        ),
      ),
    );
  }

  Widget _buildUserCertificatesSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'User Certificates (${userCertificates.length})',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (userCertificates.isEmpty)
              const Text(
                'No certificates found for current user',
                style:
                    TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
              )
            else
              ...userCertificates
                  .map((cert) => _buildCertificateCard(cert, true)),
          ],
        ),
      ),
    );
  }

  Widget _buildUserDocumentsSection() {
    final userDocs =
        analysisResults['userDocumentsList'] as List<Map<String, dynamic>>? ??
            [];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'User Documents (${analysisResults['userDocuments']})',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (userDocs.isEmpty)
              const Text('No documents uploaded by current user')
            else
              ...userDocs.map((doc) => _buildDocumentCard(doc)),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentActivitiesSection() {
    final userActivities =
        analysisResults['userActivitiesList'] as List<Map<String, dynamic>>? ??
            [];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Recent Activities (${analysisResults['userActivities']})',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (userActivities.isEmpty)
              const Text('No recent activities found')
            else
              ...userActivities.map((activity) => _buildActivityCard(activity)),
          ],
        ),
      ),
    );
  }

  Widget _buildAllCertificatesSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'All Certificates (${allCertificates.length})',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (allCertificates.isEmpty)
              const Text('No certificates found in Firestore')
            else
              ...allCertificates
                  .take(5)
                  .map((cert) => _buildCertificateCard(cert, false)),
            if (allCertificates.length > 5)
              Text('... and ${allCertificates.length - 5} more certificates'),
          ],
        ),
      ),
    );
  }

  Widget _buildCertificateCard(Map<String, dynamic> cert, bool isUserCert) {
    final recipientId = cert['recipientId'] as String?;
    final recipientEmail = cert['recipientEmail'] as String?;
    final title = cert['title'] as String?;
    final status = cert['status'] as String?;
    final createdAt = cert['createdAt'] as Timestamp?;
    final metadata = cert['metadata'] as Map<String, dynamic>?;
    final basedOnDocumentId = metadata?['basedOnDocumentId'] as String?;

    bool matchesCurrentId = recipientId == currentUserId;
    bool matchesCurrentEmail = recipientEmail == currentUserEmail;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(
          color: isUserCert ? Colors.green : Colors.grey,
          width: isUserCert ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(8),
        color: isUserCert ? Colors.green.withValues(alpha: 0.1) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title ?? 'No title',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text('Certificate ID: ${cert['documentId']}'),
          Text('Recipient ID: $recipientId'),
          Text('Recipient Email: $recipientEmail'),
          Text('Status: $status'),
          if (basedOnDocumentId != null)
            Text('Based on Document: $basedOnDocumentId'),
          if (createdAt != null) Text('Created: ${createdAt.toDate()}'),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(
                matchesCurrentId ? Icons.check_circle : Icons.cancel,
                color: matchesCurrentId ? Colors.green : Colors.red,
                size: 16,
              ),
              const SizedBox(width: 4),
              Text('ID Match: $matchesCurrentId'),
              const SizedBox(width: 16),
              Icon(
                matchesCurrentEmail ? Icons.check_circle : Icons.cancel,
                color: matchesCurrentEmail ? Colors.green : Colors.red,
                size: 16,
              ),
              const SizedBox(width: 4),
              Text('Email Match: $matchesCurrentEmail'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentCard(Map<String, dynamic> doc) {
    final title = doc['title'] as String?;
    final status = doc['status'] as String?;
    final uploaderId = doc['uploaderId'] as String?;
    final createdAt = doc['createdAt'] as Timestamp?;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.blue),
        borderRadius: BorderRadius.circular(8),
        color: Colors.blue.withValues(alpha: 0.1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title ?? 'No title',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          Text('Document ID: ${doc['documentId']}'),
          Text('Status: $status'),
          Text('Uploader ID: $uploaderId'),
          if (createdAt != null) Text('Created: ${createdAt.toDate()}'),
        ],
      ),
    );
  }

  Widget _buildActivityCard(Map<String, dynamic> activity) {
    final type = activity['type'] as String?;
    final timestamp = activity['timestamp'] as Timestamp?;
    final recipientId = activity['recipientId'] as String?;
    final certificateId = activity['certificateId'] as String?;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.orange),
        borderRadius: BorderRadius.circular(8),
        color: Colors.orange.withValues(alpha: 0.1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            type ?? 'No type',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          if (certificateId != null) Text('Certificate ID: $certificateId'),
          if (recipientId != null) Text('Recipient ID: $recipientId'),
          if (timestamp != null) Text('Time: ${timestamp.toDate()}'),
        ],
      ),
    );
  }
}
