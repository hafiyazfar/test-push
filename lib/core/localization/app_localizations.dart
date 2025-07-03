import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Localization support for the UPM Digital Certificate Repository application.
/// 
/// This class provides internationalization support for multiple languages:
/// - English (en_US) - Primary language
/// - Bahasa Malaysia (ms_MY) - National language  
/// - Chinese Simplified (zh_CN) - International support
/// 
/// Features:
/// - Static text translations
/// - Dynamic text with parameters
/// - Date and time formatting
/// - Number formatting
/// - Pluralization support
/// - Error message localization
/// - Role-based interface translations
class AppLocalizations {
  /// The current locale for this localization instance
  final Locale locale;

  /// Creates an AppLocalizations instance for the given locale
  AppLocalizations(this.locale);

  /// Retrieves the AppLocalizations instance from the widget tree
  /// 
  /// [context] The BuildContext to search for localizations
  /// Returns the AppLocalizations instance or null if not found
  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  /// The delegate used by the Flutter framework to load localizations
  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  /// List of locales supported by this application
  static const List<Locale> supportedLocales = [
    Locale('en', 'US'), // English (United States)
    Locale('ms', 'MY'), // Bahasa Malaysia (Malaysia)
    Locale('zh', 'CN'), // Chinese Simplified (China)
  ];

  /// Gets the current language code (e.g., 'en', 'ms', 'zh')
  String get languageCode => locale.languageCode;

  /// Checks if the current locale is RTL (Right-to-Left)
  bool get isRTL => false; // None of our supported languages are RTL

  // =============================================================================
  // COMMON UI ELEMENTS
  // =============================================================================

  /// Application name
  String get appName => _getSafeLocalizedValue('app_name');
  
  /// Loading indicator text
  String get loading => _getSafeLocalizedValue('loading');
  
  /// Generic error text
  String get error => _getSafeLocalizedValue('error');
  
  /// Generic success text
  String get success => _getSafeLocalizedValue('success');
  
  /// Cancel button text
  String get cancel => _getSafeLocalizedValue('cancel');
  
  /// Confirm button text
  String get confirm => _getSafeLocalizedValue('confirm');
  
  /// Save button text
  String get save => _getSafeLocalizedValue('save');
  
  /// Delete button text
  String get delete => _getSafeLocalizedValue('delete');
  
  /// Edit button text
  String get edit => _getSafeLocalizedValue('edit');
  
  /// Close button text
  String get close => _getSafeLocalizedValue('close');
  
  /// Retry button text
  String get retry => _getSafeLocalizedValue('retry');
  
  /// Continue button text
  String get continueText => _getSafeLocalizedValue('continue');
  
  /// Back button text
  String get back => _getSafeLocalizedValue('back');
  
  /// Next button text
  String get next => _getSafeLocalizedValue('next');
  
  /// Finish button text
  String get finish => _getSafeLocalizedValue('finish');

  // =============================================================================
  // AUTHENTICATION
  // =============================================================================

  /// Login button/page text
  String get login => _getSafeLocalizedValue('login');
  
  /// Logout button text
  String get logout => _getSafeLocalizedValue('logout');
  
  /// Register button/page text
  String get register => _getSafeLocalizedValue('register');
  
  /// Email field label
  String get email => _getSafeLocalizedValue('email');
  
  /// Password field label
  String get password => _getSafeLocalizedValue('password');
  
  /// Confirm password field label
  String get confirmPassword => _getSafeLocalizedValue('confirm_password');
  
  /// Forgot password link text
  String get forgotPassword => _getSafeLocalizedValue('forgot_password');
  
  /// Reset password button text
  String get resetPassword => _getSafeLocalizedValue('reset_password');
  
  /// Remember me checkbox text
  String get rememberMe => _getSafeLocalizedValue('remember_me');
  
  /// Sign in with Google button text
  String get signInWithGoogle => _getSafeLocalizedValue('sign_in_with_google');

  // =============================================================================
  // USER ROLES
  // =============================================================================

