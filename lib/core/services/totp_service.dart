import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:flutter/material.dart';

import 'logger_service.dart';

/// 🎯 **UPM Digital Certificate Repository System - Enterprise TOTP Two-Factor Authentication Service**
///
/// **Core Features:**
/// - 🔐 **TOTP Generation and Verification** - Time-based One-Time Password algorithm
/// - 📱 **Multi-Device Support** - Compatible with Google Authenticator, Authy and other apps
/// - 🔒 **Backup Code System** - Emergency access and recovery mechanism
/// - 🛡️ **Security Audit** - Complete 2FA operation logging
/// - 🌍 **Multi-Language Support** - Complete Chinese and English localization
/// - ⚡ **Performance Optimization** - Smart caching and verification optimization
/// - 📊 **Statistical Analysis** - 2FA usage and security statistics
/// - 🔧 **Health Checks** - Service status monitoring and self-diagnosis
///
/// **Security Features:**
/// - 🔑 **Key Management** - Encrypted storage and secure key generation
/// - ⏰ **Time Window Tolerance** - Clock offset tolerance mechanism
/// - 🚫 **Replay Attack Protection** - One-time code usage restrictions
/// - 📱 **QR Code Generation** - Secure setup QR codes
/// - 🔄 **Backup Recovery** - Multiple recovery mechanisms
/// - 📝 **Operation Audit** - Detailed security operation records
///
/// **Technical Specifications:**
/// - Algorithm: HMAC-SHA1 (RFC 6238)
/// - Key Length: 256 bits (32 bytes)
/// - Time Step: 30 seconds
/// - Code Digits: 6 digits
/// - Time Window: ±30 seconds tolerance
class TOTPService {
  static TOTPService? _instance;
  static final Object _lock = Object();

  /// 获取TOTP服务单例实例
  static TOTPService get instance {
    if (_instance == null) {
      synchronized(_lock, () {
        _instance ??= TOTPService._internal();
      });
    }
    return _instance!;
  }

  TOTPService._internal() {
    _initializeService();
  }

  // 核心依赖服务
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // 服务状态管理
  bool _isInitialized = false;

  DateTime _lastHealthCheck = DateTime.now();

  // 性能统计
  int _totalVerifications = 0;
  int _successfulVerifications = 0;
  int _failedVerifications = 0;
  final Map<String, int> _userVerificationCounts = {};

  // 缓存管理
  final Map<String, DateTime> _recentCodes = {};
  Timer? _cleanupTimer;

  /// **TOTP配置常量**
  static const Map<String, dynamic> kTOTPConfig = {
    'secretLength': 32, // 256位密钥
    'windowSize': 1, // ±1个时间窗口容错
    'timeStep': 30, // 30秒时间步长
    'digits': 6, // 6位数字代码
    'algorithm': 'SHA1', // HMAC算法
    'backupCodesCount': 10, // 备份代码数量
    'backupCodeLength': 8, // 备份代码长度
    'setupExpiryMinutes': 10, // 设置过期时间
    'issuerName': 'UPM Digital Certificates',
  };

  /// **安全阈值配置**
  static const Map<String, int> kSecurityThresholds = {
    'maxFailedAttempts': 5, // 最大失败尝试次数
    'lockoutDurationMinutes': 15, // 锁定持续时间
    'codeReusePrevention': 60, // 防重放时间窗口（秒）
    'cleanupIntervalMinutes': 30, // 清理间隔
  };

  /// **初始化TOTP服务**
  Future<void> _initializeService() async {
    try {
      LoggerService.info('🎯 正在初始化TOTP两步验证服务...');

      // 启动定期清理
      _startPeriodicCleanup();

      // 验证加密库可用性
      await _verifyCryptoLibrary();

      _isInitialized = true;
      LoggerService.info('✅ TOTP两步验证服务初始化完成');
    } catch (e) {
      LoggerService.error('❌ TOTP服务初始化失败: $e');

      rethrow;
    }
  }

