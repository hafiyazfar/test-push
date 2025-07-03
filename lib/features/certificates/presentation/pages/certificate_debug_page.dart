import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/services/logger_service.dart';

class CertificateDebugPage extends ConsumerStatefulWidget {
  const CertificateDebugPage({super.key});

  @override
  ConsumerState<CertificateDebugPage> createState() => _CertificateDebugPageState();
}

class _CertificateDebugPageState extends ConsumerState<CertificateDebugPage> {
  List<Map<String, dynamic>> certificates = [];
  bool isLoading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _loadCertificates();
  }

  Future<void> _loadCertificates() async {
    try {
      setState(() {
        isLoading = true;
        error = null;
      });

      // Load all certificates without any query filters
      final snapshot = await FirebaseFirestore.instance
          .collection('certificates')
          .get();

      LoggerService.info('Found ${snapshot.docs.length} certificates in Firestore');

      final certs = snapshot.docs.map((doc) {
        final data = doc.data();
        data['documentId'] = doc.id;
        return data;
      }).toList();

      setState(() {
        certificates = certs;
        isLoading = false;
      });
    } catch (e) {
      LoggerService.error('Failed to load certificates', error: e);
      setState(() {
        error = e.toString();
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Certificate Debug'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Error: $error'),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadCertificates,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : certificates.isEmpty
                  ? const Center(
                      child: Text('No certificates found in Firestore'),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: certificates.length,
                      itemBuilder: (context, index) {
                        final cert = certificates[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 16),
                          child: ExpansionTile(
                            title: Text(
                              cert['title'] ?? 'No title',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('ID: ${cert['documentId']}'),
                                Text('Recipient: ${cert['recipientEmail'] ?? 'Unknown'}'),
                                Text('Issuer ID: ${cert['issuerId'] ?? 'Unknown'}'),
                                Text('Recipient ID: ${cert['recipientId'] ?? 'Unknown'}'),
                                Text('Status: ${cert['status'] ?? 'Unknown'}'),
                              ],
                            ),
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Full Data:',
                                      style: TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(height: 8),
                                    SelectableText(
                                      cert.toString(),
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
    );
  }
} 