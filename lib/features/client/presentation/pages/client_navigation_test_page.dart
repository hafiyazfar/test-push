import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/providers/auth_providers.dart';

class ClientNavigationTestPage extends ConsumerWidget {
  const ClientNavigationTestPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(currentUserProvider);

    return currentUser.when(
      data: (user) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Client Navigation Test'),
            backgroundColor: AppTheme.primaryColor,
            foregroundColor: Colors.white,
          ),
          body: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // User Information
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'User Information',
                          style: AppTheme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text('Email: ${user?.email ?? "Unknown"}'),
                        Text('Display Name: ${user?.displayName ?? "Unknown"}'),
                        Text(
                            'User Type: ${user?.userType.toString() ?? "Unknown"}'),
                        Text(
                            'User Type Display: ${user?.userTypeDisplayName ?? "Unknown"}'),
                        Text('Is Client Type: ${user?.isClientType ?? false}'),
                        Text('Is Admin: ${user?.isAdmin ?? false}'),
                        Text('Status: ${user?.status.toString() ?? "Unknown"}'),
                        Text('Is Active: ${user?.isActive ?? false}'),
                        Text(
                            'Can Access Client Panel: ${user?.canAccessClientPanel ?? false}'),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Navigation Test Buttons
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Navigation Test',
                          style: AppTheme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildNavigationButton(
                          context,
                          'Client Dashboard',
                          '/client/dashboard',
                          Icons.dashboard,
                        ),
                        _buildNavigationButton(
                          context,
                          'Certificate Approve Center',
                          '/client/template-review',
                          Icons.rate_review,
                        ),
                        _buildNavigationButton(
                          context,
                          'Review History',
                          '/client/review-history',
                          Icons.history,
                        ),
                        _buildNavigationButton(
                          context,
                          'Reports',
                          '/client/reports',
                          Icons.bar_chart,
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Current Location
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Current Location',
                          style: AppTheme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          GoRouter.of(context)
                              .routerDelegate
                              .currentConfiguration
                              .uri
                              .path,
                          style: AppTheme.textTheme.bodyLarge?.copyWith(
                            fontFamily: 'monospace',
                            color: AppTheme.primaryColor,
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
      },
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) => Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text('Error: $error'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavigationButton(
    BuildContext context,
    String title,
    String route,
    IconData icon,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () {
            try {
              context.go(route);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Navigated to: $route'),
                  backgroundColor: AppTheme.successColor,
                ),
              );
            } catch (e) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Navigation failed: $e'),
                  backgroundColor: AppTheme.errorColor,
                ),
              );
            }
          },
          icon: Icon(icon),
          label: Text(title),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.all(16),
            alignment: Alignment.centerLeft,
          ),
        ),
      ),
    );
  }
}
