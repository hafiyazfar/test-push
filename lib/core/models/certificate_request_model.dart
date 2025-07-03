import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents the current status of a certificate request in the workflow.
///
/// This enumeration tracks the request's progress from draft creation
/// through review, approval, and final certificate issuance.
enum RequestStatus {
  /// Request is being created/edited by the client
  draft,

  /// Request has been submitted for review
  submitted,

  /// Request is currently being reviewed by CA
  underReview,

  /// CA has requested changes to the request
  changesRequested,

  /// Request has been approved by CA
  approved,

  /// Request has been rejected
  rejected,

  /// Certificate has been issued for this request
  issued,

  /// Request has been cancelled by client or admin
  cancelled,
}

/// Extension providing additional functionality for RequestStatus enum.
extension RequestStatusExtension on RequestStatus {
  /// Human-readable display name for the status
  String get displayName {
    switch (this) {
      case RequestStatus.draft:
        return 'Draft';
      case RequestStatus.submitted:
        return 'Submitted';
      case RequestStatus.underReview:
        return 'Under Review';
      case RequestStatus.changesRequested:
        return 'Changes Requested';
      case RequestStatus.approved:
        return 'Approved';
      case RequestStatus.rejected:
        return 'Rejected';
      case RequestStatus.issued:
        return 'Issued';
      case RequestStatus.cancelled:
        return 'Cancelled';
    }
  }

  /// Whether the request can still be edited by the client
  bool get canEdit {
    return this == RequestStatus.draft ||
        this == RequestStatus.changesRequested;
  }

  /// Whether the request is still in an active workflow state
  bool get isActive {
    return this != RequestStatus.cancelled &&
        this != RequestStatus.rejected &&
        this != RequestStatus.issued;
  }

  /// Whether the request requires action from a reviewer
  bool get requiresReview {
    return this == RequestStatus.submitted || this == RequestStatus.underReview;
  }

  /// Whether the request has been completed (successfully or not)
  bool get isCompleted {
    return this == RequestStatus.issued ||
        this == RequestStatus.rejected ||
        this == RequestStatus.cancelled;
  }
}

/// Represents the type of action taken in an approval workflow.
///
/// This enumeration defines the possible actions that reviewers
/// can take when processing a certificate request.
enum ApprovalAction {
  /// Request was approved and can proceed
  approved,

  /// Request was rejected and cannot proceed
  rejected,

  /// Changes are requested before approval
  changesRequested,

  /// Request was assigned to a specific reviewer
  assigned,

  /// Request was forwarded to another reviewer
  forwarded,

  /// Additional information was requested
  infoRequested,
}

/// Extension providing display functionality for ApprovalAction enum.
extension ApprovalActionExtension on ApprovalAction {
  /// Human-readable display name for the action
  String get displayName {
    switch (this) {
      case ApprovalAction.approved:
        return 'Approved';
      case ApprovalAction.rejected:
        return 'Rejected';
      case ApprovalAction.changesRequested:
        return 'Changes Requested';
      case ApprovalAction.assigned:
        return 'Assigned';
      case ApprovalAction.forwarded:
        return 'Forwarded';
      case ApprovalAction.infoRequested:
        return 'Information Requested';
    }
  }
}

/// Comprehensive model representing a certificate request in the UPM system.
///
/// This class encapsulates all data related to a client's request for a
/// certificate, including workflow status, approval history, and metadata.
/// It provides complete serialization support for Firestore and JSON.
class CertificateRequestModel {
  // =============================================================================
  // CONSTANTS
  // =============================================================================

  /// Default priority level for new requests (1=low, 3=normal, 5=high)
  static const int defaultPriority = 3;

  /// Minimum allowed priority level
  static const int minPriority = 1;

  /// Maximum allowed priority level
  static const int maxPriority = 5;

  /// Maximum number of days a request can be in draft status
  static const int maxDraftDays = 30;

  /// Standard SLA days for request processing
  static const int standardProcessingDays = 7;

  // =============================================================================
  // CORE PROPERTIES
  // =============================================================================

  /// Unique identifier for this request
  final String id;

  /// ID of the client who submitted this request
  final String clientId;

  /// Full name of the requesting client
  final String clientName;

  /// Email address of the requesting client
  final String clientEmail;

  /// Organization ID where this request originates
  final String organizationId;

  /// Name of the requesting organization
  final String organizationName;

