import 'package:flutter/foundation.dart';
import 'app_config.dart';

/// Security configuration and validation utilities for the UPM Digital Certificate Repository.
///
/// This class provides comprehensive security settings including:
/// - Network security headers and policies
/// - Password validation and requirements
/// - File upload security restrictions
/// - Input sanitization and validation
/// - Domain and URL security checks
/// - Security audit and monitoring tools
///
/// All methods are static and the class cannot be instantiated.
class SecurityConfig {
  // Private constructor to prevent instantiation
  SecurityConfig._();

  // =============================================================================
  // NETWORK SECURITY HEADERS
  // =============================================================================

  /// HTTP security headers for enhanced web security
  ///
  /// These headers help prevent various attacks including XSS, clickjacking,
  /// MIME sniffing, and enforce secure transport.
  static const Map<String, String> securityHeaders = {
    // Content Security Policy - prevents XSS and injection attacks
    'Content-Security-Policy': "default-src 'self'; "
        "script-src 'self' 'unsafe-inline' 'unsafe-eval' *.googleapis.com *.gstatic.com; "
        "style-src 'self' 'unsafe-inline' *.googleapis.com *.gstatic.com; "
        "img-src 'self' data: *.googleapis.com *.gstatic.com *.firebaseapp.com; "
        "font-src 'self' *.googleapis.com *.gstatic.com; "
        "connect-src 'self' *.googleapis.com *.firebaseio.com *.firebaseapp.com;",

    // Prevent MIME type sniffing
    'X-Content-Type-Options': 'nosniff',

    // Prevent embedding in frames
    'X-Frame-Options': 'DENY',

    // Enable XSS protection
    'X-XSS-Protection': '1; mode=block',

    // Force HTTPS connections
    'Strict-Transport-Security': 'max-age=31536000; includeSubDomains; preload',

    // Control referrer information
    'Referrer-Policy': 'strict-origin-when-cross-origin',

    // Control browser permissions
    'Permissions-Policy':
        'geolocation=(), microphone=(), camera=(), payment=(), usb=()',

    // Cache control for sensitive content
    'Cache-Control': 'no-cache, no-store, must-revalidate',
    'Pragma': 'no-cache',
    'Expires': '0',
  };

  /// Additional security headers for API responses
  static const Map<String, String> apiSecurityHeaders = {
    'X-Robots-Tag': 'noindex, nofollow, nosnippet, noarchive',
    'X-Permitted-Cross-Domain-Policies': 'none',
    'Cross-Origin-Embedder-Policy': 'require-corp',
    'Cross-Origin-Opener-Policy': 'same-origin',
    'Cross-Origin-Resource-Policy': 'same-origin',
  };

  // =============================================================================
  // ENCRYPTION SETTINGS
  // =============================================================================

  /// Primary encryption algorithm for data protection
  static const String encryptionAlgorithm = 'AES-256-GCM';

  /// Encryption key length in bits
  static const int keyLength = 256;

  /// Initialization vector length in bytes
  static const int ivLength = 16;

  /// Salt length for password hashing
  static const int saltLength = 32;

  /// Number of PBKDF2 iterations for key derivation
  static const int pbkdf2Iterations = 100000;

  // =============================================================================
  // PASSWORD SECURITY
  // =============================================================================

  /// Minimum password length (references AppConfig for consistency)
  static int get minPasswordLength => AppConfig.passwordMinLength;

  /// Maximum password length (references AppConfig for consistency)
  static int get maxPasswordLength => AppConfig.passwordMaxLength;

  /// Whether uppercase letters are required in passwords
  static bool get requireUppercase => AppConfig.requirePasswordUppercase;

  /// Whether lowercase letters are required in passwords
  static bool get requireLowercase => AppConfig.requirePasswordLowercase;

  /// Whether numbers are required in passwords
  static bool get requireNumbers => AppConfig.requirePasswordNumbers;

  /// Whether special characters are required in passwords
  static bool get requireSpecialChars => AppConfig.requirePasswordSymbols;

  /// List of commonly used weak passwords to prohibit
  static const List<String> commonWeakPasswords = [
    'password',
    '123456',
    '123456789',
    'qwerty',
    'abc123',
    'password123',
    'admin',
    'letmein',
    'welcome',
    'monkey',
    '1234567890',
    'password1',
    'iloveyou',
    'princess',
    'rockyou',
    '123123',
    'daniel',
    'master',
    'jordan',
    'superman',
    'harley',
    'charlie',
    'aa123456',
    'donald',
  ];

