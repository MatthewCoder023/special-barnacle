import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_motion.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/basics.dart';
import '../../core/widgets/overlays.dart';
import '../../data/models.dart';
import '../../domain/charging_rules.dart';
import '../../domain/community_rules.dart';
import '../../state/app_state.dart';
import '../shared/shared_widgets.dart';

/// M3: event details, RSVP with vehicle and battery level, and the route
/// check for convoys and drives.
class EventDetailScreen extends StatelessWidget {
  const EventDetailScreen({super.key, required this.eventId});

  final String eventId;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final e = state.events.where((x) => x.id == eventId).firstOrNull;
    if (e == null || !state.canSee(e)) {
      return const DetailScaffold(title: 'Event', children: [
        EmptyState(icon: 'events', title: 'This event is not available'),
      ]);
    }
    final group = state.communityById(e.communityId);
    final manage = state.canManageEvent(e);
    final mine = state.myRsvp(e);
    final stop = state.stationById(e.stopStationId);
    final route = EventRoute.of(e, stop);
    final full = e.rsvps.length >= e.capacity;
    final past = e.start.isBefore(state.now);
    final text = Theme.of(context).textTheme;

    Widget? bottom;
    if (!e.cancelled && !past) {
      if (mine != null) {
        bottom = Row(
          children: [
            Expanded(
              child: AppButton(
                label: 'Cancel RSVP',
                kind: AppButtonKind.soft,
                onTap: () {
                  state.cancelRsvp(e);
                  showToast(context, 'RSVP cancelled.', success: false);
                },
              ),
            ),
            if (e.type.hasRoute) ...[
              const SizedBox(width: 10),
              Expanded(
                child: AppButton(
                  label: 'Edit battery',
                  onTap: () => _openRsvp(context, e, mine.startBatteryPct),
                ),
              ),
            ],
          ],
        );
      } else if (state.canParticipate) {
        bottom = AppButton(
          label: full ? 'Event is full' : 'RSVP',
          expand: true,
          onTap: full ? null : () => _openRsvp(context, e, 80),
        );
      }
    }

    return DetailScaffold(
      title: 'Event',
      actions: [
        if (manage && !e.cancelled && !past)
          MenuButton<String>(
            items: const [
              AppMenuItem('cancel', 'Cancel event',
                  icon: 'close', danger: true),
            ],
            onSelected: (_) async {
              final ok = await confirmAction(
                context,
                title: 'Cancel this event?',
                message:
                    'Everyone who RSVPed is notified. This cannot be undone.',
                confirmLabel: 'Cancel event',
                danger: true,
              );
              if (ok && context.mounted) {
                state.cancelEvent(e);
                showToast(context, 'Event cancelled. Attendees were notified.',
                    success: false);
              }
            },
          ),
      ],
      bottom: bottom,
      children: [
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            Tag(e.type.label, tone: Tone.pink),
            Tag(e.visibility.label, tone: Tone.neutral),
            if (e.cancelled) const Tag('Cancelled', tone: Tone.danger),
            if (mine != null && !e.cancelled)
              const Tag('You are going', tone: Tone.success, icon: 'check'),
          ],
        ),
        const SizedBox(height: 10),
        Text(e.title, style: text.headlineMedium),
        const SizedBox(height: 4),
        Text('Hosted by ${group?.name ?? ''}', style: text.bodySmall),
        const SizedBox(height: 14),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InfoRow('events', fmtDateTime(e.start), color: AppColors.ink),
              InfoRow('pin', e.venue.name, color: AppColors.ink),
              InfoRow('community',
                  '${e.rsvps.length} of ${e.capacity} places taken',
                  color: AppColors.ink),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Text(e.description, style: const TextStyle(color: AppColors.inkSoft)),
        if (!state.canParticipate && !e.cancelled) ...[
          const SizedBox(height: 14),
          NoticeBox(
            state.isGuest
                ? 'Guests can view events. Register as a member to RSVP.'
                : 'RSVPs are for members.',
            icon: 'lock',
          ),
        ],
        if (route != null) ...[
          const SectionHeader('Route'),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RouteStrip(
                  from: e.origin!.name,
                  to: e.venue.name,
                  via: stop?.city,
                ),
                const SizedBox(height: 12),
                StationMap(
                  height: 150,
                  me: e.origin!,
                  route: [
                    e.origin!,
                    if (stop != null) Place(stop.name, stop.lat, stop.lng),
                    e.venue,
                  ],
                  pins: [
                    if (stop != null)
                      MapPin(
                          lat: stop.lat,
                          lng: stop.lng,
                          label: stop.name,
                          tone: Tone.pink),
                    MapPin(
                        lat: e.venue.lat,
                        lng: e.venue.lng,
                        label: e.venue.name),
                  ],
                ),
                const SizedBox(height: 12),
                InfoRow(
                  'route',
                  stop == null
                      ? 'About ${km(route.totalKm)} by road, no charging stop planned'
                      : 'About ${km(route.kmToStop)} to the stop, then ${km(route.kmFromStop)} to the destination',
                ),
                if (stop != null)
                  InfoRow('charging',
                      'Charging stop: ${stop.name} (${stop.connectors.map((c) => '${c.type.label} ${c.powerKw.round()} kW').join(', ')})'),
                Text(
                  'Distances are estimates. Results guide planning and are not a guarantee.',
                  style: text.bodySmall,
                ),
                if (manage && !e.cancelled) ...[
                  const SizedBox(height: 12),
                  Builder(
                    builder: (anchor) => AppButton(
                      label: stop == null
                          ? 'Choose a charging stop'
                          : 'Change charging stop',
                      icon: 'charging',
                      kind: AppButtonKind.sky,
                      small: true,
                      onTap: () => _chooseStop(anchor, e),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (mine != null && !e.cancelled) ...[
            const SectionHeader('Your route check'),
            _CheckRow(check: EventRules.check(mine, route), showName: false),
          ],
        ],
        if (manage) ...[
          SectionHeader(
              'Attendees · ${plural(e.rsvps.length, 'RSVP')}'),
          if (e.rsvps.isEmpty)
            const EmptyState(icon: 'community', title: 'No RSVPs yet'),
          if (route != null && e.rsvps.isNotEmpty)
            _RouteSummary(event: e, route: route),
          for (final (i, r) in e.rsvps.indexed)
            FadeIn(
              key: ValueKey(r.userId),
              index: i,
              child: route != null
                  ? _CheckRow(check: EventRules.check(r, route), showName: true)
                  : _AttendeeRow(rsvp: r),
            ),
        ],
      ],
    );
  }

