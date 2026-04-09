import 'package:confms_mobile/constants/colors.dart';
import 'package:confms_mobile/constants/dimensions.dart';
import 'package:confms_mobile/models/auth_user.dart';
import 'package:flutter/material.dart';

class MainTabScaffold extends StatelessWidget {
  const MainTabScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.body,
    this.user,
    this.onMenuTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Widget body;
  final AuthUser? user;
  final VoidCallback? onMenuTap;

  String _initials(AuthUser? user) {
    final first = (user?.firstName ?? '').trim();
    final last = (user?.lastName ?? '').trim();
    final a = first.isNotEmpty ? first[0] : '';
    final b = last.isNotEmpty ? last[0] : '';
    final initials = '$a$b'.trim();
    return initials.isEmpty ? 'U' : initials.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: AppDimensions.space3,
          ),
          decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
          child: Row(
            children: [
              // Hamburger menu
              if (onMenuTap != null)
                GestureDetector(
                  onTap: onMenuTap,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.menu_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ),
              if (onMenuTap != null) const SizedBox(width: 8),
              // Logo
              Image.asset(
                'assets/images/Logo Main.png',
                height: 24,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Text(
                  'ConfHub',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
              ),
              const Spacer(),
              // Page title pill
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, color: Colors.white, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // User avatar
              CircleAvatar(
                radius: 14,
                backgroundColor: Colors.white.withValues(alpha: 0.2),
                child: Text(
                  _initials(user),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(child: body),
      ],
    );
  }
}
