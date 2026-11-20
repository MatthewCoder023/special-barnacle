import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_motion.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/basics.dart';
import '../../data/models.dart';
import '../../state/app_state.dart';
import '../shared/shared_widgets.dart';
import 'event_detail_screen.dart';

/// M3 inside the Community module: a month calendar and the list of events
/// the user is allowed to see. It is a panel, not a screen, so the Community
/// tab can show it next to groups and discovery.
class EventsPanel extends StatefulWidget {
  const EventsPanel({super.key});

  @override
  State<EventsPanel> createState() => _EventsPanelState();
}

class _EventsPanelState extends State<EventsPanel> {
  late DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime? _day;
  String _filter = 'All';

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final filters = [
      'All',
      if (state.canParticipate) 'Going',
      for (final t in EventType.values) t.label,
    ];
    final filter = filters.contains(_filter) ? _filter : 'All';
    final visible = state.upcomingEvents
        .where(
          (e) => switch (filter) {
            'All' => true,
            'Going' => state.myRsvp(e) != null,
            _ => e.type.label == filter,
          },
        )
        .toList();
    final day = _day;
    final list = day == null
        ? visible
        : visible.where((e) => _sameDay(e.start, day)).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        EventCalendar(
          month: _month,
          selected: _day,
          eventDays: {
            for (final e in visible)
              if (e.start.year == _month.year && e.start.month == _month.month)
                e.start.day,
          },
          onMonthChanged: (m) => setState(() {
            _month = m;
            _day = null;
          }),
          onDaySelected: (d) => setState(
            () => _day = _day != null && _sameDay(_day!, d) ? null : d,
          ),
        ),
        const SizedBox(height: 14),
        PillRow(
          labels: filters,
          index: filters.indexOf(filter),
          padding: EdgeInsets.zero,
          onChanged: (i) => setState(() => _filter = filters[i]),
        ),
        const SizedBox(height: 14),
        Text(
          day == null ? 'Upcoming' : fmtDate(day),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 10),
        Swap(
          id: '$filter${day?.toIso8601String()}',
          child: Column(
            children: [
              if (list.isEmpty)
                EmptyState(
                  icon: 'events',
                  title: day != null
                      ? 'Nothing on this day'
                      : filter == 'Going'
                      ? 'You have not RSVPed to anything'
                      : 'No upcoming events',
                  message: 'Events from your communities and tribes, and public events, appear here.',
                ),
              for (final (i, e) in list.indexed)
                FadeIn(
                  index: i,
                  child: EventCard(event: e),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Month grid. Days with events carry a dot; tapping a day filters the list,
/// tapping it again clears the filter.
class EventCalendar extends StatelessWidget {
  const EventCalendar({
    super.key,
    required this.month,
    required this.selected,
    required this.eventDays,
    required this.onMonthChanged,
    required this.onDaySelected,
  });

  /// First day of the month shown.
  final DateTime month;
  final DateTime? selected;

  /// Day numbers in [month] that have at least one event.
  final Set<int> eventDays;
  final ValueChanged<DateTime> onMonthChanged;
  final ValueChanged<DateTime> onDaySelected;

  static const _monthNames = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    // Monday-first grid: blanks before day 1.
    final lead = DateTime(month.year, month.month, 1).weekday - 1;
    final cells = lead + daysInMonth;
    final rows = (cells / 7).ceil();
    final duration = AppMotion.of(context, AppMotion.fast);

    return AppCard(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      child: Column(
        children: [
          Row(
            children: [
              const SizedBox(width: 6),
              Expanded(
                child: AnimatedSwitcher(
                  duration: duration,
                  layoutBuilder: (current, previous) => Stack(
                    alignment: Alignment.centerLeft,
                    children: [...previous, ?current],
                  ),
                  child: Text(
                    '${_monthNames[month.month - 1]} ${month.year}',
                    key: ValueKey(month),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ),
              _Arrow(
                icon: 'back',
                label: 'Previous month',
                onTap: () =>
                    onMonthChanged(DateTime(month.year, month.month - 1)),
              ),
              const SizedBox(width: 6),
              _Arrow(
                icon: 'chevron',
                label: 'Next month',
                onTap: () =>
                    onMonthChanged(DateTime(month.year, month.month + 1)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              for (final d in const ['M', 'T', 'W', 'T', 'F', 'S', 'S'])
                Expanded(
                  child: Center(
                    child: Text(
                      d,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.inkFaint,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          for (var r = 0; r < rows; r++)
            Row(
              children: [
                for (var c = 0; c < 7; c++)
                  Expanded(
                    child: Builder(
                      builder: (context) {
                        final dayNumber = r * 7 + c - lead + 1;
                        if (dayNumber < 1 || dayNumber > daysInMonth) {
                          return const SizedBox(height: 40);
                        }
                        final date = DateTime(
                          month.year,
                          month.month,
                          dayNumber,
                        );
                        final isSelected =
                            selected != null &&
                            selected!.year == date.year &&
                            selected!.month == date.month &&
                            selected!.day == date.day;
                        final isToday =
                            today.year == date.year &&
                            today.month == date.month &&
                            today.day == date.day;
                        final hasEvent = eventDays.contains(dayNumber);
                        return Semantics(
                          button: true,
                          selected: isSelected,
                          label:
                              '${fmtDate(date)}${hasEvent ? ', has events' : ''}',
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => onDaySelected(date),
                            child: SizedBox(
                              height: 40,
                              child: Center(
                                child: AnimatedContainer(
                                  duration: duration,
                                  width: 34,
                                  height: 34,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: isSelected
                                        ? AppColors.sky
                                        : Colors.transparent,
                                    border: isToday && !isSelected
                                        ? Border.all(
                                            color: AppColors.sky,
                                            width: 1.4,
                                          )
                                        : null,
                                  ),
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      ExcludeSemantics(
                                        child: Text(
                                          '$dayNumber',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: hasEvent || isSelected
                                                ? FontWeight.w700
                                                : FontWeight.w400,
                                            color: AppColors.ink,
                                          ),
                                        ),
                                      ),
                                      if (hasEvent)
                                        const Positioned(
                                          bottom: 3,
                                          child: _EventDot(),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _EventDot extends StatelessWidget {
  const _EventDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 5,
      height: 5,
      decoration: const BoxDecoration(
        color: AppColors.pink,
        shape: BoxShape.circle,
      ),
    );
  }
}

class _Arrow extends StatelessWidget {
  const _Arrow({required this.icon, required this.label, required this.onTap});

  final String icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      label: label,
      child: Container(
        width: 34,
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.skySoft,
          borderRadius: BorderRadius.circular(11),
        ),
        child: AppIcon(icon, size: 16),
      ),
    );
  }
}

class EventCard extends StatelessWidget {
  const EventCard({super.key, required this.event});

  final CommunityEvent event;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final e = event;
    final going = state.myRsvp(e) != null;
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        onTap: () => pushScreen(context, EventDetailScreen(eventId: e.id)),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 54,
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.skySoft,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Text(
                    monthShort(e.start).toUpperCase(),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.skyDeep,
                    ),
                  ),
                  Text(
                    '${e.start.day}',
                    style: const TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(dayShort(e.start), style: text.bodySmall),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(e.title, style: text.titleSmall),
                  const SizedBox(height: 2),
                  Text(
                    state.communityById(e.communityId)?.name ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.bodySmall,
                  ),
                  const SizedBox(height: 6),
                  InfoRow('clock', fmtTime(e.start)),
                  InfoRow(
                    'pin',
                    e.origin == null
                        ? e.venue.name
                        : '${e.origin!.name} to ${e.venue.name}',
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      Tag(e.type.label, tone: Tone.pink),
                      Tag(
                        '${e.attendeeCount} of ${e.capacity} going',
                        tone: Tone.neutral,
                      ),
                      if (going)
                        const Tag('Going', tone: Tone.success, icon: 'check'),
                    ],
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
