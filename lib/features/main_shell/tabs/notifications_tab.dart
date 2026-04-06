import 'package:confms_mobile/constants/dimensions.dart';
import 'package:confms_mobile/constants/text_styles.dart';
import 'package:confms_mobile/constants/app_theme.dart';
import 'package:confms_mobile/features/main_shell/widgets/shell_shared_widgets.dart';
import 'package:confms_mobile/models/auth_user.dart';
import 'package:confms_mobile/services/mobile_feature_service.dart';
import 'package:confms_mobile/widgets/custom_card.dart';
import 'package:flutter/material.dart';

class NotificationsTab extends StatelessWidget {
  const NotificationsTab({
    super.key,
    required this.featureService,
    required this.user,
  });

  final MobileFeatureService featureService;
  final AuthUser? user;

  @override
  Widget build(BuildContext context) {
    final userId = user?.id;
    if (userId == null) {
      return const CenteredMutedText('Missing user context.');
    }

    return FutureBuilder<List<NotificationPreview>>(
      future: featureService.getNotifications(userId: userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return SectionError(message: snapshot.error.toString());
        }

        final items = snapshot.data ?? const <NotificationPreview>[];

        return ListView(
          padding: const EdgeInsets.all(AppDimensions.screenPadding),
          children: [
            Text('Notifications', style: context.text.headlineSmall),
            const SizedBox(height: AppDimensions.space2),
            Text(
              'Alerts with deep-link placeholders to Attend/Contribute flows.',
              style: AppTextStyles.bodyMuted.copyWith(
                color: context.scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppDimensions.space4),
            if (items.isEmpty)
              const CenteredMutedText('No notifications.')
            else
              ...items.map(
                (n) => Padding(
                  padding: const EdgeInsets.only(bottom: AppDimensions.space3),
                  child: CustomCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(n.title, style: AppTextStyles.title),
                            ),
                            if (!n.isRead)
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: context.scheme.primary,
                                  shape: BoxShape.circle,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          n.message,
                          style: AppTextStyles.body.copyWith(
                            color: context.scheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Deep link: ${n.deepLinkHint}',
                          style: AppTextStyles.caption.copyWith(
                            color: context.scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
