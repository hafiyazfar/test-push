import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/custom_app_bar.dart';
import '../../../../core/services/logger_service.dart';
import '../../../auth/providers/auth_providers.dart';

class CATemplateCreationPage extends ConsumerStatefulWidget {
  const CATemplateCreationPage({super.key});

  @override
  ConsumerState<CATemplateCreationPage> createState() =>
      _CATemplateCreationPageState();
}

class _CATemplateCreationPageState
    extends ConsumerState<CATemplateCreationPage> {
  final _formKey = GlobalKey<FormState>();
  final _templateNameController = TextEditingController();
  final _descriptionController = TextEditingController();
  String _selectedDocumentId = '';
  Map<String, dynamic>? _selectedDocumentData;
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserProvider).value;

    if (currentUser == null || (!currentUser.isCA && !currentUser.isAdmin)) {
      return Scaffold(
        appBar: const CustomAppBar(title: 'Template Creation'),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock, size: 80, color: AppTheme.errorColor),
              const SizedBox(height: 16),
              Text('Access Denied',
                  style: AppTheme.textTheme.headlineMedium
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(
                  'You do not have permission to create templates. CA or Admin access required.',
                  style: AppTheme.textTheme.bodyLarge
                      ?.copyWith(color: AppTheme.textSecondary),
                  textAlign: TextAlign.center),
              const SizedBox(height: 24),
              ElevatedButton(
                  onPressed: () => context.pop(), child: const Text('Go Back')),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: const CustomAppBar(title: 'Certificate Template Creation'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDocumentSelectionSection(),
            const SizedBox(height: 24),
            if (_selectedDocumentData != null) ...[
              _buildTemplateFormSection(),
              const SizedBox(height: 24),
              _buildPreviewSection(),
              const SizedBox(height: 24),
              _buildSubmitButton(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDocumentSelectionSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Select Approved Document',
                style: AppTheme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('documents')
                  .where('status', isEqualTo: 'verified') // 🔄 直接查找已批准的文档
                  .orderBy('uploadedAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final documents = snapshot.data?.docs ?? [];

                // 🔍 DEBUG: Log query results
                LoggerService.info(
                    '📄 Template Creation - Found ${documents.length} approved documents');
                for (final doc in documents.take(3)) {
                  final data = doc.data() as Map<String, dynamic>;
                  LoggerService.info(
                      '📄 Document: ${data['name']} - status: ${data['status']} - uploader: ${data['uploaderName']}');
                }

                if (documents.isEmpty) {
                  return const Center(
                      child: Text(
                          'No approved documents available for template creation.\n\nDocuments need to be approved by CA first.'));
                }

                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: documents.length,
                  itemBuilder: (context, index) {
                    final document = documents[index];
                    final documentData =
                        document.data() as Map<String, dynamic>;

                    // 🔍 提取文档信息
                    final metadata =
                        documentData['metadata'] as Map<String, dynamic>? ?? {};
                    final customFields =
                        metadata['customFields'] as Map<String, dynamic>? ?? {};
                    final documentType = documentData['type'] ?? 'academic';
                    final uploaderName =
                        documentData['uploaderName'] ?? 'Unknown';

                    return ListTile(
                      title: Text(
                          '${documentType.toString().toUpperCase()} - $uploaderName'),
                      subtitle: Text(
                          'Document: ${documentData['name']}\nApproved by CA'),
                      trailing: Radio<String>(
                        value: document.id,
                        groupValue: _selectedDocumentId,
                        onChanged: (value) {
                          setState(() {
                            _selectedDocumentId = value!;
                            // 🔄 构建模板数据结构
                            _selectedDocumentData = {
                              'documentType': documentType,
                              'studentName':
                                  customFields['studentName'] ?? uploaderName,
                              'course': customFields['course'] ??
                                  customFields['courseName'] ??
                                  'General Studies',
                              'institution': customFields['institution'] ??
                                  'Universiti Putra Malaysia',
                              'grade': customFields['grade'],
                              'graduationDate': customFields['graduationDate'],
                              'uploaderId': documentData['uploaderId'],
                              'documentId': document.id,
                              'documentName': documentData['name'],
                            };
                            _templateNameController.text =
                                '${documentType.toString().toUpperCase()} Certificate Template - ${customFields['course'] ?? 'General'}';
                          });
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTemplateFormSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Template Information',
                  style: AppTheme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              TextFormField(
                controller: _templateNameController,
                decoration: const InputDecoration(
                    labelText: 'Template Name', border: OutlineInputBorder()),
                validator: (value) =>
                    value?.isEmpty == true ? 'Template name is required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                    labelText: 'Description', border: OutlineInputBorder()),
                maxLines: 3,
                validator: (value) =>
                    value?.isEmpty == true ? 'Description is required' : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPreviewSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Template Preview',
                style: AppTheme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              height: 300,
              decoration: BoxDecoration(
                border: Border.all(color: AppTheme.dividerColor),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                      'CERTIFICATE OF ${_selectedDocumentData!['documentType']?.toString().toUpperCase()}',
                      style: AppTheme.textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),
                  Text('This is to certify that',
                      style: AppTheme.textTheme.bodyLarge),
                  const SizedBox(height: 10),
                  Text('${_selectedDocumentData!['studentName']}',
                      style: AppTheme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          decoration: TextDecoration.underline)),
                  const SizedBox(height: 20),
                  Text('has successfully completed the course',
                      style: AppTheme.textTheme.bodyLarge),
                  const SizedBox(height: 10),
                  Text(
                      '${_selectedDocumentData!['course'] ?? 'General Studies'}',
                      style: AppTheme.textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  Text('at ${_selectedDocumentData!['institution']}',
                      style: AppTheme.textTheme.bodyLarge),
                  if (_selectedDocumentData!['grade'] != null) ...[
                    const SizedBox(height: 10),
                    Text('with a grade of ${_selectedDocumentData!['grade']}',
                        style: AppTheme.textTheme.bodyLarge),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _isLoading ? null : _submitTemplate,
        icon: _isLoading
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.send),
        label: Text(
            _isLoading ? 'Creating Template...' : 'Submit for Client Review'),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primaryColor,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    );
  }

  Future<void> _submitTemplate() async {
    if (!_formKey.currentState!.validate() || _selectedDocumentData == null) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      final currentUser = ref.read(currentUserProvider).value;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      // Create certificate template record
      final templateRef = await FirebaseFirestore.instance
          .collection('certificate_templates')
          .add({
        'name': _templateNameController.text,
        'description': _descriptionController.text,
        'type': _selectedDocumentData!['documentType'],
        'studentName': _selectedDocumentData!['studentName'],
        'course': _selectedDocumentData!['course'],
        'institution': _selectedDocumentData!['institution'],
        'grade': _selectedDocumentData!['grade'],
        'graduationDate': _selectedDocumentData!['graduationDate'],
        'basedOnDocumentId': _selectedDocumentData!['documentId'], // 🔄 链接到原始文档
        'createdBy': currentUser.id,
        'createdByName': currentUser.displayName,
        'status': 'pending_client_review',
        'reviewStatus': 'pending_review',
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 🔄 记录CA活动 - 这是缺失的关键部分！
      await _logCAActivity(
        currentUser.id,
        'template_created',
        'Created template: ${_templateNameController.text}',
        {
          'templateId': templateRef.id,
          'templateName': _templateNameController.text,
          'documentType': _selectedDocumentData!['documentType'],
          'studentName': _selectedDocumentData!['studentName'],
          'course': _selectedDocumentData!['course'],
        },
      );

      // 🔄 标记文档已用于模板创建（可选）
      await FirebaseFirestore.instance
          .collection('documents')
          .doc(_selectedDocumentId)
          .update({
        'templateCreated': true,
        'templateCreatedAt': FieldValue.serverTimestamp(),
      });

      LoggerService.info('Template created successfully: ${templateRef.id}');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Template created and submitted for Client review'),
              backgroundColor: AppTheme.successColor),
        );
        context.go('/ca/dashboard');
      }
    } catch (e) {
      LoggerService.error('Failed to create template', error: e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Failed to create template: ${e.toString()}'),
              backgroundColor: AppTheme.errorColor),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  /// Log CA activity to ca_activities collection
  Future<void> _logCAActivity(
    String caId,
    String action,
    String description,
    Map<String, dynamic> metadata,
  ) async {
    try {
      await FirebaseFirestore.instance.collection('ca_activities').add({
        'caId': caId,
        'action': action,
        'description': description,
        'timestamp': FieldValue.serverTimestamp(),
        'metadata': metadata,
      });
    } catch (e) {
      LoggerService.error('Failed to log CA activity', error: e);
      // Don't throw error here to avoid breaking the main flow
    }
  }

  @override
  void dispose() {
    _templateNameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }
}
