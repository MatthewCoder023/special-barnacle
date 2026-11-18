import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_motion.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/basics.dart';
import '../../core/widgets/glass.dart';
import '../../data/models.dart';
import '../../domain/charging_rules.dart';
import '../../state/app_state.dart';
import '../community/community_detail_screen.dart';
import '../events/event_detail_screen.dart';
import '../shell/app_shell.dart';
import 'news_widgets.dart';
import 'notifications_screen.dart';
import 'search_screen.dart';

/// Home: the app's hub. EV news is the main content; above it sit the
/// driver's battery and range, quick access to the core modules, and
/// whatever is waiting on the user.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  /// 0 Philippines, 1 World.
  int _region = 0;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final me = state.me;
    final text = Theme.of(context).textTheme;
    final hasWorld = state.news.any((n) => !n.philippines);
    final articles = state.news
        .where((n) => !hasWorld || n.philippines == (_region == 0))
        .toList();
    // Lead with a story that has an image when there is one.
    final featured =
        articles.where((a) => a.imageUrl != null).firstOrNull ??
        articles.firstOrNull;
    final rest = [
      for (final a in articles)
        if (a != featured) a,
    ];

    final list = ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 14, 20, tabBarClearance),
      children: [
        Row(
          children: [
            Avatar(
              me.initials,
              size: 46,
              imageUrl: me.avatarUrl,
              imageBytes: me.avatarBytes,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_greeting(), style: text.bodySmall),
                  Text(
                    me.name.split(' ').first,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.titleLarge?.copyWith(color: AppColors.pinkDeep),
                  ),
                ],
              ),
            ),
            IconSquare(
              icon: 'search',
              label: 'Search',
              onTap: () => pushScreen(context, const SearchScreen()),
            ),
            const SizedBox(width: 8),
            IconSquare(
              icon: 'notifications',
              label: 'Notifications',
              dot: state.unreadCount > 0,
              onTap: () => pushScreen(context, const NotificationsScreen()),
            ),
          ],
        ),
        const SizedBox(height: 18),
        _CompanionCard(vehicle: me.vehicle),
        const SizedBox(height: 14),
        _QuickAccess(role: me.role),
        _ForYou(),
        const SizedBox(height: 26),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(child: Text('EV news', style: text.headlineMedium)),
            Text('Refreshed daily', style: text.bodySmall),
          ],
        ),
        if (hasWorld) ...[
          const SizedBox(height: 12),
          PillRow(
            labels: const ['Philippines', 'World'],
            index: _region,
            padding: EdgeInsets.zero,
            onChanged: (i) => setState(() => _region = i),
          ),
        ],
        const SizedBox(height: 14),
        AnimatedSwitcher(
          duration: AppMotion.of(context, AppMotion.standard),
          switchInCurve: AppMotion.enter,
          switchOutCurve: AppMotion.leave,
          layoutBuilder: (current, previous) => Stack(
            alignment: Alignment.topCenter,
            children: [...previous, ?current],
          ),
          child: Column(
            key: ValueKey(_region),
            children: [
              if (featured == null)
                EmptyState(
                  icon: 'document',
                  title: 'No articles yet',
                  message: state.isRemote
                      ? 'EV news is collected once a day. Pull down to check again.'
                      : 'News appears here once it has been collected.',
                )
              else
                FadeIn(child: FeaturedArticleCard(article: featured)),
              for (final (i, a) in rest.indexed) ...[
                if (i > 0) const Divider(),
                FadeIn(
                  index: i + 1,
                  child: ArticleRow(article: a),
                ),
              ],
            ],
          ),
        ),
      ],
    );

    return SafeArea(
      bottom: false,
      child: state.isRemote
          ? RefreshIndicator(
              color: AppColors.pinkDeep,
              onRefresh: state.refresh,
              child: list,
            )
          : list,
    );
  }

  static String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning,';
    if (hour < 18) return 'Good afternoon,';
    return 'Good evening,';
  }
}

/// The driver's vehicle at a glance, leading into route planning. Without a
/// vehicle it invites the user to add one (progressive profiling).
class _CompanionCard extends StatelessWidget {
  const _CompanionCard({required this.vehicle});

