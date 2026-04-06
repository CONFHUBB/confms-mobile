import 'package:confms_mobile/constants/colors.dart';
import 'package:confms_mobile/constants/text_styles.dart';
import 'package:flutter/material.dart';

@immutable
class AppColorTokens extends ThemeExtension<AppColorTokens> {
  const AppColorTokens({
    required this.cardBorder,
    required this.mutedSurface,
    required this.success,
    required this.warning,
    required this.destructive,
  });

  final Color cardBorder;
  final Color mutedSurface;
  final Color success;
  final Color warning;
  final Color destructive;

  @override
  AppColorTokens copyWith({
    Color? cardBorder,
    Color? mutedSurface,
    Color? success,
    Color? warning,
    Color? destructive,
  }) {
    return AppColorTokens(
      cardBorder: cardBorder ?? this.cardBorder,
      mutedSurface: mutedSurface ?? this.mutedSurface,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      destructive: destructive ?? this.destructive,
    );
  }

  @override
  AppColorTokens lerp(ThemeExtension<AppColorTokens>? other, double t) {
    if (other is! AppColorTokens) {
      return this;
    }

    return AppColorTokens(
      cardBorder: Color.lerp(cardBorder, other.cardBorder, t) ?? cardBorder,
      mutedSurface: Color.lerp(mutedSurface, other.mutedSurface, t) ?? mutedSurface,
      success: Color.lerp(success, other.success, t) ?? success,
      warning: Color.lerp(warning, other.warning, t) ?? warning,
      destructive: Color.lerp(destructive, other.destructive, t) ?? destructive,
    );
  }
}

class AppTheme {
  const AppTheme._();

  static ThemeData light() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.light,
    );

    return _buildTheme(colorScheme, const AppColorTokens(
      cardBorder: AppColors.border,
      mutedSurface: AppColors.muted,
      success: AppColors.success,
      warning: AppColors.warning,
      destructive: AppColors.destructive,
    ));
  }

  static ThemeData dark() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.dark,
    );

    return _buildTheme(colorScheme, AppColorTokens(
      cardBorder: colorScheme.outlineVariant,
      mutedSurface: colorScheme.surfaceContainerHighest,
      success: const Color(0xFF4ADE80),
      warning: const Color(0xFFFBBF24),
      destructive: const Color(0xFFF87171),
    ));
  }

  static ThemeData _buildTheme(ColorScheme colorScheme, AppColorTokens tokens) {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colorScheme.surface,
    );

    return base.copyWith(
      extensions: [tokens],
      textTheme: base.textTheme.copyWith(
        headlineSmall: AppTextStyles.h2.copyWith(
          color: colorScheme.onSurface,
        ),
        titleMedium: AppTextStyles.title.copyWith(
          color: colorScheme.onSurface,
        ),
        bodyMedium: AppTextStyles.body.copyWith(
          color: colorScheme.onSurface,
        ),
        bodySmall: AppTextStyles.caption.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.all(Radius.circular(12)),
          side: BorderSide(color: tokens.cardBorder),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: tokens.cardBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: tokens.cardBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.primary, width: 1.2),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        indicatorColor: colorScheme.primaryContainer,
        backgroundColor: colorScheme.surface,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? colorScheme.primary : colorScheme.onSurfaceVariant,
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            color: selected ? colorScheme.primary : colorScheme.onSurfaceVariant,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            fontSize: 12,
          );
        }),
      ),
    );
  }
}

extension AppThemeX on BuildContext {
  ColorScheme get scheme => Theme.of(this).colorScheme;

  TextTheme get text => Theme.of(this).textTheme;

  AppColorTokens get tokens => Theme.of(this).extension<AppColorTokens>()!;
}