import 'package:confms_mobile/constants/dimensions.dart';
import 'package:confms_mobile/constants/app_theme.dart';
import 'package:confms_mobile/constants/text_styles.dart';
import 'package:confms_mobile/features/main_shell/widgets/shell_shared_widgets.dart';
import 'package:confms_mobile/models/auth_user.dart';
import 'package:confms_mobile/services/mobile_feature_service.dart';
import 'package:flutter/material.dart';

class AttendTab extends StatefulWidget {
  const AttendTab({
    super.key,
    required this.featureService,
    required this.user,
  });

  final MobileFeatureService featureService;
  final AuthUser? user;

  @override
  State<AttendTab> createState() => _AttendTabState();
}

class _AttendTabState extends State<AttendTab> {
  @override
  Widget build(BuildContext context) {
    final userId = widget.user?.id;

    return ListView(
      padding: const EdgeInsets.all(AppDimensions.screenPadding),
      children: [
        Text('My Tickets', style: context.text.headlineSmall),
        const SizedBox(height: AppDimensions.space2),
        Text(
          'View your registered conference tickets and check-in status.',
          style: AppTextStyles.bodyMuted.copyWith(
            color: context.scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppDimensions.space4),
        _buildTicketsSection(userId: userId),
      ],
    );
  }

  Widget _buildTicketsSection({required int? userId}) {
    if (userId == null) return const CenteredMutedText('Missing user ID.');

    return FutureBuilder<List<TicketPreview>>(
      future: widget.featureService.getMyTickets(userId: userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return SectionError(message: snapshot.error.toString());
        }
        final tickets = snapshot.data ?? const <TicketPreview>[];
        if (tickets.isEmpty) {
          return const CenteredMutedText('No tickets found.');
        }

        return SectionCard(
          title: 'My Ticket List',
          children: tickets
              .map(
                (t) => SimpleListTile(
                  title: t.conferenceName,
                  subtitle: '${t.ticketType}\n${t.checkInStatus}',
                  trailing: const Icon(Icons.qr_code),
                ),
              )
              .toList(),
        );
      },
    );
  }
}
