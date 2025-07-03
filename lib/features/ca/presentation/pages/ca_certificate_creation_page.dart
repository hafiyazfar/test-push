import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:animate_do/animate_do.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/models/certificate_model.dart';
import '../../../auth/providers/auth_providers.dart';
import '../../services/ca_service.dart';
import '../../../../core/services/logger_service.dart';

class CACertificateCreationPage extends ConsumerStatefulWidget {
  const CACertificateCreationPage({super.key});

  @override
  ConsumerState<CACertificateCreationPage> createState() =>
      _CACertificateCreationPageState();
}

class _CACertificateCreationPageState
    extends ConsumerState<CACertificateCreationPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _recipientNameController = TextEditingController();
  final _recipientEmailController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _courseNameController = TextEditingController();
  final _courseCodeController = TextEditingController();
  final _gradeController = TextEditingController();
  final _creditsController = TextEditingController();
  final _achievementController = TextEditingController();

  CertificateType _selectedType = CertificateType.completion;
  DateTime _issuedAt = DateTime.now();
  DateTime? _completedAt;
  bool _isLoading = false;

  List<CertificateTemplate> _templates = [];
  String? _selectedTemplateId;

  late CAService _caService;

  @override
  void initState() {
    super.initState();
    _caService = CAService();
    _loadTemplates();
  }

  Future<void> _loadTemplates() async {
    try {
      final templates = await _caService.getCertificateTemplates();
      if (mounted) {
        setState(() {
          _templates = templates;
          if (templates.isNotEmpty) {
            _selectedTemplateId = templates.first.id;
          }
        });
      }
    } catch (e) {
      LoggerService.error('Failed to load templates', error: e);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _recipientNameController.dispose();
    _recipientEmailController.dispose();
    _descriptionController.dispose();
    _courseNameController.dispose();
    _courseCodeController.dispose();
    _gradeController.dispose();
    _creditsController.dispose();
    _achievementController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Certificate'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: AppTheme.textOnPrimary,
        elevation: 0,
        actions: [
          if (!_isLoading)
            TextButton(
              onPressed: _createCertificate,
              child: const Text(
                'Create',
                style: TextStyle(
                  color: AppTheme.textOnPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
      body: currentUser.when(
        data: (user) {
          if (user == null || (!user.isCA && !user.isAdmin)) {
            return _buildUnauthorizedView();
          }
          return _buildCreationForm();
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Text('Error: $error'),
        ),
      ),
    );
  }

  Widget _buildUnauthorizedView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.security,
            size: 64,
            color: AppTheme.errorColor,
          ),
          const SizedBox(height: 16),
          Text(
            'Access Denied',
            style: AppTheme.titleLarge.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'You need Certificate Authority privileges to create certificates.',
            style: AppTheme.bodyMedium.copyWith(
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
    );
  }

  Widget _buildCreationForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTheme.spacingL),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FadeInUp(
              duration: const Duration(milliseconds: 300),
              child: _buildBasicInfoSection(),
            ),
            const SizedBox(height: AppTheme.spacingL),
            FadeInUp(
              duration: const Duration(milliseconds: 400),
              child: _buildRecipientSection(),
            ),
            const SizedBox(height: AppTheme.spacingL),
            FadeInUp(
              duration: const Duration(milliseconds: 500),
              child: _buildCertificateDetailsSection(),
            ),
            const SizedBox(height: AppTheme.spacingL),
            FadeInUp(
              duration: const Duration(milliseconds: 600),
              child: _buildDatesSection(),
            ),
            const SizedBox(height: AppTheme.spacingXL),
          ],
        ),
      ),
    );
  }

  Widget _buildBasicInfoSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingL),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Basic Information',
              style: AppTheme.titleMedium.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppTheme.spacingM),
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Certificate Title *',
                hintText: 'Enter certificate title',
                prefixIcon: Icon(Icons.title),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a certificate title';
                }
                return null;
              },
            ),
            const SizedBox(height: AppTheme.spacingM),
            DropdownButtonFormField<CertificateType>(
              value: _selectedType,
              decoration: const InputDecoration(
                labelText: 'Certificate Type *',
                prefixIcon: Icon(Icons.category),
              ),
              items: CertificateType.values.map((type) {
                return DropdownMenuItem(
                  value: type,
                  child: Text(type.displayName),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _selectedType = value;
                  });
                }
              },
            ),
            const SizedBox(height: AppTheme.spacingM),
            DropdownButtonFormField<String>(
              value: _selectedTemplateId,
              decoration: const InputDecoration(
                labelText: 'Certificate Template *',
                prefixIcon: Icon(Icons.design_services),
              ),
              items: _templates.map((template) {
                return DropdownMenuItem(
                  value: template.id,
                  child: Text(template.name),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedTemplateId = value;
                });
              },
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please select a template';
                }
                return null;
              },
            ),
            const SizedBox(height: AppTheme.spacingM),
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description *',
                hintText: 'Enter certificate description',
                prefixIcon: Icon(Icons.description),
              ),
              maxLines: 3,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a description';
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecipientSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingL),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Recipient Information',
              style: AppTheme.titleMedium.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppTheme.spacingM),
            TextFormField(
              controller: _recipientNameController,
              decoration: const InputDecoration(
                labelText: 'Recipient Name *',
                hintText: 'Enter recipient full name',
                prefixIcon: Icon(Icons.person),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter recipient name';
                }
                return null;
              },
            ),
            const SizedBox(height: AppTheme.spacingM),
            TextFormField(
              controller: _recipientEmailController,
              decoration: const InputDecoration(
                labelText: 'Recipient Email *',
                hintText: 'Enter recipient email address',
                prefixIcon: Icon(Icons.email),
              ),
              keyboardType: TextInputType.emailAddress,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter recipient email';
                }
                if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                    .hasMatch(value)) {
                  return 'Please enter a valid email address';
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCertificateDetailsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingL),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Certificate Details',
              style: AppTheme.titleMedium.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppTheme.spacingM),
            if (_selectedType == CertificateType.academic ||
                _selectedType == CertificateType.completion) ...[
              TextFormField(
                controller: _courseNameController,
                decoration: const InputDecoration(
                  labelText: 'Course Name',
                  hintText: 'Enter course name',
                  prefixIcon: Icon(Icons.school),
                ),
              ),
              const SizedBox(height: AppTheme.spacingM),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _courseCodeController,
                      decoration: const InputDecoration(
                        labelText: 'Course Code',
                        hintText: 'e.g., CS101',
                        prefixIcon: Icon(Icons.code),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppTheme.spacingM),
                  Expanded(
                    child: TextFormField(
                      controller: _creditsController,
                      decoration: const InputDecoration(
                        labelText: 'Credits',
                        hintText: 'e.g., 3.0',
                        prefixIcon: Icon(Icons.star),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.spacingM),
              TextFormField(
                controller: _gradeController,
                decoration: const InputDecoration(
                  labelText: 'Grade',
                  hintText: 'e.g., A, B+, 85%',
                  prefixIcon: Icon(Icons.grade),
                ),
              ),
            ],
            if (_selectedType == CertificateType.achievement ||
                _selectedType == CertificateType.recognition) ...[
              const SizedBox(height: AppTheme.spacingM),
              TextFormField(
                controller: _achievementController,
                decoration: const InputDecoration(
                  labelText: 'Achievement',
                  hintText: 'Describe the achievement',
                  prefixIcon: Icon(Icons.emoji_events),
                ),
                maxLines: 2,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDatesSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingL),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Dates',
              style: AppTheme.titleMedium.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppTheme.spacingM),
            ListTile(
              leading: const Icon(Icons.calendar_today),
              title: const Text('Issue Date'),
              subtitle: Text(_issuedAt.toString().split(' ')[0]),
              trailing: const Icon(Icons.edit),
              onTap: () => _selectDate(context, true),
            ),
            ListTile(
              leading: const Icon(Icons.calendar_month),
              title: const Text('Completion Date'),
              subtitle:
                  Text(_completedAt?.toString().split(' ')[0] ?? 'Not set'),
              trailing: const Icon(Icons.edit),
              onTap: () => _selectDate(context, false),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectDate(BuildContext context, bool isIssueDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isIssueDate ? _issuedAt : (_completedAt ?? DateTime.now()),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      setState(() {
        if (isIssueDate) {
          _issuedAt = picked;
        } else {
          _completedAt = picked;
        }
      });
    }
  }

  Future<void> _createCertificate() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final certificateId = await _caService.createCertificate(
        title: _titleController.text.trim(),
        recipientName: _recipientNameController.text.trim(),
        recipientEmail: _recipientEmailController.text.trim(),
        description: _descriptionController.text.trim(),
        type: _selectedType,
        issuedAt: _issuedAt,
        templateId: _selectedTemplateId,
        customFields: {
          'courseName': _courseNameController.text.trim(),
          'courseCode': _courseCodeController.text.trim(),
          'grade': _gradeController.text.trim(),
          'credits': _creditsController.text.trim(),
          'achievement': _achievementController.text.trim(),
          'completedAt': _completedAt?.toIso8601String(),
        },
      );

      LoggerService.info('Certificate created successfully: $certificateId');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Certificate created successfully!'),
            backgroundColor: AppTheme.successColor,
          ),
        );

        context.pop();
      }
    } catch (e) {
      LoggerService.error('Failed to create certificate', error: e);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create certificate: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}