  // =============================================================================
  // REQUEST DETAILS
  // =============================================================================

  /// Type of certificate being requested (e.g., "academic", "professional")
  final String certificateType;

  /// Title/name for the requested certificate
  final String title;

  /// Detailed description of the certificate request
  final String description;

  /// Purpose or reason for requesting this certificate
  final String purpose;

  /// Structured data containing specific certificate information
  final Map<String, dynamic> requestedData;

  /// URLs of supporting documents attached to this request
  final List<String> attachmentUrls;

  // =============================================================================
  // CA ASSIGNMENT
  // =============================================================================

  /// ID of the Certificate Authority assigned to review this request
  final String? assignedCAId;

  /// Name of the assigned Certificate Authority
  final String? assignedCAName;

  /// Timestamp when the request was assigned to a CA
  final DateTime? assignedAt;

  // =============================================================================
  // STATUS AND WORKFLOW
  // =============================================================================

  /// Current status of the request in the workflow
  final RequestStatus status;

  /// Complete history of all approval actions taken
  final List<ApprovalRecord> approvalHistory;

  /// ID of the current reviewer (if any)
  final String? currentReviewerId;

  /// Reason provided when request was rejected
  final String? rejectionReason;

  /// Comments provided when changes were requested
  final String? changeRequestComments;

  // =============================================================================
  // TIMESTAMPS
  // =============================================================================

  /// When this request was originally created
  final DateTime createdAt;

  /// When this request was last modified
  final DateTime updatedAt;

  /// When this request was submitted for review
  final DateTime? submittedAt;

  /// When this request was approved
  final DateTime? approvedAt;

  /// When the certificate was issued for this request
  final DateTime? issuedAt;

  // =============================================================================
  // CERTIFICATE LINK
  // =============================================================================

  /// ID of the certificate created from this request (if issued)
  final String? certificateId;

  // =============================================================================
  // PRIORITY AND METADATA
  // =============================================================================

  /// Priority level (1=low, 3=normal, 5=high)
  final int priority;

  /// Additional metadata and custom fields
  final Map<String, dynamic> metadata;

  /// Tags for categorization and filtering
  final List<String> tags;

  /// Creates a new CertificateRequestModel instance.
  ///
  /// All required fields must be provided. Optional fields have sensible defaults.
  const CertificateRequestModel({
    required this.id,
    required this.clientId,
    required this.clientName,
    required this.clientEmail,
    required this.organizationId,
    required this.organizationName,
    required this.certificateType,
    required this.title,
    required this.description,
    required this.purpose,
    this.requestedData = const {},
    this.attachmentUrls = const [],
    this.assignedCAId,
    this.assignedCAName,
    this.assignedAt,
    this.status = RequestStatus.draft,
    this.approvalHistory = const [],
    this.currentReviewerId,
    this.rejectionReason,
    this.changeRequestComments,
    required this.createdAt,
    required this.updatedAt,
    this.submittedAt,
    this.approvedAt,
    this.issuedAt,
    this.certificateId,
    this.priority = defaultPriority,
    this.metadata = const {},
    this.tags = const [],
  });

