import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:animate_do/animate_do.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/models/user_model.dart';
import '../../../auth/providers/auth_providers.dart';

class CAPendingApprovalPage extends ConsumerStatefulWidget {
  const CAPendingApprovalPage({super.key});

  @override
  ConsumerState<CAPendingApprovalPage> createState() => _CAPendingApprovalPageState();
}

class _CAPendingApprovalPageState extends ConsumerState<CAPendingApprovalPage> {
  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserProvider);
    
    return currentUser.when(
      data: (user) {
        if (user == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            context.go('/login');
          });
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        
        return _buildPendingApprovalPage(user);
      },
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, stack) => _buildErrorPage(error.toString()),
    );
  }

  Widget _buildPendingApprovalPage(UserModel user) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: AppTheme.primaryGradient,
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.spacingL),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FadeIn(
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(60),
                    ),
                    child: const Icon(
                      Icons.hourglass_top,
                      size: 60,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: AppTheme.spacingXL),
                
                FadeInUp(
                  delay: const Duration(milliseconds: 300),
                  child: Text(
                    'Certificate Authority Application',
                    style: AppTheme.headlineMedium.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: AppTheme.spacingM),
                
                FadeInUp(
                  delay: const Duration(milliseconds: 500),
                  child: Text(
                    'Pending Approval',
                    style: AppTheme.titleLarge.copyWith(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: AppTheme.spacingL),
                
                FadeInUp(
                  delay: const Duration(milliseconds: 700),
                  child: Container(
                    padding: const EdgeInsets.all(AppTheme.spacingL),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppTheme.radiusL),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 25,
                              backgroundColor: Colors.white.withValues(alpha: 0.2),
                              backgroundImage: user.photoURL != null 
                                  ? NetworkImage(user.photoURL!) 
                                  : null,
                              child: user.photoURL == null 
                                  ? Text(
                                      user.displayName.substring(0, 1).toUpperCase(),
                                      style: AppTheme.titleMedium.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    )
                                  : null,
                            ),
                            const SizedBox(width: AppTheme.spacingM),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    user.displayName,
                                    style: AppTheme.titleMedium.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    user.email,
                                    style: AppTheme.bodyMedium.copyWith(
                                      color: Colors.white.withValues(alpha: 0.8),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppTheme.spacingL),
                        
                        _buildStatusSection(user),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: AppTheme.spacingXL),
                
                FadeInUp(
                  delay: const Duration(milliseconds: 900),
                  child: Column(
                    children: [
                      Text(
                        'What happens next?',
                        style: AppTheme.titleMedium.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: AppTheme.spacingM),
                      _buildStepsList(),
                    ],
                  ),
                ),
                
                const SizedBox(height: AppTheme.spacingXL),
                
                FadeInUp(
                  delay: const Duration(milliseconds: 1100),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _goToMainDashboard,
                          icon: const Icon(Icons.home),
                          label: const Text('Dashboard'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white.withValues(alpha: 0.8),
                            side: BorderSide(color: Colors.white.withValues(alpha: 0.6)),
                            padding: const EdgeInsets.symmetric(
                              vertical: AppTheme.spacingM,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppTheme.spacingM),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _refreshStatus,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Check Status'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: AppTheme.primaryColor,
                            padding: const EdgeInsets.symmetric(
                              vertical: AppTheme.spacingM,
                            ),
                          ),
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
    );
  }

  Widget _buildStatusSection(UserModel user) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingM),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusM),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                _getStatusIcon(user.status),
                color: _getStatusColor(user.status),
                size: 24,
              ),
              const SizedBox(width: AppTheme.spacingS),
              Text(
                'Application Status',
                style: AppTheme.titleSmall.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacingS),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.spacingM,
              vertical: AppTheme.spacingS,
            ),
            decoration: BoxDecoration(
              color: _getStatusColor(user.status).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(AppTheme.radiusS),
              border: Border.all(
                color: _getStatusColor(user.status).withValues(alpha: 0.4),
              ),
            ),
            child: Text(
              _getStatusText(user.status),
              style: AppTheme.titleSmall.copyWith(
                color: _getStatusColor(user.status),
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          if (user.status == UserStatus.pending) ...[
            const SizedBox(height: AppTheme.spacingM),
            Text(
              'Your application is being reviewed by our administrators. This process typically takes 1-3 business days.',
              style: AppTheme.bodySmall.copyWith(
                color: Colors.white.withValues(alpha: 0.8),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStepsList() {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingM),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusM),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        children: [
          _buildStepItem(
            icon: Icons.check_circle,
            title: 'Application Submitted',
            description: 'Your CA application has been received',
            isCompleted: true,
          ),
          _buildStepItem(
            icon: Icons.admin_panel_settings,
            title: 'Under Review',
            description: 'Admin team is reviewing your application',
            isCompleted: false,
            isActive: true,
          ),
          _buildStepItem(
            icon: Icons.verified_user,
            title: 'Approval & Activation',
            description: 'Account activation and access granted',
            isCompleted: false,
          ),
          _buildStepItem(
            icon: Icons.dashboard,
            title: 'CA Dashboard Access',
            description: 'Full access to Certificate Authority features',
            isCompleted: false,
          ),
        ],
      ),
    );
  }

  Widget _buildStepItem({
    required IconData icon,
    required String title,
    required String description,
    required bool isCompleted,
    bool isActive = false,
  }) {
    final color = isCompleted 
        ? AppTheme.successColor 
        : isActive 
            ? AppTheme.warningColor 
            : Colors.white.withValues(alpha: 0.5);
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppTheme.spacingS),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: color),
            ),
            child: Icon(
              isCompleted ? Icons.check : icon,
              color: color,
              size: 20,
            ),
          ),
          const SizedBox(width: AppTheme.spacingM),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTheme.titleSmall.copyWith(
                    color: Colors.white,
                    fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                Text(
                  description,
                  style: AppTheme.bodySmall.copyWith(
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _goToMainDashboard() {
    context.go('/dashboard');
  }

  void _refreshStatus() async {
    try {
      // Refresh the provider and wait for completion
      final _ = await ref.refresh(currentUserProvider.future);
      
      if (mounted) {
        final user = ref.read(currentUserProvider).value;
        if (user?.status == UserStatus.active) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Great! Your CA account has been approved!'),
              backgroundColor: AppTheme.successColor,
            ),
          );
          
          // Navigate to CA dashboard
          context.go('/ca/dashboard');
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Status checked - still pending approval'),
            ),
          );
        }
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to check status: $error'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  IconData _getStatusIcon(UserStatus status) {
    switch (status) {
      case UserStatus.pending:
        return Icons.hourglass_top;
      case UserStatus.active:
        return Icons.check_circle;
      case UserStatus.suspended:
        return Icons.block;
      default:
        return Icons.help;
    }
  }

  Color _getStatusColor(UserStatus status) {
    switch (status) {
      case UserStatus.pending:
        return AppTheme.warningColor;
      case UserStatus.active:
        return AppTheme.successColor;
      case UserStatus.suspended:
        return AppTheme.errorColor;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(UserStatus status) {
    switch (status) {
      case UserStatus.pending:
        return 'PENDING REVIEW';
      case UserStatus.active:
        return 'APPROVED';
      case UserStatus.suspended:
        return 'SUSPENDED';
      default:
        return 'UNKNOWN';
    }
  }

  Widget _buildErrorPage(String error) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingL),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: AppTheme.errorColor),
              const SizedBox(height: AppTheme.spacingL),
              Text(
                'Something went wrong',
                style: AppTheme.titleLarge.copyWith(color: AppTheme.errorColor),
              ),
              const SizedBox(height: AppTheme.spacingM),
              Text(error, textAlign: TextAlign.center),
              const SizedBox(height: AppTheme.spacingL),
              ElevatedButton(
                onPressed: () => context.go('/dashboard'),
                child: const Text('Return to Dashboard'),
              ),
            ],
          ),
        ),
      ),
    );
  }
} 
