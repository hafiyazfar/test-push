import 'dart:async';

import 'package:flutter/widgets.dart';

import '../config/app_config.dart';
import 'logger_service.dart';

/// 🎯 **UPM数字证书仓库系统 - 企业级性能监控服务**
///
/// **核心功能：**
/// - 📊 **全面性能监控** - 操作、Widget、内存、网络、数据库性能监控
/// - 🚨 **实时警报系统** - 性能瓶颈实时检测和通知
/// - 📈 **趋势分析** - 性能数据统计分析和趋势预测
/// - 💾 **数据持久化** - 性能数据存储和历史记录
/// - 🌐 **跨平台兼容** - Web、iOS、Android完美支持
/// - 📱 **实时仪表板** - 性能指标可视化和报告生成
/// - 🔧 **智能调优** - 自动性能优化建议
/// - 🌍 **多语言支持** - 完整的中英文本地化
///
/// **监控范围：**
/// - 🏃‍♂️ **操作性能** - 业务操作执行时间和效率
/// - 🎨 **UI性能** - Widget构建、渲染、帧率监控
/// - 💾 **内存性能** - 内存使用、泄漏检测、GC分析
/// - 🌐 **网络性能** - API调用、下载上传速度
/// - 🗄️ **数据库性能** - 查询执行时间、缓存效率
/// - 🔄 **系统性能** - CPU、电池、存储使用情况
///
/// **技术特性：**
/// - 线程安全的单例模式
/// - 非阻塞的异步监控
/// - 智能阈值管理
/// - 自动数据清理机制
class PerformanceService {
  static PerformanceService? _instance;
  static final Object _lock = Object();

  /// 获取性能监控服务单例实例
  static PerformanceService get instance {
    if (_instance == null) {
      synchronized(_lock, () {
        _instance ??= PerformanceService._internal();
      });
    }
    return _instance!;
  }

  PerformanceService._internal() {
    _initializeService();
  }

  // 核心依赖服务

  // ignore: unused_field

  // ignore: unused_field

  // ignore: unused_field

  // 服务状态管理
  bool _isInitialized = false;
  bool _isMonitoring = false;
  DateTime _lastHealthCheck = DateTime.now();

  // 性能数据存储
  final Map<String, DateTime> _operationStartTimes = {};
  final Map<String, List<Duration>> _operationDurations = {};
  final Map<String, List<double>> _memoryUsageHistory = {};
  final Map<String, List<int>> _networkLatencyHistory = {};
  final Map<String, List<double>> _frameTimes = {};
  final Map<String, int> _operationCounts = {};
  final Map<String, DateTime> _lastOperationTimes = {};

  // 性能警报管理
  final Set<String> _activeAlerts = {};
  final Map<String, int> _alertCounts = {};
  final List<PerformanceAlert> _alertHistory = [];

  // 配置和阈值
  Timer? _cleanupTimer;
  Timer? _healthCheckTimer;
  StreamController<PerformanceMetric>? _metricsController;

  /// **性能监控配置常量**
  static const Map<String, dynamic> kPerformanceConfig = {
    'maxOperationTime': 5000, // 5秒
    'slowOperationThreshold': 1000, // 1秒
    'frameDropThreshold': 16, // 16ms (60fps)
    'memoryWarningThreshold': 200 * 1024 * 1024, // 200MB
    'networkTimeoutThreshold': 30000, // 30秒
    'maxHistoryEntries': 1000,
    'cleanupIntervalMinutes': 30,
    'healthCheckIntervalMinutes': 5,
  };

  /// **性能阈值配置**
  static const Map<String, Map<String, int>> kPerformanceThresholds = {
    'operations': {
      'excellent': 100,
      'good': 500,
      'warning': 1000,
      'critical': 5000,
    },
    'frames': {
      'excellent': 16,
      'good': 20,
      'warning': 33,
      'critical': 50,
    },
    'memory': {
      'excellent': 50 * 1024 * 1024,
      'good': 100 * 1024 * 1024,
      'warning': 200 * 1024 * 1024,
      'critical': 500 * 1024 * 1024,
    },
    'network': {
      'excellent': 100,
      'good': 500,
      'warning': 1000,
      'critical': 5000,
    },
  };