  void _openRsvp(BuildContext context, CommunityEvent e, double initial) {
    showAppSheet<void>(
      context,
      title: 'RSVP',
      builder: (_) => _RsvpForm(
        event: e,
        initial: initial,
        onDone: () => showToast(context, 'You are going to ${e.title}.'),
      ),
    );
  }

  /// Leaders choose the one planned stop from stations near the route.
  Future<void> _chooseStop(BuildContext context, CommunityEvent e) async {
    final state = context.read<AppState>();
    final origin = e.origin!;
    final near = state.stations.where((s) {
      final off = Geo.distanceToSegmentKm(
          s.lat, s.lng, origin.lat, origin.lng, e.venue.lat, e.venue.lng);
      return off <= 12;
    }).toList()
      ..sort((a, b) => Geo.haversineKm(origin.lat, origin.lng, a.lat, a.lng)
          .compareTo(Geo.haversineKm(origin.lat, origin.lng, b.lat, b.lng)));
    final none = Station(
      id: '',
      name: 'No charging stop',
      operator: '',
      address: '',
      city: 'Drive straight to the destination',
      lat: 0,
      lng: 0,
      connectors: const [],
      fee: '',
      feeDate: state.now,
      hours: '',
      parking: '',
      source: '',
      sourceDate: state.now,
    );
    final picked = await pickOption<Station>(
      context,
      title: 'Planned charging stop',
      options: [none, ...near],
      label: (s) => s.name,
      subtitle: (s) => s.id.isEmpty
          ? s.city
          : '${s.city} · ${s.connectors.map((c) => c.type.label).toSet().join(', ')} · ${ChargingRules.condition(s, state.now).label.toLowerCase()}',
      selected: state.stationById(e.stopStationId),
    );
    if (picked == null) return;
    state.setEventStop(e, picked.id.isEmpty ? null : picked.id);
  }
}

/// Counts of the route check results, for the leader.
class _RouteSummary extends StatelessWidget {
  const _RouteSummary({required this.event, required this.route});

  final CommunityEvent event;
  final EventRoute route;

