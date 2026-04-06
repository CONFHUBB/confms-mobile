import 'package:confms_mobile/constants/app_theme.dart';
import 'package:confms_mobile/constants/dimensions.dart';
import 'package:confms_mobile/constants/text_styles.dart';
import 'package:flutter/material.dart';

enum CustomButtonVariant { primary, outline, destructive }

class CustomButton extends StatelessWidget {
  const CustomButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = CustomButtonVariant.primary,
    this.isLoading = false,
    this.icon,
    this.expanded = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final CustomButtonVariant variant;
  final bool isLoading;
  final Widget? icon;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final tokens = context.tokens;
    final spinnerColor = switch (variant) {
      CustomButtonVariant.primary ||
      CustomButtonVariant.destructive => Colors.white,
      CustomButtonVariant.outline => scheme.onSurface,
    };

    final child = FilledButton(
      onPressed: isLoading ? null : onPressed,
      style: _styleByVariant(variant, scheme, tokens),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (isLoading) ...[
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: spinnerColor,
              ),
            ),
            const SizedBox(width: AppDimensions.space2),
          ] else if (icon != null) ...[
            icon!,
            const SizedBox(width: AppDimensions.space2),
          ],
          Text(
            label,
            style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );

    if (expanded) {
      return SizedBox(width: double.infinity, child: child);
    }

    return child;
  }

  ButtonStyle _styleByVariant(
    CustomButtonVariant variant,
    ColorScheme scheme,
    AppColorTokens tokens,
  ) {
    switch (variant) {
      case CustomButtonVariant.primary:
        return FilledButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(0, AppDimensions.inputHeight),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          ),
        );
      case CustomButtonVariant.outline:
        return FilledButton.styleFrom(
          backgroundColor: scheme.surface,
          foregroundColor: scheme.onSurface,
          side: BorderSide(color: tokens.cardBorder),
          minimumSize: const Size(0, AppDimensions.inputHeight),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          ),
        );
      case CustomButtonVariant.destructive:
        return FilledButton.styleFrom(
          backgroundColor: tokens.destructive,
          foregroundColor: Colors.white,
          minimumSize: const Size(0, AppDimensions.inputHeight),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          ),
        );
    }
  }
}
