import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/utils/format.dart';
import '../../core/widgets/basics.dart';
import '../../core/widgets/overlays.dart';
import '../../domain/charging_rules.dart';
import '../../domain/community_rules.dart';
import '../../state/app_state.dart';

/// M5 Community Insights: the leader dashboard for one community or tribe.
/// Membership, event attendance, poll participation, concerns by category
/// and location, and station reliability and coverage summaries.
class InsightsScreen extends StatelessWidget {
  const InsightsScreen({super.key, required this.communityId});

  final String communityId;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final c = state.communityById(communityId)!;
    final text = Theme.of(context).textTheme;
    final members = c.memberCount;

    final events = state.events.where((e) => e.communityId == c.id).toList();
    final polls = state.proposals.where((p) => p.communityId == c.id).toList();
    final concerns = state.concernsOf(c.id);

    // Current members who had joined by the end of each of the last 6 months.
    final now = state.now;
    final growth = <(String, num)>[
      for (var back = 5; back >= 0; back--)
        (
          monthShort(DateTime(now.year, now.month - back)),
          c.members.keys.where((id) {
            final joined = c.joinedAt[id] ?? c.createdAt;
            return joined.isBefore(DateTime(now.year, now.month - back + 1));
          }).length,
        ),
    ];

    Map<String, int> countBy(Iterable<String> keys) {
      final out = <String, int>{};
      for (final k in keys) {
        out[k] = (out[k] ?? 0) + 1;
      }
      return out;
    }

    List<(String, num)> bars(Map<String, int> m) =>
        (m.entries.toList()..sort((a, b) => b.value.compareTo(a.value)))
            .map((e) => (e.key, e.value as num))
            .toList();

    final byCategory = countBy(concerns.map((k) => k.category));
    final byLocation = countBy(concerns.map((k) => k.location));
    final verified = c.members.keys
        .where((id) => state.userById(id)?.isVerified ?? false)
        .length;

    // Station reliability: share of status reports that said "working".
    final reliability = <(String, num)>[];
    for (final s in state.stations) {
      if (s.reports.isEmpty) continue;
      final ok = s.reports.where((r) => r.working).length;
      reliability.add((s.name, (ok / s.reports.length * 100).round()));
    }
    reliability.sort((a, b) => a.$2.compareTo(b.$2));
    final coverage = countBy(state.stations.map((s) => s.city));
    final reported = state.stations
        .where(
          (s) =>
              ChargingRules.condition(s, state.now) != StationCondition.unknown,
        )
        .length;

    return DetailScaffold(
      title: 'Community insights',
      children: [
        Text(c.name, style: text.headlineMedium),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: StatTile(
                icon: 'community',
                value: '$members',
                label: 'Members',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: StatTile(
                icon: 'verified',
                value: '$verified',
                label: 'Verified owners',
                pink: true,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: StatTile(
                icon: 'profile',
                value: '${c.joinRequests.length}',
                label: 'Join requests',
              ),
            ),
          ],
        ),
        const SectionHeader('Membership growth'),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              BarList(items: growth, pinkIndex: growth.length - 1),
              const SizedBox(height: 8),
              Text('Members at the end of each month.', style: text.bodySmall),
            ],
          ),
        ),
        const SectionHeader('Event attendance'),
        AppCard(
          child: events.isEmpty
              ? const Text('No events yet.')
              : BarList(
                  items: [for (final e in events) (e.title, e.attendeeCount)],
                ),
        ),
        const SectionHeader('Poll participation'),
        AppCard(
          child: polls.isEmpty
              ? const Text('No proposals or polls yet.')
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    BarList(
                      items: [
                        for (final p in polls)
                          (p.title, VotingRules.tally(p).totalVotes),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Votes cast, out of ${plural(members, 'member')}.',
                      style: text.bodySmall,
                    ),
                  ],
                ),
        ),
        const SectionHeader('Concerns by category'),
        AppCard(
          child: concerns.isEmpty
              ? const Text('No concerns filed.')
              : BarList(items: bars(byCategory), pinkIndex: 0),
        ),
        const SectionHeader('Concerns by location'),
        AppCard(
          child: concerns.isEmpty
              ? const Text('No concerns filed.')
              : BarList(items: bars(byLocation), pinkIndex: 0),
        ),
        const SectionHeader('Station reliability'),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              BarList(items: reliability.take(6).toList(), pinkIndex: 0),
              const SizedBox(height: 8),
              Text(
                'Percent of members\' status reports that said the station was working, lowest first. Based on few reports; use with the concern board as supporting evidence.',
                style: text.bodySmall,
              ),
            ],
          ),
        ),
        const SectionHeader('Charging coverage by city'),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              BarList(items: bars(coverage).take(8).toList()),
              const SizedBox(height: 8),
              Text(
                '${plural(state.stations.length, 'station')} in the reference list; $reported have a status report from the last 24 hours.',
                style: text.bodySmall,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