  /// Administrator role name
  String get roleAdmin => _getSafeLocalizedValue('role_admin');
  
  /// Certificate Authority role name
  String get roleCA => _getSafeLocalizedValue('role_ca');
  
  /// Client/Reviewer role name
  String get roleClient => _getSafeLocalizedValue('role_client');
  
  /// Student/User role name
  String get roleUser => _getSafeLocalizedValue('role_user');
  
  /// Pending approval status
  String get statusPending => _getSafeLocalizedValue('status_pending');
  
  /// Approved status
  String get statusApproved => _getSafeLocalizedValue('status_approved');
  
  /// Rejected status
  String get statusRejected => _getSafeLocalizedValue('status_rejected');

  // =============================================================================
  // NAVIGATION
  // =============================================================================

  /// Dashboard navigation item
  String get dashboard => _getSafeLocalizedValue('dashboard');
  
  /// Certificates navigation item
  String get certificates => _getSafeLocalizedValue('certificates');
  
  /// Documents navigation item
  String get documents => _getSafeLocalizedValue('documents');
  
  /// Profile navigation item
  String get profile => _getSafeLocalizedValue('profile');
  
  /// Settings navigation item
  String get settings => _getSafeLocalizedValue('settings');
  
  /// Reports navigation item
  String get reports => _getSafeLocalizedValue('reports');
  
  /// Analytics navigation item
  String get analytics => _getSafeLocalizedValue('analytics');
  
  /// Help navigation item
  String get help => _getSafeLocalizedValue('help');

  // =============================================================================
  // CERTIFICATES
  // =============================================================================

  /// Create certificate button text
  String get createCertificate => _getSafeLocalizedValue('create_certificate');
  
  /// Verify certificate button text
  String get verifyCertificate => _getSafeLocalizedValue('verify_certificate');
  
  /// Certificate title field
  String get certificateTitle => _getSafeLocalizedValue('certificate_title');
  
  /// Recipient name field
  String get recipientName => _getSafeLocalizedValue('recipient_name');
  
  /// Issue date field
  String get issueDate => _getSafeLocalizedValue('issue_date');
  
  /// Expiry date field
  String get expiryDate => _getSafeLocalizedValue('expiry_date');
  
  /// Certificate ID field
  String get certificateId => _getSafeLocalizedValue('certificate_id');
  
  /// Template selection
  String get selectTemplate => _getSafeLocalizedValue('select_template');
  
  /// Review certificate action
  String get reviewCertificate => _getSafeLocalizedValue('review_certificate');
  
  /// Approve certificate action
  String get approveCertificate => _getSafeLocalizedValue('approve_certificate');
  
  /// Reject certificate action
  String get rejectCertificate => _getSafeLocalizedValue('reject_certificate');

  // =============================================================================
  // DOCUMENTS
  // =============================================================================

  /// Upload document button
  String get uploadDocument => _getSafeLocalizedValue('upload_document');
  
  /// Document review page title
  String get documentReview => _getSafeLocalizedValue('document_review');
  
  /// Document verification
  String get documentVerification => _getSafeLocalizedValue('document_verification');
  
  /// File name field
  String get fileName => _getSafeLocalizedValue('file_name');
  
  /// File size field
  String get fileSize => _getSafeLocalizedValue('file_size');
  
  /// Upload date field
  String get uploadDate => _getSafeLocalizedValue('upload_date');

  // =============================================================================
  // PROFILE AND SETTINGS
  // =============================================================================

  /// Edit profile button
  String get editProfile => _getSafeLocalizedValue('edit_profile');
  
  /// Change password button
  String get changePassword => _getSafeLocalizedValue('change_password');
  
  /// Language setting
  String get language => _getSafeLocalizedValue('language');
  
  /// Select language prompt
  String get selectLanguage => _getSafeLocalizedValue('select_language');
  
  /// Export data button
  String get exportData => _getSafeLocalizedValue('export_data');
  
  /// First name field
  String get firstName => _getSafeLocalizedValue('first_name');
  
