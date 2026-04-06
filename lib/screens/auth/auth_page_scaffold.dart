import 'package:confms_mobile/constants/app_theme.dart';
import 'package:confms_mobile/constants/colors.dart';
import 'package:confms_mobile/constants/dimensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class AuthPageScaffold extends StatelessWidget {
  const AuthPageScaffold({super.key, required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(
                AppDimensions.screenPadding,
                AppDimensions.space4 * 4,
                AppDimensions.screenPadding,
                AppDimensions.space6,
              ),
              decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: context.text.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 30,
                        height: 1.1,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppDimensions.space4),
                  const _BrandMarks(),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppDimensions.screenPadding),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 560),
                    child: child,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BrandMarks extends StatelessWidget {
  const _BrandMarks();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topRight,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            child: _SafeSvgAsset(
              assetCandidates: const [
                'assets/images/favicon_white.svg',
                'assets/images/Favicon-White.svg',
              ],
              width: 28,
              height: 28,
              fallback: const Icon(
                Icons.auto_awesome,
                size: 22,
                color: Colors.white,
              ),
            ),
          ),
          SizedBox(
            width: 110,
            child: _SafeSvgAsset(
              assetCandidates: const [
                'assets/images/white_logo.svg',
                'assets/images/White.svg',
              ],
              height: 24,
              fit: BoxFit.contain,
              alignment: Alignment.centerRight,
              fallback: const Text(
                'CONFMS',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  letterSpacing: 0.8,
                ),
                textAlign: TextAlign.right,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SafeSvgAsset extends StatelessWidget {
  const _SafeSvgAsset({
    required this.assetCandidates,
    required this.fallback,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
    this.alignment = Alignment.center,
  });

  final List<String> assetCandidates;
  final Widget fallback;
  final double? width;
  final double? height;
  final BoxFit fit;
  final AlignmentGeometry alignment;

  Future<String?> _loadFirstAvailableSvg(BuildContext context) async {
    final bundle = DefaultAssetBundle.of(context);
    for (final assetPath in assetCandidates) {
      try {
        final raw = await bundle.loadString(assetPath);
        if (raw.trim().isNotEmpty) {
          return raw;
        }
      } catch (_) {
        // Try next candidate.
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: _loadFirstAvailableSvg(context),
      builder: (context, snapshot) {
        final svgRaw = snapshot.data;
        if (svgRaw == null || svgRaw.isEmpty) {
          return SizedBox(
            width: width,
            height: height,
            child: FittedBox(
              fit: fit,
              alignment: alignment,
              child: fallback,
            ),
          );
        }

        return SvgPicture.string(
          svgRaw,
          width: width,
          height: height,
          fit: fit,
          alignment: alignment,
        );
      },
    );
  }
}
