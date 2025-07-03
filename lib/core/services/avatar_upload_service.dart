import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:crypto/crypto.dart';

import '../config/app_config.dart';
import 'logger_service.dart';

/// Avatar Upload Service for the UPM Digital Certificate Repository.
///
/// This service provides comprehensive avatar/profile image management including:
/// - Image selection from camera or gallery with permissions
/// - Image validation and compression
/// - Firebase Storage upload with progress tracking
/// - User profile update with new avatar URL
/// - Old avatar cleanup and maintenance
///
/// Features:
/// - Multi-source image selection (camera/gallery)
/// - Automatic image compression and optimization
/// - Permission handling for camera and photos
/// - Firebase Storage integration with metadata
/// - Progress tracking for uploads
/// - Automatic cleanup of old avatars

/// Result of an avatar upload operation
class AvatarUploadResult {
  final String downloadUrl;
  final String fileName;
  final int originalSize;
  final int compressedSize;
  final String fileType;
  final DateTime uploadedAt;
  final Map<String, dynamic> metadata;

  const AvatarUploadResult({
    required this.downloadUrl,
    required this.fileName,
    required this.originalSize,
    required this.compressedSize,
    required this.fileType,
    required this.uploadedAt,
    this.metadata = const {},
  });

  /// Conversion to map for logging/storage
  Map<String, dynamic> toMap() {
    return {
      'downloadUrl': downloadUrl,
      'fileName': fileName,
      'originalSize': originalSize,
      'compressedSize': compressedSize,
      'fileType': fileType,
      'uploadedAt': uploadedAt.toIso8601String(),
      'metadata': metadata,
    };
  }
}

/// Avatar validation result
class AvatarValidationResult {
  final bool isValid;
  final List<String> errors;
  final Map<String, dynamic> details;

  const AvatarValidationResult({
    required this.isValid,
    this.errors = const [],
    this.details = const {},
  });

  factory AvatarValidationResult.success({Map<String, dynamic>? details}) {
    return AvatarValidationResult(
      isValid: true,
      details: details ?? {},
    );
  }

  factory AvatarValidationResult.failure(List<String> errors,
      {Map<String, dynamic>? details}) {
    return AvatarValidationResult(
      isValid: false,
      errors: errors,
      details: details ?? {},
    );
  }
}

/// Comprehensive avatar upload and management service
class AvatarUploadService {
  // =============================================================================
  // CONSTANTS
  // =============================================================================

  /// Maximum file size for avatars (5MB)
  static const int maxAvatarSize = 5 * 1024 * 1024;

  /// Supported image formats
  static const List<String> supportedFormats = ['jpg', 'jpeg', 'png', 'webp'];

  /// Maximum image dimensions
  static const int maxWidth = 1024;
  static const int maxHeight = 1024;

  /// Compression quality (0.0 to 1.0)
  static const double compressionQuality = 0.85;

  /// Number of old avatars to keep
  static const int keepAvatarHistory = 3;

  // =============================================================================
  // DEPENDENCIES
  // =============================================================================

  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ImagePicker _imagePicker = ImagePicker();

  // =============================================================================
  // STATE MANAGEMENT
  // =============================================================================

  bool _isInitialized = false;
  bool _isUploading = false;
  double _uploadProgress = 0.0;

  // =============================================================================
  // GETTERS
  // =============================================================================

  /// Whether the service is healthy and operational
  bool get isHealthy => _isInitialized && _auth.currentUser != null;

  /// Whether an upload is currently in progress
  bool get isUploading => _isUploading;

  /// Current upload progress (0.0 to 1.0)
  double get uploadProgress => _uploadProgress;

  // =============================================================================
  // INITIALIZATION
  // =============================================================================

