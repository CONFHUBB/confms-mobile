import 'package:confms_mobile/constants/app_theme.dart';
import 'package:confms_mobile/constants/dimensions.dart';
import 'package:confms_mobile/constants/text_styles.dart';
import 'package:confms_mobile/screens/auth/auth_page_scaffold.dart';
import 'package:confms_mobile/services/api_service.dart';
import 'package:confms_mobile/widgets/custom_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
    required this.onSubmit,
    required this.onGoToForgotPassword,
    required this.onGoToRegister,
    this.onGoogleSignIn,
  });

  final Future<void> Function({required String email, required String password})
  onSubmit;
  final VoidCallback onGoToForgotPassword;
  final VoidCallback onGoToRegister;
  final Future<void> Function()? onGoogleSignIn;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _isGoogleLoading = false;
  bool _obscurePassword = true;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _error = null;
      _isLoading = true;
    });

    try {
      await widget.onSubmit(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, '/', (_) => false);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Unable to sign in. Please try again.');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleGoogleSignIn() async {
    if (widget.onGoogleSignIn == null) return;

    setState(() {
      _error = null;
      _isGoogleLoading = true;
    });

    try {
      await widget.onGoogleSignIn!();
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, '/', (_) => false);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Google sign-in failed. Please try again.');
    } finally {
      if (mounted) {
        setState(() => _isGoogleLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final tokens = context.tokens;

    return AuthPageScaffold(
      title: 'Log in',
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.space6),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Text('Welcome back', style: context.text.headlineSmall),
                ),
                const SizedBox(height: AppDimensions.space2),
                Center(
                  child: Text(
                    'Sign in to access tickets, papers, and profile settings.',
                    style: AppTextStyles.bodyMuted.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: AppDimensions.space5),

                // --- Email/Password fields ---
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    hintText: 'm@example.com',
                    prefixIcon: Icon(Icons.mail_outline),
                  ),
                  validator: (value) {
                    final email = (value ?? '').trim();
                    if (email.isEmpty) return 'Email is required';
                    final valid = RegExp(
                      r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                    ).hasMatch(email);
                    if (!valid) return 'Invalid email format';
                    return null;
                  },
                ),
                const SizedBox(height: AppDimensions.space4),
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _submit(),
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility
                            : Icons.visibility_off,
                      ),
                    ),
                  ),
                  validator: (value) {
                    final password = value ?? '';
                    if (password.isEmpty) return 'Password is required';
                    if (password.length < 6) {
                      return 'Password must be at least 6 characters';
                    }
                    return null;
                  },
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: widget.onGoToForgotPassword,
                    child: const Text('Forgot your password?'),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: AppDimensions.space2),
                  Text(
                    _error!,
                    style: AppTextStyles.caption.copyWith(
                      color: tokens.destructive,
                    ),
                  ),
                ],
                const SizedBox(height: AppDimensions.space4),
                CustomButton(
                  label: 'Log in',
                  expanded: true,
                  isLoading: _isLoading,
                  onPressed: _submit,
                ),

                // --- Divider ---
                Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: AppDimensions.space4,
                  ),
                  child: Row(
                    children: [
                      Expanded(child: Divider(color: tokens.cardBorder)),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppDimensions.space3,
                        ),
                        child: Text(
                          'or',
                          style: AppTextStyles.caption.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      Expanded(child: Divider(color: tokens.cardBorder)),
                    ],
                  ),
                ),

                // --- Google Sign-In Button ---
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: (_isGoogleLoading || _isLoading)
                        ? null
                        : _handleGoogleSignIn,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, AppDimensions.inputHeight),
                      side: BorderSide(color: tokens.cardBorder),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          AppDimensions.radiusMd,
                        ),
                      ),
                    ),
                    child: _isGoogleLoading
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: scheme.onSurface,
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SvgPicture.asset(
                                'assets/images/google_logo.svg',
                                width: 20,
                                height: 20,
                              ),
                              const SizedBox(width: AppDimensions.space2),
                              Text(
                                'Continue with Google',
                                style: AppTextStyles.body.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: scheme.onSurface,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),

                const SizedBox(height: AppDimensions.space4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Don\'t have an account? ',
                      style: AppTextStyles.bodyMuted,
                    ),
                    TextButton(
                      onPressed: widget.onGoToRegister,
                      child: const Text('Create account'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
