import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:logger/logger.dart';
import 'package:crypto/crypto.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';

import '../models/document_model.dart';
import '../models/user_model.dart';
import '../config/app_config.dart';
import 'logger_service.dart';
import 'system_interaction_service.dart';

/// Document Management Service for the UPM Digital Certificate Repository.
///
/// This service provides comprehensive document management capabilities including:
/// - Multi-platform document upload (Web & Mobile)
/// - Document verification and approval workflow
/// - Advanced search and filtering
/// - Secure document sharing with tokens
/// - Role-based access control
/// - Document statistics and analytics
/// - File integrity verification with hash
///
/// Features:
/// - Platform-agnostic file handling
/// - Firebase Storage integration
/// - Metadata extraction and validation
/// - Share tokens with expiration and password protection
/// - Complete audit trail and access logging
/// - Advanced search with multiple filters
/// - Document statistics and reporting
///
/// Workflow:
/// 1. User uploads document (web or mobile)
/// 2. System extracts metadata and calculates hash
/// 3. CA verifies document authenticity
/// 4. Document becomes available for sharing/access
/// 5. Complete access logging throughout
class DocumentService {
  // =============================================================================
  // CONSTANTS
  // =============================================================================

  /// Collection name for documents
  // ignore: unused_field
  static const String _documentsCollection = 'documents';

  /// Collection name for access logs
  static const String _accessLogsCollection = 'document_access_logs';

  /// Collection name for activities
  static const String _activitiesCollection = 'activities';

  /// Collection name for users
  // ignore: unused_field
  static const String _usersCollection = 'users';

  /// Regular expression for file name sanitization
  // ignore: unused_field
  static const String _fileNameSanitizeRegex = r'[^\w\s.-]';

  /// Regular expression for whitespace replacement
  // ignore: unused_field
  static const String _whitespaceRegex = r'\\s+';

  /// Default file encoding
  // ignore: unused_field
  static const String _defaultEncoding = 'utf-8';

  /// Storage path prefix for documents
  // ignore: unused_field
  static const String _storagePathPrefix = 'documents';

  /// Maximum document file size (10MB)
  static const int _maxDocumentSize = 10 * 1024 * 1024;

  /// Maximum file size in MB for display
  static const int _maxFileSizeMB = 10;

  // =============================================================================
  // DEPENDENCIES
  // =============================================================================

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final Logger _logger = Logger();

  // =============================================================================
  // STATE MANAGEMENT
  // =============================================================================

  bool _isInitialized = false;

  // =============================================================================
  // GETTERS
  // =============================================================================

  /// Whether the service is healthy and operational
  bool get isHealthy => _isInitialized;

  /// Collection references
  CollectionReference get _documentsRef =>
      _firestore.collection(AppConfig.documentsCollection);
  CollectionReference get _accessLogsRef =>
      _firestore.collection(_accessLogsCollection);

  // =============================================================================
  // INITIALIZATION
  // =============================================================================