  /// Creates a CertificateRequestModel from a Firestore document.
  ///
  /// Handles type conversion and provides safe defaults for missing fields.
  factory CertificateRequestModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return CertificateRequestModel(
      id: doc.id,
      clientId: data['clientId'] ?? '',
      clientName: data['clientName'] ?? '',
      clientEmail: data['clientEmail'] ?? '',
      organizationId: data['organizationId'] ?? '',
      organizationName: data['organizationName'] ?? '',
      certificateType: data['certificateType'] ?? '',
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      purpose: data['purpose'] ?? '',
      requestedData: Map<String, dynamic>.from(data['requestedData'] ?? {}),
      attachmentUrls: List<String>.from(data['attachmentUrls'] ?? []),
      assignedCAId: data['assignedCAId'],
      assignedCAName: data['assignedCAName'],
      assignedAt: data['assignedAt'] != null
          ? (data['assignedAt'] as Timestamp).toDate()
          : null,
      status: _parseRequestStatus(data['status']),
      approvalHistory: (data['approvalHistory'] as List<dynamic>? ?? [])
          .map((record) =>
              ApprovalRecord.fromMap(record as Map<String, dynamic>))
          .toList(),
      currentReviewerId: data['currentReviewerId'],
      rejectionReason: data['rejectionReason'],
      changeRequestComments: data['changeRequestComments'],
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
      submittedAt: data['submittedAt'] != null
          ? (data['submittedAt'] as Timestamp).toDate()
          : null,
      approvedAt: data['approvedAt'] != null
          ? (data['approvedAt'] as Timestamp).toDate()
          : null,
      issuedAt: data['issuedAt'] != null
          ? (data['issuedAt'] as Timestamp).toDate()
          : null,
      certificateId: data['certificateId'],
      priority: _validatePriority(data['priority']),
      metadata: Map<String, dynamic>.from(data['metadata'] ?? {}),
      tags: List<String>.from(data['tags'] ?? []),
    );
  }

  /// Converts this model to a Firestore-compatible map.
  ///
  /// Handles DateTime to Timestamp conversion and excludes the ID field.
  Map<String, dynamic> toFirestore() {
    return {
      'clientId': clientId,
      'clientName': clientName,
      'clientEmail': clientEmail,
      'organizationId': organizationId,
      'organizationName': organizationName,
      'certificateType': certificateType,
      'title': title,
      'description': description,
      'purpose': purpose,
      'requestedData': requestedData,
      'attachmentUrls': attachmentUrls,
      'assignedCAId': assignedCAId,
      'assignedCAName': assignedCAName,
      'assignedAt': assignedAt != null ? Timestamp.fromDate(assignedAt!) : null,
      'status': status.name,
      'approvalHistory':
          approvalHistory.map((record) => record.toMap()).toList(),
      'currentReviewerId': currentReviewerId,
      'rejectionReason': rejectionReason,
      'changeRequestComments': changeRequestComments,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'submittedAt':
          submittedAt != null ? Timestamp.fromDate(submittedAt!) : null,
      'approvedAt': approvedAt != null ? Timestamp.fromDate(approvedAt!) : null,
      'issuedAt': issuedAt != null ? Timestamp.fromDate(issuedAt!) : null,
      'certificateId': certificateId,
      'priority': priority,
      'metadata': metadata,
      'tags': tags,
    };
  }

  /// Creates a copy of this model with specified fields replaced.
  ///
  /// Useful for updating specific properties while maintaining immutability.
  CertificateRequestModel copyWith({
    String? id,
    String? clientId,
    String? clientName,
    String? clientEmail,
    String? organizationId,
    String? organizationName,
    String? certificateType,
    String? title,
    String? description,
    String? purpose,
    Map<String, dynamic>? requestedData,
    List<String>? attachmentUrls,
    String? assignedCAId,
    String? assignedCAName,
    DateTime? assignedAt,
    RequestStatus? status,
    List<ApprovalRecord>? approvalHistory,
    String? currentReviewerId,
    String? rejectionReason,
    String? changeRequestComments,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? submittedAt,
    DateTime? approvedAt,
    DateTime? issuedAt,
    String? certificateId,
    int? priority,
    Map<String, dynamic>? metadata,
    List<String>? tags,
  }) {
    return CertificateRequestModel(
      id: id ?? this.id,
      clientId: clientId ?? this.clientId,
      clientName: clientName ?? this.clientName,
      clientEmail: clientEmail ?? this.clientEmail,
      organizationId: organizationId ?? this.organizationId,
      organizationName: organizationName ?? this.organizationName,
      certificateType: certificateType ?? this.certificateType,
      title: title ?? this.title,
      description: description ?? this.description,
      purpose: purpose ?? this.purpose,
      requestedData: requestedData ?? this.requestedData,
      attachmentUrls: attachmentUrls ?? this.attachmentUrls,
      assignedCAId: assignedCAId ?? this.assignedCAId,
      assignedCAName: assignedCAName ?? this.assignedCAName,
      assignedAt: assignedAt ?? this.assignedAt,
      status: status ?? this.status,
      approvalHistory: approvalHistory ?? this.approvalHistory,
      currentReviewerId: currentReviewerId ?? this.currentReviewerId,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      changeRequestComments:
          changeRequestComments ?? this.changeRequestComments,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      submittedAt: submittedAt ?? this.submittedAt,
      approvedAt: approvedAt ?? this.approvedAt,
      issuedAt: issuedAt ?? this.issuedAt,
      certificateId: certificateId ?? this.certificateId,
      priority: priority ?? this.priority,
      metadata: metadata ?? this.metadata,
      tags: tags ?? this.tags,
    );
  }

  // =============================================================================
  // BUSINESS LOGIC METHODS
  // =============================================================================

  /// Calculates the total processing time for this request.
  ///
  /// Returns null if the request hasn't been completed yet.
  Duration? get processingTime {
    if (submittedAt == null) return null;

    final endTime = issuedAt ?? approvedAt ?? DateTime.now();
    return endTime.difference(submittedAt!);
  }

  /// Gets the number of days since the request was created.
  int get daysSinceCreated {
    return DateTime.now().difference(createdAt).inDays;
  }

  /// Gets the number of days since the request was submitted.
  ///
  /// Returns null if the request hasn't been submitted yet.
  int? get daysSinceSubmitted {
    if (submittedAt == null) return null;
    return DateTime.now().difference(submittedAt!).inDays;
  }

  /// Checks if this request is overdue based on standard SLA.
  bool get isOverdue {
    if (submittedAt == null || status.isCompleted) return false;
    return daysSinceSubmitted! > standardProcessingDays;
  }

  /// Checks if this draft request is stale and should be cleaned up.
  bool get isDraftStale {
    return status == RequestStatus.draft && daysSinceCreated > maxDraftDays;
  }

  /// Gets the priority level as a descriptive string.
  String get priorityDisplayName {
    switch (priority) {
      case 1:
      case 2:
        return 'Low';
      case 3:
        return 'Normal';
      case 4:
      case 5:
        return 'High';
      default:
        return 'Normal';
    }
  }

  /// Checks if this request has any attachments.
  bool get hasAttachments => attachmentUrls.isNotEmpty;

  /// Gets the latest approval record (most recent action).
  ApprovalRecord? get latestApprovalRecord {
    if (approvalHistory.isEmpty) return null;
    return approvalHistory
        .reduce((a, b) => a.timestamp.isAfter(b.timestamp) ? a : b);
  }

  /// Checks if this request can be cancelled by the client.
  bool get canCancel {
    return status == RequestStatus.draft ||
        status == RequestStatus.submitted ||
        status == RequestStatus.changesRequested;
  }

  /// Checks if this request can be assigned to a CA.
  bool get canAssign {
    return status == RequestStatus.submitted && assignedCAId == null;
  }

  /// Validates the request data for completeness and correctness.
  ///
  /// Returns a list of validation errors, empty if valid.
  List<String> validate() {
    final errors = <String>[];

    // Required field validation
    if (clientId.trim().isEmpty) errors.add('Client ID is required');
    if (clientName.trim().isEmpty) errors.add('Client name is required');
    if (clientEmail.trim().isEmpty) errors.add('Client email is required');
    if (organizationId.trim().isEmpty) {
      errors.add('Organization ID is required');
    }
    if (certificateType.trim().isEmpty) {
      errors.add('Certificate type is required');
    }
    if (title.trim().isEmpty) errors.add('Title is required');
    if (description.trim().isEmpty) errors.add('Description is required');
    if (purpose.trim().isEmpty) errors.add('Purpose is required');

    // Email validation (basic)
    if (clientEmail.isNotEmpty && !clientEmail.contains('@')) {
      errors.add('Client email must be a valid email address');
    }

    // Priority validation
    if (priority < minPriority || priority > maxPriority) {
      errors.add('Priority must be between $minPriority and $maxPriority');
    }

    // Business logic validation
    if (status.isCompleted &&
        certificateId == null &&
        status == RequestStatus.issued) {
      errors.add('Issued requests must have a certificate ID');
    }

    if (status == RequestStatus.rejected &&
        rejectionReason?.trim().isEmpty == true) {
      errors.add('Rejected requests must have a rejection reason');
    }

    if (assignedCAId != null && assignedAt == null) {
      errors.add('Assigned requests must have an assignment timestamp');
    }

    // Date validation
    if (submittedAt != null && submittedAt!.isBefore(createdAt)) {
      errors.add('Submit date cannot be before creation date');
    }

    if (approvedAt != null &&
        submittedAt != null &&
        approvedAt!.isBefore(submittedAt!)) {
      errors.add('Approval date cannot be before submission date');
    }

    if (issuedAt != null &&
        approvedAt != null &&
        issuedAt!.isBefore(approvedAt!)) {
      errors.add('Issue date cannot be before approval date');
    }

    return errors;
  }

  // =============================================================================
  // STATIC HELPER METHODS
  // =============================================================================

  /// Safely parses a RequestStatus from dynamic data.
  static RequestStatus _parseRequestStatus(dynamic value) {
    if (value is String) {
      return RequestStatus.values.firstWhere(
        (e) => e.name == value,
        orElse: () => RequestStatus.draft,
      );
    }
    return RequestStatus.draft;
  }

  /// Validates and normalizes a priority value.
  static int _validatePriority(dynamic value) {
    if (value is int) {
      return value.clamp(minPriority, maxPriority);
    }
    if (value is String) {
      final parsed = int.tryParse(value);
      if (parsed != null) {
        return parsed.clamp(minPriority, maxPriority);
      }
    }
    return defaultPriority;
  }

  // =============================================================================
  // OBJECT OVERRIDES
  // =============================================================================

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CertificateRequestModel &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'CertificateRequestModel(id: $id, title: $title, status: $status)';
}

