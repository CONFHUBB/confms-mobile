import 'package:confms_mobile/constants/app_theme.dart';
import 'package:confms_mobile/features/checkin/qr_scanner_screen.dart';
import 'package:confms_mobile/features/conference/screens/conference_detail_screen.dart';
import 'package:confms_mobile/screens/auth/login.dart';
import 'package:confms_mobile/features/main_shell/main_shell_screen.dart';
import 'package:confms_mobile/screens/auth/forgot_password.dart';
import 'package:confms_mobile/screens/auth/register.dart';
import 'package:confms_mobile/services/api_service.dart';
import 'package:confms_mobile/services/auth_service.dart';
import 'package:confms_mobile/services/auth_session.dart';
import 'package:confms_mobile/services/conference_service.dart';
import 'package:confms_mobile/services/mobile_feature_service.dart';
import 'package:confms_mobile/services/push_notification_service.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

class App extends StatefulWidget {
  const App({super.key});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  final AuthSession _authSession = AuthSession();
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  late final ApiService _apiService = ApiService(
    tokenProvider: () async => _authSession.token,
  );
  late final AuthService _authService = AuthService(_apiService);
  late final ConferenceService _conferenceService = ConferenceService(
    _apiService,
  );
  late final MobileFeatureService _featureService = MobileFeatureService(
    _apiService,
  );

  static const String _googleClientId =
      '1041085898173-t169evq3enbhn964k822n2mjs0drag4g.apps.googleusercontent.com';

  late final GoogleSignIn _googleSignIn = GoogleSignIn(
    serverClientId: _googleClientId,
    scopes: const ['email', 'profile'],
  );

  bool _sessionReady = false;

  @override
  void initState() {
    super.initState();
    _bootstrapSession();
  }

  Future<void> _bootstrapSession() async {
    await _authSession.load();
    if (!mounted) return;
    setState(() => _sessionReady = true);

    // Register FCM token with backend if logged in
    if (_authSession.isAuthenticated) {
      _registerFcmToken();
    }
  }

  Future<void> _registerFcmToken() async {
    final push = PushNotificationService.instance;
    if (!push.isInitialized || push.fcmToken == null) return;
    final userId = _authSession.user?.id;
    if (userId == null) return;
    try {
      await _apiService.post('/notifications/register-device', body: {
        'userId': userId,
        'fcmToken': push.fcmToken,
      });
    } catch (_) {
      // Backend may not have this endpoint yet — silently ignore
    }
  }

  Future<void> _login({required String email, required String password}) async {
    final result = await _authService.login(email: email, password: password);
    await _authSession.saveSession(token: result.token, user: result.user);
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _loginWithGoogle() async {
    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) {
      throw const ApiException(message: 'Google sign-in was cancelled.');
    }

    final googleAuth = await googleUser.authentication;
    final idToken = googleAuth.idToken;
    if (idToken == null || idToken.isEmpty) {
      throw const ApiException(
        message: 'Failed to obtain Google ID token.',
      );
    }

    final result = await _authService.loginWithGoogle(idToken: idToken);
    await _authSession.saveSession(token: result.token, user: result.user);
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _register({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
    required String country,
  }) async {
    await _authService.register(
      firstName: firstName,
      lastName: lastName,
      email: email,
      password: password,
      country: country,
    );
  }

  Future<String> _requestPasswordReset({required String email}) {
    return _authService.requestPasswordReset(email: email);
  }

  Future<String> _resetPassword({
    required String email,
    required String otp,
    required String newPassword,
  }) {
    return _authService.resetPassword(
      email: email,
      otp: otp,
      newPassword: newPassword,
    );
  }

  Future<void> _logout() async {
    try {
      await _googleSignIn.signOut();
    } catch (_) {}
    await _authSession.clearSession();
    if (!mounted) return;
    setState(() {});
  }

  Widget _buildLoginScreen() => LoginScreen(
        onSubmit: _login,
        onGoogleSignIn: _loginWithGoogle,
        onGoToForgotPassword: () =>
            _navigatorKey.currentState?.pushNamed('/forgot-password'),
        onGoToRegister: () =>
            _navigatorKey.currentState?.pushNamed('/register'),
      );

  @override
  Widget build(BuildContext context) {
    if (!_sessionReady) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: ThemeMode.system,
        home: Scaffold(body: const Center(child: CircularProgressIndicator())),
      );
    }

    return MaterialApp(
      navigatorKey: _navigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'ConfMS Mobile',
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      routes: {
        '/login': (_) => _buildLoginScreen(),
        '/register': (_) => RegisterScreen(
              onSubmit: _register,
              onGoToLogin: () => _navigatorKey.currentState?.pop(),
            ),
        '/forgot-password': (_) => ForgotPasswordScreen(
              onRequestOtp: _requestPasswordReset,
              onResetPassword: _resetPassword,
              onGoToLogin: () {
                if (_navigatorKey.currentState?.canPop() ?? false) {
                  _navigatorKey.currentState?.pop();
                }
              },
            ),
        '/': (_) => _authSession.isAuthenticated
            ? MainShellScreen(
                authSession: _authSession,
                featureService: _featureService,
                onLogout: _logout,
              )
            : _buildLoginScreen(),
        '/conference-detail': (_) => ConferenceDetailScreen(
              conferenceService: _conferenceService,
              featureService: _featureService,
            ),
        '/qr-scanner': (_) => QrScannerScreen(
              apiService: _apiService,
            ),
      },
      initialRoute: '/',
    );
  }
}
