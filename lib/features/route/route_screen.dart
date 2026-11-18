import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_motion.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/basics.dart';
import '../../core/widgets/glass.dart';
import '../../core/widgets/overlays.dart';
import '../../data/models.dart';
import '../../data/seed_data.dart';
import '../../domain/charging_rules.dart';
import '../../domain/route_planner.dart';
import '../../state/app_state.dart';
import '../charging/station_detail_screen.dart';
import '../charging/tools_screens.dart';
import '../shared/shared_widgets.dart';
import 'ev_map.dart';
import 'stations_list.dart';

/// Route planning: a full-screen map with floating controls and a bottom
/// panel. Three states share the screen: browsing, route preview, and the
/// navigation view.
///
/// What is real and what is simulated:
/// - Real: station data, compatibility, status and queue, battery and range
///   checks, the one-stop rule, and the hand-off to Google Maps.
/// - Estimated: distances and times (see `RouteService.isEstimate`).
/// - Simulated: the map itself and the movement in the navigation view.
///   Both are labelled on screen.
class RouteScreen extends StatefulWidget {
  const RouteScreen({super.key});

  @override
  State<RouteScreen> createState() => _RouteScreenState();
}

class _RouteScreenState extends State<RouteScreen>
    with SingleTickerProviderStateMixin {
  final _map = GlobalKey<EvMapViewState>();

  Place? _destination;

  /// Route options for [_destination]; null while they are being planned.
  List<RouteOption>? _options;
  int _selected = 0;
  bool _navigating = false;
  bool _compatibleOnly = true;

  /// Identifies the inputs of the plan in flight, so a slower earlier
  /// request cannot overwrite a newer one.
  String? _planKey;
  final _recent = <Place>[];

  /// Measured height of the bottom panel, so the map can frame the route in
  /// the space above it.
  final _panelKey = GlobalKey();
  double _panelHeight = 260;

  void _measurePanel() {
    final height = _panelKey.currentContext?.size?.height;
    if (!mounted || height == null || (height - _panelHeight).abs() < 6) return;
    setState(() => _panelHeight = height);
    if (!_navigating) _fit();
  }

  /// Drives the simulated movement along the route.
  late final AnimationController _drive = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 26),
  );

  @override
  void dispose() {
    _drive.dispose();
    super.dispose();
  }

  /// Starting point chosen by the user; null means their current location.
  Place? _origin;

  String _keyFor(AppState state, Place destination) => [
    _origin?.name,
    destination.name,
    state.batteryPct.round(),
    state.me.vehicle?.name,
    state.me.chargeToPct,
    state.me.reservePct,
  ].join('|');

  Future<void> _plan(Place destination) async {
    final state = context.read<AppState>();
    final key = _keyFor(state, destination);
    _drive.stop();
    setState(() {
      _destination = destination;
      _options = null;
      _selected = 0;
      _navigating = false;
      _planKey = key;
      _recent
        ..removeWhere((p) => p.name == destination.name)
        ..insert(0, destination);
    });
    final options = await routeService.plan(
      origin: _origin ?? state.location,
      destination: destination,
      vehicle: state.me.vehicle,
      batteryPct: state.batteryPct,
      stations: state.stations,
      now: state.now,
      chargeToPct: state.me.chargeToPct.toDouble(),
      reservePct: state.me.reservePct.toDouble(),
    );
    if (!mounted || _planKey != key) return;
    setState(() => _options = options);
    _fit();
  }

  void _fit() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final options = _options;
      if (!mounted || options == null || options.isEmpty) return;
      _map.currentState?.fitTo(options[_selected].points);
    });
  }

  void _clear() {
    _drive.stop();
    setState(() {
      _destination = null;
      _origin = null;
      _options = null;
      _navigating = false;
      _planKey = null;
    });
    _map.currentState?.recenter();
  }

  void _start() {
    setState(() => _navigating = true);
    _fit();
    // With reduced motion the view stays still instead of animating.
    if (!AppMotion.reduced(context)) _drive.forward(from: 0);
  }

  void _end() {
    _drive.stop();
    setState(() => _navigating = false);
  }

  Future<void> _search() async {
    final picked = await showAppSheet<Place>(
      context,
      title: 'Where to?',
      builder: (_) => const _DestinationSearch(),
    );
    if (picked != null && mounted) _plan(picked);
  }

  /// Lets the user start the trip from somewhere other than where they are.
  Future<void> _pickOrigin() async {
    final state = context.read<AppState>();
    final picked = await showAppSheet<Place>(
      context,
      title: 'Starting point',
      builder: (_) => const _DestinationSearch(offerCurrentLocation: true),
    );
    final destination = _destination;
    if (picked == null || !mounted || destination == null) return;
    setState(() => _origin = picked == state.location ? null : picked);
    _plan(destination);
  }

  void _chargeNow() {
    final state = context.read<AppState>();
    final rec = state.recommendation;
    final option = rec?.options.firstOrNull ?? rec?.fallback;
    if (option == null) {
      showToast(
        context,
        state.me.vehicle == null
            ? 'Add a vehicle in Profile to get a recommended station.'
            : 'No compatible station is within reach at this battery level.',
        success: false,
      );
      return;
    }
    final s = option.station;
    _plan(Place(s.name, s.lat, s.lng));
  }

  void _nearestService() {
    final state = context.read<AppState>();
    final here = state.location;
    final list = [...state.directory]
      ..sort(
        (a, b) => Geo.haversineKm(
          here.lat,
          here.lng,
          a.lat,
          a.lng,
        ).compareTo(Geo.haversineKm(here.lat, here.lng, b.lat, b.lng)),
      );
    if (list.isEmpty) {
      showToast(context, 'No service providers listed yet.', success: false);
      return;
    }
    _plan(Place(list.first.name, list.first.lat, list.first.lng));
  }

  Future<void> _report(BuildContext anchor) async {
    final state = context.read<AppState>();
    final here = state.location;
    final nearest = [...state.stations]
      ..sort(
        (a, b) => Geo.haversineKm(
          here.lat,
          here.lng,
          a.lat,
          a.lng,
        ).compareTo(Geo.haversineKm(here.lat, here.lng, b.lat, b.lng)),
      );
    final picked = await pickOption<Station>(
      anchor,
      title: 'Report on which station?',
      options: nearest.take(6).toList(),
      label: (s) => s.name,
      subtitle: (s) =>
          '${s.city} · ${ChargingRules.condition(s, state.now).label.toLowerCase()}',
    );
    if (picked != null && mounted) {
      pushScreen(context, StationDetailScreen(stationId: picked.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final vehicle = state.me.vehicle;
    final now = state.now;
    final pad = MediaQuery.paddingOf(context);
    final destination = _destination;
    final options = _options;
    final option = options != null && _selected < options.length
        ? options[_selected]
        : null;

    // Battery or vehicle changed while a route is shown: plan again.
    if (destination != null &&
        !_navigating &&
        _planKey != _keyFor(state, destination)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _destination == destination) _plan(destination);
      });
    }

    final compatibleCount = vehicle == null
        ? 0
        : state.stations
              .where((s) => ChargingRules.compatible(vehicle, s))
              .length;
    final markers = <MapMarker>[
      for (final s in state.stations)
        if (!(option?.stops.any((x) => x.station.id == s.id) ?? false) &&
            (vehicle == null ||
                !_compatibleOnly ||
                ChargingRules.compatible(vehicle, s)))
          MapMarker(
            place: Place(s.name, s.lat, s.lng),
            kind: MarkerKind.station,
            tone: conditionTone(ChargingRules.condition(s, now)),
            dim: vehicle != null && !ChargingRules.compatible(vehicle, s),
            onTap: () =>
                pushScreen(context, StationDetailScreen(stationId: s.id)),
          ),
      for (final stop in option?.stops ?? const <ChargingStop>[])
        MapMarker(
          place: stop.place,
          kind: MarkerKind.stop,
          tone: Tone.pink,
          onTap: () => pushScreen(
            context,
            StationDetailScreen(stationId: stop.station.id),
          ),
        ),
      if (_origin != null && destination != null)
        MapMarker(
          place: _origin!,
          kind: MarkerKind.destination,
          tone: Tone.neutral,
        ),
      if (destination != null)
        MapMarker(
          place: destination,
          kind: MarkerKind.destination,
          tone: Tone.sky,
        ),
    ];

    // The panel changes height between states and animates while it does,
    // so measure it now and again once the animation has settled.
    WidgetsBinding.instance.addPostFrameCallback((_) => _measurePanel());
    Future.delayed(const Duration(milliseconds: 320), _measurePanel);
    final panelHeight = _panelHeight;

    return AnimatedBuilder(
      animation: _drive,
      builder: (context, _) {
        final t = _navigating ? _drive.value : null;
        return Stack(
          children: [
            Positioned.fill(
              child: EvMapView(
                key: _map,
                origin: state.location,
                markers: markers,
                routes: [
                  if (options != null)
                    for (final o in options) o.points,
                ],
                selectedRoute: _selected,
                progress: t,
                bottomInset: panelHeight + pad.bottom,
              ),
            ),

            // ── Top: floating controls, or the navigation banner
            Positioned(
              top: pad.top + 10,
              left: 14,
              right: 14,
              child: _navigating && option != null
                  ? _NavBanner(option: option, destination: destination!, t: t!)
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Column(
                          children: [
                            Builder(
                              builder: (anchor) => IconSquare(
                                icon: 'sliders',
                                label: 'Map options',
                                onTap: () => _openMenu(anchor),
                              ),
                            ),
                            const SizedBox(height: 10),
                            IconSquare(
                              icon: 'pin',
                              label: 'Back to my position',
                              onTap: () => _map.currentState?.recenter(),
                            ),
                          ],
                        ),
                        const Spacer(),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            if (vehicle != null)
                              _BatteryChip(
                                pct: state.batteryPct,
                                onTap: () => showAppSheet<void>(
                                  context,
                                  title: 'Battery level',
                                  builder: (_) => const _BatterySheet(),
                                ),
                              ),
                            const SizedBox(height: 10),
                            if (state.canParticipate)
                              Builder(
                                builder: (anchor) => Pressable(
                                  onTap: () => _report(anchor),
                                  label: 'Report a station\'s status',
                                  child: const Glass(
                                    radius: 18,
                                    blur: 14,
                                    tint: AppColors.pink,
                                    opacity: 0.82,
                                    child: SizedBox(
                                      width: 50,
                                      height: 50,
                                      child: Center(
                                        child: AppIcon(
                                          'alert',
                                          size: 22,
                                          color: AppColors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
            ),

            // ── Bottom: range, station count, and the panel
            Positioned(
              left: 12,
              right: 12,
              bottom: pad.bottom + 8,
              child: Column(
                key: _panelKey,
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // Hidden while navigating: the panel shows the live
                      // battery level there instead.
                      if (vehicle != null && !_navigating)
                        _RangeBubble(
                          km: ChargingRules.remainingRangeKm(
                            vehicle,
                            state.batteryPct,
                          ),
                        ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: Glass(
                            radius: 14,
                            blur: 12,
                            shadow: false,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            child: Text(
                              routeService.isEstimate
                                  ? 'Map preview · Google Maps not connected'
                                  : 'Google Maps',
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.inkSoft,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (destination == null) ...[
                    Glass(
                      radius: 26,
                      tint: AppColors.ink,
                      opacity: 0.8,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 13,
                      ),
                      child: Row(
                        children: [
                          const AppIcon(
                            'charging',
                            size: 18,
                            color: AppColors.sky,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              vehicle == null
                                  ? '${plural(state.stations.length, 'station')} around you'
                                  : '${plural(state.stations.length, 'station')} around you · $compatibleCount fit your connector',
                              style: const TextStyle(
                                color: AppColors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 13.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  Glass(
                    radius: 30,
                    opacity: 0.74,
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
                    child: AnimatedSize(
                      duration: AppMotion.of(context, AppMotion.slow),
                      curve: AppMotion.move,
                      alignment: Alignment.bottomCenter,
                      child: _navigating && option != null
                          ? _NavPanel(
                              option: option,
                              vehicle: vehicle,
                              startPct: state.batteryPct,
                              t: t!,
                              onEnd: _end,
                              destination: destination!,
                            )
                          : destination == null
                          ? _IdlePanel(
                              recent: _recent,
                              onSearch: _search,
                              onChargeNow: _chargeNow,
                              onStations: () => showAppSheet<void>(
                                context,
                                title: 'Charging stations',
                                builder: (_) => const StationsList(),
                              ),
                              onService: _nearestService,
                              onPick: _plan,
                            )
                          : _PreviewPanel(
                              origin: _origin,
                              onChangeOrigin: _pickOrigin,
                              destination: destination,
                              options: options,
                              selected: _selected,
                              vehicle: vehicle,
                              onSelect: (i) {
                                setState(() => _selected = i);
                                _fit();
                              },
                              onClose: _clear,
                              onStart: _start,
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _openMenu(BuildContext anchor) async {
    final hasVehicle = context.read<AppState>().me.vehicle != null;
    final picked = await showAppMenu<String>(anchor, [
      if (hasVehicle)
        AppMenuItem(
          'filter',
          _compatibleOnly ? 'Show all stations' : 'Compatible stations only',
          icon: 'charging',
        ),
      if (hasVehicle)
        const AppMenuItem('range', 'Round-trip range check', icon: 'battery'),
      if (hasVehicle)
        const AppMenuItem('trip', 'Trip check (list view)', icon: 'list'),
      const AppMenuItem('stations', 'Station list', icon: 'map'),
    ]);
    if (!mounted) return;
    switch (picked) {
      case 'filter':
        setState(() => _compatibleOnly = !_compatibleOnly);
      case 'range':
        pushScreen(context, const RangeCheckScreen());
      case 'trip':
        pushScreen(context, const TripCheckScreen());
      case 'stations':
        showAppSheet<void>(
          context,
          title: 'Charging stations',
          builder: (_) => const StationsList(),
        );
    }
  }
}

// ───────────────────────────── Floating pieces ─────────────────────────────

class _BatteryChip extends StatelessWidget {
  const _BatteryChip({required this.pct, required this.onTap});

  final double pct;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      label: 'Battery ${pct.round()} percent. Change battery level',
      child: Glass(
        radius: 18,
        blur: 14,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppIcon(
              'battery',
              size: 18,
              color: pct < 20 ? AppColors.danger : AppColors.ink,
            ),
            const SizedBox(width: 6),
            Text(
              '${pct.round()}%',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}

/// Remaining range in a round dial, where a navigation app shows speed.
class _RangeBubble extends StatelessWidget {
  const _RangeBubble({required this.km});

  final double km;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'About ${km.round()} kilometers of range',
      child: Glass(
        radius: 34,
        blur: 14,
        tint: AppColors.ink,
        opacity: 0.78,
        child: SizedBox(
          width: 68,
          height: 68,
          child: ExcludeSemantics(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedSwitcher(
                  duration: AppMotion.of(context, AppMotion.fast),
                  child: Text(
                    '${km.round()}',
                    key: ValueKey(km.round()),
                    style: const TextStyle(
                      color: AppColors.white,
                      fontSize: 20,
                      height: 1.05,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const Text(
                  'km range',
                  style: TextStyle(color: AppColors.sky, fontSize: 9.5),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BatterySheet extends StatelessWidget {
  const _BatterySheet();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final me = state.me;
    final v = me.vehicle!;
    final range = ChargingRules.remainingRangeKm(v, state.batteryPct);
    final usable = ChargingRules.remainingRangeKm(
      v,
      (state.batteryPct - me.reservePct).clamp(0, 100).toDouble(),
    );
    final small = Theme.of(context).textTheme.bodySmall;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(v.name, style: small),
        const SizedBox(height: 4),
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: '${state.batteryPct.round()}%',
                style: const TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w700,
                ),
              ),
              TextSpan(
                text:
                    '   about ${range.round()} km${v.hasEngine ? ' electric' : ''}',
                style: const TextStyle(fontSize: 15),
              ),
            ],
          ),
        ),
        // The thumb follows the finger directly; values update as it moves.
        Slider(
          value: state.batteryPct,
          min: 5,
          max: 100,
          divisions: 95,
          semanticFormatterCallback: (v) => '${v.round()} percent battery',
          onChanged: state.setBattery,
        ),
        Text(
          'Enter the level shown on your vehicle. Range is estimated from the battery size and rated energy use, and does not account for traffic or temperature.',
          style: small,
        ),
        const SizedBox(height: 18),
        FieldLabel(
          'Safety reserve: ${me.reservePct}% · plan with about ${usable.round()} km',
        ),
        Slider(
          value: me.reservePct.toDouble(),
          min: 0,
          max: 30,
          divisions: 6,
          semanticFormatterCallback: (v) => '${v.round()} percent reserve',
          onChanged: (v) => state.setChargingPrefs(reservePct: v.round()),
        ),
        Text(
          'Routes keep at least this much battery on reaching every stop and the destination.',
          style: small,
        ),
        const SizedBox(height: 18),
        FieldLabel('Charge to ${me.chargeToPct}% at each stop'),
        Slider(
          value: me.chargeToPct.toDouble(),
          min: 50,
          max: 100,
          divisions: 10,
          semanticFormatterCallback: (v) => 'Charge to ${v.round()} percent',
          onChanged: (v) => state.setChargingPrefs(chargeToPct: v.round()),
        ),
      ],
    );
  }
}

// ─────────────────────────────── Idle panel ───────────────────────────────

class _IdlePanel extends StatelessWidget {
  const _IdlePanel({
    required this.recent,
    required this.onSearch,
    required this.onChargeNow,
    required this.onStations,
    required this.onService,
    required this.onPick,
  });

  final List<Place> recent;
  final VoidCallback onSearch;
  final VoidCallback onChargeNow;
  final VoidCallback onStations;
  final VoidCallback onService;
  final ValueChanged<Place> onPick;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Center(child: _Handle()),
        Pressable(
          onTap: onSearch,
          label: 'Search for a destination',
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
            decoration: BoxDecoration(
              color: AppColors.white.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.white),
            ),
            child: const Row(
              children: [
                AppIcon('search', size: 20, color: AppColors.inkSoft),
                SizedBox(width: 12),
                Text(
                  'Where to?',
                  style: TextStyle(fontSize: 16, color: AppColors.inkSoft),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              flex: 6,
              child: _Shortcut(
                icon: 'charging',
                label: 'Charge now',
                onTap: onChargeNow,
                pink: true,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 5,
              child: _Shortcut(
                icon: 'list',
                label: 'Stations',
                onTap: onStations,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 5,
              child: _Shortcut(
                icon: 'wrench',
                label: 'Service',
                onTap: onService,
              ),
            ),
          ],
        ),
        for (final p in recent.take(2))
          Pressable(
            onTap: () => onPick(p),
            child: Padding(
              padding: const EdgeInsets.only(top: 12, left: 4),
              child: Row(
                children: [
                  const AppIcon('clock', size: 16, color: AppColors.inkSoft),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      p.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _Handle extends StatelessWidget {
  const _Handle();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 4,
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.ink.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}

class _Shortcut extends StatelessWidget {
  const _Shortcut({
    required this.icon,
    required this.label,
    required this.onTap,
    this.pink = false,
  });

  final String icon;
  final String label;
  final VoidCallback onTap;
  final bool pink;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 11),
        decoration: BoxDecoration(
          color: pink ? AppColors.pink : AppColors.white.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: pink ? AppColors.pink : AppColors.white),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AppIcon(
              icon,
              size: 16,
              color: pink ? AppColors.white : AppColors.skyDeep,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13.5,
                  color: pink ? AppColors.white : AppColors.ink,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Destination picker. It searches the preset places, stations and
/// providers; with Google Maps connected it would query Places instead.
class _DestinationSearch extends StatefulWidget {
  const _DestinationSearch({this.offerCurrentLocation = false});

  /// Adds "Your location" at the top, for choosing a starting point.
  final bool offerCurrentLocation;

  @override
  State<_DestinationSearch> createState() => _DestinationSearchState();
}

class _DestinationSearchState extends State<_DestinationSearch> {
  final _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    final here = state.location;
    final q = _query.text.trim().toLowerCase();
    final all = <(String icon, String kind, Place place)>[
      if (widget.offerCurrentLocation)
        ('route', 'Your location', state.location),
      for (final p in SeedData.places) ('pin', 'Place', p),
      for (final s in state.stations)
        (
          'charging',
          'Charging station · ${s.city}',
          Place(s.name, s.lat, s.lng),
        ),
      for (final p in state.directory)
        (
          'wrench',
          '${p.category.label} · ${p.city}',
          Place(p.name, p.lat, p.lng),
        ),
    ];
    final results = all
        .where(
          (r) =>
              q.isEmpty ||
              r.$3.name.toLowerCase().contains(q) ||
              r.$2.toLowerCase().contains(q),
        )
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _query,
          autofocus: true,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(
            hintText: 'Place, station or service provider',
            prefixIcon: Padding(
              padding: EdgeInsets.all(13),
              child: AppIcon('search', size: 18, color: AppColors.inkSoft),
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (results.isEmpty)
          const EmptyState(
            icon: 'search',
            title: 'Nothing matches',
            message: 'Only sample places are searchable until Google Maps is connected.',
          ),
        for (final r in results.take(30))
          Pressable(
            onTap: () => Navigator.of(context).pop(r.$3),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 9),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: AppColors.skySoft,
                      shape: BoxShape.circle,
                    ),
                    child: AppIcon(r.$1, size: 17, color: AppColors.skyDeep),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          r.$3.name,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          '${r.$2} · about ${km(Geo.roadKm(here.lat, here.lng, r.$3.lat, r.$3.lng))}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

// ────────────────────────────── Route preview ──────────────────────────────

class _PreviewPanel extends StatelessWidget {
  const _PreviewPanel({
    required this.origin,
    required this.onChangeOrigin,
    required this.destination,
    required this.options,
    required this.selected,
    required this.vehicle,
    required this.onSelect,
    required this.onClose,
    required this.onStart,
  });

  /// Chosen starting point; null means the user's current location.
  final Place? origin;
  final VoidCallback onChangeOrigin;
  final Place destination;
  final List<RouteOption>? options;
  final int selected;
  final Vehicle? vehicle;
  final ValueChanged<int> onSelect;
  final VoidCallback onClose;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final list = options;
    final option = list != null && selected < list.length
        ? list[selected]
        : null;
    // A plug-in hybrid can finish on its engine, so it may still start.
    final canStart =
        option != null && (option.feasible || (vehicle?.hasEngine ?? true));
    final firstFeasible = list?.indexWhere((o) => o.feasible) ?? -1;
    final text = Theme.of(context).textTheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Start and destination joined by a short line, like a route.
            const Padding(
              padding: EdgeInsets.only(top: 5),
              child: Column(
                children: [
                  _EndDot(filled: false),
                  SizedBox(
                    height: 20,
                    child: VerticalDivider(
                      width: 12,
                      thickness: 1.5,
                      color: AppColors.inkFaint,
                    ),
                  ),
                  _EndDot(filled: true),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Pressable(
                    onTap: onChangeOrigin,
                    label: 'Change starting point',
                    child: Row(
                      children: [
                        Flexible(
                          child: Text(
                            origin?.name ?? 'Your location',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
                              color: AppColors.inkSoft,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        const AppIcon(
                          'edit',
                          size: 13,
                          color: AppColors.pinkDeep,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 9),
                  Text(
                    destination.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.titleMedium,
                  ),
                ],
              ),
            ),
            Pressable(
              onTap: onClose,
              label: 'Clear route',
              child: Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.white.withValues(alpha: 0.8),
                  shape: BoxShape.circle,
                ),
                child: const AppIcon('close', size: 16),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (list == null)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 22),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    color: AppColors.skyDeep,
                  ),
                ),
                SizedBox(width: 12),
                Text('Finding routes'),
              ],
            ),
          )
        else ...[
          for (final (i, o) in list.indexed)
            FadeIn(
              key: ValueKey('${origin?.name}${destination.name}$i${o.label}'),
              index: i,
              child: _OptionTile(
                option: o,
                selected: i == selected,
                recommended: i == firstFeasible,
                onTap: () => onSelect(i),
              ),
            ),
          if (routeService.isEstimate)
            Padding(
              padding: const EdgeInsets.only(top: 2, bottom: 8),
              child: Text(
                'Distances and times are estimates until Google Maps is connected.',
                style: text.bodySmall?.copyWith(fontSize: 11.5),
              ),
            ),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  label: 'Start',
                  icon: 'route',
                  onTap: canStart ? onStart : null,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: AppButton(
                  label: 'Google Maps',
                  kind: AppButtonKind.soft,
                  onTap: () => openDirections(
                    context,
                    destination.lat,
                    destination.lng,
                    via: [
                      for (final s in option?.stops ?? const <ChargingStop>[])
                        s.place,
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _EndDot extends StatelessWidget {
  const _EndDot({required this.filled});

  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: filled ? AppColors.pink : AppColors.white,
        shape: BoxShape.circle,
        border: Border.all(
          color: filled ? AppColors.pink : AppColors.inkFaint,
          width: 2,
        ),
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.option,
    required this.selected,
    required this.recommended,
    required this.onTap,
  });

  final RouteOption option;
  final bool selected;
  final bool recommended;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final o = option;
    final arrival = o.batteryOnArrival;
    final small = Theme.of(context).textTheme.bodySmall;
    return Pressable(
      onTap: onTap,
      child: Semantics(
        selected: selected,
        child: AnimatedContainer(
          duration: AppMotion.of(context, AppMotion.fast),
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            color: AppColors.white.withValues(alpha: selected ? 0.95 : 0.6),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected ? AppColors.pink : AppColors.white,
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            o.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        if (recommended) ...[
                          const SizedBox(width: 6),
                          const Tag('Recommended', tone: Tone.pink),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [
                        minutes(o.minutes),
                        km(o.km),
                        if (o.stops.isNotEmpty)
                          'charging ${minutes(o.chargeMinutes)}',
                        if (o.detourKm >= 1) '+${km(o.detourKm)} detour',
                      ].join(' · '),
                      style: small,
                    ),
                    // With several stops the label only gives the count, so
                    // name them here with the level on reaching each.
                    if (o.stops.length > 1 || selected)
                      for (final s in o.stops)
                        Padding(
                          padding: const EdgeInsets.only(top: 3),
                          child: Row(
                            children: [
                              const AppIcon(
                                'charging',
                                size: 12,
                                color: AppColors.pinkDeep,
                              ),
                              const SizedBox(width: 5),
                              Flexible(
                                child: Text(
                                  '${s.station.name} · arrive ${s.arriveBattery.round()}%, charge to ${s.chargeToPct.round()}%',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: small?.copyWith(fontSize: 11.5),
                                ),
                              ),
                            ],
                          ),
                        ),
                    if (o.note != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Text(
                          o.note!,
                          style: TextStyle(
                            fontSize: 12,
                            color: o.feasible
                                ? AppColors.inkSoft
                                : AppColors.danger,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (arrival != null) ...[
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      // Rounded down, so a level just under the reserve
                      // never reads as the reserve itself.
                      '${arrival.floor()}%',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: o.feasible ? AppColors.ink : AppColors.danger,
                      ),
                    ),
                    const Text(
                      'on arrival',
                      style: TextStyle(
                        fontSize: 10.5,
                        color: AppColors.inkSoft,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────── Navigation ───────────────────────────────

/// Top banner in the navigation view. Real turn-by-turn steps come from the
/// routing service; until then it names the next point on the route.
class _NavBanner extends StatelessWidget {
  const _NavBanner({
    required this.option,
    required this.destination,
    required this.t,
  });

  final RouteOption option;
  final Place destination;
  final double t;

  @override
  Widget build(BuildContext context) {
    final next = option.nextAt(t);
    final stop = next.stop;
    final arrived = t >= 1;
    return Glass(
      radius: 24,
      tint: AppColors.ink,
      opacity: 0.82,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: AppColors.sky,
              shape: BoxShape.circle,
            ),
            child: AppIcon(
              arrived
                  ? 'check'
                  : stop != null
                  ? 'charging'
                  : 'arrow',
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  arrived
                      ? 'You have arrived'
                      : stop != null
                      ? 'Charging stop in ${km(next.km)}'
                      : '${km(next.km)} to go',
                  style: const TextStyle(
                    color: AppColors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  stop?.station.name ?? destination.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.white.withValues(alpha: 0.85),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Tag('Simulated', tone: Tone.warning),
        ],
      ),
    );
  }
}

class _NavPanel extends StatelessWidget {
  const _NavPanel({
    required this.option,
    required this.vehicle,
    required this.startPct,
    required this.t,
    required this.onEnd,
    required this.destination,
  });

  final RouteOption option;
  final Vehicle? vehicle;
  final double startPct;
  final double t;
  final VoidCallback onEnd;
  final Place destination;

  @override
  Widget build(BuildContext context) {
    final o = option;
    final battery = o.batteryAt(t, startPct);
    final remainingMin = o.minutes * (1 - t);
    final eta = DateTime.now().add(Duration(minutes: remainingMin.round()));
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Center(child: _Handle()),
        Row(
          children: [
            _NavFact(value: fmtTime(eta), label: 'arrival'),
            _NavFact(value: km(o.km * (1 - t)), label: 'remaining'),
            if (battery != null)
              _NavFact(
                value: '${battery.round()}%',
                label: 'battery',
                warn: battery < 15,
              ),
          ],
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: t,
            minHeight: 6,
            backgroundColor: AppColors.white.withValues(alpha: 0.7),
            color: AppColors.pink,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Simulated drive. Turn-by-turn directions need the Google Maps connection; use Google Maps for real navigation today.',
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(fontSize: 11.5),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: AppButton(
                label: 'End',
                kind: AppButtonKind.danger,
                onTap: onEnd,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: AppButton(
                label: 'Google Maps',
                kind: AppButtonKind.soft,
                onTap: () => openDirections(
                  context,
                  destination.lat,
                  destination.lng,
                  via: [for (final s in o.stops) s.place],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _NavFact extends StatelessWidget {
  const _NavFact({required this.value, required this.label, this.warn = false});

  final String value;
  final String label;
  final bool warn;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: warn ? AppColors.danger : AppColors.ink,
            ),
          ),
          Text(
            label,
            style: const TextStyle(fontSize: 11.5, color: AppColors.inkSoft),
          ),
        ],
      ),
    );
  }
}
