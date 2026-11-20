import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_motion.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/basics.dart';
import '../../data/models.dart';
import '../../state/app_state.dart';
import '../shared/shared_widgets.dart';
import '../events/create_event_screen.dart';
import '../events/events_screen.dart';
import 'community_detail_screen.dart';
import 'create_community_screen.dart';

/// The Community module's home: the groups you belong to, discovery, and
/// events (M1 and M3). Events live here instead of in a tab of their own.
class CommunitiesScreen extends StatefulWidget {
  const CommunitiesScreen({super.key, this.viewRequest});

  /// Lets other screens open a specific view, for example 'Events' from the
  /// Home quick access. The value is cleared once it has been applied.
  final ValueNotifier<String?>? viewRequest;

  @override
  State<CommunitiesScreen> createState() => _CommunitiesScreenState();
}

class _CommunitiesScreenState extends State<CommunitiesScreen> {
  String _view = 'My groups';
  int _type = 0;

  @override
  void initState() {
    super.initState();
    widget.viewRequest?.addListener(_applyRequest);
    _applyRequest();
  }

  @override
  void dispose() {
    widget.viewRequest?.removeListener(_applyRequest);
    super.dispose();
  }

  void _applyRequest() {
    final requested = widget.viewRequest?.value;
    if (requested == null) return;
    widget.viewRequest!.value = null;
    if (mounted) setState(() => _view = requested);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final joined = [...state.myGroups, ...state.myPendingCommunities];
    final typeFilter = _type == 0 ? null : CommunityType.values[_type - 1];
    final discover = state.approvedCommunities
        .where((c) => typeFilter == null || c.type == typeFilter)
        .toList();
    // Admins and providers do not join communities, so they only browse.
    final browsing = state.isAdmin || state.isProvider;
    final views = [if (!browsing) 'My groups', 'Discover', 'Events'];
    final view = views.contains(_view) ? _view : views.first;
    final onEvents = view == 'Events';

    return TabPage(
      title: 'Community',
      subtitle: 'Communities, tribes and their events',
      actions: [
        if (onEvents && state.managedGroups.isNotEmpty)
          IconSquare(
            icon: 'add',
            label: 'Create an event',
            filled: true,
            onTap: () => pushScreen(context, const CreateEventScreen()),
          )
        else if (!onEvents && state.canParticipate)
          IconSquare(
            icon: 'add',
            label: 'Create a community',
            filled: true,
            onTap: () => pushScreen(context, const CreateCommunityScreen()),
          ),
      ],
      children: [
        SegmentedTabs(
          labels: views,
          index: views.indexOf(view),
          onChanged: (i) => setState(() => _view = views[i]),
        ),
        const SizedBox(height: 14),
        Swap(
          id: view,
          child: switch (view) {
            'Events' => const EventsPanel(),
            'My groups' => Column(
              children: [
                if (joined.isEmpty)
                  const EmptyState(
                    icon: 'community',
                    title: 'No communities yet',
                    message:
                        'Open Discover to find a community or tribe to join.',
                  ),
                for (final (i, c) in joined.indexed)
                  FadeIn(
                    index: i,
                    child: CommunityCard(community: c),
                  ),
              ],
            ),
            _ => Column(
              children: [
                PillRow(
                  padding: EdgeInsets.zero,
                  labels: [
                    'All',
                    for (final t in CommunityType.values) t.label,
                  ],
                  index: _type,
                  onChanged: (i) => setState(() => _type = i),
                ),
                const SizedBox(height: 14),
                if (discover.isEmpty)
                  const EmptyState(
                    icon: 'community',
                    title: 'No communities of this type',
                  ),
                for (final (i, c) in discover.indexed)
                  FadeIn(
                    key: ValueKey(c.id),
                    index: i,
                    child: CommunityCard(community: c),
                  ),
              ],
            ),
          },
        ),
      ],
    );
  }
}

class CommunityCard extends StatelessWidget {
  const CommunityCard({super.key, required this.community});

  final Community community;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final c = community;
    final role = state.roleIn(c);
    final parent = c.parentId == null ? null : state.communityById(c.parentId!);
    final tribes = state.tribesOf(c).length;
    final pending = c.status == ApprovalStatus.pending;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        onTap: () =>
            pushScreen(context, CommunityDetailScreen(communityId: c.id)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 46,
                  height: 46,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: c.isTribe ? AppColors.pinkSoft : AppColors.skySoft,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: AppIcon(
                    c.isTribe ? 'flag' : 'community',
                    size: 20,
                    color: c.isTribe ? AppColors.pinkDeep : AppColors.skyDeep,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        c.name,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        parent != null
                            ? 'Tribe of ${parent.name}'
                            : [
                                plural(c.memberCount, 'member'),
                                if (tribes > 0) plural(tribes, 'tribe'),
                              ].join(' · '),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                const AppIcon('chevron', size: 18, color: AppColors.inkFaint),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              c.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppColors.inkSoft, fontSize: 13.5),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                Tag(c.type.label),
                Tag(c.joinPolicy.label, tone: Tone.neutral),
                if (c.requiresVerification)
                  const Tag(
                    'Verified owners',
                    tone: Tone.success,
                    icon: 'check',
                  ),
                if (role != null) Tag(role.label, tone: Tone.pink),
                if (pending)
                  const Tag('Waiting for admin approval', tone: Tone.warning),
                if (state.hasRequested(c))
                  const Tag('Request sent', tone: Tone.warning),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
