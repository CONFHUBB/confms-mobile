import 'package:confms_mobile/constants/app_theme.dart';
import 'package:confms_mobile/constants/dimensions.dart';
import 'package:confms_mobile/constants/text_styles.dart';
import 'package:confms_mobile/screens/auth/auth_page_scaffold.dart';
import 'package:confms_mobile/services/api_service.dart';
import 'package:confms_mobile/widgets/custom_button.dart';
import 'package:flutter/material.dart';

enum ForgotPasswordStep { email, reset }

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({
    super.key,
    required this.onRequestOtp,
    required this.onResetPassword,
    required this.onGoToLogin,
  });

  final Future<String> Function({required String email}) onRequestOtp;
  final Future<String> Function({
    required String email,
    required String otp,
    required String newPassword,
  })
  onResetPassword;
  final VoidCallback onGoToLogin;

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  final _otpController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  final _emailFormKey = GlobalKey<FormState>();
  final _resetFormKey = GlobalKey<FormState>();

  ForgotPasswordStep _step = ForgotPasswordStep.email;
  bool _isLoading = false;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _otpController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _requestOtp() async {
    if (!(_emailFormKey.currentState?.validate() ?? false)) return;

    setState(() {
      _error = null;
      _isLoading = true;
    });

    try {
      final message = await widget.onRequestOtp(
        email: _emailController.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message.isEmpty ? 'Verification code sent.' : message),
        ),
      );
      setState(() => _step = ForgotPasswordStep.reset);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Failed to send verification code.');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _resetPassword() async {
    if (!(_resetFormKey.currentState?.validate() ?? false)) return;

    setState(() {
      _error = null;
      _isLoading = true;
    });

    try {
      final message = await widget.onResetPassword(
        email: _emailController.text.trim(),
        otp: _otpController.text.trim(),
        newPassword: _newPasswordController.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            message.isEmpty ? 'Password reset successfully.' : message,
          ),
        ),
      );
      widget.onGoToLogin();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Failed to reset password.');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _resendOtp() async {
    setState(() {
      _error = null;
      _isLoading = true;
    });

    try {
      final message = await widget.onRequestOtp(
        email: _emailController.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message.isEmpty ? 'New code sent.' : message)),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Failed to resend verification code.');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _changeEmail() {
    setState(() {
      _step = ForgotPasswordStep.email;
      _otpController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();
      _error = null;
    });
  }

  Widget _buildCard(ColorScheme scheme, AppColorTokens tokens) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.space6),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          child: _step == ForgotPasswordStep.email
              ? Form(
                  key: _emailFormKey,
                  child: Column(
                    key: const ValueKey('forgot-email-step'),
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: scheme.primaryContainer,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(Icons.mail_outline, color: scheme.primary),
                      ),
                      const SizedBox(height: AppDimensions.space4),
                      Text(
                        'Forgot password?',
                        style: context.text.headlineSmall,
                      ),
                      const SizedBox(height: AppDimensions.space2),
                      Text(
                        'Enter your email and we will send a verification code to reset your password.',
                        style: AppTextStyles.bodyMuted.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: AppDimensions.space5),
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _requestOtp(),
                        decoration: const InputDecoration(
                          labelText: 'Email address',
                          hintText: 'you@example.com',
                          prefixIcon: Icon(Icons.alternate_email),
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
                      if (_error != null) ...[
                        const SizedBox(height: AppDimensions.space3),
                        Text(
                          _error!,
                          style: AppTextStyles.caption.copyWith(
                            color: tokens.destructive,
                          ),
                        ),
                      ],
                      const SizedBox(height: AppDimensions.space5),
                      CustomButton(
                        label: 'Send verification code',
                        expanded: true,
                        isLoading: _isLoading,
                        onPressed: _requestOtp,
                      ),
                      const SizedBox(height: AppDimensions.space4),
                      Center(
                        child: TextButton(
                          onPressed: widget.onGoToLogin,
                          child: const Text('Back to login'),
                        ),
                      ),
                    ],
                  ),
                )
              : Form(
                  key: _resetFormKey,
                  child: Column(
                    key: const ValueKey('forgot-reset-step'),
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: scheme.primaryContainer,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(
                          Icons.verified_outlined,
                          color: scheme.primary,
                        ),
                      ),
                      const SizedBox(height: AppDimensions.space4),
                      Text('Reset password', style: context.text.headlineSmall),
                      const SizedBox(height: AppDimensions.space2),
                      Text.rich(
                        TextSpan(
                          text: 'We sent a verification code to ',
                          style: AppTextStyles.bodyMuted.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                          children: [
                            TextSpan(
                              text: _emailController.text.trim(),
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const TextSpan(
                              text: '. Enter it below with your new password.',
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppDimensions.space5),
                      TextFormField(
                        controller: _otpController,
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.next,
                        maxLength: 6,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          letterSpacing: 6,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Verification code',
                          hintText: '123456',
                        ),
                        onChanged: (value) {
                          final digitsOnly = value.replaceAll(
                            RegExp(r'\D'),
                            '',
                          );
                          if (digitsOnly != value) {
                            _otpController.value = TextEditingValue(
                              text: digitsOnly,
                              selection: TextSelection.collapsed(
                                offset: digitsOnly.length,
                              ),
                            );
                          }
                        },
                        validator: (value) {
                          final otp = (value ?? '').trim();
                          if (otp.isEmpty)
                            return 'Verification code is required';
                          if (otp.length < 4) return 'Enter a valid code';
                          return null;
                        },
                      ),
                      const SizedBox(height: AppDimensions.space4),
                      TextFormField(
                        controller: _newPasswordController,
                        obscureText: _obscureNewPassword,
                        textInputAction: TextInputAction.next,
                        decoration: InputDecoration(
                          labelText: 'New password',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            onPressed: () {
                              setState(() {
                                _obscureNewPassword = !_obscureNewPassword;
                              });
                            },
                            icon: Icon(
                              _obscureNewPassword
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                            ),
                          ),
                        ),
                        validator: (value) {
                          final password = value ?? '';
                          if (password.isEmpty)
                            return 'New password is required';
                          if (password.length < 6) {
                            return 'Password must be at least 6 characters';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: AppDimensions.space4),
                      TextFormField(
                        controller: _confirmPasswordController,
                        obscureText: _obscureConfirmPassword,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _resetPassword(),
                        decoration: InputDecoration(
                          labelText: 'Confirm new password',
                          prefixIcon: const Icon(Icons.lock_reset_outlined),
                          suffixIcon: IconButton(
                            onPressed: () {
                              setState(() {
                                _obscureConfirmPassword =
                                    !_obscureConfirmPassword;
                              });
                            },
                            icon: Icon(
                              _obscureConfirmPassword
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                            ),
                          ),
                        ),
                        validator: (value) {
                          final confirm = value ?? '';
                          if (confirm.isEmpty)
                            return 'Please confirm your password';
                          if (confirm != _newPasswordController.text) {
                            return 'Passwords do not match';
                          }
                          return null;
                        },
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: AppDimensions.space3),
                        Text(
                          _error!,
                          style: AppTextStyles.caption.copyWith(
                            color: tokens.destructive,
                          ),
                        ),
                      ],
                      const SizedBox(height: AppDimensions.space5),
                      CustomButton(
                        label: 'Reset password',
                        expanded: true,
                        isLoading: _isLoading,
                        onPressed: _resetPassword,
                      ),
                      const SizedBox(height: AppDimensions.space4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          TextButton(
                            onPressed: _changeEmail,
                            child: const Text('Change email'),
                          ),
                          TextButton(
                            onPressed: _isLoading ? null : _resendOtp,
                            child: const Text('Resend code'),
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

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final tokens = context.tokens;

    return AuthPageScaffold(
      title: 'Forgot password',
      child: _buildCard(scheme, tokens),
    );
  }
}