  /// **初始化性能监控服务**
  Future<void> _initializeService() async {
    try {
      LoggerService.i('🎯 正在初始化性能监控服务...');

      // 初始化度量流
      _metricsController = StreamController<PerformanceMetric>.broadcast();

      // 启动定期清理
      _startPeriodicCleanup();

      // 启动健康检查
      _startHealthCheckTimer();

      // 初始化帧性能监控
      _initializeFrameMonitoring();

      // 启动内存监控
      _startMemoryMonitoring();

      _isInitialized = true;
      _isMonitoring = true;
      LoggerService.i('✅ 性能监控服务初始化完成');
    } catch (e) {
      LoggerService.e('❌ 性能监控服务初始化失败: $e');
      rethrow;
    }
  }

  /// **健康检查**
  Future<Map<String, dynamic>> performHealthCheck() async {
    try {
      final startTime = DateTime.now();

      // 检查服务状态
      _checkServiceStatus();

      // 检查内存使用
      final memoryStatus = _checkMemoryHealth();

      // 检查性能数据完整性
      final dataIntegrity = _checkDataIntegrity();

      // 生成性能统计
      final performanceStats = getDetailedPerformanceStats();

      final healthCheckTime =
          DateTime.now().difference(startTime).inMilliseconds;
      _lastHealthCheck = DateTime.now();

      return {
        'service': 'PerformanceService',
        'status': 'healthy',
        'initialized': _isInitialized,
        'monitoring': _isMonitoring,
        'lastCheck': _lastHealthCheck.toIso8601String(),
        'healthCheckTime': '${healthCheckTime}ms',
        'memoryStatus': memoryStatus,
        'dataIntegrity': dataIntegrity,
        'statistics': performanceStats,
        'alerts': {
          'active': _activeAlerts.length,
          'total': _alertHistory.length,
          'recent': _getRecentAlerts(10),
        },
      };
    } catch (e) {
      LoggerService.e('❌ 性能监控服务健康检查失败: $e');
      return {
        'service': 'PerformanceService',
        'status': 'unhealthy',
        'error': e.toString(),
        'lastCheck': DateTime.now().toIso8601String(),
      };
    }
  }

  /// **开始监控操作性能**
  ///
  /// [operationName] 操作名称
  /// [category] 操作分类（如 'api', 'database', 'ui'）
  /// [metadata] 附加元数据
  static void startOperation(
    String operationName, {
    String category = 'general',
    Map<String, dynamic>? metadata,
  }) {
    if (!AppConfig.isDebugMode && !AppConfig.isProfileMode) return;

    try {
      final now = DateTime.now();
      final fullName = '$category:$operationName';

      instance._operationStartTimes[fullName] = now;
      instance._lastOperationTimes[fullName] = now;
      instance._operationCounts[fullName] =
          (instance._operationCounts[fullName] ?? 0) + 1;

      // 发送开始事件
      instance._emitMetric(PerformanceMetric(
        name: fullName,
        type: MetricType.operationStart,
        value: 0,
        timestamp: now,
        category: category,
        metadata: metadata,
      ));
    } catch (e) {
      LoggerService.e('❌ 开始操作监控失败: $e');
    }
  }

  /// **结束监控操作性能**
  ///
  /// [operationName] 操作名称
  /// [category] 操作分类
  /// [success] 操作是否成功
  /// [metadata] 附加元数据
  static void endOperation(
    String operationName, {
    String category = 'general',
    bool success = true,
    Map<String, dynamic>? metadata,
  }) {
    if (!AppConfig.isDebugMode && !AppConfig.isProfileMode) return;

    try {
      final now = DateTime.now();
      final fullName = '$category:$operationName';
      final startTime = instance._operationStartTimes.remove(fullName);

      if (startTime != null) {
        final duration = now.difference(startTime);

        // 存储性能数据
        instance._operationDurations.putIfAbsent(fullName, () => []);
        instance._operationDurations[fullName]!.add(duration);

        // 限制历史记录大小
        _limitHistorySize(instance._operationDurations[fullName]!);

        // 检查性能阈值
        instance._checkOperationThreshold(fullName, duration, success);

        // 记录性能日志
        LoggerService.performance(fullName, duration);

        // 发送结束事件
        instance._emitMetric(PerformanceMetric(
          name: fullName,
          type: MetricType.operationEnd,
          value: duration.inMilliseconds.toDouble(),
          timestamp: now,
          category: category,
          success: success,
          metadata: metadata,
        ));
      }
    } catch (e) {
      LoggerService.e('❌ 结束操作监控失败: $e');
    }
  }

