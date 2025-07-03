import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:animate_do/animate_do.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/models/certificate_model.dart';
import '../../../../core/services/logger_service.dart';
import '../../../../core/config/app_config.dart';

class PublicCertificateViewerPage extends ConsumerStatefulWidget {
  final String token;

  const PublicCertificateViewerPage({
    super.key,
    required this.token,
  });

  @override
  ConsumerState<PublicCertificateViewerPage> createState() => _PublicCertificateViewerPageState();
}

class _PublicCertificateViewerPageState extends ConsumerState<PublicCertificateViewerPage> {
  bool _isLoading = true;
  CertificateModel? _certificate;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCertificate();
  }

  Future<void> _loadCertificate() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      // Search for certificate by verification code or share token
      final certificateQuery = await FirebaseFirestore.instance
          .collection(AppConfig.certificatesCollection)
          .where('verificationCode', isEqualTo: widget.token)
          .limit(1)
          .get();

      if (certificateQuery.docs.isNotEmpty) {
        final doc = certificateQuery.docs.first;
        _certificate = CertificateModel.fromFirestore(doc);
        
        // Check if certificate is publicly viewable
        if (_certificate?.status != CertificateStatus.issued) {
          _error = 'Certificate is not available for public viewing';
          _certificate = null;
        }
      } else {
        _error = 'Certificate not found or verification code is invalid';
      }

      LoggerService.info('Public certificate viewed: ${widget.token}');
    } catch (e, stackTrace) {
      LoggerService.error('Error loading public certificate', 
          error: e, stackTrace: stackTrace);
      _error = 'Failed to load certificate: $e';
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Certificate Verification'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: AppTheme.textOnPrimary,
        elevation: 0,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: AppTheme.spacingM),
            Text('Verifying certificate...'),
          ],
        ),
      );
    }

    if (_error != null) {
      return _buildErrorView();
    }

    if (_certificate == null) {
      return _buildNotFoundView();
    }

    return _buildCertificateView();
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingL),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FadeIn(
              child: const Icon(
                Icons.error_outline,
                size: 64,
                color: AppTheme.errorColor,
              ),
            ),
            const SizedBox(height: AppTheme.spacingL),
            FadeInUp(
              delay: const Duration(milliseconds: 200),
              child: Text(
                'Verification Failed',
                style: AppTheme.titleLarge.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.errorColor,
                ),
              ),
            ),
            const SizedBox(height: AppTheme.spacingM),
            FadeInUp(
              delay: const Duration(milliseconds: 400),
              child: Text(
                _error!,
                style: AppTheme.bodyMedium.copyWith(
                  color: AppTheme.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: AppTheme.spacingL),
            FadeInUp(
              delay: const Duration(milliseconds: 600),
              child: ElevatedButton.icon(
                onPressed: _loadCertificate,
                icon: const Icon(Icons.refresh),
                label: const Text('Try Again'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotFoundView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingL),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FadeIn(
              child: const Icon(
                Icons.search_off,
                size: 64,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: AppTheme.spacingL),
            FadeInUp(
              delay: const Duration(milliseconds: 200),
              child: Text(
                'Certificate Not Found',
                style: AppTheme.titleLarge.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: AppTheme.spacingM),
            FadeInUp(
              delay: const Duration(milliseconds: 400),
              child: Text(
                'The certificate you are looking for could not be found or may have been revoked.',
                style: AppTheme.bodyMedium.copyWith(
                  color: AppTheme.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCertificateView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTheme.spacingL),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FadeInUp(
            duration: const Duration(milliseconds: 300),
            child: _buildVerificationStatusCard(),
          ),
          const SizedBox(height: AppTheme.spacingL),
          FadeInUp(
            duration: const Duration(milliseconds: 400),
            child: _buildCertificateInfoCard(),
          ),
          const SizedBox(height: AppTheme.spacingL),
          FadeInUp(
            duration: const Duration(milliseconds: 500),
            child: _buildRecipientInfoCard(),
          ),
          const SizedBox(height: AppTheme.spacingL),
          FadeInUp(
            duration: const Duration(milliseconds: 600),
            child: _buildIssuerInfoCard(),
          ),
        ],
      ),
    );
  }

  Widget _buildVerificationStatusCard() {
    final certificate = _certificate!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingL),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(AppTheme.spacingL),
              decoration: BoxDecoration(
                color: AppTheme.successColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppTheme.radiusL),
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.verified,
                    size: 64,
                    color: AppTheme.successColor,
                  ),
                  const SizedBox(height: AppTheme.spacingM),
                  Text(
                    'Certificate Verified',
                    style: AppTheme.titleLarge.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.successColor,
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacingS),
                  Text(
                    'This is a genuine certificate issued by ${AppConfig.universityName}',
                    style: AppTheme.bodyMedium.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppTheme.spacingL),
            _buildInfoRow('Verification Code', certificate.verificationCode),
            _buildInfoRow('Verification URL', '${AppConfig.verificationBaseUrl}/${certificate.verificationCode}'),
            _buildInfoRow('Issued Date', _formatDate(certificate.issuedAt)),
            if (certificate.expiresAt != null)
              _buildInfoRow('Expires', _formatDate(certificate.expiresAt!)),
          ],
        ),
      ),
    );
  }

  Widget _buildCertificateInfoCard() {
    final certificate = _certificate!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingL),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Certificate Details',
              style: AppTheme.titleMedium.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppTheme.spacingM),
            _buildInfoRow('Title', certificate.title),
            _buildInfoRow('Type', certificate.type.displayName),
            _buildInfoRow('Description', certificate.description.isNotEmpty ? certificate.description : 'No description'),
            if (certificate.grade.isNotEmpty)
              _buildInfoRow('Grade/Score', certificate.grade),
            if (certificate.creditsEarned != null)
              _buildInfoRow('Credits', certificate.creditsEarned.toString()),
          ],
        ),
      ),
    );
  }

  Widget _buildRecipientInfoCard() {
    final certificate = _certificate!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingL),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Recipient Information',
              style: AppTheme.titleMedium.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppTheme.spacingM),
            _buildInfoRow('Name', certificate.recipientName),
            _buildInfoRow('Email', certificate.recipientEmail),
            if (certificate.recipientId.isNotEmpty)
              _buildInfoRow('Student/Staff ID', certificate.recipientId),
          ],
        ),
      ),
    );
  }

  Widget _buildIssuerInfoCard() {
    final certificate = _certificate!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingL),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Issuer Information',
              style: AppTheme.titleMedium.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppTheme.spacingM),
            _buildInfoRow('Issued by', certificate.issuerName),
            if (certificate.issuerTitle?.isNotEmpty == true)
              _buildInfoRow('Title', certificate.issuerTitle!),
            _buildInfoRow('Institution', AppConfig.universityName),
            _buildInfoRow('Digital Signature', certificate.digitalSignature.isNotEmpty 
                ? certificate.digitalSignature.substring(0, 32) 
                : 'Not available'),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppTheme.spacingS),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: AppTheme.bodyMedium.copyWith(
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: AppTheme.bodyMedium.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
} 
