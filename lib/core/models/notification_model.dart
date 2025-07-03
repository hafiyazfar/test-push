import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents the type of notification in the system.
///
/// This enumeration defines the various categories of notifications
/// that can be sent to users in different scenarios.
enum NotificationType {
  /// General system information
  info,

  /// Warning messages requiring attention
  warning,

  /// Error notifications
  error,

  /// Success confirmations
  success,

  /// Certificate-related notifications
  certificate,

  /// Document-related notifications
  document,

  /// Account and authentication notifications
  account,

  /// System maintenance and updates
  system,

  /// Reminder notifications
  reminder,

  /// Security alerts
  security,
}

/// Extension providing additional functionality for NotificationType enum.
extension NotificationTypeExtension on NotificationType {
  /// Human-readable display name for the notification type
  String get displayName {
    switch (this) {
      case NotificationType.info:
        return 'Information';
      case NotificationType.warning:
        return 'Warning';
      case NotificationType.error:
        return 'Error';
      case NotificationType.success:
        return 'Success';
      case NotificationType.certificate:
        return 'Certificate';
      case NotificationType.document:
        return 'Document';
      case NotificationType.account:
        return 'Account';
      case NotificationType.system:
        return 'System';
      case NotificationType.reminder:
        return 'Reminder';
      case NotificationType.security:
        return 'Security';
    }
  }

  /// Icon name for UI display
  String get iconName {
    switch (this) {
      case NotificationType.info:
        return 'info';
      case NotificationType.warning:
        return 'warning';
      case NotificationType.error:
        return 'error';
      case NotificationType.success:
        return 'check_circle';
      case NotificationType.certificate:
        return 'certificate';
      case NotificationType.document:
        return 'description';
      case NotificationType.account:
        return 'account_circle';
      case NotificationType.system:
        return 'settings';
      case NotificationType.reminder:
        return 'schedule';
      case NotificationType.security:
        return 'security';
    }
  }

  /// Whether this notification type is considered critical
  bool get isCritical {
    return this == NotificationType.error ||
        this == NotificationType.security ||
        this == NotificationType.warning;
  }
}

/// Represents the priority level of a notification.
enum NotificationPriority {
  /// Low priority - can be dismissed easily
  low,

  /// Normal priority - standard notification
  normal,

  /// High priority - requires attention
  high,

  /// Critical priority - urgent action required
  critical,
}

/// Extension for NotificationPriority enum.
extension NotificationPriorityExtension on NotificationPriority {
  /// Human-readable display name
  String get displayName {
    switch (this) {
      case NotificationPriority.low:
        return 'Low';
      case NotificationPriority.normal:
        return 'Normal';
      case NotificationPriority.high:
        return 'High';
      case NotificationPriority.critical:
        return 'Critical';
    }
  }

  /// Numerical value for sorting (higher = more important)
  int get value {
    switch (this) {
      case NotificationPriority.low:
        return 1;
      case NotificationPriority.normal:
        return 2;
      case NotificationPriority.high:
        return 3;
      case NotificationPriority.critical:
        return 4;
    }
  }
}

/// Comprehensive model representing a notification in the UPM system.
///
/// This class encapsulates all notification data including metadata,
/// priority, expiration, and delivery status. It provides complete
/// serialization support for Firestore and JSON.
class NotificationModel {
  // =============================================================================
  // CONSTANTS
  // =============================================================================

  /// Default priority for new notifications
  static const NotificationPriority defaultPriority =
      NotificationPriority.normal;

  /// Default notification expiry in days
  static const int defaultExpiryDays = 30;

  /// Maximum title length
  static const int maxTitleLength = 200;

  /// Maximum body length
  static const int maxBodyLength = 1000;

  // =============================================================================
  // CORE PROPERTIES
  // =============================================================================

  /// Unique identifier for this notification
  final String id;

  /// ID of the user who should receive this notification
  final String userId;

  /// Notification title/subject
  final String title;

  /// Notification body/message content
  final String body;

  /// Type/category of this notification
  final NotificationType type;

  /// Priority level of this notification
  final NotificationPriority priority;

  /// Additional data payload for the notification
  final Map<String, dynamic> data;

  /// Whether the notification has been read by the user
  final bool isRead;

  /// Whether the notification has been delivered
  final bool isDelivered;

