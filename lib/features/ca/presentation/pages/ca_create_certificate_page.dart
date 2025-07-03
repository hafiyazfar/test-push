import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:animate_do/animate_do.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/models/certificate_model.dart';
import '../../../../core/models/user_model.dart';
import '../../../auth/providers/auth_providers.dart';
import '../../providers/ca_providers.dart';

class CACreateCertificatePage extends ConsumerStatefulWidget {
  const CACreateCertificatePage({super.key});

  @override
  ConsumerState<CACreateCertificatePage> createState() =>
      _CACreateCertificatePageState();
}

class _CACreateCertificatePageState
    extends ConsumerState<CACreateCertificatePage> {
  final _formKey = GlobalKey<FormState>();
  final _pageController = PageController();

  // Form controllers
  final _titleController = TextEditingController();
  final _recipientNameController = TextEditingController();
  final _recipientEmailController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _organizationController = TextEditingController();
  final _achievementController = TextEditingController();

  // Form state
  int _currentStep = 0;
  CertificateType _selectedType = CertificateType.academic;
  DateTime _issuedDate = DateTime.now();
  String? _selectedTemplateId;
  final Map<String, dynamic> _customFields = {};
  bool _isLoading = false;

  final List<CertificateType> _certificateTypes = [
    CertificateType.academic,
    CertificateType.professional,
    CertificateType.completion,
    CertificateType.achievement,
    CertificateType.participation,
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _recipientNameController.dispose();
    _recipientEmailController.dispose();
    _descriptionController.dispose();
    _organizationController.dispose();
    _achievementController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserProvider);

    return currentUser.when(
      data: (user) {
        if (user == null || (!user.isCA && !user.isAdmin)) {
          return _buildUnauthorizedPage();
        }
        return _buildCreateCertificatePage(user);
      },
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, stack) => _buildErrorPage(error.toString()),
    );
  }

  Widget _buildCreateCertificatePage(UserModel user) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Certificate'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: AppTheme.textOnPrimary,
        elevation: 0,
        actions: [
          if (_currentStep == 2)
            TextButton(
              onPressed: _isLoading ? null : _createCertificate,
              child: Text(
                'Issue Certificate',
                style: TextStyle(
                  color: _isLoading ? Colors.grey : AppTheme.textOnPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // Progress indicator
          _buildProgressIndicator(),

          // Form content
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildBasicInfoStep(),
                _buildRecipientInfoStep(),
                _buildPreviewStep(),
              ],
            ),
          ),

          // Navigation buttons
          _buildNavigationButtons(),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingL),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            offset: const Offset(0, 2),
            blurRadius: 4,
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildStepIndicator(0, 'Basic Info', Icons.info_outline),
          ),
          Expanded(
            child: _buildStepIndicator(1, 'Recipient', Icons.person_outline),
          ),
          Expanded(
            child: _buildStepIndicator(2, 'Preview', Icons.preview_outlined),
          ),
        ],
      ),
    );
  }

  Widget _buildStepIndicator(int step, String title, IconData icon) {
    final isActive = _currentStep == step;
    final isCompleted = _currentStep > step;

    return Column(
      children: [
        CircleAvatar(
          radius: 20,
          backgroundColor: isActive || isCompleted
              ? Colors.white
              : Colors.white.withValues(alpha: 0.5),
          child: Icon(
            isCompleted ? Icons.check : icon,
            color:
                isActive || isCompleted ? AppTheme.primaryColor : Colors.white,
            size: 20,
          ),
        ),
        const SizedBox(height: AppTheme.spacingXS),
        Text(
          title,
          style: AppTheme.bodySmall.copyWith(
            color: isActive || isCompleted
                ? Colors.white
                : Colors.white.withValues(alpha: 0.7),
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  Widget _buildBasicInfoStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTheme.spacingL),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FadeInUp(
              duration: const Duration(milliseconds: 300),
              child: Text(
                'Certificate Information',
                style: AppTheme.titleLarge.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: AppTheme.spacingL),
            FadeInUp(
              duration: const Duration(milliseconds: 400),
              child: TextFormField(
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
                  if (value.trim().length < 5) {
                    return 'Title must be at least 5 characters long';
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(height: AppTheme.spacingM),
            FadeInUp(
              duration: const Duration(milliseconds: 500),
              child: DropdownButtonFormField<CertificateType>(
                value: _selectedType,
                decoration: const InputDecoration(
                  labelText: 'Certificate Type *',
                  prefixIcon: Icon(Icons.category),
                ),
                items: _certificateTypes.map((type) {
                  return DropdownMenuItem(
                    value: type,
                    child: Text(_getCertificateTypeDisplayName(type)),
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
            ),
            const SizedBox(height: AppTheme.spacingM),
            FadeInUp(
              duration: const Duration(milliseconds: 600),
              child: TextFormField(
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
                  if (value.trim().length < 10) {
                    return 'Description must be at least 10 characters long';
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(height: AppTheme.spacingM),
            FadeInUp(
              duration: const Duration(milliseconds: 700),
              child: TextFormField(
                controller: _organizationController,
                decoration: const InputDecoration(
                  labelText: 'Issuing Organization',
                  hintText: 'Enter organization name',
                  prefixIcon: Icon(Icons.business),
                ),
                validator: (value) {
                  if (value != null &&
                      value.trim().isNotEmpty &&
                      value.trim().length < 3) {
                    return 'Organization name must be at least 3 characters long';
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(height: AppTheme.spacingM),
            FadeInUp(
              duration: const Duration(milliseconds: 800),
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.calendar_today),
                title: const Text('Issue Date'),
                subtitle: Text(
                  '${_issuedDate.day}/${_issuedDate.month}/${_issuedDate.year}',
                  style: AppTheme.bodyMedium.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: _selectDate,
              ),
            ),
            if (_selectedType == CertificateType.achievement) ...[
              const SizedBox(height: AppTheme.spacingM),
              FadeInUp(
                duration: const Duration(milliseconds: 900),
                child: TextFormField(
                  controller: _achievementController,
                  decoration: const InputDecoration(
                    labelText: 'Achievement Details',
                    hintText: 'Enter achievement details',
                    prefixIcon: Icon(Icons.star),
                  ),
                  maxLines: 2,
                ),
              ),
            ],
            const SizedBox(height: AppTheme.spacingL),
            FadeInUp(
              duration: const Duration(milliseconds: 1000),
              child: Container(
                padding: const EdgeInsets.all(AppTheme.spacingM),
                decoration: BoxDecoration(
                  color: AppTheme.infoColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppTheme.radiusM),
                  border: Border.all(
                    color: AppTheme.infoColor.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.info_outline,
                      color: AppTheme.infoColor,
                      size: 20,
                    ),
                    const SizedBox(width: AppTheme.spacingS),
                    Expanded(
                      child: Text(
                        'All certificate information will be securely stored and can be verified using the generated verification code.',
                        style: AppTheme.bodySmall.copyWith(
                          color: AppTheme.infoColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecipientInfoStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTheme.spacingL),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FadeInUp(
            duration: const Duration(milliseconds: 300),
            child: Text(
              'Recipient Information',
              style: AppTheme.titleLarge.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: AppTheme.spacingL),
          FadeInUp(
            duration: const Duration(milliseconds: 400),
            child: TextFormField(
              controller: _recipientNameController,
              decoration: const InputDecoration(
                labelText: 'Recipient Full Name *',
                hintText: 'Enter recipient\'s full name',
                prefixIcon: Icon(Icons.person),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter recipient\'s name';
                }
                if (value.trim().length < 3) {
                  return 'Name must be at least 3 characters long';
                }
                return null;
              },
            ),
          ),
          const SizedBox(height: AppTheme.spacingM),
          FadeInUp(
            duration: const Duration(milliseconds: 500),
            child: TextFormField(
              controller: _recipientEmailController,
              decoration: const InputDecoration(
                labelText: 'Recipient Email *',
                hintText: 'Enter recipient\'s email address',
                prefixIcon: Icon(Icons.email),
              ),
              keyboardType: TextInputType.emailAddress,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter recipient\'s email';
                }
                if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                    .hasMatch(value)) {
                  return 'Please enter a valid email address';
                }
                return null;
              },
            ),
          ),
          const SizedBox(height: AppTheme.spacingL),
          FadeInUp(
            duration: const Duration(milliseconds: 600),
            child: Container(
              padding: const EdgeInsets.all(AppTheme.spacingM),
              decoration: BoxDecoration(
                color: AppTheme.successColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppTheme.radiusM),
                border: Border.all(
                  color: AppTheme.successColor.withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.check_circle_outline,
                        color: AppTheme.successColor,
                        size: 20,
                      ),
                      const SizedBox(width: AppTheme.spacingS),
                      Text(
                        'What happens next?',
                        style: AppTheme.titleSmall.copyWith(
                          color: AppTheme.successColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppTheme.spacingS),
                  Text(
                    '• The recipient will receive an email notification\n'
                    '• A unique verification code will be generated\n'
                    '• The certificate will be available for download\n'
                    '• Verification can be done using the QR code',
                    style: AppTheme.bodySmall.copyWith(
                      color: AppTheme.successColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTheme.spacingL),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FadeInUp(
            duration: const Duration(milliseconds: 300),
            child: Text(
              'Certificate Preview',
              style: AppTheme.titleLarge.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: AppTheme.spacingL),

          FadeInUp(
            duration: const Duration(milliseconds: 400),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppTheme.spacingL),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppTheme.primaryColor.withValues(alpha: 0.1),
                    Colors.white,
                  ],
                ),
                borderRadius: BorderRadius.circular(AppTheme.radiusL),
                border: Border.all(
                  color: AppTheme.primaryColor.withValues(alpha: 0.3),
                  width: 2,
                ),
              ),
              child: Column(
                children: [
                  // Header
                  Text(
                    'CERTIFICATE OF ${_getCertificateTypeDisplayName(_selectedType).toUpperCase()}',
                    style: AppTheme.titleMedium.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryColor,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: AppTheme.spacingL),

                  // Title
                  Text(
                    _titleController.text.isNotEmpty
                        ? _titleController.text
                        : 'Certificate Title',
                    style: AppTheme.headlineSmall.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: AppTheme.spacingL),

                  // Awarded to
                  Text(
                    'This is to certify that',
                    style: AppTheme.bodyLarge,
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: AppTheme.spacingS),

                  // Recipient name
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.spacingL,
                      vertical: AppTheme.spacingS,
                    ),
                    decoration: const BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: AppTheme.primaryColor,
                          width: 2,
                        ),
                      ),
                    ),
                    child: Text(
                      _recipientNameController.text.isNotEmpty
                          ? _recipientNameController.text
                          : 'Recipient Name',
                      style: AppTheme.headlineSmall.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryColor,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),

                  const SizedBox(height: AppTheme.spacingL),

                  // Description
                  Text(
                    _descriptionController.text.isNotEmpty
                        ? _descriptionController.text
                        : 'Certificate description will appear here',
                    style: AppTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: AppTheme.spacingL),

                  // Date and signature area
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Date of Issue:',
                            style: AppTheme.bodySmall.copyWith(
                              color: AppTheme.textSecondary,
                            ),
                          ),
                          Text(
                            '${_issuedDate.day}/${_issuedDate.month}/${_issuedDate.year}',
                            style: AppTheme.bodyMedium.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'Issued by:',
                            style: AppTheme.bodySmall.copyWith(
                              color: AppTheme.textSecondary,
                            ),
                          ),
                          Text(
                            _organizationController.text.isNotEmpty
                                ? _organizationController.text
                                : 'Universiti Putra Malaysia',
                            style: AppTheme.bodyMedium.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: AppTheme.spacingL),

          // Summary card
          FadeInUp(
            duration: const Duration(milliseconds: 500),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(AppTheme.spacingL),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Certificate Summary',
                      style: AppTheme.titleMedium.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacingM),
                    _buildSummaryRow(
                        'Type', _getCertificateTypeDisplayName(_selectedType)),
                    _buildSummaryRow(
                        'Title',
                        _titleController.text.isNotEmpty
                            ? _titleController.text
                            : 'Not specified'),
                    _buildSummaryRow(
                        'Recipient',
                        _recipientNameController.text.isNotEmpty
                            ? _recipientNameController.text
                            : 'Not specified'),
                    _buildSummaryRow(
                        'Email',
                        _recipientEmailController.text.isNotEmpty
                            ? _recipientEmailController.text
                            : 'Not specified'),
                    _buildSummaryRow('Issue Date',
                        '${_issuedDate.day}/${_issuedDate.month}/${_issuedDate.year}'),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: AppTheme.bodySmall.copyWith(
                color: AppTheme.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: AppTheme.bodySmall.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationButtons() {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingL),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            offset: const Offset(0, -2),
            blurRadius: 4,
          ),
        ],
      ),
      child: Row(
        children: [
          if (_currentStep > 0)
            Expanded(
              child: OutlinedButton(
                onPressed: _previousStep,
                child: const Text('Previous'),
              ),
            ),
          if (_currentStep > 0) const SizedBox(width: AppTheme.spacingM),
          Expanded(
            child: ElevatedButton(
              onPressed: _isLoading ? null : _nextStep,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: AppTheme.textOnPrimary,
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(_currentStep == 2 ? 'Create Certificate' : 'Next'),
            ),
          ),
        ],
      ),
    );
  }

  // Helper methods
  String _getCertificateTypeDisplayName(CertificateType type) {
    switch (type) {
      case CertificateType.academic:
        return 'Academic Certificate';
      case CertificateType.professional:
        return 'Professional Certificate';
      case CertificateType.completion:
        return 'Completion Certificate';
      case CertificateType.achievement:
        return 'Achievement Certificate';
      case CertificateType.participation:
        return 'Participation Certificate';
      default:
        return 'Certificate';
    }
  }

  void _nextStep() {
    if (_currentStep == 0) {
      if (_formKey.currentState?.validate() ?? false) {
        _goToStep(1);
      }
    } else if (_currentStep == 1) {
      if (_validateRecipientInfo()) {
        _goToStep(2);
      }
    } else if (_currentStep == 2) {
      _createCertificate();
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      _goToStep(_currentStep - 1);
    }
  }

  void _goToStep(int step) {
    setState(() {
      _currentStep = step;
    });
    _pageController.animateToPage(
      step,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  bool _validateRecipientInfo() {
    if (_recipientNameController.text.trim().isEmpty) {
      _showErrorSnackBar('Please enter recipient\'s name');
      return false;
    }
    if (_recipientEmailController.text.trim().isEmpty) {
      _showErrorSnackBar('Please enter recipient\'s email');
      return false;
    }
    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
        .hasMatch(_recipientEmailController.text)) {
      _showErrorSnackBar('Please enter a valid email address');
      return false;
    }
    return true;
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _issuedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null && picked != _issuedDate) {
      setState(() {
        _issuedDate = picked;
      });
    }
  }

  Future<void> _createCertificate() async {
    if (!_formKey.currentState!.validate() || !_validateRecipientInfo()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Add custom fields
      if (_achievementController.text.isNotEmpty) {
        _customFields['achievement'] = _achievementController.text;
      }
      if (_organizationController.text.isNotEmpty) {
        _customFields['organization'] = _organizationController.text;
      }

      await ref.read(certificateCreationProvider.notifier).createCertificate(
            title: _titleController.text.trim(),
            recipientName: _recipientNameController.text.trim(),
            recipientEmail: _recipientEmailController.text.trim(),
            description: _descriptionController.text.trim(),
            type: _selectedType,
            issuedAt: _issuedDate,
            templateId: _selectedTemplateId,
            customFields: _customFields,
          );

      // Listen for success
      ref.listen<CertificateCreationState>(certificateCreationProvider,
          (previous, next) {
        if (next.isSuccess && mounted) {
          setState(() {
            _isLoading = false;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Certificate created successfully!'),
              backgroundColor: AppTheme.successColor,
            ),
          );
          context.pop();
        } else if (next.error != null && mounted) {
          _showErrorSnackBar(next.error!);
          ref.read(certificateCreationProvider.notifier).clearState();
        }
      });
    } catch (error) {
      _showErrorSnackBar(error.toString());
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.errorColor,
      ),
    );
  }

  Widget _buildUnauthorizedPage() {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingL),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.block, size: 64, color: AppTheme.errorColor),
              const SizedBox(height: AppTheme.spacingL),
              Text(
                'Access Denied',
                style: AppTheme.titleLarge.copyWith(color: AppTheme.errorColor),
              ),
              const SizedBox(height: AppTheme.spacingM),
              const Text('You do not have permission to create certificates.'),
              const SizedBox(height: AppTheme.spacingL),
              ElevatedButton(
                onPressed: () => context.pop(),
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorPage(String error) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingL),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline,
                  size: 64, color: AppTheme.errorColor),
              const SizedBox(height: AppTheme.spacingL),
              Text(
                'Something went wrong',
                style: AppTheme.titleLarge.copyWith(color: AppTheme.errorColor),
              ),
              const SizedBox(height: AppTheme.spacingM),
              Text(error, textAlign: TextAlign.center),
              const SizedBox(height: AppTheme.spacingL),
              ElevatedButton(
                onPressed: () => context.pop(),
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
