import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:animate_do/animate_do.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/custom_app_bar.dart';
import '../../../../core/models/user_model.dart';
import '../../../auth/providers/auth_providers.dart';

class RoleApprovalPage extends ConsumerStatefulWidget {
  const RoleApprovalPage({super.key});

  @override
  ConsumerState<RoleApprovalPage> createState() => _RoleApprovalPageState();
}

class _RoleApprovalPageState extends ConsumerState<RoleApprovalPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedRole = 'all';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserProvider).value;

    if (currentUser?.userType != UserType.admin) {
      return Scaffold(
        appBar: const CustomAppBar(title: 'Role Approval'),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock, size: 80, color: AppTheme.errorColor),
              const SizedBox(height: 16),
              Text('Admin Access Required',
                  style: AppTheme.textTheme.headlineMedium
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('Only administrators can access role approvals.',
                  style: AppTheme.textTheme.bodyLarge
                      ?.copyWith(color: AppTheme.textSecondary)),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: const CustomAppBar(title: 'Role Application Approval'),
      body: Column(
        children: [
          _buildFilterSection(),
          _buildTabBar(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildPendingApprovals(),
                _buildApprovedApplications(),
                _buildRejectedApplications(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.backgroundLight,
        border:
            Border(bottom: BorderSide(color: AppTheme.dividerColor, width: 1)),
      ),
      child: Row(
        children: [
          Text('Filter by Role:',
              style: AppTheme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(width: 16),
          Expanded(
            child: DropdownButtonFormField<String>(
              value: _selectedRole,
              decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
              items: const [
                DropdownMenuItem(value: 'all', child: Text('All Roles')),
                DropdownMenuItem(
                    value: 'client',
                    child: Text('Certificate Reviewer (Client)')),
                DropdownMenuItem(
                    value: 'ca', child: Text('Certificate Authority (CA)')),
              ],
              onChanged: (value) =>
                  setState(() => _selectedRole = value ?? 'all'),
            ),
          ),
          const SizedBox(width: 16),
          ElevatedButton.icon(
            onPressed: _isLoading ? null : _refreshData,
            icon: _isLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.refresh),
            label: const Text('Refresh'),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.backgroundLight,
        border:
            Border(bottom: BorderSide(color: AppTheme.dividerColor, width: 1)),
      ),
      child: TabBar(
        controller: _tabController,
        labelColor: AppTheme.primaryColor,
        unselectedLabelColor: AppTheme.textSecondary,
        indicatorColor: AppTheme.primaryColor,
        tabs: const [
          Tab(icon: Icon(Icons.pending_actions), text: 'Pending'),
          Tab(icon: Icon(Icons.check_circle), text: 'Approved'),
          Tab(icon: Icon(Icons.cancel), text: 'Rejected'),
        ],
      ),
    );
  }

  Widget _buildPendingApprovals() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .where('status', isEqualTo: 'pending')
          .where('userType', whereIn: ['client', 'ca'])
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError)
          return _buildErrorWidget(snapshot.error.toString());
        if (snapshot.connectionState == ConnectionState.waiting)
          return const Center(child: CircularProgressIndicator());

        final users = snapshot.data?.docs ?? [];
        var filteredUsers = _selectedRole == 'all'
            ? users
            : users.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                return data['userType'] == _selectedRole;
              }).toList();

        if (filteredUsers.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.check_circle_outline,
                    size: 80, color: AppTheme.textSecondary),
                const SizedBox(height: 16),
                Text('No Pending Applications',
                    style: AppTheme.textTheme.headlineMedium
                        ?.copyWith(color: AppTheme.textSecondary)),
                const SizedBox(height: 8),
                Text('All applications have been processed.',
                    style: AppTheme.textTheme.bodyLarge
                        ?.copyWith(color: AppTheme.textSecondary)),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: filteredUsers.length,
          itemBuilder: (context, index) {
            final userDoc = filteredUsers[index];
            final userData = userDoc.data() as Map<String, dynamic>;
            return FadeInUp(
              duration: Duration(milliseconds: 300 + (index * 100)),
              child: _buildUserApplicationCard(userDoc.id, userData, 'pending'),
            );
          },
        );
      },
    );
  }

  Widget _buildApprovedApplications() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .where('status', isEqualTo: 'active')
          .where('userType', whereIn: ['client', 'ca'])
          .orderBy('approvedAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError)
          return _buildErrorWidget(snapshot.error.toString());
        if (snapshot.connectionState == ConnectionState.waiting)
          return const Center(child: CircularProgressIndicator());

        final users = snapshot.data?.docs ?? [];
        var filteredUsers = _selectedRole == 'all'
            ? users
            : users.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                return data['userType'] == _selectedRole;
              }).toList();

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: filteredUsers.length,
          itemBuilder: (context, index) {
            final userDoc = filteredUsers[index];
            final userData = userDoc.data() as Map<String, dynamic>;
            return _buildUserApplicationCard(userDoc.id, userData, 'approved');
          },
        );
      },
    );
  }

  Widget _buildRejectedApplications() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .where('status', isEqualTo: 'rejected')
          .where('userType', whereIn: ['client', 'ca'])
          .orderBy('rejectedAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError)
          return _buildErrorWidget(snapshot.error.toString());
        if (snapshot.connectionState == ConnectionState.waiting)
          return const Center(child: CircularProgressIndicator());

        final users = snapshot.data?.docs ?? [];
        var filteredUsers = _selectedRole == 'all'
            ? users
            : users.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                return data['userType'] == _selectedRole;
              }).toList();

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: filteredUsers.length,
          itemBuilder: (context, index) {
            final userDoc = filteredUsers[index];
            final userData = userDoc.data() as Map<String, dynamic>;
            return _buildUserApplicationCard(userDoc.id, userData, 'rejected');
          },
        );
      },
    );
  }

  Widget _buildUserApplicationCard(
      String userId, Map<String, dynamic> userData, String status) {
    final userType = userData['userType'] as String;
    final roleTitle =
        userType == 'client' ? 'Certificate Reviewer' : 'Certificate Authority';
    final roleDescription = userType == 'client'
        ? 'Reviews and approves CA-created certificate templates'
        : 'Reviews student documents and creates certificate templates';

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor:
                      _getRoleColor(userType).withValues(alpha: 0.1),
                  child: Icon(_getRoleIcon(userType),
                      color: _getRoleColor(userType)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(userData['displayName'] ?? 'Unknown User',
                          style: AppTheme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold)),
                      Text(userData['email'] ?? 'No email',
                          style: AppTheme.textTheme.bodyMedium
                              ?.copyWith(color: AppTheme.textSecondary)),
                    ],
                  ),
                ),
                _buildStatusBadge(status),
              ],
            ),
            const SizedBox(height: 12),
            Text(roleTitle,
                style: AppTheme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: _getRoleColor(userType))),
            const SizedBox(height: 4),
            Text(roleDescription,
                style: AppTheme.textTheme.bodySmall
                    ?.copyWith(color: AppTheme.textSecondary)),
            const SizedBox(height: 12),
            _buildApplicationDetails(userData),
            if (status == 'pending') ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _rejectApplication(userId, userData),
                      icon: const Icon(Icons.close, size: 16),
                      label: const Text('Reject'),
                      style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.errorColor,
                          side: BorderSide(color: AppTheme.errorColor)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _approveApplication(userId, userData),
                      icon: const Icon(Icons.check, size: 16),
                      label: const Text('Approve'),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.successColor,
                          foregroundColor: Colors.white),
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

  Widget _buildApplicationDetails(Map<String, dynamic> userData) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.backgroundLight,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.dividerColor.withValues(alpha: 0.5)),
      ),
      child: Column(
        children: [
          _buildDetailRow(
              'Application Date',
              _formatDate((userData['createdAt'] as Timestamp?)?.toDate() ??
                  DateTime.now())),
          if (userData['institution'] != null)
            _buildDetailRow('Institution', userData['institution']),
          if (userData['phone'] != null)
            _buildDetailRow('Phone', userData['phone']),
          if (userData['rejectionReason'] != null)
            _buildDetailRow('Rejection Reason', userData['rejectionReason']),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
              width: 100,
              child: Text('$label:',
                  style: AppTheme.textTheme.bodySmall?.copyWith(
                      color: AppTheme.textSecondary,
                      fontWeight: FontWeight.w600))),
          Expanded(child: Text(value, style: AppTheme.textTheme.bodySmall)),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    String text;
    IconData icon;

    switch (status) {
      case 'pending':
        color = AppTheme.warningColor;
        text = 'Pending';
        icon = Icons.pending;
        break;
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
          Text(text,
              style: TextStyle(
                  color: color, fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildErrorWidget(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: AppTheme.errorColor),
          const SizedBox(height: 16),
          Text('Error Loading Applications',
              style: AppTheme.textTheme.headlineMedium
                  ?.copyWith(color: AppTheme.errorColor)),
          const SizedBox(height: 8),
          Text(error,
              style: AppTheme.textTheme.bodyMedium
                  ?.copyWith(color: AppTheme.textSecondary),
              textAlign: TextAlign.center),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: _refreshData, child: const Text('Retry')),
        ],
      ),
    );
  }

  IconData _getRoleIcon(String userType) {
    switch (userType) {
      case 'client':
        return Icons.rate_review;
      case 'ca':
        return Icons.verified_user;
      default:
        return Icons.person;
    }
  }

  Color _getRoleColor(String userType) {
    switch (userType) {
      case 'client':
        return AppTheme.primaryColor;
      case 'ca':
        return AppTheme.successColor;
      default:
        return AppTheme.textSecondary;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  Future<void> _refreshData() async {
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(seconds: 1));
    setState(() => _isLoading = false);
  }

  Future<void> _approveApplication(
      String userId, Map<String, dynamic> userData) async {
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Approve Application'),
          content: Text(
              'Approve ${userData['displayName']} as ${userData['userType'] == 'client' ? 'Certificate Reviewer' : 'Certificate Authority'}?'),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.successColor),
              child: const Text('Approve'),
            ),
          ],
        ),
      );

      if (confirmed != true) return;

      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'status': 'active',
        'approvedAt': FieldValue.serverTimestamp(),
        'approvedBy': ref.read(currentUserProvider).value?.id,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Application approved successfully'),
              backgroundColor: AppTheme.successColor),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Failed to approve: ${e.toString()}'),
              backgroundColor: AppTheme.errorColor),
        );
      }
    }
  }

  Future<void> _rejectApplication(
      String userId, Map<String, dynamic> userData) async {
    try {
      final reason = await showDialog<String>(
        context: context,
        builder: (context) => _RejectReasonDialog(),
      );

      if (reason == null || reason.trim().isEmpty) return;

      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'status': 'rejected',
        'rejectedAt': FieldValue.serverTimestamp(),
        'rejectedBy': ref.read(currentUserProvider).value?.id,
        'rejectionReason': reason,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Application rejected'),
              backgroundColor: AppTheme.errorColor),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Failed to reject: ${e.toString()}'),
              backgroundColor: AppTheme.errorColor),
        );
      }
    }
  }
}

class _RejectReasonDialog extends StatefulWidget {
  @override
  _RejectReasonDialogState createState() => _RejectReasonDialogState();
}

class _RejectReasonDialogState extends State<_RejectReasonDialog> {
  final _reasonController = TextEditingController();

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Reject Application'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Please provide a reason for rejecting this application:'),
          const SizedBox(height: 16),
          TextFormField(
            controller: _reasonController,
            maxLines: 3,
            decoration: const InputDecoration(
                hintText: 'Enter rejection reason...',
                border: OutlineInputBorder()),
          ),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () {
            final reason = _reasonController.text.trim();
            if (reason.isNotEmpty) Navigator.of(context).pop(reason);
          },
          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorColor),
          child: const Text('Reject'),
        ),
      ],
    );
  }
}
