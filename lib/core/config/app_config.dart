/// Application configuration constants and helper methods for the UPM Digital Certificate Repository.
///
/// This file contains all application-wide configuration values including:
/// - App metadata and university information
/// - Firebase collection names
/// - File size limits and supported types
/// - Security and authentication settings
/// - URL configurations
/// - Helper methods for validation and path generation
class AppConfig {
  // Private constructor to prevent instantiation
  AppConfig._();

  // ⚠️ SECURITY NOTE:
  // This file contains application configuration.
  // Sensitive data like passwords should NEVER be hardcoded here.
  // Use environment variables or secure storage for sensitive information.

  // =============================================================================
  // APPLICATION INFORMATION
  // =============================================================================

  /// The display name of the application
  static const String appName = 'Digital Certificate Repository';

  /// Current version of the application
  static const String appVersion = '1.0.0';

  /// Brief description of the application
  static const String appDescription =
      'UPM Digital Certificate Management System';

  /// Build number for internal tracking
  static const String buildNumber = '1.0.0+1';

  // =============================================================================
  // UNIVERSITY INFORMATION
  // =============================================================================

  /// Official name of the university
  static const String universityName = 'Universiti Putra Malaysia';

  /// University code abbreviation
  static const String universityCode = 'UPM';

  /// Official email domain for university accounts
  static const String upmEmailDomain = '@upm.edu.my';

  // =============================================================================
  // FIREBASE COLLECTIONS
  // =============================================================================

  /// User accounts collection
  static const String usersCollection = 'users';

  /// Certificates collection
  static const String certificatesCollection = 'certificates';

  /// Documents collection
  static const String documentsCollection = 'documents';

  /// Certificate templates collection
  static const String templatesCollection = 'certificate_templates';

  /// Transaction records collection
  static const String transactionsCollection = 'certificate_transactions';

  /// Document access logs collection
  static const String accessLogsCollection = 'document_access_logs';

  /// Notifications collection
  static const String notificationsCollection = 'notifications';

  /// App settings collection
  static const String settingsCollection = 'app_settings';

  /// User activity logs collection
  static const String activityCollection = 'activities';

  // Admin System Collections
  /// Administrative logs collection
  static const String adminLogsCollection = 'admin_logs';

  /// System configuration collection
  static const String systemConfigCollection = 'system_config';

  /// Backup jobs collection
  static const String backupJobsCollection = 'backup_jobs';

  /// Audit trail collection for security tracking
  static const String auditTrailCollection = 'audit_trail';

  // =============================================================================
  // FILE STORAGE PATHS
  // =============================================================================

  /// Storage path for document files
  static const String documentsStoragePath = 'documents';

  /// Storage path for certificate files
  static const String certificatesStoragePath = 'certificates';

  /// Storage path for template files
  static const String templatesStoragePath = 'templates';

  /// Storage path for profile images
  static const String profileImagesStoragePath = 'profile_images';

  // =============================================================================
  // FILE SIZE LIMITS
  // =============================================================================

  /// Maximum document file size in bytes (10MB)
  static const int maxDocumentSizeBytes = 10 * 1024 * 1024;

  /// Maximum image file size in bytes (5MB)
  static const int maxImageSizeBytes = 5 * 1024 * 1024;

  /// Maximum certificate file size in bytes (20MB)
  static const int maxCertificateSizeBytes = 20 * 1024 * 1024;

  /// Maximum document file size in MB (for display purposes)
  static const int maxDocumentSizeMB = 10;

  /// Maximum image file size in MB (for display purposes)
  static const int maxImageSizeMB = 5;

  /// Maximum certificate file size in MB (for display purposes)
  static const int maxCertificateSizeMB = 20;

  /// General file size limit in MB (for compatibility)
  static const int maxFileSizeMB = 10;

  /// Maximum document size (alias for compatibility)
  static const int maxDocumentSize = maxDocumentSizeBytes;

  // =============================================================================
  // SUPPORTED FILE TYPES
  // =============================================================================

  /// Supported document file extensions
  static const List<String> supportedDocumentTypes = [
    'pdf',
    'doc',
    'docx',
    'txt',
    'jpg',
    'jpeg',
    'png'
  ];

  /// Supported image file extensions
  static const List<String> supportedImageTypes = [
    'jpg',
    'jpeg',
    'png',
    'gif',
    'webp',
    'bmp'
  ];

