import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';

import 'core/config/app_config.dart';
import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';
import 'core/services/notification_service.dart';
import 'core/services/logger_service.dart';
import 'core/providers/theme_provider.dart';
import 'core/services/migration_service.dart';
import 'core/services/validation_service.dart';
import 'core/scripts/initialize_admin.dart';
import 'core/services/initialization_service.dart';
import 'core/scripts/firebase_health_check.dart';
import 'firebase_options.dart';

/// Main application entry point - Enterprise initialization flow
///
/// Includes features:
/// - Firebase initialization (Web/Mobile adaptive)
/// - Notification service configuration
/// - Data migration and validation
/// - System health checks
/// - Automatic admin account configuration
/// - Comprehensive error handling and fallback mechanisms
/// - Startup performance monitoring
void main() async {
  // ========================================================================================
  // 🚀 Core system initialization
  // ========================================================================================

  WidgetsFlutterBinding.ensureInitialized();

  // Global error handler
  FlutterError.onError = (FlutterErrorDetails details) {
    if (kDebugMode) {
      FlutterError.presentError(details);
    }
    // Log to remote in production environment
    if (!kDebugMode) {
      LoggerService.fatal(
        'Unhandled Flutter Error: ${details.exception}',
        error: details.exception,
        stackTrace: details.stack,
        remoteLog: true,
      );
    }
  };

  // Start startup performance monitoring
  final startTime = DateTime.now();

  try {
    // ========================================================================================
    // 🔥 Firebase initialization - Platform adaptive
    // ========================================================================================

    LoggerService.info('🚀 Starting application initialization...');

    await _initializeFirebaseServices();

    // ========================================================================================
    // 🎨 System UI configuration
    // ========================================================================================

    await _configureSystemUI();

    // ========================================================================================
    // 🔄 Data migration and system initialization
    // ========================================================================================

    await _runSystemInitialization();

    // ========================================================================================
    // 👑 Admin account guarantee
    // ========================================================================================

    await _ensureAdminAccess();

    // ========================================================================================
    // 📊 Startup performance report
    // ========================================================================================

    final initDuration = DateTime.now().difference(startTime);
    LoggerService.performance('Application Initialization', initDuration);
    LoggerService.info(
        '✅ Application initialization completed successfully in ${initDuration.inMilliseconds}ms');
  } catch (e, stackTrace) {
    LoggerService.fatal(
      '💥 Critical initialization failure - starting in safe mode',
      error: e,
      stackTrace: stackTrace,
      remoteLog: true,
    );

    // Emergency fallback mode - Ensure app can still start
    await _emergencyFallback();
  }

  // ========================================================================================
  // 🏁 Launch application
  // ========================================================================================

  runApp(const ProviderScope(child: MyApp()));
}

/// Firebase service initialization - Platform aware
Future<void> _initializeFirebaseServices() async {
  try {
    LoggerService.info('🔥 Initializing Firebase services...');

    // Firebase initialization timeout protection
    await Future.any([
      _initializeFirebase(),
      Future.delayed(
        const Duration(seconds: 30),
        () => throw TimeoutException('Firebase initialization timeout', 30),
      ),
    ]);

    LoggerService.info('✅ Firebase services initialized successfully');
  } catch (e, stackTrace) {
    LoggerService.error(
      '❌ Firebase initialization failed',
      error: e,
      stackTrace: stackTrace,
    );

    // Non-blocking failure - App can still run in offline mode
    if (kDebugMode) {
      LoggerService.warning('⚠️ Continuing in offline mode for development');
    }
  }
}

/// 实际Firebase初始化逻辑
Future<void> _initializeFirebase() async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // 移动端才初始化通知服务
  if (!kIsWeb) {
    try {
      await NotificationService().initialize();
      LoggerService.info('📱 Notification service initialized');
    } catch (e) {
      LoggerService.warning('⚠️ Notification service failed to initialize',
          error: e);
    }
  }
}

/// 系统UI配置
Future<void> _configureSystemUI() async {
  try {
    LoggerService.info('🎨 Configuring system UI...');

    // 屏幕方向设置（移动端）
    if (!kIsWeb) {
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
    }

    // 状态栏样式设置
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
    );

    LoggerService.info('✅ System UI configured');
  } catch (e) {
    LoggerService.warning('⚠️ System UI configuration failed', error: e);
  }
}

/// 系统初始化流程
Future<void> _runSystemInitialization() async {
  LoggerService.info('🔧 Running system initialization...');

  // 数据迁移（可选失败）
  await _runMigrations();

  // 系统集合初始化
  await _initializeSystemCollections();

  // 用户验证和会话初始化
  await _initializeUserSession();

  // Firebase健康检查（仅移动端）
  if (!kIsWeb) {
    await _runHealthCheck();
  }
}

