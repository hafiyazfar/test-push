import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';

import '../models/certificate_request_model.dart';
import '../models/user_model.dart';
import '../models/certificate_model.dart';
import 'logger_service.dart';
import 'notification_service.dart';
import '../../features/certificates/services/certificate_service.dart';

/// Certificate Request Management Service for the UPM Digital Certificate Repository.
///
/// This service manages the complete certificate request lifecycle including:
/// - Request creation and submission by clients
/// - CA review and approval workflow
/// - Client confirmation and certificate generation
/// - Status tracking and notifications
/// - Request updates and cancellation
///
/// Workflow:
/// 1. Client creates and submits request
/// 2. System assigns available CA
/// 3. CA reviews and approves/rejects/requests changes
/// 4. Client confirms approved request
/// 5. System generates certificate automatically
///
/// Features:
/// - Role-based access control (Client, CA, Admin)
/// - Real-time notifications
/// - Comprehensive audit trail
/// - Organization-based CA assignment
/// - Transactional updates for data consistency
class CertificateRequestService {
  // =============================================================================
  // CONSTANTS
  // =============================================================================

  /// Collection name for certificate requests
  static const String _collection = 'certificate_requests';

  /// Default priority level for requests
  static const int _defaultPriority = 3;

  /// Template ID for default certificates
  static const String _defaultTemplateId = 'default-template';

  /// Actions for request review
  static const String actionApprove = 'approve';
  static const String actionReject = 'reject';
  static const String actionRequestChanges = 'request_changes';

  /// Reviewer roles
  static const String roleClient = 'client';
  static const String roleCA = 'ca';
  static const String roleAdmin = 'admin';

  // =============================================================================
  // DEPENDENCIES
  // =============================================================================

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final NotificationService _notificationService;
  final CertificateService _certificateService;
  final _uuid = const Uuid();

  // =============================================================================
  // STATE MANAGEMENT
  // =============================================================================

  bool _isInitialized = false;

  // =============================================================================
  // CONSTRUCTOR
  // =============================================================================

  /// Create certificate request service with dependency injection
  CertificateRequestService({
    NotificationService? notificationService,
    CertificateService? certificateService,
  })  : _notificationService = notificationService ?? NotificationService(),
        _certificateService = certificateService ?? CertificateService();

  // =============================================================================
  // GETTERS
  // =============================================================================

  /// Whether the service is healthy and operational
  bool get isHealthy => _isInitialized && _auth.currentUser != null;

  // =============================================================================
  // INITIALIZATION
  // =============================================================================

