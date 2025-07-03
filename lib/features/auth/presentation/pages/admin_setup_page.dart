import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/services/initialization_service.dart';
import '../../../../core/services/logger_service.dart';

class AdminSetupPage extends ConsumerStatefulWidget {
  const AdminSetupPage({super.key});

  @override
  ConsumerState<AdminSetupPage> createState() => _AdminSetupPageState();
}

class _AdminSetupPageState extends ConsumerState<AdminSetupPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _displayNameController = TextEditingController();

  bool _isLoading = false;
  bool _isObscured = true;
  String? _statusMessage;
  Color? _statusColor;

  @override
  void initState() {
    super.initState();
    // No longer pre-fill hardcoded credentials, let users enter themselves
    _emailController.text = 'admin@upm.edu.my'; // Only keep email as hint
    // _passwordController.text = ''; // Remove hardcoded password

    _checkSystemStatus();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _displayNameController.dispose();
    super.dispose();
  }

  Future<void> _checkSystemStatus() async {
    try {
      final status = await InitializationService.checkAdminStatus();

      if (mounted) {
        setState(() {
          if (status['activeAdmins'] > 0) {
            _statusMessage =
                'System already has ${status['activeAdmins']} active admin(s)';
            _statusColor = AppTheme.successColor;
          } else {
            _statusMessage =
                'No active admin found. System initialization required.';
            _statusColor = AppTheme.warningColor;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _statusMessage = 'Error checking system status: $e';
          _statusColor = AppTheme.errorColor;
        });
      }
    }
  }

  Future<void> _createInitialAdmin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _statusMessage = null;
    });

    try {
      LoggerService.info('Starting initial admin creation process...');

      await InitializationService.createInitialAdmin(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        displayName: _displayNameController.text.trim(),
      );

      if (mounted) {
        setState(() {
          _statusMessage = 'Initial Admin account created successfully!';
          _statusColor = AppTheme.successColor;
        });

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🎉 Initial Admin account created successfully!'),
            backgroundColor: AppTheme.successColor,
            duration: Duration(seconds: 5),
          ),
        );

        // Navigate to login page after 3 seconds
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) {
            context.go('/login');
          }
        });
      }

      LoggerService.info('Initial admin creation completed successfully');
    } catch (e, stackTrace) {
      LoggerService.error('Failed to create initial admin',
          error: e, stackTrace: stackTrace);

      if (mounted) {
        setState(() {
          _statusMessage = 'Failed to create admin: ${e.toString()}';
          _statusColor = AppTheme.errorColor;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error: ${e.toString()}'),
            backgroundColor: AppTheme.errorColor,
            duration: const Duration(seconds: 5),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: AppTheme.primaryGradient,
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Card(
                elevation: 8,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Header
                        const Icon(
                          Icons.admin_panel_settings,
                          size: 80,
                          color: AppTheme.primaryColor,
                        ),
                        const SizedBox(height: 16),

                        Text(
                          'System Initialization',
                          style: AppTheme.headlineMedium.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryColor,
                          ),
                          textAlign: TextAlign.center,
                        ),

                        const SizedBox(height: 8),

                        Text(
                          'Create Initial Administrator Account',
                          style: AppTheme.bodyLarge.copyWith(
                            color: AppTheme.textSecondary,
                          ),
                          textAlign: TextAlign.center,
                        ),

                        const SizedBox(height: 32),

                        // Status message
                        if (_statusMessage != null) ...[
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: _statusColor!.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: _statusColor!.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  _statusColor == AppTheme.successColor
                                      ? Icons.check_circle
                                      : _statusColor == AppTheme.warningColor
                                          ? Icons.warning
                                          : Icons.error,
                                  color: _statusColor,
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    _statusMessage!,
                                    style: TextStyle(
                                      color: _statusColor,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],

                        // Form fields
                        TextFormField(
                          controller: _emailController,
                          decoration: const InputDecoration(
                            labelText: 'Admin Email',
                            prefixIcon: Icon(Icons.email),
                            helperText: 'Must be a valid UPM email address',
                          ),
                          keyboardType: TextInputType.emailAddress,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please enter admin email';
                            }
                            if (!AppConfig.isValidUpmEmail(value)) {
                              return 'Please enter a valid UPM email address';
                            }
                            return null;
                          },
                        ),

                        const SizedBox(height: 16),

                        TextFormField(
                          controller: _passwordController,
                          decoration: InputDecoration(
                            labelText: 'Admin Password',
                            prefixIcon: const Icon(Icons.lock),
                            suffixIcon: IconButton(
                              icon: Icon(_isObscured
                                  ? Icons.visibility
                                  : Icons.visibility_off),
                              onPressed: () {
                                setState(() {
                                  _isObscured = !_isObscured;
                                });
                              },
                            ),
                            helperText:
                                'Minimum 8 characters, include uppercase, lowercase, numbers',
                          ),
                          obscureText: _isObscured,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter admin password';
                            }
                            if (value.length < 8) {
                              return 'Password must be at least 8 characters';
                            }
                            if (!value.contains(RegExp(r'[A-Z]'))) {
                              return 'Password must contain uppercase letter';
                            }
                            if (!value.contains(RegExp(r'[a-z]'))) {
                              return 'Password must contain lowercase letter';
                            }
                            if (!value.contains(RegExp(r'[0-9]'))) {
                              return 'Password must contain number';
                            }
                            return null;
                          },
                        ),

                        const SizedBox(height: 16),

                        TextFormField(
                          controller: _displayNameController,
                          decoration: const InputDecoration(
                            labelText: 'Display Name',
                            prefixIcon: Icon(Icons.person),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please enter display name';
                            }
                            if (value.trim().length < 3) {
                              return 'Display name must be at least 3 characters';
                            }
                            return null;
                          },
                        ),

                        const SizedBox(height: 32),

                        // Create button
                        SizedBox(
                          height: 50,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _createInitialAdmin,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryColor,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: _isLoading
                                ? const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                  Colors.white),
                                        ),
                                      ),
                                      SizedBox(width: 12),
                                      Text('Creating Admin Account...'),
                                    ],
                                  )
                                : const Text(
                                    'Create Initial Admin',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Go to login button
                        TextButton(
                          onPressed: () => context.go('/login'),
                          child: const Text('Already have admin? Go to Login'),
                        ),

                        const SizedBox(height: 24),

                        // Warning message
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppTheme.warningColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color:
                                  AppTheme.warningColor.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.warning,
                                    color: AppTheme.warningColor,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Important Notice',
                                    style: AppTheme.titleSmall.copyWith(
                                      color: AppTheme.warningColor,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '• This should only be done during initial system setup\n'
                                '• The admin account will have full system privileges\n'
                                '• Change the default password after first login\n'
                                '• Keep admin credentials secure and confidential',
                                style: AppTheme.bodySmall.copyWith(
                                  color: AppTheme.warningColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
