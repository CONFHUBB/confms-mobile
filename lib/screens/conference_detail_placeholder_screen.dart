import 'package:confms_mobile/constants/dimensions.dart';
import 'package:confms_mobile/constants/text_styles.dart';
import 'package:confms_mobile/models/conference.dart';
import 'package:flutter/material.dart';

class ConferenceDetailPlaceholderScreen extends StatelessWidget {
  const ConferenceDetailPlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final conference =
        ModalRoute.of(context)?.settings.arguments as Conference?;

    return Scaffold(
      appBar: AppBar(title: const Text('Conference Detail')),
      body: Padding(
        padding: const EdgeInsets.all(AppDimensions.screenPadding),
        child: conference == null
            ? const Text('No conference selected.', style: AppTextStyles.body)
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(conference.name, style: AppTextStyles.h2),
                  const SizedBox(height: AppDimensions.space3),
                  Text(conference.description, style: AppTextStyles.body),
                ],
              ),
      ),
    );
  }
}
