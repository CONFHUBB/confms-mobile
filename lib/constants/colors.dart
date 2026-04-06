import 'package:flutter/material.dart';

class AppColors {
  const AppColors._();

  static const Color primary = Color(0xFF4338CA); // indigo-700
  static const Color primaryBase = Color(0xFF4F46E5); // indigo-600
  static const Color primaryStart = Color(0xFF1E1B4B);
  static const Color primaryMid = Color(0xFF272463);
  static const Color primaryEnd = Color(0xFF312E81);
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [primaryStart, primaryMid, primaryEnd],
    stops: [0.0, 0.5, 1.0],
  );
  static const Color secondary = Color(0xFFEEF2FF); // indigo-50
  static const Color accent = secondary;

  static const Color background = Color(0xFFFFFFFF);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color card = Color(0xFFFFFFFF);

  static const Color textPrimary = Color(0xFF171717);
  static const Color textSecondary = Color(0xFF737373);

  static const Color border = Color(0xFFE5E5E5);
  static const Color muted = Color(0xFFF5F5F5);

  static const Color success = Color(0xFF16A34A);
  static const Color warning = Color(0xFFD97706);
  static const Color destructive = Color(0xFFDC2626);
}
