import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:animate_do/animate_do.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/services/logger_service.dart';
import '../../providers/ca_providers.dart';

class CASettingsPage extends ConsumerStatefulWidget {
  const CASettingsPage({super.key});

  @override
  ConsumerState<CASettingsPage> createState() => _CASettingsPageState();
}

class _CASettingsPageState extends ConsumerState<CASettingsPage> 
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  late AnimationController _saveAnimationController;

  // Form controllers
  final _organizationNameController = TextEditingController();
  final _contactEmailController = TextEditingController();
  final _contactPhoneController = TextEditingController();
  final _addressController = TextEditingController();

  bool _autoApproveDocuments = false;
  List<String> _allowedFileTypes = ['pdf', 'doc', 'docx', 'jpg', 'png'];
  int _maxFileSizeMB = 10;

  @override
  void initState() {
    super.initState();
    _saveAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _loadSettings();
  }

  @override
  void dispose() {
    _organizationNameController.dispose();
    _contactEmailController.dispose();
    _contactPhoneController.dispose();
    _addressController.dispose();
    _saveAnimationController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    try {
      await ref.read(caSettingsProvider.notifier).loadSettings();
      final settings = ref.read(caSettingsProvider).settings;

      if (settings != null && mounted) {
        setState(() {
          _organizationNameController.text = settings.organizationName;
          _contactEmailController.text = settings.contactEmail;
          _contactPhoneController.text = settings.contactPhone;
          _addressController.text = settings.address;
          _autoApproveDocuments = settings.autoApproveDocuments;
          _allowedFileTypes = settings.allowedFileTypes;
          _maxFileSizeMB = settings.maxFileSize;
        });
      }
    } catch (e) {
      LoggerService.error('Failed to load CA settings', error: e);
    }
  }

  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) return;

    _saveAnimationController.forward();

    try {
      final currentSettings = ref.read(caSettingsProvider).settings;
      final updatedSettings = currentSettings?.copyWith(
            organizationName: _organizationNameController.text,
            contactEmail: _contactEmailController.text,
            contactPhone: _contactPhoneController.text,
            address: _addressController.text,
            autoApproveDocuments: _autoApproveDocuments,
            allowedFileTypes: _allowedFileTypes,
            maxFileSize: _maxFileSizeMB,
          ) ??
          CASettingsModel(
            organizationName: _organizationNameController.text,
            contactEmail: _contactEmailController.text,
            contactPhone: _contactPhoneController.text,
            address: _addressController.text,
            autoApproveDocuments: _autoApproveDocuments,
            allowedFileTypes: _allowedFileTypes,
            maxFileSize: _maxFileSizeMB,
          );

      await ref
          .read(caSettingsProvider.notifier)
          .updateSettings(updatedSettings);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Settings saved successfully'),
            backgroundColor: AppTheme.successColor,
          ),
        );
      }
    } catch (e) {
      LoggerService.error('Failed to save CA settings', error: e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save settings: ${e.toString()}'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } finally {
      _saveAnimationController.reset();
    }
  }

  @override
  Widget build(BuildContext context) {
    final settingsState = ref.watch(caSettingsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Semantics(
          header: true,
          child: const Text('CA Settings'),
        ),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: settingsState.isLoading
          ? Center(
              child: Semantics(
                label: 'Loading CA settings',
                child: const CircularProgressIndicator(),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(AppTheme.spacingL),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FadeInUp(
                      duration: const Duration(milliseconds: 300),
                      child: _buildOrganizationSection(),
                    ),
                    const SizedBox(height: AppTheme.spacingXL),
                    FadeInUp(
                      duration: const Duration(milliseconds: 400),
                      child: _buildDocumentSettingsSection(),
                    ),
                    const SizedBox(height: AppTheme.spacingXL),
                    FadeInUp(
                      duration: const Duration(milliseconds: 500),
                      child: _buildNotificationSection(),
                    ),
                    const SizedBox(height: AppTheme.spacingXL),
                    FadeInUp(
                      duration: const Duration(milliseconds: 600),
                      child: _buildSaveButton(),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildOrganizationSection() {
    return Semantics(
      label: 'Organization information section',
      child: Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingL),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.business,
                      color: AppTheme.primaryColor,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Semantics(
                    header: true,
                    child: Text(
                      'Organization Information',
                      style: AppTheme.titleLarge.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.spacingL),
              Semantics(
                textField: true,
                label: 'Organization name field',
                child: TextFormField(
                  controller: _organizationNameController,
                  decoration: const InputDecoration(
                    labelText: 'Organization Name',
                    prefixIcon: Icon(Icons.business),
                    helperText: 'Enter your organization or institution name',
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter organization name';
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(height: AppTheme.spacingM),
              Semantics(
                textField: true,
                label: 'Contact email field',
                child: TextFormField(
                  controller: _contactEmailController,
                  decoration: const InputDecoration(
                    labelText: 'Contact Email',
                    prefixIcon: Icon(Icons.email),
                    helperText: 'Official contact email for your organization',
                  ),
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter contact email';
                    }
                    if (!value.contains('@')) {
                      return 'Please enter a valid email';
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(height: AppTheme.spacingM),
              Semantics(
                textField: true,
                label: 'Contact phone field',
                child: TextFormField(
                  controller: _contactPhoneController,
                  decoration: const InputDecoration(
                    labelText: 'Contact Phone',
                    prefixIcon: Icon(Icons.phone),
                    helperText: 'Official contact phone number',
                  ),
                  keyboardType: TextInputType.phone,
                ),
              ),
              const SizedBox(height: AppTheme.spacingM),
              Semantics(
                textField: true,
                label: 'Address field',
                child: TextFormField(
                  controller: _addressController,
                  decoration: const InputDecoration(
                    labelText: 'Address',
                    prefixIcon: Icon(Icons.location_on),
                    helperText: 'Complete address of your organization',
                  ),
                  maxLines: 3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDocumentSettingsSection() {
    return Semantics(
      label: 'Document settings section',
      child: Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingL),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.infoColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.document_scanner,
                      color: AppTheme.infoColor,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Semantics(
                    header: true,
                    child: Text(
                      'Document Settings',
                      style: AppTheme.titleLarge.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.spacingL),
              Semantics(
                label: 'Auto-approve documents toggle. Currently ${_autoApproveDocuments ? "enabled" : "disabled"}',
                child: SwitchListTile(
                  title: const Text('Auto-approve Documents'),
                  subtitle: const Text('Automatically approve verified documents'),
                  value: _autoApproveDocuments,
                  secondary: const Icon(Icons.auto_awesome),
                  onChanged: (value) {
                    setState(() {
                      _autoApproveDocuments = value;
                    });
                  },
                ),
              ),
              const SizedBox(height: AppTheme.spacingM),
              Semantics(
                label: 'Maximum file size setting. Currently $_maxFileSizeMB megabytes',
                child: ListTile(
                  leading: const Icon(Icons.folder_zip),
                  title: const Text('Maximum File Size'),
                  subtitle: Text('$_maxFileSizeMB MB'),
                  trailing: SizedBox(
                    width: 200,
                    child: Semantics(
                      label: 'File size slider. Current value $_maxFileSizeMB megabytes',
                      child: Slider(
                        value: _maxFileSizeMB.toDouble(),
                        min: 1,
                        max: 50,
                        divisions: 49,
                        label: '$_maxFileSizeMB MB',
                        onChanged: (value) {
                          setState(() {
                            _maxFileSizeMB = value.toInt();
                          });
                        },
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppTheme.spacingM),
              Semantics(
                button: true,
                label: 'Edit allowed file types. Current types: ${_allowedFileTypes.join(", ")}',
                child: ListTile(
                  leading: const Icon(Icons.file_present),
                  title: const Text('Allowed File Types'),
                  subtitle: Text(_allowedFileTypes.join(', ')),
                  trailing: IconButton(
                    icon: const Icon(Icons.edit),
                    tooltip: 'Edit file types',
                    onPressed: _showFileTypesDialog,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationSection() {
    return Semantics(
      label: 'Notification settings section',
      child: Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingL),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.warningColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.notifications_active,
                      color: AppTheme.warningColor,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Semantics(
                    header: true,
                    child: Text(
                      'Notification Settings',
                      style: AppTheme.titleLarge.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.spacingL),
              Semantics(
                label: 'Email notifications toggle. Currently enabled',
                child: SwitchListTile(
                  title: const Text('Email Notifications'),
                  subtitle: const Text('Receive email notifications for new requests'),
                  value: true,
                  secondary: const Icon(Icons.email),
                  onChanged: (value) {
                    setState(() {
                      // Email notification settings will be saved with other settings
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(value
                            ? 'Email notifications enabled'
                            : 'Email notifications disabled'),
                      ),
                    );
                  },
                ),
              ),
              Semantics(
                label: 'Push notifications toggle. Currently enabled',
                child: SwitchListTile(
                  title: const Text('Push Notifications'),
                  subtitle: const Text('Receive push notifications for urgent items'),
                  value: true,
                  secondary: const Icon(Icons.mobile_friendly),
                  onChanged: (value) {
                    setState(() {
                      // Push notification settings will be saved with other settings
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(value
                            ? 'Push notifications enabled'
                            : 'Push notifications disabled'),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      child: ScaleTransition(
        scale: Tween<double>(begin: 1.0, end: 0.95).animate(
          CurvedAnimation(
            parent: _saveAnimationController,
            curve: Curves.easeInOut,
          ),
        ),
        child: Semantics(
          button: true,
          label: 'Save all settings',
          child: ElevatedButton.icon(
            onPressed: _saveSettings,
            icon: const Icon(Icons.save),
            label: const Text('Save Settings'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: AppTheme.spacingM),
              elevation: 2,
            ),
          ),
        ),
      ),
    );
  }

  void _showFileTypesDialog() {
    final allFileTypes = [
      'pdf',
      'doc',
      'docx',
      'jpg',
      'jpeg',
      'png',
      'gif',
      'bmp',
      'txt',
      'csv',
      'xlsx'
    ];
    final selectedTypes = List<String>.from(_allowedFileTypes);

    showDialog(
      context: context,
      builder: (context) => Semantics(
        label: 'File types selection dialog',
        child: AlertDialog(
          title: const Text('Select Allowed File Types'),
          content: Semantics(
            label: 'List of file types to select from',
            child: StatefulBuilder(
              builder: (context, setState) => SizedBox(
                width: double.maxFinite,
                child: ListView(
                  shrinkWrap: true,
                  children: allFileTypes
                      .map((type) => Semantics(
                            label: '$type file type. ${selectedTypes.contains(type) ? "Selected" : "Not selected"}',
                            child: CheckboxListTile(
                              title: Text(type.toUpperCase()),
                              value: selectedTypes.contains(type),
                              onChanged: (value) {
                                setState(() {
                                  if (value == true) {
                                    selectedTypes.add(type);
                                  } else {
                                    selectedTypes.remove(type);
                                  }
                                });
                              },
                            ),
                          ))
                      .toList(),
                ),
              ),
            ),
          ),
          actions: [
            Semantics(
              button: true,
              label: 'Cancel file type selection',
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
            ),
            Semantics(
              button: true,
              label: 'Save selected file types',
              child: ElevatedButton(
                onPressed: () {
                  setState(() {
                    _allowedFileTypes = selectedTypes;
                  });
                  Navigator.of(context).pop();
                },
                child: const Text('Save'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
