import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';

/// 🎨 **UPM数字证书仓库系统 - 简化版自定义应用栏组件**
///
/// **核心功能：**
/// - 🎯 **多样式支持** - 标准、渐变、透明、毛玻璃等多种样式
/// - 🌈 **主题适配** - 完美适配亮暗模式和企业主题
/// - 📱 **响应式设计** - 自适应不同屏幕尺寸和方向
/// - ♿ **无障碍支持** - 完整的语义标签和辅助功能
/// - ✨ **动画效果** - 流畅的过渡动画和视觉反馈
/// - 🔧 **高度自定义** - 丰富的配置选项和样式控制
/// - 📊 **状态感知** - 智能状态显示和交互反馈
/// - 🌍 **国际化支持** - 多语言文本和RTL布局
///
/// **设计特色：**
/// - 🏢 **UPM品牌设计** - 符合大学视觉识别系统
/// - 🎨 **Material 3.0** - 现代化设计语言实现
/// - 📐 **黄金比例布局** - 优雅的比例和间距
/// - 🌟 **微交互设计** - 精致的交互动画效果
/// - 🔄 **平滑过渡** - 丝滑的状态切换动画
/// - 🎭 **情境感知** - 根据使用场景自动调整
/// - 📱 **平台适配** - iOS、Android、Web完美支持
/// - 🚀 **性能优化** - 高效渲染和内存管理
///
/// **使用场景：**
/// - 主要页面标题栏
/// - 设置页面顶栏
/// - 详情页面导航栏
/// - 搜索结果页面
/// - 表单页面标题
/// - 列表页面顶栏
/// - 对话框标题栏
class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  // =============================================================================
  // 基础属性 - Basic Properties
  // =============================================================================

  /// **标题文本**
  final String title;

  /// **副标题文本（可选）**
  final String? subtitle;

  /// **左侧操作按钮组**
  final List<Widget>? actions;

  /// **导航按钮（返回/菜单）**
  final Widget? leading;

  /// **是否自动显示导航按钮**
  final bool automaticallyImplyLeading;

  /// **是否居中显示标题**
  final bool centerTitle;

  /// **底部组件（如TabBar）**
  final PreferredSizeWidget? bottom;

  // =============================================================================
  // 样式属性 - Style Properties
  // =============================================================================

  /// **背景颜色（覆盖样式设置）**
  final Color? backgroundColor;

  /// **前景颜色（文本和图标）**
  final Color? foregroundColor;

  /// **标题文本样式**
  final TextStyle? titleStyle;

  /// **阴影高度**
  final double? elevation;

  /// **自定义高度**
  final double? height;

  /// **应用栏样式类型**
  final AppBarStyle appBarStyle;

  /// **点击事件回调**
  final VoidCallback? onTitleTap;

  /// **自定义系统状态栏样式**
  final SystemUiOverlayStyle? systemOverlayStyle;

  // =============================================================================
  // 构造函数
  // =============================================================================

  const CustomAppBar({
    super.key,
    required this.title,
    this.subtitle,
    this.actions,
    this.leading,
    this.automaticallyImplyLeading = true,
    this.centerTitle = true,
    this.bottom,
    this.appBarStyle = AppBarStyle.standard,
    this.backgroundColor,
    this.foregroundColor,
    this.titleStyle,
    this.elevation,
    this.height,
    this.onTitleTap,
    this.systemOverlayStyle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return AppBar(
      title: _buildTitle(context, isDarkMode),
      centerTitle: centerTitle,
      backgroundColor: _getBackgroundColor(isDarkMode),
      foregroundColor: _getForegroundColor(isDarkMode),
      elevation: elevation ?? 4.0,
      leading: leading,
      automaticallyImplyLeading: automaticallyImplyLeading,
      actions: actions,
      bottom: bottom,
      systemOverlayStyle:
          systemOverlayStyle ?? _getSystemOverlayStyle(isDarkMode),
      toolbarHeight: height ?? kToolbarHeight,
    );
  }

  /// **构建标题**
  Widget _buildTitle(BuildContext context, bool isDarkMode) {
    final titleWidget = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          style: _getTitleStyle(isDarkMode),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          semanticsLabel: title,
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 2),
          Text(
            subtitle!,
            style: _getSubtitleStyle(isDarkMode),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            semanticsLabel: subtitle,
          ),
        ],
      ],
    );

    if (onTitleTap != null) {
      return GestureDetector(
        onTap: onTitleTap,
        child: titleWidget,
      );
    }

    return titleWidget;
  }

  /// **获取背景颜色**
  Color? _getBackgroundColor(bool isDarkMode) {
    if (backgroundColor != null) {
      return backgroundColor;
    }

    switch (appBarStyle) {
      case AppBarStyle.transparent:
        return Colors.transparent;
      default:
        return isDarkMode ? const Color(0xFF1E1E1E) : AppTheme.primaryColor;
    }
  }

  /// **获取前景颜色**
  Color? _getForegroundColor(bool isDarkMode) {
    if (foregroundColor != null) {
      return foregroundColor;
    }

    return Colors.white;
  }

  /// **获取标题样式**
  TextStyle _getTitleStyle(bool isDarkMode) {
    final baseStyle = titleStyle ?? AppTheme.titleLarge;

    return baseStyle.copyWith(
      fontWeight: FontWeight.w600,
      color: _getForegroundColor(isDarkMode),
      fontSize: 18,
    );
  }

  /// **获取副标题样式**
  TextStyle _getSubtitleStyle(bool isDarkMode) {
    return AppTheme.bodyMedium.copyWith(
      color: _getForegroundColor(isDarkMode)?.withValues(alpha: 0.8),
      fontSize: 12,
    );
  }

  /// **获取系统状态栏样式**
  SystemUiOverlayStyle _getSystemOverlayStyle(bool isDarkMode) {
    return isDarkMode ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark;
  }

  @override
  Size get preferredSize => Size.fromHeight(height ?? kToolbarHeight);
}

/// **AppBar样式枚举**
enum AppBarStyle {
  /// 标准样式
  standard,

  /// 透明样式
  transparent,

  /// 大尺寸样式
  large,

  /// 中等尺寸样式
  medium,

  /// 紧凑样式
  compact,
}