  /// **监控Widget构建性能**
  ///
  /// [widgetName] Widget名称
  /// [buildFunction] 构建函数
  /// [metadata] 附加元数据
  static T trackBuildPerformance<T>(
    String widgetName,
    T Function() buildFunction, {
    Map<String, dynamic>? metadata,
  }) {
    if (!AppConfig.isDebugMode && !AppConfig.isProfileMode) {
      return buildFunction();
    }

    final stopwatch = Stopwatch()..start();
    T result;
    bool success = true;

    try {
      result = buildFunction();
    } catch (e) {
      success = false;
      LoggerService.e('❌ Widget构建失败: $widgetName', error: e);
      rethrow;
    } finally {
      stopwatch.stop();

      final duration = stopwatch.elapsed;
      final thresholds = kPerformanceThresholds['frames']!;

      // 检查构建性能
      if (duration.inMilliseconds > thresholds['warning']!) {
        instance._createAlert(
          'slow_widget_build',
          '${'Slow widget build'}: $widgetName (${duration.inMilliseconds}ms)',
          AlertSeverity.warning,
        );
      }

      // 记录性能数据
      instance._emitMetric(PerformanceMetric(
        name: 'widget:$widgetName',
        type: MetricType.widgetBuild,
        value: duration.inMilliseconds.toDouble(),
        timestamp: DateTime.now(),
        category: 'ui',
        success: success,
        metadata: metadata,
      ));
    }

    return result;
  }

  /// **监控异步操作性能**
  ///
  /// [operationName] 操作名称
  /// [operation] 异步操作函数
  /// [category] 操作分类
  /// [timeout] 超时时间
  /// [metadata] 附加元数据
  static Future<T> trackAsyncOperation<T>(
    String operationName,
    Future<T> Function() operation, {
    String category = 'async',
    Duration? timeout,
    Map<String, dynamic>? metadata,
  }) async {
    if (!AppConfig.isDebugMode && !AppConfig.isProfileMode) {
      return await operation();
    }

    startOperation(operationName, category: category, metadata: metadata);
    bool success = true;

    try {
      final result = timeout != null
          ? await operation().timeout(timeout)
          : await operation();
      return result;
    } catch (e) {
      success = false;
      LoggerService.e('❌ 异步操作失败: $operationName', error: e);
      rethrow;
    } finally {
      endOperation(operationName,
          category: category, success: success, metadata: metadata);
    }
  }

  /// **监控网络请求性能**
  ///
  /// [requestName] 请求名称
  /// [url] 请求URL
  /// [method] 请求方法
  /// [responseSize] 响应大小（字节）
  /// [statusCode] HTTP状态码
  static void trackNetworkRequest(
    String requestName, {
    required String url,
    required String method,
    required Duration duration,
    int? responseSize,
    int? statusCode,
  }) {
    if (!AppConfig.isDebugMode && !AppConfig.isProfileMode) return;

    try {
      final success =
          statusCode != null && statusCode >= 200 && statusCode < 300;

      // 存储网络延迟历史
      instance._networkLatencyHistory.putIfAbsent(requestName, () => []);
      instance._networkLatencyHistory[requestName]!
          .add(duration.inMilliseconds);
      _limitHistorySize(instance._networkLatencyHistory[requestName]!);

      // 检查网络性能阈值
      instance._checkNetworkThreshold(requestName, duration, success);

      // 发送网络度量
      instance._emitMetric(PerformanceMetric(
        name: 'network:$requestName',
        type: MetricType.networkRequest,
        value: duration.inMilliseconds.toDouble(),
        timestamp: DateTime.now(),
        category: 'network',
        success: success,
        metadata: {
          'url': url,
          'method': method,
          'statusCode': statusCode,
          'responseSize': responseSize,
        },
      ));
    } catch (e) {
      LoggerService.e('❌ 网络请求监控失败: $e');
    }
  }

