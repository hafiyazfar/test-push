import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/models/user_model.dart';
import '../../../core/services/logger_service.dart';
import '../../../core/config/app_config.dart';
import 'user_service.dart';
import '../../dashboard/services/activity_service.dart';

class AuthService {
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
  );
  final UserService _userService = UserService();
  final ActivityService _activityService = ActivityService();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  static const String _rememberMeKey = 'remember_me';
  static const String _rememberEmailKey = 'remember_email';

  // Get current user stream
  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();

  // Get current user
  User? get currentUser => _firebaseAuth.currentUser;

  // Check if user is signed in
  bool get isSignedIn => _firebaseAuth.currentUser != null;

  // Remember me functionality
  Future<void> setRememberMe(bool remember, String email) async {
    try {
      await _storage.write(key: _rememberMeKey, value: remember.toString());
      if (remember) {
        await _storage.write(key: _rememberEmailKey, value: email);
      } else {
        await _storage.delete(key: _rememberEmailKey);
      }
    } catch (e) {
      LoggerService.error('Error setting remember me', error: e);
    }
  }

  Future<Map<String, dynamic>> getRememberMeData() async {
    try {
      final rememberString = await _storage.read(key: _rememberMeKey);
      final email = await _storage.read(key: _rememberEmailKey);

      return {
        'remember': rememberString == 'true',
        'email': email ?? '',
      };
    } catch (e) {
      LoggerService.error('Error getting remember me data', error: e);
      return {'remember': false, 'email': ''};
    }
  }

  Future<bool> getRememberMeStatus() async {
    final rememberData = await getRememberMeData();
    return rememberData['remember'] as bool;
  }

  Future<String?> getRememberedEmail() async {
    final rememberData = await getRememberMeData();
    final remember = rememberData['remember'] as bool;
    if (remember) {
      return rememberData['email'] as String?;
    }
    return null;
  }

  Future<void> _clearRememberMe() async {
    try {
      await _storage.delete(key: _rememberMeKey);
      await _storage.delete(key: _rememberEmailKey);
    } catch (e) {
      LoggerService.error('Error clearing remember me', error: e);
    }
  }

  // Get current Firebase user synchronously
  User? get currentFirebaseUser => _firebaseAuth.currentUser;

  // Sign in with Google - Enhanced for UPM email validation
  Future<UserModel?> signInWithGoogle() async {
    try {
      LoggerService.info('Starting Google Sign-In process...');

      try {
        await _googleSignIn.signOut();
        LoggerService.info('Previous Google Sign-In session cleared');
      } catch (e) {
        LoggerService.warning('Warning: Could not clear previous session',
            error: e);
      }

      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        try {
          await _googleSignIn.signOut();
        } catch (e) {
          LoggerService.error('Google Sign-In account selection failed',
              error: e);
        }

        LoggerService.info('Google sign-in cancelled by user');
        throw Exception('Google sign-in was cancelled by the user');
      }

      LoggerService.info('Google user selected: ${googleUser.email}');

      if (!AppConfig.isValidUpmEmail(googleUser.email)) {
        LoggerService.warning('Invalid email domain: ${googleUser.email}');
        await _googleSignIn.signOut();
        throw Exception('Only UPM email addresses (@upm.edu.my) are allowed');
      }

      GoogleSignInAuthentication? googleAuth;
      try {
        googleAuth = await googleUser.authentication;
        LoggerService.info('Google authentication tokens obtained');
      } catch (e) {
        LoggerService.error('Failed to obtain Google authentication', error: e);
        await _googleSignIn.signOut();
        rethrow;
      }

      if (googleAuth.accessToken == null || googleAuth.idToken == null) {
        LoggerService.error('Missing required authentication tokens');
        await _googleSignIn.signOut();
        throw Exception('Failed to obtain authentication tokens');
      }

      final AuthCredential credential;
      try {
        credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );
        LoggerService.info('Firebase credential created');
      } catch (e) {
        LoggerService.error('Failed to create Firebase credential', error: e);
        await _googleSignIn.signOut();
        rethrow;
      }

      UserCredential? userCredential;
      try {
        userCredential = await _firebaseAuth.signInWithCredential(credential);
        LoggerService.info('Firebase authentication successful');
      } catch (e) {
        LoggerService.error('Firebase sign-in failed', error: e);
        await _googleSignIn.signOut();
        rethrow;
      }

      final user = userCredential.user;
      if (user == null) {
        LoggerService.error(
            'Firebase user is null after successful authentication');
        await _googleSignIn.signOut();
        throw Exception('Authentication failed: User data unavailable');
      }

      LoggerService.info('User authenticated: ${user.email}');

      UserModel? userModel;
      try {
        userModel = await _userService.getUserById(user.uid);
        LoggerService.info(
            'User model fetched from Firestore: ${userModel?.email}');
      } catch (e) {
        LoggerService.warning('Error fetching user from Firestore', error: e);
        userModel = null;
      }

      if (userModel == null) {
        try {
          LoggerService.info(
              'Creating new user with role: ${UserRole.recipient.name}, type: ${UserType.user.name}');

          userModel = await _createUserFromFirebaseUser(
            user,
            UserRole.recipient,
            user.displayName ?? googleUser.displayName ?? 'Google User',
            UserStatus.active,
            UserType.user,
          );

          LoggerService.info(
              'New user created: ${user.email} with role: ${UserRole.recipient.name}');

          await _activityService.logAuthActivity(
            action: 'register_google',
            details: 'New user registered via Google: ${user.email}',
          );
        } catch (createError) {
          LoggerService.error('Failed to create user in Firestore',
              error: createError);

          try {
            await _firebaseAuth.signOut();
            await _googleSignIn.signOut();
          } catch (signOutError) {
            LoggerService.error('Error during cleanup after creation failure',
                error: signOutError);
          }

          rethrow;
        }
      } else {
        if (userModel.status == UserStatus.pending) {
          await _firebaseAuth.signOut();
          await _googleSignIn.signOut();
          throw Exception(
              'Your account is pending approval. Please wait for confirmation.');
        }

        if (userModel.status == UserStatus.suspended) {
          await _firebaseAuth.signOut();
          await _googleSignIn.signOut();
          throw Exception(
              'Your account has been suspended. Please contact administrator.');
        }

        try {
          await _updateLastLogin(user.uid);

          await _activityService.logAuthActivity(
            action: 'login_google',
            details: 'User signed in via Google: ${user.email}',
          );

          LoggerService.info('Last login updated for user: ${user.email}');
        } catch (e) {
          LoggerService.warning('Failed to update last login', error: e);
        }
      }

      LoggerService.info(
          'Google sign-in completed successfully for user: ${user.email}');
      return userModel;
    } on FirebaseAuthException catch (e) {
      LoggerService.error('Firebase Auth error during Google sign-in',
          error: e);

      try {
        await _firebaseAuth.signOut();
        await _googleSignIn.signOut();
      } catch (signOutError) {
        LoggerService.warning('Error during cleanup sign out',
            error: signOutError);
      }

      throw _handleFirebaseAuthException(e);
    } catch (e) {
      LoggerService.error('Google sign-in error', error: e);

      try {
        await _firebaseAuth.signOut();
        await _googleSignIn.signOut();
      } catch (signOutError) {
        LoggerService.warning('Error during cleanup sign out',
            error: signOutError);
      }

      rethrow;
    }
  }

  // Determine user role from UPM email
  UserRole _determineUserRoleFromEmail(String email) {
    // Extract the part before @upm.edu.my
    final emailPrefix = email.toLowerCase().split('@').first;

    // Check for admin patterns
    if (emailPrefix.contains('admin') ||
        emailPrefix.contains('system') ||
        emailPrefix.startsWith('gs') || // Graduate School
        emailPrefix.startsWith('vc') || // Vice Chancellor
        emailPrefix.startsWith('dvc')) {
      // Deputy Vice Chancellor
      return UserRole.systemAdmin;
    }

    // Check for CA patterns (usually faculty/department heads)
    if (emailPrefix.contains('dean') ||
        emailPrefix.contains('director') ||
        emailPrefix.contains('head') ||
        emailPrefix.contains('registrar') ||
        emailPrefix.contains('academic')) {
      return UserRole.certificateAuthority;
    }

    // Check for staff/faculty patterns
    if (emailPrefix.contains('staff') ||
        emailPrefix.contains('faculty') ||
        emailPrefix.length < 6) {
      // Usually staff have shorter IDs
      return UserRole.certificateAuthority;
    }

    // Default to recipient for students and others
    return UserRole.recipient;
  }

  // Map UserRole to UserType
  UserType _determineUserTypeFromRole(UserRole role) {
    switch (role) {
      case UserRole.systemAdmin:
        return UserType.admin;
      case UserRole.client:
        return UserType.client;
      case UserRole.certificateAuthority:
        return UserType.ca;
      case UserRole.recipient:
      case UserRole.viewer:
        return UserType.user;
    }
  }

  // Sign in with email and password - Enhanced validation
  Future<UserModel?> signInWithEmailAndPassword(
      String email, String password) async {
    try {
      // Validate UPM email domain
      if (!AppConfig.isValidUpmEmail(email)) {
        throw Exception('Please use your UPM email address (@upm.edu.my)');
      }

      final UserCredential userCredential =
          await _firebaseAuth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final user = userCredential.user;
      if (user == null) {
        throw Exception('Failed to sign in');
      }

      // Get user model
      UserModel? userModel = await _userService.getUserById(user.uid);

      if (userModel == null) {
        // If user exists in Auth but not in Firestore, create them
        LoggerService.info(
            'User ${user.uid} found in Auth but not Firestore. Creating now...');
        final userRole = _determineUserRoleFromEmail(email);
        final userType = _determineUserTypeFromRole(userRole);
        userModel = await _createUserFromFirebaseUser(
          user,
          userRole,
          user.displayName ?? user.email?.split('@').first ?? 'User',
          UserStatus.active,
          userType,
        );

        // Log registration activity
        await _activityService.logAuthActivity(
          action: 'register',
          details: 'New user registered via email sign-in: $email',
        );
      }

      // Check if account is active (userModel is guaranteed to be non-null here)
      if (userModel.status == UserStatus.suspended) {
        throw Exception(
            'Your account has been suspended. Contact administrator.');
      } else if (userModel.status == UserStatus.pending) {
        throw Exception(
            'Your account is pending approval. Please wait for confirmation.');
      }

      await _updateLastLogin(user.uid);

      // Log successful login activity
      await _activityService.logAuthActivity(
        action: 'login',
        details: 'User signed in via email: $email',
      );

      LoggerService.info('Email sign-in successful for user: $email');
      return userModel;
    } on FirebaseAuthException catch (e) {
      LoggerService.error('Email sign-in error', error: e);
      throw _handleFirebaseAuthException(e);
    } catch (e) {
      LoggerService.error('Sign-in error', error: e);
      rethrow;
    }
  }

  // Sign up with email and password - Enhanced for UPM validation
  Future<UserModel?> signUpWithEmailAndPassword(
    String email,
    String password,
    String displayName,
    UserType userType,
  ) async {
    try {
      LoggerService.info('Starting email sign-up for: $email');

      // Validate UPM email domain for all roles
      if (!AppConfig.isValidUpmEmail(email)) {
        throw Exception(
            'Registration requires a valid UPM email address (@upm.edu.my)');
      }

      // Additional validation for admin/CA/Client roles
      if ((userType == UserType.client ||
          userType == UserType.ca ||
          userType == UserType.admin)) {
        final emailPrefix = email.toLowerCase().split('@').first;
        if (userType == UserType.admin && !_isValidAdminEmail(emailPrefix)) {
          throw Exception(
              'System administrator role requires valid admin credentials');
        }
      }

      final UserCredential userCredential =
          await _firebaseAuth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final user = userCredential.user;
      if (user == null) {
        throw Exception('Failed to create account');
      }

      await user.updateDisplayName(displayName);

      // Create user model in Firestore with pending status for manual approval
      final userStatus = (userType == UserType.admin ||
              userType == UserType.client ||
              userType == UserType.ca)
          ? UserStatus.pending
          : UserStatus.active;

      // Convert UserType to UserRole
      UserRole role;
      switch (userType) {
        case UserType.admin:
          role = UserRole.systemAdmin;
          break;
        case UserType.client:
          role = UserRole.client;
          break;
        case UserType.ca:
          role = UserRole.certificateAuthority;
          break;
        case UserType.user:
          role = UserRole.recipient;
          break;
      }

      final userModel = await _createUserFromFirebaseUser(
          user, role, displayName, userStatus, userType);

      await user.sendEmailVerification();

      // Log registration activity
      await _activityService.logAuthActivity(
        action: 'register',
        details: 'New user registered: $email with role: ${role.name}',
      );

      LoggerService.info(
          'Account created successfully for user: $email with role: ${role.name}');
      return userModel;
    } on FirebaseAuthException catch (e) {
      LoggerService.error('Sign-up error', error: e);
      throw _handleFirebaseAuthException(e);
    } catch (e) {
      LoggerService.error('Sign-up error', error: e);
      rethrow;
    }
  }

  // Validate admin email patterns
  bool _isValidAdminEmail(String emailPrefix) {
    const adminPatterns = [
      'admin',
      'system',
      'registrar',
      'vc',
      'dvc',
      'gs',
      'dean',
      'director'
    ];
    return adminPatterns.any((pattern) => emailPrefix.contains(pattern));
  }

  // Sign out
  Future<void> signOut() async {
    try {
      LoggerService.info('Starting sign out process...');

      // Log logout activity before signing out
      final currentUser = _firebaseAuth.currentUser;
      if (currentUser != null) {
        await _activityService.logAuthActivity(
          action: 'logout',
          details: 'User signed out: ${currentUser.email}',
        );
      }

      // Clear remember me settings
      await _clearRememberMe();

      // Sign out from both Firebase Auth and Google Sign In
      await Future.wait([
        _firebaseAuth.signOut(),
        _googleSignIn.signOut(),
      ]);

      LoggerService.info(
          'User signed out successfully from Firebase and Google');
    } catch (e) {
      LoggerService.error('Sign-out error', error: e);
      rethrow;
    }
  }

  // Check if user should auto-login (for splash screen)
  Future<bool> shouldAutoLogin() async {
    try {
      final rememberData = await getRememberMeData();
      final rememberMe = rememberData['remember'] as bool;
      final currentUser = _firebaseAuth.currentUser;
      return rememberMe && currentUser != null;
    } catch (e) {
      LoggerService.error('Error checking auto-login status', error: e);
      return false;
    }
  }

  // Reset password
  Future<void> resetPassword(String email) async {
    try {
      if (!AppConfig.isValidUpmEmail(email)) {
        throw Exception('Please enter a valid UPM email address');
      }

      await _firebaseAuth.sendPasswordResetEmail(email: email.trim());
      LoggerService.info('Password reset email sent to: $email');
    } on FirebaseAuthException catch (e) {
      LoggerService.error('Password reset error', error: e);
      throw _handleFirebaseAuthException(e);
    } catch (e) {
      LoggerService.error('Password reset error', error: e);
      rethrow;
    }
  }

  // Update user profile
  Future<UserModel> updateUserProfile(UserModel updatedUser) async {
    try {
      final user = _firebaseAuth.currentUser;
      if (user == null) {
        throw Exception('No authenticated user');
      }

      // Update Firebase Auth profile
      if (updatedUser.displayName != user.displayName) {
        await user.updateDisplayName(updatedUser.displayName);
      }

      if (updatedUser.photoURL != user.photoURL) {
        await user.updatePhotoURL(updatedUser.photoURL);
      }

      // Update user in Firestore
      final userModel = await _userService.updateUser(updatedUser);
      LoggerService.info('User profile updated successfully');
      return userModel;
    } catch (e) {
      LoggerService.error('Profile update error', error: e);
      rethrow;
    }
  }

  // Change password
  Future<void> changePassword(
      String currentPassword, String newPassword) async {
    try {
      final user = _firebaseAuth.currentUser;
      if (user == null) {
        throw Exception('No authenticated user');
      }

      // Re-authenticate user
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: currentPassword,
      );
      await user.reauthenticateWithCredential(credential);

      // Update password
      await user.updatePassword(newPassword);
      LoggerService.info('Password changed successfully');
    } on FirebaseAuthException catch (e) {
      LoggerService.error('Password change error', error: e);
      throw _handleFirebaseAuthException(e);
    } catch (e) {
      LoggerService.error('Password change error', error: e);
      rethrow;
    }
  }

  // Delete account
  Future<void> deleteAccount(String password) async {
    try {
      final user = _firebaseAuth.currentUser;
      if (user == null) {
        throw Exception('No authenticated user');
      }

      // Re-authenticate user
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: password,
      );
      await user.reauthenticateWithCredential(credential);

      // Delete user data from Firestore
      await _userService.deleteUser(user.uid);

      // Delete Firebase Auth account
      await user.delete();
      LoggerService.info('Account deleted successfully');
    } on FirebaseAuthException catch (e) {
      LoggerService.error('Account deletion error', error: e);
      throw _handleFirebaseAuthException(e);
    } catch (e) {
      LoggerService.error('Account deletion error', error: e);
      rethrow;
    }
  }

  // Verify email
  Future<void> sendEmailVerification() async {
    try {
      final user = _firebaseAuth.currentUser;
      if (user == null) {
        throw Exception('No authenticated user');
      }

      if (!user.emailVerified) {
        await user.sendEmailVerification();
        LoggerService.info('Email verification sent');
      }
    } catch (e) {
      LoggerService.error('Email verification error', error: e);
      rethrow;
    }
  }

  // Check if email is verified
  Future<bool> isEmailVerified() async {
    final user = _firebaseAuth.currentUser;
    if (user == null) return false;

    await user.reload();
    return user.emailVerified;
  }

  // Create user model from Firebase user
  Future<UserModel> _createUserFromFirebaseUser(
    User firebaseUser,
    UserRole role,
    String displayName,
    UserStatus status,
    UserType userType,
  ) async {
    final now = DateTime.now();

    final userModel = UserModel(
      id: firebaseUser.uid,
      email: firebaseUser.email ?? '',
      displayName: displayName,
      photoURL: firebaseUser.photoURL,
      role: role,
      status: status,
      createdAt: now,
      updatedAt: now,
      lastLoginAt: now,
      isEmailVerified: firebaseUser.emailVerified,
      profile: {
        'department': _extractDepartmentFromEmail(firebaseUser.email ?? ''),
        'university': AppConfig.universityName,
        'emailDomain': AppConfig.upmEmailDomain,
      },
      permissions: _getDefaultPermissions(role),
      metadata: {
        'signInMethod': firebaseUser.providerData.isNotEmpty
            ? firebaseUser.providerData.first.providerId
            : 'email',
        'createdBy': 'self-registration',
        'emailPrefix': firebaseUser.email?.split('@').first ?? '',
        'registrationSource': 'mobile_app',
      },
      userType: userType,
    );

    // Create the user and verify it was created successfully
    final createdUser = await _userService.createUser(userModel);

    // Verify the user was actually created by trying to fetch it
    UserModel? verifyUser;
    int retryCount = 0;
    const maxRetries = 3;
    const retryDelay = Duration(milliseconds: 500);

    while (retryCount < maxRetries) {
      try {
        verifyUser = await _userService.getUserById(firebaseUser.uid);
        if (verifyUser != null) {
          LoggerService.info(
              'User creation verified successfully: ${firebaseUser.uid}');
          break;
        }
      } catch (e) {
        LoggerService.warning(
            'User verification attempt ${retryCount + 1} failed: $e');
      }

      if (retryCount < maxRetries - 1) {
        await Future.delayed(retryDelay);
        retryCount++;
      } else {
        LoggerService.error(
            'Failed to verify user creation after $maxRetries attempts');
        throw Exception('User creation verification failed - please try again');
      }
    }

    if (verifyUser == null) {
      LoggerService.error(
          'User verification failed - user not found in Firestore');
      throw Exception('User creation verification failed - please try again');
    }

    return createdUser;
  }

  // Extract department from UPM email
  String _extractDepartmentFromEmail(String email) {
    final emailPrefix = email.toLowerCase().split('@').first;

    // Common UPM department patterns
    if (emailPrefix.startsWith('fpp')) return 'Faculty of Educational Studies';
    if (emailPrefix.startsWith('fst'))
      return 'Faculty of Science and Technology';
    if (emailPrefix.startsWith('fpe')) return 'Faculty of Engineering';
    if (emailPrefix.startsWith('fpm'))
      return 'Faculty of Medicine and Health Sciences';
    if (emailPrefix.startsWith('fpv')) return 'Faculty of Veterinary Medicine';
    if (emailPrefix.startsWith('fpe'))
      return 'Faculty of Economics and Management';
    if (emailPrefix.startsWith('fbmk'))
      return 'Faculty of Modern Languages and Communication';
    if (emailPrefix.startsWith('fs')) return 'Faculty of Science';
    if (emailPrefix.startsWith('fp')) return 'Faculty of Agriculture';
    if (emailPrefix.startsWith('frsb'))
      return 'Faculty of Forestry and Environment';
    if (emailPrefix.startsWith('gs')) return 'Graduate School';

    return 'Unknown Department';
  }

  // Get default permissions for role
  List<String> _getDefaultPermissions(UserRole role) {
    switch (role) {
      case UserRole.systemAdmin:
        return ['*']; // All permissions
      case UserRole.certificateAuthority:
        return [
          'certificates.create',
          'certificates.issue',
          'certificates.manage',
          'certificates.approve',
          'documents.verify',
          'documents.certify',
          'users.view_clients',
          'templates.manage',
          'reports.view',
        ];
      case UserRole.client:
        return [
          'certificates.request',
          'certificates.approve',
          'certificates.view_own',
          'documents.upload',
          'documents.view_own',
          'users.manage_recipients',
        ];
      case UserRole.recipient:
        return [
          'certificates.view_own',
          'certificates.download',
          'certificates.share',
          'documents.view_own',
          'documents.upload',
          'profile.manage',
        ];
      case UserRole.viewer:
        return [
          'certificates.view_shared',
          'documents.view_shared',
          'certificates.verify',
        ];
    }
  }

  // Update last login timestamp
  Future<void> _updateLastLogin(String userId) async {
    try {
      await _userService.updateUserLastLogin(userId);
    } catch (e) {
      LoggerService.warning('Failed to update last login', error: e);
    }
  }

  // Handle Firebase Auth exceptions
  Exception _handleFirebaseAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return Exception('No account found with this email address');
      case 'wrong-password':
        return Exception('Incorrect password');
      case 'email-already-in-use':
        return Exception('An account already exists with this email address');
      case 'weak-password':
        return Exception(
            'Password must be at least ${AppConfig.passwordMinLength} characters');
      case 'invalid-email':
        return Exception('Invalid email address format');
      case 'user-disabled':
        return Exception('This account has been disabled');
      case 'too-many-requests':
        return Exception('Too many failed attempts. Please try again later');
      case 'operation-not-allowed':
        return Exception('This sign-in method is not enabled');
      case 'requires-recent-login':
        return Exception('Please re-authenticate to perform this action');
      case 'network-request-failed':
        return Exception('Network error. Please check your connection');
      default:
        return Exception(e.message ?? 'Authentication error occurred');
    }
  }
}
