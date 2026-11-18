import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_motion.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/basics.dart';
import '../../data/models.dart';
import '../../domain/charging_rules.dart';
import '../../state/app_state.dart';
import '../charging/station_detail_screen.dart';
import '../shared/shared_widgets.dart';

/// M4: compatible stations within range, ranked by latest status report,
/// queue and travel time, with the first one marked as recommended. Shown
/// from the Route tab.
class StationsList extends StatefulWidget {
  const StationsList({super.key});

  @override
  State<StationsList> createState() => _StationsListState();
}

class _StationsListState extends State<StationsList> {
  bool _all = false;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final vehicle = state.me.vehicle;
    final rec = state.recommendation;
    final now = state.now;
    final here = state.location;

    final allStations = [...state.stations]
      ..sort(
        (a, b) => Geo.haversineKm(
          here.lat,
          here.lng,
          a.lat,
          a.lng,
        ).compareTo(Geo.haversineKm(here.lat, here.lng, b.lat, b.lng)),
      );
    final showAll = _all || vehicle == null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (vehicle == null)
          const NoticeBox(
            'Add a vehicle in Profile to get compatible stations ranked for your connector and remaining range.',
            icon: 'car',
          )
        else
          PillRow(
            labels: const ['Recommended', 'All stations'],
            index: _all ? 1 : 0,
            padding: EdgeInsets.zero,
            onChanged: (i) => setState(() => _all = i == 1),
          ),
        const SizedBox(height: 12),
        Swap(
          id: showAll,
          child: showAll
              ? Column(
                  children: [
                    for (final (i, s) in allStations.indexed)
                      FadeIn(
                        index: i,
                        child: _StationCard(
                          station: s,
                          option: vehicle == null
                              ? null
                              : ChargingRules.evaluate(
                                  vehicle,
                                  state.batteryPct,
                                  here.lat,
                                  here.lng,
                                  s,
                                  now,
                                ),
                          compatible: vehicle == null
                              ? null
                              : ChargingRules.compatible(vehicle, s),
                        ),
                      ),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (rec!.options.isEmpty && rec.fallback == null)
                      const EmptyState(
                        icon: 'alert',
                        title: 'No compatible station within range',
                        message: 'Nothing with your connector can be reached at this battery level.',
                      ),
                    if (rec.fallback != null) ...[
                      const NoticeBox(
                        'No station passes the round-trip check. This is the nearest compatible station you can reach one way.',
                        tone: Tone.warning,
                        icon: 'alert',
                      ),
                      const SizedBox(height: 12),
                      _StationCard(
                        station: rec.fallback!.station,
                        option: rec.fallback,
                        compatible: true,
                      ),
                    ],
                    for (final (i, o) in rec.options.indexed)
                      FadeIn(
                        key: ValueKey(o.station.id),
                        index: i,
                        child: _StationCard(
                          station: o.station,
                          option: o,
                          compatible: true,
                          recommended: i == 0,
                        ),
                      ),
                    if (rec.options.isNotEmpty)
                      Text(
                        'Ranked by latest status report, queue, then travel time. Distances and times are estimates, a guide and not a guarantee.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _StationCard extends StatelessWidget {
  const _StationCard({
    required this.station,
    required this.option,
    required this.compatible,
    this.recommended = false,
  });

  final Station station;
  final StationOption? option;

  /// Whether the user's vehicle can plug in here; null without a vehicle.
  final bool? compatible;
  final bool recommended;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final s = station;
    final now = state.now;
    final condition = ChargingRules.condition(s, now);
    final latest = ChargingRules.latestReport(s);
    final waiting = ChargingRules.waitingCount(s, now);
    final o = option;
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        color: recommended ? AppColors.skyMist : AppColors.white,
        onTap: () => pushScreen(context, StationDetailScreen(stationId: s.id)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (recommended)
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Tag('Recommended', tone: Tone.pink, icon: 'star'),
              ),
            Row(
              children: [
                Expanded(child: Text(s.name, style: text.titleSmall)),
                const AppIcon('chevron', size: 16, color: AppColors.inkFaint),
              ],
            ),
            const SizedBox(height: 2),
            Text('${s.operator} · ${s.city}', style: text.bodySmall),
            const SizedBox(height: 10),
            if (o != null)
              Row(
                children: [
                  _Fact(km(o.roadKm), 'by road'),
                  _Fact(minutes(o.minutes), 'travel'),
                  _Fact(
                    '${o.batteryAfterRoundTrip.round()}%',
                    'after return',
                    warn: !o.passes,
                  ),
                  _Fact('${s.maxPowerKw.round()} kW', 'max power'),
                ],
              ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                Tag(
                  latest == null
                      ? condition.label
                      : '${condition == StationCondition.unknown ? 'Last report' : condition.label} · ${timeAgo(latest.createdAt)}',
                  tone: conditionTone(condition),
                ),
                Tag(
                  waiting == 0 ? 'No queue reported' : '$waiting waiting',
                  tone: waiting == 0 ? Tone.neutral : Tone.warning,
                ),
                if (compatible == false)
                  const Tag('No matching connector', tone: Tone.danger),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact(this.value, this.label, {this.warn = false});

  final String value;
  final String label;
  final bool warn;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AnimatedSwitcher(
            duration: AppMotion.of(context, AppMotion.fast),
            child: Text(
              value,
              key: ValueKey(value),
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: warn ? AppColors.danger : AppColors.ink,
              ),
            ),
          ),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: AppColors.inkSoft),
          ),
        ],
      ),
    );
  }
}
