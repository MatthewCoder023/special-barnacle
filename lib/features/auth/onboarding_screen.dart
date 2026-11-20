import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_motion.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/basics.dart';
import '../../core/widgets/glass.dart';
import '../../data/seed_data.dart';
import '../../domain/charging_rules.dart';
import '../../state/app_state.dart';
import '../shared/shared_widgets.dart';
import 'auth_screen.dart';
import 'welcome_screen.dart';

/// First-run onboarding: three slides, each with something to try, then
/// straight into sign-up. The slides use illustrative sample content.
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  final _pages = PageController();
  int _page = 0;
  static const _count = 3;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _continue({bool signIn = false}) {
    final remote = context.read<AppState>().isRemote;
    pushScreen(
      context,
      remote ? AuthScreen(startWithSignIn: signIn) : const SignInScreen(),
    );
  }

  void _next() {
    if (_page == _count - 1) {
      _continue();
      return;
    }
    if (AppMotion.reduced(context)) {
      _pages.jumpToPage(_page + 1);
    } else {
      _pages.nextPage(duration: AppMotion.slow, curve: AppMotion.move);
    }
  }

  @override
  Widget build(BuildContext context) {
    final remote = context.read<AppState>().isRemote;
    final last = _page == _count - 1;
    return Scaffold(
      body: AppBackdrop(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 14, 16, 0),
                child: Row(
                  children: [
                    const Text(
                      'EVYAHE',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 3,
                        color: AppColors.skyDeep,
                      ),
                    ),
                    const Spacer(),
                    AnimatedOpacity(
                      opacity: last ? 0 : 1,
                      duration: AppMotion.of(context, AppMotion.fast),
                      child: IgnorePointer(
                        ignoring: last,
                        child: AppButton(
                          label: 'Skip',
                          kind: AppButtonKind.ghost,
                          small: true,
                          onTap: _continue,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: PageView(
                  controller: _pages,
                  onPageChanged: (i) => setState(() => _page = i),
                  children: [
                    _Slide(
                      controller: _pages,
                      index: 0,
                      demo: const _CommunityDemo(),
                      title: 'Find your',
                      accent: 'people.',
                      body: 'Join EV communities and the tribes inside them, by model, region or interest.',
                    ),
                    _Slide(
                      controller: _pages,
                      index: 1,
                      demo: const _EventDemo(),
                      title: 'Drive',
                      accent: 'together.',
                      body: 'RSVP with your vehicle and battery level, and see if you can make the trip before you leave.',
                    ),
                    _Slide(
                      controller: _pages,
                      index: 2,
                      demo: const _RangeDemo(),
                      title: 'Know before',
                      accent: 'you go.',
                      body: 'Compatible chargers, range checks and route planning for your own EV.',
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < _count; i++)
                    AnimatedContainer(
                      duration: AppMotion.of(context, AppMotion.standard),
                      curve: AppMotion.move,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: i == _page ? 24 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: i == _page ? AppColors.pink : AppColors.sky,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
                child: Column(
                  children: [
                    AppButton(
                      label: last ? 'Get started' : 'Next',
                      icon: last ? null : 'arrow',
                      expand: true,
                      onTap: _next,
                    ),
                    const SizedBox(height: 4),
                    AppButton(
                      label: remote
                          ? 'I already have an account'
                          : 'Use a sample account',
                      kind: AppButtonKind.ghost,
                      small: true,
                      onTap: () => _continue(signIn: true),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Slide extends StatelessWidget {
  const _Slide({
    required this.controller,
    required this.index,
    required this.demo,
    required this.title,
    required this.accent,
    required this.body,
  });

  final PageController controller;
  final int index;
  final Widget demo;
  final String title;
  final String accent;
  final String body;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            // The demo drifts a little slower than the page while swiping,
            // which gives the slides depth. Reduced motion turns it off.
            child: AnimatedBuilder(
              animation: controller,
              builder: (context, child) {
                final page =
                    controller.hasClients && controller.position.haveDimensions
                    ? controller.page ?? index.toDouble()
                    : index.toDouble();
                final shift = AppMotion.reduced(context)
                    ? 0.0
                    : (page - index) * 70;
                return Transform.translate(
                  offset: Offset(shift, 0),
                  child: child,
                );
              },
              child: Center(
                child: SingleChildScrollView(
                  physics: const NeverScrollableScrollPhysics(),
                  child: demo,
                ),
              ),
            ),
          ),
          Text.rich(
            TextSpan(
              text: '$title ',
              children: [
                TextSpan(
                  text: accent,
                  style: const TextStyle(color: AppColors.pink),
                ),
              ],
              style: text.headlineLarge?.copyWith(fontSize: 32),
            ),
          ),
          const SizedBox(height: 10),
          Text(body, style: text.bodyLarge?.copyWith(color: AppColors.inkSoft)),
          const SizedBox(height: 22),
        ],
      ),
    );
  }
}

/// Slide 1: a community card you can join.
class _CommunityDemo extends StatefulWidget {
  const _CommunityDemo();

  @override
  State<_CommunityDemo> createState() => _CommunityDemoState();
}

class _CommunityDemoState extends State<_CommunityDemo> {
  bool _joined = false;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FadeIn(
          child: Align(
            alignment: Alignment.centerRight,
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: glassCard(radius: 18),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppIcon('flag', size: 16, color: AppColors.pinkDeep),
                  SizedBox(width: 8),
                  Text(
                    'Weekend Convoy Tribe',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
        ),
        FadeIn(
          index: 2,
          child: AppCard(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.skySoft,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const AppIcon(
                        'community',
                        color: AppColors.skyDeep,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Metro EV Owners Circle',
                            style: text.titleMedium,
                          ),
                          AnimatedSwitcher(
                            duration: AppMotion.of(context, AppMotion.standard),
                            layoutBuilder: (current, previous) => Stack(
                              alignment: Alignment.centerLeft,
                              children: [...previous, ?current],
                            ),
                            child: Text(
                              '${_joined ? 129 : 128} members · 3 tribes',
                              key: ValueKey(_joined),
                              style: text.bodySmall,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    for (final (i, n) in const ['RC', 'JD', 'CL', 'BT'].indexed)
                      Align(
                        widthFactor: 0.72,
                        child: Avatar(n, size: 34, pink: i.isOdd),
                      ),
                    const Spacer(),
                    AppButton(
                      label: _joined ? 'Joined' : 'Join',
                      icon: _joined ? 'check' : 'add',
                      kind: _joined
                          ? AppButtonKind.soft
                          : AppButtonKind.primary,
                      small: true,
                      onTap: () => setState(() => _joined = !_joined),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        FadeIn(
          index: 4,
          child: Align(
            alignment: Alignment.centerLeft,
            child: Container(
              margin: const EdgeInsets.only(top: 12),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: glassCard(radius: 18),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppIcon('vote', size: 16, color: AppColors.skyDeep),
                  SizedBox(width: 8),
                  Text(
                    'Poll: where to in December?',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Slide 2: an event you can RSVP to, which then shows the route check.
class _EventDemo extends StatefulWidget {
  const _EventDemo();

  @override
  State<_EventDemo> createState() => _EventDemoState();
}

class _EventDemoState extends State<_EventDemo> {
  bool _going = false;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return FadeIn(
      child: AppCard(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Tag('Convoy', tone: Tone.pink),
                const SizedBox(width: 8),
                Text('Sat · 6:00 AM', style: text.bodySmall),
              ],
            ),
            const SizedBox(height: 10),
            Text('Tagaytay Weekend Run', style: text.titleLarge),
            const SizedBox(height: 14),
            const RouteStrip(
              from: 'BGC, Taguig',
              to: 'Tagaytay',
              via: 'Sta. Rosa',
            ),
            const SizedBox(height: 14),
            AnimatedSize(
              duration: AppMotion.of(context, AppMotion.standard),
              curve: AppMotion.move,
              alignment: Alignment.topCenter,
              child: _going
                  ? const Padding(
                      padding: EdgeInsets.only(bottom: 12),
                      child: NoticeBox(
                        'Route check: your vehicle can make the trip, with about 74% left on arrival.',
                        tone: Tone.success,
                        icon: 'check',
                      ),
                    )
                  : const SizedBox(width: double.infinity),
            ),
            AppButton(
              label: _going ? 'You are going' : 'RSVP',
              icon: _going ? 'check' : null,
              kind: _going ? AppButtonKind.soft : AppButtonKind.primary,
              expand: true,
              onTap: () => setState(() => _going = !_going),
            ),
          ],
        ),
      ),
    );
  }
}

/// Slide 3: drag the battery level and watch the range checks change. It
/// uses the app's real range rule on a sample vehicle.
class _RangeDemo extends StatefulWidget {
  const _RangeDemo();

  @override
  State<_RangeDemo> createState() => _RangeDemoState();
}

class _RangeDemoState extends State<_RangeDemo> {
  double _battery = 55;

  @override
  Widget build(BuildContext context) {
    final vehicle = SeedData.vehicles.first;
    const here = SeedData.userPlace;
    final range = ChargingRules.remainingRangeKm(vehicle, _battery);
    final trips = [SeedData.places[8], SeedData.places[10]];
    return FadeIn(
      child: AppCard(
        color: AppColors.sky,
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(vehicle.name, style: const TextStyle(fontSize: 13)),
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '${_battery.round()}%',
                    style: const TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  TextSpan(
                    text: '   about ${range.round()} km',
                    style: const TextStyle(fontSize: 15),
                  ),
                ],
              ),
            ),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: AppColors.ink,
                inactiveTrackColor: AppColors.white.withValues(alpha: 0.6),
              ),
              child: Slider(
                value: _battery,
                min: 5,
                max: 100,
                semanticFormatterCallback: (v) =>
                    '${v.round()} percent battery',
                onChanged: (v) => setState(() => _battery = v),
              ),
            ),
            for (final place in trips)
              Builder(
                builder: (context) {
                  final check = ChargingRules.roundTrip(
                    vehicle: vehicle,
                    batteryPct: _battery,
                    lat: here.lat,
                    lng: here.lng,
                    destLat: place.lat,
                    destLng: place.lng,
                  );
                  return Container(
                    margin: const EdgeInsets.only(top: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.white.withValues(alpha: 0.75),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${place.name.split(',').first} and back · ${km(check.roadKm * 2)}',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        AnimatedSwitcher(
                          duration: AppMotion.of(context, AppMotion.fast),
                          child: Tag(
                            check.passes ? 'In range' : 'Needs a charge',
                            key: ValueKey(check.passes),
                            tone: check.passes ? Tone.success : Tone.danger,
                            icon: check.passes ? 'check' : 'charging',
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
