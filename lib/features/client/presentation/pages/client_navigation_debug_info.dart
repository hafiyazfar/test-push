import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/services/logger_service.dart';
import '../../../auth/providers/auth_providers.dart';

class ClientNavigationDebugInfo extends ConsumerStatefulWidget {
  const ClientNavigationDebugInfo({super.key});

  @override
  ConsumerState<ClientNavigationDebugInfo> createState() =>
      _ClientNavigationDebugInfoState();
}

class _ClientNavigationDebugInfoState
    extends ConsumerState<ClientNavigationDebugInfo> {
  String _currentRoute = '';
  final List<String> _navigationLog = [];

  @override
  void initState() {
    super.initState();
    _updateCurrentRoute();
  }

  void _updateCurrentRoute() {
    final route =
        GoRouter.of(context).routerDelegate.currentConfiguration.uri.path;
    setState(() {
      _currentRoute = route;
    });
  }

  void _addToLog(String message) {
    setState(() {
      _navigationLog.insert(
          0, '${DateTime.now().toString().substring(11, 19)}: $message');
      if (_navigationLog.length > 20) {
        _navigationLog.removeLast();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserProvider);

    return currentUser.when(
      data: (user) {
        return Container(
          margin: const EdgeInsets.all(8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.black87,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.orange, width: 2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '🐛 Client Navigation Debug Panel',
                style: const TextStyle(
                  color: Colors.orange,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),

              // Current Status
              _buildDebugSection('Current Status', [
                'Route: $_currentRoute',
                'User: ${user?.email ?? "Unknown"}',
                'Type: ${user?.userType.toString() ?? "Unknown"}',
                'Is Client: ${user?.isClientType ?? false}',
                'Is Active: ${user?.isActive ?? false}',
              ]),

              const SizedBox(height: 12),

              // Navigation Tests
              _buildDebugSection('Quick Tests', []),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildTestButton('Dashboard', '/client/dashboard'),
                  _buildTestButton('Review', '/client/template-review'),
                  _buildTestButton('History', '/client/review-history'),
                  _buildTestButton('Reports', '/client/reports'),
                ],
              ),

              const SizedBox(height: 12),

              // Navigation Log
              _buildDebugSection(
                  'Navigation Log',
                  _navigationLog.isEmpty
                      ? ['No navigation events yet']
                      : _navigationLog.take(5).toList()),

              const SizedBox(height: 8),
              Row(
                children: [
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _navigationLog.clear();
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                    ),
                    child: const Text('Clear Log'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {
                      _updateCurrentRoute();
                      _addToLog('Debug panel refreshed');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                    ),
                    child: const Text('Refresh'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
      loading: () => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.black87,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Text(
          'Loading debug info...',
          style: TextStyle(color: Colors.white),
        ),
      ),
      error: (error, stack) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          'Debug Error: $error',
          style: const TextStyle(color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildDebugSection(String title, List<String> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.cyan,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        ...items.map((item) => Padding(
              padding: const EdgeInsets.only(left: 8, bottom: 2),
              child: Text(
                '• $item',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontFamily: 'monospace',
                ),
              ),
            )),
      ],
    );
  }

  Widget _buildTestButton(String label, String route) {
    return ElevatedButton(
      onPressed: () {
        _addToLog('Testing navigation to $route');
        try {
          context.go(route);
          _addToLog('✅ Success: $route');
          _updateCurrentRoute();
        } catch (e) {
          _addToLog('❌ Failed: $route - $e');
          LoggerService.error('Navigation test failed', error: e);
        }
      },
      style: ElevatedButton.styleFrom(
        backgroundColor:
            _currentRoute == route ? Colors.green : Colors.grey[700],
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 12),
      ),
    );
  }
}