  /// Last name field
  String get lastName => _getSafeLocalizedValue('last_name');
  
  /// Phone number field
  String get phoneNumber => _getSafeLocalizedValue('phone_number');
  
  /// Current password field
  String get currentPassword => _getSafeLocalizedValue('current_password');
  
  /// New password field
  String get newPassword => _getSafeLocalizedValue('new_password');

  // =============================================================================
  // SUPPORT AND HELP
  // =============================================================================

  /// Help and support page title
  String get helpSupport => _getSafeLocalizedValue('help_support');
  
  /// Live chat feature
  String get liveChat => _getSafeLocalizedValue('live_chat');
  
  /// Contact support button
  String get contactSupport => _getSafeLocalizedValue('contact_support');
  
  /// Start chat button
  String get startChat => _getSafeLocalizedValue('start_chat');
  
  /// FAQ section
  String get faq => _getSafeLocalizedValue('faq');
  
  /// User guide
  String get userGuide => _getSafeLocalizedValue('user_guide');
  
  /// Submit feedback
  String get submitFeedback => _getSafeLocalizedValue('submit_feedback');

  // =============================================================================
  // ERROR MESSAGES
  // =============================================================================

  /// Invalid email format error
  String get errorInvalidEmail => _getSafeLocalizedValue('error_invalid_email');
  
  /// Password too short error
  String get errorPasswordTooShort => _getSafeLocalizedValue('error_password_too_short');
  
  /// Passwords don't match error
  String get errorPasswordsNotMatch => _getSafeLocalizedValue('error_passwords_not_match');
  
  /// Network connection error
  String get errorNetworkConnection => _getSafeLocalizedValue('error_network_connection');
  
  /// File upload error
  String get errorFileUpload => _getSafeLocalizedValue('error_file_upload');
  
  /// Invalid file type error
  String get errorInvalidFileType => _getSafeLocalizedValue('error_invalid_file_type');
  
  /// File too large error
  String get errorFileTooLarge => _getSafeLocalizedValue('error_file_too_large');
  
  /// Unauthorized access error
  String get errorUnauthorized => _getSafeLocalizedValue('error_unauthorized');
  
  /// Certificate not found error
  String get errorCertificateNotFound => _getSafeLocalizedValue('error_certificate_not_found');

  // =============================================================================
  // SUCCESS MESSAGES
  // =============================================================================

  /// Language changed successfully
  String get languageChanged => _getSafeLocalizedValue('language_changed');
  
  /// Data exported successfully
  String get dataExported => _getSafeLocalizedValue('data_exported');
  
  /// Chat started successfully
  String get chatStarted => _getSafeLocalizedValue('chat_started');
  
  /// Profile updated successfully
  String get profileUpdated => _getSafeLocalizedValue('profile_updated');
  
  /// Password changed successfully
  String get passwordChanged => _getSafeLocalizedValue('password_changed');
  
  /// Certificate created successfully
  String get certificateCreated => _getSafeLocalizedValue('certificate_created');
  
  /// Document uploaded successfully
  String get documentUploaded => _getSafeLocalizedValue('document_uploaded');

  // =============================================================================
  // DYNAMIC MESSAGES WITH PARAMETERS
  // =============================================================================

  /// Welcome message with user name
  String welcomeUser(String name) => _getParameterizedValue('welcome_user', {'name': name});
  
  /// Certificate expires in X days
  String certificateExpiresIn(int days) => _getParameterizedValue('certificate_expires_in', {'days': days.toString()});
  
  /// X items found
  String itemsFound(int count) => _getParameterizedValue('items_found', {'count': count.toString()});
  
  /// File size limit message
  String fileSizeLimit(String limit) => _getParameterizedValue('file_size_limit', {'limit': limit});
  
  /// Last updated time
  String lastUpdated(String time) => _getParameterizedValue('last_updated', {'time': time});
  
  /// X pending reviews
  String pendingReviews(int count) => _getParameterizedValue('pending_reviews', {'count': count.toString()});