  /// Password strength requirements regex patterns
  static final Map<String, RegExp> passwordPatterns = {
    'uppercase': RegExp(r'[A-Z]'),
    'lowercase': RegExp(r'[a-z]'),
    'numbers': RegExp(r'[0-9]'),
    'specialChars': RegExp(r'[!@#$%^&*()_+\-=\[\]{};:"\\|,.<>?]'),
    'repeating':
        RegExp(r'(.)\1{2,}'), // More than 2 consecutive same characters
    'sequential': RegExp(
        r'(abc|bcd|cde|def|efg|fgh|ghi|hij|ijk|jkl|klm|lmn|mno|nop|opq|pqr|qrs|rst|stu|tuv|uvw|vwx|wxy|xyz|123|234|345|456|567|678|789)',
        caseSensitive: false),
  };

  // =============================================================================
  // SESSION SECURITY
  // =============================================================================

  /// Session timeout duration (references AppConfig)
  static Duration get sessionTimeout =>
      Duration(minutes: AppConfig.sessionTimeoutMinutes);

  /// Token refresh interval for JWT tokens
  static const Duration tokenRefreshInterval = Duration(minutes: 30);

  /// Maximum concurrent sessions per user
  static const int maxConcurrentSessions = 3;

  /// Session cookie security settings
  static const Map<String, dynamic> sessionCookieSettings = {
    'httpOnly': true,
    'secure': true,
    'sameSite': 'strict',
    'path': '/',
    'maxAge': 28800, // 8 hours in seconds
  };

  // =============================================================================
  // RATE LIMITING
  // =============================================================================

  /// Maximum login attempts (references AppConfig)
  static int get maxLoginAttempts => AppConfig.maxLoginAttempts;

  /// Account lockout duration (references AppConfig)
  static Duration get lockoutDuration =>
      Duration(minutes: AppConfig.lockoutDurationMinutes);

  /// Maximum API requests per minute (references AppConfig)
  static int get maxRequestsPerMinute => AppConfig.maxRequestsPerMinute;

  /// Maximum upload requests per hour (references AppConfig)
  static int get maxUploadRequestsPerHour => AppConfig.maxUploadRequestsPerHour;

  /// Maximum verification requests per minute
  static int get maxVerificationRequestsPerMinute =>
      AppConfig.maxVerificationRequestsPerMinute;

  /// Rate limiting time windows
  static const Map<String, Duration> rateLimitWindows = {
    'login': Duration(minutes: 15),
    'api': Duration(minutes: 1),
    'upload': Duration(hours: 1),
    'verification': Duration(minutes: 1),
    'password_reset': Duration(hours: 1),
  };

  // =============================================================================
  // FILE UPLOAD SECURITY
  // =============================================================================

  /// Allowed file extensions for uploads (references AppConfig)
  static List<String> get allowedFileTypes => [
        ...AppConfig.supportedDocumentTypes,
        ...AppConfig.supportedImageTypes,
        ...AppConfig.supportedCertificateTypes,
      ];

  /// File extensions that are explicitly blocked for security
  static const List<String> blockedFileTypes = [
    // Executable files
    'exe', 'bat', 'cmd', 'com', 'pif', 'scr', 'msi', 'dll', 'sys',
    // Script files
    'vbs', 'js', 'jse', 'wsf', 'wsh', 'ps1', 'psm1', 'psd1',
    // Archive files that might contain malware
    'rar', 'zip', '7z', 'tar', 'gz', 'bz2',
    // Server-side scripts
    'php', 'asp', 'aspx', 'jsp', 'cfm', 'cgi', 'pl', 'py', 'rb', 'sh',
    // Other potentially dangerous files
    'jar', 'war', 'ear', 'apk', 'ipa', 'deb', 'rpm',
  ];

  /// Maximum file size for uploads (references AppConfig)
  static int get maxFileSize => AppConfig.maxCertificateSizeBytes;

  /// MIME types that are allowed for file uploads
  static const List<String> allowedMimeTypes = [
    // Document types
    'application/pdf',
    'application/msword',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'text/plain',
    // Image types
    'image/jpeg',
    'image/png',
    'image/gif',
    'image/webp',
    'image/bmp',
    'image/svg+xml',
  ];