/// 数据迁移
Future<void> _runMigrations() async {
  try {
    LoggerService.info('🔄 Running data migrations...');
    final migrationService = MigrationService();
    await migrationService.migrateUserTypes();
    LoggerService.info('✅ Data migration completed successfully');
  } catch (e) {
    LoggerService.warning('⚠️ Migration completed with warnings', error: e);
  }
}

/// 系统集合初始化
Future<void> _initializeSystemCollections() async {
  try {
    LoggerService.info('🏗️ Initializing system collections...');
    final initializationService = InitializationService();
    await initializationService.initializeSystemCollections();
    LoggerService.info('✅ System collections initialized');
  } catch (e) {
    LoggerService.error('❌ System collections initialization failed', error: e);
  }
}

/// 用户会话初始化
Future<void> _initializeUserSession() async {
  try {
    LoggerService.info('👤 Initializing user session...');

    final validationResult =
        await ValidationService.validateUserAuthentication();
    if (validationResult.isValid) {
      LoggerService.info('✅ User authentication validated');

      final initializationService = InitializationService();
      await initializationService.initializeUserSession();
      LoggerService.info('✅ User session initialized');
    } else if (validationResult.errorMessage != null) {
      LoggerService.warning(
          '⚠️ User validation issue: ${validationResult.errorMessage}');
    }
  } catch (e) {
    LoggerService.warning(
      '⚠️ User session initialization failed - guest mode available',
      error: e,
    );
  }
}

/// Firebase健康检查
Future<void> _runHealthCheck() async {
  try {
    LoggerService.info('🔍 Running Firebase health check...');

    final healthCheckResults = await Future.any([
      FirebaseHealthCheck.runCompleteHealthCheck(),
      Future.delayed(
        const Duration(seconds: 10),
        () => {'success': false, 'error': 'Health check timeout'},
      ),
    ]);

    if (healthCheckResults['success'] == true) {
      LoggerService.info('✅ Firebase health check passed');
      final summary = healthCheckResults['summary'] as String?;
      if (summary != null) {
        LoggerService.info(summary);
      }
    } else {
      LoggerService.warning('⚠️ Firebase health check found issues');
      final errors = healthCheckResults['errors'] as List?;
      if (errors != null && errors.isNotEmpty) {
        for (final error in errors) {
          LoggerService.error('Health check error: $error');
        }
      }
    }
  } catch (e) {
    LoggerService.warning('⚠️ Firebase health check failed', error: e);
  }
}

/// 管理员账户保障
Future<void> _ensureAdminAccess() async {
  try {
    LoggerService.info('👑 Ensuring admin access...');

    final adminStatus = await Future.any([
      checkAdminStatusScript(),
      Future.delayed(
        const Duration(seconds: 15),
        () => {'needsInitialization': true, 'error': 'Admin check timeout'},
      ),
    ]);

    if (adminStatus['needsInitialization'] == true) {
      LoggerService.info(
          '⚠️ No active admin found - creating emergency admin...');

      final success = await emergencyAdminFix();
      if (success) {
        LoggerService.info('✅ Emergency admin created successfully');
      } else {
        LoggerService.error('❌ Failed to create emergency admin');
        LoggerService.info('💡 Manual admin setup available at /admin-setup');
      }
    } else {
      LoggerService.info('✅ Admin access verified');
    }
  } catch (e, stackTrace) {
    LoggerService.error(
      '❌ Admin access check failed',
      error: e,
      stackTrace: stackTrace,
    );
    LoggerService.info('💡 Manual admin setup available at /admin-setup route');
  }
}

/// 紧急回退机制
Future<void> _emergencyFallback() async {
  try {
    LoggerService.warning('🆘 Activating emergency fallback mode...');

    // 最小化系统UI配置
    if (!kIsWeb) {
      SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark);
    }

    LoggerService.info(
        '🆘 Emergency fallback activated - basic functionality available');
  } catch (e) {
    if (kDebugMode) {
      LoggerService.fatal('Emergency fallback failed',
          error: e, remoteLog: true);
    }
  }
}

/// 自定义超时异常
class TimeoutException implements Exception {
  final String message;
  final int timeoutSeconds;

  TimeoutException(this.message, this.timeoutSeconds);

  @override
  String toString() => 'TimeoutException: $message (${timeoutSeconds}s)';
}

/// 主应用组件 - 企业级配置
class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      // 应用基础配置
      title: AppConfig.appName,
      debugShowCheckedModeBanner: AppConfig.isDebugMode,

      // 主题配置
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,

      // 路由配置
      routerConfig: AppRouter.router,

      // 响应式设计和可访问性
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            // 固定文本缩放以确保一致的UI
            textScaler: const TextScaler.linear(1.0),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },

      // 本地化支持（如果需要）
      // locale: ...,
      // localizationsDelegates: ...,
      // supportedLocales: ...,
    );
  }
}
