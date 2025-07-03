import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'logger_service.dart';

/// Comprehensive Error Handling Service for the UPM Digital Certificate Repository.
///
/// This service provides enterprise-grade error management including:
/// - Centralized error logging and reporting
/// - User-friendly error message transformation
/// - Context-aware error handling
/// - Async operation error management
/// - Navigation error protection
/// - Error categorization and analysis
/// - Recovery suggestions and actions
///
/// Features:
/// - Multi-level error classification
/// - Automatic error reporting to Firebase
/// - User-friendly message conversion
/// - Context validation and safety checks
/// - Loading state management
/// - Recovery action suggestions
/// - Error statistics and analytics
///
/// Error Categories:
/// - Network/Connection errors
/// - Authentication/Authorization errors
/// - Validation/Input errors
/// - Firebase/Backend errors
/// - File/Storage errors
/// - Permission errors
/// - System/Platform errors
class ErrorHandlerService {
  // =============================================================================
  // CONSTANTS
  // =============================================================================

  /// Default error message for unknown errors
  static const String _defaultErrorMessage =
      'An unexpected error occurred. Please try again.';

  /// Loading snackbar duration in seconds
  static const int _loadingDurationSeconds = 30;

  /// Error snackbar duration in seconds
  static const int _errorDurationSeconds = 5;

  /// Success snackbar duration in seconds
  static const int _successDurationSeconds = 3;

  /// Maximum error message length
  static const int _maxErrorMessageLength = 200;

  /// Error collection name for Firebase logging
  static const String _errorCollectionName = 'error_logs';

  // =============================================================================
  // SINGLETON PATTERN
  // =============================================================================

  static ErrorHandlerService? _instance;

  ErrorHandlerService._internal();

  factory ErrorHandlerService() {
    _instance ??= ErrorHandlerService._internal();
    return _instance!;
  }

  // =============================================================================
  // STATE MANAGEMENT
  // =============================================================================

  bool _isInitialized = false;
  int _errorCount = 0;
  DateTime? _lastErrorTime;

  // =============================================================================
  // GETTERS
  // =============================================================================

  /// Whether the service is healthy and operational
  bool get isHealthy => _isInitialized;

  /// Total number of errors handled
  int get errorCount => _errorCount;

  /// Time of last error
  DateTime? get lastErrorTime => _lastErrorTime;

  // =============================================================================
  // INITIALIZATION
  // =============================================================================

