import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Core services
import '../services/logger_service.dart';

// Auth
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/pages/register_page.dart';
import '../../features/auth/presentation/pages/admin_setup_page.dart';
import '../../features/auth/presentation/pages/pending_page.dart';
import '../../features/ca/presentation/pages/ca_pending_approval_page.dart';
import '../../features/auth/presentation/pages/splash_page.dart';

// Dashboard
import '../../features/dashboard/presentation/pages/main_dashboard.dart';
import '../../features/dashboard/presentation/pages/dashboard_page.dart';

// Certificates
import '../../features/certificates/presentation/pages/certificate_list_page.dart';
import '../../features/certificates/presentation/pages/certificate_detail_page.dart';
import '../../features/certificates/presentation/pages/create_certificate_page.dart';
import '../../features/certificates/presentation/pages/certificate_templates_page.dart';
import '../../features/certificates/presentation/pages/certificate_request_page.dart';
import '../../features/certificates/presentation/pages/certificate_pending_page.dart';
import '../../features/certificates/presentation/pages/verify_certificate_page.dart';
import '../../features/certificates/presentation/pages/public_certificate_viewer_page.dart';
import '../../features/certificates/presentation/pages/certificate_recipient_debug_page.dart';

// Documents
import '../../features/documents/presentation/pages/document_list_page.dart';
import '../../features/documents/presentation/pages/document_detail_page.dart';
import '../../features/documents/presentation/pages/document_upload_page.dart';

// Profile
import '../../features/profile/presentation/pages/profile_page.dart';
import '../../features/profile/presentation/pages/edit_profile_page.dart';

// Notifications
import '../../features/notifications/presentation/pages/notifications_page.dart';

// Help
import '../../features/help/presentation/pages/help_page.dart';

// Support
import '../../features/support/presentation/pages/donation_page.dart';

// Client Pages
import '../../features/client/presentation/pages/client_dashboard.dart';
import '../../features/client/presentation/pages/client_template_review_page.dart';

import '../../features/client/presentation/pages/client_review_history_page.dart';
import '../../features/client/presentation/pages/client_reports_page.dart';

import '../../features/client/presentation/pages/client_navigation_test_page.dart';

// CA Pages
import '../../features/ca/presentation/pages/ca_dashboard.dart';
import '../../features/ca/presentation/pages/ca_document_review_page.dart';
import '../../features/ca/presentation/pages/ca_template_creation_page.dart';
import '../../features/ca/presentation/pages/ca_certificate_creation_page.dart';
import '../../features/ca/presentation/pages/ca_settings_page.dart';
import '../../features/ca/presentation/pages/ca_activity_page.dart';
import '../../features/ca/presentation/pages/ca_reports_page.dart';
import '../../features/ca/presentation/pages/ca_reports_debug_page.dart';

// Admin Pages
import '../../features/admin/presentation/pages/admin_dashboard.dart';
import '../../features/admin/presentation/pages/admin_analytics_page.dart';
import '../../features/admin/presentation/pages/admin_backup_page.dart';
import '../../features/admin/presentation/pages/admin_settings_page.dart';
import '../../features/admin/presentation/pages/ca_approval_page.dart';
import '../../features/admin/presentation/pages/user_management_page.dart';

// Auth providers for route guards
import '../../features/auth/providers/auth_providers.dart';

// Create aliases for the missing classes
typedef CACreateCertificatePage = CACertificateCreationPage;
typedef DashboardHomePage = DashboardPage;

class AppRouter {
  static final _rootNavigatorKey = GlobalKey<NavigatorState>();
  static final _shellNavigatorKey = GlobalKey<NavigatorState>();

  static GoRouter router = GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/splash',
    routes: [
      // Splash Screen
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashPage(),
      ),