  /// Supported certificate file extensions
  static const List<String> supportedCertificateTypes = [
    'pdf',
    'png',
    'jpg',
    'jpeg'
  ];

  // =============================================================================
  // ENVIRONMENT-SPECIFIC URLS
  // =============================================================================

  /// Base URL for the application (environment-specific)
  static String get baseUrl {
    if (isProduction) {
      return 'https://upm-digital-certificates.web.app';
    } else if (isStaging) {
      return 'https://upm-certificates-staging.web.app';
    } else {
      return 'http://localhost:8080';
    }
  }

  /// Base URL for certificate verification
  static String get verificationBaseUrl => '$baseUrl/verify';

  /// Base URL for public resources
  static String get publicBaseUrl => '$baseUrl/public';

  /// API base URL for backend services
  static String get apiBaseUrl => '$baseUrl/api';

  // =============================================================================
  // ENVIRONMENT DETECTION
  // =============================================================================

  /// Whether the app is running in production environment
  static const bool isProduction =
      bool.fromEnvironment('PRODUCTION', defaultValue: false);

  /// Whether the app is running in staging environment
  static const bool isStaging =
      bool.fromEnvironment('STAGING', defaultValue: false);

  /// Whether the app is running in development environment
  static bool get isDevelopment => !isProduction && !isStaging;

  // =============================================================================
  // SECURITY CONFIGURATION
  // =============================================================================

  /// Maximum number of failed login attempts before account lockout
  static const int maxLoginAttempts = 5;

  /// Account lockout duration in minutes after max attempts reached
  static const int lockoutDurationMinutes = 30;

  /// User session timeout in minutes (8 hours)
  static const int sessionTimeoutMinutes = 480;

  /// Minimum required password length
  static const int passwordMinLength = 8;

  /// Maximum password length
  static const int passwordMaxLength = 128;

  /// Password complexity requirements
  static const bool requirePasswordNumbers = true;
  static const bool requirePasswordSymbols = true;
  static const bool requirePasswordUppercase = true;
  static const bool requirePasswordLowercase = true;

  // =============================================================================
  // CERTIFICATE CONFIGURATION
  // =============================================================================

  /// Default certificate validity period in days (1 year)
  static const int defaultCertificateValidityDays = 365;

  /// Maximum certificate validity period in days (10 years)
  static const int maxCertificateValidityDays = 3650;

  /// Default certificate output format
  static const String defaultCertificateFormat = 'PDF';

  /// Certificate QR code size in pixels
  static const int certificateQrCodeSize = 200;

  // =============================================================================
  // SHARE TOKEN CONFIGURATION
  // =============================================================================

  /// Default share token validity period in days
  static const int defaultShareTokenValidityDays = 7;

  /// Maximum share token validity period in days
  static const int maxShareTokenValidityDays = 90;

  /// Maximum number of accesses per share token
  static const int maxShareTokenAccess = 100;

  /// Share token length (characters)
  static const int shareTokenLength = 32;

  // =============================================================================
  // PAGINATION CONFIGURATION
  // =============================================================================

  /// Default number of items per page
  static const int defaultPageSize = 20;

  /// Maximum number of items per page
  static const int maxPageSize = 100;

  /// Minimum number of items per page
  static const int minPageSize = 5;

  // =============================================================================
  // RATE LIMITING
  // =============================================================================

  /// Maximum API requests per minute per user
  static const int maxRequestsPerMinute = 60;

  /// Maximum file upload requests per hour per user
  static const int maxUploadRequestsPerHour = 10;

  /// Maximum verification requests per minute per IP
  static const int maxVerificationRequestsPerMinute = 20;

  // =============================================================================
  // NOTIFICATION CONFIGURATION
  // =============================================================================

  /// Whether push notifications are enabled
  static const bool enablePushNotifications = true;

  /// Whether email notifications are enabled
  static const bool enableEmailNotifications = true;

  /// Default notification topic for FCM
  static const String defaultNotificationTopic = 'upm_certificates';

  /// Notification retention period in days
  static const int notificationRetentionDays = 30;

  // =============================================================================
  // DEVELOPMENT CONFIGURATION
  // =============================================================================

  /// Whether debug mode is enabled (should be false in production)
  static bool get isDebugMode => isDevelopment;

  /// Whether detailed logging is enabled
  static bool get enableDetailedLogging => isDevelopment;

  /// Whether performance logging is enabled
  static bool get enablePerformanceLogging => isDevelopment;