  /// Magic bytes for file type validation
  static const Map<String, List<int>> fileMagicBytes = {
    'pdf': [0x25, 0x50, 0x44, 0x46], // %PDF
    'jpg': [0xFF, 0xD8, 0xFF],
    'png': [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A],
    'gif': [0x47, 0x49, 0x46, 0x38],
    'bmp': [0x42, 0x4D],
    'zip': [0x50, 0x4B, 0x03, 0x04],
    'doc': [0xD0, 0xCF, 0x11, 0xE0, 0xA1, 0xB1, 0x1A, 0xE1],
  };

  // =============================================================================
  // DOMAIN AND URL SECURITY
  // =============================================================================

  /// Domains that are allowed for external requests
  static const List<String> allowedDomains = [
    'upm.edu.my',
    'firebase.google.com',
    'firebaseapp.com',
    'googleapis.com',
    'gstatic.com',
    'firebaseio.com',
    'cloudfunctions.net',
    'googleusercontent.com',
  ];

  /// URL schemes that are considered secure
  static const List<String> allowedSchemes = ['https'];

  /// Whether to enforce HTTPS for all connections
  static const bool enforceHttps = true;

  /// Whether to validate SSL certificates
  static bool get validateSSLCertificates => !kDebugMode;

  // =============================================================================
  // API SECURITY
  // =============================================================================

  /// Default timeout for API requests
  static const Duration apiTimeout = Duration(seconds: 30);

  /// Maximum retry attempts for failed requests
  static const int maxRetryAttempts = 3;

  /// Delay between retry attempts
  static const Duration retryDelay = Duration(seconds: 2);

  /// Request timeout for different operations
  static const Map<String, Duration> operationTimeouts = {
    'authentication': Duration(seconds: 10),
    'file_upload': Duration(minutes: 5),
    'file_download': Duration(minutes: 3),
    'database_query': Duration(seconds: 15),
    'certificate_generation': Duration(minutes: 2),
  };

  // =============================================================================
  // INPUT VALIDATION PATTERNS
  // =============================================================================

  /// Enhanced SQL injection detection pattern
  static final RegExp sqlInjectionPattern = RegExp(
    r'''(\b(ALTER|CREATE|DELETE|DROP|EXEC(UTE){0,1}|INSERT( +INTO){0,1}|MERGE|SELECT|UPDATE|UNION( +ALL){0,1}|GRANT|REVOKE|TRUNCATE|CALL|DECLARE|PREPARE|EXECUTE)\b|--|\/\*|\*\/|;|\x00|\x1a|\'|"|\\)''',
    caseSensitive: false,
    multiLine: true,
  );

  /// Enhanced XSS detection pattern
  static final RegExp xssPattern = RegExp(
    r'''(<script[^>]*>.*?</script>|<iframe[^>]*>.*?</iframe>|<object[^>]*>.*?</object>|<embed[^>]*>|<link[^>]*>|javascript:|vbscript:|data:|on\w+\s*=|<img[^>]+src\s*=\s*["\']?javascript:|eval\s*\(|setTimeout\s*\(|setInterval\s*\()''',
    caseSensitive: false,
    multiLine: true,
  );

  /// UPM email validation pattern
  static final RegExp emailPattern = RegExp(
    r'^[a-zA-Z0-9._%+-]+@upm\.edu\.my$',
    caseSensitive: false,
  );

  /// Path traversal detection pattern
  static final RegExp pathTraversalPattern = RegExp(
    r'(\.\.\/|\.\.\\|\.\.\%2f|\.\.\%5c|%2e%2e%2f|%2e%2e%5c)',
    caseSensitive: false,
  );

  /// Command injection detection pattern
  static final RegExp commandInjectionPattern = RegExp(
    r'[;&|`$(){}[\]<>]|cmd|powershell|bash|sh|eval|exec',
    caseSensitive: false,
  );

  // =============================================================================
  // VALIDATION METHODS
  // =============================================================================

  /// Validates if an email address follows UPM format and security requirements
  ///
  /// [email] The email address to validate
  /// Returns true if the email is valid and secure
  static bool isValidEmail(String email) {
    if (email.isEmpty || email.length > 320) return false;

    // Check basic format
    if (!emailPattern.hasMatch(email)) return false;

    // Check for suspicious patterns
    if (containsSqlInjection(email) || containsXss(email)) return false;

    return true;
  }