      // Authentication Routes
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterPage(),
      ),

      // System Initialization Routes
      GoRoute(
        path: '/admin-setup',
        builder: (context, state) => const AdminSetupPage(),
      ),

      // Pending Routes (Outside shell for special layout)
      GoRoute(
        path: '/pending',
        builder: (context, state) => const PendingPage(),
      ),

      // Legacy CA Pending Route for backward compatibility
      GoRoute(
        path: '/ca/pending',
        builder: (context, state) => const CAPendingApprovalPage(),
      ),

      // Main Dashboard with Shell Navigation
      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        builder: (context, state, child) => MainDashboard(child: child),
        routes: [
          // Dashboard Home
          GoRoute(
            path: '/dashboard',
            builder: (context, state) => const DashboardHomePage(),
          ),

          // Certificates
          GoRoute(
            path: '/certificates',
            builder: (context, state) => const CertificateListPage(),
            routes: [
              GoRoute(
                path: 'create',
                builder: (context, state) => const CreateCertificatePage(),
              ),
              GoRoute(
                path: 'request',
                builder: (context, state) => const CertificateRequestPage(),
              ),
              GoRoute(
                path: 'pending',
                builder: (context, state) => const CertificatePendingPage(),
              ),
              GoRoute(
                path: 'downloads',
                builder: (context, state) => const CertificateListPage(),
              ),
              GoRoute(
                path: 'share',
                builder: (context, state) => const CertificateListPage(),
              ),
              GoRoute(
                path: 'templates',
                builder: (context, state) => const CertificateTemplatesPage(),
              ),
              GoRoute(
                path: 'issued',
                builder: (context, state) => const CertificateListPage(),
              ),
              GoRoute(
                path: ':id/edit',
                builder: (context, state) => CreateCertificatePage(
                  certificateId: state.pathParameters['id']!,
                ),
              ),
              GoRoute(
                path: 'debug-recipient',
                builder: (context, state) =>
                    const CertificateRecipientDebugPage(),
              ),
              GoRoute(
                path: ':id',
                builder: (context, state) => CertificateDetailPage(
                  certificateId: state.pathParameters['id']!,
                ),
              ),
            ],
          ),

          // Documents
          GoRoute(
            path: '/documents',
            builder: (context, state) => const DocumentListPage(),
            routes: [
              GoRoute(
                path: 'upload',
                builder: (context, state) => const DocumentUploadPage(),
              ),
              GoRoute(
                path: 'share',
                builder: (context, state) => const DocumentListPage(),
              ),
              GoRoute(
                path: 'view/:id',
                builder: (context, state) => DocumentDetailPage(
                  documentId: state.pathParameters['id']!,
                ),
              ),
              GoRoute(
                path: 'edit/:id',
                builder: (context, state) => DocumentUploadPage(
                  documentId: state.pathParameters['id']!,
                ),
              ),
              GoRoute(
                path: ':id',
                builder: (context, state) => DocumentDetailPage(
                  documentId: state.pathParameters['id']!,
                ),
              ),
            ],
          ),

          // Profile
          GoRoute(
            path: '/profile',
            builder: (context, state) => const ProfilePage(),
            routes: [
              GoRoute(
                path: 'edit',
                builder: (context, state) => const EditProfilePage(),
              ),
            ],
          ),

          // Admin Routes
          GoRoute(
            path: '/admin',
            redirect: (context, state) {
              // 只有当用户直接访问 /admin 时才重定向到 dashboard
              // 不要影响子路由的访问
              if (state.uri.path == '/admin') {
                return '/admin/dashboard';
              }
              return null; // 允许访问子路由
            },
            routes: [
              GoRoute(
                path: 'dashboard',
                builder: (context, state) => const AdminDashboard(),
              ),
              GoRoute(
                path: 'users',
                builder: (context, state) => const UserManagementPage(),
              ),
              GoRoute(
                path: 'ca-approval',
                builder: (context, state) => const CAApprovalPage(),
              ),
              GoRoute(
                path: 'ca-approvals',
                builder: (context, state) => const CAApprovalPage(),
              ),
              GoRoute(
                path: 'settings',
                builder: (context, state) => const AdminSettingsPage(),
              ),
              GoRoute(
                path: 'analytics',
                builder: (context, state) => const AdminAnalyticsPage(),
              ),
              GoRoute(
                path: 'backup',
                builder: (context, state) => const AdminBackupPage(),
              ),
              GoRoute(
                path: 'reports',
                builder: (context, state) => const AdminAnalyticsPage(),
              ),
            ],
          ),

          // Client Routes (Certificate Approval Center)
          GoRoute(
            path: '/client',
            redirect: (context, state) {
              // 只有当用户直接访问 /client 时才重定向到 dashboard
              // 不要影响子路由的访问
              if (state.uri.path == '/client') {
                return '/client/dashboard';
              }
              return null; // 允许访问子路由
            },
            routes: [
              GoRoute(
                path: 'dashboard',
                builder: (context, state) => const ClientDashboard(),
              ),
              GoRoute(
                path: 'template-review',
                builder: (context, state) => const ClientTemplateReviewPage(),
              ),
              GoRoute(
                path: 'review-history',
                builder: (context, state) => const ClientReviewHistoryPage(),
              ),
              GoRoute(
                path: 'reports',
                builder: (context, state) => const ClientReportsPage(),
              ),
              GoRoute(
                path: 'navigation-test',
                builder: (context, state) => const ClientNavigationTestPage(),
              ),
            ],
          ),

          // Certificate Authority (CA) Routes (Document Review & Template Creation)
          GoRoute(
            path: '/ca',
            redirect: (context, state) {
              // 只有当用户直接访问 /ca 时才重定向到 dashboard
              // 不要影响子路由的访问
              if (state.uri.path == '/ca') {
                return '/ca/dashboard';
              }
              return null; // 允许访问子路由
            },
            routes: [
              GoRoute(
                path: 'dashboard',
                builder: (context, state) => const CADashboard(),
              ),
              GoRoute(
                path: 'document-review',
                builder: (context, state) => const CADocumentReviewPage(),
              ),
              GoRoute(
                path: 'template-creation',
                builder: (context, state) => const CATemplateCreationPage(),
              ),
              GoRoute(
                path: 'template-submission',
                builder: (context, state) => const CACertificateCreationPage(),
              ),
              GoRoute(
                path: 'reports',
                builder: (context, state) => const CAReportsPage(),
              ),
              GoRoute(
                path: 'reports-debug',
                builder: (context, state) => const CAReportsDebugPage(),
              ),
              GoRoute(
                path: 'activity',
                builder: (context, state) => const CAActivityPage(),
              ),
              GoRoute(
                path: 'settings',
                builder: (context, state) => const CASettingsPage(),
              ),
            ],
          ),

          // Verification Routes
          GoRoute(
            path: '/verify',
            builder: (context, state) => const VerifyCertificatePage(),
            routes: [
              GoRoute(
                path: 'scanner',
                builder: (context, state) => const VerifyCertificatePage(),
              ),
            ],
          ),

          // Public Routes
          GoRoute(
            path: '/public',
            builder: (context, state) => const VerifyCertificatePage(),
          ),

          // Help Route
          GoRoute(
            path: '/help',
            builder: (context, state) => const HelpPage(),
          ),

          // Notifications Route
          GoRoute(
            path: '/notifications',
            builder: (context, state) => const NotificationsPage(),
          ),

          // Support/Donation Route
          GoRoute(
            path: '/support',
            builder: (context, state) =>
                const HelpPage(), // Default to help page
            routes: [
              GoRoute(
                path: 'donate',
                builder: (context, state) => const DonationPage(),
              ),
            ],
          ),
        ],
      ),

      // Public Viewer (No authentication required)
      GoRoute(
        path: '/view/:token',
        builder: (context, state) => PublicCertificateViewerPage(
          token: state.pathParameters['token']!,
        ),
      ),

      // Error Page
      GoRoute(
        path: '/error',
        builder: (context, state) => ErrorPage(
          error: state.extra as String?,
        ),
      ),
    ],

    // Redirect logic for authentication and authorization
    redirect: (context, state) {
      final currentPath = state.uri.path;

      if (kDebugMode) {
        LoggerService.debug('Router checking path: $currentPath');
      }

      // 🚀 立即允许访问的路径，无需任何检查
      final immediateAccessPaths = [
        '/login',
        '/register',
        '/splash',
        '/admin-setup',
        '/pending',
        '/ca/pending',
        '/error'
      ];

      // 🚀 允许访问公开页面
      if (currentPath.startsWith('/view/') ||
          immediateAccessPaths.contains(currentPath)) {
        if (kDebugMode) {
          LoggerService.debug(
              'Router immediate access granted to: $currentPath');
        }
        return null;
      }

      try {
        final container = ProviderScope.containerOf(context);
        final authState = container.read(authStateProvider);

        // 🚀 简化认证检查：只检查Firebase Auth状态
        final isAuthenticated = authState.hasValue &&
            authState.value != null &&
            !authState.hasError;

        if (kDebugMode) {
          LoggerService.debug(
              'Router auth status: $isAuthenticated for path: $currentPath');
        }

        // 🚀 未认证用户：重定向到登录页面
        if (!isAuthenticated) {
          if (kDebugMode) {
            LoggerService.debug(
                'Router not authenticated, redirecting to /login');
          }
          return '/login';
        }

        // 🚀 已认证用户的路由处理

        // 处理根路径重定向
        if (currentPath == '/') {
          if (kDebugMode) {
            LoggerService.debug(
                'Router authenticated user at root, redirecting to /dashboard');
          }
          return '/dashboard';
        }

        // 允许访问所有受保护的路径
        final protectedBasePaths = [
          '/dashboard',
          '/admin',
          '/client',
          '/ca',
          '/certificates',
          '/documents',
          '/profile',
          '/settings',
          '/notifications',
          '/help',
          '/support',
          '/verify',
          '/public'
        ];

        final isProtectedPath = protectedBasePaths
            .any((basePath) => currentPath.startsWith(basePath));

        if (isProtectedPath) {
          if (kDebugMode) {
            LoggerService.debug(
                'Router authenticated user accessing protected path: $currentPath');
          }
          return null; // 允许访问
        }

        // 其他未匹配的路径，允许通过（可能是动态路由）
        if (kDebugMode) {
          LoggerService.debug('Router allowing unmatched path: $currentPath');
        }
        return null;
      } catch (e, stackTrace) {
        LoggerService.error(
            'Router redirect logic error for path: $currentPath',
            error: e,
            stackTrace: stackTrace);

        // 发生错误时的处理
        final isPublicPath = currentPath.startsWith('/view/') ||
            immediateAccessPaths.contains(currentPath);

        if (isPublicPath) {
          return null; // 允许访问公开路径
        } else {
          // 对于受保护路径发生错误，重定向到登录页面
          return '/login';
        }
      }
    },

    errorBuilder: (context, state) => ErrorPage(
      error: state.error?.toString(),
    ),
  );
}

class ErrorPage extends StatelessWidget {
  final String? error;

  const ErrorPage({super.key, this.error});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Error'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red,
            ),
            const SizedBox(height: 16),
            Text(
              'Something went wrong',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            if (error != null) ...[
              const SizedBox(height: 8),
              Text(
                error!,
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => context.go('/dashboard'),
              child: const Text('Go to Dashboard'),
            ),
          ],
        ),
      ),
    );
  }
}
