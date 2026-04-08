import 'package:confms_mobile/constants/app_theme.dart';
import 'package:confms_mobile/constants/dimensions.dart';
import 'package:confms_mobile/features/main_shell/widgets/main_tab_scaffold.dart';
import 'package:confms_mobile/features/main_shell/widgets/shell_shared_widgets.dart';
import 'package:confms_mobile/models/auth_user.dart';
import 'package:confms_mobile/services/mobile_feature_service.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

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

    return MainTabScaffold(
      title: 'My Tickets',
      subtitle: 'Conferences first, then ticket details and documents.',
      icon: Icons.confirmation_num_rounded,
      user: widget.user,
      body: _buildTicketsSection(userId: userId),
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

        final byConference = <int, TicketPreview>{};
        final looseTickets = <TicketPreview>[];
        for (final ticket in tickets) {
          final conferenceId = ticket.conferenceId;
          if (conferenceId == null) {
            looseTickets.add(ticket);
            continue;
          }
          byConference.putIfAbsent(conferenceId, () => ticket);
        }

        final conferenceTickets = byConference.values.toList()
          ..sort(
            (a, b) => a.conferenceName.toLowerCase().compareTo(
              b.conferenceName.toLowerCase(),
            ),
          );

        return ListView(
          padding: const EdgeInsets.all(AppDimensions.screenPadding),
          children: [
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    label: 'Conferences',
                    value: conferenceTickets.length.toString(),
                    icon: Icons.event_rounded,
                    color: Colors.indigo,
                  ),
                ),
                const SizedBox(width: AppDimensions.space2),
                Expanded(
                  child: _StatCard(
                    label: 'Paid',
                    value: tickets
                        .where(
                          (t) => t.paymentStatus?.toUpperCase() == 'COMPLETED',
                        )
                        .length
                        .toString(),
                    icon: Icons.verified_rounded,
                    color: Colors.green,
                  ),
                ),
                const SizedBox(width: AppDimensions.space2),
                Expanded(
                  child: _StatCard(
                    label: 'Pending',
                    value: tickets
                        .where(
                          (t) => t.paymentStatus?.toUpperCase() == 'PENDING',
                        )
                        .length
                        .toString(),
                    icon: Icons.hourglass_top_rounded,
                    color: Colors.orange,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.space3),
            if (conferenceTickets.isEmpty && looseTickets.isNotEmpty)
              const CenteredMutedText(
                'Some tickets do not have a conference association.',
              )
            else
              ...conferenceTickets.map(
                (ticket) => Padding(
                  padding: const EdgeInsets.only(bottom: AppDimensions.space3),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                    onTap: () => _openTicketDetails(userId, ticket),
                    child: SectionCard(
                      title: ticket.conferenceName,
                      children: [
                        Row(
                          children: [
                            _Badge(
                              label: ticket.paymentStatus ?? 'UNKNOWN',
                              icon: Icons.payments_rounded,
                              color: _statusColor(ticket.paymentStatus),
                            ),
                            const SizedBox(width: AppDimensions.space2),
                            _Badge(
                              label: ticket.ticketType,
                              icon: Icons.confirmation_num_rounded,
                              color: Colors.indigo,
                            ),
                          ],
                        ),
                        const SizedBox(height: AppDimensions.space2),
                        SimpleListTile(
                          title: ticket.registrationNumber?.isNotEmpty == true
                              ? ticket.registrationNumber!
                              : 'Registration #${ticket.ticketId}',
                          subtitle: [
                            'Ticket type: ${ticket.ticketType}',
                            'Check-in: ${ticket.checkInStatus}',
                          ].join('\n'),
                          trailing: const Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            if (looseTickets.isNotEmpty) ...[
              const SizedBox(height: AppDimensions.space3),
              SectionCard(
                title: 'Other Tickets',
                children: looseTickets
                    .map(
                      (ticket) => SimpleListTile(
                        title: ticket.ticketType,
                        subtitle: ticket.conferenceName,
                        trailing: IconButton(
                          onPressed: () => _openTicketDetails(userId, ticket),
                          icon: const Icon(Icons.visibility_rounded),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ],
          ],
        );
      },
    );
  }

  Future<void> _openTicketDetails(int userId, TicketPreview ticket) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _TicketDetailScreen(
          userId: userId,
          ticket: ticket,
          featureService: widget.featureService,
        ),
      ),
    );
  }

  Color _statusColor(String? status) {
    switch ((status ?? '').toLowerCase()) {
      case 'completed':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'failed':
        return Colors.red;
      case 'refunded':
        return Colors.grey;
      default:
        return Colors.blueGrey;
    }
  }
}

class _TicketDetailScreen extends StatelessWidget {
  const _TicketDetailScreen({
    required this.userId,
    required this.ticket,
    required this.featureService,
  });

  final int userId;
  final TicketPreview ticket;
  final MobileFeatureService featureService;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(ticket.conferenceName)),
      body: FutureBuilder<_TicketDetailData>(
        future: _loadTicketData(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return SectionError(message: snapshot.error.toString());
          }

          final data = snapshot.data;
          if (data == null) {
            return const CenteredMutedText('Ticket details unavailable.');
          }

          return ListView(
            padding: const EdgeInsets.all(AppDimensions.screenPadding),
            children: [
              SectionCard(
                title: 'Check-in QR Code',
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppDimensions.space4),
                    decoration: BoxDecoration(
                      color: context.scheme.primaryContainer.withValues(
                        alpha: 0.45,
                      ),
                      borderRadius: BorderRadius.circular(
                        AppDimensions.radiusMd,
                      ),
                    ),
                    child: Column(
                      children: [
                        if (data.qrCode.isNotEmpty && data.qrCode != '-')
                          QrImageView(
                            data: data.qrCode,
                            size: 260,
                            backgroundColor: Colors.white,
                          )
                        else
                          Icon(
                            Icons.qr_code_2_rounded,
                            size: 120,
                            color: context.scheme.onSurfaceVariant,
                          ),
                        const SizedBox(height: AppDimensions.space2),
                        Text(
                          data.qrCode,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.4,
                              ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Present this QR code at check-in',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppDimensions.space3),
              SectionCard(
                title: 'Documents',
                children: [
                  _DocumentActionButton(
                    label: 'Acceptance Letter',
                    icon: Icons.description_rounded,
                    available: data.acceptanceLetterAvailable,
                    onPressed: data.acceptanceLetterAvailable
                        ? () => _downloadAndOpen(
                            context,
                            path:
                                '/documents/papers/${data.acceptancePaperId}/acceptance-letter',
                            fallbackFilename:
                                'Acceptance_Letter_${data.acceptancePaperId}.pdf',
                          )
                        : null,
                  ),
                  const SizedBox(height: AppDimensions.space2),
                  _DocumentActionButton(
                    label: 'Invoice',
                    icon: Icons.receipt_long_rounded,
                    available: data.invoiceAvailable,
                    onPressed: data.invoiceAvailable
                        ? () => _downloadAndOpen(
                            context,
                            path:
                                '/documents/tickets/${ticket.ticketId}/invoice',
                            fallbackFilename: 'Invoice_${ticket.ticketId}.pdf',
                          )
                        : null,
                  ),
                  const SizedBox(height: AppDimensions.space2),
                  _DocumentActionButton(
                    label: 'Certificate',
                    icon: Icons.workspace_premium_rounded,
                    available: data.certificateAvailable,
                    onPressed: data.certificateAvailable
                        ? () => _downloadAndOpen(
                            context,
                            path:
                                '/documents/tickets/${ticket.ticketId}/certificate',
                            fallbackFilename:
                                'Certificate_${ticket.ticketId}.pdf',
                          )
                        : null,
                  ),
                ],
              ),
              const SizedBox(height: AppDimensions.space3),
              SectionCard(
                title: 'Registration Details',
                children: [
                  SimpleListTile(
                    title: 'Registration Number',
                    subtitle: ticket.registrationNumber?.isNotEmpty == true
                        ? ticket.registrationNumber!
                        : '—',
                    trailing: const Icon(Icons.badge_outlined),
                  ),
                  SimpleListTile(
                    title: 'Ticket Type',
                    subtitle: ticket.ticketType,
                    trailing: const Icon(Icons.confirmation_num_rounded),
                  ),
                  SimpleListTile(
                    title: 'Payment Status',
                    subtitle: ticket.paymentStatus ?? 'UNKNOWN',
                    trailing: const Icon(Icons.payments_outlined),
                  ),
                  SimpleListTile(
                    title: 'Amount',
                    subtitle: ticket.priceLabel ?? '—',
                    trailing: const Icon(Icons.payments_rounded),
                  ),
                  SimpleListTile(
                    title: 'Attendee Name',
                    subtitle: ticket.userName?.isNotEmpty == true
                        ? ticket.userName!
                        : '—',
                    trailing: const Icon(Icons.person_rounded),
                  ),
                  SimpleListTile(
                    title: 'Email',
                    subtitle: ticket.userEmail?.isNotEmpty == true
                        ? ticket.userEmail!
                        : '—',
                    trailing: const Icon(Icons.mail_outline_rounded),
                  ),
                  SimpleListTile(
                    title: 'Check-in',
                    subtitle: ticket.isCheckedIn
                        ? 'Checked in'
                        : 'Not checked in',
                    trailing: Icon(
                      ticket.isCheckedIn
                          ? Icons.verified_rounded
                          : Icons.shield_outlined,
                      color: ticket.isCheckedIn ? Colors.green : null,
                    ),
                  ),
                  SimpleListTile(
                    title: 'Registered At',
                    subtitle: ticket.createdAt?.isNotEmpty == true
                        ? ticket.createdAt!
                        : '—',
                    trailing: const Icon(Icons.schedule_rounded),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Future<_TicketDetailData> _loadTicketData() async {
    final papers = await featureService.getAuthorPapersByConference(
      userId: userId,
      conferenceId: ticket.conferenceId ?? 0,
    );
    final acceptedPaper = papers.where((paper) {
      final status = paper.status.toUpperCase();
      return status == 'ACCEPTED' || status == 'PUBLISHED';
    }).toList();
    final acceptedPaperId = acceptedPaper.isNotEmpty
        ? acceptedPaper.first.paperId
        : ticket.paperId;

    return _TicketDetailData(
      qrCode: ticket.qrCodeValue,
      acceptancePaperId: acceptedPaperId,
      acceptanceLetterAvailable: acceptedPaperId != null,
      invoiceAvailable:
          (ticket.paymentStatus ?? '').toUpperCase() == 'COMPLETED',
      certificateAvailable: ticket.isCheckedIn,
    );
  }

  Future<void> _downloadAndOpen(
    BuildContext context, {
    required String path,
    required String fallbackFilename,
  }) async {
    try {
      final document = await featureService.downloadDocument(
        path: path,
        fallbackFilename: fallbackFilename,
      );
      if (!context.mounted) return;
      final result = await launchUrl(
        Uri.file(document.filePath),
        mode: LaunchMode.externalApplication,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result
                ? 'Downloaded: ${document.filename}'
                : 'Downloaded: ${document.filename}',
          ),
        ),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Download failed: $error')));
    }
  }
}

class _TicketDetailData {
  const _TicketDetailData({
    required this.qrCode,
    required this.acceptanceLetterAvailable,
    required this.invoiceAvailable,
    required this.certificateAvailable,
    this.acceptancePaperId,
  });

  final String qrCode;
  final bool acceptanceLetterAvailable;
  final bool invoiceAvailable;
  final bool certificateAvailable;
  final int? acceptancePaperId;
}

class _DocumentActionButton extends StatelessWidget {
  const _DocumentActionButton({
    required this.label,
    required this.icon,
    required this.available,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final bool available;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final color = available ? context.scheme.primary : Colors.grey;
    return Opacity(
      opacity: available ? 1 : 0.45,
      child: OutlinedButton.icon(
        onPressed: available ? onPressed : null,
        icon: Icon(icon, size: 18, color: color),
        label: Text(label, style: TextStyle(color: color)),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(46),
          side: BorderSide(color: color.withValues(alpha: 0.45)),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.space2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 15),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          Text(label, style: Theme.of(context).textTheme.labelSmall),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.icon, required this.color});

  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
