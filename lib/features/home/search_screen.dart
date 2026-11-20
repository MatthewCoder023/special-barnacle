import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_motion.dart';
import '../../core/widgets/basics.dart';
import '../../core/widgets/overlays.dart';
import '../../state/app_state.dart';
import '../charging/provider_detail_screen.dart';
import '../charging/station_detail_screen.dart';
import '../community/community_detail_screen.dart';
import '../events/event_detail_screen.dart';

/// Searches communities, events, stations and providers by name.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final q = _query.text.trim().toLowerCase();
    bool hit(String s) => s.toLowerCase().contains(q);

    final results =
        <(String icon, String title, String subtitle, Widget screen)>[
          if (q.isNotEmpty) ...[
            for (final c in state.communities.where(
              (c) =>
                  c.status.name == 'approved' &&
                  (hit(c.name) || hit(c.description)),
            ))
              (
                'community',
                c.name,
                c.isTribe ? 'Tribe' : 'Community',
                CommunityDetailScreen(communityId: c.id),
              ),
            for (final e in state.upcomingEvents.where((e) => hit(e.title)))
              ('events', e.title, 'Event', EventDetailScreen(eventId: e.id)),
            for (final s in state.stations.where(
              (s) => hit(s.name) || hit(s.city) || hit(s.operator),
            ))
              (
                'charging',
                s.name,
                'Charging station · ${s.city}',
                StationDetailScreen(stationId: s.id),
              ),
            for (final p in state.directory.where(
              (p) =>
                  hit(p.name) ||
                  hit(p.city) ||
                  p.services.any(hit) ||
                  p.brands.any(hit),
            ))
              (
                'wrench',
                p.name,
                '${p.category.label} · ${p.city}',
                ProviderDetailScreen(providerId: p.id),
              ),
          ],
        ];

    return DetailScaffold(
      title: 'Search',
      children: [
        TextField(
          controller: _query,
          autofocus: true,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(
            hintText: 'Communities, events, stations, providers',
            prefixIcon: Padding(
              padding: EdgeInsets.all(13),
              child: AppIcon('search', size: 18, color: AppColors.inkSoft),
            ),
          ),
        ),
        const SizedBox(height: 14),
        if (q.isEmpty)
          const EmptyState(
            icon: 'search',
            title: 'Search EVYAHE',
            message: 'Type a name, city, brand or service.',
          )
        else if (results.isEmpty)
          EmptyState(
            icon: 'search',
            title: 'No results for "${_query.text.trim()}"',
            message: 'Check the spelling or try a shorter word.',
          ),
        for (final (i, r) in results.indexed)
          FadeIn(
            key: ValueKey('${r.$1}${r.$2}'),
            index: i,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: AppCard(
                onTap: () => pushScreen(context, r.$4),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    AppIcon(r.$1, size: 18, color: AppColors.skyDeep),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            r.$2,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          Text(
                            r.$3,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    const AppIcon(
                      'chevron',
                      size: 16,
                      color: AppColors.inkFaint,
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
