import 'dart:async';
import 'package:confms_mobile/constants/app_theme.dart';
import 'package:confms_mobile/constants/colors.dart';
import 'package:confms_mobile/models/auth_user.dart';
import 'package:confms_mobile/features/main_shell/tabs/attend_tab.dart';
import 'package:confms_mobile/features/main_shell/tabs/contribute_tab.dart';
import 'package:confms_mobile/features/main_shell/tabs/home_tab.dart';
import 'package:confms_mobile/features/main_shell/tabs/my_conferences_tab.dart';
import 'package:confms_mobile/features/main_shell/tabs/my_reviews_tab.dart';
import 'package:confms_mobile/features/main_shell/tabs/notifications_tab.dart';
import 'package:confms_mobile/features/main_shell/tabs/profile_tab.dart';
import 'package:confms_mobile/services/auth_session.dart';
import 'package:confms_mobile/services/mobile_feature_service.dart';
import 'package:confms_mobile/services/push_notification_service.dart';
import 'package:flutter/material.dart';

/// Primary bottom tabs.
enum MainTab { home, myConferences, myPapers, myReviews, notifications }

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
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  int _unreadNotificationCount = 0;
  StreamSubscription? _fcmSub;

  @override
  void initState() {
    super.initState();
    _loadUnreadCount();
    _listenForPushMessages();
  }

  @override
  void dispose() {
    _fcmSub?.cancel();
    super.dispose();
  }

  Future<void> _loadUnreadCount() async {
    final userId = widget.authSession.user?.id;
    if (userId == null) return;
    try {
      final notifs = await widget.featureService.getNotifications(userId: userId);
      if (!mounted) return;
      setState(() {
        _unreadNotificationCount = notifs.where((n) => !n.isRead).length;
      });
    } catch (_) {}
  }

  void _listenForPushMessages() {
    final push = PushNotificationService.instance;
    if (!push.isInitialized) return;

    _fcmSub = push.onMessage.listen((message) {
      // Increment badge
      if (mounted) {
        setState(() => _unreadNotificationCount++);
      }

      // Show snackbar
      final title = message.notification?.title ?? 'New Notification';
      final body = message.notification?.body ?? '';
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
                if (body.isNotEmpty) Text(body, maxLines: 2, overflow: TextOverflow.ellipsis),
              ],
            ),
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(
              label: 'View',
              onPressed: () {
                setState(() => _currentTab = MainTab.notifications);
              },
            ),
          ),
        );
      }
    });
  }

  Future<void> _handleLogout() async {
    await widget.onLogout();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
  }

  void _openDrawer() {
    _scaffoldKey.currentState?.openDrawer();
  }

  // Navigate to full-screen secondary pages via drawer.
  void _openTickets() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          body: SafeArea(
            child: AttendTab(
              featureService: widget.featureService,
              user: widget.authSession.user,
            ),
          ),
        ),
      ),
    );
  }

  void _openProfile() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          body: SafeArea(
            child: ProfileTab(
              authSession: widget.authSession,
              featureService: widget.featureService,
              onLogout: _handleLogout,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.authSession.user;
    final scheme = context.scheme;
    final fullName =
        '${user?.firstName ?? ''} ${user?.lastName ?? ''}'.trim();

    return Scaffold(
      key: _scaffoldKey,
      drawer: _buildDrawer(context, scheme, fullName),
      body: SafeArea(
        child: IndexedStack(
          index: _currentTab.index,
          children: [
            HomeTab(
              featureService: widget.featureService,
              user: user,
              onMenuTap: _openDrawer,
            ),
            MyConferencesTab(
              featureService: widget.featureService,
              user: user,
              onMenuTap: _openDrawer,
            ),
            ContributeTab(
              user: user,
              featureService: widget.featureService,
              onMenuTap: _openDrawer,
            ),
            MyReviewsTab(
              featureService: widget.featureService,
              user: user,
              onMenuTap: _openDrawer,
            ),
            NotificationsTab(
              featureService: widget.featureService,
              user: user,
              onMenuTap: _openDrawer,
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          decoration: BoxDecoration(
            color: scheme.surface,
            border:
                Border(top: BorderSide(color: context.tokens.cardBorder)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
          child: NavigationBar(
            selectedIndex: _currentTab.index,
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            height: 64,
            onDestinationSelected: (index) {
              setState(() => _currentTab = MainTab.values[index]);
            },
            destinations: [
              const NavigationDestination(
                icon: Icon(Icons.home_outlined, size: 22),
                selectedIcon: Icon(Icons.home, size: 22),
                label: 'Home',
              ),
              const NavigationDestination(
                icon: Icon(Icons.groups_outlined, size: 22),
                selectedIcon: Icon(Icons.groups, size: 22),
                label: 'Confs',
              ),
              const NavigationDestination(
                icon: Icon(Icons.article_outlined, size: 22),
                selectedIcon: Icon(Icons.article, size: 22),
                label: 'Papers',
              ),
              const NavigationDestination(
                icon: Icon(Icons.rate_review_outlined, size: 22),
                selectedIcon: Icon(Icons.rate_review, size: 22),
                label: 'Reviews',
              ),
              NavigationDestination(
                icon: Badge(
                  isLabelVisible: _unreadNotificationCount > 0,
                  label: Text('$_unreadNotificationCount'),
                  child: const Icon(Icons.notifications_outlined, size: 22),
                ),
                selectedIcon: Badge(
                  isLabelVisible: _unreadNotificationCount > 0,
                  label: Text('$_unreadNotificationCount'),
                  child: const Icon(Icons.notifications, size: 22),
                ),
                label: 'Alerts',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDrawer(
    BuildContext context,
    ColorScheme scheme,
    String fullName,
  ) {
    final user = widget.authSession.user;
    final email = user?.email ?? '';
    final initials = _initials(user);

    return Drawer(
      child: Column(
        children: [
          // Drawer header with gradient
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(
              20,
              MediaQuery.of(context).padding.top + 20,
              20,
              20,
            ),
            decoration:
                const BoxDecoration(gradient: AppColors.primaryGradient),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: Colors.white.withValues(alpha: 0.2),
                      child: Text(
                        initials,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            fullName.isEmpty ? 'User' : fullName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            email,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.85),
                              fontSize: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Logo
                    Image.asset(
                      'assets/images/White (1).png',
                  height: 20,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Text(
                    'ConfHub',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Menu items
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                const SizedBox(height: 8),
                _DrawerSectionHeader(title: 'Quick Navigation'),
                _DrawerItem(
                  icon: Icons.home_rounded,
                  label: 'Home',
                  selected: _currentTab == MainTab.home,
                  onTap: () {
                    setState(() => _currentTab = MainTab.home);
                    Navigator.pop(context);
                  },
                ),
                _DrawerItem(
                  icon: Icons.groups_rounded,
                  label: 'My Conferences',
                  selected: _currentTab == MainTab.myConferences,
                  onTap: () {
                    setState(() => _currentTab = MainTab.myConferences);
                    Navigator.pop(context);
                  },
                ),
                _DrawerItem(
                  icon: Icons.article_rounded,
                  label: 'My Papers',
                  selected: _currentTab == MainTab.myPapers,
                  onTap: () {
                    setState(() => _currentTab = MainTab.myPapers);
                    Navigator.pop(context);
                  },
                ),
                _DrawerItem(
                  icon: Icons.rate_review_rounded,
                  label: 'My Reviews',
                  selected: _currentTab == MainTab.myReviews,
                  onTap: () {
                    setState(() => _currentTab = MainTab.myReviews);
                    Navigator.pop(context);
                  },
                ),
                _DrawerItem(
                  icon: Icons.notifications_rounded,
                  label: 'Notifications',
                  selected: _currentTab == MainTab.notifications,
                  onTap: () {
                    setState(() => _currentTab = MainTab.notifications);
                    Navigator.pop(context);
                  },
                ),
                const Divider(indent: 16, endIndent: 16),
                _DrawerSectionHeader(title: 'More'),
                _DrawerItem(
                  icon: Icons.confirmation_num_rounded,
                  label: 'My Tickets',
                  onTap: () {
                    Navigator.pop(context);
                    _openTickets();
                  },
                ),
                _DrawerItem(
                  icon: Icons.qr_code_scanner_rounded,
                  label: 'Scan QR Check-in',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, '/qr-scanner');
                  },
                ),
                _DrawerItem(
                  icon: Icons.person_rounded,
                  label: 'Profile',
                  onTap: () {
                    Navigator.pop(context);
                    _openProfile();
                  },
                ),
                const Divider(indent: 16, endIndent: 16),
                _DrawerItem(
                  icon: Icons.logout_rounded,
                  label: 'Logout',
                  color: Colors.red,
                  onTap: () {
                    Navigator.pop(context);
                    _handleLogout();
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _initials(AuthUser? user) {
    final first = (user?.firstName ?? '').trim();
    final last = (user?.lastName ?? '').trim();
    final a = first.isNotEmpty ? first[0] : '';
    final b = last.isNotEmpty ? last[0] : '';
    final initials = '$a$b'.trim();
    return initials.isEmpty ? 'U' : initials.toUpperCase();
  }
}

class _DrawerSectionHeader extends StatelessWidget {
  const _DrawerSectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  const _DrawerItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.selected = false,
    this.color,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool selected;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final itemColor = color ?? (selected ? scheme.primary : scheme.onSurface);

    return ListTile(
      leading: Icon(icon, color: itemColor, size: 22),
      title: Text(
        label,
        style: TextStyle(
          color: itemColor,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          fontSize: 14,
        ),
      ),
      selected: selected,
      selectedTileColor: scheme.primaryContainer.withValues(alpha: 0.15),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      onTap: onTap,
    );
  }
}
