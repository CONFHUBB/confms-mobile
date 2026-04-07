import 'package:confms_mobile/models/auth_user.dart';
import 'package:confms_mobile/services/api_service.dart';

class AuthService {
  AuthService(this._apiService);

  final ApiService _apiService;

  Future<String> requestPasswordReset({required String email}) async {
    final data = await _apiService.post(
      '/auth/forgot-password',
      body: {'email': email},
    );

    return _extractMessage(
      data,
      fallback: 'Verification code sent to your email.',
    );
  }

  Future<String> resetPassword({
    required String email,
    required String otp,
    required String newPassword,
  }) async {
    final data = await _apiService.post(
      '/auth/reset-password',
      body: {'email': email, 'otp': otp, 'newPassword': newPassword},
    );

    return _extractMessage(data, fallback: 'Password reset successfully.');
  }

  Future<void> register({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
    required String country,
  }) async {
    await _apiService.post(
      '/auth/signup',
      body: {
        'firstName': firstName,
        'lastName': lastName,
        'email': email,
        'password': password,
        'country': country,
        'roles': <String>[],
      },
    );
  }

  Future<LoginResult> login({
    required String email,
    required String password,
  }) async {
    final data = await _apiService.post(
      '/auth/signin',
      body: {'email': email, 'password': password},
    );

    final token = _extractToken(data);
    if (token.trim().isEmpty) {
      throw const ApiException(
        message: 'Login response did not include a token.',
      );
    }

    return LoginResult(token: token, user: AuthUser.fromJson(data));
  }

  Future<LoginResult> loginWithGoogle({required String idToken}) async {
    final data = await _apiService.post(
      '/auth/google',
      body: {'idToken': idToken},
    );

    final token = _extractToken(data);
    if (token.trim().isEmpty) {
      throw const ApiException(
        message: 'Google login response did not include a token.',
      );
    }

    return LoginResult(token: token, user: AuthUser.fromJson(data));
  }

  String _extractToken(Map<String, dynamic> data) {
    final fromCommonKeys =
        data['token'] ?? data['accessToken'] ?? data['jwt'] ?? '';

    final raw = fromCommonKeys.toString().trim();
    if (raw.isEmpty) return '';

    if (raw.toLowerCase().startsWith('bearer ')) {
      return raw.substring(7).trim();
    }

    return raw;
  }

  String _extractMessage(
    Map<String, dynamic> data, {
    required String fallback,
  }) {
    final message = data['message'] ?? data['detail'] ?? data['error'];
    if (message is String && message.trim().isNotEmpty) {
      return message.trim();
    }

    return fallback;
  }
}

class LoginResult {
  const LoginResult({required this.token, required this.user});

  final String token;
  final AuthUser user;
}