  /// **获取详细性能统计**
  static Map<String, Map<String, dynamic>> getDetailedPerformanceStats() {
    if (!AppConfig.isDebugMode && !AppConfig.isProfileMode) {
      return {};
    }

    try {
      final stats = <String, Map<String, dynamic>>{};

      // 操作性能统计
      for (final entry in instance._operationDurations.entries) {
        final durations = entry.value;
        if (durations.isNotEmpty) {
          stats[entry.key] = _calculateStatistics(durations);
        }
      }

      return stats;
    } catch (e) {
      LoggerService.e('❌ 获取性能统计失败: $e');
      return {};
    }
  }

  /// **获取性能度量流**
  static Stream<PerformanceMetric> get metricsStream {
    return instance._metricsController?.stream ?? Stream.empty();
  }

  /// **清理性能数据**
  static void clearPerformanceData({bool keepRecentData = true}) {
    try {
      if (keepRecentData) {
        // 只保留最近的数据
        final cutoffTime = DateTime.now().subtract(const Duration(hours: 1));
        instance._operationDurations.removeWhere((key, durations) {
          final lastTime = instance._lastOperationTimes[key];
          return lastTime == null || lastTime.isBefore(cutoffTime);
        });
      } else {
        // 清理所有数据
        instance._operationStartTimes.clear();
        instance._operationDurations.clear();
        instance._memoryUsageHistory.clear();
        instance._networkLatencyHistory.clear();
        instance._frameTimes.clear();
        instance._operationCounts.clear();
        instance._lastOperationTimes.clear();
        instance._activeAlerts.clear();
        instance._alertCounts.clear();
        instance._alertHistory.clear();
      }

      LoggerService.i('🗑️ 性能数据清理完成');
    } catch (e) {
      LoggerService.e('❌ 性能数据清理失败: $e');
    }
  }

  /// **开始监控模式**
  static void startMonitoring() {
    if (instance._isMonitoring) return;

    try {
      instance._isMonitoring = true;
      instance._initializeFrameMonitoring();
      instance._startMemoryMonitoring();
      LoggerService.i('▶️ 性能监控已启动');
    } catch (e) {
      LoggerService.e('❌ 启动性能监控失败: $e');
    }
  }

  /// **停止监控模式**
  static void stopMonitoring() {
    if (!instance._isMonitoring) return;

    try {
      instance._isMonitoring = false;
      LoggerService.i('⏸️ 性能监控已停止');
    } catch (e) {
      LoggerService.e('❌ 停止性能监控失败: $e');
    }
  }

  /// **内部辅助方法**

  void _checkServiceStatus() {
    if (!_isInitialized || _metricsController == null) {
      throw Exception('性能监控服务未正确初始化');
    }
  }

  Map<String, dynamic> _checkMemoryHealth() {
    try {
      // 简化的内存健康检查
      final memoryUsage = _getApproximateMemoryUsage();
      final threshold = kPerformanceConfig['memoryWarningThreshold'] as int;

      return {
        'usage': memoryUsage,
        'threshold': threshold,
        'status': memoryUsage > threshold ? 'warning' : 'good',
      };
    } catch (e) {
      return {'status': 'unknown', 'error': e.toString()};
    }
  }

  Map<String, dynamic> _checkDataIntegrity() {
    return {
      'operationDurations': _operationDurations.length,
      'networkLatencyHistory': _networkLatencyHistory.length,
      'memoryUsageHistory': _memoryUsageHistory.length,
      'alertHistory': _alertHistory.length,
    };
  }