  /// Validates password security according to current requirements
  ///
  /// [password] The password to validate
  /// Returns true if the password meets all security requirements
  static bool isSecurePassword(String password) {
    if (password.isEmpty) return false;
    if (password.length < minPasswordLength) return false;
    if (password.length > maxPasswordLength) return false;

    // Check for common weak passwords
    if (commonWeakPasswords.contains(password.toLowerCase())) return false;

    // Check character requirements
    if (requireUppercase && !passwordPatterns['uppercase']!.hasMatch(password))
      return false;
    if (requireLowercase && !passwordPatterns['lowercase']!.hasMatch(password))
      return false;
    if (requireNumbers && !passwordPatterns['numbers']!.hasMatch(password))
      return false;
    if (requireSpecialChars &&
        !passwordPatterns['specialChars']!.hasMatch(password)) return false;

    // Check for weak patterns
    if (passwordPatterns['repeating']!.hasMatch(password)) return false;
    if (passwordPatterns['sequential']!.hasMatch(password)) return false;

    return true;
  }

  /// Gets a detailed password strength assessment
  ///
  /// [password] The password to assess
  /// Returns a map with strength score and suggestions
  static Map<String, dynamic> assessPasswordStrength(String password) {
    int score = 0;
    List<String> suggestions = [];
    List<String> strengths = [];

    // Length check
    if (password.length >= minPasswordLength) {
      score += 1;
      strengths.add('Adequate length');
    } else {
      suggestions.add('Use at least $minPasswordLength characters');
    }

    // Character variety checks
    if (passwordPatterns['uppercase']!.hasMatch(password)) {
      score += 1;
      strengths.add('Contains uppercase letters');
    } else if (requireUppercase) {
      suggestions.add('Add uppercase letters (A-Z)');
    }

    if (passwordPatterns['lowercase']!.hasMatch(password)) {
      score += 1;
      strengths.add('Contains lowercase letters');
    } else if (requireLowercase) {
      suggestions.add('Add lowercase letters (a-z)');
    }

    if (passwordPatterns['numbers']!.hasMatch(password)) {
      score += 1;
      strengths.add('Contains numbers');
    } else if (requireNumbers) {
      suggestions.add('Add numbers (0-9)');
    }

    if (passwordPatterns['specialChars']!.hasMatch(password)) {
      score += 1;
      strengths.add('Contains special characters');
    } else if (requireSpecialChars) {
      suggestions.add('Add special characters (!@#\$%^&*)');
    }

    // Weakness checks
    if (commonWeakPasswords.contains(password.toLowerCase())) {
      score -= 2;
      suggestions.add('Avoid common passwords');
    }

    if (passwordPatterns['repeating']!.hasMatch(password)) {
      score -= 1;
      suggestions.add('Avoid repeating characters');
    }

    if (passwordPatterns['sequential']!.hasMatch(password)) {
      score -= 1;
      suggestions.add('Avoid sequential characters');
    }

    // Determine strength level
    String strengthLevel;
    if (score >= 5) {
      strengthLevel = 'Strong';
    } else if (score >= 3) {
      strengthLevel = 'Medium';
    } else {
      strengthLevel = 'Weak';
    }

    return {
      'score': score,
      'strengthLevel': strengthLevel,
      'isSecure': score >= 4 && isSecurePassword(password),
      'suggestions': suggestions,
      'strengths': strengths,
    };
  }

  /// Validates file upload security
  ///
  /// [fileName] Name of the file being uploaded
  /// [fileSize] Size of the file in bytes
  /// [mimeType] MIME type of the file (optional)
  /// [fileBytes] First few bytes of the file for magic number validation (optional)
  /// Returns true if the file is safe to upload
  static bool isValidFileUpload(String fileName, int fileSize,
      {String? mimeType, List<int>? fileBytes}) {
    if (fileName.isEmpty) return false;

    // Check file extension
    final extension = fileName.split('.').last.toLowerCase();
    if (!allowedFileTypes.contains(extension)) return false;
    if (blockedFileTypes.contains(extension)) return false;

    // Check file size
    if (!isValidFileSize(fileSize)) return false;

    // Check MIME type if provided
    if (mimeType != null && !isValidMimeType(mimeType)) return false;

    // Check magic bytes if provided
    if (fileBytes != null && !isValidFileMagicBytes(extension, fileBytes))
      return false;

    // Additional security checks
    if (containsSuspiciousPath(fileName)) return false;

    return true;
  }

