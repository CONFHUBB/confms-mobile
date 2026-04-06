import 'package:confms_mobile/constants/dimensions.dart';
import 'package:confms_mobile/constants/app_theme.dart';
import 'package:confms_mobile/constants/text_styles.dart';
import 'package:confms_mobile/features/main_shell/widgets/shell_shared_widgets.dart';
import 'package:confms_mobile/models/auth_user.dart';
import 'package:confms_mobile/services/mobile_feature_service.dart';
import 'package:flutter/material.dart';

class ContributeTab extends StatefulWidget {
  const ContributeTab({
    super.key,
    required this.user,
    required this.featureService,
  });

  final AuthUser? user;
  final MobileFeatureService featureService;

  @override
  State<ContributeTab> createState() => _ContributeTabState();
}

class _ContributeTabState extends State<ContributeTab> {
  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    if (user == null) return const CenteredMutedText('Missing user context.');

    return FutureBuilder<List<TaskPreview>>(
      future: widget.featureService.getSubmissionUpdates(userId: user.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return SectionError(message: snapshot.error.toString());
        }

        final papers = snapshot.data ?? const <TaskPreview>[];

        return ListView(
          padding: const EdgeInsets.all(AppDimensions.screenPadding),
          children: [
            Text('My Papers', style: context.text.headlineSmall),
            const SizedBox(height: AppDimensions.space2),
            Text(
              'Track your submitted papers and their current status.',
              style: AppTextStyles.bodyMuted.copyWith(
                color: context.scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppDimensions.space3),
            SectionCard(
              title: 'My Submissions',
              children: papers
                  .map(
                    (task) => SimpleListTile(
                      title: task.title,
                      subtitle: task.subtitle,
                      trailing: const Icon(Icons.upload_file_outlined),
                    ),
                  )
                  .toList(),
            ),
          ],
        );
      },
    );
  }
}