  final Vehicle? vehicle;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final v = vehicle;
    final ownsVehicle =
        state.me.role == PlatformRole.member ||
        state.me.role == PlatformRole.guest;
    if (v == null) {
      if (!ownsVehicle) return const SizedBox.shrink();
      return AppCard(
        color: AppColors.sky,
        onTap: () => AppShell.goTo(context, 'Profile'),
        child: const Row(
          children: [
            AppIcon('car', size: 22),
            SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Add your vehicle',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                  Text(
                    'Get range, compatible chargers and route checks for your EV',
                    style: TextStyle(fontSize: 12.5),
                  ),
                ],
              ),
            ),
            AppIcon('chevron', size: 16),
          ],
        ),
      );
    }
    final range = ChargingRules.remainingRangeKm(v, state.batteryPct);
    final top = state.recommendation?.options.firstOrNull;
    return AppCard(
      color: AppColors.sky,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(v.name, style: const TextStyle(fontSize: 13)),
                    const SizedBox(height: 2),
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: '${state.batteryPct.round()}%',
                            style: const TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          TextSpan(
                            text:
                                '   about ${range.round()} km${v.hasEngine ? ' electric' : ''}',
                            style: const TextStyle(fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              AppButton(
                label: 'Plan a route',
                icon: 'route',
                small: true,
                onTap: () => AppShell.goTo(context, 'Route'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: state.batteryPct / 100,
              minHeight: 7,
              backgroundColor: AppColors.white.withValues(alpha: 0.55),
              color: AppColors.ink,
            ),
          ),
          if (top != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                const AppIcon('charging', size: 15),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Nearest recommended: ${top.station.name} · ${km(top.roadKm)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12.5),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// One-tap entry to the core modules.
class _QuickAccess extends StatelessWidget {
  const _QuickAccess({required this.role});

  final PlatformRole role;

  @override
  Widget build(BuildContext context) {
    void go(String tab, {String? view}) =>
        AppShell.goTo(context, tab, communityView: view);
    final items = <(String icon, String label, VoidCallback onTap)>[
      ('route', 'Route', () => go('Route')),
      if (role == PlatformRole.provider)
        ('store', 'Listings', () => go('Listings'))
      else ...[
        ('community', 'Community', () => go('Community')),
        ('events', 'Events', () => go('Community', view: 'Events')),
      ],
      if (role == PlatformRole.admin)
        ('shield', 'Admin', () => go('Admin'))
      else
        ('wrench', 'Services', () => go('Services')),
    ];
    return Row(
      children: [
        for (final (i, item) in items.indexed) ...[
          if (i > 0) const SizedBox(width: 10),
          Expanded(
            child: Pressable(
              onTap: item.$3,
              label: item.$2,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: glassCard(radius: 20),
                child: Column(
                  children: [
                    AppIcon(
                      item.$1,
                      size: 22,
                      color: i.isOdd ? AppColors.pinkDeep : AppColors.skyDeep,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      item.$2,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// What is waiting on the user: leader tasks, polls, the next event, and
/// profile steps left to complete.
class _ForYou extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final requests = state.managedGroups
        .where((c) => c.joinRequests.isNotEmpty)
        .toList();
    final polls = state.myOpenPolls;
    final next = state.upcomingEvents.firstOrNull;
    final steps = state.profileSteps;

    final cards = <Widget>[
      for (final c in requests)
        _Nudge(
          icon: 'verified',
          title: plural(c.joinRequests.length, 'join request'),
          detail: c.name,
          pink: true,
          onTap: () => pushScreen(
            context,
            CommunityDetailScreen(communityId: c.id, initialTab: 'Members'),
          ),
        ),
      if (polls.isNotEmpty)
        _Nudge(
          icon: 'vote',
          title: '${plural(polls.length, 'poll')} to vote on',
          detail: polls.first.title,
          onTap: () => pushScreen(
            context,
            CommunityDetailScreen(
              communityId: polls.first.communityId,
              initialTab: 'Polls',
            ),
          ),
        ),
      if (next != null)
        _Nudge(
          icon: 'events',
          title: next.title,
          detail: fmtDateTime(next.start),
          pink: true,
          onTap: () => pushScreen(context, EventDetailScreen(eventId: next.id)),
        ),
      if (steps.isNotEmpty)
        _Nudge(
          icon: 'profile',
          title: 'Finish your profile',
          detail: steps.first,
          onTap: () => AppShell.goTo(context, 'Profile'),
        ),
    ];
    if (cards.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: SizedBox(
        height: 78,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          clipBehavior: Clip.none,
          itemCount: cards.length,
          separatorBuilder: (_, _) => const SizedBox(width: 10),
          itemBuilder: (_, i) => FadeIn(index: i, child: cards[i]),
        ),
      ),
    );
  }
}

class _Nudge extends StatelessWidget {
  const _Nudge({
    required this.icon,
    required this.title,
    required this.detail,
    required this.onTap,
    this.pink = false,
  });

  final String icon;
  final String title;
  final String detail;
  final VoidCallback onTap;
  final bool pink;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      label: '$title, $detail',
      child: Container(
        width: 230,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: glassCard(radius: 20),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: pink ? AppColors.pinkSoft : AppColors.skySoft,
                shape: BoxShape.circle,
              ),
              child: AppIcon(
                icon,
                size: 18,
                color: pink ? AppColors.pinkDeep : AppColors.skyDeep,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    detail,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
