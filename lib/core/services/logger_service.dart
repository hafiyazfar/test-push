import 'package:logger/logger.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../config/app_config.dart';

/// Comprehensive Logging Service for the UPM Digital Certificate Repository.
///
/// This service provides enterprise-grade logging functionality including:
/// - Multi-level logging (debug, info, warning, error, fatal)
/// - Production-safe filtering and configuration
/// - Specialized logging for different domains
/// - Performance monitoring and metrics
/// - Remote logging capabilities
/// - Error tracking and analytics
/// - Log level management and statistics
///
/// Features:
/// - Environment-aware log filtering
/// - Structured logging with metadata
/// - Performance and network monitoring
/// - Authentication event tracking
/// - Error aggregation and reporting
/// - Debug-only sensitive data logging
/// - Configurable output formatting
///
/// Log Levels:
/// - DEBUG: Development debugging information
/// - INFO: General application information
/// - WARNING: Potential issues that don't stop execution
/// - ERROR: Error conditions that affect functionality
/// - FATAL: Critical errors that may crash the application
class LoggerService {
  // =============================================================================
  // CONSTANTS
  // =============================================================================

  /// Maximum number of logs to keep in memory
  static const int _maxLogHistory = 1000;

  /// Remote logging collection name
  static const String _remoteLogCollection = 'app_logs';

  /// Log statistics update interval in minutes
  static const int _statsUpdateIntervalMinutes = 5;

  // =============================================================================
  // SINGLETON PATTERN
  // =============================================================================

  static LoggerService? _instance;
  late final Logger _logger;

  LoggerService._internal() {
    _logger = Logger(
      level: AppConfig.isDebugMode ? Level.debug : Level.warning,
      printer: PrettyPrinter(
        methodCount: AppConfig.isDebugMode ? 2 : 0,
        errorMethodCount: 3,
        lineLength: 80,
        colors: true,
        printEmojis: true,
        dateTimeFormat: AppConfig.enableDetailedLogging
            ? DateTimeFormat.onlyTimeAndSinceStart
            : DateTimeFormat.none,
      ),
      filter: ProductionFilter(),
    );
    _initialize();
  }

  static LoggerService get instance {
    _instance ??= LoggerService._internal();
    return _instance!;
  }

  // =============================================================================
  // STATE MANAGEMENT
  // =============================================================================

  bool _isInitialized = false;
  final Map<Level, int> _logCounts = {
    Level.debug: 0,
    Level.info: 0,
    Level.warning: 0,
    Level.error: 0,
    Level.fatal: 0,
  };
  final List<LogEntry> _logHistory = [];
  DateTime _lastStatsUpdate = DateTime.now();
  int _totalLogsGenerated = 0;

  // =============================================================================
  // GETTERS
  // =============================================================================

  /// Whether the service is healthy and operational
  bool get isHealthy => _isInitialized;

  /// Total number of logs generated
  int get totalLogsGenerated => _totalLogsGenerated;

  /// Get log counts by level
  Map<Level, int> get logCounts => Map.unmodifiable(_logCounts);

  /// Get recent log history (limited)
  List<LogEntry> get recentLogs => List.unmodifiable(_logHistory);

  // =============================================================================
  // INITIALIZATION
  // =============================================================================

  /// Initialize the logger service
  void _initialize() {
    try {
      _isInitialized = true;
      _totalLogsGenerated++;
      _logCounts[Level.info] = (_logCounts[Level.info] ?? 0) + 1;

      if (kDebugMode) {
        _logger.i('Logger service initialized successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Failed to initialize logger service: $e');
      }
    }
  }

  // =============================================================================
  // CORE LOGGING METHODS
  // =============================================================================