/// Represents a single approval action taken in the request workflow.
///
/// This class records who took what action, when, and any associated
/// comments or changes made during the approval process.
class ApprovalRecord {
  // =============================================================================
  // PROPERTIES
  // =============================================================================

  /// Unique identifier for this approval record
  final String id;

  /// ID of the user who took this action
  final String reviewerId;

  /// Full name of the reviewer
  final String reviewerName;

  /// Role of the reviewer (e.g., "CA", "Admin", "Client")
  final String reviewerRole;

  /// Type of action taken
  final ApprovalAction action;

  /// Optional comments provided by the reviewer
  final String? comments;

  /// When this action was taken
  final DateTime timestamp;

  /// Any specific changes requested or made
  final Map<String, dynamic>? changes;

  /// Creates a new ApprovalRecord instance.
  const ApprovalRecord({
    required this.id,
    required this.reviewerId,
    required this.reviewerName,
    required this.reviewerRole,
    required this.action,
    this.comments,
    required this.timestamp,
    this.changes,
  });

  /// Creates an ApprovalRecord from a map.
  ///
  /// Handles type conversion and provides safe defaults for missing fields.
  factory ApprovalRecord.fromMap(Map<String, dynamic> data) {
    return ApprovalRecord(
      id: data['id'] ?? '',
      reviewerId: data['reviewerId'] ?? '',
      reviewerName: data['reviewerName'] ?? '',
      reviewerRole: data['reviewerRole'] ?? '',
      action: _parseApprovalAction(data['action']),
      comments: data['comments'],
      timestamp: DateTime.parse(data['timestamp']),
      changes: data['changes'] != null
          ? Map<String, dynamic>.from(data['changes'])
          : null,
    );
  }

