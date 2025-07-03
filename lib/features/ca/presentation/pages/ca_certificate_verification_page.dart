import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/custom_app_bar.dart';
import '../../../../core/services/logger_service.dart';
import '../../../auth/providers/auth_providers.dart';

class CACertificateVerificationPage extends ConsumerStatefulWidget {
  const CACertificateVerificationPage({super.key});

  @override
  ConsumerState<CACertificateVerificationPage> createState() =>
      _CACertificateVerificationPageState();
}

class _CACertificateVerificationPageState
    extends ConsumerState<CACertificateVerificationPage> {
  final _certificateIdController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isVerifying = false;
  Map<String, dynamic>? _verificationResult;

  @override
  void dispose() {
    _certificateIdController.dispose();
    super.dispose();
  }

  Future<void> _verifyCertificate(String certificateId) async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isVerifying = true;
      _verificationResult = null;
    });

    try {
      // 真实的Firebase证书验证逻辑
      final certificateDoc = await FirebaseFirestore.instance
          .collection('certificates')
          .doc(certificateId)
          .get();

      if (certificateDoc.exists) {
        final data = certificateDoc.data()!;
        final status = data['status'] as String? ?? 'unknown';

        // 只有已发布的证书才被认为是有效的
        final isValid = status == 'issued' || status == 'active';

        if (isValid) {
          setState(() {
            _verificationResult = {
              'isValid': true,
              'certificateId': certificateId,
              'holderName': data['recipientName'] ?? 'Unknown',
              'issuerName':
                  data['issuerName'] ?? 'UPM Digital Certificate Authority',
              'issueDate': (data['issuedAt'] as Timestamp?)?.toDate(),
              'expiryDate': (data['expiresAt'] as Timestamp?)?.toDate(),
              'templateName': data['templateName'] ?? 'Unknown Template',
              'certificateType': data['type'] ?? 'Certificate',
              'verificationCode': data['verificationCode'] ?? certificateId,
            };
          });

          // 记录验证活动
          await _recordVerificationActivity(certificateId, true);
        } else {
          setState(() {
            _verificationResult = {
              'isValid': false,
              'certificateId': certificateId,
              'reason': 'Certificate status is $status',
            };
          });

          await _recordVerificationActivity(certificateId, false);
        }
      } else {
        setState(() {
          _verificationResult = {
            'isValid': false,
            'certificateId': certificateId,
            'reason': 'Certificate not found',
          };
        });

        await _recordVerificationActivity(certificateId, false);
      }

      LoggerService.info(
          'Certificate verification completed for ID: $certificateId');
    } catch (e) {
      LoggerService.error('Certificate verification failed', error: e);
      setState(() {
        _verificationResult = {
          'isValid': false,
          'certificateId': certificateId,
          'reason': 'Verification system error',
        };
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Verification failed: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } finally {
      setState(() {
        _isVerifying = false;
      });
    }
  }

  Future<void> _recordVerificationActivity(
      String certificateId, bool isValid) async {
    try {
      final currentUser = ref.read(currentUserProvider).value;
      if (currentUser != null) {
        await FirebaseFirestore.instance
            .collection('certificate_verifications')
            .add({
          'certificateId': certificateId,
          'verifiedBy': currentUser.id,
          'verifierName': currentUser.displayName,
          'verifierRole': currentUser.userType.name,
          'isValid': isValid,
          'verifiedAt': FieldValue.serverTimestamp(),
          'verificationMethod': 'manual_input',
        });
      }
    } catch (e) {
      LoggerService.error('Failed to record verification activity', error: e);
    }
  }

  Widget _buildManualInput() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Manual Verification',
                style: AppTheme.titleMedium.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _certificateIdController,
                decoration: const InputDecoration(
                  labelText: 'Certificate ID',
                  hintText: 'Enter certificate ID',
                  prefixIcon: Icon(Icons.verified),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a certificate ID';
                  }
                  if (value.trim().length < 10) {
                    return 'Certificate ID must be at least 10 characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isVerifying
                      ? null
                      : () => _verifyCertificate(
                          _certificateIdController.text.trim()),
                  child: _isVerifying
                      ? const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            SizedBox(width: 8),
                            Text('Verifying...'),
                          ],
                        )
                      : const Text('Verify Certificate'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVerificationResult() {
    if (_verificationResult == null) return const SizedBox.shrink();

    final isValid = _verificationResult!['isValid'] as bool;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isValid ? Icons.check_circle : Icons.error,
                  color: isValid ? AppTheme.successColor : AppTheme.errorColor,
                  size: 32,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    isValid ? 'Certificate Valid' : 'Certificate Invalid',
                    style: AppTheme.titleLarge.copyWith(
                      color:
                          isValid ? AppTheme.successColor : AppTheme.errorColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            if (isValid) ...[
              const SizedBox(height: 16),
              _buildDetailRow(
                  'Certificate ID', _verificationResult!['certificateId']),
              _buildDetailRow(
                  'Holder Name', _verificationResult!['holderName']),
              _buildDetailRow('Issuer', _verificationResult!['issuerName']),
              _buildDetailRow(
                  'Certificate Type', _verificationResult!['certificateType']),
              _buildDetailRow('Template', _verificationResult!['templateName']),
              _buildDetailRow(
                  'Issue Date', _formatDate(_verificationResult!['issueDate'])),
              _buildDetailRow('Expiry Date',
                  _formatDate(_verificationResult!['expiryDate'])),
              _buildDetailRow('Verification Code',
                  _verificationResult!['verificationCode']),
            ] else ...[
              const SizedBox(height: 16),
              _buildDetailRow(
                  'Certificate ID', _verificationResult!['certificateId']),
              _buildDetailRow('Reason', _verificationResult!['reason']),
            ],
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.backgroundLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 16,
                    color: AppTheme.textSecondary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isValid
                          ? 'This certificate has been verified as authentic and is currently valid.'
                          : 'This certificate could not be verified. Please check the certificate ID and try again.',
                      style: AppTheme.bodySmall.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: AppTheme.bodyMedium.copyWith(
                fontWeight: FontWeight.w500,
                color: AppTheme.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value ?? 'N/A',
              style: AppTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'N/A';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(
        title: 'Certificate Verification',
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Verify Certificate Authenticity',
              style: AppTheme.headlineSmall.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Enter a certificate ID to verify its authenticity and view details. This verification system connects to our secure database to ensure certificate validity.',
              style: AppTheme.bodyLarge.copyWith(
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 24),
            _buildManualInput(),
            const SizedBox(height: 16),
            _buildVerificationResult(),
          ],
        ),
      ),
    );
  }
}