  /// Internal logging method with enhanced functionality
  static void _log(
    Level level,
    String message, {
    dynamic error,
    StackTrace? stackTrace,
    String category = 'general',
    Map<String, dynamic>? metadata,
    bool remoteLog = false,
  }) {
    final service = instance;
    service._totalLogsGenerated++;
    service._logCounts[level] = (service._logCounts[level] ?? 0) + 1;

    // Add to history
    service._addToHistory(LogEntry(
      level: level,
      message: message,
      category: category,
      timestamp: DateTime.now(),
      error: error,
      stackTrace: stackTrace,
      metadata: metadata,
    ));

    // Console logging based on level and configuration
    switch (level) {
      case Level.debug:
        if (AppConfig.isDebugMode && kDebugMode) {
          service._logger.d(message, error: error, stackTrace: stackTrace);
        }
        break;
      case Level.info:
        if (AppConfig.enableDetailedLogging || kDebugMode) {
          service._logger.i(message, error: error, stackTrace: stackTrace);
        }
        break;
      case Level.warning:
        service._logger.w(message, error: error, stackTrace: stackTrace);
        break;
      case Level.error:
        service._logger.e(message, error: error, stackTrace: stackTrace);
        if (remoteLog && !kDebugMode) {
          service._logToRemote(
              level, message, error, stackTrace, category, metadata);
        }
        break;
      case Level.fatal:
        service._logger.f(message, error: error, stackTrace: stackTrace);
        if (remoteLog && !kDebugMode) {
          service._logToRemote(
              level, message, error, stackTrace, category, metadata);
        }
        break;
      default:
        service._logger.i(message, error: error, stackTrace: stackTrace);
    }

    // Update statistics periodically
    service._updateStatsIfNeeded();
  }

  /// Debug level logging - Development only
  static void debug(
    String message, {
    dynamic error,
    StackTrace? stackTrace,
    String category = 'debug',
    Map<String, dynamic>? metadata,
  }) {
    _log(Level.debug, message,
        error: error,
        stackTrace: stackTrace,
        category: category,
        metadata: metadata);
  }

  /// Information level logging
  static void info(
    String message, {
    dynamic error,
    StackTrace? stackTrace,
    String category = 'info',
    Map<String, dynamic>? metadata,
  }) {
    _log(Level.info, message,
        error: error,
        stackTrace: stackTrace,
        category: category,
        metadata: metadata);
  }

  /// Warning level logging
  static void warning(
    String message, {
    dynamic error,
    StackTrace? stackTrace,
    String category = 'warning',
    Map<String, dynamic>? metadata,
    bool remoteLog = false,
  }) {
    _log(Level.warning, message,
        error: error,
        stackTrace: stackTrace,
        category: category,
        metadata: metadata,
        remoteLog: remoteLog);
  }

  /// Error level logging with automatic remote logging
  static void error(
    String message, {
    dynamic error,
    StackTrace? stackTrace,
    String category = 'error',
    Map<String, dynamic>? metadata,
    bool remoteLog = true,
  }) {
    _log(Level.error, message,
        error: error,
        stackTrace: stackTrace,
        category: category,
        metadata: metadata,
        remoteLog: remoteLog);
  }

  /// Fatal level logging with automatic remote logging
  static void fatal(
    String message, {
    dynamic error,
    StackTrace? stackTrace,
    String category = 'fatal',
    Map<String, dynamic>? metadata,
    bool remoteLog = true,
  }) {
    _log(Level.fatal, message,
        error: error,
        stackTrace: stackTrace,
        category: category,
        metadata: metadata,
        remoteLog: remoteLog);
  }

  // =============================================================================
  // COMPATIBILITY ALIASES
  // =============================================================================

  /// **简化的调试日志方法（向后兼容）**
  static void d(String message, {dynamic error, StackTrace? stackTrace}) =>
      debug(message, error: error, stackTrace: stackTrace);

  /// **简化的信息日志方法（向后兼容）**
  static void i(String message, {dynamic error, StackTrace? stackTrace}) =>
      info(message, error: error, stackTrace: stackTrace);

  /// **简化的警告日志方法（向后兼容）**
  static void w(String message, {dynamic error, StackTrace? stackTrace}) =>
      warning(message, error: error, stackTrace: stackTrace);

