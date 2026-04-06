import 'package:confms_mobile/constants/dimensions.dart';
import 'package:confms_mobile/constants/app_theme.dart';
import 'package:confms_mobile/constants/text_styles.dart';
import 'package:confms_mobile/features/main_shell/widgets/shell_shared_widgets.dart';
import 'package:confms_mobile/models/auth_user.dart';
import 'package:confms_mobile/services/mobile_feature_service.dart';
import 'package:flutter/material.dart';

class HomeTab extends StatelessWidget {
  const HomeTab({
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
      return const CenteredMutedText('No user context available.');
    }

    return FutureBuilder<HomeDashboardData>(
      future: featureService.getHomeDashboard(userId: userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return SectionError(message: snapshot.error.toString());
        }

        final data = snapshot.data;
        if (data == null) {
          return const CenteredMutedText('No home data available.');
        }

        return RefreshIndicator(
          onRefresh: () async {
            await featureService.getHomeDashboard(userId: userId);
          },
          child: ListView(
            padding: const EdgeInsets.all(AppDimensions.screenPadding),
            children: [
              Text('Home', style: context.text.headlineSmall),
              const SizedBox(height: AppDimensions.space2),
              Text(
                'Welcome, ${user?.firstName ?? 'User'}',
                style: AppTextStyles.bodyMuted.copyWith(
                  color: context.scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppDimensions.space4),
              SectionCard(
                title: 'Upcoming Sessions',
                children: data.upcomingSessions
                    .map(
                      (s) => SimpleListTile(
                        title: s.title,
                        subtitle: '${s.subtitle}\n${s.conferenceName}',
                        trailing: Icon(
                          s.isBookmarked
                              ? Icons.bookmark
                              : Icons.bookmark_outline,
                        ),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: AppDimensions.space3),
              SectionCard(
                title: 'My Tickets (Preview)',
                children: data.myTickets
                    .map(
                      (t) => SimpleListTile(
                        title: t.conferenceName,
                        subtitle: '${t.ticketType}\n${t.checkInStatus}',
                        trailing: const Icon(Icons.qr_code_2),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: AppDimensions.space3),
              SectionCard(
                title: 'Pending Reviews',
                children: data.pendingReviews
                    .map(
                      (r) => SimpleListTile(
                        title: r.title,
                        subtitle: r.subtitle,
                        trailing: const Icon(Icons.rate_review_outlined),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: AppDimensions.space3),
              SectionCard(
                title: 'Submission Updates',
                children: data.submissionUpdates
                    .map(
                      (u) => SimpleListTile(
                        title: u.title,
                        subtitle: u.subtitle,
                        trailing: const Icon(Icons.upload_file_outlined),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: AppDimensions.space3),
              SectionCard(
                title: 'Announcements / Notifications',
                children: data.announcements
                    .map(
                      (a) => SimpleListTile(
                        title: a.title,
                        subtitle: a.subtitle,
                        trailing: const Icon(Icons.campaign_outlined),
                      ),
                    )
                    .toList(),
              ),
            ],
          ),
        );
      },
    );
  }
}
