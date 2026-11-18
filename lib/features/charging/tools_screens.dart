import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_motion.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/basics.dart';
import '../../core/widgets/overlays.dart';
import '../../data/models.dart';
import '../../data/seed_data.dart';
import '../../domain/charging_rules.dart';
import '../../domain/community_rules.dart';
import '../../state/app_state.dart';
import '../shared/shared_widgets.dart';
import 'station_detail_screen.dart';

/// All destinations the tools can check: preset places, stations, providers.
List<Place> _destinations(AppState state) => [
      ...SeedData.places,
      for (final s in state.stations) Place(s.name, s.lat, s.lng),
      for (final p in state.directory) Place(p.name, p.lat, p.lng),
    ];

class _DestinationField extends StatelessWidget {
  const _DestinationField({required this.value, required this.onPicked});

  final Place? value;
  final ValueChanged<Place> onPicked;

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    return Pressable(
      onTap: () async {
        final picked = await pickOption<Place>(
          context,
          title: 'Destination',
          options: _destinations(state),
          label: (p) => p.name,
          subtitle: (p) =>
              'About ${km(Geo.roadKm(state.location.lat, state.location.lng, p.lat, p.lng))} by road',
          selected: value,
        );
        if (picked != null) onPicked(picked);
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.skyMist,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.line),
        ),
        child: Row(
          children: [
            const AppIcon('pin', size: 18, color: AppColors.inkSoft),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                value?.name ?? 'Choose a destination',
                style: TextStyle(
                    color: value == null ? AppColors.inkFaint : AppColors.ink),
              ),
            ),
            const AppIcon('chevron', size: 16, color: AppColors.inkFaint),
          ],
        ),
      ),
    );
  }
}

/// Line that states where the trip starts and with what charge.
class _StartLine extends StatelessWidget {
  const _StartLine();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final v = state.me.vehicle!;
    return InfoRow(
      'battery',
      'From ${state.location.name} with ${v.name} at ${state.batteryPct.round()}% '
          '(about ${ChargingRules.remainingRangeKm(v, state.batteryPct).round()} km${v.hasEngine ? ' electric' : ''}). '
          'Change the battery level on the Charging tab.',
    );
  }
}

const _estimateNote =
    'Road distance is estimated and the check does not account for traffic or temperature. Treat it as a guide, not a guarantee.';

/// Compares the remaining range with the road distance there and back.
class RangeCheckScreen extends StatefulWidget {
  const RangeCheckScreen({super.key});

  @override
  State<RangeCheckScreen> createState() => _RangeCheckScreenState();
}

