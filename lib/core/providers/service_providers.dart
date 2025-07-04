/// Service providers for the UPM Digital Certificate Repository.
///
/// This file contains all Riverpod providers for services used throughout
/// the application. Each service is properly scoped and manages the
/// application's service layer dependencies.

import 'package:flutter_riverpod/flutter_riverpod.dart';

// Core services
import '../services/logger_service.dart';
import '../services/error_handler_service.dart';
import '../services/performance_service.dart';
import '../services/system_health_monitor.dart';
import '../services/initialization_service.dart';
import '../services/migration_service.dart';

// Validation and security
import '../services/validation_service.dart';
import '../services/cross_system_validator.dart';
import '../services/totp_service.dart';

// User management
import '../services/user_profile_service.dart';
import '../services/avatar_upload_service.dart';

// Certificate and document services
import '../services/certificate_request_service.dart';
import '../services/document_service.dart';
import '../services/pdf_generation_service.dart';
import '../services/certificate_pdf_service.dart';

// Communication
import '../services/notification_service.dart';
import '../services/live_chat_service.dart';
import '../services/localization_service.dart';

// Reports and analytics
import '../services/report_export_service.dart';
import '../services/advanced_export_service.dart';

// Other services
import '../services/payment_service.dart';
import '../services/project_completion_service.dart';

// =============================================================================
// CORE SYSTEM SERVICES
// =============================================================================

/// Logger Service Provider - Handles application logging
final loggerServiceProvider = Provider<LoggerService>((ref) {
  return LoggerService();
});

/// Error Handler Service Provider - Centralized error handling
final errorHandlerServiceProvider = Provider<ErrorHandlerService>((ref) {
  return ErrorHandlerService();
});

/// Performance Service Provider - Performance monitoring
final performanceServiceProvider = Provider<PerformanceService>((ref) {
  return PerformanceService();
});

/// System Health Monitor Provider - System health monitoring
final systemHealthMonitorProvider = Provider<SystemHealthMonitor>((ref) {
  return SystemHealthMonitor();
});

/// Initialization Service Provider - App startup management
final initializationServiceProvider = Provider<InitializationService>((ref) {
  return InitializationService();
});

/// Migration Service Provider - Data migration management
final migrationServiceProvider = Provider<MigrationService>((ref) {
  return MigrationService();
});

// =============================================================================
// VALIDATION AND SECURITY
// =============================================================================

/// Validation Service Provider - Input validation
final validationServiceProvider = Provider<ValidationService>((ref) {
  return ValidationService();
});

/// Cross System Validator Provider - Inter-service validation
final crossSystemValidatorProvider = Provider<CrossSystemValidator>((ref) {
  return CrossSystemValidator();
});

/// TOTP Service Provider - Two-factor authentication
final totpServiceProvider = Provider<TOTPService>((ref) {
  return TOTPService();
});

// =============================================================================
// USER MANAGEMENT
// =============================================================================

/// User Profile Service Provider - User profile management
final userProfileServiceProvider = Provider<UserProfileService>((ref) {
  return UserProfileService();
});

/// Avatar Upload Service Provider - Profile image management
final avatarUploadServiceProvider = Provider<AvatarUploadService>((ref) {
  return AvatarUploadService();
});

// =============================================================================
// CERTIFICATE AND DOCUMENT SERVICES
// =============================================================================

/// Certificate Request Service Provider - Certificate workflow management
final certificateRequestServiceProvider =
    Provider<CertificateRequestService>((ref) {
  return CertificateRequestService();
});

/// Document Service Provider - Document management
final documentServiceProvider = Provider<DocumentService>((ref) {
  return DocumentService();
});

/// PDF Generation Service Provider - PDF creation
final pdfGenerationServiceProvider = Provider<PDFGenerationService>((ref) {
  return PDFGenerationService();
});

/// Certificate PDF Service Provider - Certificate PDF generation
final certificatePdfServiceProvider = Provider<CertificatePDFService>((ref) {
  return CertificatePDFService();
});

// =============================================================================
// COMMUNICATION SERVICES
// =============================================================================

/// Notification Service Provider - Notification management
final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});

/// Live Chat Service Provider - Real-time chat
final liveChatServiceProvider = Provider<LiveChatService>((ref) {
  return LiveChatService();
});

/// Localization Service Provider - Multi-language support
final localizationServiceProvider = Provider<LocalizationService>((ref) {
  return LocalizationService();
});

// =============================================================================
// REPORTING AND ANALYTICS
// =============================================================================

/// Report Export Service Provider - Report generation
final reportExportServiceProvider = Provider<ReportExportService>((ref) {
  return ReportExportService();
});

/// Advanced Export Service Provider - Advanced analytics
final advancedExportServiceProvider = Provider<AdvancedExportService>((ref) {
  return AdvancedExportService();
});

// =============================================================================
// OTHER SERVICES
// =============================================================================

/// Payment Service Provider - Payment processing
final paymentServiceProvider = Provider<PaymentService>((ref) {
  return PaymentService();
});

/// Project Completion Service Provider - Project lifecycle management
final projectCompletionServiceProvider =
    Provider<ProjectCompletionService>((ref) {
  return ProjectCompletionService();
});

// =============================================================================
// COMPOSITE PROVIDERS
// =============================================================================

/// All Services Provider - Access to all services (for testing/debugging)
final allServicesProvider = Provider<Map<String, dynamic>>((ref) {
  return {
    'logger': ref.watch(loggerServiceProvider),
    'errorHandler': ref.watch(errorHandlerServiceProvider),
    'performance': ref.watch(performanceServiceProvider),
    'systemHealth': ref.watch(systemHealthMonitorProvider),
    'initialization': ref.watch(initializationServiceProvider),
    'migration': ref.watch(migrationServiceProvider),
    'validation': ref.watch(validationServiceProvider),
    'crossSystemValidator': ref.watch(crossSystemValidatorProvider),
    'totp': ref.watch(totpServiceProvider),
    'userProfile': ref.watch(userProfileServiceProvider),
    'avatarUpload': ref.watch(avatarUploadServiceProvider),
    'certificateRequest': ref.watch(certificateRequestServiceProvider),
    'document': ref.watch(documentServiceProvider),
    'pdfGeneration': ref.watch(pdfGenerationServiceProvider),
    'certificatePdf': ref.watch(certificatePdfServiceProvider),
    'notification': ref.watch(notificationServiceProvider),
    'liveChat': ref.watch(liveChatServiceProvider),
    'localization': ref.watch(localizationServiceProvider),
    'reportExport': ref.watch(reportExportServiceProvider),
    'advancedExport': ref.watch(advancedExportServiceProvider),
    'payment': ref.watch(paymentServiceProvider),
    'projectCompletion': ref.watch(projectCompletionServiceProvider),
  };
});
