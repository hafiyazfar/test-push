import 'package:cloud_firestore/cloud_firestore.dart';

/// Utility class for safe timestamp handling and conversion
class TimestampUtils {
  /// Safely parse timestamp from any type to DateTime
  ///
  /// Supports:
  /// - Firestore Timestamp
  /// - String (ISO 8601 format)
  /// - int (milliseconds since epoch)
  /// - DateTime (passthrough)
  ///
  /// Returns current DateTime for null or invalid inputs
  static DateTime parseTimestamp(dynamic timestamp) {
    try {
      if (timestamp == null) {
        return DateTime.now();
      } else if (timestamp is Timestamp) {
        return timestamp.toDate();
      } else if (timestamp is DateTime) {
        return timestamp;
      } else if (timestamp is String) {
        if (timestamp.isEmpty) return DateTime.now();
        return DateTime.parse(timestamp);
      } else if (timestamp is int) {
        return DateTime.fromMillisecondsSinceEpoch(timestamp);
      } else {
        return DateTime.now();
      }
    } catch (e) {
      // Fallback to current time if parsing fails
      return DateTime.now();
    }
  }

  /// Convert DateTime to Firestore Timestamp
  static Timestamp toTimestamp(DateTime dateTime) {
    return Timestamp.fromDate(dateTime);
  }

  /// Safely parse timestamp and format as string
  static String formatTimestamp(dynamic timestamp,
      {String format = 'yyyy-MM-dd HH:mm:ss'}) {
    final dateTime = parseTimestamp(timestamp);
    // For basic formatting without external dependencies
    return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} '
        '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}:${dateTime.second.toString().padLeft(2, '0')}';
  }

  /// Get time ago string from timestamp
  static String timeAgo(dynamic timestamp) {
    final dateTime = parseTimestamp(timestamp);
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 365) {
      final years = (difference.inDays / 365).floor();
      return '${years}y ago';
    } else if (difference.inDays > 30) {
      final months = (difference.inDays / 30).floor();
      return '${months}mo ago';
    } else if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  /// Check if timestamp is valid
  static bool isValidTimestamp(dynamic timestamp) {
    try {
      parseTimestamp(timestamp);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Convert timestamp to ISO 8601 string
  static String toIsoString(dynamic timestamp) {
    final dateTime = parseTimestamp(timestamp);
    return dateTime.toIso8601String();
  }

  /// Get start of day for timestamp
  static DateTime startOfDay(dynamic timestamp) {
    final dateTime = parseTimestamp(timestamp);
    return DateTime(dateTime.year, dateTime.month, dateTime.day);
  }

  /// Get end of day for timestamp
  static DateTime endOfDay(dynamic timestamp) {
    final dateTime = parseTimestamp(timestamp);
    return DateTime(
        dateTime.year, dateTime.month, dateTime.day, 23, 59, 59, 999);
  }
}