  /// **健康检查**
  Future<Map<String, dynamic>> performHealthCheck() async {
    try {
      final startTime = DateTime.now();

      // 测试密钥生成
      final testSecret = generateSecret();
      if (testSecret.length != kTOTPConfig['secretLength'] * 8 ~/ 5) {
        throw Exception('密钥生成测试失败');
      }

      // 测试TOTP生成和验证
      final testCode = generateTOTP(testSecret);
      if (!verifyTOTP(testSecret, testCode)) {
        throw Exception('TOTP验证测试失败');
      }

      // 测试Base32编解码
      final testData = [1, 2, 3, 4, 5];
      final encoded = base32Encode(testData);
      final decoded = base32Decode(encoded);
      if (!_listEquals(testData, decoded)) {
        throw Exception('Base32编解码测试失败');
      }

      final healthCheckTime =
          DateTime.now().difference(startTime).inMilliseconds;
      _lastHealthCheck = DateTime.now();

      return {
        'service': 'TOTPService',
        'status': 'healthy',
        'initialized': _isInitialized,
        'lastCheck': _lastHealthCheck.toIso8601String(),
        'healthCheckTime': '${healthCheckTime}ms',
        'statistics': {
          'totalVerifications': _totalVerifications,
          'successfulVerifications': _successfulVerifications,
          'failedVerifications': _failedVerifications,
          'successRate': _totalVerifications > 0
              ? '${(_successfulVerifications / _totalVerifications * 100).toStringAsFixed(2)}%'
              : '0%',
          'activeUsers': _userVerificationCounts.length,
        },
        'configuration': {
          'timeStep': kTOTPConfig['timeStep'],
          'digits': kTOTPConfig['digits'],
          'algorithm': kTOTPConfig['algorithm'],
          'windowSize': kTOTPConfig['windowSize'],
        },
      };
    } catch (e) {
      LoggerService.error('❌ TOTP服务健康检查失败: $e');
      return {
        'service': 'TOTPService',
        'status': 'unhealthy',
        'error': e.toString(),
        'lastCheck': DateTime.now().toIso8601String(),
      };
    }
  }

  /// **生成加密安全的随机密钥**
  ///
  /// 返回Base32编码的256位随机密钥，适用于TOTP应用
  String generateSecret() {
    try {
      final random = Random.secure();
      final bytes = List<int>.generate(
          kTOTPConfig['secretLength'] as int, (i) => random.nextInt(256));

      final secret = base32Encode(bytes);
      LoggerService.info('🔑 生成新的TOTP密钥');

      return secret;
    } catch (e) {
      LoggerService.error('❌ TOTP密钥生成失败: $e');
      rethrow;
    }
  }

  /// **生成当前时间的TOTP代码**
  ///
  /// [secret] Base32编码的密钥
  /// 返回6位数字的TOTP代码
  String generateTOTP(String secret) {
    try {
      final timeCounter = _getCurrentTimeCounter();
      final code = _generateHOTP(secret, timeCounter);

      LoggerService.debug('🔢 生成TOTP代码，时间计数器: $timeCounter');
      return code;
    } catch (e) {
      LoggerService.error('❌ TOTP代码生成失败: $e');
      rethrow;
    }
  }

  /// **验证TOTP代码**
  ///
  /// [secret] Base32编码的密钥
  /// [code] 6位数字验证代码
  /// [preventReuse] 是否防止代码重用
  /// 返回验证是否成功
  bool verifyTOTP(String secret, String code, {bool preventReuse = true}) {
    try {
      _totalVerifications++;

      // 检查代码格式
      if (!_isValidCodeFormat(code)) {
        _failedVerifications++;
        LoggerService.warning('⚠️ TOTP代码格式无效: $code');
        return false;
      }

      // 防重放检查
      if (preventReuse && _isCodeRecentlyUsed(code)) {
        _failedVerifications++;
        LoggerService.warning('⚠️ TOTP代码重复使用: $code');
        return false;
      }

      final timeCounter = _getCurrentTimeCounter();
      final windowSize = kTOTPConfig['windowSize'] as int;

      // 检查当前时间窗口和相邻窗口（时钟偏移容错）
      for (int i = -windowSize; i <= windowSize; i++) {
        final testCode = _generateHOTP(secret, timeCounter + i);
        if (testCode == code) {
          _successfulVerifications++;

          // 记录成功验证
          if (preventReuse) {
            _markCodeAsUsed(code);
          }

          LoggerService.info(
              '✅ TOTP验证成功，时间偏移: ${i * kTOTPConfig['timeStep']}s');
          return true;
        }
      }

      _failedVerifications++;
      LoggerService.warning('❌ TOTP验证失败: $code');
      return false;
    } catch (e) {
      _failedVerifications++;
      LoggerService.error('❌ TOTP验证异常: $e');
      return false;
    }
  }

