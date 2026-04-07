import 'package:confms_mobile/features/main_shell/tabs/notifications_tab.dart';
import 'package:confms_mobile/models/auth_user.dart';
import 'package:confms_mobile/services/mobile_feature_service.dart';
import 'package:flutter/material.dart';

class NotificationsCenterScreen extends StatelessWidget {
  const NotificationsCenterScreen({
    super.key,
    required this.featureService,
    required this.user,
  });

  final MobileFeatureService featureService;
  final AuthUser? user;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: NotificationsTab(featureService: featureService, user: user),
    );
  }
}