  // =============================================================================
  // DATE AND TIME FORMATTING
  // =============================================================================

  /// Formats a date according to the current locale
  String formatDate(DateTime date) {
    switch (languageCode) {
      case 'ms':
        return DateFormat('dd/MM/yyyy', 'ms_MY').format(date);
      case 'zh':
        return DateFormat('yyyy年MM月dd日', 'zh_CN').format(date);
      default:
        return DateFormat('MM/dd/yyyy', 'en_US').format(date);
    }
  }

  /// Formats a date and time according to the current locale
  String formatDateTime(DateTime dateTime) {
    switch (languageCode) {
      case 'ms':
        return DateFormat('dd/MM/yyyy HH:mm', 'ms_MY').format(dateTime);
      case 'zh':
        return DateFormat('yyyy年MM月dd日 HH:mm', 'zh_CN').format(dateTime);
      default:
        return DateFormat('MM/dd/yyyy HH:mm', 'en_US').format(dateTime);
    }
  }

  /// Formats a time according to the current locale
  String formatTime(DateTime time) {
    switch (languageCode) {
      case 'ms':
      case 'zh':
        return DateFormat('HH:mm').format(time);
      default:
        return DateFormat('h:mm a').format(time);
    }
  }

  // =============================================================================
  // HELPER METHODS
  // =============================================================================

  /// Safely retrieves a localized value with fallback to English
  String _getSafeLocalizedValue(String key) {
    final langValues = _localizedValues[languageCode];
    if (langValues != null && langValues.containsKey(key)) {
      return langValues[key]!;
    }
    
    // Fallback to English
    final enValues = _localizedValues['en'];
    if (enValues != null && enValues.containsKey(key)) {
      return enValues[key]!;
    }
    
    // Last resort fallback
    return '[$key]';
  }

  /// Gets a parameterized localized value with variable substitution
  String _getParameterizedValue(String key, Map<String, String> parameters) {
    String value = _getSafeLocalizedValue(key);
    
    for (final entry in parameters.entries) {
      value = value.replaceAll('{${entry.key}}', entry.value);
    }
    
    return value;
  }

  // =============================================================================
  // LOCALIZED VALUES MAP
  // =============================================================================

