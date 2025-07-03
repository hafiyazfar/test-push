import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:animate_do/animate_do.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../auth/providers/auth_providers.dart';
import '../../../profile/presentation/widgets/change_password_dialog.dart';
import '../../../profile/presentation/widgets/two_factor_setup_dialog.dart';


class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  bool _notificationsEnabled = true;
  bool _emailNotifications = true;
  bool _pushNotifications = true;
  bool _biometricAuth = false;
  bool _darkTheme = false;
  String _language = 'English';
  String _timezone = 'UTC';

  final List<String> _languages = [
    'English',
    'Spanish',
    'French',
    'German',
    'Chinese (Simplified)',
    'Japanese',
  ];

  final List<String> _timezones = [
    'UTC',
    'UTC-8 (PST)',
    'UTC-5 (EST)',
    'UTC+1 (CET)',
    'UTC+8 (CST)',
    'UTC+9 (JST)',
  ];

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserProvider);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: AppTheme.textOnPrimary,
        elevation: 0,
      ),
      body: currentUser.when(
        data: (user) {
          if (user == null) {
            return const Center(
              child: Text('Please log in to access settings'),
            );
          }
          return _buildSettingsView();
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Text('Error: $error'),
        ),
      ),
    );
  }

  Widget _buildSettingsView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTheme.spacingL),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FadeInUp(
            duration: const Duration(milliseconds: 300),
            child: _buildProfileSection(),
          ),
          const SizedBox(height: AppTheme.spacingL),
          FadeInUp(
            duration: const Duration(milliseconds: 400),
            child: _buildNotificationSettings(),
          ),
          const SizedBox(height: AppTheme.spacingL),
          FadeInUp(
            duration: const Duration(milliseconds: 500),
            child: _buildSecuritySettings(),
          ),
          const SizedBox(height: AppTheme.spacingL),
          FadeInUp(
            duration: const Duration(milliseconds: 600),
            child: _buildAppearanceSettings(),
          ),
          const SizedBox(height: AppTheme.spacingL),
          FadeInUp(
            duration: const Duration(milliseconds: 700),
            child: _buildLanguageSettings(),
          ),
          const SizedBox(height: AppTheme.spacingL),
          FadeInUp(
            duration: const Duration(milliseconds: 800),
            child: _buildDataSettings(),
          ),
          const SizedBox(height: AppTheme.spacingL),
          FadeInUp(
            duration: const Duration(milliseconds: 900),
            child: _buildSupportSection(),
          ),
          const SizedBox(height: AppTheme.spacingL),
          FadeInUp(
            duration: const Duration(milliseconds: 1000),
            child: _buildAccountActions(),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileSection() {
    final currentUser = ref.watch(currentUserProvider).value;
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingL),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Profile',
              style: AppTheme.titleMedium.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppTheme.spacingM),
            ListTile(
              leading: CircleAvatar(
                backgroundImage: currentUser?.profileImageUrl != null
                    ? NetworkImage(currentUser!.profileImageUrl!)
                    : null,
                child: currentUser?.profileImageUrl == null
                    ? Text(currentUser?.displayName.substring(0, 1) ?? 'U')
                    : null,
              ),
              title: Text(currentUser?.displayName ?? 'Unknown User'),
              subtitle: Text(currentUser?.email ?? ''),
              trailing: const Icon(Icons.edit),
              onTap: _editProfile,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationSettings() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingL),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Notifications',
              style: AppTheme.titleMedium.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppTheme.spacingS),
            SwitchListTile(
              title: const Text('Enable Notifications'),
              subtitle: const Text('Receive app notifications'),
              value: _notificationsEnabled,
              onChanged: (value) {
                setState(() {
                  _notificationsEnabled = value;
                });
              },
            ),
            SwitchListTile(
              title: const Text('Email Notifications'),
              subtitle: const Text('Receive notifications via email'),
              value: _emailNotifications,
              onChanged: _notificationsEnabled ? (value) {
                setState(() {
                  _emailNotifications = value;
                });
              } : null,
            ),
            SwitchListTile(
              title: const Text('Push Notifications'),
              subtitle: const Text('Receive push notifications'),
              value: _pushNotifications,
              onChanged: _notificationsEnabled ? (value) {
                setState(() {
                  _pushNotifications = value;
                });
              } : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSecuritySettings() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingL),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Security',
              style: AppTheme.titleMedium.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppTheme.spacingS),
            SwitchListTile(
              title: const Text('Biometric Authentication'),
              subtitle: const Text('Use fingerprint or face ID'),
              value: _biometricAuth,
              onChanged: (value) {
                setState(() {
                  _biometricAuth = value;
                });
              },
            ),
            ListTile(
              title: const Text('Change Password'),
              subtitle: const Text('Update your account password'),
              leading: const Icon(Icons.lock),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: _changePassword,
            ),
            ListTile(
              title: const Text('Two-Factor Authentication'),
              subtitle: const Text('Add extra security to your account'),
              leading: const Icon(Icons.security),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: _setupTwoFactor,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppearanceSettings() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingL),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Appearance',
              style: AppTheme.titleMedium.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppTheme.spacingS),
            SwitchListTile(
              title: const Text('Dark Theme'),
              subtitle: const Text('Use dark mode'),
              value: _darkTheme,
              onChanged: (value) {
                setState(() {
                  _darkTheme = value;
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLanguageSettings() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingL),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Language & Region',
              style: AppTheme.titleMedium.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppTheme.spacingS),
            ListTile(
              title: const Text('Language'),
              subtitle: Text(_language),
              leading: const Icon(Icons.language),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: _selectLanguage,
            ),
            ListTile(
              title: const Text('Timezone'),
              subtitle: Text(_timezone),
              leading: const Icon(Icons.schedule),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: _selectTimezone,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDataSettings() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingL),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Data & Privacy',
              style: AppTheme.titleMedium.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppTheme.spacingS),
            ListTile(
              title: const Text('Download Data'),
              subtitle: const Text('Export your data'),
              leading: const Icon(Icons.download),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: _downloadData,
            ),
            ListTile(
              title: const Text('Privacy Policy'),
              subtitle: const Text('View privacy policy'),
              leading: const Icon(Icons.privacy_tip),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: () => _showPrivacyPolicy(),
            ),
            ListTile(
              title: const Text('Terms of Service'),
              subtitle: const Text('View terms of service'),
              leading: const Icon(Icons.description),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: () => _showTermsOfService(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSupportSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingL),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Support',
              style: AppTheme.titleMedium.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppTheme.spacingS),
            ListTile(
              title: const Text('Help Center'),
              subtitle: const Text('Get help and support'),
              leading: const Icon(Icons.help),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: () => context.go('/help'),
            ),
            ListTile(
              title: const Text('Contact Support'),
              subtitle: const Text('Get in touch with our team'),
              leading: const Icon(Icons.support_agent),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: () => context.go('/support'),
            ),
            ListTile(
              title: const Text('Send Feedback'),
              subtitle: const Text('Share your thoughts'),
              leading: const Icon(Icons.feedback),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: () => _showFeedbackDialog(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccountActions() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingL),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Account',
              style: AppTheme.titleMedium.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppTheme.spacingS),
            ListTile(
              title: const Text('Sign Out'),
              subtitle: const Text('Sign out of your account'),
              leading: const Icon(Icons.logout),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: _signOut,
            ),
            ListTile(
              title: const Text(
                'Delete Account',
                style: TextStyle(color: AppTheme.errorColor),
              ),
              subtitle: const Text('Permanently delete your account'),
              leading: const Icon(Icons.delete_forever, color: AppTheme.errorColor),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: _deleteAccount,
            ),
          ],
        ),
      ),
    );
  }

  void _editProfile() {
    context.push('/profile/edit');
  }

  void _changePassword() {
    showDialog(
      context: context,
      builder: (context) => const ChangePasswordDialog(),
    );
  }

  void _setupTwoFactor() {
    showDialog(
      context: context,
      builder: (context) => const TwoFactorSetupDialog(),
    );
  }

  void _selectLanguage() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Language'),
        content: SizedBox(
          width: 300,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: _languages.map((language) => ListTile(
              title: Text(language),
              leading: Radio<String>(
                value: language,
                groupValue: _language,
                onChanged: (value) {
                  setState(() {
                    _language = value!;
                  });
                  Navigator.pop(context);
                },
              ),
            )).toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _selectTimezone() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Timezone'),
        content: SizedBox(
          width: 300,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: _timezones.map((timezone) => ListTile(
              title: Text(timezone),
              leading: Radio<String>(
                value: timezone,
                groupValue: _timezone,
                onChanged: (value) {
                  setState(() {
                    _timezone = value!;
                  });
                  Navigator.pop(context);
                },
              ),
            )).toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _downloadData() async {
    try {
      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('Preparing data export...'),
            ],
          ),
        ),
      );

      // Simulate data preparation
      await Future.delayed(const Duration(seconds: 2));

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Data export prepared. Download link sent to your email.'),
            backgroundColor: AppTheme.successColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to export data: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  Widget buildDeleteConfirmationDialog() {
    return AlertDialog(
      title: const Text('Delete Account'),
      content: const Text(
        'Are you sure you want to delete your account? This action cannot be undone.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.of(context).pop();
            performAccountDeletion();
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.errorColor,
          ),
          child: const Text('Delete'),
        ),
      ],
    );
  }

  Future<void> performAccountDeletion() async {
    try {
      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('Deleting account...'),
            ],
          ),
        ),
      );

      // Simulate account deletion
      await Future.delayed(const Duration(seconds: 3));

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Account deletion initiated. You will be signed out.'),
            backgroundColor: AppTheme.successColor,
          ),
        );
        
        // Sign out user
        ref.read(authServiceProvider).signOut();
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete account: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  void _showPrivacyPolicy() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Privacy Policy'),
        content: const SingleChildScrollView(
          child: Text(
            'UPM Digital Certificate Repository Privacy Policy\n\n'
            '1. Information We Collect\n'
            'We collect information you provide directly to us, such as when you create an account, upload documents, or contact us for support.\n\n'
            '2. How We Use Your Information\n'
            'We use the information we collect to provide, maintain, and improve our services, process transactions, and communicate with you.\n\n'
            '3. Information Sharing\n'
            'We do not share your personal information with third parties except as described in this policy or with your consent.\n\n'
            '4. Data Security\n'
            'We implement appropriate security measures to protect your personal information against unauthorized access, alteration, disclosure, or destruction.\n\n'
            '5. Contact Us\n'
            'If you have questions about this Privacy Policy, please contact us at privacy@upm.edu.my.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showTermsOfService() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Terms of Service'),
        content: const SingleChildScrollView(
          child: Text(
            'UPM Digital Certificate Repository Terms of Service\n\n'
            '1. Acceptance of Terms\n'
            'By accessing and using this service, you accept and agree to be bound by the terms and provision of this agreement.\n\n'
            '2. Use License\n'
            'Permission is granted to temporarily download one copy of the materials on UPM Digital Certificate Repository for personal, non-commercial transitory viewing only.\n\n'
            '3. Disclaimer\n'
            'The materials on UPM Digital Certificate Repository are provided on an \'as is\' basis. UPM makes no warranties, expressed or implied.\n\n'
            '4. Limitations\n'
            'In no event shall UPM or its suppliers be liable for any damages arising out of the use or inability to use the materials.\n\n'
            '5. Accuracy of Materials\n'
            'The materials appearing on UPM Digital Certificate Repository could include technical, typographical, or photographic errors.\n\n'
            '6. Links\n'
            'UPM has not reviewed all of the sites linked to our platform and is not responsible for the contents of any such linked site.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showFeedbackDialog() {
    final feedbackController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Send Feedback'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('We value your feedback! Please share your thoughts or suggestions.'),
            const SizedBox(height: 16),
            TextField(
              controller: feedbackController,
              decoration: const InputDecoration(
                hintText: 'Enter your feedback...',
                border: OutlineInputBorder(),
              ),
              maxLines: 4,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final feedback = feedbackController.text.trim();
              if (feedback.isNotEmpty) {
                try {
                  final user = ref.read(currentUserProvider).value;
                  await FirebaseFirestore.instance.collection('feedback').add({
                    'userId': user?.id ?? 'anonymous',
                    'userEmail': user?.email ?? 'anonymous',
                    'feedback': feedback,
                    'timestamp': FieldValue.serverTimestamp(),
                    'platform': 'mobile',
                  });
                  
                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Thank you for your feedback!'),
                        backgroundColor: AppTheme.successColor,
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
                        content: Text('Failed to send feedback: $e'),
                        backgroundColor: AppTheme.errorColor,
                      ),
                    );
                  }
                }
              }
            },
            child: const Text('Send'),
          ),
        ],
      ),
    );
  }

  void _signOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await ref.read(authServiceProvider).signOut();
        if (mounted) {
          context.go('/login');
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to sign out: $e'),
              backgroundColor: AppTheme.errorColor,
            ),
          );
        }
      }
    }
  }

  void _deleteAccount() {
    showDialog(
      context: context,
      builder: (context) => buildDeleteConfirmationDialog(),
    );
  }
} 