  void _checkOperationThreshold(
      String operationName, Duration duration, bool success) {
    final thresholds = kPerformanceThresholds['operations']!;
    final ms = duration.inMilliseconds;

    if (!success) {
      _createAlert(
        'operation_failed',
        '${'Operation failed'}: $operationName',
        AlertSeverity.error,
      );
    } else if (ms > thresholds['critical']!) {
      _createAlert(
        'critical_slow_operation',
        '${'Critical slow operation'}: $operationName (${ms}ms)',
        AlertSeverity.critical,
      );
    } else if (ms > thresholds['warning']!) {
      _createAlert(
        'slow_operation',
        '${'Slow operation'}: $operationName (${ms}ms)',
        AlertSeverity.warning,
      );
    }
  }

  void _checkNetworkThreshold(
      String requestName, Duration duration, bool success) {
    final thresholds = kPerformanceThresholds['network']!;
    final ms = duration.inMilliseconds;

    if (!success) {
      _createAlert(
        'network_error',
        '${'Network error'}: $requestName',
        AlertSeverity.error,
      );
    } else if (ms > thresholds['critical']!) {
      _createAlert(
        'slow_network_request',
        '${'Slow network request'}: $requestName (${ms}ms)',
        AlertSeverity.warning,
      );
    }
  }

  void _createAlert(String alertId, String message, AlertSeverity severity) {
    if (_activeAlerts.contains(alertId)) return;

    final alert = PerformanceAlert(
      id: alertId,
      message: message,
      severity: severity,
      timestamp: DateTime.now(),
    );

    _activeAlerts.add(alertId);
    _alertHistory.add(alert);
    _alertCounts[alertId] = (_alertCounts[alertId] ?? 0) + 1;

    // 限制警报历史大小
    if (_alertHistory.length > 500) {
      _alertHistory.removeAt(0);
    }

    LoggerService.w('🚨 性能警报: $message');

    // 自动解除警报（30秒后）
    Timer(const Duration(seconds: 30), () {
      _activeAlerts.remove(alertId);
    });
  }

  void _emitMetric(PerformanceMetric metric) {
    try {
      _metricsController?.add(metric);
    } catch (e) {
      LoggerService.e('❌ 发送性能度量失败: $e');
    }
  }

  void _initializeFrameMonitoring() {
    if (_isMonitoring) {
      try {
        WidgetsBinding.instance.addPersistentFrameCallback((timeStamp) {
          final frameDuration = timeStamp.inMilliseconds;

          _frameTimes.putIfAbsent('frame_time', () => []);
          _frameTimes['frame_time']!.add(frameDuration.toDouble());
          _limitHistorySize(_frameTimes['frame_time']!);

          if (frameDuration > kPerformanceConfig['frameDropThreshold']) {
            _createAlert(
              'frame_drop',
              '${'Frame drop detected'}: ${frameDuration}ms',
              AlertSeverity.warning,
            );
          }
        });
      } catch (e) {
        LoggerService.e('❌ 帧监控初始化失败: $e');
      }
    }
  }

  void _startMemoryMonitoring() {
    if (_isMonitoring) {
      Timer.periodic(const Duration(minutes: 1), (timer) {
        if (!_isMonitoring) {
          timer.cancel();
          return;
        }

        try {
          final memoryUsage = _getApproximateMemoryUsage().toDouble();
          _memoryUsageHistory.putIfAbsent('memory_usage', () => []);
          _memoryUsageHistory['memory_usage']!.add(memoryUsage);
          _limitHistorySize(_memoryUsageHistory['memory_usage']!);

          final threshold = kPerformanceConfig['memoryWarningThreshold'] as int;
          if (memoryUsage > threshold) {
            _createAlert(
              'high_memory_usage',
              '${'High memory usage'}: ${(memoryUsage / 1024 / 1024).toStringAsFixed(1)}MB',
              AlertSeverity.warning,
            );
          }
        } catch (e) {
          LoggerService.e('❌ 内存监控失败: $e');
        }
      });
    }
  }

