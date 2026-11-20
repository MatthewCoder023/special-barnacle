import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_motion.dart';
import '../../core/widgets/app_tab_bar.dart';
import '../../core/widgets/glass.dart';
import '../../core/widgets/overlays.dart';
import '../../data/models.dart';
import '../../state/app_state.dart';
import '../admin/admin_screen.dart';
import '../charging/services_screen.dart';
import '../community/communities_screen.dart';
import '../home/home_screen.dart';
import '../profile/profile_screen.dart';
import '../provider/provider_home_screen.dart';
import '../route/route_screen.dart';

/// Bottom-tab shell. Home is always the middle tab and the one shown first.
/// The other tabs depend on the signed-in role:
///
/// - Member, leader, guest: Community, Route, Home, Services, Profile
/// - Service provider: Listings, Route, Home, Services, Profile
/// - Platform administrator: Admin, Community, Home, Route, Profile
///
/// Events have no tab of their own: they live inside Community.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  /// Switches to the tab with [label] from any screen below the shell.
  /// [communityView] also picks a view inside the Community tab, for
  /// example 'Events'.
  static void goTo(
    BuildContext context,
    String label, {
    String? communityView,
  }) => context.findAncestorStateOfType<_AppShellState>()?._goTo(
    label,
    communityView,
  );

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  static const _homeIndex = 2;
  int _index = _homeIndex;

  /// Asks the Community tab to show one of its views.
  final _communityView = ValueNotifier<String?>(null);

  static const _community = AppTab('community', 'Community');
  static const _route = AppTab('route', 'Route');
  static const _home = AppTab('home', 'Home');
  static const _services = AppTab('wrench', 'Services');
  static const _profile = AppTab('profile', 'Profile');

  late final _communityScreen = CommunitiesScreen(viewRequest: _communityView);

  List<(AppTab, Widget)> _tabs(PlatformRole role) => switch (role) {
    PlatformRole.provider => const [
      (AppTab('store', 'Listings'), ProviderHomeScreen()),
      (_route, RouteScreen()),
      (_home, HomeScreen()),
      (_services, ServicesScreen()),
      (_profile, ProfileScreen()),
    ],
    PlatformRole.admin => [
      const (AppTab('shield', 'Admin'), AdminScreen()),
      (_community, _communityScreen),
      const (_home, HomeScreen()),
      const (_route, RouteScreen()),
      const (_profile, ProfileScreen()),
    ],
    _ => [
      (_community, _communityScreen),
      const (_route, RouteScreen()),
      const (_home, HomeScreen()),
      const (_services, ServicesScreen()),
      const (_profile, ProfileScreen()),
    ],
  };

  void _goTo(String label, String? communityView) {
    final role = context.read<AppState>().me.role;
    final i = _tabs(role).indexWhere((t) => t.$1.label == label);
    if (i < 0) return;
    if (communityView != null) _communityView.value = communityView;
    setState(() => _index = i);
  }

  @override
  void dispose() {
    _communityView.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final role = context.select<AppState, PlatformRole>((s) => s.me.role);
    // A change the server rejected, or a failed reload: tell the user once.
    final error = context.select<AppState, String?>((s) => s.syncError);
    if (error != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final state = context.read<AppState>();
        final message = state.syncError;
        if (message == null) return;
        state.clearSyncError();
        showToast(context, message, success: false);
      });
    }
    final tabs = _tabs(role);
    final duration = AppMotion.of(context, AppMotion.standard);
    return Scaffold(
      extendBody: true,
      body: AppBackdrop(
        child: Stack(
          children: [
            // Every tab stays alive; the active one fades in over the old one.
            for (var i = 0; i < tabs.length; i++)
              IgnorePointer(
                ignoring: i != _index,
                child: AnimatedOpacity(
                  opacity: i == _index ? 1 : 0,
                  duration: duration,
                  curve: i == _index ? AppMotion.enter : AppMotion.leave,
                  child: ExcludeSemantics(
                    excluding: i != _index,
                    child: TickerMode(enabled: i == _index, child: tabs[i].$2),
                  ),
                ),
              ),
          ],
        ),
      ),
      bottomNavigationBar: AppTabBar(
        tabs: [for (final t in tabs) t.$1],
        index: _index,
        onChanged: (i) => setState(() => _index = i),
      ),
    );
  }
}

/// Bottom padding for tab screens so content clears the floating tab bar.
const tabBarClearance = 120.0;
