import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:animate_do/animate_do.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/services/validation_service.dart';
import '../../../../core/models/user_model.dart';
import '../../providers/auth_providers.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/social_login_button.dart';
import '../../../../core/services/logger_service.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isPasswordVisible = false;
  bool _rememberMe = false;

  @override
  void initState() {
    super.initState();
    _loadRememberMeData();
  }

  Future<void> _loadRememberMeData() async {
    final authService = ref.read(authServiceProvider);
    final rememberMe = await authService.getRememberMeStatus();
    final rememberedEmail = await authService.getRememberedEmail();

    if (mounted) {
      setState(() {
        _rememberMe = rememberMe;
        if (rememberedEmail != null) {
          _emailController.text = rememberedEmail;
        }
      });
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleGoogleSignIn() async {
    await ref.read(authNotifierProvider.notifier).signInWithGoogle();
  }

  void _handleEmailSignIn() async {
    if (_formKey.currentState?.validate() ?? false) {
      final authService = ref.read(authServiceProvider);
      await authService.setRememberMe(
          _rememberMe, _emailController.text.trim());

      await ref.read(authNotifierProvider.notifier).signInWithEmail(
            email: _emailController.text.trim(),
            password: _passwordController.text,
          );
    }
  }

  void _handleForgotPassword() {
    // Navigate to forgot password page or show dialog
    showDialog(
      context: context,
      builder: (context) => _ForgotPasswordDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);

    // Listen for auth state changes
    ref.listen<AuthState>(authNotifierProvider, (previous, next) {
      LoggerService.info(
          '🔑 Login Debug - AuthState changed: isAuthenticated=${next.isAuthenticated}, error=${next.error}');

      if (next.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.error!),
            backgroundColor: AppTheme.errorColor,
          ),
        );
        Future.delayed(Duration.zero, () {
          if (mounted) {
            ref.read(authNotifierProvider.notifier).clearError();
          }
        });
      }

      if (next.isAuthenticated) {
        LoggerService.info(
            '🔑 Login Debug - User authenticated, waiting for user data to load...');

        // 🚀 关键修复：不立即检查用户数据，而是等待数据稳定加载
        _waitForUserDataAndRedirect();
      }
    });

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppTheme.spacingL),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: AppTheme.spacingXXL),

                // App Logo and Title
                FadeInDown(
                  duration: const Duration(milliseconds: 800),
                  child: Column(
                    children: [
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          borderRadius: AppTheme.extraLargeRadius,
                          gradient: AppTheme.primaryGradient,
                        ),
                        child: const Icon(
                          Icons.security_rounded,
                          size: 50,
                          color: AppTheme.textOnPrimary,
                        ),
                      ),
                      const SizedBox(height: AppTheme.spacingL),
                      Text(
                        AppConfig.appName,
                        style: AppTheme.headlineMedium.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppTheme.spacingS),
                      Text(
                        'Secure Digital Certificate Management',
                        style: AppTheme.bodyLarge.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: AppTheme.spacingXXL),

                // Welcome Text
                FadeInLeft(
                  duration: const Duration(milliseconds: 800),
                  delay: const Duration(milliseconds: 200),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Welcome Back',
                        style: AppTheme.headlineSmall.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: AppTheme.spacingS),
                      Text(
                        'Sign in to access your certificates',
                        style: AppTheme.bodyLarge.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: AppTheme.spacingXL),

                // Google Sign In Button
                FadeInRight(
                  duration: const Duration(milliseconds: 800),
                  delay: const Duration(milliseconds: 400),
                  child: SocialLoginButton(
                    onPressed: authState.isLoading ? null : _handleGoogleSignIn,
                    isLoading: authState.isLoading,
                    icon: 'assets/icons/google.svg',
                    text: 'Continue with Google',
                    subtitle: 'Use your UPM email address',
                  ),
                ),

                const SizedBox(height: AppTheme.spacingL),

                // Divider
                FadeInUp(
                  duration: const Duration(milliseconds: 800),
                  delay: const Duration(milliseconds: 600),
                  child: Row(
                    children: [
                      const Expanded(child: Divider()),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: AppTheme.spacingM),
                        child: Text(
                          'OR',
                          style: AppTheme.bodySmall.copyWith(
                            color: AppTheme.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const Expanded(child: Divider()),
                    ],
                  ),
                ),

                const SizedBox(height: AppTheme.spacingL),

                // Email Field
                FadeInLeft(
                  duration: const Duration(milliseconds: 800),
                  delay: const Duration(milliseconds: 800),
                  child: CustomTextField(
                    controller: _emailController,
                    label: 'Email Address',
                    hintText: 'Enter your email',
                    keyboardType: TextInputType.emailAddress,
                    prefixIcon: Icons.email_outlined,
                    validator: (value) {
                      return ValidationService.validateUpmEmail(value);
                    },
                  ),
                ),

                const SizedBox(height: AppTheme.spacingM),

                // Password Field
                FadeInRight(
                  duration: const Duration(milliseconds: 800),
                  delay: const Duration(milliseconds: 1000),
                  child: CustomTextField(
                    controller: _passwordController,
                    label: 'Password',
                    hintText: 'Enter your password',
                    obscureText: !_isPasswordVisible,
                    prefixIcon: Icons.lock_outline,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _isPasswordVisible
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                      ),
                      onPressed: () {
                        setState(() {
                          _isPasswordVisible = !_isPasswordVisible;
                        });
                      },
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your password';
                      }
                      if (value.length < AppConfig.passwordMinLength) {
                        return 'Password must be at least ${AppConfig.passwordMinLength} characters';
                      }
                      return null;
                    },
                  ),
                ),

                const SizedBox(height: AppTheme.spacingM),

                // Remember Me and Forgot Password
                FadeInUp(
                  duration: const Duration(milliseconds: 800),
                  delay: const Duration(milliseconds: 1200),
                  child: Row(
                    children: [
                      Checkbox(
                        value: _rememberMe,
                        onChanged: (value) {
                          setState(() {
                            _rememberMe = value ?? false;
                          });
                        },
                        activeColor: AppTheme.primaryColor,
                      ),
                      Text(
                        'Remember me',
                        style: AppTheme.bodyMedium,
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: _handleForgotPassword,
                        child: Text(
                          'Forgot Password?',
                          style: AppTheme.bodyMedium.copyWith(
                            color: AppTheme.primaryColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: AppTheme.spacingL),

                // Sign In Button
                FadeInUp(
                  duration: const Duration(milliseconds: 800),
                  delay: const Duration(milliseconds: 1400),
                  child: ElevatedButton(
                    onPressed: authState.isLoading ? null : _handleEmailSignIn,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          vertical: AppTheme.spacingM),
                      shape: const RoundedRectangleBorder(
                        borderRadius: AppTheme.mediumRadius,
                      ),
                    ),
                    child: authState.isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                AppTheme.textOnPrimary,
                              ),
                            ),
                          )
                        : Text(
                            'Sign In',
                            style: AppTheme.labelLarge.copyWith(
                              color: AppTheme.textOnPrimary,
                            ),
                          ),
                  ),
                ),

                const SizedBox(height: AppTheme.spacingXL),

                // Sign Up Link
                FadeInUp(
                  duration: const Duration(milliseconds: 800),
                  delay: const Duration(milliseconds: 1600),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Don\'t have an account? ',
                        style: AppTheme.bodyMedium.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      TextButton(
                        onPressed: () => context.go('/register'),
                        child: Text(
                          'Sign Up',
                          style: AppTheme.bodyMedium.copyWith(
                            color: AppTheme.primaryColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Admin Setup Link (only for system initialization)
                FadeInUp(
                  duration: const Duration(milliseconds: 800),
                  delay: const Duration(milliseconds: 1800),
                  child: Container(
                    margin: const EdgeInsets.only(top: AppTheme.spacingM),
                    padding: const EdgeInsets.all(AppTheme.spacingM),
                    decoration: BoxDecoration(
                      color: AppTheme.warningColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppTheme.warningColor.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.admin_panel_settings,
                          color: AppTheme.warningColor,
                          size: 20,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'System Administrator Setup',
                          style: AppTheme.bodySmall.copyWith(
                            color: AppTheme.warningColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        TextButton(
                          onPressed: () => context.go('/admin-setup'),
                          child: Text(
                            'Initialize Admin Account',
                            style: AppTheme.bodySmall.copyWith(
                              color: AppTheme.warningColor,
                              fontWeight: FontWeight.w600,
                              decoration: TextDecoration.underline,
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
        ),
      ),
    );
  }

  // 🚀 新增方法：等待用户数据完全加载后再重定向
  void _waitForUserDataAndRedirect() async {
    LoggerService.info('🔄 Starting user data wait cycle...');

    // 最多等待10秒，每500ms检查一次
    const maxAttempts = 20;
    const checkInterval = Duration(milliseconds: 500);

    for (int attempt = 1; attempt <= maxAttempts; attempt++) {
      if (!mounted) return;

      final currentUserState = ref.read(currentUserProvider);
      LoggerService.info(
          '🔄 Attempt $attempt/$maxAttempts - hasValue=${currentUserState.hasValue}, isLoading=${currentUserState.isLoading}, hasError=${currentUserState.hasError}');

      if (currentUserState.hasValue) {
        final user = currentUserState.value;
        if (user != null) {
          LoggerService.info(
              '✅ User data loaded successfully: ${user.email}, type=${user.userType}, status=${user.status}');

          // 用户数据加载完成，执行重定向
          _executeRedirection(user);
          return;
        } else {
          LoggerService.info('⚠️ User data is null but hasValue=true');
        }
      } else if (currentUserState.hasError) {
        LoggerService.error(
            '❌ Error loading user data: ${currentUserState.error}');
        _fallbackRedirection('Error loading user data');
        return;
      }

      // 还在加载中，等待下一次检查
      if (attempt < maxAttempts) {
        LoggerService.info(
            '⏳ User data still loading, waiting ${checkInterval.inMilliseconds}ms...');
        await Future.delayed(checkInterval);
      }
    }

    // 超时后的回退处理
    LoggerService.warning(
        '⚠️ User data loading timeout after ${maxAttempts * checkInterval.inMilliseconds}ms');
    _fallbackRedirection('User data loading timeout');
  }

  // 🚀 执行重定向逻辑
  void _executeRedirection(UserModel user) {
    if (!mounted) return;

    final defaultRoute = user.getDefaultRoute();
    LoggerService.info(
        '🎯 Executing redirection for ${user.userType}: $defaultRoute');

    if ((user.userType == UserType.client || user.userType == UserType.ca) &&
        user.status == UserStatus.pending) {
      LoggerService.info(
          '🔄 Redirecting pending ${user.userType} user to /pending');
      context.go('/pending');
    } else if (user.userType == UserType.admin &&
        user.status == UserStatus.pending) {
      LoggerService.info(
          '⏸️ Admin user pending, showing message and staying on login');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Your admin account is pending approval. Please wait for confirmation.'),
          backgroundColor: AppTheme.warningColor,
          duration: Duration(seconds: 5),
        ),
      );
      // Keep user on login page for pending admin
      return;
    } else {
      LoggerService.info('🎯 Navigating to default route: $defaultRoute');
      context.go(defaultRoute);
    }
  }

  // 🚀 回退重定向处理
  void _fallbackRedirection(String reason) {
    if (!mounted) return;

    LoggerService.warning('⚠️ Fallback redirection triggered: $reason');

    // 显示错误消息
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('登录遇到问题，请重试。原因：$reason'),
        backgroundColor: AppTheme.warningColor,
        duration: const Duration(seconds: 3),
      ),
    );

    // 清除认证状态，让用户重新登录
    ref.read(authNotifierProvider.notifier).signOut();
  }
}

class _ForgotPasswordDialog extends ConsumerStatefulWidget {
  @override
  ConsumerState<_ForgotPasswordDialog> createState() =>
      _ForgotPasswordDialogState();
}

class _ForgotPasswordDialogState extends ConsumerState<_ForgotPasswordDialog> {
  final _emailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  void _handleResetPassword() async {
    if (_formKey.currentState?.validate() ?? false) {
      setState(() {
        _isLoading = true;
      });

      try {
        await ref.read(authNotifierProvider.notifier).resetPassword(
              _emailController.text.trim(),
            );

        if (mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Password reset email sent! Check your inbox.'),
              backgroundColor: AppTheme.successColor,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(e.toString()),
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

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Reset Password'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Enter your email address and we\'ll send you a link to reset your password.',
              style: AppTheme.bodyMedium.copyWith(
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: AppTheme.spacingM),
            CustomTextField(
              controller: _emailController,
              label: 'Email Address',
              hintText: 'Enter your email',
              keyboardType: TextInputType.emailAddress,
              prefixIcon: Icons.email_outlined,
              validator: (value) {
                return ValidationService.validateUpmEmail(value);
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _handleResetPassword,
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Send Reset Link'),
        ),
      ],
    );
  }
}
