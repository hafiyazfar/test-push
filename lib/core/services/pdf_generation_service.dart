import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/certificate_model.dart';
import '../config/app_config.dart';
import 'logger_service.dart';
import 'localization_service.dart';

///  **UPM???????? - PDF????**
class PdfGenerationService {
  static PdfGenerationService? _instance;

  /// ??PDF????????
  static PdfGenerationService get instance {
    return _instance ??= PdfGenerationService._internal();
  }

  PdfGenerationService._internal() {
    _initializeService();
  }

  // ??????
  bool _isInitialized = false;
  // ignore: unused_field

  // ignore: unused_field

  // ignore: unused_field

  DateTime _lastHealthCheck = DateTime.now();

  // ????
  int _totalGenerated = 0;
  int _totalErrors = 0;
  // ignore: unused_field
  double _averageGenerationTime = 0.0;
  final List<double> _generationTimes = [];

  // ????
  final Map<String, pw.Font> _fontCache = {};
  final Map<String, pw.ImageProvider> _imageCache = {};

  /// **PDF??????**
  static const Map<String, dynamic> kPdfConfig = {
    'maxFileSize': 50 * 1024 * 1024, // 50MB
    'defaultPageFormat': 'A4',
    'supportedFormats': ['A4', 'A3', 'Letter', 'Legal'],
    'maxBatchSize': 100,
    'cacheExpiryHours': 24,
    'compressionLevel': 6,
  };

  /// **UPM??????**
  static const Map<String, PdfColor> kUpmColors = {
    'primary': PdfColor.fromInt(0xFF1E3A8A), // UPM??
    'secondary': PdfColor.fromInt(0xFF059669), // UPM??
    'accent': PdfColor.fromInt(0xFFD97706), // UPM??
    'text': PdfColor.fromInt(0xFF374151),
    'textLight': PdfColor.fromInt(0xFF6B7280),
    'background': PdfColor.fromInt(0xFFF9FAFB),
    'border': PdfColor.fromInt(0xFFD1D5DB),
  };

  /// **???PDF????**
  Future<void> _initializeService() async {
    try {
      LoggerService.i(' ?????PDF????...');
      await _preloadFonts();
      _isInitialized = true;
      LoggerService.i(' PDF?????????');
    } catch (e) {
      LoggerService.e(' PDF?????????: ');
    }
  }

  /// **????**
  Future<Map<String, dynamic>> performHealthCheck() async {
    try {
      _lastHealthCheck = DateTime.now();

      return {
        'service': 'PdfGenerationService',
        'status': 'healthy',
        'initialized': _isInitialized,
        'lastCheck': _lastHealthCheck.toIso8601String(),
        'statistics': {
          'totalGenerated': _totalGenerated,
          'totalErrors': _totalErrors,
          'averageGenerationTime': 'ms',
          'cacheSize': _imageCache.length + _fontCache.length,
        },
      };
    } catch (e) {
      LoggerService.e(' PDF??????????: ');
      return {
        'service': 'PdfGenerationService',
        'status': 'unhealthy',
        'error': e.toString(),
        'lastCheck': DateTime.now().toIso8601String(),
      };
    }
  }

  /// **??????PDF**
  Future<Uint8List> generateCertificatePdf({
    required CertificateModel certificate,
    String templateType = 'certificate',
    Map<String, dynamic>? customization,
    String? locale,
  }) async {
    final startTime = DateTime.now();

    try {
      LoggerService.i(' ??????PDF: ');

      _validateCertificateInput(certificate);

      if (!_isInitialized) {
        await _initializeService();
      }

      final effectiveLocale = locale ?? 'en';

      final pdf = pw.Document(
        title: _getLocalizedText('certificate_title', effectiveLocale),
        author: AppConfig.appName,
        creator: 'UPM Certificate Repository',
        subject: certificate.typeDisplayName.isNotEmpty
            ? certificate.typeDisplayName
            : certificate.type.name,
        keywords: [certificate.type.name, 'certificate', 'UPM'].join(','),
      );

      final templateAssets =
          await _loadTemplateAssets(templateType, customization);

      pdf.addPage(
        pw.Page(
          pageFormat: _getPageFormat(customization?['pageFormat']),
          margin: const pw.EdgeInsets.all(40),
          build: (pw.Context context) => _buildCertificatePage(
            certificate,
            templateAssets,
            effectiveLocale,
            customization,
          ),
        ),
      );

      final pdfBytes = await pdf.save();
      _validateGeneratedPdf(pdfBytes);
      _updateStatistics(startTime);

      LoggerService.i(' ??PDF????:  bytes');
      return pdfBytes;
    } catch (e) {
      _totalErrors++;
      LoggerService.e(' ??PDF????: ');
      rethrow;
    }
  }

