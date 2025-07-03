import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../localization/app_localizations.dart';
import 'logger_service.dart';

/// Comprehensive Localization Service for the UPM Digital Certificate Repository.
///
/// This service provides enterprise-grade internationalization and localization including:
/// - Multi-language support with persistent storage
/// - Automatic system locale detection
/// - Dynamic language switching with state management
/// - Locale-specific date and time formatting
/// - Text direction handling
/// - Currency and number formatting
/// - Timezone awareness
///
/// Supported Languages:
/// - English (US) - Primary language
/// - Bahasa Malaysia (MY) - Local official language
/// - Chinese Simplified (CN) - International support
///
/// Features:
/// - Automatic fallback to supported languages
/// - Persistent language preference storage
/// - Real-time language switching
/// - Context-aware text formatting
/// - Cultural adaptation for dates/times
/// - Riverpod state management integration
class LocalizationService extends ChangeNotifier {
  // =============================================================================
  // CONSTANTS
  // =============================================================================

  /// SharedPreferences key for storing selected language
  static const String _languageKey = 'selected_language';

  /// Default locale when no preference is set
  static const Locale _defaultLocale = Locale('en', 'US');

  /// Supported locale codes
  static const Set<String> _supportedLanguageCodes = {'en', 'ms', 'zh'};

  // =============================================================================
  // SINGLETON PATTERN
  // =============================================================================

  static LocalizationService? _instance;

  /// Get the singleton instance of LocalizationService
  static LocalizationService get instance {
    _instance ??= LocalizationService();
    return _instance!;
  }

  // =============================================================================
  // STATE MANAGEMENT
  // =============================================================================

  Locale _currentLocale = _defaultLocale;
  bool _isInitialized = false;
  String? _lastError;
  DateTime? _lastLanguageChange;

  // =============================================================================
  // GETTERS
  // =============================================================================

  /// Current locale being used
  Locale get currentLocale => _currentLocale;

  /// Whether the service is initialized and ready
  bool get isInitialized => _isInitialized;

  /// Whether the service is healthy and operational
  bool get isHealthy => _isInitialized && _lastError == null;

  /// Last error that occurred (if any)
  String? get lastError => _lastError;

  /// Time of last language change
  DateTime? get lastLanguageChange => _lastLanguageChange;

  /// Current language code
  String get currentLanguageCode => _currentLocale.languageCode;

  /// Current country code
  String? get currentCountryCode => _currentLocale.countryCode;

  // =============================================================================
  // INITIALIZATION
  // =============================================================================