  /// **简化的错误日志方法（向后兼容）**
  static void e(String message, {dynamic error, StackTrace? stackTrace}) =>
      error(message, error: error, stackTrace: stackTrace);

  /// **简化的致命错误日志方法（向后兼容）**
  static void f(String message, {dynamic error, StackTrace? stackTrace}) =>
      fatal(message, error: error, stackTrace: stackTrace);

  // =============================================================================
  // SPECIALIZED LOGGING METHODS
  // =============================================================================

  /// Network request and response logging
  static void network(
    String method,
    String url, {
    int? statusCode,
    dynamic requestBody,
    dynamic responseBody,
    Duration? duration,
    Map<String, String>? headers,
  }) {
    if (AppConfig.isDebugMode && kDebugMode) {
      final metadata = {
        'method': method,
        'url': url,
        'statusCode': statusCode,
        'duration': duration?.inMilliseconds,
        'hasRequestBody': requestBody != null,
        'hasResponseBody': responseBody != null,
        'headers': headers,
      };

      debug(
          'Network: [$method] $url ${statusCode != null ? '($statusCode)' : ''}${duration != null ? ' - ${duration.inMilliseconds}ms' : ''}',
          category: 'network',
          metadata: metadata);
    }
  }

  /// Authentication and authorization event logging
  static void auth(
    String event, {
    String? userId,
    String? email,
    String? method,
    bool success = true,
    String? errorReason,
  }) {
    final metadata = {
      'event': event,
      'userId': userId,
      'email': email,
      'method': method,
      'success': success,
      'errorReason': errorReason,
    };

    if (success) {
      info('Auth: $event', category: 'auth', metadata: metadata);
    } else {
      warning('Auth Failed: $event - $errorReason',
          category: 'auth', metadata: metadata, remoteLog: true);
    }
  }

  /// Performance monitoring and metrics
  static void performance(
    String operation,
    Duration duration, {
    Map<String, dynamic>? metrics,
    String? userId,
  }) {
    final metadata = {
      'operation': operation,
      'duration': duration.inMilliseconds,
      'userId': userId,
      'metrics': metrics,
    };

    if (AppConfig.isDebugMode && kDebugMode) {
      debug('Performance: $operation took ${duration.inMilliseconds}ms',
          category: 'performance', metadata: metadata);
    }

    // Log slow operations as warnings
    if (duration.inMilliseconds > 2000) {
      warning('Slow Operation: $operation took ${duration.inMilliseconds}ms',
          category: 'performance', metadata: metadata);
    }
  }

  /// User interaction and analytics logging
  static void analytics(
    String event, {
    String? userId,
    String? screen,
    Map<String, dynamic>? properties,
  }) {
    final metadata = {
      'event': event,
      'userId': userId,
      'screen': screen,
      'properties': properties,
      'timestamp': DateTime.now().toIso8601String(),
    };

    if (AppConfig.enableDetailedLogging) {
      info('Analytics: $event', category: 'analytics', metadata: metadata);
    }
  }

  /// Security event logging
  static void security(
    String event, {
    String? userId,
    String? ipAddress,
    String severity = 'medium',
    Map<String, dynamic>? details,
  }) {
    final metadata = {
      'event': event,
      'userId': userId,
      'ipAddress': ipAddress,
      'severity': severity,
      'details': details,
    };

    switch (severity.toLowerCase()) {
      case 'low':
        info('Security: $event', category: 'security', metadata: metadata);
        break;
      case 'high':
      case 'critical':
        error('Security Alert: $event',
            category: 'security', metadata: metadata, remoteLog: true);
        break;
      default:
        warning('Security: $event',
            category: 'security', metadata: metadata, remoteLog: true);
    }
  }

  // =============================================================================
  // UTILITY METHODS
  // =============================================================================

  /// Add log entry to history with size management
  void _addToHistory(LogEntry entry) {
    _logHistory.add(entry);
    if (_logHistory.length > _maxLogHistory) {
      _logHistory.removeAt(0);
    }
  }

