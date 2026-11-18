import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_motion.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/basics.dart';
import '../../core/widgets/overlays.dart';
import '../../data/models.dart';
import '../../data/seed_data.dart';
import '../../domain/charging_rules.dart';
import '../../state/app_state.dart';
import '../shared/shared_widgets.dart';

/// Opens Google Maps directions to a point. Navigation itself stays in
/// Google Maps, as the proposal specifies.
Future<void> openDirections(
  BuildContext context,
  double lat,
  double lng, {
  double? viaLat,
  double? viaLng,
  List<Place> via = const [],
}) async {
  final stops = [
    if (viaLat != null && viaLng != null) '$viaLat,$viaLng',
    for (final p in via) '${p.lat},${p.lng}',
  ];
  final waypoints = stops.isEmpty ? '' : '&waypoints=${stops.join('%7C')}';
  final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng$waypoints');
  final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!ok && context.mounted) {
    showToast(context, 'Could not open Google Maps.', success: false);
  }
}

/// M4: one station with its reference data, latest status report, the
/// community-reported queue and reviews.
class StationDetailScreen extends StatelessWidget {
  const StationDetailScreen({super.key, required this.stationId});

  final String stationId;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final s = state.stationById(stationId);
    if (s == null) {
      return const DetailScaffold(title: 'Station', children: [
        EmptyState(icon: 'charging', title: 'This station is not available'),
      ]);
    }
    final now = state.now;
    final vehicle = state.me.vehicle;
    final here = state.location;
    final condition = ChargingRules.condition(s, now);
    final latest = ChargingRules.latestReport(s);
    final active = ChargingRules.activeCheckIns(s, now)
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    final waiting = active.where((c) => !c.charging).toList();
    final charging = active.where((c) => c.charging).toList();
    final mine = state.myCheckIn(s);
    final option = vehicle == null
        ? null
        : ChargingRules.evaluate(
            vehicle, state.batteryPct, here.lat, here.lng, s, now);
    final text = Theme.of(context).textTheme;