  /// Initialize the document service
  Future<void> initialize() async {
    try {
      LoggerService.info('Initializing document service...');

      // Test Firebase connectivity
      await _firestore.collection(AppConfig.documentsCollection).limit(1).get();

      _isInitialized = true;
      LoggerService.info('Document service initialized successfully');
    } catch (e, stackTrace) {
      LoggerService.error('Failed to initialize document service',
          error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  // Upload Document - Web Compatible Version
  Future<DocumentModel> uploadDocumentWeb({
    required String name,
    required String description,
    required DocumentType type,
    required String uploadedBy,
    required Uint8List fileBytes,
    required String fileName,
    required int fileSize,
    required String mimeType,
    String? associatedCertificateId,
    VerificationLevel verificationLevel = VerificationLevel.basic,
    List<String> allowedUsers = const [],
    Map<String, dynamic>? metadata,
    List<String> tags = const [],
  }) async {
    try {
      _logger.i('Starting web document upload: $fileName');

      // Validate inputs
      if (fileBytes.isEmpty) {
        throw Exception('File is empty');
      }
      if (fileSize > _maxDocumentSize) {
        throw Exception('File size exceeds limit of ${_maxFileSizeMB}MB');
      }

      // Generate unique document ID
      final documentId = _generateDocumentId();

      // Create storage path with proper structure
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final sanitizedFileName = _sanitizeFileName(fileName);
      final storagePath =
          '${AppConfig.documentsStoragePath}/$uploadedBy/${timestamp}_${documentId}_$sanitizedFileName';

      _logger.i('Uploading to storage path: $storagePath');

      // Upload to Firebase Storage with error handling
      final storageRef = _storage.ref().child(storagePath);

      String downloadUrl;
      try {
        // Upload with metadata
        final uploadTask = await storageRef.putData(
          fileBytes,
          SettableMetadata(
            contentType: mimeType,
            customMetadata: {
              'uploadedBy': uploadedBy,
              'documentId': documentId,
              'originalFileName': fileName,
              'uploadTime': DateTime.now().toIso8601String(),
            },
          ),
        );

        // Get download URL
        downloadUrl = await uploadTask.ref.getDownloadURL();
        _logger.i('File uploaded to storage successfully: $downloadUrl');
      } catch (storageError) {
        _logger.e('Firebase Storage upload failed: $storageError');
        throw Exception('Failed to upload file to storage: $storageError');
      }

      // Calculate file hash for integrity
      final fileHash = _calculateFileHash(fileBytes);

      // Extract metadata from file bytes
      final extractedMetadata =
          await _extractFileMetadataFromBytes(fileBytes, mimeType);

      // Get uploader name
      String uploaderName = uploadedBy;
      try {
        final userDoc =
            await _firestore.collection('users').doc(uploadedBy).get();
        if (userDoc.exists) {
          uploaderName = userDoc.data()?['displayName'] ?? uploadedBy;
        }
      } catch (e) {
        _logger.w('Could not fetch uploader name: $e');
      }

      // Create document model with proper timestamps
      final now = DateTime.now();
      final document = DocumentModel(
        id: documentId,
        name: name,
        description: description,
        type: type,
        status: DocumentStatus.uploaded,
        uploaderId: uploadedBy,
        uploaderName: uploaderName,
        uploadedAt: now,
        updatedAt: now,
        fileUrl: downloadUrl,
        fileName: sanitizedFileName,
        fileSize: fileSize,
        mimeType: mimeType,
        hash: fileHash,
        verificationLevel: verificationLevel,
        verificationStatus: VerificationStatus.pending,
        associatedCertificateId: associatedCertificateId,
        accessLevel: AccessLevel.restricted,
        allowedUsers: allowedUsers,
        tags: tags,
        metadata: DocumentMetadata(
          technicalDetails: extractedMetadata,
          customFields: {
            ...metadata ?? {},
            'storagePath': storagePath,
            'originalFileName': fileName,
          },
        ),
        accessHistory: [],
        shareTokens: [],
      );

      // Save to Firestore with transaction
      try {
        await _firestore.runTransaction((transaction) async {
          // Set document
          final documentData = document.toMap();
          transaction.set(_documentsRef.doc(documentId), documentData);

          // 🔍 DEBUG: Log document data being saved
          _logger.i('📄 Saving document data: $documentData');
          _logger.i('📄 Document uploaderId: $uploadedBy, name: $name');

          // Create initial activity log
          final activityRef =
              _firestore.collection(_activitiesCollection).doc();
          transaction.set(activityRef, {
            'type': 'document_upload',
            'documentId': documentId,
            'userId': uploadedBy,
            'action': 'uploaded',
            'timestamp': FieldValue.serverTimestamp(),
            'details': {
              'fileName': fileName,
              'fileSize': fileSize,
              'mimeType': mimeType,
              'type': type.name,
            },
          });
        });

        _logger.i('✅ Document saved to Firestore successfully: $documentId');
      } catch (firestoreError) {
        _logger.e('Firestore save failed: $firestoreError');
        // Try to delete uploaded file if Firestore save fails
        try {
          await storageRef.delete();
          _logger.i('Cleaned up storage file after Firestore error');
        } catch (cleanupError) {
          _logger.e('Failed to cleanup storage file: $cleanupError');
        }
        throw Exception('Failed to save document data: $firestoreError');
      }

      // Log access (non-critical, don't fail if this fails)
      try {
        await _logDocumentAccess(
          documentId: documentId,
          userId: uploadedBy,
          action: DocumentAccessAction.uploaded,
          details: 'Document uploaded via web',
        );
      } catch (logError) {
        _logger.w('Failed to log document access: $logError');
      }

      // 🔄 CRITICAL: Notify CA system about new document upload
      try {
        final systemInteractionService = SystemInteractionService();
        await systemInteractionService.handleDocumentUploaded(
          documentId: documentId,
          documentName: name,
          uploaderId: uploadedBy,
          uploaderName: uploaderName,
          documentType: type.name,
          documentData: {
            'fileName': sanitizedFileName,
            'fileSize': fileSize,
            'mimeType': mimeType,
            'category': metadata?['category'] ?? 'Unknown',
            'uploadedAt': now.toIso8601String(),
            'fileUrl': downloadUrl,
            'description': description,
          },
        );
        _logger.i('✅ CA notified about document upload: $documentId');
      } catch (e) {
        _logger.w('⚠️ Failed to notify CA about document upload: $e');
        // Don't fail the upload if notification fails
      }

      _logger.i('Document uploaded successfully (Web): $documentId');
      return document;
    } catch (e) {
      _logger.e('Error uploading document (Web): $e');
      rethrow;
    }
  }

  // Upload Document - Platform Agnostic
  Future<DocumentModel> uploadDocument({
    required String name,
    required String description,
    required DocumentType type,
    required String uploadedBy,
    required String filePath,
    required int fileSize,
    required String mimeType,
    String? associatedCertificateId,
    VerificationLevel verificationLevel = VerificationLevel.basic,
    List<String> allowedUsers = const [],
    Map<String, dynamic>? metadata,
    List<String> tags = const [],
  }) async {
    try {
      // For Web platform, this should not be called
      if (kIsWeb) {
        throw UnsupportedError('Use uploadDocumentWeb for web platform');
      }

      // Generate unique document ID
      final documentId = _generateDocumentId();

      // Upload file to Firebase Storage
      final file = File(filePath);
      final fileName = '${documentId}_$name';
      final storageRef = _storage.ref().child('documents/$fileName');

      final uploadTask = await storageRef.putFile(file);
      final downloadUrl = await uploadTask.ref.getDownloadURL();

      // Calculate file hash for integrity
      final fileBytes = await file.readAsBytes();
      final fileHash = _calculateFileHash(fileBytes);

      // Extract metadata from file
      final extractedMetadata = await _extractFileMetadata(file, mimeType);

      // Create document model
      final document = DocumentModel(
        id: documentId,
        name: name,
        description: description,
        type: type,
        status: DocumentStatus.uploaded,
        uploaderId: uploadedBy,
        uploaderName: uploadedBy,
        uploadedAt: DateTime.now(),
        updatedAt: DateTime.now(),
        fileUrl: downloadUrl,
        fileName: fileName,
        fileSize: fileSize,
        mimeType: mimeType,
        hash: fileHash,
        verificationLevel: verificationLevel,
        verificationStatus: VerificationStatus.pending,
        associatedCertificateId: associatedCertificateId,
        accessLevel: AccessLevel.restricted,
        allowedUsers: allowedUsers,
        tags: tags,
        metadata: DocumentMetadata(
          technicalDetails: extractedMetadata,
          customFields: metadata ?? {},
        ),
        accessHistory: [],
        shareTokens: [],
      );

      // Save to Firestore
      await _documentsRef.doc(documentId).set(document.toMap());

      // Log access
      await _logDocumentAccess(
        documentId: documentId,
        userId: uploadedBy,
        action: DocumentAccessAction.uploaded,
        details: 'Document uploaded',
      );

      _logger.i('Document uploaded successfully: $documentId');
      return document;
    } catch (e) {
      _logger.e('Error uploading document: $e');
      rethrow;
    }
  }

  // Get Document by ID
  Future<DocumentModel?> getDocumentById(String documentId) async {
    try {
      final doc = await _documentsRef.doc(documentId).get();
      if (doc.exists) {
        return DocumentModel.fromMap(doc.data() as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      _logger.e('Error getting document: $e');
      rethrow;
    }
  }

  // Get Documents by User
  Future<List<DocumentModel>> getDocumentsByUser({
    required String userId,
    UserRole? userRole,
    List<DocumentType>? types,
    List<VerificationStatus>? statuses,
    int? limit,
  }) async {
    try {
      Query query = _documentsRef;

      // Filter based on user role and permissions
      if (userRole == UserRole.systemAdmin) {
        // Admin can see all documents
      } else {
        // Users can only see documents they uploaded or have access to
        query = query.where(Filter.or(
          Filter('uploadedBy', isEqualTo: userId),
          Filter('allowedUsers', arrayContains: userId),
        ));
      }

      // Filter by type
      if (types != null && types.isNotEmpty) {
        query = query.where('type', whereIn: types.map((t) => t.name).toList());
      }

      // Filter by status
      if (statuses != null && statuses.isNotEmpty) {
        query = query.where('verificationStatus',
            whereIn: statuses.map((s) => s.name).toList());
      }

      // Add limit
      if (limit != null) {
        query = query.limit(limit);
      }

      // Order by upload date
      query = query.orderBy('uploadedAt', descending: true);

      final querySnapshot = await query.get();
      return querySnapshot.docs
          .map((doc) =>
              DocumentModel.fromMap(doc.data() as Map<String, dynamic>))
          .toList();
    } catch (e) {
      _logger.e('Error getting documents by user: $e');
      rethrow;
    }
  }

  // Search Documents
  Future<List<DocumentModel>> searchDocuments({
    String? searchTerm,
    DocumentType? type,
    List<VerificationStatus>? statuses,
    DateTime? startDate,
    DateTime? endDate,
    List<String>? tags,
    String? userId,
    UserRole? userRole,
    int? limit,
  }) async {
    try {
      Query query = _documentsRef;

      // Apply user-based filtering
      if (userRole != UserRole.systemAdmin && userId != null) {
        query = query.where(Filter.or(
          Filter('uploadedBy', isEqualTo: userId),
          Filter('allowedUsers', arrayContains: userId),
        ));
      }

      // Filter by type
      if (type != null) {
        query = query.where('type', isEqualTo: type.name);
      }

      // Filter by status
      if (statuses != null && statuses.isNotEmpty) {
        query = query.where('verificationStatus',
            whereIn: statuses.map((s) => s.name).toList());
      }

      // Filter by date range
      if (startDate != null) {
        query = query.where('uploadedAt', isGreaterThanOrEqualTo: startDate);
      }
      if (endDate != null) {
        query = query.where('uploadedAt', isLessThanOrEqualTo: endDate);
      }

      // Add limit
      if (limit != null) {
        query = query.limit(limit);
      }

      query = query.orderBy('uploadedAt', descending: true);

      final querySnapshot = await query.get();
      List<DocumentModel> documents = querySnapshot.docs
          .map((doc) =>
              DocumentModel.fromMap(doc.data() as Map<String, dynamic>))
          .toList();

      // Apply additional filters that can't be done in Firestore query
      if (searchTerm != null && searchTerm.isNotEmpty) {
        final searchLower = searchTerm.toLowerCase();
        documents = documents
            .where((doc) =>
                doc.name.toLowerCase().contains(searchLower) ||
                doc.description.toLowerCase().contains(searchLower))
            .toList();
      }

      if (tags != null && tags.isNotEmpty) {
        documents = documents
            .where((doc) => doc.tags.any((tag) => tags.contains(tag)))
            .toList();
      }

      return documents;
    } catch (e) {
      _logger.e('Error searching documents: $e');
      rethrow;
    }
  }

  // Update Document
  Future<void> updateDocument(
    String documentId,
    Map<String, dynamic> updates,
    String updatedBy,
  ) async {
    try {
      updates['updatedAt'] = FieldValue.serverTimestamp();

      await _documentsRef.doc(documentId).update(updates);

      await _logDocumentAccess(
        documentId: documentId,
        userId: updatedBy,
        action: DocumentAccessAction.modified,
        details: 'Document updated: ${updates.keys.join(', ')}',
      );

      _logger.i('Document updated: $documentId');
    } catch (e) {
      _logger.e('Error updating document: $e');
      rethrow;
    }
  }

  // Verify Document
  Future<void> verifyDocument(
    String documentId,
    String verifiedBy,
    VerificationStatus status, {
    String? verificationNotes,
    Map<String, dynamic>? verificationData,
  }) async {
    try {
      final updates = <String, dynamic>{
        'verificationStatus': status.name,
        'verifiedBy': verifiedBy,
        'verifiedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (verificationNotes != null) {
        updates['verificationNotes'] = verificationNotes;
      }
      if (verificationData != null) {
        updates['verificationData'] = verificationData;
      }

      await _documentsRef.doc(documentId).update(updates);

      await _logDocumentAccess(
        documentId: documentId,
        userId: verifiedBy,
        action: DocumentAccessAction.verified,
        details: 'Document verification: ${status.name}',
      );

      _logger.i('Document verified: $documentId');
    } catch (e) {
      _logger.e('Error verifying document: $e');
      rethrow;
    }
  }

  // Generate Share Token
  Future<String> generateShareToken({
    required String documentId,
    required String sharedBy,
    required Duration validity,
    String? password,
    int? maxAccess,
  }) async {
    try {
      final token = _generateShareToken();
      final expiresAt = DateTime.now().add(validity);

      final shareData = ShareToken(
        token: token,
        documentId: documentId,
        sharedBy: sharedBy,
        createdAt: DateTime.now(),
        expiresAt: expiresAt,
        password: password,
        maxAccess: maxAccess,
        currentAccess: 0,
        isActive: true,
      );

      // Update document with new share token
      await _documentsRef.doc(documentId).update({
        'shareTokens': FieldValue.arrayUnion([shareData.toMap()]),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await _logDocumentAccess(
        documentId: documentId,
        userId: sharedBy,
        action: DocumentAccessAction.shared,
        details: 'Share token generated',
      );

      _logger.i('Share token generated for document: $documentId');
      return token;
    } catch (e) {
      _logger.e('Error generating share token: $e');
      rethrow;
    }
  }

  // Access Document via Token
  Future<DocumentModel?> accessDocumentViaToken({
    required String token,
    String? password,
    required String accessedBy,
  }) async {
    try {
      // Find document with this token
      final querySnapshot = await _documentsRef
          .where('shareTokens', arrayContains: {'token': token})
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        throw Exception('Invalid token');
      }

      final doc = querySnapshot.docs.first;
      final document =
          DocumentModel.fromMap(doc.data() as Map<String, dynamic>);

      // Find the specific token
      final shareToken = document.shareTokens.firstWhere(
        (t) => t.token == token,
        orElse: () => throw Exception('Token not found'),
      );

      // Validate token
      if (!shareToken.isActive) {
        throw Exception('Token is inactive');
      }
      if (shareToken.expiresAt.isBefore(DateTime.now())) {
        throw Exception('Token has expired');
      }
      if (shareToken.maxAccess != null &&
          shareToken.currentAccess >= shareToken.maxAccess!) {
        throw Exception('Token access limit reached');
      }
      if (shareToken.password != null && shareToken.password != password) {
        throw Exception('Invalid password');
      }

      // Update access count
      final updatedTokens = document.shareTokens.map((t) {
        if (t.token == token) {
          return ShareToken(
            token: t.token,
            documentId: t.documentId,
            sharedBy: t.sharedBy,
            createdAt: t.createdAt,
            expiresAt: t.expiresAt,
            password: t.password,
            maxAccess: t.maxAccess,
            currentAccess: t.currentAccess + 1,
            isActive: t.isActive,
          );
        }
        return t;
      }).toList();

      await _documentsRef.doc(document.id).update({
        'shareTokens': updatedTokens.map((t) => t.toMap()).toList(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await _logDocumentAccess(
        documentId: document.id,
        userId: accessedBy,
        action: DocumentAccessAction.accessed,
        details: 'Accessed via share token',
      );

      return document;
    } catch (e) {
      _logger.e('Error accessing document via token: $e');
      rethrow;
    }
  }

  // Delete Document
  Future<void> deleteDocument(String documentId, String deletedBy) async {
    try {
      final document = await getDocumentById(documentId);
      if (document == null) {
        throw Exception('Document not found');
      }

      // Delete file from storage
      try {
        final storageRef = _storage.refFromURL(document.fileUrl);
        await storageRef.delete();
      } catch (e) {
        _logger.w('Error deleting file from storage: $e');
        // Continue with document deletion even if file deletion fails
      }

      // Delete document from Firestore
      await _documentsRef.doc(documentId).delete();

      await _logDocumentAccess(
        documentId: documentId,
        userId: deletedBy,
        action: DocumentAccessAction.deleted,
        details: 'Document deleted',
      );

      _logger.i('Document deleted: $documentId');
    } catch (e) {
      _logger.e('Error deleting document: $e');
      rethrow;
    }
  }

  // Get Document Statistics
  Future<DocumentStatistics> getDocumentStatistics({
    String? userId,
    UserRole? userRole,
  }) async {
    try {
      Query query = _documentsRef;

      if (userRole != UserRole.systemAdmin && userId != null) {
        query = query.where(Filter.or(
          Filter('uploadedBy', isEqualTo: userId),
          Filter('allowedUsers', arrayContains: userId),
        ));
      }

      final querySnapshot = await query.get();
      final documents = querySnapshot.docs
          .map((doc) =>
              DocumentModel.fromMap(doc.data() as Map<String, dynamic>))
          .toList();

      return DocumentStatistics(
        totalDocuments: documents.length,
        verifiedDocuments: documents
            .where((d) => d.verificationStatus == VerificationStatus.verified)
            .length,
        pendingDocuments: documents
            .where((d) => d.verificationStatus == VerificationStatus.pending)
            .length,
        rejectedDocuments: documents
            .where((d) => d.verificationStatus == VerificationStatus.rejected)
            .length,
        documentsByType: _groupDocumentsByType(documents),
        documentsByMonth: _groupDocumentsByMonth(documents),
        totalFileSize: documents.fold(0, (total, doc) => total + doc.fileSize),
      );
    } catch (e) {
      _logger.e('Error getting document statistics: $e');
      rethrow;
    }
  }

  // Private helper methods
  String _generateDocumentId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = DateTime.now().microsecond;
    return 'DOC-${timestamp.toRadixString(36).toUpperCase()}-${random.toRadixString(36).toUpperCase()}';
  }

  String _generateShareToken() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = DateTime.now().microsecond;
    return 'TOKEN-${timestamp.toRadixString(36)}-${random.toRadixString(36)}';
  }

  // Sanitize file name for storage
  String _sanitizeFileName(String fileName) {
    // Remove special characters and spaces
    return fileName
        .replaceAll(RegExp(r'[^\w\s.-]'), '')
        .replaceAll(RegExp(r'\s+'), '_')
        .toLowerCase();
  }

  String _calculateFileHash(Uint8List fileBytes) {
    final digest = sha256.convert(fileBytes);
    return digest.toString();
  }

  Future<Map<String, dynamic>> _extractFileMetadata(
      File file, String mimeType) async {
    try {
      final stat = await file.stat();
      return {
        'fileName': file.path.split('/').last,
        'fileExtension': file.path.split('.').last,
        'createdAt': stat.changed.toIso8601String(),
        'modifiedAt': stat.modified.toIso8601String(),
        'mimeType': mimeType,
        'encoding': 'utf-8', // Default encoding
      };
    } catch (e) {
      _logger.w('Error extracting file metadata: $e');
      return {};
    }
  }

  Future<Map<String, dynamic>> _extractFileMetadataFromBytes(
      Uint8List fileBytes, String mimeType) async {
    final metadata = <String, dynamic>{
      'size': fileBytes.length,
      'mimeType': mimeType,
      'extractedAt': DateTime.now().toIso8601String(),
    };

    // Add type-specific properties
    if (mimeType.startsWith('image/')) {
      metadata['type'] = 'image';
      metadata['isImage'] = true;
    } else if (mimeType.contains('pdf')) {
      metadata['type'] = 'pdf';
      metadata['isPdf'] = true;
    } else if (mimeType.contains('word') || mimeType.contains('document')) {
      metadata['type'] = 'document';
      metadata['isDocument'] = true;
    } else if (mimeType.contains('excel') || mimeType.contains('spreadsheet')) {
      metadata['type'] = 'spreadsheet';
      metadata['isSpreadsheet'] = true;
    } else {
      metadata['type'] = 'other';
    }

    return metadata;
  }

  Future<void> _logDocumentAccess({
    required String documentId,
    required String userId,
    required DocumentAccessAction action,
    required String details,
  }) async {
    try {
      await _accessLogsRef.add({
        'documentId': documentId,
        'userId': userId,
        'action': action.name,
        'details': details,
        'timestamp': FieldValue.serverTimestamp(),
        'ipAddress': null, // Could be added if needed
        'userAgent': null, // Could be added if needed
      });
    } catch (e) {
      _logger.w('Error logging document access: $e');
      // Don't throw error for logging failures
    }
  }

  Map<String, int> _groupDocumentsByType(List<DocumentModel> documents) {
    final Map<String, int> result = {};
    for (final doc in documents) {
      result[doc.type.name] = (result[doc.type.name] ?? 0) + 1;
    }
    return result;
  }

  Map<String, int> _groupDocumentsByMonth(List<DocumentModel> documents) {
    final Map<String, int> result = {};
    for (final doc in documents) {
      final monthKey =
          '${doc.uploadedAt.year}-${doc.uploadedAt.month.toString().padLeft(2, '0')}';
      result[monthKey] = (result[monthKey] ?? 0) + 1;
    }
    return result;
  }
}

// Supporting classes
enum DocumentAccessAction {
  uploaded,
  accessed,
  modified,
  verified,
  shared,
  deleted,
}

class DocumentStatistics {
  final int totalDocuments;
  final int verifiedDocuments;
  final int pendingDocuments;
  final int rejectedDocuments;
  final Map<String, int> documentsByType;
  final Map<String, int> documentsByMonth;
  final int totalFileSize;

  DocumentStatistics({
    required this.totalDocuments,
    required this.verifiedDocuments,
    required this.pendingDocuments,
    required this.rejectedDocuments,
    required this.documentsByType,
    required this.documentsByMonth,
    required this.totalFileSize,
  });
}