  /// **??PDF**
  Future<void> printPdf(Uint8List pdfBytes, {String? jobName}) async {
    try {
      await Printing.layoutPdf(
        name: jobName ?? 'UPM Certificate',
        onLayout: (PdfPageFormat format) async => pdfBytes,
      );
      LoggerService.i(' PDF???????');
    } catch (e) {
      LoggerService.e(' PDF????: ');
      rethrow;
    }
  }

  /// **??PDF**
  Future<void> sharePdf(
    Uint8List pdfBytes,
    String fileName, {
    String? subject,
  }) async {
    try {
      await Printing.sharePdf(
        bytes: pdfBytes,
        filename: '.pdf',
        subject: subject ?? _getLocalizedText('share_certificate_subject'),
      );
      LoggerService.i(' PDF????');
    } catch (e) {
      LoggerService.e(' PDF????: ');
      rethrow;
    }
  }

  /// **????????**
  pw.Widget _buildCertificatePage(
    CertificateModel certificate,
    Map<String, dynamic> templateAssets,
    String locale,
    Map<String, dynamic>? customization,
  ) {
    final fonts = templateAssets['fonts'] as Map<String, pw.Font>;

    return pw.Container(
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          _buildPdfHeader(certificate, fonts['bold']!, locale),
          pw.SizedBox(height: 40),
          _buildCertificateTitle(certificate, fonts['bold']!, locale),
          pw.SizedBox(height: 40),
          _buildCertificateBody(certificate, fonts, locale),
          pw.Spacer(),
          _buildPdfFooter(certificate, fonts, locale),
        ],
      ),
    );
  }

  /// **??PDF??**
  pw.Widget _buildPdfHeader(
    CertificateModel certificate,
    pw.Font fontBold,
    String locale,
  ) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              certificate.organizationName.isNotEmpty
                  ? certificate.organizationName
                  : 'UPM',
              style: pw.TextStyle(
                font: fontBold,
                fontSize: 16,
                color: kUpmColors['primary'],
              ),
            ),
            pw.Text(
              _getLocalizedText('official_certificate', locale),
              style: pw.TextStyle(
                font: fontBold,
                fontSize: 12,
                color: kUpmColors['textLight'],
              ),
            ),
          ],
        ),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Text(
              _getLocalizedText('certificate_id', locale),
              style: pw.TextStyle(
                font: fontBold,
                fontSize: 12,
                color: kUpmColors['textLight'],
              ),
            ),
            pw.Text(
              certificate.verificationId,
              style: pw.TextStyle(
                font: fontBold,
                fontSize: 14,
                color: kUpmColors['text'],
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// **??????**
  pw.Widget _buildCertificateTitle(
    CertificateModel certificate,
    pw.Font fontBold,
    String locale,
  ) {
    return pw.Column(
      children: [
        pw.Text(
          _getLocalizedText('certificate', locale).toUpperCase(),
          style: pw.TextStyle(
            font: fontBold,
            fontSize: 36,
            color: kUpmColors['primary'],
            letterSpacing: 2,
          ),
        ),
        pw.SizedBox(height: 10),
        pw.Text(
          _getLocalizedCertificateType(certificate.type, locale),
          style: pw.TextStyle(
            font: fontBold,
            fontSize: 18,
            color: kUpmColors['secondary'],
          ),
        ),
      ],
    );
  }

  /// **????????**
  pw.Widget _buildCertificateBody(
    CertificateModel certificate,
    Map<String, pw.Font> fonts,
    String locale,
  ) {
    return pw.Column(
      children: [
        pw.Text(
          _getLocalizedText('this_certifies_that', locale),
          style: pw.TextStyle(
            font: fonts['regular']!,
            fontSize: 16,
            color: kUpmColors['textLight'],
          ),
        ),
        pw.SizedBox(height: 20),
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(vertical: 15, horizontal: 30),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: kUpmColors['primary']!, width: 2),
            borderRadius: pw.BorderRadius.circular(10),
          ),
          child: pw.Text(
            certificate.recipientName,
            style: pw.TextStyle(
              font: fonts['bold']!,
              fontSize: 28,
              color: kUpmColors['primary'],
            ),
          ),
        ),
        pw.SizedBox(height: 30),
        pw.Container(
          width: 400,
          child: pw.Text(
            certificate.description,
            style: pw.TextStyle(
              font: fonts['regular']!,
              fontSize: 14,
              color: kUpmColors['text'],
              lineSpacing: 5,
            ),
            textAlign: pw.TextAlign.center,
          ),
        ),
      ],
    );
  }

  /// **??PDF??**
  pw.Widget _buildPdfFooter(
    CertificateModel certificate,
    Map<String, pw.Font> fonts,
    String locale,
  ) {
    final qrCodeData = _generateQRCodeData(certificate);

    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      crossAxisAlignment: pw.CrossAxisAlignment.end,
      children: [
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Container(
              width: 200,
              height: 1,
              color: kUpmColors['border'],
            ),
            pw.SizedBox(height: 5),
            pw.Text(
              _getLocalizedText('authorized_signature', locale),
              style: pw.TextStyle(
                font: fonts['regular']!,
                fontSize: 12,
                color: kUpmColors['textLight'],
              ),
            ),
            pw.Text(
              certificate.organizationName.isNotEmpty
                  ? certificate.organizationName
                  : 'UPM',
              style: pw.TextStyle(
                font: fonts['bold']!,
                fontSize: 14,
                color: kUpmColors['text'],
              ),
            ),
          ],
        ),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.BarcodeWidget(
              barcode: pw.Barcode.qrCode(),
              data: qrCodeData,
              width: 80,
              height: 80,
            ),
            pw.SizedBox(height: 5),
            pw.Text(
              _getLocalizedText('verify_certificate', locale),
              style: pw.TextStyle(
                font: fonts['regular']!,
                fontSize: 10,
                color: kUpmColors['textLight'],
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// **???????**
  Future<void> _preloadFonts() async {
    try {
      LoggerService.i(' ???????...');
      final interRegular = await PdfGoogleFonts.interRegular();
      final interBold = await PdfGoogleFonts.interBold();

      _fontCache['regular'] = interRegular;
      _fontCache['bold'] = interBold;

      LoggerService.i(' ?????????');
    } catch (e) {
      LoggerService.e(' ???????: ');
      rethrow;
    }
  }

  /// **????**
  void _validateCertificateInput(CertificateModel certificate) {
    if (certificate.recipientName.trim().isEmpty) {
      throw ArgumentError('?????????');
    }
    if (certificate.verificationId.trim().isEmpty) {
      throw ArgumentError('??ID????');
    }
  }

  /// **?????PDF**
  void _validateGeneratedPdf(Uint8List pdfBytes) {
    if (pdfBytes.isEmpty) {
      throw Exception('???PDF????');
    }
    if (pdfBytes.length > kPdfConfig['maxFileSize']) {
      throw Exception('???PDF????:  bytes');
    }
  }

  /// **???????**
  String _generateQRCodeData(CertificateModel certificate) {
    final baseUrl = AppConfig.verificationBaseUrl;
    return '$baseUrl/verify/${certificate.verificationId}';
  }

  /// **???????**
  String _getLocalizedText(String key, [String? locale]) {
    return LocalizationService.getText(key);
  }

  /// **?????????**
  String _getLocalizedCertificateType(CertificateType type, String locale) {
    final key = 'certificate_type_';
    return _getLocalizedText(key, locale);
  }

  /// **??????**
  PdfPageFormat _getPageFormat(String? format) {
    switch (format?.toUpperCase()) {
      case 'A3':
        return PdfPageFormat.a3;
      case 'LETTER':
        return PdfPageFormat.letter;
      case 'LEGAL':
        return PdfPageFormat.legal;
      default:
        return PdfPageFormat.a4;
    }
  }

  /// **??????**
  Future<Map<String, dynamic>> _loadTemplateAssets(
      String templateType, Map<String, dynamic>? customization) async {
    final fonts = Map<String, pw.Font>.from(_fontCache);
    return {
      'fonts': fonts,
    };
  }

  void _updateStatistics(DateTime startTime) {
    _totalGenerated++;
    final generationTime =
        DateTime.now().difference(startTime).inMilliseconds.toDouble();
    _generationTimes.add(generationTime);
    if (_generationTimes.length > 100) {
      _generationTimes.removeAt(0);
    }
    _averageGenerationTime =
        _generationTimes.reduce((a, b) => a + b) / _generationTimes.length;
  }
}
