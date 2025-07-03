import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/logger_service.dart';

/// UPM数字证书仓库企业级主题系统
///
/// 包含完整的Material 3.0主题实现，支持：
/// - 亮色/暗色模式
/// - 响应式设计
/// - 无障碍支持
/// - UPM品牌视觉识别
class AppTheme {
  AppTheme._();

  // =============================================================================
  // 私有状态管理
  // =============================================================================

  static bool _isInitialized = false;
  static DateTime _lastHealthCheck = DateTime.now();
  static final Map<String, ThemeData> _themeCache = {};

  // =============================================================================
  // UPM品牌色彩系统
  // =============================================================================

  /// **主色调** - UPM蓝色
  static const Color primaryColor = Color(0xFF1976D2);

  /// **次要色调** - UPM绿色
  static const Color secondaryColor = Color(0xFF4CAF50);

  /// **强调色** - UPM橙色
  static const Color accentColor = Color(0xFFFF9800);

  /// **错误色**
  static const Color errorColor = Color(0xFFD32F2F);

  /// **成功色**
  static const Color successColor = Color(0xFF388E3C);

  /// **警告色**
  static const Color warningColor = Color(0xFFF57C00);

  /// **信息色**
  static const Color infoColor = Color(0xFF1976D2);
  
  // =============================================================================
  // 表面和背景色彩
  // =============================================================================

  /// **背景色**
  static const Color backgroundColor = Color(0xFFFAFAFA);

  /// **表面色**
  static const Color surfaceColor = Color(0xFFFFFFFF);

  /// **卡片背景色**
  static const Color cardColor = Color(0xFFFFFFFF);

  /// **输入框背景色**
  static const Color inputBackground = Color(0xFFF5F5F5);

  // =============================================================================
  // 文字色彩系统
  // =============================================================================

  /// **主要文字色**
  static const Color textPrimary = Color(0xFF212121);

  /// **次要文字色**
  static const Color textSecondary = Color(0xFF757575);

  /// **禁用文字色**
  static const Color textDisabled = Color(0xFFBDBDBD);

  /// **主色上的文字**
  static const Color textOnPrimary = Color(0xFFFFFFFF);

  /// **次要色上的文字**
  static const Color textOnSecondary = Color(0xFFFFFFFF);

  /// **错误色上的文字**
  static const Color textOnError = Color(0xFFFFFFFF);

  // =============================================================================
  // 边框和分割线
  // =============================================================================

  /// **主要边框色**
  static const Color borderColor = Color(0xFFE0E0E0);

  /// **浅色边框**
  static const Color borderLight = Color(0xFFF5F5F5);

  /// **分割线色**
  static const Color dividerColor = Color(0xFFEEEEEE);

  /// **阴影色**
  static const Color shadowColor = Color(0x1F000000);

  // =============================================================================
  // 间距系统
  // =============================================================================

  /// **微小间距** - 4dp
  static const double spacingXS = 4.0;

  /// **小间距** - 8dp
  static const double spacingS = 8.0;

  /// **中间距** - 16dp
  static const double spacingM = 16.0;

  /// **大间距** - 24dp
  static const double spacingL = 24.0;

  /// **超大间距** - 32dp
  static const double spacingXL = 32.0;

  /// **超超大间距** - 48dp
  static const double spacingXXL = 48.0;

  // =============================================================================
  // 圆角系统
  // =============================================================================

  /// **圆角半径常量**
  static const double radiusXS = 4.0;
  static const double radiusS = 8.0;
  static const double radiusM = 12.0;
  static const double radiusL = 16.0;
  static const double radiusXL = 24.0;

  /// **圆角边框样式**
  static const BorderRadius smallRadius = BorderRadius.all(Radius.circular(8));
  static const BorderRadius mediumRadius =
      BorderRadius.all(Radius.circular(12));
  static const BorderRadius largeRadius = BorderRadius.all(Radius.circular(16));
  static const BorderRadius extraLargeRadius =
      BorderRadius.all(Radius.circular(24));

  // =============================================================================
  // 海拔系统
  // =============================================================================

