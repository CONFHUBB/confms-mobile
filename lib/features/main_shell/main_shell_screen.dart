import 'package:confms_mobile/constants/app_theme.dart';
import 'package:confms_mobile/constants/dimensions.dart';
import 'package:confms_mobile/features/main_shell/tabs/attend_tab.dart';
import 'package:confms_mobile/features/main_shell/tabs/contribute_tab.dart';
import 'package:confms_mobile/features/main_shell/tabs/home_tab.dart';
import 'package:confms_mobile/features/main_shell/tabs/profile_tab.dart';
import 'package:confms_mobile/services/auth_session.dart';
import 'package:confms_mobile/services/mobile_feature_service.dart';
import 'package:flutter/material.dart';

enum MainTab { home, myTickets, myPapers, profile }

class MainShellScreen extends StatefulWidget {
  const MainShellScreen({
    super.key,
    required this.authSession,
    required this.featureService,
    required this.onLogout,
  });

  final AuthSession authSession;
  final MobileFeatureService featureService;
  final Future<void> Function() onLogout;

  @override
  State<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends State<MainShellScreen> {
  MainTab _currentTab = MainTab.home;

  Future<void> _handleLogout() async {
    await widget.onLogout();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.authSession.user;

    return Scaffold(
      body: SafeArea(
        child: IndexedStack(
          index: _currentTab.index,
          children: [
            HomeTab(featureService: widget.featureService, user: user),
            AttendTab(
              featureService: widget.featureService,
              user: user,
            ),
            ContributeTab(
              user: user,
              featureService: widget.featureService,
            ),
            ProfileTab(
              authSession: widget.authSession,
              featureService: widget.featureService,
              onLogout: _handleLogout,
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          decoration: BoxDecoration(
            color: context.scheme.surface,
            border: Border(top: BorderSide(color: context.tokens.cardBorder)),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.space2,
            vertical: 4,
          ),
          child: NavigationBar(
            selectedIndex: _currentTab.index,
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            onDestinationSelected: (index) {
              setState(() => _currentTab = MainTab.values[index]);
            },
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home),
                label: 'Home',
              ),
              NavigationDestination(
                icon: Icon(Icons.confirmation_num_outlined),
                selectedIcon: Icon(Icons.confirmation_num),
                label: 'My Tickets',
              ),
              NavigationDestination(
                icon: Icon(Icons.article_outlined),
                selectedIcon: Icon(Icons.article),
                label: 'My Papers',
              ),
              NavigationDestination(
                icon: Icon(Icons.person_outline),
                selectedIcon: Icon(Icons.person),
                label: 'Profile',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