  /// Validates if a file type is allowed based on extension
  ///
  /// [fileName] The name of the file to check
  /// Returns true if the file type is allowed
  static bool isValidFileType(String fileName) {
    if (fileName.isEmpty) return false;

    final extension = fileName.split('.').last.toLowerCase();
    return allowedFileTypes.contains(extension) &&
        !blockedFileTypes.contains(extension);
  }

  /// Validates if a file size is within acceptable limits
  ///
  /// [fileSize] Size of the file in bytes
  /// Returns true if the file size is acceptable
  static bool isValidFileSize(int fileSize) {
    return fileSize > 0 && fileSize <= maxFileSize;
  }

  /// Validates if a MIME type is allowed
  ///
  /// [mimeType] The MIME type to validate
  /// Returns true if the MIME type is allowed
  static bool isValidMimeType(String mimeType) {
    return allowedMimeTypes.contains(mimeType.toLowerCase());
  }

  /// Validates file magic bytes against expected values
  ///
  /// [extension] File extension
  /// [fileBytes] First few bytes of the file
  /// Returns true if magic bytes match expected values for the file type
  static bool isValidFileMagicBytes(String extension, List<int> fileBytes) {
    if (!fileMagicBytes.containsKey(extension))
      return true; // No magic bytes to check

    final expectedBytes = fileMagicBytes[extension]!;
    if (fileBytes.length < expectedBytes.length) return false;

    for (int i = 0; i < expectedBytes.length; i++) {
      if (fileBytes[i] != expectedBytes[i]) return false;
    }

    return true;
  }

  /// Comprehensive input sanitization
  ///
  /// [input] The input string to sanitize
  /// [allowHtml] Whether to allow safe HTML tags (default: false)
  /// Returns sanitized input string
  static String sanitizeInput(String input, {bool allowHtml = false}) {
    if (input.isEmpty) return input;

    String sanitized = input;

    // Remove null bytes and control characters
    sanitized =
        sanitized.replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]'), '');

    // Remove potential SQL injection patterns
    sanitized = sanitized.replaceAll(sqlInjectionPattern, '');

    // Remove potential XSS patterns (unless HTML is explicitly allowed)
    if (!allowHtml) {
      sanitized = sanitized.replaceAll(xssPattern, '');
    }

    // Remove path traversal attempts
    sanitized = sanitized.replaceAll(pathTraversalPattern, '');

    // Remove command injection patterns
    sanitized = sanitized.replaceAll(commandInjectionPattern, '');

    // Normalize unicode characters
    sanitized = sanitized.replaceAll(RegExp(r'[^\x20-\x7E\xA0-\uFFFF]'), '');

    // Trim whitespace
    sanitized = sanitized.trim();

    // Limit length to prevent DoS
    if (sanitized.length > 10000) {
      sanitized = sanitized.substring(0, 10000);
    }

