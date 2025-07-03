import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:logger/logger.dart';

import '../../../core/models/user_model.dart';
import '../services/auth_service.dart';
import '../services/user_service.dart';
import '../../dashboard/services/activity_service.dart';
import '../../../core/services/logger_service.dart';

// Authentication State Provider
final authStateProvider = StreamProvider<User?>((ref) {
  return FirebaseAuth.instance.authStateChanges();
});

// Current User Provider - Get complete user information from Firestore
final currentUserProvider = StreamProvider<UserModel?>((ref) {
  return FirebaseAuth.instance.authStateChanges().asyncMap((authUser) async {
    if (authUser == null) {
      LoggerService.info(
          '🔄 currentUserProvider - No auth user, returning null');
      return null;
    }

    final userService = ref.read(userServiceProvider);
    LoggerService.info(
        '🔄 currentUserProvider - Loading user data for UID: ${authUser.uid}');

    try {
      // Add retry logic to handle race conditions when creating users
      UserModel? userModel;
      int retryCount = 0;
      const maxRetries = 5; // 增加重试次数
      const retryDelay = Duration(milliseconds: 500); // 减少重试间隔

      while (retryCount < maxRetries) {
        userModel = await userService.getUserById(authUser.uid);

        if (userModel != null) {
          LoggerService.info(
              '🔄 currentUserProvider - User data loaded successfully: ${userModel.email}, type: ${userModel.userType}');
          return userModel;
        }

        // If first attempt fails, wait for a while before retrying
        if (retryCount < maxRetries - 1) {
          LoggerService.warning(
              'User data not found, retrying in ${retryDelay.inMilliseconds}ms... (attempt ${retryCount + 1}/$maxRetries)');
          await Future.delayed(retryDelay);
          retryCount++;
        } else {
          break;
        }
      }

      // If user data is still not found after retrying
      if (userModel == null) {
        LoggerService.error(
            'User ${authUser.uid} exists in Auth but not in Firestore after $maxRetries attempts.');

        // 不抛出异常，而是返回null，让路由逻辑处理
        // 这样避免了路由重定向死循环
        return null;
      }

      return userModel;
    } catch (e) {
      LoggerService.error(
          'Error fetching user data in currentUserProvider for UID ${authUser.uid}: $e');

      // 发生错误时也返回null，避免路由死循环
      return null;
    }
  });
});

// Authentication Service Provider
final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService();
});

// User Service Provider
final userServiceProvider = Provider<UserService>((ref) {
  return UserService();
});

// Activity Service Provider
final activityServiceProvider = Provider<ActivityService>((ref) {
  return ActivityService();
});

// Authentication State Notifier
final authNotifierProvider =
    StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref.read(authServiceProvider));
});

// Role-based Access Providers
final canCreateCertificatesProvider = Provider<bool>((ref) {
  final user = ref.watch(currentUserProvider).value;
  return (user?.isCA ?? false) || (user?.isAdmin ?? false);
});

final canManageUsersProvider = Provider<bool>((ref) {
  final user = ref.watch(currentUserProvider).value;
  return user?.isAdmin ?? false;
});

final canApproveRequestsProvider = Provider<bool>((ref) {
  final user = ref.watch(currentUserProvider).value;
  return (user?.isClientType ?? false) || (user?.isAdmin ?? false);
});

final canUploadDocumentsProvider = Provider<bool>((ref) {
  final user = ref.watch(currentUserProvider).value;
  return (user?.isClientType ?? false) ||
      (user?.isAdmin ?? false) ||
      (user?.isCA ?? false);
});

final canViewReportsProvider = Provider<bool>((ref) {
  final user = ref.watch(currentUserProvider).value;
  return user?.isAdmin ?? false;
});

// Authentication State Classes
class AuthState {
  final bool isLoading;
  final bool isAuthenticated;
  final String? error;
  final UserModel? user;

  const AuthState({
    this.isLoading = false,
    this.isAuthenticated = false,
    this.error,
    this.user,
  });