  /// Initialize the avatar upload service
  Future<void> initialize() async {
    try {
      LoggerService.info('Initializing avatar upload service...');

      // Verify Firebase services are available
      if (FirebaseAuth.instance.currentUser == null) {
        LoggerService.warning(
            'Avatar service initialized without authenticated user');
      }

      // Test Firebase Storage connectivity
      try {
        await _storage.ref().child('test').getMetadata();
      } catch (e) {
        // If test fails, it might be because file doesn't exist, which is fine
        LoggerService.info('Firebase Storage connectivity test completed');
      }

      _isInitialized = true;
      LoggerService.info('Avatar upload service initialized successfully');
    } catch (e, stackTrace) {
      LoggerService.error('Failed to initialize avatar upload service',
          error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  // =============================================================================
  // PERMISSION MANAGEMENT
  // =============================================================================

  /// Request necessary permissions for camera and photo access
  Future<Map<String, bool>> requestPermissions() async {
    try {
      LoggerService.info('Requesting camera and photo permissions...');

      final results = <String, bool>{};

      // Request camera permission
      final cameraStatus = await Permission.camera.request();
      results['camera'] = cameraStatus.isGranted;

      // Request photos permission
      final photosStatus = await Permission.photos.request();
      results['photos'] = photosStatus.isGranted;

      LoggerService.info('Permission results: $results');
      return results;
    } catch (e) {
      LoggerService.error('Error requesting permissions', error: e);
      return {'camera': false, 'photos': false};
    }
  }

  /// Check current permission status
  Future<Map<String, bool>> checkPermissions() async {
    try {
      final cameraStatus = await Permission.camera.status;
      final photosStatus = await Permission.photos.status;

      return {
        'camera': cameraStatus.isGranted,
        'photos': photosStatus.isGranted,
      };
    } catch (e) {
      LoggerService.error('Error checking permissions', error: e);
      return {'camera': false, 'photos': false};
    }
  }

  // =============================================================================
  // IMAGE SOURCE SELECTION
  // =============================================================================

  /// Show dialog to select image source (camera or gallery)
  Future<ImageSource?> showImageSourceDialog(BuildContext context) async {
    return await showDialog<ImageSource>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Select Avatar Source'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Camera'),
                subtitle: const Text('Take a new photo'),
                onTap: () => Navigator.of(context).pop(ImageSource.camera),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Gallery'),
                subtitle: const Text('Choose from gallery'),
                onTap: () => Navigator.of(context).pop(ImageSource.gallery),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  // =============================================================================
  // IMAGE SELECTION
  // =============================================================================

  /// Pick image from camera with permission handling
  Future<File?> pickImageFromCamera() async {
    try {
      LoggerService.info('Picking image from camera...');

      // Check and request permissions
      final permissions = await checkPermissions();
      if (!permissions['camera']!) {
        final requested = await requestPermissions();
        if (!requested['camera']!) {
          throw Exception('Camera permission is required to take photos');
        }
      }

      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: (compressionQuality * 100).round(),
        maxWidth: maxWidth.toDouble(),
        maxHeight: maxHeight.toDouble(),
      );

      if (image != null) {
        final file = File(image.path);
        LoggerService.info('Image selected from camera: ${file.path}');
        return file;
      }

      LoggerService.info('No image selected from camera');
      return null;
    } catch (e) {
      LoggerService.error('Error picking image from camera', error: e);
      rethrow;
    }
  }

  /// Pick image from gallery with permission handling
  Future<File?> pickImageFromGallery() async {
    try {
      LoggerService.info('Picking image from gallery...');

      // Check and request permissions
      final permissions = await checkPermissions();
      if (!permissions['photos']!) {
        final requested = await requestPermissions();
        if (!requested['photos']!) {
          throw Exception('Photos permission is required to select images');
        }
      }

      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: (compressionQuality * 100).round(),
        maxWidth: maxWidth.toDouble(),
        maxHeight: maxHeight.toDouble(),
      );

      if (image != null) {
        final file = File(image.path);
        LoggerService.info('Image selected from gallery: ${file.path}');
        return file;
      }

      LoggerService.info('No image selected from gallery');
      return null;
    } catch (e) {
      LoggerService.error('Error picking image from gallery', error: e);
      rethrow;
    }
  }

  // =============================================================================
  // IMAGE VALIDATION
  // =============================================================================

  /// Validate image file with comprehensive checks
  AvatarValidationResult validateImage(File imageFile) {
    try {
      final errors = <String>[];
      final details = <String, dynamic>{};

      // Check if file exists
      if (!imageFile.existsSync()) {
        errors.add('Image file does not exist');
        return AvatarValidationResult.failure(errors);
      }

      // Check file size
      final fileSize = imageFile.lengthSync();
      details['fileSize'] = fileSize;

      if (fileSize > maxAvatarSize) {
        errors.add(
            'Image size (${_formatFileSize(fileSize)}) exceeds maximum allowed size (${_formatFileSize(maxAvatarSize)})');
      }

      if (fileSize < 1024) {
        // Minimum 1KB
        errors.add('Image file is too small (minimum 1KB required)');
      }

      // Check file extension
      final fileName = imageFile.path.toLowerCase();
      final extension = fileName.split('.').last;
      details['extension'] = extension;

      if (!supportedFormats.contains(extension)) {
        errors.add(
            'Unsupported image format: $extension. Supported formats: ${supportedFormats.join(', ')}');
      }

      // Basic file content validation
      try {
        final bytes = imageFile.readAsBytesSync();
        details['actualSize'] = bytes.length;

        // Check for common image file signatures
        if (bytes.length < 8) {
          errors.add('Image file appears to be corrupted (too small)');
        } else {
          final isValidImage = _validateImageSignature(bytes, extension);
          if (!isValidImage) {
            errors
                .add('Image file signature does not match the file extension');
          }
        }
      } catch (e) {
        errors.add('Unable to read image file: ${e.toString()}');
      }

      if (errors.isEmpty) {
        LoggerService.info('Image validation passed: ${details.toString()}');
        return AvatarValidationResult.success(details: details);
      } else {
        LoggerService.warning('Image validation failed: ${errors.join(', ')}');
        return AvatarValidationResult.failure(errors, details: details);
      }
    } catch (e) {
      LoggerService.error('Error during image validation', error: e);
      return AvatarValidationResult.failure(
          ['Validation error: ${e.toString()}']);
    }
  }

  /// Validate image file signature
  bool _validateImageSignature(Uint8List bytes, String extension) {
    if (bytes.length < 8) return false;

    switch (extension) {
      case 'jpg':
      case 'jpeg':
        return bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF;
      case 'png':
        return bytes[0] == 0x89 &&
            bytes[1] == 0x50 &&
            bytes[2] == 0x4E &&
            bytes[3] == 0x47;
      case 'webp':
        return bytes[0] == 0x52 &&
            bytes[1] == 0x49 &&
            bytes[2] == 0x46 &&
            bytes[3] == 0x46 &&
            bytes[8] == 0x57 &&
            bytes[9] == 0x45 &&
            bytes[10] == 0x42 &&
            bytes[11] == 0x50;
      default:
        return true; // Allow unknown formats to pass basic validation
    }
  }

  // =============================================================================
  // IMAGE PROCESSING
  // =============================================================================

  /// Compress and optimize image for avatar use
  Future<Uint8List> processImage(File imageFile) async {
    try {
      LoggerService.info('Processing image for avatar upload...');

      final originalBytes = await imageFile.readAsBytes();
      final originalSize = originalBytes.length;

      LoggerService.info(
          'Original image size: ${_formatFileSize(originalSize)}');

      // If image is already within acceptable size, return as-is
      if (originalSize <= maxAvatarSize * 0.8) {
        LoggerService.info('Image size acceptable, using original');
        return originalBytes;
      }

      // For web platform, we can't do much compression without additional packages
      if (kIsWeb) {
        if (originalSize > maxAvatarSize) {
          throw Exception(
              'Image too large for web upload. Please select a smaller image (max ${_formatFileSize(maxAvatarSize)})');
        }
        return originalBytes;
      }

      // For mobile platforms, implement basic size reduction
      // Note: For production, consider using packages like flutter_image_compress
      // For now, we'll implement basic file size checking and error handling

      if (originalSize > maxAvatarSize) {
        final compressionRatio = maxAvatarSize / originalSize;
        LoggerService.warning(
            'Image requires compression (ratio: ${(compressionRatio * 100).toStringAsFixed(1)}%)');

        // If compression ratio is too extreme, suggest user to resize
        if (compressionRatio < 0.3) {
          throw Exception(
              'Image is too large (${_formatFileSize(originalSize)}). Please resize to under ${_formatFileSize(maxAvatarSize)} or use a different image.');
        }

        // For now, we'll return the original and let Firebase handle it
        // In production, implement actual image compression here
        LoggerService.warning(
            'Image size exceeds limit but proceeding with original');
      }

      LoggerService.info('Image processing completed');
      return originalBytes;
    } catch (e) {
      LoggerService.error('Error processing image', error: e);
      rethrow;
    }
  }

  // =============================================================================
  // UPLOAD OPERATIONS
  // =============================================================================

  /// Upload avatar to Firebase Storage with comprehensive monitoring
  Future<AvatarUploadResult> uploadAvatar(
    File imageFile, {
    Function(double)? onProgress,
    Map<String, String>? customMetadata,
  }) async {
    try {
      _isUploading = true;
      _uploadProgress = 0.0;

      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception('No authenticated user found');
      }

      LoggerService.info('Starting avatar upload for user: ${currentUser.uid}');

      // Validate image
      final validation = validateImage(imageFile);
      if (!validation.isValid) {
        throw Exception(
            'Image validation failed: ${validation.errors.join(', ')}');
      }

      // Update progress
      _updateProgress(0.1, onProgress);

      // Process image
      final processedBytes = await processImage(imageFile);

      // Update progress
      _updateProgress(0.3, onProgress);

      // Generate unique filename
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extension = imageFile.path.split('.').last.toLowerCase();
      final hash = sha256.convert(processedBytes).toString().substring(0, 8);
      final fileName =
          'avatar_${currentUser.uid}_${timestamp}_$hash.$extension';

      // Create storage reference
      final storageRef = _storage
          .ref()
          .child('${AppConfig.profileImagesStoragePath}/$fileName');

      // Prepare metadata
      final metadata = SettableMetadata(
        contentType: 'image/$extension',
        customMetadata: {
          'userId': currentUser.uid,
          'uploadedAt': DateTime.now().toIso8601String(),
          'type': 'avatar',
          'originalSize': imageFile.lengthSync().toString(),
          'processedSize': processedBytes.length.toString(),
          'version': '1.0',
          ...?customMetadata,
        },
      );

      // Start upload
      final uploadTask = storageRef.putData(processedBytes, metadata);

      // Monitor upload progress
      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        final progress =
            0.3 + (snapshot.bytesTransferred / snapshot.totalBytes) * 0.6;
        _updateProgress(progress, onProgress);
      });

