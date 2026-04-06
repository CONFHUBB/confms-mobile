import 'package:confms_mobile/constants/dimensions.dart';
import 'package:confms_mobile/constants/text_styles.dart';
import 'package:confms_mobile/models/conference.dart';
import 'package:confms_mobile/services/conference_service.dart';
import 'package:flutter/material.dart';

class ConferenceDetailScreen extends StatelessWidget {
  const ConferenceDetailScreen({
    super.key,
    required this.conferenceService,
  });

  final ConferenceService conferenceService;

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments;
    final conferenceId = _resolveConferenceId(args);

    if (conferenceId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Conference Detail')),
        body: const Padding(
          padding: EdgeInsets.all(AppDimensions.screenPadding),
          child: Text(
            'No conference selected.',
            style: AppTextStyles.body,
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Conference Detail')),
      body: FutureBuilder<Conference>(
        future: conferenceService.getConferenceById(conferenceId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Padding(
              padding: const EdgeInsets.all(AppDimensions.screenPadding),
              child: Text(
                snapshot.error.toString(),
                style: AppTextStyles.body,
              ),
            );
          }

          final conference = snapshot.data;
          if (conference == null) {
            return const Padding(
              padding: EdgeInsets.all(AppDimensions.screenPadding),
              child: Text('Conference not found.', style: AppTextStyles.body),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(AppDimensions.screenPadding),
            children: [
              Text(conference.name, style: AppTextStyles.h2),
              const SizedBox(height: AppDimensions.space2),
              Text(conference.acronym, style: AppTextStyles.caption),
              const SizedBox(height: AppDimensions.space4),
              Text(conference.description, style: AppTextStyles.body),
              const SizedBox(height: AppDimensions.space4),
              Text(
                'Location: ${conference.location}',
                style: AppTextStyles.bodyMuted,
              ),
              const SizedBox(height: AppDimensions.space2),
              Text('Area: ${conference.area}', style: AppTextStyles.bodyMuted),
              const SizedBox(height: AppDimensions.space2),
              Text(
                'Country: ${conference.country}',
                style: AppTextStyles.bodyMuted,
              ),
              const SizedBox(height: AppDimensions.space2),
              Text(
                'Status: ${conference.status}',
                style: AppTextStyles.bodyMuted,
              ),
            ],
          );
        },
      ),
    );
  }

  int? _resolveConferenceId(dynamic args) {
    if (args is int) return args;
    if (args is String) return int.tryParse(args);
    if (args is Conference) return args.id;
    if (args is Map<String, dynamic>) {
      final raw = args['conferenceId'] ?? args['id'];
      if (raw is int) return raw;
      if (raw is String) return int.tryParse(raw);
    }
    return null;
  }
}
