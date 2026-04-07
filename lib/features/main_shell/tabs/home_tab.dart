import 'package:confms_mobile/constants/dimensions.dart';
import 'package:confms_mobile/constants/app_theme.dart';
import 'package:confms_mobile/features/main_shell/widgets/main_tab_scaffold.dart';
import 'package:confms_mobile/features/main_shell/widgets/shell_shared_widgets.dart';
import 'package:confms_mobile/models/auth_user.dart';
import 'package:confms_mobile/services/mobile_feature_service.dart';
import 'package:flutter/material.dart';

class HomeTab extends StatelessWidget {
  const HomeTab({
    super.key,
    required this.featureService,
    required this.user,
    required this.onOpenNotifications,
  });

  final MobileFeatureService featureService;
  final AuthUser? user;
  final VoidCallback onOpenNotifications;

  @override
  Widget build(BuildContext context) {
    final userId = user?.id;
    if (userId == null) {
      return MainTabScaffold(
        title: 'Home',
        subtitle: 'Conference highlights and quick updates.',
        icon: Icons.home_rounded,
        onOpenNotifications: onOpenNotifications,
        body: const CenteredMutedText('No user context available.'),
      );
    }

    return MainTabScaffold(
      title: 'Home',
      subtitle: 'Welcome, ${user?.firstName ?? 'User'}',
      icon: Icons.space_dashboard_rounded,
      onOpenNotifications: onOpenNotifications,
      body: FutureBuilder<_HomeData>(
        future: _loadHomeData(userId),
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
              await _loadHomeData(userId);
            },
            child: ListView(
              padding: const EdgeInsets.all(AppDimensions.screenPadding),
              children: [
                if (data.ticketCount > 0)
                  _buildSummaryCard(
                    context,
                    icon: Icons.confirmation_num_rounded,
                    title: 'My Tickets',
                    count: data.ticketCount,
                    status:
                        '${data.paidCount} paid, ${data.pendingCount} pending',
                    color: Colors.indigo,
                  ),
                if (data.ticketCount > 0) const SizedBox(height: 12),
                if (data.paperCount > 0)
                  _buildSummaryCard(
                    context,
                    icon: Icons.article_rounded,
                    title: 'My Papers',
                    count: data.paperCount,
                    status:
                        '${data.acceptedCount} accepted, ${data.underReviewCount} reviewing',
                    color: Colors.teal,
                  ),
                if (data.paperCount > 0)
                  const SizedBox(height: AppDimensions.space3),
                SectionCard(
                  title: 'Active Conferences',
                  children: data.activeConferences.isEmpty
                      ? const [CenteredMutedText('No active conferences.')]
                      : data.activeConferences
                            .map((conf) => _buildConferenceCard(context, conf))
                            .toList(),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<_HomeData> _loadHomeData(int userId) async {
    final tickets = await featureService.getMyTickets(userId: userId);
    final conferences = await featureService.getAuthorConferences(
      userId: userId,
    );

    final activeConfs = conferences
        .where(
          (c) =>
              c.status.toLowerCase() == 'active' ||
              c.status.toLowerCase() == 'ongoing',
        )
        .toList();

    final allPapers = <AuthorPaperSummary>[];
    for (final conf in conferences) {
      final papers = await featureService.getAuthorPapersByConference(
        userId: userId,
        conferenceId: conf.conferenceId,
      );
      allPapers.addAll(papers);
    }

    final accepted = allPapers.where((p) {
      final status = p.status.toUpperCase();
      return status == 'ACCEPTED' ||
          status == 'PUBLISHED' ||
          status == 'CAMERA_READY';
    }).length;
    final underReview = allPapers
        .where((p) => p.status.toUpperCase() == 'UNDER_REVIEW')
        .length;

    return _HomeData(
      ticketCount: tickets.length,
      paidCount: tickets
          .where((t) => (t.paymentStatus ?? '').toUpperCase() == 'COMPLETED')
          .length,
      pendingCount: tickets
          .where((t) => (t.paymentStatus ?? '').toUpperCase() == 'PENDING')
          .length,
      paperCount: allPapers.length,
      acceptedCount: accepted,
      underReviewCount: underReview,
      activeConferences: activeConfs,
    );
  }

  Widget _buildSummaryCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required int count,
    required String status,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      status,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: context.scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  count.toString(),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildConferenceCard(
    BuildContext context,
    AuthorConferenceSummary conf,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.scheme.primaryContainer.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: context.scheme.primary.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      conf.conferenceName,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.location_on_rounded,
                          size: 14,
                          color: context.scheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            conf.location,
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  color: context.scheme.onSurfaceVariant,
                                ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: Colors.green.withValues(alpha: 0.25),
                  ),
                ),
                child: Text(
                  conf.status,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Colors.green,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildConfMiniStat(
                context,
                label: 'Papers',
                value: conf.myPaperCount.toString(),
                color: Colors.indigo,
              ),
              _buildConfMiniStat(
                context,
                label: 'Accepted',
                value: conf.acceptedCount.toString(),
                color: Colors.green,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildConfMiniStat(
    BuildContext context, {
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: color,
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: context.scheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _HomeData {
  const _HomeData({
    required this.ticketCount,
    required this.paidCount,
    required this.pendingCount,
    required this.paperCount,
    required this.acceptedCount,
    required this.underReviewCount,
    required this.activeConferences,
  });

  final int ticketCount;
  final int paidCount;
  final int pendingCount;
  final int paperCount;
  final int acceptedCount;
  final int underReviewCount;
  final List<AuthorConferenceSummary> activeConferences;
}
