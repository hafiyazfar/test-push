import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:animate_do/animate_do.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/models/certificate_request_model.dart';
import '../../../../core/services/certificate_request_service.dart';
import '../../../../core/services/logger_service.dart';
import '../../../auth/providers/auth_providers.dart';
import '../../../auth/presentation/widgets/custom_text_field.dart';

final certificateRequestServiceProvider = Provider((ref) => CertificateRequestService());

final clientRequestsProvider = StreamProvider.family<List<CertificateRequestModel>, String>((ref, clientId) {
  final service = ref.read(certificateRequestServiceProvider);
  return service.getRequestsForClient(clientId);
});

class CertificateRequestPage extends ConsumerStatefulWidget {
  final String? requestId; // For viewing/editing existing request

  const CertificateRequestPage({super.key, this.requestId});

  @override
  ConsumerState<CertificateRequestPage> createState() => _CertificateRequestPageState();
}

class _CertificateRequestPageState extends ConsumerState<CertificateRequestPage> {
  final _formKey = GlobalKey<FormState>();
  final _pageController = PageController();
  int _currentStep = 0;
  bool _isLoading = false;

  // Form controllers
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _purposeController = TextEditingController();
  final _organizationController = TextEditingController();
  
  // Request data
  String _selectedCertificateType = 'Academic Certificate';
  final Map<String, TextEditingController> _customFieldControllers = {};
  final List<String> _tags = [];
  int _priority = 3;