class _RangeCheckScreenState extends State<RangeCheckScreen> {
  Place? _dest;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final v = state.me.vehicle!;
    final dest = _dest;
    final check = dest == null
        ? null
        : ChargingRules.roundTrip(
            vehicle: v,
            batteryPct: state.batteryPct,
            lat: state.location.lat,
            lng: state.location.lng,
            destLat: dest.lat,
            destLng: dest.lng,
          );
    return DetailScaffold(
      title: 'Round-trip range check',
      children: [
        const _StartLine(),
        const SizedBox(height: 12),
        _DestinationField(
            value: _dest, onPicked: (p) => setState(() => _dest = p)),
        const SizedBox(height: 16),
        Swap(
          id: '${dest?.name}${check?.passes}',
          child: check == null
              ? const EmptyState(
                  icon: 'battery',
                  title: 'Choose where you are going',
                  message:
                      'The check compares your remaining range with the road distance to the destination and back.',
                )
              : AppCard(
                  color: check.passes
                      ? AppColors.successSoft
                      : AppColors.dangerSoft,
                  border: false,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          AppIcon(check.passes ? 'check' : 'alert',
                              color: check.passes
                                  ? AppColors.success
                                  : AppColors.danger),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              check.passes
                                  ? 'You can get there and back'
                                  : v.hasEngine
                                      ? 'Not on electricity alone'
                                      : 'Not enough range for the round trip',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      InfoRow('route',
                          '${km(check.roadKm)} each way, ${km(check.roadKm * 2)} round trip',
                          color: AppColors.ink),
                      InfoRow('battery',
                          'Remaining range about ${km(check.rangeKm)}',
                          color: AppColors.ink),
                      InfoRow(
                          'charging',
                          'Battery about ${check.batteryOnArrival.round()}% on arrival and ${check.batteryAfterRoundTrip.round()}% after the round trip',
                          color: AppColors.ink),
                      if (!check.passes && v.hasEngine)
                        const InfoRow('info',
                            'Your vehicle\'s engine can extend the range beyond the electric-only figure.',
                            color: AppColors.ink),
                    ],
                  ),
                ),
        ),
        const SizedBox(height: 14),
        Text(_estimateNote, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

/// Checks a trip and suggests at most one charging stop near the route.
class TripCheckScreen extends StatefulWidget {
  const TripCheckScreen({super.key});

  @override
  State<TripCheckScreen> createState() => _TripCheckScreenState();
}

class _TripCheckScreenState extends State<TripCheckScreen> {
  Place? _dest;
  double _chargeTo = 80;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final v = state.me.vehicle!;
    final here = state.location;
    final dest = _dest;
    final plan = dest == null
        ? null
        : ChargingRules.planTrip(
            vehicle: v,
            batteryPct: state.batteryPct,
            lat: here.lat,
            lng: here.lng,
            destination: dest,
            stations: state.stations,
            now: state.now,
            chargeToPct: _chargeTo,
          );
    final stop = plan?.stop;
    final text = Theme.of(context).textTheme;

    return DetailScaffold(
      title: 'Trip check',
      bottom: plan == null || plan.result == TripResult.notFeasible
          ? null
          : AppButton(
              label: stop == null
                  ? 'Open navigation in Google Maps'
                  : 'Open navigation with the stop',
              icon: 'route',
              expand: true,
              onTap: () => openDirections(context, dest!.lat, dest.lng,
                  viaLat: stop?.lat, viaLng: stop?.lng),
            ),
      children: [
        const _StartLine(),
        const SizedBox(height: 12),
        _DestinationField(
            value: _dest, onPicked: (p) => setState(() => _dest = p)),
        const SizedBox(height: 14),
        FieldLabel('Charge to ${_chargeTo.round()}% at the stop'),
        Slider(
          value: _chargeTo,
          min: 50,
          max: 100,
          divisions: 10,
          onChanged: (x) => setState(() => _chargeTo = x),
        ),
        const SizedBox(height: 6),
        Swap(
          id: '${dest?.name}${plan?.result}${stop?.id}',
          child: plan == null
              ? const EmptyState(
                  icon: 'route',
                  title: 'Choose a destination',
                  message:
                      'If the trip is beyond your range, one compatible charging stop within 2 km of the route is suggested.',
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppCard(
                      color: switch (plan.result) {
                        TripResult.direct => AppColors.successSoft,
                        TripResult.withStop => AppColors.skySoft,
                        TripResult.notFeasible => AppColors.dangerSoft,
                      },
                      border: false,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            switch (plan.result) {
                              TripResult.direct =>
                                'Feasible without charging',
                              TripResult.withStop =>
                                'Feasible with one charging stop',
                              TripResult.notFeasible =>
                                'Not feasible with one stop',
                            },
                            style: text.titleMedium,
                          ),
                          const SizedBox(height: 10),
                          InfoRow(
                              'route',
                              'About ${km(plan.roadKm)} by road; your range is about ${km(plan.rangeKm)}',
                              color: AppColors.ink),
                          if (plan.result == TripResult.direct)
                            InfoRow('battery',
                                'About ${plan.batteryOnArrival.round()}% left on arrival',
                                color: AppColors.ink),
                          if (plan.result == TripResult.notFeasible)
                            InfoRow(
                                'info',
                                v.hasEngine
                                    ? 'No single stop near the route covers it on electricity; your engine can extend the range.'
                                    : 'No compatible station within 2 km of the route can be reached and still get you to the destination. EVYAHE plans one stop at most.',
                                color: AppColors.ink),
                        ],
                      ),
                    ),
                    if (stop != null) ...[
                      const SizedBox(height: 14),
                      AppCard(
                        onTap: () => pushScreen(
                            context, StationDetailScreen(stationId: stop.id)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Tag('Suggested charging stop',
                                tone: Tone.pink, icon: 'charging'),
                            const SizedBox(height: 10),
                            RouteStrip(
                                from: here.name,
                                to: dest!.name,
                                via: stop.city),
                            const SizedBox(height: 12),
                            Text(stop.name, style: text.titleSmall),
                            InfoRow('route',
                                '${km(plan.kmToStop)} to the stop, arriving at about ${plan.batteryAtStop.round()}%'),
                            InfoRow('charging',
                                'Charge to ${_chargeTo.round()}%, then ${km(plan.kmFromStop)} to the destination, arriving at about ${plan.batteryAtDestination.round()}%'),
                            InfoRow('info',
                                ChargingRules.condition(stop, state.now).label),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      StationMap(
                        height: 160,
                        me: here,
                        route: [
                          here,
                          Place(stop.name, stop.lat, stop.lng),
                          dest,
                        ],
                        pins: [
                          MapPin(
                              lat: stop.lat,
                              lng: stop.lng,
                              label: stop.name,
                              tone: Tone.pink),
                          MapPin(lat: dest.lat, lng: dest.lng, label: dest.name),
                        ],
                      ),
                    ],
                  ],
                ),
        ),
        const SizedBox(height: 14),
        Text(_estimateNote, style: text.bodySmall),
      ],
    );
  }
}