    return sanitized;
  }

  /// Checks if input contains SQL injection patterns
  ///
  /// [input] The input to check
  /// Returns true if SQL injection patterns are detected
  static bool containsSqlInjection(String input) {
    return sqlInjectionPattern.hasMatch(input);
  }

  /// Checks if input contains XSS patterns
  ///
  /// [input] The input to check
  /// Returns true if XSS patterns are detected
  static bool containsXss(String input) {
    return xssPattern.hasMatch(input);
  }

  /// Checks if input contains path traversal patterns
  ///
  /// [input] The input to check
  /// Returns true if path traversal patterns are detected
  static bool containsSuspiciousPath(String input) {
    return pathTraversalPattern.hasMatch(input);
  }

  /// Validates if a domain is in the allowed list
  ///
  /// [domain] The domain to validate
  /// Returns true if the domain is allowed
  static bool isValidDomain(String domain) {
    if (domain.isEmpty) return false;
    return allowedDomains.any((allowed) => domain.endsWith(allowed));
  }

  /// Validates if a URL is secure and allowed
  ///
  /// [url] The URL to validate
  /// Returns true if the URL is secure
  static bool isSecureUrl(String url) {
    if (url.isEmpty) return false;

    final uri = Uri.tryParse(url);
    if (uri == null) return false;

    // Check scheme
    if (enforceHttps && !allowedSchemes.contains(uri.scheme)) return false;

    // Check domain
    if (!isValidDomain(uri.host)) return false;

    // Check for suspicious patterns in URL
    if (containsXss(url) || containsSqlInjection(url)) return false;

    return true;
  }

  // =============================================================================
  // SECURITY AUDIT AND MONITORING
  // =============================================================================

  /// Gets the current security configuration for audit purposes
  ///
  /// Returns a map containing all security settings
  static Map<String, dynamic> getSecurityConfiguration() {
    return {
      'version': '2.0.0',
      'lastUpdated': DateTime.now().toIso8601String(),
      'environment': kDebugMode ? 'development' : 'production',
      'security': {
        'enforceHttps': enforceHttps,
        'validateSSLCertificates': validateSSLCertificates,
        'minPasswordLength': minPasswordLength,
        'maxPasswordLength': maxPasswordLength,
        'passwordRequirements': {
          'uppercase': requireUppercase,
          'lowercase': requireLowercase,
          'numbers': requireNumbers,
          'specialChars': requireSpecialChars,
        },
        'sessionTimeout': sessionTimeout.inMinutes,
        'maxLoginAttempts': maxLoginAttempts,
        'lockoutDuration': lockoutDuration.inMinutes,
      },
      'rateLimiting': {
        'maxRequestsPerMinute': maxRequestsPerMinute,
        'maxUploadRequestsPerHour': maxUploadRequestsPerHour,
        'maxVerificationRequestsPerMinute': maxVerificationRequestsPerMinute,
      },
      'fileUpload': {
        'maxFileSize': maxFileSize,
        'allowedFileTypes': allowedFileTypes,
        'blockedFileTypes': blockedFileTypes,
        'allowedMimeTypes': allowedMimeTypes,
      },
      'network': {
        'allowedDomains': allowedDomains,
        'allowedSchemes': allowedSchemes,
        'apiTimeout': apiTimeout.inSeconds,
      },
    };
  }

  /// Gets security headers appropriate for the current environment
  ///
  /// Returns security headers map
  static Map<String, String> getEnvironmentSecurityHeaders() {
    if (kReleaseMode) {
      return {...securityHeaders, ...apiSecurityHeaders};
    } else {
      // Relaxed headers for development
      return {
        'X-Content-Type-Options': 'nosniff',
        'X-Frame-Options': 'SAMEORIGIN',
        'Referrer-Policy': 'strict-origin-when-cross-origin',
      };
    }
  }

  /// Checks if running in a production environment
  ///
  /// Returns true if in production mode
  static bool isProductionEnvironment() {
    return kReleaseMode && !kDebugMode;
  }

  /// Validates the overall security posture
  ///
  /// Returns a security assessment report
  static Map<String, dynamic> performSecurityAudit() {
    List<String> warnings = [];
    List<String> recommendations = [];
    int score = 100;

    // Check environment
    if (kDebugMode) {
      warnings.add('Debug mode is enabled');
      score -= 10;
    }

    // Check SSL validation
    if (!validateSSLCertificates) {
      warnings.add('SSL certificate validation is disabled');
      score -= 20;
    }

    // Check HTTPS enforcement
    if (!enforceHttps) {
      warnings.add('HTTPS enforcement is disabled');
      score -= 15;
    }

    // Check password requirements
    if (minPasswordLength < 8) {
      warnings.add('Minimum password length is too short');
      score -= 10;
    }

    // Recommendations
    if (sessionTimeout.inHours > 8) {
      recommendations
          .add('Consider reducing session timeout for better security');
    }

    if (maxLoginAttempts > 5) {
      recommendations.add('Consider reducing maximum login attempts');
    }

    return {
      'score': score,
      'grade': _getSecurityGrade(score),
      'warnings': warnings,
      'recommendations': recommendations,
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  /// Gets security grade based on score
  static String _getSecurityGrade(int score) {
    if (score >= 90) return 'A';
    if (score >= 80) return 'B';
    if (score >= 70) return 'C';
    if (score >= 60) return 'D';
    return 'F';
  }
}