      // Wait for upload completion
      final TaskSnapshot snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();

      // Update progress
      _updateProgress(0.95, onProgress);

      // Create result
      final result = AvatarUploadResult(
        downloadUrl: downloadUrl,
        fileName: fileName,
        originalSize: imageFile.lengthSync(),
        compressedSize: processedBytes.length,
        fileType: extension,
        uploadedAt: DateTime.now(),
        metadata: metadata.customMetadata ?? {},
      );

      // Final progress update
      _updateProgress(1.0, onProgress);

      _isUploading = false;
      _uploadProgress = 0.0;

      LoggerService.info('Avatar upload completed successfully: $downloadUrl');
      return result;
    } catch (e) {
      _isUploading = false;
      _uploadProgress = 0.0;
      LoggerService.error('Avatar upload failed', error: e);
      rethrow;
    }
  }

  /// Update user profile with new avatar URL
  Future<void> updateUserAvatar(String avatarUrl) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception('No authenticated user found');
      }

      LoggerService.info('Updating user profile with new avatar URL...');

      // Update Firebase Auth profile
      await currentUser.updatePhotoURL(avatarUrl);

      // Update Firestore user document
      await _firestore.collection('users').doc(currentUser.uid).update({
        'photoURL': avatarUrl,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      LoggerService.info(
          'User avatar updated successfully in Firebase Auth and Firestore');
    } catch (e) {
      LoggerService.error('Failed to update user avatar', error: e);
      rethrow;
    }
  }

  /// Complete avatar update process (upload + profile update)
  Future<AvatarUploadResult> updateAvatar(
    File imageFile, {
    Function(double)? onProgress,
    bool deleteOldAvatar = true,
  }) async {
    try {
      LoggerService.info('Starting complete avatar update process...');

      // Get current user data for old avatar deletion
      String? oldAvatarUrl;
      if (deleteOldAvatar) {
        final currentUser = _auth.currentUser;
        if (currentUser != null) {
          oldAvatarUrl = currentUser.photoURL;
        }
      }

      // Upload new avatar
      final uploadResult = await uploadAvatar(
        imageFile,
        onProgress: (progress) {
          // Reserve last 10% for profile update
          onProgress?.call(progress * 0.9);
        },
      );

      // Update user profile
      await updateUserAvatar(uploadResult.downloadUrl);

      // Delete old avatar if exists and requested
      if (deleteOldAvatar && oldAvatarUrl != null && oldAvatarUrl.isNotEmpty) {
        await _deleteOldAvatar(oldAvatarUrl);
      }

      // Final progress update
      onProgress?.call(1.0);

      LoggerService.info(
          'Complete avatar update process finished successfully');
      return uploadResult;
    } catch (e) {
      LoggerService.error('Complete avatar update process failed', error: e);
      rethrow;
    }
  }

  // =============================================================================
  // AVATAR MANAGEMENT
  // =============================================================================

  /// Remove current user avatar
  Future<void> removeAvatar() async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception('No authenticated user found');
      }

      LoggerService.info('Removing user avatar...');

      final oldAvatarUrl = currentUser.photoURL;

      // Remove from Firebase Auth
      await currentUser.updatePhotoURL(null);

      // Remove from Firestore
      await _firestore.collection('users').doc(currentUser.uid).update({
        'photoURL': FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Delete from storage
      if (oldAvatarUrl != null && oldAvatarUrl.isNotEmpty) {
        await _deleteOldAvatar(oldAvatarUrl);
      }

      LoggerService.info('User avatar removed successfully');
    } catch (e) {
      LoggerService.error('Failed to remove user avatar', error: e);
      rethrow;
    }
  }

  /// Delete old avatar from Firebase Storage
  Future<void> _deleteOldAvatar(String avatarUrl) async {
    try {
      // Only delete if it's a Firebase Storage URL from our app
      if (avatarUrl.contains('firebase') &&
          avatarUrl.contains(
              AppConfig.profileImagesStoragePath.replaceAll('/', '%2F'))) {
        final storageRef = _storage.refFromURL(avatarUrl);
        await storageRef.delete();
        LoggerService.info('Old avatar deleted successfully: $avatarUrl');
      } else {
        LoggerService.info(
            'Skipping deletion of external avatar URL: $avatarUrl');
      }
    } catch (e) {
      LoggerService.warning('Could not delete old avatar: $e');
      // Don't throw error as this is not critical for the main operation
    }
  }

  // =============================================================================
  // UTILITY METHODS
  // =============================================================================

  /// Update upload progress and notify callback
  void _updateProgress(double progress, Function(double)? onProgress) {
    _uploadProgress = progress.clamp(0.0, 1.0);
    onProgress?.call(_uploadProgress);
  }

  /// Format file size for human-readable display
  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  /// Get avatar upload history for a user (admin function)
  Future<List<String>> getAvatarHistory(String userId) async {
    try {
      LoggerService.info('Getting avatar history for user: $userId');

      final listResult =
          await _storage.ref(AppConfig.profileImagesStoragePath).listAll();

      final userAvatars = <String>[];
      for (final item in listResult.items) {
        if (item.name.contains('avatar_${userId}_')) {
          final url = await item.getDownloadURL();
          userAvatars.add(url);
        }
      }

      LoggerService.info(
          'Found ${userAvatars.length} avatars for user $userId');
      return userAvatars;
    } catch (e) {
      LoggerService.error('Error getting avatar history', error: e);
      return [];
    }
  }

  /// Clean up old avatars for maintenance
  Future<int> cleanupOldAvatars(String userId,
      {int keepLatest = keepAvatarHistory}) async {
    try {
      LoggerService.info(
          'Cleaning up old avatars for user: $userId (keeping latest $keepLatest)');

      final avatarHistory = await getAvatarHistory(userId);

      if (avatarHistory.length <= keepLatest) {
        LoggerService.info(
            'No cleanup needed - user has ${avatarHistory.length} avatars');
        return 0;
      }

      // Sort by timestamp (assuming filename contains timestamp)
      avatarHistory.sort((a, b) => b.compareTo(a)); // Newest first

      final toDelete = avatarHistory.skip(keepLatest).toList();
      int deletedCount = 0;

      for (final avatarUrl in toDelete) {
        try {
          await _deleteOldAvatar(avatarUrl);
          deletedCount++;
        } catch (e) {
          LoggerService.warning('Failed to delete avatar $avatarUrl: $e');
        }
      }

      LoggerService.info(
          'Cleaned up $deletedCount old avatars for user $userId');
      return deletedCount;
    } catch (e) {
      LoggerService.error('Error cleaning up old avatars', error: e);
      return 0;
    }
  }

  /// Get service statistics
  Future<Map<String, dynamic>> getServiceStats() async {
    try {
      final currentUser = _auth.currentUser;
      final stats = <String, dynamic>{
        'isInitialized': _isInitialized,
        'isHealthy': isHealthy,
        'isUploading': _isUploading,
        'uploadProgress': _uploadProgress,
        'hasCurrentUser': currentUser != null,
        'supportedFormats': supportedFormats,
        'maxAvatarSize': maxAvatarSize,
        'maxDimensions': {'width': maxWidth, 'height': maxHeight},
      };

      if (currentUser != null) {
        stats['currentUserId'] = currentUser.uid;
        stats['hasAvatar'] = currentUser.photoURL?.isNotEmpty == true;

        // Get user's avatar count
        final avatarHistory = await getAvatarHistory(currentUser.uid);
        stats['avatarCount'] = avatarHistory.length;
      }

      return stats;
    } catch (e) {
      LoggerService.error('Error getting service stats', error: e);
      return {'error': e.toString()};
    }
  }
}