/// Monthly cost of home charging, public charging and fuel.
class CostComparisonScreen extends StatefulWidget {
  const CostComparisonScreen({super.key});

  @override
  State<CostComparisonScreen> createState() => _CostComparisonScreenState();
}

class _CostComparisonScreenState extends State<CostComparisonScreen> {
  double _monthlyKm = 1000;
  double _share = 60;
  final _home = TextEditingController(text: '15.55');
  final _public = TextEditingController(text: '35.00');
  final _fuel = TextEditingController(text: '60.00');
  final _kmPerLiter = TextEditingController(text: '12');

  @override
  void dispose() {
    for (final c in [_home, _public, _fuel, _kmPerLiter]) {
      c.dispose();
    }
    super.dispose();
  }

  double _num(TextEditingController c, double fallback) {
    final v = double.tryParse(c.text.trim());
    return v == null || v <= 0 ? fallback : v;
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final v = state.me.vehicle;
    final kwhPerKm = v?.kwhPerKm ?? 0.16;
    final hybrid = v?.hasEngine ?? false;
    final result = CostRules.compare(
      monthlyKm: _monthlyKm,
      kwhPerKm: kwhPerKm,
      homeRate: _num(_home, 15.55),
      publicRate: _num(_public, 35),
      fuelPrice: _num(_fuel, 60),
      fuelKmPerLiter: _num(_kmPerLiter, 12),
      electricShare: hybrid ? _share / 100 : 1,
    );
    final rows = [
      ('Home charging', result.home),
      ('Public charging', result.public),
      ('Fuel only', result.fuel),
    ];
    final cheapest = rows.indexWhere((r) =>
        r.$2 == rows.map((x) => x.$2).reduce((a, b) => a < b ? a : b));
    final text = Theme.of(context).textTheme;

    return DetailScaffold(
      title: 'Cost comparison',
      children: [
        InfoRow(
          'car',
          v == null
              ? 'No vehicle on your profile; using a typical ${kwhPerKm.toStringAsFixed(2)} kWh per km.'
              : '${v.name} · rated ${v.kwhPerKm.toStringAsFixed(3)} kWh per km${hybrid ? ' on electricity' : ''}',
        ),
        const SizedBox(height: 10),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Estimated cost per month', style: text.titleSmall),
              const SizedBox(height: 10),
              for (final (i, r) in rows.indexed)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(child: Text(r.$1)),
                          if (i == cheapest) ...[
                            const Tag('Lowest', tone: Tone.success),
                            const SizedBox(width: 8),
                          ],
                          Text(peso(r.$2),
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700, fontSize: 16)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          height: 9,
                          color: AppColors.skySoft,
                          alignment: Alignment.centerLeft,
                          child: AnimatedFractionallySizedBox(
                            duration: AppMotion.of(context, AppMotion.fast),
                            curve: AppMotion.move,
                            widthFactor: (r.$2 /
                                    rows
                                        .map((x) => x.$2)
                                        .reduce((a, b) => a > b ? a : b))
                                .clamp(0.02, 1.0)
                                .toDouble(),
                            heightFactor: 1,
                            child: Container(
                              color:
                                  i == 2 ? AppColors.pink : AppColors.sky,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '₱${(r.$2 / _monthlyKm).toStringAsFixed(2)} per km',
                        style: text.bodySmall,
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        FieldLabel('Distance driven: ${_monthlyKm.round()} km per month'),
        Slider(
          value: _monthlyKm,
          min: 200,
          max: 3000,
          divisions: 28,
          onChanged: (x) => setState(() => _monthlyKm = x),
        ),
        if (hybrid) ...[
          FieldLabel('Electric share: ${_share.round()}% of distance'),
          Slider(
            value: _share,
            min: 0,
            max: 100,
            divisions: 20,
            onChanged: (x) => setState(() => _share = x),
          ),
          Text(
            'For PHEV and REEV, the rest of the distance burns fuel at the engine\'s rate below.',
            style: text.bodySmall,
          ),
          const SizedBox(height: 10),
        ],
        Row(
          children: [
            Expanded(
              child: AppField(
                controller: _home,
                label: 'Home rate, ₱ per kWh',
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: AppField(
                controller: _public,
                label: 'Public rate, ₱ per kWh',
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                onChanged: (_) => setState(() {}),
              ),
            ),
          ],
        ),
        Row(
          children: [
            Expanded(
              child: AppField(
                controller: _fuel,
                label: 'Fuel price, ₱ per liter',
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: AppField(
                controller: _kmPerLiter,
                label: 'Fuel economy, km per liter',
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                onChanged: (_) => setState(() {}),
              ),
            ),
          ],
        ),
        const NoticeBox(
          'Defaults are sample values. Enter the rate on your own electricity bill and the fuel price you pay. Results are estimates.',
        ),
      ],
    );
  }
}