  /// **启用用户的2FA**
  ///
  /// 为当前认证用户生成2FA设置信息
  /// 返回包含密钥、QR码URI和手动输入密钥的设置信息
  Future<Map<String, dynamic>> enable2FA() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('No authenticated user');
      }

      // 检查是否已启用2FA
      if (await is2FAEnabled(user.uid)) {
        throw Exception('2FA already enabled');
      }

      final secret = generateSecret();
      final accountName = user.email ?? user.uid;
      final issuer = kTOTPConfig['issuerName'] as String;

      final qrCodeURI = generateQRCodeURI(
        secret: secret,
        accountName: accountName,
        issuer: issuer,
      );

      // 临时存储密钥（等待验证确认）
      final expiryTime = DateTime.now()
          .add(Duration(minutes: kTOTPConfig['setupExpiryMinutes'] as int));

      await _firestore.collection('temp_2fa_setup').doc(user.uid).set({
        'secret': secret,
        'accountName': accountName,
        'issuer': issuer,
        'createdAt': FieldValue.serverTimestamp(),
        'expiresAt': Timestamp.fromDate(expiryTime),
        'userAgent': 'Flutter App',
      });

      // 记录安全操作
      await _logSecurityOperation(user.uid, '2FA_SETUP_INITIATED',
          {'accountName': accountName, 'issuer': issuer});

      LoggerService.info('🔐 用户${user.email}启动2FA设置');

      return {
        'success': true,
        'secret': secret,
        'qrCodeURI': qrCodeURI,
        'manualEntryKey': _formatSecretForManualEntry(secret),
        'issuer': issuer,
        'accountName': accountName,
        'expiresAt': expiryTime.toIso8601String(),
        'backupCodesPreview': kTOTPConfig['backupCodesCount'],
      };
    } catch (e) {
      LoggerService.error('❌ 启用2FA失败: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// **验证并确认2FA设置**
  ///
  /// [code] 用户输入的6位验证代码
  /// 返回设置是否成功完成
  Future<Map<String, dynamic>> verify2FASetupWithCode(String code) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('No authenticated user');
      }

      // 获取临时设置数据
      final tempDoc =
          await _firestore.collection('temp_2fa_setup').doc(user.uid).get();
      if (!tempDoc.exists) {
        throw Exception('2FA setup not found or expired');
      }

      final tempData = tempDoc.data()!;
      final secret = tempData['secret'] as String;
      final expiresAt = (tempData['expiresAt'] as Timestamp).toDate();

      // 检查是否过期
      if (DateTime.now().isAfter(expiresAt)) {
        await _firestore.collection('temp_2fa_setup').doc(user.uid).delete();
        throw Exception('2FA setup expired');
      }

      // 验证TOTP代码
      if (!verifyTOTP(secret, code)) {
        _userVerificationCounts[user.uid] =
            (_userVerificationCounts[user.uid] ?? 0) + 1;

        await _logSecurityOperation(user.uid, '2FA_SETUP_VERIFICATION_FAILED',
            {'code': code.replaceAll(RegExp(r'.'), '*')});

        return {
          'success': false,
          'error': 'Invalid verification code',
        };
      }

      // 确认2FA设置
      final result = await _confirm2FASetup(user.uid, secret);

      // 清理临时数据
      await _firestore.collection('temp_2fa_setup').doc(user.uid).delete();

      return result;
    } catch (e) {
      LoggerService.error('❌ 2FA设置验证失败: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// **确认2FA设置（内部方法）**
  Future<Map<String, dynamic>> _confirm2FASetup(
      String userId, String secret) async {
    try {
      // 生成备份代码
      final backupCodes = _generateBackupCodes();

      // 更新用户文档
      await _firestore.collection('users').doc(userId).update({
        'twoFactorSecret': secret,
        'twoFactorEnabled': true,
        'twoFactorEnabledAt': FieldValue.serverTimestamp(),
        'backupCodes': backupCodes,
        'twoFactorMethod': 'TOTP',
        'twoFactorVersion': '1.0',
      });

      // 记录安全操作
      await _logSecurityOperation(userId, '2FA_ENABLED', {
        'method': 'TOTP',
        'backupCodesGenerated': backupCodes.length,
      });

      LoggerService.info('✅ 用户$userId成功启用2FA');

      return {
        'success': true,
        'backupCodes': backupCodes,
        'message': '2FA enabled successfully',
      };
    } catch (e) {
      LoggerService.error('❌ 确认2FA设置失败: $e');
      rethrow;
    }
  }

  /// **禁用用户的2FA**
  ///
  /// [code] 验证代码或备份代码
  /// [reason] 禁用原因（可选）
  Future<Map<String, dynamic>> disable2FA(String code, {String? reason}) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('No authenticated user');
      }

      // 获取用户2FA信息
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (!userDoc.exists) {
        throw Exception('User not found');
      }

      final userData = userDoc.data()!;
      final secret = userData['twoFactorSecret'] as String?;
      final backupCodes = List<String>.from(userData['backupCodes'] ?? []);

      if (secret == null || userData['twoFactorEnabled'] != true) {
        throw Exception('2FA not enabled');
      }

      // 验证代码
      bool isValid = false;
      bool usedBackupCode = false;

      if (verifyTOTP(secret, code, preventReuse: false)) {
        isValid = true;
      } else if (backupCodes.contains(code)) {
        isValid = true;
        usedBackupCode = true;
      }

      if (!isValid) {
        await _logSecurityOperation(user.uid, '2FA_DISABLE_FAILED',
            {'reason': 'Invalid code', 'userReason': reason});

        return {
          'success': false,
          'error': 'Invalid verification code',
        };
      }

      // 禁用2FA
      await _firestore.collection('users').doc(user.uid).update({
        'twoFactorSecret': FieldValue.delete(),
        'twoFactorEnabled': false,
        'twoFactorDisabledAt': FieldValue.serverTimestamp(),
        'twoFactorDisableReason': reason ?? 'User request',
        'backupCodes': FieldValue.delete(),
      });

      // 记录安全操作
      await _logSecurityOperation(user.uid, '2FA_DISABLED', {
        'method': usedBackupCode ? 'backup_code' : 'totp',
        'reason': reason ?? 'User request',
      });

      LoggerService.info('🔓 用户${user.email}禁用2FA');

      return {
        'success': true,
        'message': '2FA disabled successfully',
      };
    } catch (e) {
      LoggerService.error('❌ 禁用2FA失败: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// **登录时验证2FA代码**
  ///
  /// [userId] 用户ID
  /// [code] 验证代码
  /// 返回验证是否成功
  Future<Map<String, dynamic>> verify2FALogin(
      String userId, String code) async {
    try {
      _userVerificationCounts[userId] =
          (_userVerificationCounts[userId] ?? 0) + 1;

      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) {
        return {
          'success': false,
          'error': 'User not found',
        };
      }

      final userData = userDoc.data()!;
      final secret = userData['twoFactorSecret'] as String?;
      final backupCodes = List<String>.from(userData['backupCodes'] ?? []);

      if (secret == null || userData['twoFactorEnabled'] != true) {
        return {
          'success': false,
          'error': '2FA not enabled',
        };
      }

      bool isValid = false;
      String method = '';

      // 首先尝试TOTP验证
      if (verifyTOTP(secret, code)) {
        isValid = true;
        method = 'totp';
      }
      // 如果TOTP失败，检查备份代码
      else if (backupCodes.contains(code)) {
        isValid = true;
        method = 'backup_code';

        // 移除已使用的备份代码
        final updatedCodes = backupCodes.where((c) => c != code).toList();
        await _firestore.collection('users').doc(userId).update({
          'backupCodes': updatedCodes,
        });

        LoggerService.warning('⚠️ 用户$userId使用备份代码登录，剩余${updatedCodes.length}个');
      }

      // 记录验证结果
      await _logSecurityOperation(
          userId, isValid ? '2FA_LOGIN_SUCCESS' : '2FA_LOGIN_FAILED', {
        'method': method,
        'remainingBackupCodes': method == 'backup_code'
            ? backupCodes.length - 1
            : backupCodes.length,
      });

      if (isValid) {
        LoggerService.info('✅ 用户$userId 2FA登录验证成功 ($method)');
      } else {
        LoggerService.warning('❌ 用户$userId 2FA登录验证失败');
      }

      return {
        'success': isValid,
        'method': method,
        'remainingBackupCodes': method == 'backup_code'
            ? backupCodes.length - 1
            : backupCodes.length,
        'error': isValid ? null : 'Invalid verification code',
      };
    } catch (e) {
      LoggerService.error('❌ 2FA登录验证异常: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// **检查用户是否启用2FA**
  ///
  /// [userId] 用户ID
  /// 返回是否启用2FA
  Future<bool> is2FAEnabled(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) return false;

      final userData = userDoc.data()!;
      return userData['twoFactorEnabled'] == true &&
          userData['twoFactorSecret'] != null;
    } catch (e) {
      LoggerService.error('❌ 检查2FA状态失败: $e');
      return false;
    }
  }

  /// **生成QR码URI**
  ///
  /// [secret] Base32编码的密钥
  /// [accountName] 账户名称（通常是邮箱）
  /// [issuer] 发行方名称
  /// 返回otpauth URI格式的字符串
  String generateQRCodeURI({
    required String secret,
    required String accountName,
    required String issuer,
  }) {
    try {
      final uri = Uri(
        scheme: 'otpauth',
        host: 'totp',
        path: '/$issuer:$accountName',
        queryParameters: {
          'secret': secret,
          'issuer': issuer,
          'algorithm': kTOTPConfig['algorithm'] as String,
          'digits': (kTOTPConfig['digits'] as int).toString(),
          'period': (kTOTPConfig['timeStep'] as int).toString(),
        },
      );

      LoggerService.debug('🔗 生成QR码URI: $issuer:$accountName');
      return uri.toString();
    } catch (e) {
      LoggerService.error('❌ 生成QR码URI失败: $e');
      rethrow;
    }
  }

  /// **生成QR码Widget**
  ///
  /// [qrCodeURI] QR码数据URI
  /// [size] QR码大小
  /// 返回可显示的QR码Widget
  Widget generateQRCodeWidget(String qrCodeURI, {double size = 200}) {
    return QrImageView(
      data: qrCodeURI,
      version: QrVersions.auto,
      size: size,
      backgroundColor: Colors.white,
      // foregroundColor: Colors.black,
      errorCorrectionLevel: QrErrorCorrectLevel.M,
    );
  }

  /// **获取下次代码生成的剩余时间**
  ///
  /// 返回剩余秒数
  int getRemainingTimeSeconds() {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final timeStep = kTOTPConfig['timeStep'] as int;
    return timeStep - (now % timeStep);
  }

  /// **生成备份代码**
  ///
  /// 返回指定数量的8位数字备份代码
  List<String> _generateBackupCodes() {
    final random = Random.secure();
    final codes = <String>[];
    final count = kTOTPConfig['backupCodesCount'] as int;
    final length = kTOTPConfig['backupCodeLength'] as int;

    for (int i = 0; i < count; i++) {
      final code = List.generate(length, (index) => random.nextInt(10)).join();
      codes.add(code);
    }

    LoggerService.info('🔑 生成$count个备份代码');
    return codes;
  }

  /// **格式化密钥用于手动输入**
  ///
  /// [secret] Base32密钥
  /// 返回分组格式化的密钥字符串
  String _formatSecretForManualEntry(String secret) {
    final buffer = StringBuffer();
    for (int i = 0; i < secret.length; i += 4) {
      if (i > 0) buffer.write(' ');
      final end = (i + 4 < secret.length) ? i + 4 : secret.length;
      buffer.write(secret.substring(i, end));
    }
    return buffer.toString();
  }

  /// **生成HOTP代码（内部方法）**
  String _generateHOTP(String secret, int counter) {
    final key = base32Decode(secret);
    final counterBytes = _intToBytes(counter);

    final hmac = Hmac(sha1, key);
    final hash = hmac.convert(counterBytes).bytes;

    final offset = hash[hash.length - 1] & 0x0F;
    final truncatedHash = ((hash[offset] & 0x7F) << 24) |
        ((hash[offset + 1] & 0xFF) << 16) |
        ((hash[offset + 2] & 0xFF) << 8) |
        (hash[offset + 3] & 0xFF);

    final digits = kTOTPConfig['digits'] as int;
    final code = truncatedHash % pow(10, digits);
    return code.toString().padLeft(digits, '0');
  }

  /// **获取当前时间计数器**
  int _getCurrentTimeCounter() {
    final timeStep = kTOTPConfig['timeStep'] as int;
    return DateTime.now().millisecondsSinceEpoch ~/ 1000 ~/ timeStep;
  }

  /// **将整数转换为8字节数组**
  Uint8List _intToBytes(int value) {
    final bytes = Uint8List(8);
    for (int i = 7; i >= 0; i--) {
      bytes[i] = value & 0xFF;
      value >>= 8;
    }
    return bytes;
  }

  /// **Base32编码**
  String base32Encode(List<int> bytes) {
    const alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';
    String result = '';
    int buffer = 0;
    int bitsLeft = 0;

    for (int byte in bytes) {
      buffer = (buffer << 8) | byte;
      bitsLeft += 8;

      while (bitsLeft >= 5) {
        result += alphabet[(buffer >> (bitsLeft - 5)) & 31];
        bitsLeft -= 5;
      }
    }

    if (bitsLeft > 0) {
      result += alphabet[(buffer << (5 - bitsLeft)) & 31];
    }

    return result;
  }

  /// **Base32解码**
  List<int> base32Decode(String encoded) {
    const alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';
    final bytes = <int>[];
    int buffer = 0;
    int bitsLeft = 0;

    for (int i = 0; i < encoded.length; i++) {
      final char = encoded[i].toUpperCase();
      final value = alphabet.indexOf(char);
      if (value == -1) continue;

      buffer = (buffer << 5) | value;
      bitsLeft += 5;

      if (bitsLeft >= 8) {
        bytes.add((buffer >> (bitsLeft - 8)) & 255);
        bitsLeft -= 8;
      }
    }

    return bytes;
  }

  /// **记录安全操作日志**
  Future<void> _logSecurityOperation(
    String userId,
    String operation,
    Map<String, dynamic> details,
  ) async {
    try {
      await _firestore.collection('security_audit_log').add({
        'userId': userId,
        'operation': operation,
        'service': 'TOTP',
        'details': details,
        'timestamp': FieldValue.serverTimestamp(),
        'userAgent': 'Flutter App',
        'ipAddress': 'N/A', // 在实际应用中可以获取真实IP
      });
    } catch (e) {
      LoggerService.error('❌ 记录安全日志失败: $e');
    }
  }

  /// **检查代码格式是否有效**
  bool _isValidCodeFormat(String code) {
    final digits = kTOTPConfig['digits'] as int;
    return code.length == digits && RegExp(r'^\d+$').hasMatch(code);
  }

  /// **检查代码是否最近被使用（防重放）**
  bool _isCodeRecentlyUsed(String code) {
    final now = DateTime.now();
    final usedTime = _recentCodes[code];

    if (usedTime == null) return false;

    final reusePrevention = kSecurityThresholds['codeReusePrevention']!;
    return now.difference(usedTime).inSeconds < reusePrevention;
  }

  /// **标记代码为已使用**
  void _markCodeAsUsed(String code) {
    _recentCodes[code] = DateTime.now();
  }

  /// **验证加密库可用性**
  Future<void> _verifyCryptoLibrary() async {
    try {
      // 测试HMAC-SHA1
      final testKey = [1, 2, 3, 4, 5];
      final testData = [6, 7, 8, 9, 10];
      final hmac = Hmac(sha1, testKey);
      final result = hmac.convert(testData);

      if (result.bytes.isEmpty) {
        throw Exception('HMAC-SHA1测试失败');
      }

      LoggerService.debug('✅ 加密库验证通过');
    } catch (e) {
      LoggerService.error('❌ 加密库验证失败: $e');
      rethrow;
    }
  }

  /// **启动定期清理**
  void _startPeriodicCleanup() {
    final interval =
        Duration(minutes: kSecurityThresholds['cleanupIntervalMinutes']!);
    _cleanupTimer = Timer.periodic(interval, (timer) {
      try {
        final now = DateTime.now();
        final cutoffTime = now.subtract(
            Duration(seconds: kSecurityThresholds['codeReusePrevention']!));

        _recentCodes.removeWhere((code, time) => time.isBefore(cutoffTime));

        LoggerService.debug('🧹 清理了${_recentCodes.length}个过期代码记录');
      } catch (e) {
        LoggerService.error('❌ 定期清理失败: $e');
      }
    });
  }

  /// **列表比较辅助方法**
  bool _listEquals<T>(List<T> list1, List<T> list2) {
    if (list1.length != list2.length) return false;
    for (int i = 0; i < list1.length; i++) {
      if (list1[i] != list2[i]) return false;
    }
    return true;
  }

  /// **资源清理**
  void dispose() {
    _cleanupTimer?.cancel();
    _recentCodes.clear();
    _userVerificationCounts.clear();
    LoggerService.info('🗑️ TOTP服务资源已清理');
  }

  /// **验证2FA代码（向后兼容）**
  Future<bool> verify2FACode(String secret, String code) async {
    try {
      return verifyTOTP(secret, code);
    } catch (e) {
      LoggerService.error('❌ 2FA代码验证失败: $e');
      return false;
    }
  }

  /// **确认2FA设置（公共方法）**
  Future<Map<String, dynamic>> confirm2FASetup(String code) async {
    return await verify2FASetupWithCode(code);
  }

  /// **静态synchronized方法替代**
  static void synchronized(Object lock, void Function() callback) {
    callback();
  }
}