  // Certificate types
  final List<String> _certificateTypes = [
    'Academic Certificate',
    'Professional Certificate',
    'Achievement Certificate',
    'Completion Certificate',
    'Participation Certificate',
    'Recognition Certificate',
    'Custom Certificate',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.requestId != null) {
      _loadRequest();
    } else {
      // Set default organization
      _organizationController.text = 'Universiti Putra Malaysia';
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    _purposeController.dispose();
    _organizationController.dispose();
    for (final controller in _customFieldControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadRequest() async {
    try {
      final service = ref.read(certificateRequestServiceProvider);
      final request = await service.getRequestById(widget.requestId!);
      
      if (request != null) {
        setState(() {
          _titleController.text = request.title;
          _descriptionController.text = request.description;
          _purposeController.text = request.purpose;
          _organizationController.text = request.organizationName;
          _selectedCertificateType = request.certificateType;
          _tags.addAll(request.tags);
          _priority = request.priority;
          
          // Load custom fields
          request.requestedData.forEach((key, value) {
            _customFieldControllers[key] = TextEditingController(text: value.toString());
          });
        });
      }
    } catch (e) {
      LoggerService.error('Failed to load request', error: e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load request: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserProvider).value;

    if (currentUser == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        title: Text(widget.requestId != null ? 'Certificate Request' : 'Request Certificate'),
        elevation: 0,
        backgroundColor: AppTheme.primaryColor,
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // Progress indicator
              _buildProgressIndicator(),
              // Form content
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  onPageChanged: (index) {
                    setState(() {
                      _currentStep = index;
                    });
                  },
                  children: [
                    _buildBasicInfoStep(),
                    _buildCertificateDetailsStep(),
                    _buildAdditionalInfoStep(),
                    _buildReviewStep(),
                  ],
                ),
              ),
              // Navigation buttons
              _buildNavigationButtons(),
            ],
          ),
          // Loading overlay
          if (_isLoading)
            Container(
              color: Colors.black54,
              child: const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Container(
      color: AppTheme.primaryColor,
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(4, (index) {
          final isActive = index <= _currentStep;
          final isCompleted = index < _currentStep;
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 8),
            child: Column(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: isActive ? Colors.white : Colors.white30,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: isCompleted
                        ? const Icon(
                            Icons.check,
                            color: AppTheme.primaryColor,
                            size: 20,
                          )
                        : Text(
                            '${index + 1}',
                            style: TextStyle(
                              color: isActive 
                                  ? AppTheme.primaryColor 
                                  : Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _getStepTitle(index),
                  style: AppTheme.bodySmall.copyWith(
                    color: isActive ? Colors.white : Colors.white60,
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  String _getStepTitle(int index) {
    switch (index) {
      case 0:
        return 'Basic Info';
      case 1:
        return 'Details';
      case 2:
        return 'Additional';
      case 3:
        return 'Review';
      default:
        return '';
    }
  }

  Widget _buildBasicInfoStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: FadeInUp(
        duration: const Duration(milliseconds: 600),
        child: Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Request Information',
                    style: AppTheme.headlineSmall,
                  ),
                  const SizedBox(height: 24),
                  
                  // Certificate Title
                  CustomTextField(
                    controller: _titleController,
                    label: 'Certificate Title',
                    hintText: 'Enter the title for your certificate',
                    prefixIcon: Icons.card_membership,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter certificate title';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),
                  
                  // Certificate Type
                  Text(
                    'Certificate Type',
                    style: AppTheme.bodyLarge.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: AppTheme.dividerColor),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: DropdownButtonFormField<String>(
                      value: _selectedCertificateType,
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                      items: _certificateTypes.map((type) {
                        return DropdownMenuItem(
                          value: type,
                          child: Text(type),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedCertificateType = value!;
                          _updateCustomFields();
                        });
                      },
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  // Organization
                  CustomTextField(
                    controller: _organizationController,
                    label: 'Organization',
                    hintText: 'Organization issuing the certificate',
                    prefixIcon: Icons.business,
                    enabled: false, // Fixed for UPM
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCertificateDetailsStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: FadeInUp(
        duration: const Duration(milliseconds: 600),
        child: Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Certificate Details',
                  style: AppTheme.headlineSmall,
                ),
                const SizedBox(height: 24),
                
                // Description
                CustomTextField(
                  controller: _descriptionController,
                  label: 'Description',
                  hintText: 'Describe what this certificate is for',
                  maxLines: 4,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter certificate description';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                
                // Purpose
                CustomTextField(
                  controller: _purposeController,
                  label: 'Purpose',
                  hintText: 'Why do you need this certificate?',
                  maxLines: 3,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter the purpose';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                
                // Priority
                Text(
                  'Priority Level',
                  style: AppTheme.bodyLarge.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    for (int i = 1; i <= 5; i++) ...[
                      InkWell(
                        onTap: () {
                          setState(() {
                            _priority = i;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            color: i <= _priority
                                ? _getPriorityColor(_priority)
                                : AppTheme.backgroundLight,
                            border: Border.all(
                              color: i <= _priority
                                  ? _getPriorityColor(_priority)
                                  : AppTheme.dividerColor,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            i.toString(),
                            style: TextStyle(
                              color: i <= _priority ? Colors.white : AppTheme.textSecondary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(width: 16),
                    Text(
                      _getPriorityLabel(_priority),
                      style: AppTheme.bodyMedium.copyWith(
                        color: _getPriorityColor(_priority),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAdditionalInfoStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: FadeInUp(
        duration: const Duration(milliseconds: 600),
        child: Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Additional Information',
                  style: AppTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  'Provide any additional details required for this certificate type',
                  style: AppTheme.bodyMedium.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 24),
                
                // Dynamic fields based on certificate type
                ..._buildCustomFields(),
                
                const SizedBox(height: 20),
                
                // Tags
                Text(
                  'Tags (Optional)',
                  style: AppTheme.bodyLarge.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ..._tags.map((tag) => Chip(
                      label: Text(tag),
                      onDeleted: () {
                        setState(() {
                          _tags.remove(tag);
                        });
                      },
                    )),
                    ActionChip(
                      label: const Text('Add Tag'),
                      onPressed: _showAddTagDialog,
                      avatar: const Icon(Icons.add, size: 18),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildReviewStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: FadeInUp(
        duration: const Duration(milliseconds: 600),
        child: Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Review Your Request',
                  style: AppTheme.headlineSmall,
                ),
                const SizedBox(height: 24),
                
                _buildReviewItem('Certificate Title', _titleController.text),
                _buildReviewItem('Type', _selectedCertificateType),
                _buildReviewItem('Organization', _organizationController.text),
                _buildReviewItem('Priority', _getPriorityLabel(_priority)),
                
                const Divider(height: 32),
                
                _buildReviewItem('Description', _descriptionController.text),
                _buildReviewItem('Purpose', _purposeController.text),
                
                if (_customFieldControllers.isNotEmpty) ...[
                  const Divider(height: 32),
                  Text(
                    'Additional Information',
                    style: AppTheme.titleMedium,
                  ),
                  const SizedBox(height: 16),
                  ..._customFieldControllers.entries.map((entry) {
                    return _buildReviewItem(
                      _formatFieldName(entry.key),
                      entry.value.text,
                    );
                  }),
                ],
                
                if (_tags.isNotEmpty) ...[
                  const Divider(height: 32),
                  Text(
                    'Tags',
                    style: AppTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _tags.map((tag) => Chip(
                      label: Text(tag),
                      backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
                    )).toList(),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavigationButtons() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (_currentStep > 0)
            OutlinedButton(
              onPressed: () {
                _pageController.previousPage(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                );
              },
              child: const Text('Previous'),
            )
          else
            const SizedBox(),
          
          if (_currentStep < 3)
            ElevatedButton(
              onPressed: () {
                if (_validateCurrentStep()) {
                  _pageController.nextPage(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  );
                }
              },
              child: const Text('Next'),
            )
          else
            ElevatedButton(
              onPressed: _submitRequest,
              child: Text(widget.requestId != null ? 'Update Request' : 'Submit Request'),
            ),
        ],
      ),
    );
  }

  List<Widget> _buildCustomFields() {
    final fields = <Widget>[];
    
    switch (_selectedCertificateType) {
      case 'Academic Certificate':
        fields.addAll([
          _buildCustomField('Student ID', 'studentId', Icons.badge),
          const SizedBox(height: 16),
          _buildCustomField('Program/Course', 'program', Icons.school),
          const SizedBox(height: 16),
          _buildCustomField('Year/Semester', 'yearSemester', Icons.calendar_today),
          const SizedBox(height: 16),
          _buildCustomField('CGPA/Result', 'result', Icons.grade),
        ]);
        break;
      case 'Professional Certificate':
        fields.addAll([
          _buildCustomField('Professional ID', 'professionalId', Icons.badge),
          const SizedBox(height: 16),
          _buildCustomField('Qualification', 'qualification', Icons.workspace_premium),
          const SizedBox(height: 16),
          _buildCustomField('Issuing Body', 'issuingBody', Icons.business),
        ]);
        break;
      case 'Completion Certificate':
        fields.addAll([
          _buildCustomField('Course/Training Name', 'courseName', Icons.book),
          const SizedBox(height: 16),
          _buildCustomField('Duration', 'duration', Icons.timer),
          const SizedBox(height: 16),
          _buildCustomField('Completion Date', 'completionDate', Icons.event_available),
          const SizedBox(height: 16),
          _buildCustomField('Score/Grade (if applicable)', 'score', Icons.assessment),
        ]);
        break;
      default:
        fields.addAll([
          _buildCustomField('Additional Details 1', 'detail1', Icons.info),
          const SizedBox(height: 16),
          _buildCustomField('Additional Details 2', 'detail2', Icons.info),
        ]);
    }
    
    return fields;
  }

  Widget _buildCustomField(String label, String key, IconData icon) {
    if (!_customFieldControllers.containsKey(key)) {
      _customFieldControllers[key] = TextEditingController();
    }
    
    return CustomTextField(
      controller: _customFieldControllers[key]!,
      label: label,
      hintText: 'Enter $label',
      prefixIcon: icon,
    );
  }

  Widget _buildReviewItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: AppTheme.bodyMedium.copyWith(
                color: AppTheme.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '-' : value,
              style: AppTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }

  void _updateCustomFields() {
    setState(() {
      // Clear existing custom fields
      for (final controller in _customFieldControllers.values) {
        controller.dispose();
      }
      _customFieldControllers.clear();
    });
  }

  bool _validateCurrentStep() {
    switch (_currentStep) {
      case 0:
        if (_titleController.text.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please enter certificate title')),
          );
          return false;
        }
        return true;
      case 1:
        if (_descriptionController.text.isEmpty || _purposeController.text.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please fill in all required fields')),
          );
          return false;
        }
        return true;
      case 2:
        // Additional fields are optional
        return true;
      default:
        return true;
    }
  }

  Future<void> _submitRequest() async {
    if (!_validateCurrentStep()) return;
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      final service = ref.read(certificateRequestServiceProvider);
      
      // Collect custom field data
      final requestedData = <String, dynamic>{};
      _customFieldControllers.forEach((key, controller) {
        if (controller.text.isNotEmpty) {
          requestedData[key] = controller.text;
        }
      });
      
      if (widget.requestId != null) {
        // Update existing request
        await service.updateRequest(
          requestId: widget.requestId!,
          title: _titleController.text,
          description: _descriptionController.text,
          purpose: _purposeController.text,
          requestedData: requestedData,
          tags: _tags,
          priority: _priority,
        );
      } else {
        // Create new request
        final request = await service.createRequest(
          title: _titleController.text,
          description: _descriptionController.text,
          purpose: _purposeController.text,
          certificateType: _selectedCertificateType,
          requestedData: requestedData,
          organizationId: 'upm', // Fixed for UPM
          organizationName: _organizationController.text,
          tags: _tags,
          priority: _priority,
        );
        
        // Auto-submit the request
        await service.submitRequest(request.id);
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.requestId != null 
                ? 'Request updated successfully' 
                : 'Request submitted successfully'),
            backgroundColor: AppTheme.successColor,
          ),
        );
        context.pop();
      }
    } catch (e) {
      LoggerService.error('Failed to submit request', error: e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to submit request: $e'),
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

  void _showAddTagDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Tag'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'Enter tag',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                setState(() {
                  _tags.add(controller.text);
                });
                Navigator.pop(context);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Color _getPriorityColor(int priority) {
    switch (priority) {
      case 1:
        return Colors.grey;
      case 2:
        return Colors.blue;
      case 3:
        return Colors.orange;
      case 4:
        return Colors.deepOrange;
      case 5:
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getPriorityLabel(int priority) {
    switch (priority) {
      case 1:
        return 'Low';
      case 2:
        return 'Medium';
      case 3:
        return 'Normal';
      case 4:
        return 'High';
      case 5:
        return 'Urgent';
      default:
        return 'Normal';
    }
  }

  String _formatFieldName(String key) {
    // Convert camelCase to Title Case
    return key.replaceAllMapped(
      RegExp(r'([A-Z])'),
      (match) => ' ${match.group(0)}',
    ).trim().split(' ').map((word) {
      return word.substring(0, 1).toUpperCase() + word.substring(1);
    }).join(' ');
  }
} 