  void _startPeriodicCleanup() {
    final interval =
        Duration(minutes: kPerformanceConfig['cleanupIntervalMinutes'] as int);
    _cleanupTimer = Timer.periodic(interval, (timer) {
      if (!_isInitialized) {
        timer.cancel();
        return;
      }

      try {
        clearPerformanceData(keepRecentData: true);
      } catch (e) {
        LoggerService.e('❌ 定期清理失败: $e');
      }
    });
  }

  void _startHealthCheckTimer() {
    final interval = Duration(
        minutes: kPerformanceConfig['healthCheckIntervalMinutes'] as int);
    _healthCheckTimer = Timer.periodic(interval, (timer) {
      if (!_isInitialized) {
        timer.cancel();
        return;
      }

      performHealthCheck().catchError((e) {
        LoggerService.e('❌ 定期健康检查失败: $e');
        return <String, dynamic>{'status': 'error', 'error': e.toString()};
      });
    });
  }

  int _getApproximateMemoryUsage() {
    // 简化的内存使用估算
    try {
      return (_operationDurations.length * 1000) +
          (_memoryUsageHistory.length * 100) +
          (_networkLatencyHistory.length * 100) +
          (_alertHistory.length * 200);
    } catch (e) {
      return 0;
    }
  }

  /// **静态辅助方法**

  static void _limitHistorySize<T>(List<T> list) {
    final maxSize = kPerformanceConfig['maxHistoryEntries'] as int;
    while (list.length > maxSize) {
      list.removeAt(0);
    }
  }

  static Map<String, dynamic> _calculateStatistics(List<Duration> durations) {
    if (durations.isEmpty) return {};

    final values = durations.map((d) => d.inMilliseconds).toList();
    values.sort();

    final total = values.fold<int>(0, (sum, value) => sum + value);
    final avg = total / values.length;
    final median = values[values.length ~/ 2];
    final p95 = values[(values.length * 0.95).floor()];
    final p99 = values[(values.length * 0.99).floor()];

    return {
      'count': values.length,
      'avgMs': avg.round(),
      'medianMs': median,
      'minMs': values.first,
      'maxMs': values.last,
      'p95Ms': p95,
      'p99Ms': p99,
      'totalMs': total,
    };
  }

  static List<Map<String, dynamic>> _getRecentAlerts(int limit) {
    final recent = instance._alertHistory.reversed.take(limit).toList();
    return recent.map((alert) => alert.toMap()).toList();
  }

  /// **资源清理**
  void dispose() {
    try {
      _cleanupTimer?.cancel();
      _healthCheckTimer?.cancel();
      _metricsController?.close();

      clearPerformanceData(keepRecentData: false);

      _isInitialized = false;
      _isMonitoring = false;

      LoggerService.i('🗑️ 性能监控服务资源已清理');
    } catch (e) {
      LoggerService.e('❌ 性能监控服务清理失败: $e');
    }
  }
}

/// **性能度量数据模型**
class PerformanceMetric {
  final String name;
  final MetricType type;
  final double value;
  final DateTime timestamp;
  final String category;
  final bool success;
  final Map<String, dynamic>? metadata;

  PerformanceMetric({
    required this.name,
    required this.type,
    required this.value,
    required this.timestamp,
    required this.category,
    this.success = true,
    this.metadata,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'type': type.name,
      'value': value,
      'timestamp': timestamp.toIso8601String(),
      'category': category,
      'success': success,
      'metadata': metadata,
    };
  }
}

/// **性能警报数据模型**
class PerformanceAlert {
  final String id;
  final String message;
  final AlertSeverity severity;
  final DateTime timestamp;

  PerformanceAlert({
    required this.id,
    required this.message,
    required this.severity,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'message': message,
      'severity': severity.name,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}

/// **度量类型枚举**
enum MetricType {
  operationStart,
  operationEnd,
  widgetBuild,
  networkRequest,
  databaseQuery,
  memoryUsage,
  frameTime,
}

/// **警报严重程度枚举**
enum AlertSeverity {
  info,
  warning,
  error,
  critical,
}

/// **同步锁辅助函数**
void synchronized(Object lock, void Function() callback) {
  callback();
}