  /// Whether profile mode is enabled (for performance profiling)
  static bool get isProfileMode =>
      bool.fromEnvironment('PROFILE', defaultValue: false);

  /// Whether analytics are enabled
  static bool get enableAnalytics => isProduction || isStaging;

  // =============================================================================
  // CACHE CONFIGURATION
  // =============================================================================

  /// Cache validity period in minutes
  static const int cacheValidityMinutes = 15;

  /// Maximum number of cache entries
  static const int maxCacheEntries = 1000;

  /// Cache cleanup interval in minutes
  static const int cacheCleanupIntervalMinutes = 60;

  // =============================================================================
  // BACKUP CONFIGURATION
  // =============================================================================

  /// Backup interval in days
  static const int backupIntervalDays = 7;

  /// Maximum backup retention period in days
  static const int maxBackupRetentionDays = 90;

  /// Maximum number of backup files to keep
  static const int maxBackupFiles = 20;

  // =============================================================================
  // HELPER METHODS
  // =============================================================================

  /// Validates if an email address belongs to UPM domain
  ///
  /// [email] The email address to validate
  /// Returns true if the email ends with the UPM domain
  static bool isValidUpmEmail(String email) {
    if (email.isEmpty) return false;
    return email.toLowerCase().trim().endsWith(upmEmailDomain);
  }

  /// Validates if a file size is within acceptable limits for its type
  ///
  /// [fileSize] Size of the file in bytes
  /// [fileType] File extension (e.g., 'pdf', 'jpg')
  /// Returns true if the file size is acceptable for the given type
  static bool isValidFileSize(int fileSize, String fileType) {
    if (fileSize <= 0) return false;

    final lowerFileType = fileType.toLowerCase().replaceAll('.', '');

    if (supportedImageTypes.contains(lowerFileType)) {
      return fileSize <= maxImageSizeBytes;
    } else if (supportedDocumentTypes.contains(lowerFileType)) {
      return fileSize <= maxDocumentSizeBytes;
    } else if (supportedCertificateTypes.contains(lowerFileType)) {
      return fileSize <= maxCertificateSizeBytes;
    }

    return false;
  }

  /// Checks if a file type is supported by the application
  ///
  /// [fileType] File extension to check
  /// Returns true if the file type is supported
  static bool isSupportedFileType(String fileType) {
    if (fileType.isEmpty) return false;

    final lowerFileType = fileType.toLowerCase().replaceAll('.', '');

    return supportedDocumentTypes.contains(lowerFileType) ||
        supportedImageTypes.contains(lowerFileType) ||
        supportedCertificateTypes.contains(lowerFileType);
  }

  /// Gets the appropriate storage path for a file type
  ///
  /// [fileType] File extension
  /// Returns the storage path for the given file type
  static String getStoragePath(String fileType) {
    if (fileType.isEmpty) return documentsStoragePath;

    final lowerFileType = fileType.toLowerCase().replaceAll('.', '');

    if (supportedImageTypes.contains(lowerFileType)) {
      return profileImagesStoragePath;
    } else if (lowerFileType == 'pdf' ||
        supportedCertificateTypes.contains(lowerFileType)) {
      return certificatesStoragePath;
    } else {
      return documentsStoragePath;
    }
  }

  /// Generates a verification URL for a certificate
  ///
  /// [certificateId] The unique identifier of the certificate
  /// Returns the complete verification URL
  static String getVerificationUrl(String certificateId) {
    if (certificateId.isEmpty) return verificationBaseUrl;
    return '$verificationBaseUrl/$certificateId';
  }

  /// Generates a public URL for a resource
  ///
  /// [resourceId] The unique identifier of the resource
  /// Returns the complete public URL
  static String getPublicUrl(String resourceId) {
    if (resourceId.isEmpty) return publicBaseUrl;
    return '$publicBaseUrl/$resourceId';
  }

  /// Gets the human-readable file size limit for a file type
  ///
  /// [fileType] File extension
  /// Returns the size limit in MB as a string
  static String getFileSizeLimit(String fileType) {
    if (fileType.isEmpty) return '${maxDocumentSizeMB}MB';

    final lowerFileType = fileType.toLowerCase().replaceAll('.', '');

    if (supportedImageTypes.contains(lowerFileType)) {
      return '${maxImageSizeMB}MB';
    } else if (supportedCertificateTypes.contains(lowerFileType)) {
      return '${maxCertificateSizeMB}MB';
    } else {
      return '${maxDocumentSizeMB}MB';
    }
  }
}