  /// **海拔等级**
  static const double elevation0 = 0.0;
  static const double elevation1 = 1.0;
  static const double elevation2 = 2.0;
  static const double elevation4 = 4.0;
  static const double elevation8 = 8.0;
  static const double elevation16 = 16.0;
  static const double elevation24 = 24.0;

  // =============================================================================
  // 动画配置
  // =============================================================================

  /// **动画持续时间**
  static const Duration fastAnimation = Duration(milliseconds: 150);
  static const Duration mediumAnimation = Duration(milliseconds: 300);
  static const Duration slowAnimation = Duration(milliseconds: 500);

  // =============================================================================
  // 文字主题
  // =============================================================================

  /// **完整文字主题**
  static TextTheme get textTheme => GoogleFonts.interTextTheme(
    const TextTheme(
      displayLarge: TextStyle(
        fontSize: 57,
        fontWeight: FontWeight.w400,
        letterSpacing: -0.25,
            height: 1.12,
            color: textPrimary,
      ),
      displayMedium: TextStyle(
        fontSize: 45,
        fontWeight: FontWeight.w400,
        letterSpacing: 0,
            height: 1.16,
            color: textPrimary,
      ),
      displaySmall: TextStyle(
        fontSize: 36,
        fontWeight: FontWeight.w400,
        letterSpacing: 0,
            height: 1.22,
            color: textPrimary,
      ),
      headlineLarge: TextStyle(
        fontSize: 32,
            fontWeight: FontWeight.w400,
        letterSpacing: 0,
            height: 1.25,
            color: textPrimary,
      ),
      headlineMedium: TextStyle(
        fontSize: 28,
            fontWeight: FontWeight.w400,
        letterSpacing: 0,
            height: 1.29,
            color: textPrimary,
      ),
      headlineSmall: TextStyle(
        fontSize: 24,
            fontWeight: FontWeight.w400,
        letterSpacing: 0,
            height: 1.33,
            color: textPrimary,
      ),
      titleLarge: TextStyle(
        fontSize: 22,
            fontWeight: FontWeight.w400,
        letterSpacing: 0,
            height: 1.27,
            color: textPrimary,
      ),
      titleMedium: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.15,
            height: 1.50,
            color: textPrimary,
      ),
      titleSmall: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.1,
            height: 1.43,
            color: textPrimary,
      ),
      labelLarge: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.1,
            height: 1.43,
            color: textPrimary,
      ),
      labelMedium: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.5,
            height: 1.33,
            color: textPrimary,
      ),
      labelSmall: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.5,
            height: 1.45,
            color: textPrimary,
      ),
      bodyLarge: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w400,
            letterSpacing: 0.15,
            height: 1.50,
            color: textPrimary,
      ),
      bodyMedium: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.25,
            height: 1.43,
            color: textPrimary,
      ),
      bodySmall: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.4,
            height: 1.33,
            color: textPrimary,
      ),
    ),
  );

  // =============================================================================
  // 组件主题
  // =============================================================================

  /// **按钮主题 - 提升按钮**
  static ElevatedButtonThemeData get elevatedButtonTheme =>
      ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
          foregroundColor: textOnPrimary,
      backgroundColor: primaryColor,
          disabledForegroundColor: textDisabled,
          disabledBackgroundColor: borderColor,
          elevation: elevation2,
      shadowColor: shadowColor,
      shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusM),
      ),
          padding: const EdgeInsets.symmetric(
              horizontal: spacingL, vertical: spacingM),
          minimumSize: const Size(64, 48),
      textStyle: textTheme.labelLarge?.copyWith(
        fontWeight: FontWeight.w600,
            color: textOnPrimary,
      ),
    ),
  );

  /// **按钮主题 - 轮廓按钮**
  static OutlinedButtonThemeData get outlinedButtonTheme =>
      OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: primaryColor,
      backgroundColor: Colors.transparent,
          disabledForegroundColor: textDisabled,
      side: const BorderSide(color: primaryColor, width: 1.5),
      shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusM),
      ),
          padding: const EdgeInsets.symmetric(
              horizontal: spacingL, vertical: spacingM),
          minimumSize: const Size(64, 48),
      textStyle: textTheme.labelLarge?.copyWith(
        fontWeight: FontWeight.w600,
        color: primaryColor,
      ),
    ),
  );

  /// **按钮主题 - 文本按钮**
  static TextButtonThemeData get textButtonTheme => TextButtonThemeData(
    style: TextButton.styleFrom(
      foregroundColor: primaryColor,
          disabledForegroundColor: textDisabled,
      shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusS),
      ),
          padding: const EdgeInsets.symmetric(
              horizontal: spacingM, vertical: spacingS),
          minimumSize: const Size(48, 40),
      textStyle: textTheme.labelLarge?.copyWith(
        fontWeight: FontWeight.w600,
        color: primaryColor,
      ),
    ),
  );

  /// **输入框主题**
  static InputDecorationTheme get inputDecorationTheme => InputDecorationTheme(
    filled: true,
        fillColor: inputBackground,
    border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusM),
          borderSide: const BorderSide(color: borderColor, width: 1),
    ),
    enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusM),
          borderSide: const BorderSide(color: borderColor, width: 1),
    ),
    focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusM),
      borderSide: const BorderSide(color: primaryColor, width: 2),
    ),
    errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusM),
          borderSide: const BorderSide(color: errorColor, width: 1),
    ),
    focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusM),
      borderSide: const BorderSide(color: errorColor, width: 2),
    ),
        contentPadding: const EdgeInsets.symmetric(
            horizontal: spacingM, vertical: spacingM),
        hintStyle: textTheme.bodyMedium?.copyWith(color: textSecondary),
        labelStyle: textTheme.bodyMedium?.copyWith(color: textSecondary),
    errorStyle: textTheme.bodySmall?.copyWith(color: errorColor),
  );

  /// **应用栏主题**
  static AppBarTheme get appBarTheme => AppBarTheme(
    backgroundColor: primaryColor,
        foregroundColor: textOnPrimary,
        elevation: elevation2,
    shadowColor: shadowColor,
    centerTitle: true,
    titleTextStyle: textTheme.titleLarge?.copyWith(
          color: textOnPrimary,
      fontWeight: FontWeight.w600,
    ),
    iconTheme: const IconThemeData(
          color: textOnPrimary,
      size: 24,
    ),
        systemOverlayStyle: SystemUiOverlayStyle.light,
  );

  /// **卡片主题**
  static CardThemeData get cardTheme => CardThemeData(
        color: cardColor,
        elevation: elevation2,
    shadowColor: shadowColor,
    shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusL),
        ),
        margin: const EdgeInsets.all(spacingS),
        clipBehavior: Clip.antiAlias,
      );

  // =============================================================================
  // 完整主题
  // =============================================================================

  /// **亮色主题**
  static ThemeData get lightTheme => ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primaryColor,
      brightness: Brightness.light,
      primary: primaryColor,
          secondary: secondaryColor,
      surface: surfaceColor,
      error: errorColor,
          onPrimary: textOnPrimary,
          onSecondary: textOnSecondary,
          onSurface: textPrimary,
          onError: textOnError,
          outline: borderColor,
          shadow: shadowColor,
        ),
    textTheme: textTheme,
    elevatedButtonTheme: elevatedButtonTheme,
    outlinedButtonTheme: outlinedButtonTheme,
    textButtonTheme: textButtonTheme,
    inputDecorationTheme: inputDecorationTheme,
    appBarTheme: appBarTheme,
    cardTheme: cardTheme,
    scaffoldBackgroundColor: backgroundColor,
    canvasColor: surfaceColor,
    dividerColor: dividerColor,
    shadowColor: shadowColor,
    iconTheme: const IconThemeData(
          color: textPrimary,
      size: 24,
    ),
    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    visualDensity: VisualDensity.adaptivePlatformDensity,
  );

  /// **暗色主题**
  static ThemeData get darkTheme => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primaryColor,
      brightness: Brightness.dark,
      primary: primaryColor,
          secondary: secondaryColor,
      surface: const Color(0xFF1E1E1E),
      error: errorColor,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: Colors.white,
      onError: Colors.white,
          outline: const Color(0xFF424242),
          shadow: Colors.black54,
    ),
    textTheme: textTheme.apply(
      bodyColor: Colors.white,
      displayColor: Colors.white,
    ),
    scaffoldBackgroundColor: const Color(0xFF121212),
    canvasColor: const Color(0xFF1E1E1E),
    iconTheme: const IconThemeData(
      color: Colors.white,
      size: 24,
    ),
    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    visualDensity: VisualDensity.adaptivePlatformDensity,
  );

  // =============================================================================
  // 辅助方法
  // =============================================================================

  /// **初始化主题系统**
  static Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      LoggerService.info('🎨 初始化主题系统...');

      // 预加载主题到缓存
      _themeCache['light'] = lightTheme;
      _themeCache['dark'] = darkTheme;

      _isInitialized = true;
      _lastHealthCheck = DateTime.now();

      LoggerService.info('✅ 主题系统初始化完成');
    } catch (e) {
      LoggerService.error('❌ 主题系统初始化失败: $e');
      rethrow;
    }
  }

  /// **健康检查**
  static Map<String, dynamic> getHealthStatus() {
    return {
      'isInitialized': _isInitialized,
      'lastHealthCheck': _lastHealthCheck.toIso8601String(),
      'cacheSize': _themeCache.length,
      'status': _isInitialized ? 'healthy' : 'uninitialized',
    };
  }

  /// **根据亮度获取主题**
  static ThemeData getThemeByBrightness(Brightness brightness) {
    return brightness == Brightness.dark ? darkTheme : lightTheme;
  }

  /// **清理缓存**
  static void dispose() {
    _themeCache.clear();
    _isInitialized = false;
    LoggerService.debug('🗑️ 主题系统已清理');
  }

  // =============================================================================
  // 缺少的Getter方法 - Missing Getter Methods
  // =============================================================================

  /// **文字样式Getter**
  static TextStyle get displayLarge =>
      textTheme.displayLarge ?? const TextStyle();
  static TextStyle get displayMedium =>
      textTheme.displayMedium ?? const TextStyle();
  static TextStyle get displaySmall =>
      textTheme.displaySmall ?? const TextStyle();
  static TextStyle get headlineLarge =>
      textTheme.headlineLarge ?? const TextStyle();
  static TextStyle get headlineMedium =>
      textTheme.headlineMedium ?? const TextStyle();
  static TextStyle get headlineSmall =>
      textTheme.headlineSmall ?? const TextStyle();
  static TextStyle get titleLarge => textTheme.titleLarge ?? const TextStyle();
  static TextStyle get titleMedium =>
      textTheme.titleMedium ?? const TextStyle();
  static TextStyle get titleSmall => textTheme.titleSmall ?? const TextStyle();
  static TextStyle get labelLarge => textTheme.labelLarge ?? const TextStyle();
  static TextStyle get labelMedium =>
      textTheme.labelMedium ?? const TextStyle();
  static TextStyle get labelSmall => textTheme.labelSmall ?? const TextStyle();
  static TextStyle get bodyLarge => textTheme.bodyLarge ?? const TextStyle();
  static TextStyle get bodyMedium => textTheme.bodyMedium ?? const TextStyle();
  static TextStyle get bodySmall => textTheme.bodySmall ?? const TextStyle();

  /// **颜色Getter**
  static Color get backgroundLight => backgroundColor;
  static Color get textColor => textPrimary;
  static Color get textSecondaryColor => textSecondary;
  static Color get textHint => textSecondary;

  /// **渐变Getter**
  static Gradient get primaryGradient => LinearGradient(
        colors: [primaryColor, primaryColor.withValues(alpha: 0.8)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  static Gradient get cardGradient => LinearGradient(
        colors: [surfaceColor, surfaceColor.withValues(alpha: 0.95)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      );

  /// **阴影Getter**
  static List<BoxShadow> get cardShadow => [
        BoxShadow(
          color: shadowColor,
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ];

  /// **暗色主题Getter**
  static Color get darkSurface => const Color(0xFF1E1E1E);
  static Color get darkBackground => const Color(0xFF121212);
  static TextStyle get darkTitleLarge =>
      textTheme.titleLarge?.copyWith(color: Colors.white) ?? const TextStyle();
  static TextStyle get darkBodyMedium =>
      textTheme.bodyMedium?.copyWith(color: Colors.white) ?? const TextStyle();
  static Gradient get darkGradient => LinearGradient(
        colors: [darkSurface, darkBackground],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
} 
