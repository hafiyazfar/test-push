import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/custom_app_bar.dart';
import '../../../../core/providers/unified_data_providers.dart';

class SystemSyncMonitorPage extends ConsumerStatefulWidget {
  const SystemSyncMonitorPage({super.key});

  @override
  ConsumerState<SystemSyncMonitorPage> createState() =>
      _SystemSyncMonitorPageState();
}

class _SystemSyncMonitorPageState extends ConsumerState<SystemSyncMonitorPage>
    with TickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(
        title: 'System Sync Monitor',
        centerTitle: true,
      ),
      body: Column(
        children: [
          _buildSyncStatusOverview(),
          TabBar(
            controller: _tabController,
            tabs: const [
              Tab(icon: Icon(Icons.sync), text: 'Sync Status'),
              Tab(icon: Icon(Icons.swap_horiz), text: 'Interactions'),
              Tab(icon: Icon(Icons.data_usage), text: 'Data Flow'),
              Tab(icon: Icon(Icons.timeline), text: 'Real-time'),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildSyncStatusTab(),
                _buildInteractionsTab(),
                _buildDataFlowTab(),
                _buildRealTimeTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSyncStatusOverview() {
    final syncStatus = ref.watch(dataSyncStatusProvider);

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                syncStatus['allSynced'] == true
                    ? Icons.check_circle
                    : Icons.warning,
                color: syncStatus['allSynced'] == true
                    ? AppTheme.successColor
                    : AppTheme.warningColor,
                size: 32,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      syncStatus['allSynced'] == true
                          ? 'All Systems Synchronized'
                          : 'Some Systems Need Attention',
                      style: AppTheme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: syncStatus['allSynced'] == true
                            ? AppTheme.successColor
                            : AppTheme.warningColor,
                      ),
                    ),
                    Text(
                      'Last checked: ${DateFormat('HH:mm:ss').format(DateTime.now())}',
                      style: AppTheme.textTheme.bodySmall?.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () {
                  ref.invalidate(dataSyncStatusProvider);
                },
                icon: const Icon(Icons.refresh),
                tooltip: 'Refresh Status',
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildStatusChip('Templates', syncStatus['templates'] == true),
              _buildStatusChip(
                  'Certificates', syncStatus['certificates'] == true),
              _buildStatusChip('Documents', syncStatus['documents'] == true),
              _buildStatusChip('Reviews', syncStatus['reviews'] == true),
              _buildStatusChip(
                  'Notifications', syncStatus['notifications'] == true),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String label, bool isHealthy) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isHealthy ? AppTheme.successColor : AppTheme.errorColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isHealthy ? Icons.check : Icons.error,
            size: 16,
            color: Colors.white,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: AppTheme.textTheme.bodySmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSyncStatusTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildRoleStatusCard('Certificate Authorities (CA)', 'ca'),
        const SizedBox(height: 16),
        _buildRoleStatusCard('Clients', 'client'),
        const SizedBox(height: 16),
        _buildRoleStatusCard('Recipients', 'user'),
        const SizedBox(height: 16),
        _buildRoleStatusCard('Administrators', 'admin'),
      ],
    );
  }

  Widget _buildRoleStatusCard(String roleName, String roleType) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _getRoleIcon(roleType),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    roleName,
                    style: AppTheme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Chip(
                  label: const Text('Active'),
                  backgroundColor: AppTheme.successColor,
                  labelStyle: const TextStyle(color: Colors.white),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildRoleDataStatus(roleType),
          ],
        ),
      ),
    );
  }

  Widget _buildRoleDataStatus(String roleType) {
    final userStats = ref.watch(unifiedUserStatsProvider);

    return userStats.when(
      data: (stats) {
        final total = stats['total'] ?? 0;
        final active = stats['active'] ?? 0;
        final pending = stats['pending'] ?? 0;

        return Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem('Total Users', '$total', Icons.people),
                _buildStatItem('Active', '$active', Icons.check_circle),
                _buildStatItem('Pending', '$pending', Icons.pending),
              ],
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: total > 0 ? active / total : 0,
              backgroundColor: AppTheme.dividerColor,
              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.successColor),
            ),
            const SizedBox(height: 4),
            Text(
              '${total > 0 ? ((active / total) * 100).toInt() : 0}% Active Users',
              style: AppTheme.textTheme.bodySmall?.copyWith(
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const Text('Error loading stats'),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: AppTheme.primaryColor),
        const SizedBox(height: 4),
        Text(
          value,
          style: AppTheme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: AppTheme.textTheme.bodySmall?.copyWith(
            color: AppTheme.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildInteractionsTab() {
    final interactions = ref.watch(systemInteractionProvider);

    return interactions.when(
      data: (data) {
        final interactionsList = data['interactions'] as List? ?? [];
        final stats = data['stats'] as Map<String, int>? ?? {};

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Interaction Statistics',
                      style: AppTheme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: stats.entries.map((entry) {
                        return Chip(
                          label: Text('${entry.key}: ${entry.value}'),
                          backgroundColor:
                              AppTheme.primaryColor.withValues(alpha: 0.1),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            ...interactionsList
                .map((interaction) => _buildInteractionCard(interaction)),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const Text('Error loading interactions'),
    );
  }

  Widget _buildInteractionCard(Map<String, dynamic> interaction) {
    final type = interaction['type'] as String? ?? 'unknown';
    final fromRole = interaction['fromRole'] as String? ?? 'unknown';
    final toRole = interaction['toRole'] as String? ?? 'unknown';
    final timestamp =
        (interaction['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: _getInteractionIcon(type),
        title: Text(_getInteractionTitle(type)),
        subtitle: Text('$fromRole → $toRole'),
        trailing: Text(
          DateFormat('HH:mm:ss').format(timestamp),
          style: AppTheme.textTheme.bodySmall,
        ),
      ),
    );
  }

  Widget _buildDataFlowTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildDataFlowDiagram(),
          const SizedBox(height: 24),
          _buildDataVolumeStats(),
        ],
      ),
    );
  }

  Widget _buildDataFlowDiagram() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Data Flow Diagram',
              style: AppTheme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              height: 300,
              decoration: BoxDecoration(
                border: Border.all(color: AppTheme.dividerColor),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildRoleNode('CA', Icons.business),
                        const Icon(Icons.arrow_forward),
                        _buildRoleNode('Client', Icons.people),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const Icon(Icons.arrow_downward),
                    const SizedBox(height: 20),
                    _buildRoleNode('Recipients', Icons.person),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoleNode(String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.primaryColor),
      ),
      child: Column(
        children: [
          Icon(icon, color: AppTheme.primaryColor, size: 32),
          const SizedBox(height: 4),
          Text(
            label,
            style: AppTheme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDataVolumeStats() {
    final templates = ref.watch(unifiedPendingTemplatesProvider);
    final certificates = ref.watch(unifiedCertificatesProvider);
    final documents = ref.watch(unifiedDocumentsProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Data Volume Statistics',
              style: AppTheme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildVolumeCard(
                  'Templates',
                  templates.value?.length ?? 0,
                  Icons.design_services,
                ),
                _buildVolumeCard(
                  'Certificates',
                  certificates.value?.length ?? 0,
                  Icons.verified,
                ),
                _buildVolumeCard(
                  'Documents',
                  documents.value?.length ?? 0,
                  Icons.description,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVolumeCard(String label, int count, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.dividerColor),
      ),
      child: Column(
        children: [
          Icon(icon, color: AppTheme.primaryColor, size: 32),
          const SizedBox(height: 8),
          Text(
            '$count',
            style: AppTheme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: AppTheme.primaryColor,
            ),
          ),
          Text(
            label,
            style: AppTheme.textTheme.bodySmall?.copyWith(
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRealTimeTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('system_interactions')
          .orderBy('timestamp', descending: true)
          .limit(50)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Text('No real-time interactions'),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final doc = snapshot.data!.docs[index];
            final interaction = doc.data() as Map<String, dynamic>;

            return _buildRealTimeInteractionCard(interaction);
          },
        );
      },
    );
  }

  Widget _buildRealTimeInteractionCard(Map<String, dynamic> interaction) {
    final timestamp =
        (interaction['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();
    final type = interaction['type'] as String? ?? 'unknown';
    final fromRole = interaction['fromRole'] as String? ?? 'unknown';
    final toRole = interaction['toRole'] as String? ?? 'unknown';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getInteractionColor(type),
          child: Icon(
            _getInteractionIconData(type),
            color: Colors.white,
            size: 20,
          ),
        ),
        title: Text(_getInteractionTitle(type)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$fromRole → $toRole'),
            Text(
              'Just now • ${DateFormat('HH:mm:ss').format(timestamp)}',
              style: AppTheme.textTheme.bodySmall?.copyWith(
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
        trailing: Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: AppTheme.successColor,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }

  // Helper methods
  Widget _getRoleIcon(String roleType) {
    switch (roleType) {
      case 'ca':
        return const Icon(Icons.business, color: AppTheme.primaryColor);
      case 'client':
        return const Icon(Icons.people, color: AppTheme.accentColor);
      case 'user':
        return const Icon(Icons.person, color: AppTheme.successColor);
      case 'admin':
        return const Icon(Icons.admin_panel_settings,
            color: AppTheme.warningColor);
      default:
        return const Icon(Icons.help, color: Colors.grey);
    }
  }

  Widget _getInteractionIcon(String type) {
    return Icon(
      _getInteractionIconData(type),
      color: _getInteractionColor(type),
    );
  }

  IconData _getInteractionIconData(String type) {
    switch (type) {
      case 'template_created':
        return Icons.add_box;
      case 'template_reviewed':
        return Icons.rate_review;
      case 'certificate_issued':
        return Icons.verified;
      case 'document_uploaded':
        return Icons.upload_file;
      case 'user_status_changed':
        return Icons.person_pin;
      default:
        return Icons.sync;
    }
  }

  Color _getInteractionColor(String type) {
    switch (type) {
      case 'template_created':
        return AppTheme.primaryColor;
      case 'template_reviewed':
        return AppTheme.accentColor;
      case 'certificate_issued':
        return AppTheme.successColor;
      case 'document_uploaded':
        return AppTheme.infoColor;
      case 'user_status_changed':
        return AppTheme.warningColor;
      default:
        return Colors.grey;
    }
  }

  String _getInteractionTitle(String type) {
    switch (type) {
      case 'template_created':
        return 'Template Created';
      case 'template_reviewed':
        return 'Template Reviewed';
      case 'certificate_issued':
        return 'Certificate Issued';
      case 'document_uploaded':
        return 'Document Uploaded';
      case 'user_status_changed':
        return 'User Status Changed';
      default:
        return 'System Interaction';
    }
  }
}