  /// Initialize localization service with comprehensive setup
  Future<void> initialize() async {
    try {
      LoggerService.info('Initializing localization service...');
      _lastError = null;

      final prefs = await SharedPreferences.getInstance();
      final savedLanguage = prefs.getString(_languageKey);

      if (savedLanguage != null &&
          _supportedLanguageCodes.contains(savedLanguage)) {
        _currentLocale = _getLocaleFromCode(savedLanguage);
        LoggerService.info('Loaded saved language: $savedLanguage');
      } else {
        // Use system locale if supported, otherwise default to English
        final systemLocale = WidgetsBinding.instance.platformDispatcher.locale;
        if (_isSupportedLocale(systemLocale)) {
          _currentLocale = systemLocale;
          LoggerService.info(
              'Using system locale: ${systemLocale.languageCode}');
        } else {
          _currentLocale = _defaultLocale;
          LoggerService.info(
              'System locale not supported, using default: ${_defaultLocale.languageCode}');
        }

        // Save the determined language
        await prefs.setString(_languageKey, _currentLocale.languageCode);
      }

      _isInitialized = true;
      _lastLanguageChange = DateTime.now();

      LoggerService.info(
          'Localization service initialized successfully with locale: ${_currentLocale.languageCode}');
      notifyListeners();
    } catch (e, stackTrace) {
      _lastError = e.toString();
      LoggerService.error('Failed to initialize localization service',
          error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  // =============================================================================
  // LANGUAGE MANAGEMENT
  // =============================================================================

  /// Change language with validation and persistence
  Future<void> changeLanguage(Locale locale) async {
    try {
      if (!_isSupportedLocale(locale)) {
        throw Exception('Unsupported locale: ${locale.languageCode}');
      }

      if (_currentLocale.languageCode == locale.languageCode) {
        LoggerService.info('Language already set to: ${locale.languageCode}');
        return;
      }

      final previousLocale = _currentLocale;
      _currentLocale = locale;
      _lastLanguageChange = DateTime.now();

      // Save to preferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_languageKey, locale.languageCode);

      LoggerService.info(
          'Language changed from ${previousLocale.languageCode} to ${locale.languageCode}');
      notifyListeners();
    } catch (e, stackTrace) {
      _lastError = e.toString();
      LoggerService.error('Failed to change language',
          error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  /// Get all supported languages with detailed information
  List<LanguageOption> getSupportedLanguages() {
    return [
      const LanguageOption(
        locale: Locale('en', 'US'),
        name: 'English',
        nativeName: 'English',
        flag: '🇺🇸',
        isDefault: true,
        direction: TextDirection.ltr,
        cultureName: 'en-US',
      ),
      const LanguageOption(
        locale: Locale('ms', 'MY'),
        name: 'Bahasa Malaysia',
        nativeName: 'Bahasa Malaysia',
        flag: '🇲🇾',
        isDefault: false,
        direction: TextDirection.ltr,
        cultureName: 'ms-MY',
      ),
      const LanguageOption(
        locale: Locale('zh', 'CN'),
        name: 'Chinese (Simplified)',
        nativeName: '简体中文',
        flag: '🇨🇳',
        isDefault: false,
        direction: TextDirection.ltr,
        cultureName: 'zh-CN',
      ),
    ];
  }

  /// Get current language option with full details
  LanguageOption getCurrentLanguageOption() {
    return getSupportedLanguages().firstWhere(
      (option) => option.locale.languageCode == _currentLocale.languageCode,
      orElse: () => getSupportedLanguages().first,
    );
  }

  /// Get language option by code
  LanguageOption? getLanguageOptionByCode(String languageCode) {
    try {
      return getSupportedLanguages().firstWhere(
        (option) => option.locale.languageCode == languageCode,
      );
    } catch (e) {
      return null;
    }
  }

  // =============================================================================
  // LOCALIZATION UTILITIES
  // =============================================================================

  /// Get localized text for common keys with fallback
  String getLocalizedText(BuildContext context, String key) {
    try {
      final localizations = AppLocalizations.of(context);
      if (localizations == null) {
        LoggerService.warning('AppLocalizations not available for key: $key');
        return key;
      }

      switch (key) {
        case 'app_name':
          return localizations.appName;
        case 'loading':
          return localizations.loading;
        case 'error':
          return localizations.error;
        case 'success':
          return localizations.success;
        case 'cancel':
          return localizations.cancel;
        case 'confirm':
          return localizations.confirm;
        case 'save':
          return localizations.save;
        case 'delete':
          return localizations.delete;
        case 'edit':
          return localizations.edit;
        case 'close':
          return localizations.close;
        case 'retry':
          return localizations.retry;
        case 'settings':
          return localizations.settings;
        case 'profile':
          return localizations.profile;
        case 'logout':
          return localizations.logout;
        case 'login':
          return localizations.login;
        case 'register':
          return localizations.register;
        default:
          LoggerService.warning('Unknown localization key: $key');
          return key;
      }
    } catch (e) {
      LoggerService.error('Failed to get localized text for key: $key',
          error: e);
      return key;
    }
  }

  /// **静态getText方法（向后兼容）**
  static String getText(String key, {BuildContext? context}) {
    if (context != null) {
      return instance.getLocalizedText(context, key);
    }
    // 如果没有context，返回key作为fallback
    return key;
  }

  // =============================================================================
  // FORMATTING UTILITIES
  // =============================================================================

  /// Format date according to current locale with enhanced options
  String formatDate(DateTime date, {DateFormat format = DateFormat.short}) {
    try {
      switch (_currentLocale.languageCode) {
        case 'ms':
          return _formatDateMalay(date, format);
        case 'zh':
          return _formatDateChinese(date, format);
        default:
          return _formatDateEnglish(date, format);
      }
    } catch (e) {
      LoggerService.error('Failed to format date', error: e);
      return date.toString();
    }
  }

  /// Format time according to current locale
  String formatTime(DateTime time, {bool use24Hour = false}) {
    try {
      switch (_currentLocale.languageCode) {
        case 'ms':
        case 'zh':
          return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
        default:
          if (use24Hour) {
            return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
          } else {
            final hour = time.hour == 0
                ? 12
                : (time.hour > 12 ? time.hour - 12 : time.hour);
            final period = time.hour >= 12 ? 'PM' : 'AM';
            return '${hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')} $period';
          }
      }
    } catch (e) {
      LoggerService.error('Failed to format time', error: e);
      return time.toString();
    }
  }

  /// Format currency according to current locale
  String formatCurrency(double amount, {String? currencySymbol}) {
    try {
      final formattedAmount = amount.toStringAsFixed(2);

      switch (_currentLocale.languageCode) {
        case 'ms':
          return currencySymbol != null
              ? '$currencySymbol $formattedAmount'
              : 'RM $formattedAmount';
        case 'zh':
          return currencySymbol != null
              ? '$currencySymbol$formattedAmount'
              : '¥$formattedAmount';
        default:
          return currencySymbol != null
              ? '$currencySymbol$formattedAmount'
              : '\$$formattedAmount';
      }
    } catch (e) {
      LoggerService.error('Failed to format currency', error: e);
      return amount.toString();
    }
  }

  /// Format number according to current locale
  String formatNumber(num number, {int? decimalPlaces}) {
    try {
      final places = decimalPlaces ?? (number is int ? 0 : 2);
      return number.toStringAsFixed(places);
    } catch (e) {
      LoggerService.error('Failed to format number', error: e);
      return number.toString();
    }
  }

  // =============================================================================
  // PRIVATE HELPER METHODS
  // =============================================================================

  /// Check if locale is supported
  bool _isSupportedLocale(Locale locale) {
    return _supportedLanguageCodes.contains(locale.languageCode);
  }

  /// Get locale from language code
  Locale _getLocaleFromCode(String languageCode) {
    switch (languageCode) {
      case 'en':
        return const Locale('en', 'US');
      case 'ms':
        return const Locale('ms', 'MY');
      case 'zh':
        return const Locale('zh', 'CN');
      default:
        return _defaultLocale;
    }
  }

  /// Format date in Malay style
  String _formatDateMalay(DateTime date, DateFormat format) {
    switch (format) {
      case DateFormat.long:
        return '${date.day} ${_getMalayMonthName(date.month)} ${date.year}';
      case DateFormat.medium:
        return '${date.day} ${_getMalayMonthAbbr(date.month)} ${date.year}';
      default:
        return '${date.day}/${date.month}/${date.year}';
    }
  }

  /// Format date in Chinese style
  String _formatDateChinese(DateTime date, DateFormat format) {
    switch (format) {
      case DateFormat.long:
        return '${date.year}年${date.month}月${date.day}日';
      case DateFormat.medium:
        return '${date.year}年${date.month}月${date.day}日';
      default:
        return '${date.year}/${date.month}/${date.day}';
    }
  }

  /// Format date in English style
  String _formatDateEnglish(DateTime date, DateFormat format) {
    switch (format) {
      case DateFormat.long:
        return '${_getEnglishMonthName(date.month)} ${date.day}, ${date.year}';
      case DateFormat.medium:
        return '${_getEnglishMonthAbbr(date.month)} ${date.day}, ${date.year}';
      default:
        return '${date.month}/${date.day}/${date.year}';
    }
  }

  /// Get currency symbol for current locale
  // ignore: unused_element
  String _getCurrencySymbol() {
    switch (_currentLocale.languageCode) {
      case 'ms':
        return 'RM';
      case 'zh':
        return '¥';
      default:
        return '\$';
    }
  }

  /// Get English month names
  String _getEnglishMonthName(int month) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December'
    ];
    return months[month - 1];
  }

  /// Get English month abbreviations
  String _getEnglishMonthAbbr(int month) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return months[month - 1];
  }

  /// Get Malay month names
  String _getMalayMonthName(int month) {
    const months = [
      'Januari',
      'Februari',
      'Mac',
      'April',
      'Mei',
      'Jun',
      'Julai',
      'Ogos',
      'September',
      'Oktober',
      'November',
      'Disember'
    ];
    return months[month - 1];
  }

  /// Get Malay month abbreviations
  String _getMalayMonthAbbr(int month) {
    const months = [
      'Jan',
      'Feb',
      'Mac',
      'Apr',
      'Mei',
      'Jun',
      'Jul',
      'Ogs',
      'Sep',
      'Okt',
      'Nov',
      'Dis'
    ];
    return months[month - 1];
  }

  // =============================================================================
  // PUBLIC UTILITIES
  // =============================================================================

  /// Get text direction for current locale
  TextDirection getTextDirection() {
    // All supported languages use LTR
    return TextDirection.ltr;
  }

  /// Reset to default language
  Future<void> resetToDefault() async {
    LoggerService.info('Resetting language to default');
    await changeLanguage(_defaultLocale);
  }

  /// Get service statistics
  Map<String, dynamic> getStatistics() {
    return {
      'isInitialized': _isInitialized,
      'currentLanguage': _currentLocale.languageCode,
      'lastLanguageChange': _lastLanguageChange?.toIso8601String(),
      'supportedLanguages': _supportedLanguageCodes.toList(),
      'isHealthy': isHealthy,
      'lastError': _lastError,
    };
  }

  /// Clear any cached data
  Future<void> clearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_languageKey);
      LoggerService.info('Localization cache cleared');
    } catch (e) {
      LoggerService.error('Failed to clear localization cache', error: e);
    }
  }
}