  /// When this notification was created
  final DateTime createdAt;

  /// When this notification was read (if applicable)
  final DateTime? readAt;

  /// When this notification was delivered (if applicable)
  final DateTime? deliveredAt;

  /// When this notification expires and can be cleaned up
  final DateTime? expiresAt;

  /// ID of the user or system that created this notification
  final String? senderId;

  /// Name of the sender (for display purposes)
  final String? senderName;

  /// Optional action URL or deep link
  final String? actionUrl;

  /// Optional image URL for rich notifications
  final String? imageUrl;

  /// Number of times the user has been notified (for retry logic)
  final int deliveryAttempts;

  /// Creates a new NotificationModel instance.
  ///
  /// All required fields must be provided. Optional fields have sensible defaults.
  const NotificationModel({
    required this.id,
    required this.userId,
    required this.title,
    required this.body,
    required this.type,
    this.priority = defaultPriority,
    this.data = const {},
    this.isRead = false,
    this.isDelivered = false,
    required this.createdAt,
    this.readAt,
    this.deliveredAt,
    this.expiresAt,
    this.senderId,
    this.senderName,
    this.actionUrl,
    this.imageUrl,
    this.deliveryAttempts = 0,
  });

  /// Creates a NotificationModel from a JSON map.
  ///
  /// Handles type conversion and provides safe defaults for missing fields.
  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id'] as String? ?? '',
      userId: json['userId'] as String? ?? '',
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? json['message'] as String? ?? '',
      type: _parseNotificationType(json['type']),
      priority: _parseNotificationPriority(json['priority']),
      data: Map<String, dynamic>.from(
          json['data'] as Map<String, dynamic>? ?? {}),
      isRead: json['isRead'] as bool? ?? false,
      isDelivered: json['isDelivered'] as bool? ?? false,
      createdAt: _parseDateTime(json['createdAt']) ?? DateTime.now(),
      readAt: _parseDateTime(json['readAt']),
      deliveredAt: _parseDateTime(json['deliveredAt']),
      expiresAt: _parseDateTime(json['expiresAt']),
      senderId: json['senderId'] as String?,
      senderName: json['senderName'] as String?,
      actionUrl: json['actionUrl'] as String?,
      imageUrl: json['imageUrl'] as String?,
      deliveryAttempts: json['deliveryAttempts'] as int? ?? 0,
    );
  }

  /// Creates a NotificationModel from a Firestore document.
  ///
  /// Handles Firestore-specific type conversion (Timestamp to DateTime).
  factory NotificationModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return NotificationModel(
      id: doc.id,
      userId: data['userId'] as String? ?? '',
      title: data['title'] as String? ?? '',
      body: data['body'] as String? ?? data['message'] as String? ?? '',
      type: _parseNotificationType(data['type']),
      priority: _parseNotificationPriority(data['priority']),
      data: Map<String, dynamic>.from(
          data['data'] as Map<String, dynamic>? ?? {}),
      isRead: data['isRead'] as bool? ?? false,
      isDelivered: data['isDelivered'] as bool? ?? false,
      createdAt: _parseTimestamp(data['createdAt']) ?? DateTime.now(),
      readAt: _parseTimestamp(data['readAt']),
      deliveredAt: _parseTimestamp(data['deliveredAt']),
      expiresAt: _parseTimestamp(data['expiresAt']),
      senderId: data['senderId'] as String?,
      senderName: data['senderName'] as String?,
      actionUrl: data['actionUrl'] as String?,
      imageUrl: data['imageUrl'] as String?,
      deliveryAttempts: data['deliveryAttempts'] as int? ?? 0,
    );
  }

  /// Converts this model to a JSON-compatible map.
  ///
  /// Uses ISO 8601 string format for dates.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'title': title,
      'body': body,
      'type': type.name,
      'priority': priority.name,
      'data': data,
      'isRead': isRead,
      'isDelivered': isDelivered,
      'createdAt': createdAt.toIso8601String(),
      'readAt': readAt?.toIso8601String(),
      'deliveredAt': deliveredAt?.toIso8601String(),
      'expiresAt': expiresAt?.toIso8601String(),
      'senderId': senderId,
      'senderName': senderName,
      'actionUrl': actionUrl,
      'imageUrl': imageUrl,
      'deliveryAttempts': deliveryAttempts,
    };
  }

  /// Converts this model to a Firestore-compatible map.
  ///
  /// Uses Firestore Timestamp objects for dates.
  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'title': title,
      'body': body,
      'type': type.name,
      'priority': priority.name,
      'data': data,
      'isRead': isRead,
      'isDelivered': isDelivered,
      'createdAt': Timestamp.fromDate(createdAt),
      'readAt': readAt != null ? Timestamp.fromDate(readAt!) : null,
      'deliveredAt':
          deliveredAt != null ? Timestamp.fromDate(deliveredAt!) : null,
      'expiresAt': expiresAt != null ? Timestamp.fromDate(expiresAt!) : null,
      'senderId': senderId,
      'senderName': senderName,
      'actionUrl': actionUrl,
      'imageUrl': imageUrl,
      'deliveryAttempts': deliveryAttempts,
    };
  }

  /// Creates a copy of this model with specified fields replaced.
  ///
  /// Useful for updating specific properties while maintaining immutability.
  NotificationModel copyWith({
    String? id,
    String? userId,
    String? title,
    String? body,
    NotificationType? type,
    NotificationPriority? priority,
    Map<String, dynamic>? data,
    bool? isRead,
    bool? isDelivered,
    DateTime? createdAt,
    DateTime? readAt,
    DateTime? deliveredAt,
    DateTime? expiresAt,
    String? senderId,
    String? senderName,
    String? actionUrl,
    String? imageUrl,
    int? deliveryAttempts,
  }) {
    return NotificationModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      body: body ?? this.body,
      type: type ?? this.type,
      priority: priority ?? this.priority,
      data: data ?? this.data,
      isRead: isRead ?? this.isRead,
      isDelivered: isDelivered ?? this.isDelivered,
      createdAt: createdAt ?? this.createdAt,
      readAt: readAt ?? this.readAt,
      deliveredAt: deliveredAt ?? this.deliveredAt,
      expiresAt: expiresAt ?? this.expiresAt,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      actionUrl: actionUrl ?? this.actionUrl,
      imageUrl: imageUrl ?? this.imageUrl,
      deliveryAttempts: deliveryAttempts ?? this.deliveryAttempts,
    );
  }

  // =============================================================================
  // BUSINESS LOGIC METHODS
  // =============================================================================

  /// Checks if this notification has expired and can be cleaned up.
  bool get isExpired {
    if (expiresAt == null) return false;
    return DateTime.now().isAfter(expiresAt!);
  }

  /// Checks if this notification is still pending (not read and not expired).
  bool get isPending {
    return !isRead && !isExpired;
  }

  /// Checks if this notification has an action URL.
  bool get hasAction {
    return actionUrl?.isNotEmpty == true;
  }

  /// Checks if this notification has an image.
  bool get hasImage {
    return imageUrl?.isNotEmpty == true;
  }

  /// Gets the age of this notification in hours.
  int get ageInHours {
    return DateTime.now().difference(createdAt).inHours;
  }

  /// Gets the age of this notification in days.
  int get ageInDays {
    return DateTime.now().difference(createdAt).inDays;
  }

  /// Checks if this notification is recent (less than 24 hours old).
  bool get isRecent {
    return ageInHours < 24;
  }

  /// Checks if this notification should be highlighted in the UI.
  bool get shouldHighlight {
    return isPending &&
        (priority.value >= NotificationPriority.high.value || type.isCritical);
  }

  /// Gets a short preview of the notification body (first 100 characters).
  String get bodyPreview {
    if (body.length <= 100) return body;
    return '${body.substring(0, 97)}...';
  }

  /// Gets a formatted time string for display (e.g., "2 hours ago").
  String get timeAgo {
    final now = DateTime.now();
    final difference = now.difference(createdAt);

    if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes == 1 ? '' : 's'} ago';
    } else {
      return 'Just now';
    }
  }

  /// Marks this notification as read and returns a new instance.
  NotificationModel markAsRead() {
    return copyWith(
      isRead: true,
      readAt: DateTime.now(),
    );
  }

  /// Marks this notification as delivered and returns a new instance.
  NotificationModel markAsDelivered() {
    return copyWith(
      isDelivered: true,
      deliveredAt: DateTime.now(),
    );
  }

  /// Increments the delivery attempts counter.
  NotificationModel incrementDeliveryAttempts() {
    return copyWith(deliveryAttempts: deliveryAttempts + 1);
  }

  /// Validates the notification data for completeness and correctness.
  ///
  /// Returns a list of validation errors, empty if valid.
  List<String> validate() {
    final errors = <String>[];

    // Required field validation
    if (userId.trim().isEmpty) {
      errors.add('User ID is required');
    }
    if (title.trim().isEmpty) {
      errors.add('Title is required');
    }
    if (body.trim().isEmpty) {
      errors.add('Body is required');
    }

    // Length validation
    if (title.length > maxTitleLength) {
      errors.add('Title must be $maxTitleLength characters or less');
    }
    if (body.length > maxBodyLength) {
      errors.add('Body must be $maxBodyLength characters or less');
    }

    // URL validation (basic)
    if (actionUrl?.isNotEmpty == true && !_isValidUrl(actionUrl!)) {
      errors.add('Action URL must be a valid URL');
    }
    if (imageUrl?.isNotEmpty == true && !_isValidUrl(imageUrl!)) {
      errors.add('Image URL must be a valid URL');
    }

    // Date validation
    if (readAt != null && readAt!.isBefore(createdAt)) {
      errors.add('Read time cannot be before creation time');
    }
    if (deliveredAt != null && deliveredAt!.isBefore(createdAt)) {
      errors.add('Delivery time cannot be before creation time');
    }
    if (expiresAt != null && expiresAt!.isBefore(createdAt)) {
      errors.add('Expiry time cannot be before creation time');
    }

    // Business logic validation
    if (isRead && readAt == null) {
      errors.add('Read notifications must have a read timestamp');
    }
    if (isDelivered && deliveredAt == null) {
      errors.add('Delivered notifications must have a delivery timestamp');
    }
    if (deliveryAttempts < 0) {
      errors.add('Delivery attempts cannot be negative');
    }

    return errors;
  }

  /// Creates a notification with automatic expiry date.
  factory NotificationModel.withAutoExpiry({
    required String id,
    required String userId,
    required String title,
    required String body,
    required NotificationType type,
    NotificationPriority priority = defaultPriority,
    Map<String, dynamic> data = const {},
    int expiryDays = defaultExpiryDays,
    String? senderId,
    String? senderName,
    String? actionUrl,
    String? imageUrl,
  }) {
    final now = DateTime.now();
    return NotificationModel(
      id: id,
      userId: userId,
      title: title,
      body: body,
      type: type,
      priority: priority,
      data: data,
      createdAt: now,
      expiresAt: now.add(Duration(days: expiryDays)),
      senderId: senderId,
      senderName: senderName,
      actionUrl: actionUrl,
      imageUrl: imageUrl,
    );
  }

  // =============================================================================
  // STATIC HELPER METHODS
  // =============================================================================

  /// Safely parses a NotificationType from dynamic data.
  static NotificationType _parseNotificationType(dynamic value) {
    if (value is String) {
      return NotificationType.values.firstWhere(
        (e) => e.name == value,
        orElse: () => NotificationType.info,
      );
    }
    return NotificationType.info;
  }

  /// Safely parses a NotificationPriority from dynamic data.
  static NotificationPriority _parseNotificationPriority(dynamic value) {
    if (value is String) {
      return NotificationPriority.values.firstWhere(
        (e) => e.name == value,
        orElse: () => defaultPriority,
      );
    }
    return defaultPriority;
  }

  /// Safely parses a DateTime from various formats.
  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;

    if (value is DateTime) return value;
    if (value is Timestamp) return value.toDate();
    if (value is String) {
      try {
        return DateTime.parse(value);
      } catch (e) {
        return null;
      }
    }

    return null;
  }

  /// Safely parses a Firestore Timestamp.
  static DateTime? _parseTimestamp(dynamic value) {
    if (value == null) return null;

    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;

    return null;
  }

  /// Basic URL validation.
  static bool _isValidUrl(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.hasAbsolutePath &&
          (uri.scheme == 'http' || uri.scheme == 'https');
    } catch (e) {
      return false;
    }
  }

  // =============================================================================
  // OBJECT OVERRIDES
  // =============================================================================

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NotificationModel &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'NotificationModel(id: $id, title: $title, type: $type, isRead: $isRead)';
}