  /// Initialize the certificate request service
  Future<void> initialize() async {
    try {
      LoggerService.info('Initializing certificate request service...');

      // Test Firestore connectivity
      await _firestore.collection(_collection).limit(1).get();

      // Initialize dependent services
      await _notificationService.initialize();

      _isInitialized = true;
      LoggerService.info(
          'Certificate request service initialized successfully');
    } catch (e, stackTrace) {
      LoggerService.error('Failed to initialize certificate request service',
          error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  // =============================================================================
  // REQUEST CREATION AND SUBMISSION
  // =============================================================================

  /// Create a new certificate request (Client action)
  Future<CertificateRequestModel> createRequest({
    required String title,
    required String description,
    required String purpose,
    required String certificateType,
    required Map<String, dynamic> requestedData,
    required String organizationId,
    required String organizationName,
    List<String> attachmentUrls = const [],
    List<String> tags = const [],
    int priority = _defaultPriority,
  }) async {
    try {
      // Validate inputs
      _validateRequestInput(
        title: title,
        description: description,
        purpose: purpose,
        certificateType: certificateType,
        organizationId: organizationId,
        organizationName: organizationName,
      );

      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      // Get and validate user details
      final userData = await _getUserData(currentUser.uid);
      final userRole = _getUserRole(userData);

      // Check permissions
      if (!_canCreateRequest(userRole)) {
        throw Exception('Only clients can create certificate requests');
      }

      final now = DateTime.now();
      final requestId = _uuid.v4();

      final request = CertificateRequestModel(
        id: requestId,
        clientId: currentUser.uid,
        clientName: userData['displayName'] ?? currentUser.email ?? '',
        clientEmail: currentUser.email ?? '',
        organizationId: organizationId,
        organizationName: organizationName,
        certificateType: certificateType,
        title: title,
        description: description,
        purpose: purpose,
        requestedData: requestedData,
        attachmentUrls: attachmentUrls,
        status: RequestStatus.draft,
        createdAt: now,
        updatedAt: now,
        priority: priority,
        tags: tags,
        metadata: _createRequestMetadata(currentUser),
      );

      // Save to Firestore
      await _firestore.collection(_collection).doc(requestId).set(
            request.toFirestore(),
          );

      LoggerService.info('Certificate request created: $requestId');
      return request;
    } catch (e, stackTrace) {
      LoggerService.error('Failed to create certificate request',
          error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  // Submit request for review (Client action)
  Future<void> submitRequest(String requestId) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      await _firestore.runTransaction((transaction) async {
        final requestDoc = await transaction.get(
          _firestore.collection(_collection).doc(requestId),
        );

        if (!requestDoc.exists) {
          throw Exception('Request not found');
        }

        final request = CertificateRequestModel.fromFirestore(requestDoc);

        // Verify ownership
        if (request.clientId != currentUser.uid) {
          throw Exception('You can only submit your own requests');
        }

        // Check if request can be submitted
        if (!request.status.canEdit) {
          throw Exception(
              'Request cannot be submitted in current status: ${request.status.displayName}');
        }

        // Find available CA
        final availableCA = await _findAvailableCA(request.organizationId);
        if (availableCA == null) {
          throw Exception(
              'No Certificate Authority available for this organization');
        }

        // Update request
        transaction.update(requestDoc.reference, {
          'status': RequestStatus.submitted.name,
          'submittedAt': FieldValue.serverTimestamp(),
          'assignedCAId': availableCA['id'],
          'assignedCAName': availableCA['displayName'],
          'assignedAt': FieldValue.serverTimestamp(),
          'currentReviewerId': availableCA['id'],
          'updatedAt': FieldValue.serverTimestamp(),
          'approvalHistory': FieldValue.arrayUnion([
            {
              'id': _uuid.v4(),
              'reviewerId': currentUser.uid,
              'reviewerName': request.clientName,
              'reviewerRole': 'client',
              'action': 'submitted',
              'comments': 'Request submitted for review',
              'timestamp': DateTime.now().toIso8601String(),
            }
          ]),
        });

        // Send notification to CA
        await _notificationService.sendNotification(
          userId: availableCA['id'],
          title: 'New Certificate Request',
          message:
              'You have a new certificate request from ${request.clientName}',
          type: 'certificate_request',
          data: {
            'requestId': requestId,
            'clientName': request.clientName,
            'certificateType': request.certificateType,
          },
        );
      });

      LoggerService.info('Certificate request submitted: $requestId');
    } catch (e, stackTrace) {
      LoggerService.error('Failed to submit certificate request',
          error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  // Review request (CA action)
  Future<void> reviewRequest({
    required String requestId,
    required String action, // approve, reject, request_changes
    String? comments,
    Map<String, dynamic>? changes,
  }) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      // Get CA details
      final userDoc =
          await _firestore.collection('users').doc(currentUser.uid).get();
      if (!userDoc.exists) {
        throw Exception('User document not found');
      }

      final userData = userDoc.data()!;
      final userType = UserType.values.firstWhere(
        (type) => type.name == userData['userType'],
        orElse: () => UserType.user,
      );

      // Check if user is CA
      if (userType != UserType.ca &&
          userType != UserType.admin &&
          userType != UserType.client) {
        throw Exception(
            'Insufficient permissions: Only CA, Client and Admin can handle certificate requests');
      }

      await _firestore.runTransaction((transaction) async {
        final requestDoc = await transaction.get(
          _firestore.collection(_collection).doc(requestId),
        );

        if (!requestDoc.exists) {
          throw Exception('Request not found');
        }

        final request = CertificateRequestModel.fromFirestore(requestDoc);

        // Verify reviewer
        if (request.assignedCAId != currentUser.uid &&
            userType != UserType.admin) {
          throw Exception('You are not assigned to review this request');
        }

        RequestStatus newStatus;
        String notificationTitle;
        String notificationMessage;

        switch (action) {
          case 'approve':
            newStatus = RequestStatus.approved;
            notificationTitle = 'Certificate Request Approved';
            notificationMessage =
                'Your certificate request has been approved by ${userData['displayName']}';
            break;
          case 'reject':
            newStatus = RequestStatus.rejected;
            notificationTitle = 'Certificate Request Rejected';
            notificationMessage =
                'Your certificate request has been rejected. ${comments ?? ''}';
            break;
          case 'request_changes':
            newStatus = RequestStatus.changesRequested;
            notificationTitle = 'Changes Requested';
            notificationMessage =
                'Changes have been requested for your certificate request. ${comments ?? ''}';
            break;
          default:
            throw Exception('Invalid action: $action');
        }

        // Update request
        final updateData = {
          'status': newStatus.name,
          'updatedAt': FieldValue.serverTimestamp(),
          'approvalHistory': FieldValue.arrayUnion([
            {
              'id': _uuid.v4(),
              'reviewerId': currentUser.uid,
              'reviewerName': userData['displayName'] ?? currentUser.email,
              'reviewerRole': userType.name,
              'action': action,
              'comments': comments,
              'timestamp': DateTime.now().toIso8601String(),
              'changes': changes,
            }
          ]),
        };

        if (action == 'approve') {
          updateData['approvedAt'] = FieldValue.serverTimestamp();
          updateData['status'] =
              RequestStatus.underReview.name; // Client needs to confirm
        } else if (action == 'reject') {
          updateData['rejectionReason'] = comments ?? '';
          updateData.remove(
              'currentReviewerId'); // Remove field instead of setting null
        } else if (action == 'request_changes') {
          updateData['changeRequestComments'] = comments ?? '';
          updateData.remove(
              'currentReviewerId'); // Remove field instead of setting null
        }

        transaction.update(requestDoc.reference, updateData);

        // Send notification to client
        await _notificationService.sendNotification(
          userId: request.clientId,
          title: notificationTitle,
          message: notificationMessage,
          type: 'certificate_request_update',
          data: {
            'requestId': requestId,
            'action': action,
            'status': newStatus.name,
          },
        );
      });

      LoggerService.info(
          'Certificate request reviewed: $requestId, action: $action');
    } catch (e, stackTrace) {
      LoggerService.error('Failed to review certificate request',
          error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  // Client confirms approved request (Client action)
  Future<void> confirmApprovedRequest(String requestId) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      await _firestore.runTransaction((transaction) async {
        final requestDoc = await transaction.get(
          _firestore.collection(_collection).doc(requestId),
        );

        if (!requestDoc.exists) {
          throw Exception('Request not found');
        }

        final request = CertificateRequestModel.fromFirestore(requestDoc);

        // Verify ownership
        if (request.clientId != currentUser.uid) {
          throw Exception('You can only confirm your own requests');
        }

        // Check status
        if (request.status != RequestStatus.underReview) {
          throw Exception('Request is not pending client confirmation');
        }

        // Update to approved
        transaction.update(requestDoc.reference, {
          'status': RequestStatus.approved.name,
          'updatedAt': FieldValue.serverTimestamp(),
          'approvalHistory': FieldValue.arrayUnion([
            {
              'id': _uuid.v4(),
              'reviewerId': currentUser.uid,
              'reviewerName': request.clientName,
              'reviewerRole': 'client',
              'action': 'client_approved',
              'comments': 'Client confirmed the approved request',
              'timestamp': DateTime.now().toIso8601String(),
            }
          ]),
        });

        // Create the certificate
        await _createCertificateFromRequest(request, transaction);
      });

      LoggerService.info('Certificate request confirmed by client: $requestId');
    } catch (e, stackTrace) {
      LoggerService.error('Failed to confirm certificate request',
          error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  // Create certificate from approved request
  Future<void> _createCertificateFromRequest(
    CertificateRequestModel request,
    Transaction transaction,
  ) async {
    try {
      // Get current user as issuer
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      // Generate certificate
      final certificate = await _certificateService.createCertificate(
        templateId: _defaultTemplateId, // Using default template
        issuerId: request.assignedCAId ?? currentUser.uid,
        title: request.title,
        description: request.description,
        type: CertificateType.values.firstWhere(
          (type) => type.displayName == request.certificateType,
          orElse: () => CertificateType.custom,
        ),
        recipientId: request.clientId,
        recipientEmail: request.clientEmail,
        recipientName: request.clientName,
        organizationId: request.organizationId,
        organizationName: request.organizationName,
        metadata: {
          ...request.requestedData,
          'requestId': request.id,
          'approvedByCA': request.assignedCAId,
        },
      );

      // Update request with certificate ID
      transaction.update(
        _firestore.collection(_collection).doc(request.id),
        {
          'certificateId': certificate.id,
          'status': RequestStatus.issued.name,
          'issuedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
      );

      // Send notification
      await _notificationService.sendNotification(
        userId: request.clientId,
        title: 'Certificate Issued',
        message:
            'Your certificate "${request.title}" has been issued successfully',
        type: 'certificate_issued',
        data: {
          'certificateId': certificate.id,
          'requestId': request.id,
        },
      );
    } catch (e) {
      LoggerService.error('Failed to create certificate from request',
          error: e);
      rethrow;
    }
  }

  // Find available CA for organization
  Future<Map<String, dynamic>?> _findAvailableCA(String organizationId) async {
    try {
      // Query CAs for the organization
      final caQuery = await _firestore
          .collection('users')
          .where('userType', isEqualTo: UserType.ca.name)
          .where('status', isEqualTo: UserStatus.active.name)
          .where('organizationId', isEqualTo: organizationId)
          .limit(1)
          .get();

      if (caQuery.docs.isNotEmpty) {
        final caDoc = caQuery.docs.first;
        return {
          'id': caDoc.id,
          'displayName': caDoc.data()['displayName'],
          'email': caDoc.data()['email'],
        };
      }

      // If no CA for specific organization, find any available CA
      final generalCAQuery = await _firestore
          .collection('users')
          .where('userType', isEqualTo: UserType.ca.name)
          .where('status', isEqualTo: UserStatus.active.name)
          .limit(1)
          .get();

      if (generalCAQuery.docs.isNotEmpty) {
        final caDoc = generalCAQuery.docs.first;
        return {
          'id': caDoc.id,
          'displayName': caDoc.data()['displayName'],
          'email': caDoc.data()['email'],
        };
      }

      return null;
    } catch (e) {
      LoggerService.error('Failed to find available CA', error: e);
      return null;
    }
  }

  // Get requests for CA
  Stream<List<CertificateRequestModel>> getRequestsForCA(String caId) {
    return _firestore
        .collection(_collection)
        .where('assignedCAId', isEqualTo: caId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => CertificateRequestModel.fromFirestore(doc))
          .toList();
    });
  }

  // Get requests for client
  Stream<List<CertificateRequestModel>> getRequestsForClient(String clientId) {
    return _firestore
        .collection(_collection)
        .where('clientId', isEqualTo: clientId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => CertificateRequestModel.fromFirestore(doc))
          .toList();
    });
  }

  // Get request by ID
  Future<CertificateRequestModel?> getRequestById(String requestId) async {
    try {
      final doc = await _firestore.collection(_collection).doc(requestId).get();

      if (!doc.exists) {
        return null;
      }

      return CertificateRequestModel.fromFirestore(doc);
    } catch (e) {
      LoggerService.error('Failed to get request by ID', error: e);
      rethrow;
    }
  }

  // Update request (Client action - for draft or changes requested status)
  Future<void> updateRequest({
    required String requestId,
    String? title,
    String? description,
    String? purpose,
    Map<String, dynamic>? requestedData,
    List<String>? attachmentUrls,
    List<String>? tags,
    int? priority,
  }) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      await _firestore.runTransaction((transaction) async {
        final requestDoc = await transaction.get(
          _firestore.collection(_collection).doc(requestId),
        );

        if (!requestDoc.exists) {
          throw Exception('Request not found');
        }

        final request = CertificateRequestModel.fromFirestore(requestDoc);

        // Verify ownership
        if (request.clientId != currentUser.uid) {
          throw Exception('You can only update your own requests');
        }

        // Check if request can be edited
        if (!request.status.canEdit) {
          throw Exception(
              'Request cannot be edited in current status: ${request.status.displayName}');
        }

        // Update fields
        final updateData = <String, dynamic>{
          'updatedAt': FieldValue.serverTimestamp(),
        };

        if (title != null) updateData['title'] = title;
        if (description != null) updateData['description'] = description;
        if (purpose != null) updateData['purpose'] = purpose;
        if (requestedData != null) updateData['requestedData'] = requestedData;
        if (attachmentUrls != null)
          updateData['attachmentUrls'] = attachmentUrls;
        if (tags != null) updateData['tags'] = tags;
        if (priority != null) updateData['priority'] = priority;

        // If status was changesRequested, reset to draft
        if (request.status == RequestStatus.changesRequested) {
          updateData['status'] = RequestStatus.draft.name;
          updateData['changeRequestComments'] = null;
        }

        transaction.update(requestDoc.reference, updateData);
      });

      LoggerService.info('Certificate request updated: $requestId');
    } catch (e, stackTrace) {
      LoggerService.error('Failed to update certificate request',
          error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  // Cancel request (Client action)
  Future<void> cancelRequest(String requestId, String reason) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      await _firestore.runTransaction((transaction) async {
        final requestDoc = await transaction.get(
          _firestore.collection(_collection).doc(requestId),
        );

        if (!requestDoc.exists) {
          throw Exception('Request not found');
        }

        final request = CertificateRequestModel.fromFirestore(requestDoc);

        // Verify ownership
        if (request.clientId != currentUser.uid) {
          throw Exception('You can only cancel your own requests');
        }

        // Check if request can be cancelled
        if (!request.status.isActive) {
          throw Exception(
              'Request cannot be cancelled in current status: ${request.status.displayName}');
        }

        // Update request
        transaction.update(requestDoc.reference, {
          'status': RequestStatus.cancelled.name,
          'updatedAt': FieldValue.serverTimestamp(),
          'metadata.cancelledReason': reason,
          'metadata.cancelledAt': DateTime.now().toIso8601String(),
          'approvalHistory': FieldValue.arrayUnion([
            {
              'id': _uuid.v4(),
              'reviewerId': currentUser.uid,
              'reviewerName': request.clientName,
              'reviewerRole': 'client',
              'action': 'cancelled',
              'comments': reason,
              'timestamp': DateTime.now().toIso8601String(),
            }
          ]),
        });

        // If CA was assigned, notify them
        if (request.assignedCAId != null) {
          await _notificationService.sendNotification(
            userId: request.assignedCAId!,
            title: 'Certificate Request Cancelled',
            message:
                'Request "${request.title}" has been cancelled by the client',
            type: 'certificate_request_cancelled',
            data: {
              'requestId': requestId,
              'clientName': request.clientName,
            },
          );
        }
      });

      LoggerService.info('Certificate request cancelled: $requestId');
    } catch (e, stackTrace) {
      LoggerService.error('Failed to cancel certificate request',
          error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  // =============================================================================
  // HELPER METHODS
  // =============================================================================

  /// Validate request input parameters
  void _validateRequestInput({
    required String title,
    required String description,
    required String purpose,
    required String certificateType,
    required String organizationId,
    required String organizationName,
  }) {
    if (title.trim().isEmpty) {
      throw Exception('Title cannot be empty');
    }
    if (description.trim().isEmpty) {
      throw Exception('Description cannot be empty');
    }
    if (purpose.trim().isEmpty) {
      throw Exception('Purpose cannot be empty');
    }
    if (certificateType.trim().isEmpty) {
      throw Exception('Certificate type cannot be empty');
    }
    if (organizationId.trim().isEmpty) {
      throw Exception('Organization ID cannot be empty');
    }
    if (organizationName.trim().isEmpty) {
      throw Exception('Organization name cannot be empty');
    }

    // Length validations
    if (title.length > 100) {
      throw Exception('Title cannot exceed 100 characters');
    }
    if (description.length > 1000) {
      throw Exception('Description cannot exceed 1000 characters');
    }
  }

  /// Get user data from Firestore
  Future<Map<String, dynamic>> _getUserData(String userId) async {
    final userDoc = await _firestore.collection('users').doc(userId).get();
    if (!userDoc.exists) {
      throw Exception('User document not found');
    }
    return userDoc.data()!;
  }

  /// Extract user role from user data
  UserRole _getUserRole(Map<String, dynamic> userData) {
    return UserRole.values.firstWhere(
      (role) => role.name == userData['role'],
      orElse: () => UserRole.recipient,
    );
  }

  /// Check if user can create requests
  bool _canCreateRequest(UserRole userRole) {
    return userRole == UserRole.client || userRole == UserRole.systemAdmin;
  }

  /// Create request metadata
  Map<String, dynamic> _createRequestMetadata(User currentUser) {
    return {
      'createdBy': currentUser.uid,
      'createdByEmail': currentUser.email,
      'requestSource': 'mobile_app',
      'version': '1.0',
    };
  }
}