  /// Map containing all localized strings for all supported languages
  static const Map<String, Map<String, String>> _localizedValues = {
    'en': {
      // Common
      'app_name': 'UPM Digital Certificates',
      'loading': 'Loading...',
      'error': 'Error',
      'success': 'Success',
      'cancel': 'Cancel',
      'confirm': 'Confirm',
      'save': 'Save',
      'delete': 'Delete',
      'edit': 'Edit',
      'close': 'Close',
      'retry': 'Retry',
      'continue': 'Continue',
      'back': 'Back',
      'next': 'Next',
      'finish': 'Finish',

      // Authentication
      'login': 'Login',
      'logout': 'Logout',
      'register': 'Register',
      'email': 'Email',
      'password': 'Password',
      'confirm_password': 'Confirm Password',
      'forgot_password': 'Forgot Password',
      'reset_password': 'Reset Password',
      'remember_me': 'Remember Me',
      'sign_in_with_google': 'Sign in with Google',

      // User Roles
      'role_admin': 'Administrator',
      'role_ca': 'Certificate Authority',
      'role_client': 'Client Reviewer',
      'role_user': 'Student',
      'status_pending': 'Pending',
      'status_approved': 'Approved',
      'status_rejected': 'Rejected',

      // Navigation
      'dashboard': 'Dashboard',
      'certificates': 'Certificates',
      'documents': 'Documents',
      'profile': 'Profile',
      'settings': 'Settings',
      'reports': 'Reports',
      'analytics': 'Analytics',
      'help': 'Help',

      // Certificates
      'create_certificate': 'Create Certificate',
      'verify_certificate': 'Verify Certificate',
      'certificate_title': 'Certificate Title',
      'recipient_name': 'Recipient Name',
      'issue_date': 'Issue Date',
      'expiry_date': 'Expiry Date',
      'certificate_id': 'Certificate ID',
      'select_template': 'Select Template',
      'review_certificate': 'Review Certificate',
      'approve_certificate': 'Approve Certificate',
      'reject_certificate': 'Reject Certificate',

      // Documents
      'upload_document': 'Upload Document',
      'document_review': 'Document Review',
      'document_verification': 'Document Verification',
      'file_name': 'File Name',
      'file_size': 'File Size',
      'upload_date': 'Upload Date',

      // Profile and Settings
      'edit_profile': 'Edit Profile',
      'change_password': 'Change Password',
      'language': 'Language',
      'select_language': 'Select Language',
      'export_data': 'Export Data',
      'first_name': 'First Name',
      'last_name': 'Last Name',
      'phone_number': 'Phone Number',
      'current_password': 'Current Password',
      'new_password': 'New Password',

      // Support
      'help_support': 'Help & Support',
      'live_chat': 'Live Chat',
      'contact_support': 'Contact Support',
      'start_chat': 'Start Chat',
      'faq': 'FAQ',
      'user_guide': 'User Guide',
      'submit_feedback': 'Submit Feedback',

      // Error Messages
      'error_invalid_email': 'Please enter a valid email address',
      'error_password_too_short': 'Password must be at least 8 characters',
      'error_passwords_not_match': 'Passwords do not match',
      'error_network_connection': 'Network connection error',
      'error_file_upload': 'File upload failed',
      'error_invalid_file_type': 'Invalid file type',
      'error_file_too_large': 'File size is too large',
      'error_unauthorized': 'You are not authorized to perform this action',
      'error_certificate_not_found': 'Certificate not found',

      // Success Messages
      'language_changed': 'Language changed successfully',
      'data_exported': 'Data exported successfully',
      'chat_started': 'Chat session started',
      'profile_updated': 'Profile updated successfully',
      'password_changed': 'Password changed successfully',
      'certificate_created': 'Certificate created successfully',
      'document_uploaded': 'Document uploaded successfully',

      // Parameterized Messages
      'welcome_user': 'Welcome, {name}!',
      'certificate_expires_in': 'Certificate expires in {days} days',
      'items_found': '{count} items found',
      'file_size_limit': 'Maximum file size: {limit}',
      'last_updated': 'Last updated: {time}',
      'pending_reviews': '{count} pending reviews',
    },

    'ms': {
      // Common
      'app_name': 'Sijil Digital UPM',
      'loading': 'Memuatkan...',
      'error': 'Ralat',
      'success': 'Berjaya',
      'cancel': 'Batal',
      'confirm': 'Sahkan',
      'save': 'Simpan',
      'delete': 'Padam',
      'edit': 'Edit',
      'close': 'Tutup',
      'retry': 'Cuba Lagi',
      'continue': 'Teruskan',
      'back': 'Kembali',
      'next': 'Seterusnya',
      'finish': 'Selesai',

      // Authentication
      'login': 'Log Masuk',
      'logout': 'Log Keluar',
      'register': 'Daftar',
      'email': 'E-mel',
      'password': 'Kata Laluan',
      'confirm_password': 'Sahkan Kata Laluan',
      'forgot_password': 'Lupa Kata Laluan',
      'reset_password': 'Set Semula Kata Laluan',
      'remember_me': 'Ingat Saya',
      'sign_in_with_google': 'Log masuk dengan Google',

      // User Roles
      'role_admin': 'Pentadbir',
      'role_ca': 'Pihak Berkuasa Sijil',
      'role_client': 'Penyemak Pelanggan',
      'role_user': 'Pelajar',
      'status_pending': 'Menunggu',
      'status_approved': 'Diluluskan',
      'status_rejected': 'Ditolak',

      // Navigation
      'dashboard': 'Papan Pemuka',
      'certificates': 'Sijil',
      'documents': 'Dokumen',
      'profile': 'Profil',
      'settings': 'Tetapan',
      'reports': 'Laporan',
      'analytics': 'Analitik',
      'help': 'Bantuan',

      // Certificates
      'create_certificate': 'Cipta Sijil',
      'verify_certificate': 'Sahkan Sijil',
      'certificate_title': 'Tajuk Sijil',
      'recipient_name': 'Nama Penerima',
      'issue_date': 'Tarikh Dikeluarkan',
      'expiry_date': 'Tarikh Tamat',
      'certificate_id': 'ID Sijil',
      'select_template': 'Pilih Templat',
      'review_certificate': 'Semak Sijil',
      'approve_certificate': 'Luluskan Sijil',
      'reject_certificate': 'Tolak Sijil',

      // Documents
      'upload_document': 'Muat Naik Dokumen',
      'document_review': 'Semakan Dokumen',
      'document_verification': 'Pengesahan Dokumen',
      'file_name': 'Nama Fail',
      'file_size': 'Saiz Fail',
      'upload_date': 'Tarikh Muat Naik',

      // Profile and Settings
      'edit_profile': 'Edit Profil',
      'change_password': 'Tukar Kata Laluan',
      'language': 'Bahasa',
      'select_language': 'Pilih Bahasa',
      'export_data': 'Eksport Data',
      'first_name': 'Nama Pertama',
      'last_name': 'Nama Akhir',
      'phone_number': 'Nombor Telefon',
      'current_password': 'Kata Laluan Semasa',
      'new_password': 'Kata Laluan Baru',

      // Support
      'help_support': 'Bantuan & Sokongan',
      'live_chat': 'Sembang Langsung',
      'contact_support': 'Hubungi Sokongan',
      'start_chat': 'Mula Sembang',
      'faq': 'Soalan Lazim',
      'user_guide': 'Panduan Pengguna',
      'submit_feedback': 'Hantar Maklum Balas',

      // Error Messages
      'error_invalid_email': 'Sila masukkan alamat e-mel yang sah',
      'error_password_too_short': 'Kata laluan mestilah sekurang-kurangnya 8 aksara',
      'error_passwords_not_match': 'Kata laluan tidak sepadan',
      'error_network_connection': 'Ralat sambungan rangkaian',
      'error_file_upload': 'Muat naik fail gagal',
      'error_invalid_file_type': 'Jenis fail tidak sah',
      'error_file_too_large': 'Saiz fail terlalu besar',
      'error_unauthorized': 'Anda tidak diberi kuasa untuk melakukan tindakan ini',
      'error_certificate_not_found': 'Sijil tidak dijumpai',

      // Success Messages
      'language_changed': 'Bahasa berjaya ditukar',
      'data_exported': 'Data berjaya dieksport',
      'chat_started': 'Sesi sembang dimulakan',
      'profile_updated': 'Profil berjaya dikemaskini',
      'password_changed': 'Kata laluan berjaya ditukar',
      'certificate_created': 'Sijil berjaya dicipta',
      'document_uploaded': 'Dokumen berjaya dimuat naik',

      // Parameterized Messages
      'welcome_user': 'Selamat datang, {name}!',
      'certificate_expires_in': 'Sijil tamat tempoh dalam {days} hari',
      'items_found': '{count} item dijumpai',
      'file_size_limit': 'Saiz fail maksimum: {limit}',
      'last_updated': 'Kemaskini terakhir: {time}',
      'pending_reviews': '{count} semakan tertangguh',
    },

    'zh': {
      // Common
      'app_name': 'UPM数字证书',
      'loading': '加载中...',
      'error': '错误',
      'success': '成功',
      'cancel': '取消',
      'confirm': '确认',
      'save': '保存',
      'delete': '删除',
      'edit': '编辑',
      'close': '关闭',
      'retry': '重试',
      'continue': '继续',
      'back': '返回',
      'next': '下一步',
      'finish': '完成',

      // Authentication
      'login': '登录',
      'logout': '登出',
      'register': '注册',
      'email': '电子邮件',
      'password': '密码',
      'confirm_password': '确认密码',
      'forgot_password': '忘记密码',
      'reset_password': '重置密码',
      'remember_me': '记住我',
      'sign_in_with_google': '使用Google登录',

      // User Roles
      'role_admin': '管理员',
      'role_ca': '证书授权机构',
      'role_client': '客户审查员',
      'role_user': '学生',
      'status_pending': '待处理',
      'status_approved': '已批准',
      'status_rejected': '已拒绝',

      // Navigation
      'dashboard': '仪表板',
      'certificates': '证书',
      'documents': '文档',
      'profile': '个人资料',
      'settings': '设置',
      'reports': '报告',
      'analytics': '分析',
      'help': '帮助',

      // Certificates
      'create_certificate': '创建证书',
      'verify_certificate': '验证证书',
      'certificate_title': '证书标题',
      'recipient_name': '接收者姓名',
      'issue_date': '颁发日期',
      'expiry_date': '到期日期',
      'certificate_id': '证书编号',
      'select_template': '选择模板',
      'review_certificate': '审查证书',
      'approve_certificate': '批准证书',
      'reject_certificate': '拒绝证书',

      // Documents
      'upload_document': '上传文档',
      'document_review': '文档审查',
      'document_verification': '文档验证',
      'file_name': '文件名',
      'file_size': '文件大小',
      'upload_date': '上传日期',

      // Profile and Settings
      'edit_profile': '编辑个人资料',
      'change_password': '更改密码',
      'language': '语言',
      'select_language': '选择语言',
      'export_data': '导出数据',
      'first_name': '名字',
      'last_name': '姓氏',
      'phone_number': '电话号码',
      'current_password': '当前密码',
      'new_password': '新密码',

      // Support
      'help_support': '帮助与支持',
      'live_chat': '在线聊天',
      'contact_support': '联系支持',
      'start_chat': '开始聊天',
      'faq': '常见问题',
      'user_guide': '用户指南',
      'submit_feedback': '提交反馈',

      // Error Messages
      'error_invalid_email': '请输入有效的电子邮件地址',
      'error_password_too_short': '密码必须至少8个字符',
      'error_passwords_not_match': '密码不匹配',
      'error_network_connection': '网络连接错误',
      'error_file_upload': '文件上传失败',
      'error_invalid_file_type': '无效的文件类型',
      'error_file_too_large': '文件大小过大',
      'error_unauthorized': '您无权执行此操作',
      'error_certificate_not_found': '找不到证书',

      // Success Messages
      'language_changed': '语言更改成功',
      'data_exported': '数据导出成功',
      'chat_started': '聊天会话已开始',
      'profile_updated': '个人资料更新成功',
      'password_changed': '密码更改成功',
      'certificate_created': '证书创建成功',
      'document_uploaded': '文档上传成功',

      // Parameterized Messages
      'welcome_user': '欢迎，{name}！',
      'certificate_expires_in': '证书将在{days}天后过期',
      'items_found': '找到{count}个项目',
      'file_size_limit': '最大文件大小：{limit}',
      'last_updated': '最后更新：{time}',
      'pending_reviews': '{count}个待审查项目',
    },
  };
}

/// Delegate class for loading AppLocalizations
/// 
/// This class is used by Flutter's localization system to determine
/// which locales are supported and how to load the appropriate
/// localization instance.
class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  /// Creates a const delegate instance
  const _AppLocalizationsDelegate();

  /// Determines if the given locale is supported by this delegate
  /// 
  /// [locale] The locale to check for support
  /// Returns true if the locale is supported, false otherwise
  @override
  bool isSupported(Locale locale) {
    return ['en', 'ms', 'zh'].contains(locale.languageCode);
  }

  /// Loads the AppLocalizations instance for the given locale
  /// 
  /// [locale] The locale to load localizations for
  /// Returns a Future that completes with the AppLocalizations instance
  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(locale);
  }

  /// Determines if the localizations should be reloaded
  /// 
  /// [old] The previous delegate instance
  /// Returns false as localizations are static and don't need reloading
  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
} 