  /// Update statistics if interval has passed
  void _updateStatsIfNeeded() {
    final now = DateTime.now();
    if (now.difference(_lastStatsUpdate).inMinutes >=
        _statsUpdateIntervalMinutes) {
      _lastStatsUpdate = now;
      // Statistics could be persisted here if needed
    }
  }

  /// Log to remote service (Firebase)
  Future<void> _logToRemote(
    Level level,
    String message,
    dynamic error,
    StackTrace? stackTrace,
    String category,
    Map<String, dynamic>? metadata,
  ) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      await FirebaseFirestore.instance.collection(_remoteLogCollection).add({
        'level': level.name,
        'message': message,
        'category': category,
        'timestamp': Timestamp.now(),
        'userId': user?.uid,
        'userEmail': user?.email,
        'error': error?.toString(),
        'stackTrace': stackTrace?.toString(),
        'metadata': metadata,
        'platform': 'flutter',
        'version': AppConfig.appVersion,
      });
    } catch (e) {
      // Fail silently for remote logging to avoid infinite loops
      if (kDebugMode) {
        debugPrint('Failed to log remotely: $e');
      }
    }
  }

  // =============================================================================
  // SERVICE MANAGEMENT
  // =============================================================================

  /// Get logging statistics
  Map<String, dynamic> getStatistics() {
    return {
      'isHealthy': isHealthy,
      'totalLogsGenerated': totalLogsGenerated,
      'logCounts': logCounts.map((k, v) => MapEntry(k.name, v)),
      'historySize': _logHistory.length,
      'lastStatsUpdate': _lastStatsUpdate.toIso8601String(),
    };
  }

  /// Clear log history
  void clearHistory() {
    _logHistory.clear();
    info('Log history cleared', category: 'system');
  }

  /// Get logs by category
  List<LogEntry> getLogsByCategory(String category) {
    return _logHistory.where((log) => log.category == category).toList();
  }

  /// Get logs by level
  List<LogEntry> getLogsByLevel(Level level) {
    return _logHistory.where((log) => log.level == level).toList();
  }

  /// Export logs for debugging
  String exportLogs({Level? minLevel, String? category}) {
    var logs = _logHistory.asMap().entries;

    if (minLevel != null) {
      logs = logs.where((entry) => entry.value.level.index >= minLevel.index);
    }

    if (category != null) {
      logs = logs.where((entry) => entry.value.category == category);
    }

    return logs.map((entry) => entry.value.toString()).join('\n');
  }
}

// =============================================================================
// SUPPORTING CLASSES
// =============================================================================

/// Enhanced production filter with more granular control
class ProductionFilter extends LogFilter {
  @override
  bool shouldLog(LogEvent event) {
    // In production, only log warnings and above
    if (!kDebugMode && !AppConfig.isDebugMode) {
      return event.level.index >= Level.warning.index;
    }

    // In debug mode, log everything based on configuration
    if (AppConfig.enableDetailedLogging) {
      return true;
    }

    // Default: log info and above
    return event.level.index >= Level.info.index;
  }
}

/// Log entry data structure
class LogEntry {
  final Level level;
  final String message;
  final String category;
  final DateTime timestamp;
  final dynamic error;
  final StackTrace? stackTrace;
  final Map<String, dynamic>? metadata;

  const LogEntry({
    required this.level,
    required this.message,
    required this.category,
    required this.timestamp,
    this.error,
    this.stackTrace,
    this.metadata,
  });

  @override
  String toString() {
    final buffer = StringBuffer();
    buffer.write('[${timestamp.toIso8601String()}] ');
    buffer.write('[${level.name.toUpperCase()}] ');
    buffer.write('[$category] ');
    buffer.write(message);

    if (error != null) {
      buffer.write(' - Error: $error');
    }

    if (metadata != null && metadata!.isNotEmpty) {
      buffer.write(' - Metadata: $metadata');
    }

    return buffer.toString();
  }
}
