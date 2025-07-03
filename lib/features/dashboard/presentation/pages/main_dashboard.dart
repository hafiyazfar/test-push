import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/models/user_model.dart';
import '../../../../core/services/logger_service.dart';
import '../../../auth/providers/auth_providers.dart';

class MainDashboard extends ConsumerStatefulWidget {
  final Widget child;

  const MainDashboard({
    super.key,
    required this.child,
  });

  @override
  ConsumerState<MainDashboard> createState() => _MainDashboardState();
}

class _MainDashboardState extends ConsumerState<MainDashboard> {
  int _selectedIndex = 0;
  UserModel? _currentUser;
  List<NavigationItem> _navigationItems = [];

  @override
  void initState() {
    super.initState();
    // Initialize state once
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeNavigation();
    });
  }

  String? _lastKnownRoute;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Listen for route changes, update navigation state (avoid duplicate updates)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _navigationItems.isNotEmpty) {
        final currentRoute =
            GoRouter.of(context).routerDelegate.currentConfiguration.uri.path;

        // Only update when route actually changes
        if (currentRoute != _lastKnownRoute) {
          _lastKnownRoute = currentRoute;
          if (kDebugMode) {
            LoggerService.debug(
                '🔄 Main Dashboard - Route change detected: $currentRoute');
          }
          _updateSelectedIndexFromRoute();
        }
      }
    });
  }

  void _initializeNavigation() {
    final currentUser = ref.read(currentUserProvider).value;
    if (kDebugMode) {
      LoggerService.debug(
          'Initializing navigation for user: ${currentUser?.email}, type: ${currentUser?.userType}');
    }

    if (currentUser != null && currentUser != _currentUser) {
      setState(() {
        _currentUser = currentUser;
        _navigationItems = _getNavigationItems(currentUser);
        _updateSelectedIndexFromRoute();
      });
    }
  }

  // Improved route matching logic
  void _updateSelectedIndexFromRoute() {
    final currentLocation =
        GoRouter.of(context).routerDelegate.currentConfiguration.uri.path;

    if (kDebugMode) {
      LoggerService.debug(
          'Updating navigation index for route: $currentLocation');
    }

    int newIndex = 0; // Default to first item

    for (int i = 0; i < _navigationItems.length; i++) {
      final route = _navigationItems[i].route;

      // Improved route matching logic
      bool routeMatches = false;

      // First perform exact matching
      if (currentLocation == route) {
        routeMatches = true;
      }
      // Then handle special route processing
      else {
        switch (route) {
          case '/client/dashboard':
            if (currentLocation == '/client') {
              routeMatches = true;
            }
            break;
          case '/client/template-review':
            if (currentLocation == '/client/template-review') {
              routeMatches = true;
            }
            break;

          case '/client/review-history':
            if (currentLocation == '/client/review-history') {
              routeMatches = true;
            }
            break;
          case '/ca/dashboard':
            if (currentLocation == '/ca') {
              routeMatches = true;
            }
            break;
          case '/ca/document-review':
            if (currentLocation == '/ca/document-review') {
              routeMatches = true;
            }
            break;
          case '/ca/template-creation':
            if (currentLocation == '/ca/template-creation' ||
                currentLocation == '/ca/template-submission') {
              routeMatches = true;
            }
            break;
          case '/ca/reports':
            if (currentLocation == '/ca/reports') {
              routeMatches = true;
            }
            break;
          case '/admin':
            if (currentLocation.startsWith('/admin')) {
              routeMatches = true;
            }
            break;
          case '/certificates':
            if (currentLocation.startsWith('/certificates')) {
              routeMatches = true;
            }
            break;
          case '/documents':
            if (currentLocation.startsWith('/documents')) {
              routeMatches = true;
            }
            break;
          case '/dashboard':
            if (currentLocation == '/dashboard') {
              routeMatches = true;
            }
            break;
          case '/profile':
            if (currentLocation.startsWith('/profile')) {
              routeMatches = true;
            }
            break;
        }
      }

      if (routeMatches) {
        newIndex = i;
        if (kDebugMode) {
          LoggerService.debug(
              'Route matched: $route at index $i for location: $currentLocation');
        }
        break;
      }
    }

    if (_selectedIndex != newIndex) {
      if (kDebugMode) {
        LoggerService.debug(
            'Updating selected index from $_selectedIndex to $newIndex');
      }
      setState(() {
        _selectedIndex = newIndex;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserProvider);

    return currentUser.when(
      data: (user) {
        if (user == null) {
          // User not authenticated, redirect to login page
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              context.go('/login');
            }
          });
          return Scaffold(
            backgroundColor: AppTheme.backgroundColor,
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: AppTheme.spacingL),
                  Text(
                    'Please sign in to continue',
                    style: AppTheme.bodyLarge.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        // Only update navigation if user changed
        if (user != _currentUser) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              final newNavigationItems = _getNavigationItems(user);
              setState(() {
                _currentUser = user;
                _navigationItems = newNavigationItems;
                // 重置选中索引并根据当前路由更新
                _selectedIndex = 0;
                _lastKnownRoute = null; // 重置路由状态
                _updateSelectedIndexFromRoute();
              });
            }
          });
        }

        // If navigation items are not yet initialized, show loading
        if (_navigationItems.isEmpty) {
          return Scaffold(
            backgroundColor: AppTheme.backgroundColor,
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: AppTheme.spacingL),
                  Text(
                    'Loading your dashboard...',
                    style: AppTheme.bodyLarge.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacingS),
                  Text(
                    'User type: ${user.userTypeDisplayName}',
                    style: AppTheme.bodySmall.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacingS),
                  if (kDebugMode)
                    Text(
                      'Debug: userType=${user.userType}, isClientType=${user.isClientType}, email=${user.email}',
                      style: AppTheme.bodySmall.copyWith(
                        color: AppTheme.errorColor,
                      ),
                      textAlign: TextAlign.center,
                    ),
                ],
              ),
            ),
          );
        }

        return Scaffold(
          body: widget.child,
          bottomNavigationBar: _buildBottomNavigationBar(_navigationItems),
        );
      },
      loading: () => Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: AppTheme.spacingL),
              Text(
                'Loading user profile...',
                style: AppTheme.bodyLarge.copyWith(
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
      error: (error, stack) {
        LoggerService.error('Main dashboard authentication error',
            error: error, stackTrace: stack);
        // Also redirect to login page when error occurs
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            context.go('/login');
          }
        });
        return Scaffold(
          backgroundColor: AppTheme.backgroundColor,
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: AppTheme.spacingL),
                Text(
                  'Redirecting to login...',
                  style: AppTheme.bodyLarge.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBottomNavigationBar(List<NavigationItem> items) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.backgroundLight,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            offset: const Offset(0, -2),
            blurRadius: 8,
            spreadRadius: 0,
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spacingS,
            vertical: AppTheme.spacingXS,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: items.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              final isSelected = _selectedIndex == index;

              return Expanded(
                child: GestureDetector(
                  onTap: () {
                    if (kDebugMode) {
                      LoggerService.debug(
                          '🔵 Navigation tapped: ${item.label} -> ${item.route}');
                    }

                    // 检查当前是否已经在目标路由
                    final currentLocation = GoRouter.of(context)
                        .routerDelegate
                        .currentConfiguration
                        .uri
                        .path;

                    if (kDebugMode) {
                      LoggerService.debug(
                          '🔵 Current location: $currentLocation, Target: ${item.route}');
                    }

                    if (currentLocation == item.route) {
                      if (kDebugMode) {
                        LoggerService.debug(
                            '🔵 Already on target route: ${item.route}');
                      }
                      return; // 如果已经在目标路由，不需要导航
                    }

                    // 更新选中索引
                    if (kDebugMode) {
                      LoggerService.debug(
                          '🔵 Updating selected index from $_selectedIndex to $index');
                    }
                    setState(() {
                      _selectedIndex = index;
                    });

                    // 导航到目标路由
                    try {
                      if (kDebugMode) {
                        LoggerService.debug(
                            '🔵 Attempting navigation to: ${item.route}');
                      }
                      context.go(item.route);
                      // 更新已知路由，避免重复状态更新
                      _lastKnownRoute = item.route;
                      if (kDebugMode) {
                        LoggerService.debug(
                            '🔵 Successfully navigated to: ${item.route}');
                      }
                    } catch (e) {
                      if (kDebugMode) {
                        LoggerService.error(
                            '🔴 Navigation error to ${item.route}',
                            error: e);
                      }

                      // 重置选中状态
                      _updateSelectedIndexFromRoute();

                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('导航失败: ${e.toString()}'),
                            backgroundColor: AppTheme.errorColor,
                            duration: const Duration(seconds: 3),
                            action: SnackBarAction(
                              label: '重试',
                              textColor: Colors.white,
                              onPressed: () {
                                try {
                                  context.go(item.route);
                                } catch (retryError) {
                                  LoggerService.error('Retry navigation failed',
                                      error: retryError);
                                }
                              },
                            ),
                          ),
                        );
                      }
                    }
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                      vertical: AppTheme.spacingS,
                      horizontal: AppTheme.spacingXS,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: AppTheme.mediumRadius,
                      color: isSelected
                          ? AppTheme.primaryColor.withValues(alpha: 0.1)
                          : Colors.transparent,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.all(AppTheme.spacingXS),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppTheme.primaryColor
                                : Colors.transparent,
                            borderRadius: AppTheme.smallRadius,
                          ),
                          child: Icon(
                            item.icon,
                            size: 24,
                            color: isSelected
                                ? AppTheme.textOnPrimary
                                : AppTheme.textSecondary,
                          ),
                        ),
                        const SizedBox(height: AppTheme.spacingXS),
                        Text(
                          item.label,
                          style: AppTheme.bodySmall.copyWith(
                            color: isSelected
                                ? AppTheme.primaryColor
                                : AppTheme.textSecondary,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  List<NavigationItem> _getNavigationItems(UserModel user) {
    final baseItems = <NavigationItem>[
      const NavigationItem(
        icon: Icons.dashboard_outlined,
        label: 'Dashboard',
        route: '/dashboard',
      ),
      const NavigationItem(
        icon: Icons.description_outlined,
        label: 'Certificates',
        route: '/certificates',
      ),
    ];

    // Debug: Log user information
    if (kDebugMode) {
      LoggerService.debug(
          'Creating navigation for user: ${user.email}, userType: ${user.userType}, isClientType: ${user.isClientType}');
    }

    // Add user type specific navigation items
    switch (user.userType) {
      case UserType.admin:
        return [
          ...baseItems,
          const NavigationItem(
            icon: Icons.folder_outlined,
            label: 'Documents',
            route: '/documents',
          ),
          const NavigationItem(
            icon: Icons.admin_panel_settings_outlined,
            label: 'Admin',
            route: '/admin',
          ),
          const NavigationItem(
            icon: Icons.person_outlined,
            label: 'Profile',
            route: '/profile',
          ),
        ];

      case UserType.client:
        if (kDebugMode) {
          LoggerService.debug(
              'Creating CLIENT navigation items for user: ${user.email}');
        }
        return [
          const NavigationItem(
            icon: Icons.dashboard_outlined,
            label: 'Dashboard',
            route: '/client/dashboard',
          ),
          const NavigationItem(
            icon: Icons.rate_review_outlined,
            label: 'Certificate Approve Center',
            route: '/client/template-review',
          ),
          const NavigationItem(
            icon: Icons.history_outlined,
            label: 'History',
            route: '/client/review-history',
          ),
          const NavigationItem(
            icon: Icons.person_outlined,
            label: 'Profile',
            route: '/profile',
          ),
        ];

      case UserType.ca:
        return [
          const NavigationItem(
            icon: Icons.dashboard_outlined,
            label: 'Dashboard',
            route: '/ca/dashboard',
          ),
          const NavigationItem(
            icon: Icons.folder_open_outlined,
            label: 'Doc Review',
            route: '/ca/document-review',
          ),
          const NavigationItem(
            icon: Icons.create_outlined,
            label: 'Create Template',
            route: '/ca/template-creation',
          ),
          const NavigationItem(
            icon: Icons.analytics_outlined,
            label: 'Reports',
            route: '/ca/reports',
          ),
          const NavigationItem(
            icon: Icons.person_outlined,
            label: 'Profile',
            route: '/profile',
          ),
        ];

      case UserType.user:
        return [
          ...baseItems,
          const NavigationItem(
            icon: Icons.folder_outlined,
            label: 'Documents',
            route: '/documents',
          ),
          const NavigationItem(
            icon: Icons.person_outlined,
            label: 'Profile',
            route: '/profile',
          ),
        ];
    }
  }
}

class NavigationItem {
  final IconData icon;
  final String label;
  final String route;

  const NavigationItem({
    required this.icon,
    required this.label,
    required this.route,
  });
}
