import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/widgets/custom_app_bar.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/providers/auth_providers.dart';

// 用户验证结果提供者
final userVerificationProvider = StateNotifierProvider.family<
    UserVerificationNotifier,
    AsyncValue<Map<String, dynamic>?>,
    String>((ref, userId) {
  return UserVerificationNotifier(userId);
});

class UserVerificationNotifier
    extends StateNotifier<AsyncValue<Map<String, dynamic>?>> {
  final String userId;

  UserVerificationNotifier(this.userId) : super(const AsyncValue.loading()) {
    _verifyUser();
  }

  Future<void> _verifyUser() async {
    try {
      // 从Firebase获取用户数据
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

      if (userDoc.exists) {
        final userData = userDoc.data()!;

        // 获取用户相关的文档和证书
        final documentsQuery = await FirebaseFirestore.instance
            .collection('documents')
            .where('uploadedBy', isEqualTo: userId)
            .get();

        final certificatesQuery = await FirebaseFirestore.instance
            .collection('certificates')
            .where('recipientId', isEqualTo: userId)
            .get();

        // 执行验证检查
        final verificationResult = await _performUserVerificationChecks(
          userData,
          documentsQuery.docs,
          certificatesQuery.docs,
        );

        state = AsyncValue.data({
          'userData': userData,
          'documents': documentsQuery.docs
              .map((doc) => {
                    'id': doc.id,
                    ...doc.data(),
                  })
              .toList(),
          'certificates': certificatesQuery.docs
              .map((doc) => {
                    'id': doc.id,
                    ...doc.data(),
                  })
              .toList(),
          'verificationResult': verificationResult,
          'verifiedAt': DateTime.now().toIso8601String(),
        });

        // 记录验证活动
        await FirebaseFirestore.instance
            .collection('user_verification_logs')
            .add({
          'userId': userId,
          'verifiedAt': FieldValue.serverTimestamp(),
          'verificationResult': verificationResult,
          'verifierType': 'ca_system',
        });
      } else {
        state = const AsyncValue.data(null);
      }
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<Map<String, dynamic>> _performUserVerificationChecks(
      Map<String, dynamic> userData,
      List<QueryDocumentSnapshot> documents,
      List<QueryDocumentSnapshot> certificates) async {
    final checks = <String, bool>{};
    final details = <String, dynamic>{};

    // 1. 基本信息验证
    checks['profileComplete'] = _verifyProfileCompleteness(userData);
    details['profileScore'] = _calculateProfileScore(userData);

    // 2. 邮箱验证
    checks['emailVerified'] = userData['emailVerified'] == true;
    checks['upmEmail'] = _verifyUPMEmail(userData['email']);

    // 3. 文档验证
    checks['documentsUploaded'] = documents.isNotEmpty;
    details['documentsCount'] = documents.length;
    details['approvedDocuments'] = documents.where((doc) {
      final data = doc.data() as Map<String, dynamic>?;
      return data != null && data['status'] == 'approved';
    }).length;

    // 4. 证书历史验证
    details['certificatesCount'] = certificates.length;
    details['activeCertificates'] = certificates.where((cert) {
      final data = cert.data() as Map<String, dynamic>?;
      return data != null && data['status'] == 'active';
    }).length;

    // 5. 活动验证
    checks['recentActivity'] = await _verifyRecentActivity(userData['id']);

    // 6. 状态验证
    checks['accountActive'] = userData['status'] == 'active';

    final allCriticalChecks = [
      'profileComplete',
      'emailVerified',
      'accountActive'
    ].every((check) => checks[check] == true);

    final score = checks.values.where((v) => v).length / checks.length * 100;

    return {
      'isVerified': allCriticalChecks,
      'overallScore': score,
      'checks': checks,
      'details': details,
      'recommendation': _generateRecommendation(checks, details),
      'verifiedAt': DateTime.now().toIso8601String(),
    };
  }

  bool _verifyProfileCompleteness(Map<String, dynamic> userData) {
    final requiredFields = ['displayName', 'email', 'phone'];
    return requiredFields.every((field) =>
        userData[field] != null && userData[field].toString().isNotEmpty);
  }

  double _calculateProfileScore(Map<String, dynamic> userData) {
    final allFields = [
      'displayName',
      'email',
      'phone',
      'photoURL',
      'address',
      'institution',
      'studentId'
    ];
    final completedFields = allFields
        .where((field) =>
            userData[field] != null && userData[field].toString().isNotEmpty)
        .length;
    return (completedFields / allFields.length) * 100;
  }

  bool _verifyUPMEmail(String? email) {
    if (email == null) return false;
    return email.endsWith('@upm.edu.my') ||
        email.endsWith('@student.upm.edu.my') ||
        email.endsWith('@staff.upm.edu.my');
  }

  Future<bool> _verifyRecentActivity(String? userId) async {
    if (userId == null) return false;

    try {
      final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));

      // 检查最近的登录活动
      final activityQuery = await FirebaseFirestore.instance
          .collection('user_activities')
          .where('userId', isEqualTo: userId)
          .where('timestamp', isGreaterThan: Timestamp.fromDate(thirtyDaysAgo))
          .limit(1)
          .get();

      return activityQuery.docs.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  String _generateRecommendation(
      Map<String, bool> checks, Map<String, dynamic> details) {
    final issues = <String>[];

    if (checks['profileComplete'] != true) {
      issues.add('Complete user profile information');
    }
    if (checks['emailVerified'] != true) {
      issues.add('Verify email address');
    }
    if (checks['upmEmail'] != true) {
      issues.add('Use official UPM email address');
    }
    if (checks['documentsUploaded'] != true) {
      issues.add('Upload required documents');
    }
    if (checks['recentActivity'] != true) {
      issues.add('Encourage recent platform activity');
    }
    if (checks['accountActive'] != true) {
      issues.add('Account needs activation');
    }

    if (issues.isEmpty) {
      return 'User verification successful. All checks passed.';
    } else {
      return 'Issues found: ${issues.join(', ')}.';
    }
  }

  void refresh() {
    state = const AsyncValue.loading();
    _verifyUser();
  }
}

class CAUserVerificationPage extends ConsumerStatefulWidget {
  const CAUserVerificationPage({super.key});

  @override
  ConsumerState<CAUserVerificationPage> createState() =>
      _CAUserVerificationPageState();
}

class _CAUserVerificationPageState
    extends ConsumerState<CAUserVerificationPage> {
  final TextEditingController _userIdController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  String? currentVerificationId;
  bool isSearchByEmail = false;

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserProvider).value;

    if (currentUser == null || (!currentUser.isCA && !currentUser.isAdmin)) {
      return Scaffold(
        appBar: const CustomAppBar(title: 'User Information Verification'),
        body: _buildUnauthorizedView(),
      );
    }

    return Scaffold(
      appBar: const CustomAppBar(title: 'User Information Verification'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeaderSection(),
            const SizedBox(height: 24),
            _buildSearchSection(),
            const SizedBox(height: 24),
            if (currentVerificationId != null) ...[
              _buildVerificationResultsSection(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildUnauthorizedView() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.lock, size: 64, color: AppTheme.errorColor),
          SizedBox(height: 16),
          Text(
            'Unauthorized Access',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppTheme.errorColor,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Only CA staff can verify user information',
            style: TextStyle(color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.person_search,
                color: AppTheme.primaryColor,
                size: 32,
              ),
            ),
            const SizedBox(width: 16),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'User Information Verification',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Verify user identity, documents, and academic credentials',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Search User',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),

            // Search method toggle
            Row(
              children: [
                Expanded(
                  child: CheckboxListTile(
                    title: const Text('Search by User ID'),
                    value: !isSearchByEmail,
                    onChanged: (value) {
                      setState(() {
                        isSearchByEmail = false;
                        _userIdController.clear();
                        _emailController.clear();
                      });
                    },
                  ),
                ),
                Expanded(
                  child: CheckboxListTile(
                    title: const Text('Search by Email'),
                    value: isSearchByEmail,
                    onChanged: (value) {
                      setState(() {
                        isSearchByEmail = true;
                        _userIdController.clear();
                        _emailController.clear();
                      });
                    },
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            if (!isSearchByEmail) ...[
              // User ID Search
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _userIdController,
                      decoration: const InputDecoration(
                        labelText: 'User ID',
                        hintText: 'Enter user ID to verify',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _verifyUserById,
                    icon: const Icon(Icons.search),
                    label: const Text('Verify'),
                  ),
                ],
              ),
            ] else ...[
              // Email Search
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _emailController,
                      decoration: const InputDecoration(
                        labelText: 'Email Address',
                        hintText: 'Enter email to search user',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.email),
                      ),
                      keyboardType: TextInputType.emailAddress,
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _searchUserByEmail,
                    icon: const Icon(Icons.search),
                    label: const Text('Search'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildVerificationResultsSection() {
    final verificationAsync =
        ref.watch(userVerificationProvider(currentVerificationId!));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Verification Results',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                IconButton(
                  onPressed: () {
                    ref
                        .read(userVerificationProvider(currentVerificationId!)
                            .notifier)
                        .refresh();
                  },
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            const SizedBox(height: 16),
            verificationAsync.when(
              data: (result) {
                if (result == null) {
                  return _buildNotFoundResult();
                }
                return _buildUserVerificationResult(result);
              },
              loading: () => _buildLoadingResult(),
              error: (error, stack) => _buildErrorResult(error.toString()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserVerificationResult(Map<String, dynamic> data) {
    final userData = data['userData'] as Map<String, dynamic>;
    final verification = data['verificationResult'] as Map<String, dynamic>;
    final documents = data['documents'] as List<dynamic>;
    final certificates = data['certificates'] as List<dynamic>;

    final isVerified = verification['isVerified'] as bool;
    final score = verification['overallScore'] as double;
    final checks = verification['checks'] as Map<String, dynamic>;
    final details = verification['details'] as Map<String, dynamic>;
    final recommendation = verification['recommendation'] as String;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Overall Status
        _buildOverallStatus(isVerified, score, recommendation),

        const SizedBox(height: 16),

        // User Information
        _buildUserInformation(userData),

        const SizedBox(height: 16),

        // Verification Checks
        _buildVerificationChecks(checks, details),

        const SizedBox(height: 16),

        // Documents Summary
        _buildDocumentsSummary(documents),

        const SizedBox(height: 16),

        // Certificates Summary
        _buildCertificatesSummary(certificates),
      ],
    );
  }

  Widget _buildOverallStatus(
      bool isVerified, double score, String recommendation) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isVerified
            ? AppTheme.successColor.withValues(alpha: 0.1)
            : AppTheme.warningColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isVerified ? AppTheme.successColor : AppTheme.warningColor,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isVerified ? Icons.verified_user : Icons.warning,
                color:
                    isVerified ? AppTheme.successColor : AppTheme.warningColor,
                size: 32,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isVerified
                          ? 'User Verified'
                          : 'Verification Issues Found',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isVerified
                            ? AppTheme.successColor
                            : AppTheme.warningColor,
                      ),
                    ),
                    Text(
                      'Verification Score: ${score.toStringAsFixed(1)}%',
                      style: const TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Recommendation: $recommendation',
            style: const TextStyle(
              fontSize: 14,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserInformation(Map<String, dynamic> userData) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'User Information',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          _buildDetailRow('Name', userData['displayName'] ?? 'N/A'),
          _buildDetailRow('Email', userData['email'] ?? 'N/A'),
          _buildDetailRow('Phone', userData['phone'] ?? 'N/A'),
          _buildDetailRow('User Type', userData['userType'] ?? 'N/A'),
          _buildDetailRow('Status', userData['status'] ?? 'N/A'),
          _buildDetailRow('Institution', userData['institution'] ?? 'N/A'),
          if (userData['studentId'] != null)
            _buildDetailRow('Student ID', userData['studentId']),
        ],
      ),
    );
  }

  Widget _buildVerificationChecks(
      Map<String, dynamic> checks, Map<String, dynamic> details) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Verification Checks',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          ...checks.entries
              .map((entry) => _buildCheckItem(entry.key, entry.value)),
          const SizedBox(height: 12),
          const Divider(),
          const SizedBox(height: 8),
          _buildDetailRow('Profile Score',
              '${details['profileScore']?.toStringAsFixed(1) ?? '0'}%'),
          _buildDetailRow(
              'Documents Count', '${details['documentsCount'] ?? 0}'),
          _buildDetailRow(
              'Approved Documents', '${details['approvedDocuments'] ?? 0}'),
          _buildDetailRow(
              'Certificates Count', '${details['certificatesCount'] ?? 0}'),
          _buildDetailRow(
              'Active Certificates', '${details['activeCertificates'] ?? 0}'),
        ],
      ),
    );
  }

  Widget _buildDocumentsSummary(List<dynamic> documents) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Documents (${documents.length})',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          if (documents.isEmpty) ...[
            const Text(
              'No documents uploaded',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          ] else ...[
            ...documents.take(3).map((doc) => ListTile(
                  dense: true,
                  title: Text(doc['title'] ?? 'Untitled Document'),
                  subtitle: Text('Status: ${doc['status'] ?? 'Unknown'}'),
                  trailing: Icon(
                    doc['status'] == 'approved'
                        ? Icons.check_circle
                        : doc['status'] == 'rejected'
                            ? Icons.cancel
                            : Icons.pending,
                    color: doc['status'] == 'approved'
                        ? AppTheme.successColor
                        : doc['status'] == 'rejected'
                            ? AppTheme.errorColor
                            : AppTheme.warningColor,
                  ),
                )),
            if (documents.length > 3) ...[
              Text(
                '... and ${documents.length - 3} more documents',
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildCertificatesSummary(List<dynamic> certificates) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Certificates (${certificates.length})',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          if (certificates.isEmpty) ...[
            const Text(
              'No certificates issued',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          ] else ...[
            ...certificates.take(3).map((cert) => ListTile(
                  dense: true,
                  title: Text(cert['type'] ?? 'Certificate'),
                  subtitle: Text('Status: ${cert['status'] ?? 'Unknown'}'),
                  trailing: Icon(
                    cert['status'] == 'active'
                        ? Icons.verified
                        : cert['status'] == 'revoked'
                            ? Icons.cancel
                            : Icons.pending,
                    color: cert['status'] == 'active'
                        ? AppTheme.successColor
                        : cert['status'] == 'revoked'
                            ? AppTheme.errorColor
                            : AppTheme.warningColor,
                  ),
                )),
            if (certificates.length > 3) ...[
              Text(
                '... and ${certificates.length - 3} more certificates',
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: AppTheme.textSecondary,
              ),
            ),
          ),
          const Text(': '),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckItem(String checkName, bool isValid) {
    final displayName = _getCheckDisplayName(checkName);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            isValid ? Icons.check_circle : Icons.cancel,
            color: isValid ? AppTheme.successColor : AppTheme.errorColor,
            size: 20,
          ),
          const SizedBox(width: 8),
          Text(
            displayName,
            style: TextStyle(
              color: isValid ? AppTheme.successColor : AppTheme.errorColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  String _getCheckDisplayName(String checkName) {
    switch (checkName) {
      case 'profileComplete':
        return 'Profile Complete';
      case 'emailVerified':
        return 'Email Verified';
      case 'upmEmail':
        return 'UPM Email Address';
      case 'documentsUploaded':
        return 'Documents Uploaded';
      case 'recentActivity':
        return 'Recent Activity';
      case 'accountActive':
        return 'Account Active';
      default:
        return checkName;
    }
  }

  Widget _buildNotFoundResult() {
    return const Center(
      child: Column(
        children: [
          Icon(Icons.person_off, size: 48, color: AppTheme.textSecondary),
          SizedBox(height: 16),
          Text(
            'User Not Found',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'The user was not found in our database',
            style: TextStyle(color: AppTheme.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingResult() {
    return const Center(
      child: Column(
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Verifying user information...'),
        ],
      ),
    );
  }

  Widget _buildErrorResult(String error) {
    return Center(
      child: Column(
        children: [
          const Icon(Icons.error, size: 48, color: AppTheme.errorColor),
          const SizedBox(height: 16),
          const Text(
            'Verification Failed',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppTheme.errorColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            error,
            style: const TextStyle(color: AppTheme.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  void _verifyUserById() {
    final userId = _userIdController.text.trim();
    if (userId.isNotEmpty) {
      setState(() {
        currentVerificationId = userId;
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a user ID'),
          backgroundColor: AppTheme.warningColor,
        ),
      );
    }
  }

  void _searchUserByEmail() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter an email address'),
          backgroundColor: AppTheme.warningColor,
        ),
      );
      return;
    }

    try {
      // Search for user by email
      final query = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (query.docs.isNotEmpty) {
        final userId = query.docs.first.id;
        setState(() {
          currentVerificationId = userId;
        });
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No user found with this email address'),
              backgroundColor: AppTheme.errorColor,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error searching user: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _userIdController.dispose();
    _emailController.dispose();
    super.dispose();
  }
}