  @override
  Widget build(BuildContext context) {
    final checks = [for (final r in event.rsvps) EventRules.check(r, route)];
    final flagged =
        checks.where((c) => c.result == Feasibility.flagged).length;
    final engine = checks.where((c) => c.result == Feasibility.engine).length;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AnimatedSwitcher(
        duration: AppMotion.of(context, AppMotion.standard),
        child: NoticeBox(
          key: ValueKey('$flagged$engine${route.stop?.id}'),
          flagged == 0
              ? 'Route check: every attending vehicle can make the trip${engine > 0 ? ', ${plural(engine, 'plug-in hybrid')} partly on engine' : ''}.'
              : 'Route check: ${plural(flagged, 'vehicle')} may not reach the ${route.stop == null ? 'destination' : 'stop or destination'}. Consider a different charging stop.',
          tone: flagged == 0 ? Tone.success : Tone.danger,
          icon: flagged == 0 ? 'check' : 'alert',
        ),
      ),
    );
  }
}

class _CheckRow extends StatelessWidget {
  const _CheckRow({required this.check, required this.showName});

  final AttendeeCheck check;
  final bool showName;

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    final r = check.rsvp;
    final user = state.userById(r.userId);
    final tone = switch (check.result) {
      Feasibility.ok => Tone.success,
      Feasibility.engine => Tone.warning,
      Feasibility.flagged => Tone.danger,
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showName) ...[
              Avatar(user?.initials ?? '?', imageUrl: user?.avatarUrl, imageBytes: user?.avatarBytes, size: 38),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (showName)
                    Text(user?.name ?? 'Member',
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                  Text(
                    r.vehicle == null
                        ? 'No vehicle'
                        : '${r.vehicle!.name} · starts at ${r.startBatteryPct.round()}% · ${r.vehicle!.connectors.map((c) => c.label).join(', ')}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 8),
                  Tag(check.result.label,
                      tone: tone,
                      icon: check.result == Feasibility.ok ? 'check' : 'alert'),
                  const SizedBox(height: 6),
                  Text(check.reason, style: const TextStyle(fontSize: 13)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AttendeeRow extends StatelessWidget {
  const _AttendeeRow({required this.rsvp});

  final Rsvp rsvp;

  @override
  Widget build(BuildContext context) {
    final user = context.read<AppState>().userById(rsvp.userId);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Avatar(user?.initials ?? '?', imageUrl: user?.avatarUrl, imageBytes: user?.avatarBytes, size: 38),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(user?.name ?? 'Member',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                Text(
                  rsvp.vehicle == null
                      ? 'No vehicle'
                      : '${rsvp.vehicle!.name} · ${rsvp.vehicle!.connectors.map((c) => c.label).join(', ')}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RsvpForm extends StatefulWidget {
  const _RsvpForm({
    required this.event,
    required this.initial,
    required this.onDone,
  });

  final CommunityEvent event;
  final double initial;
  final VoidCallback onDone;

  @override
  State<_RsvpForm> createState() => _RsvpFormState();
}

class _RsvpFormState extends State<_RsvpForm> {
  late double _battery = widget.initial;

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    final v = state.me.vehicle;
    final route = widget.event.type.hasRoute;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const FieldLabel('Attending vehicle'),
        AppCard(
          color: AppColors.skyMist,
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              const AppIcon('car', color: AppColors.skyDeep),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  v == null
                      ? 'No vehicle on your profile'
                      : '${v.name} · ${v.type.label} · ${v.connectors.map((c) => c.label).join(', ')}',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Text('Taken from your profile.',
            style: Theme.of(context).textTheme.bodySmall),
        if (v != null) ...[
          const SizedBox(height: 16),
          FieldLabel(
              'Starting battery level: ${_battery.round()}%${route ? ' · about ${ChargingRules.remainingRangeKm(v, _battery).round()} km' : ''}'),
          Slider(
            value: _battery,
            min: 5,
            max: 100,
            divisions: 19,
            onChanged: (x) => setState(() => _battery = x),
          ),
          if (route)
            Text(
              'Officers use this to check whether every vehicle can reach the charging stop and the destination.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
        ],
        const SizedBox(height: 16),
        AppButton(
          label: 'Confirm RSVP',
          expand: true,
          onTap: () {
            final ok = state.rsvp(widget.event, _battery);
            Navigator.of(context).pop();
            if (ok) widget.onDone();
          },
        ),
      ],
    );
  }
}