    return DetailScaffold(
      title: 'Station',
      bottom: AppButton(
        label: 'Open navigation in Google Maps',
        icon: 'route',
        expand: true,
        onTap: () => openDirections(context, s.lat, s.lng),
      ),
      children: [
        Text(s.name, style: text.headlineMedium),
        const SizedBox(height: 4),
        Text('${s.operator} · ${s.address}', style: text.bodySmall),
        const SizedBox(height: 14),
        if (option != null) ...[
          AppCard(
            color: option.passes ? AppColors.skySoft : AppColors.warningSoft,
            border: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    AppIcon(option.passes ? 'check' : 'alert', size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        option.passes
                            ? 'Round trip is within your range'
                            : 'Round trip is beyond your range',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'About ${km(option.roadKm)} and ${minutes(option.minutes)} by road. '
                  'Needs about ${(option.roadKm * vehicle!.kwhPerKm).toStringAsFixed(1)} kWh one way. '
                  'Battery on arrival about ${option.batteryOnArrival.round()}%, after the round trip about ${option.batteryAfterRoundTrip.round()}%.',
                  style: const TextStyle(fontSize: 13),
                ),
                if (!ChargingRules.compatible(vehicle, s)) ...[
                  const SizedBox(height: 8),
                  const Tag('No connector matches your vehicle',
                      tone: Tone.danger, icon: 'alert'),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),
        ],
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Connectors', style: text.titleSmall),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final c in s.connectors)
                    Tag(
                      '${c.type.label} · ${c.powerKw.round()} kW',
                      tone: vehicle != null &&
                              vehicle.connectors.contains(c.type)
                          ? Tone.success
                          : Tone.neutral,
                      icon: 'charging',
                    ),
                ],
              ),
              const SizedBox(height: 12),
              InfoRow('wallet',
                  '${s.fee} · published fee collected ${fmtDate(s.feeDate)}'),
              InfoRow('clock', s.hours),
              InfoRow('car', '${s.parking} · for reference, not guaranteed on arrival'),
              InfoRow('database',
                  'Source: ${s.source}, ${fmtDate(s.sourceDate)}'),
            ],
          ),
        ),
        SectionHeader(
          'Status',
          action: state.canParticipate ? 'Report status' : null,
          onAction: () => _report(context, s),
        ),
        AppCard(
          child: AnimatedSwitcher(
            duration: AppMotion.of(context, AppMotion.standard),
            child: Column(
              key: ValueKey(latest?.createdAt),
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Tag(condition.label,
                    tone: conditionTone(condition),
                    icon: condition == StationCondition.working
                        ? 'check'
                        : condition == StationCondition.notWorking
                            ? 'alert'
                            : 'info'),
                const SizedBox(height: 8),
                Text(
                  latest == null
                      ? 'No one has reported on this station yet.'
                      : 'Latest report ${timeAgo(latest.createdAt)} by ${state.stationName(latest.userId)}: ${latest.working ? 'working' : 'not working'}.${latest.note.isEmpty ? '' : ' "${latest.note}"'}',
                  style: const TextStyle(fontSize: 13.5),
                ),
                if (s.reports.length > 1)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                        '${plural(s.reports.length, 'report')} in total',
                        style: text.bodySmall),
                  ),
              ],
            ),
          ),
        ),
        const SectionHeader('Queue'),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: _QueueCount(
                        value: charging.length, label: 'Charging now'),
                  ),
                  Expanded(
                    child: _QueueCount(
                        value: waiting.length, label: 'Waiting', pink: true),
                  ),
                ],
              ),
              if (active.isNotEmpty) ...[
                const SizedBox(height: 12),
                for (final c in active)
                  InfoRow(
                    c.charging ? 'charging' : 'clock',
                    '${state.stationName(c.userId)} checked in as ${c.charging ? 'charging' : 'waiting'} ${timeAgo(c.createdAt)}',
                  ),
              ],
              const SizedBox(height: 6),
              Text(
                'Reported by the community and may be incomplete. Check-ins expire after ${ChargingRules.checkInExpiry.inHours} hours.',
                style: text.bodySmall,
              ),
              if (state.canParticipate) ...[
                const SizedBox(height: 12),
                AnimatedSwitcher(
                  duration: AppMotion.of(context, AppMotion.standard),
                  child: mine == null
                      ? Row(
                          key: const ValueKey('in'),
                          children: [
                            Expanded(
                              child: AppButton(
                                label: 'I am waiting',
                                kind: AppButtonKind.soft,
                                small: true,
                                onTap: () {
                                  state.checkIn(s, charging: false);
                                  showToast(context, 'Checked in as waiting.');
                                },
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: AppButton(
                                label: 'I am charging',
                                kind: AppButtonKind.sky,
                                small: true,
                                onTap: () {
                                  state.checkIn(s, charging: true);
                                  showToast(context, 'Checked in as charging.');
                                },
                              ),
                            ),
                          ],
                        )
                      : Row(
                          key: const ValueKey('out'),
                          children: [
                            if (!mine.charging) ...[
                              Expanded(
                                child: AppButton(
                                  label: 'Now charging',
                                  kind: AppButtonKind.sky,
                                  small: true,
                                  onTap: () =>
                                      state.checkIn(s, charging: true),
                                ),
                              ),
                              const SizedBox(width: 10),
                            ],
                            Expanded(
                              child: AppButton(
                                label: 'Check out',
                                small: true,
                                onTap: () {
                                  state.checkOut(s);
                                  showToast(context, 'Checked out.');
                                },
                              ),
                            ),
                          ],
                        ),
                ),
              ],
            ],
          ),
        ),
        ReviewSection(
          target: ReviewTarget.station,
          targetId: s.id,
          tags: SeedData.stationTags,
        ),
      ],
    );
  }

  void _report(BuildContext context, Station s) {
    showAppSheet<void>(
      context,
      title: 'Report station status',
      builder: (_) => _StatusForm(
        onSubmit: (working, note) {
          context.read<AppState>().reportStatus(s, working: working, note: note);
          showToast(context, 'Status report posted with the current time.');
        },
      ),
    );
  }
}

class _QueueCount extends StatelessWidget {
  const _QueueCount({
    required this.value,
    required this.label,
    this.pink = false,
  });

  final int value;
  final String label;
  final bool pink;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedSwitcher(
          duration: AppMotion.of(context, AppMotion.standard),
          child: Text(
            '$value',
            key: ValueKey(value),
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: pink ? AppColors.pinkDeep : AppColors.ink,
            ),
          ),
        ),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _StatusForm extends StatefulWidget {
  const _StatusForm({required this.onSubmit});

  final void Function(bool working, String note) onSubmit;

  @override
  State<_StatusForm> createState() => _StatusFormState();
}

class _StatusFormState extends State<_StatusForm> {
  bool? _working;
  final _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const FieldLabel('Is the charger working right now?'),
        Row(
          children: [
            ChoicePill(
              label: 'Working',
              selected: _working == true,
              onTap: () => setState(() => _working = true),
            ),
            const SizedBox(width: 8),
            ChoicePill(
              label: 'Not working',
              selected: _working == false,
              onTap: () => setState(() => _working = false),
            ),
          ],
        ),
        const SizedBox(height: 16),
        AppField(
          controller: _note,
          label: 'Note (optional)',
          hint: 'Which unit, what you saw',
          maxLines: 3,
        ),
        AppButton(
          label: 'Post report',
          expand: true,
          onTap: _working == null
              ? null
              : () {
                  Navigator.of(context).pop();
                  widget.onSubmit(_working!, _note.text.trim());
                },
        ),
      ],
    );
  }
}
