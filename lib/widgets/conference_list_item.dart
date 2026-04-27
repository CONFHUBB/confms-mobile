import 'package:confms_mobile/constants/colors.dart';
import 'package:confms_mobile/constants/dimensions.dart';
import 'package:confms_mobile/constants/text_styles.dart';
import 'package:confms_mobile/models/conference.dart';
import 'package:confms_mobile/utils/date_time_display.dart';
import 'package:confms_mobile/widgets/custom_card.dart';
import 'package:flutter/material.dart';

class ConferenceListItem extends StatelessWidget {
  const ConferenceListItem({super.key, required this.conference, this.onTap});

  final Conference conference;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return CustomCard(
      onTap: onTap,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Banner(conference: conference),
          Padding(
            padding: const EdgeInsets.all(AppDimensions.cardPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        conference.name,
                        style: AppTextStyles.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: AppDimensions.space2),
                    _StatusChip(status: conference.status),
                  ],
                ),
                const SizedBox(height: AppDimensions.space2),
                Text(conference.acronym, style: AppTextStyles.caption),
                const SizedBox(height: AppDimensions.space2),
                Text(
                  conference.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodyMuted,
                ),
                const SizedBox(height: AppDimensions.space3),
                Row(
                  children: [
                    const Icon(
                      Icons.calendar_today_outlined,
                      size: 16,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: AppDimensions.space2),
                    Expanded(
                      child: Text(
                        '${formatDateTimeFromDate(conference.startDate)} - ${formatDateTimeFromDate(conference.endDate)}',
                        style: AppTextStyles.caption,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppDimensions.space2),
                Row(
                  children: [
                    const Icon(
                      Icons.location_on_outlined,
                      size: 16,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: AppDimensions.space2),
                    Expanded(
                      child: Text(
                        conference.location,
                        style: AppTextStyles.caption,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.conference});

  final Conference conference;

  @override
  Widget build(BuildContext context) {
    final bannerUrl = conference.bannerImageUrl;
    return ClipRRect(
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(AppDimensions.radiusMd),
        topRight: Radius.circular(AppDimensions.radiusMd),
      ),
      child: SizedBox(
        height: 140,
        width: double.infinity,
        child: bannerUrl != null && bannerUrl.isNotEmpty
            ? Image.network(
                bannerUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) =>
                    _FallbackBanner(acronym: conference.acronym),
              )
            : _FallbackBanner(acronym: conference.acronym),
      ),
    );
  }
}

class _FallbackBanner extends StatelessWidget {
  const _FallbackBanner({required this.acronym});

  final String acronym;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.primary,
      alignment: Alignment.center,
      child: Text(
        acronym.isEmpty ? 'CONF' : acronym,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 28,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final upper = status.toUpperCase();
    final (bg, fg) = switch (upper) {
      'SCHEDULED' || 'ONGOING' => (const Color(0xFFDCFCE7), AppColors.success),
      'PENDING' => (const Color(0xFFFEF3C7), AppColors.warning),
      'COMPLETED' => (const Color(0xFFE0E7FF), const Color(0xFF4338CA)),
      'CANCELLED' => (const Color(0xFFFEE2E2), AppColors.destructive),
      _ => (const Color(0xFFF3F4F6), AppColors.textSecondary),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(upper, style: AppTextStyles.caption.copyWith(color: fg)),
    );
  }
}