  AuthState copyWith({
    bool? isLoading,
    bool? isAuthenticated,
    String? error,
    UserModel? user,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      error: error ?? this.error,
      user: user ?? this.user,
    );
  }

  AuthState clearError() {
    return copyWith(error: null);
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthService _authService;

  AuthNotifier(this._authService) : super(const AuthState()) {
    _initAuth();
  }

  void _initAuth() {
    FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null) {
        state = state.copyWith(
          isAuthenticated: true,
          isLoading: false,
        );
      } else {
        state = state.copyWith(
          isAuthenticated: false,
          isLoading: false,
          user: null,
        );
      }
    });
  }

  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      state = state.copyWith(isLoading: true, error: null, user: null);

      final UserModel? userModel =
          await _authService.signInWithEmailAndPassword(email, password);

      state = state.copyWith(
        isLoading: false,
        isAuthenticated: userModel != null,
        user: userModel,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        isAuthenticated: false,
        error: e.toString(),
        user: null,
      );
    }
  }

  Future<void> signInWithGoogle() async {
    try {
      state = state.copyWith(isLoading: true, error: null, user: null);

      final UserModel? userModel = await _authService.signInWithGoogle();

      state = state.copyWith(
        isLoading: false,
        isAuthenticated: userModel != null,
        user: userModel,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        isAuthenticated: false,
        error: e.toString(),
        user: null,
      );
    }
  }

  Future<void> signUpWithEmailAndPassword({
    required String email,
    required String password,
    required String displayName,
    required UserType userType,
  }) async {
    try {
      state = state.copyWith(isLoading: true, error: null);

      final userModel = await _authService.signUpWithEmailAndPassword(
        email,
        password,
        displayName,
        userType,
      );

      if (userModel != null) {
        LoggerService.info(
            'User created with ID: ${userModel.id}, Status: ${userModel.status}');
        state = state.copyWith(
          isLoading: false,
          isAuthenticated: true,
          user: userModel,
        );
        LoggerService.info(
            'AuthNotifier state updated - isAuthenticated: true');
      }
    } catch (e) {
      LoggerService.error('AuthNotifier.signUpWithEmailAndPassword error: $e');
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<void> signOut() async {
    try {
      state = state.copyWith(isLoading: true, error: null);

      await _authService.signOut();

      // Ensure state is completely cleared
      state = const AuthState(
        isLoading: false,
        isAuthenticated: false,
        user: null,
        error: null,
      );

      // Add logging for debugging
      final logger = Logger();
      logger.i('AuthNotifier: Sign out completed, state reset');
    } catch (e) {
      final logger = Logger();
      logger.e('AuthNotifier: Sign out error: $e');
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
      rethrow; // Re-throw error for UI layer handling
    }
  }

  Future<void> resetPassword(String email) async {
    try {
      state = state.copyWith(isLoading: true, error: null);

      await _authService.resetPassword(email);

      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  void clearError() {
    state = state.clearError();
  }
}

// Helper providers for checking user roles
final isAdminProvider = Provider<bool>((ref) {
  final user = ref.watch(currentUserProvider).value;
  return user?.isAdmin ?? false;
});

final isCertificateAuthorityProvider = Provider<bool>((ref) {
  final user = ref.watch(currentUserProvider).value;
  return user?.isCA ?? false;
});

final isClientProvider = Provider<bool>((ref) {
  final user = ref.watch(currentUserProvider).value;
  return user?.isClientType ?? false;
});

final isRecipientProvider = Provider<bool>((ref) {
  final user = ref.watch(currentUserProvider).value;
  return user?.isRecipient ?? false;
});

// Permission checker provider
final permissionCheckerProvider = Provider<bool Function(String)>((ref) {
  final user = ref.watch(currentUserProvider).value;
  return (String permission) => user?.hasPermission(permission) ?? false;
});

// Logger Provider
final loggerProvider = Provider<Logger>((ref) {
  return Logger();
});