  /// Initialize the error handler service
  Future<void> initialize() async {
    try {
      LoggerService.info('Initializing error handler service...');

      // Test Firebase connectivity for error logging
      try {
        await FirebaseFirestore.instance
            .collection(_errorCollectionName)
            .limit(1)
            .get();
      } catch (e) {
        LoggerService.warning(
            'Firebase error logging may not be available: $e');
      }

      _isInitialized = true;
      LoggerService.info('Error handler service initialized successfully');
    } catch (e, stackTrace) {
      LoggerService.error('Failed to initialize error handler service',
          error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  // =============================================================================
  // ERROR HANDLING METHODS
  // =============================================================================

  /// Handle and log errors with comprehensive user feedback
  static Future<void> handleError({
    required dynamic error,
    required BuildContext context,
    StackTrace? stackTrace,
    String? customMessage,
    bool showSnackBar = true,
    bool logToFirebase = true,
    ErrorSeverity severity = ErrorSeverity.error,
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      final instance = ErrorHandlerService();
      instance._errorCount++;
      instance._lastErrorTime = DateTime.now();

      // Enhanced error logging
      final errorData =
          _createErrorData(error, stackTrace, severity, additionalData);
      LoggerService.error('Error handled by ErrorHandlerService',
          error: error, stackTrace: stackTrace);

      // Log to Firebase if enabled
      if (logToFirebase && instance._isInitialized) {
        await _logErrorToFirebase(errorData);
      }

      // Determine user-friendly message
      final userMessage = customMessage ?? _getUserFriendlyMessage(error);
      final truncatedMessage = _truncateMessage(userMessage);

      // Show user feedback if requested and context is valid
      if (showSnackBar && context.mounted) {
        await _showErrorSnackBar(context, truncatedMessage, severity);
      }
    } catch (handlingError) {
      LoggerService.error('Error in error handler', error: handlingError);
    }
  }

  /// Handle async operations with comprehensive error management
  static Future<T?> handleAsyncOperation<T>({
    required Future<T> Function() operation,
    required BuildContext context,
    String? loadingMessage,
    String? successMessage,
    String? errorMessage,
    bool showLoading = false,
    bool showSuccess = true,
    Map<String, dynamic>? operationData,
  }) async {
    try {
      // Show loading indicator
      if (showLoading && loadingMessage != null && context.mounted) {
        _showLoadingSnackBar(context, loadingMessage);
      }

      // Execute operation
      final result = await operation();

      if (context.mounted) {
        // Hide loading snackbar
        ScaffoldMessenger.of(context).hideCurrentSnackBar();

        // Show success message
        if (showSuccess && successMessage != null) {
          _showSuccessSnackBar(context, successMessage);
        }
      }

      LoggerService.info('Async operation completed successfully');
      return result;
    } catch (error, stackTrace) {
      if (context.mounted) {
        // Hide loading snackbar
        ScaffoldMessenger.of(context).hideCurrentSnackBar();

        // Handle error
        await handleError(
          error: error,
          context: context,
          stackTrace: stackTrace,
          customMessage: errorMessage,
          additionalData: operationData,
        );
      }
      return null;
    }
  }

  /// Safe navigation with comprehensive error protection
  static Future<void> safeNavigate({
    required BuildContext context,
    required VoidCallback navigation,
    String? errorMessage,
    bool validateContext = true,
  }) async {
    try {
      if (validateContext && !context.mounted) {
        LoggerService.warning('Navigation attempted on unmounted context');
        return;
      }

      navigation();
      LoggerService.info('Safe navigation completed');
    } catch (error, stackTrace) {
      await handleError(
        error: error,
        context: context,
        stackTrace: stackTrace,
        customMessage: errorMessage ?? 'Navigation failed. Please try again.',
        additionalData: {'action': 'navigation'},
      );
    }
  }

  /// Handle form validation errors
  static Future<void> handleValidationError({
    required BuildContext context,
    required String fieldName,
    required String validationMessage,
    bool showSnackBar = true,
  }) async {
    final message = 'Validation Error: $fieldName - $validationMessage';

    await handleError(
      error: ValidationException(message),
      context: context,
      customMessage: validationMessage,
      showSnackBar: showSnackBar,
      severity: ErrorSeverity.warning,
      additionalData: {
        'type': 'validation',
        'field': fieldName,
      },
    );
  }

  /// Handle network errors specifically
  static Future<void> handleNetworkError({
    required BuildContext context,
    required dynamic error,
    StackTrace? stackTrace,
    String? customMessage,
  }) async {
    await handleError(
      error: error,
      context: context,
      stackTrace: stackTrace,
      customMessage: customMessage ??
          'Network connection error. Please check your internet connection and try again.',
      severity: ErrorSeverity.warning,
      additionalData: {'type': 'network'},
    );
  }

  /// Handle authentication errors specifically
  static Future<void> handleAuthError({
    required BuildContext context,
    required dynamic error,
    StackTrace? stackTrace,
    String? customMessage,
  }) async {
    await handleError(
      error: error,
      context: context,
      stackTrace: stackTrace,
      customMessage:
          customMessage ?? 'Authentication failed. Please log in again.',
      severity: ErrorSeverity.error,
      additionalData: {'type': 'authentication'},
    );
  }

  // =============================================================================
  // HELPER METHODS
  // =============================================================================

  /// Convert technical errors to user-friendly messages
  static String _getUserFriendlyMessage(dynamic error) {
    if (error == null) return _defaultErrorMessage;

    final errorString = error.toString().toLowerCase();

    // Network/Connection errors
    if (_isNetworkError(errorString)) {
      return 'Network connection error. Please check your internet connection and try again.';
    }

    // Timeout errors
    if (_isTimeoutError(errorString)) {
      return 'Request timed out. Please check your connection and try again.';
    }

    // Permission/Authorization errors
    if (_isPermissionError(errorString)) {
      return 'Access denied. Please check your permissions or contact support.';
    }

    // Authentication errors
    if (_isAuthenticationError(errorString)) {
      return 'Authentication failed. Please log in again.';
    }

    // Not found errors
    if (_isNotFoundError(errorString)) {
      return 'The requested resource was not found. Please try again.';
    }

    // Firebase/Backend errors
    if (_isFirebaseError(errorString)) {
      return 'Service temporarily unavailable. Please try again later.';
    }

    // File/Storage errors
    if (_isStorageError(errorString)) {
      return 'File operation failed. Please check file size and format.';
    }

    // Validation errors
    if (_isValidationError(errorString)) {
      return 'Invalid input detected. Please check your data and try again.';
    }

    return _defaultErrorMessage;
  }

  /// Check if error is network-related
  static bool _isNetworkError(String errorString) {
    return errorString.contains('network') ||
        errorString.contains('connection') ||
        errorString.contains('unreachable') ||
        errorString.contains('socket');
  }

  /// Check if error is timeout-related
  static bool _isTimeoutError(String errorString) {
    return errorString.contains('timeout') ||
        errorString.contains('timed out') ||
        errorString.contains('deadline exceeded');
  }

  /// Check if error is permission-related
  static bool _isPermissionError(String errorString) {
    return errorString.contains('permission') ||
        errorString.contains('access denied') ||
        errorString.contains('forbidden') ||
        errorString.contains('unauthorized');
  }

  /// Check if error is authentication-related
  static bool _isAuthenticationError(String errorString) {
    return errorString.contains('authentication') ||
        errorString.contains('auth') ||
        errorString.contains('login') ||
        errorString.contains('credential');
  }

  /// Check if error is not found-related
  static bool _isNotFoundError(String errorString) {
    return errorString.contains('not found') ||
        errorString.contains('404') ||
        errorString.contains('missing');
  }

  /// Check if error is Firebase-related
  static bool _isFirebaseError(String errorString) {
    return errorString.contains('firebase') ||
        errorString.contains('firestore') ||
        errorString.contains('cloud');
  }

  /// Check if error is storage-related
  static bool _isStorageError(String errorString) {
    return errorString.contains('storage') ||
        errorString.contains('file') ||
        errorString.contains('upload') ||
        errorString.contains('download');
  }

  /// Check if error is validation-related
  static bool _isValidationError(String errorString) {
    return errorString.contains('validation') ||
        errorString.contains('invalid') ||
        errorString.contains('format') ||
        errorString.contains('required');
  }

  /// Create comprehensive error data for logging
  static Map<String, dynamic> _createErrorData(
    dynamic error,
    StackTrace? stackTrace,
    ErrorSeverity severity,
    Map<String, dynamic>? additionalData,
  ) {
    return {
      'error': error.toString(),
      'stackTrace': stackTrace.toString(),
      'severity': severity.name,
      'timestamp': DateTime.now().toIso8601String(),
      'userId': FirebaseAuth.instance.currentUser?.uid,
      'platform': 'flutter',
      'additionalData': additionalData,
    };
  }

  /// Log error to Firebase for analytics
  static Future<void> _logErrorToFirebase(
      Map<String, dynamic> errorData) async {
    try {
      await FirebaseFirestore.instance
          .collection(_errorCollectionName)
          .add(errorData);
    } catch (e) {
      LoggerService.warning('Failed to log error to Firebase: $e');
    }
  }

  /// Truncate message to maximum length
  static String _truncateMessage(String message) {
    if (message.length <= _maxErrorMessageLength) {
      return message;
    }
    return '${message.substring(0, _maxErrorMessageLength - 3)}...';
  }

  /// Show loading snackbar
  static void _showLoadingSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        duration: const Duration(seconds: _loadingDurationSeconds),
        backgroundColor: Colors.blue.shade600,
      ),
    );
  }