// =============================================================================
// SUPPORTING CLASSES AND ENUMS
// =============================================================================

/// Date format options for localization
enum DateFormat {
  short,
  medium,
  long,
}

/// Language option with comprehensive details
class LanguageOption {
  final Locale locale;
  final String name;
  final String nativeName;
  final String flag;
  final bool isDefault;
  final TextDirection direction;
  final String cultureName;

  const LanguageOption({
    required this.locale,
    required this.name,
    required this.nativeName,
    required this.flag,
    required this.isDefault,
    required this.direction,
    required this.cultureName,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is LanguageOption && other.locale == locale;
  }

  @override
  int get hashCode => locale.hashCode;

  @override
  String toString() => 'LanguageOption(${locale.languageCode}: $name)';
}

// =============================================================================
// RIVERPOD PROVIDERS
// =============================================================================

/// Main localization service provider
final localizationServiceProvider =
    ChangeNotifierProvider<LocalizationService>((ref) {
  return LocalizationService();
});

/// Current locale provider
final currentLocaleProvider = Provider<Locale>((ref) {
  return ref.watch(localizationServiceProvider).currentLocale;
});

/// Supported languages provider
final supportedLanguagesProvider = Provider<List<LanguageOption>>((ref) {
  return ref.read(localizationServiceProvider).getSupportedLanguages();
});

/// Current language option provider
final currentLanguageProvider = Provider<LanguageOption>((ref) {
  return ref.read(localizationServiceProvider).getCurrentLanguageOption();
});

/// Localization service health provider
final localizationHealthProvider = Provider<bool>((ref) {
  return ref.watch(localizationServiceProvider).isHealthy;
});