  /// Converts this record to a map for serialization.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'reviewerId': reviewerId,
      'reviewerName': reviewerName,
      'reviewerRole': reviewerRole,
      'action': action.name,
      'comments': comments,
      'timestamp': timestamp.toIso8601String(),
      'changes': changes,
    };
  }

  /// Gets a human-readable description of this approval action.
  String get actionDescription {
    final baseDescription =
        '$reviewerName ($reviewerRole) ${action.displayName.toLowerCase()}';
    return comments?.isNotEmpty == true
        ? '$baseDescription: $comments'
        : baseDescription;
  }

  /// Checks if this record represents a positive action.
  bool get isPositiveAction {
    return action == ApprovalAction.approved ||
        action == ApprovalAction.assigned;
  }

  /// Checks if this record represents a negative action.
  bool get isNegativeAction {
    return action == ApprovalAction.rejected;
  }

  /// Safely parses an ApprovalAction from dynamic data.
  static ApprovalAction _parseApprovalAction(dynamic value) {
    if (value is String) {
      // Handle legacy string values
      switch (value.toLowerCase()) {
        case 'approved':
          return ApprovalAction.approved;
        case 'rejected':
          return ApprovalAction.rejected;
        case 'changes_requested':
        case 'changesrequested':
          return ApprovalAction.changesRequested;
        case 'assigned':
          return ApprovalAction.assigned;
        case 'forwarded':
          return ApprovalAction.forwarded;
        case 'info_requested':
        case 'inforequested':
          return ApprovalAction.infoRequested;
        default:
          // Try to parse as enum name
          return ApprovalAction.values.firstWhere(
            (e) => e.name == value,
            orElse: () => ApprovalAction.assigned,
          );
      }
    }
    return ApprovalAction.assigned;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ApprovalRecord &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'ApprovalRecord(id: $id, action: $action, reviewer: $reviewerName)';
}