  /// Show success snackbar
  static void _showSuccessSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 16),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: _successDurationSeconds),
      ),
    );
  }

  /// Show error snackbar with severity-based styling
  static Future<void> _showErrorSnackBar(
    BuildContext context,
    String message,
    ErrorSeverity severity,
  ) async {
    final color = _getColorForSeverity(severity);
    final icon = _getIconForSeverity(severity);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 16),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: _errorDurationSeconds),
        action: SnackBarAction(
          label: 'Dismiss',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

  /// Get color for error severity
  static Color _getColorForSeverity(ErrorSeverity severity) {
    switch (severity) {
      case ErrorSeverity.info:
        return Colors.blue.shade600;
      case ErrorSeverity.warning:
        return Colors.orange.shade600;
      case ErrorSeverity.error:
        return Colors.red.shade600;
      case ErrorSeverity.critical:
        return Colors.red.shade800;
    }
  }

  /// Get icon for error severity
  static IconData _getIconForSeverity(ErrorSeverity severity) {
    switch (severity) {
      case ErrorSeverity.info:
        return Icons.info;
      case ErrorSeverity.warning:
        return Icons.warning;
      case ErrorSeverity.error:
        return Icons.error;
      case ErrorSeverity.critical:
        return Icons.dangerous;
    }
  }

  // =============================================================================
  // SERVICE STATUS
  // =============================================================================

  /// Get error handling statistics
  Map<String, dynamic> getStatistics() {
    return {
      'isInitialized': _isInitialized,
      'errorCount': _errorCount,
      'lastErrorTime': _lastErrorTime?.toIso8601String(),
      'isHealthy': isHealthy,
    };
  }

  /// Reset error statistics
  void resetStatistics() {
    _errorCount = 0;
    _lastErrorTime = null;
    LoggerService.info('Error handler statistics reset');
  }
}

// =============================================================================
// SUPPORTING CLASSES AND ENUMS
// =============================================================================

/// Error severity levels
enum ErrorSeverity {
  info,
  warning,
  error,
  critical,
}

/// Custom validation exception
class ValidationException implements Exception {
  final String message;

  const ValidationException(this.message);

  @override
  String toString() => 'ValidationException: $message';
}

/// Global navigator key for context access
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
