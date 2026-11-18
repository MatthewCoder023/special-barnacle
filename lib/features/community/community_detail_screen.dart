import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_motion.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/basics.dart';
import '../../core/widgets/overlays.dart';
import '../../data/models.dart';
import '../../data/seed_data.dart';
import '../../domain/community_rules.dart';
import '../../state/app_state.dart';
import '../admin/insights_screen.dart';
import '../engagement/discussion_screens.dart';
import '../engagement/proposal_screens.dart';
import '../engagement/voice_screens.dart';
import '../events/create_event_screen.dart';
import '../events/events_screen.dart';
import '../shared/shared_widgets.dart';
import 'communities_screen.dart';
import 'create_community_screen.dart';

/// Hub for one community or tribe. Its tabs cover M1 (members, tribes),
/// M2 (feed, polls, Community Voice) and the group's M3 events.
class CommunityDetailScreen extends StatefulWidget {
  const CommunityDetailScreen({
    super.key,
    required this.communityId,
    this.initialTab,
  });

  final String communityId;
  final String? initialTab;

  @override
  State<CommunityDetailScreen> createState() => _CommunityDetailScreenState();
}

class _CommunityDetailScreenState extends State<CommunityDetailScreen> {
  late String _tab = widget.initialTab ?? 'Feed';

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final c = state.communityById(widget.communityId);
    if (c == null) {
      return const DetailScaffold(title: 'Community', children: [
        EmptyState(icon: 'community', title: 'This community is not available'),
      ]);
    }
    final member = state.isMemberOf(c);
    final manage = state.canManage(c);
    final approved = c.status == ApprovalStatus.approved;
    // Approval-based groups show their content to members only.
    final canView = approved &&
        (member || state.isAdmin || c.joinPolicy == JoinPolicy.open);
    final tabs = canView
        ? [
            'Feed',
            if (!c.isTribe) 'Tribes',
            'Polls',
            'Voice',
            'Events',
            'Members',
            'About',
          ]
        : ['About'];
    final tab = tabs.contains(_tab) ? _tab : tabs.first;

    return DetailScaffold(
      title: c.isTribe ? 'Tribe' : 'Community',
      actions: [
        if (approved && (manage || member))
          MenuButton<String>(
            items: [
              if (manage && !c.isTribe)
                const AppMenuItem('tribe', 'Create a tribe', icon: 'flag'),
              if (manage)
                const AppMenuItem('insights', 'Community insights',
                    icon: 'chart'),
              if (manage)
                const AppMenuItem('settings', 'Membership and voting rules',
                    icon: 'sliders'),
              if (member && !state.isLeaderOf(c))
                AppMenuItem('leave', 'Leave ${c.kind}',
                    icon: 'logout', danger: true),
            ],
            onSelected: (v) => _onMenu(v, c),
          ),
      ],
      children: [
        _Header(community: c),
        const SizedBox(height: 16),
        if (tabs.length > 1) ...[
          PillRow(
            padding: EdgeInsets.zero,
            labels: tabs,
            index: tabs.indexOf(tab),
            onChanged: (i) => setState(() => _tab = tabs[i]),
          ),
          const SizedBox(height: 16),
        ],
        Swap(
          id: tab,
          child: switch (tab) {
            'Feed' => _FeedTab(community: c),
            'Tribes' => _TribesTab(community: c),
            'Polls' => _PollsTab(community: c),
            'Voice' => _VoiceTab(community: c),
            'Events' => _EventsTab(community: c),
            'Members' => _MembersTab(community: c),
            _ => _AboutTab(community: c, limited: !canView),
          },
        ),
      ],
    );
  }

  Future<void> _onMenu(String value, Community c) async {
    final state = context.read<AppState>();
    switch (value) {
      case 'tribe':
        pushScreen(context, CreateCommunityScreen(parent: c));
      case 'insights':
        pushScreen(context, InsightsScreen(communityId: c.id));
      case 'settings':
        showAppSheet<void>(
          context,
          title: 'Membership and voting rules',
          builder: (_) => _SettingsForm(community: c),
        );
      case 'leave':
        final ok = await confirmAction(
          context,
          title: 'Leave ${c.name}?',
          message: c.isTribe
              ? 'You can join again later.'
              : 'You will also leave its tribes. You can join again later.',
          confirmLabel: 'Leave',
          danger: true,
        );
        if (!ok || !mounted) return;
        state.leave(c);
        showToast(context, 'You left ${c.name}.');
    }
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.community});

  final Community community;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final c = community;
    final role = state.roleIn(c);
    final parent = c.parentId == null ? null : state.communityById(c.parentId!);
    final block = state.joinBlockReason(c);
    final approved = c.status == ApprovalStatus.approved;

    Widget action;
    if (!approved) {
      action = const NoticeBox(
        'Waiting for the platform administrator to approve this community. Approval prevents impersonation of real clubs.',
        tone: Tone.warning,
      );
    } else if (role != null) {
      action = Row(
        children: [
          const AppIcon('check', size: 16),
          const SizedBox(width: 8),
          Text('You are ${role == GroupRole.member ? 'a member' : 'the ${role.label.toLowerCase()}'}',
              style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      );
    } else if (state.hasRequested(c)) {
      action = Row(
        children: [
          const Expanded(
            child: Text('Request sent. Waiting for an officer.',
                style: TextStyle(fontWeight: FontWeight.w600)),
          ),
          AppButton(
            label: 'Cancel',
            kind: AppButtonKind.soft,
            small: true,
            onTap: () => state.cancelRequest(c),
          ),
        ],
      );
    } else if (block != null) {
      action = Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.white.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            const AppIcon('lock', size: 16),
            const SizedBox(width: 10),
            Expanded(child: Text(block, style: const TextStyle(fontSize: 13))),
          ],
        ),
      );
    } else {
      action = AppButton(
        label: c.joinPolicy == JoinPolicy.open ? 'Join' : 'Request to join',
        expand: true,
        onTap: () {
          final joined = state.join(c);
          showToast(context,
              joined ? 'You joined ${c.name}.' : 'Request sent to the officers.');
        },
      );
    }

    return AppCard(
      color: AppColors.sky,
      border: false,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (parent != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text('Tribe of ${parent.name}',
                  style: const TextStyle(fontSize: 12.5)),
            ),
          Text(c.name, style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 8),
          Text(
            [
              c.type.label,
              plural(c.members.length, 'member'),
              c.joinPolicy.label,
            ].join(' · '),
            style: const TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 16),
          AnimatedSwitcher(
            duration: AppMotion.of(context, AppMotion.standard),
            child: KeyedSubtree(
              key: ValueKey('$role${state.hasRequested(c)}$approved'),
              child: action,
            ),
          ),
        ],
      ),
    );
  }
}

// ───────────────────────────────── Feed ─────────────────────────────────

class _FeedTab extends StatefulWidget {
  const _FeedTab({required this.community});

  final Community community;

  @override
  State<_FeedTab> createState() => _FeedTabState();
}

class _FeedTabState extends State<_FeedTab> {
  int _topic = 0;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final c = widget.community;
    final member = state.isMemberOf(c);
    final manage = state.canManage(c);
    final announcements = state.announcementsOf(c.id);
    final topic = _topic == 0 ? null : SeedData.topics[_topic - 1];
    final discussions = state
        .discussionsOf(c.id)
        .where((d) => topic == null || d.topic == topic)
        .toList();
    final flagged = manage ? state.reportsForLeader(c) : <ContentReport>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (member && (manage || state.canParticipate))
          Row(
            children: [
              if (manage) ...[
                Expanded(
                  child: AppButton(
                    label: 'Announce',
                    icon: 'megaphone',
                    kind: AppButtonKind.sky,
                    onTap: () =>
                        showNewPostSheet(context, c, announcement: true),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: AppButton(
                  label: 'New post',
                  icon: 'add',
                  onTap: () =>
                      showNewPostSheet(context, c, announcement: false),
                ),
              ),
            ],
          ),
        if (flagged.isNotEmpty) ...[
          const SizedBox(height: 12),
          AppCard(
            color: AppColors.warningSoft,
            border: false,
            onTap: () => showAppSheet<void>(
              context,
              title: 'Reported content',
              builder: (_) => _ReportsReview(community: c),
            ),
            child: Row(
              children: [
                const AppIcon('flag', size: 18, color: AppColors.warning),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '${plural(flagged.length, 'report')} to review',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                const AppIcon('chevron', size: 16),
              ],
            ),
          ),
        ],
        if (announcements.isNotEmpty) const SectionHeader('Announcements'),
        for (final (i, a) in announcements.indexed)
          FadeIn(
            index: i,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: AppCard(
                color: a.pinned ? AppColors.skyMist : AppColors.white,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (a.pinned) ...[
                          const Tag('Pinned', tone: Tone.pink, icon: 'bookmark'),
                          const SizedBox(width: 8),
                        ],
                        Expanded(
                          child: Text(
                            '${state.userName(a.authorId)} · ${timeAgo(a.createdAt)}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                        if (manage)
                          Pressable(
                            onTap: () => state.togglePin(a),
                            label: a.pinned ? 'Unpin' : 'Pin',
                            child: Padding(
                              padding: const EdgeInsets.all(4),
                              child: AppIcon('bookmark',
                                  size: 17,
                                  color: a.pinned
                                      ? AppColors.pinkDeep
                                      : AppColors.inkFaint),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(a.title,
                        style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 4),
                    Text(a.body,
                        style: const TextStyle(color: AppColors.inkSoft)),
                  ],
                ),
              ),
            ),
          ),
        const SectionHeader('Discussions'),
        PillRow(
          padding: EdgeInsets.zero,
          labels: ['All', ...SeedData.topics],
          index: _topic,
          onChanged: (i) => setState(() => _topic = i),
        ),
        const SizedBox(height: 12),
        if (discussions.isEmpty)
          const EmptyState(
            icon: 'chat',
            title: 'No discussions here yet',
            message: 'Members can post questions and experiences by topic.',
          ),
        for (final (i, d) in discussions.indexed)
          FadeIn(
            key: ValueKey(d.id),
            index: i,
            child: DiscussionCard(discussion: d, community: c),
          ),
      ],
    );
  }
}

/// Leader and officer review of reported content in their own group.
class _ReportsReview extends StatelessWidget {
  const _ReportsReview({required this.community});

  final Community community;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final list = state.reportsForLeader(community);
    if (list.isEmpty) {
      return const EmptyState(icon: 'check', title: 'All reports reviewed');
    }
    return Column(
      children: [
        for (final r in list)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(r.contentTitle,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(
                    'Reason: ${r.reason} · reported by ${state.userName(r.reporterId)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      AppButton(
                        label: 'Remove',
                        kind: AppButtonKind.danger,
                        small: true,
                        onTap: () =>
                            state.decideReport(r, ReportStatus.removed),
                      ),
                      AppButton(
                        label: 'Dismiss',
                        kind: AppButtonKind.soft,
                        small: true,
                        onTap: () =>
                            state.decideReport(r, ReportStatus.dismissed),
                      ),
                      AppButton(
                        label: 'Send to admin',
                        kind: AppButtonKind.ghost,
                        small: true,
                        onTap: () =>
                            state.decideReport(r, ReportStatus.escalated),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

// ───────────────────────────────── Tribes ─────────────────────────────────

class _TribesTab extends StatelessWidget {
  const _TribesTab({required this.community});

  final Community community;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final tribes = state.tribesOf(community);
    return Column(
      children: [
        if (state.canManage(community))
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: AppButton(
              label: 'Create a tribe',
              icon: 'add',
              expand: true,
              onTap: () => pushScreen(
                  context, CreateCommunityScreen(parent: community)),
            ),
          ),
        if (tribes.isEmpty)
          const EmptyState(
            icon: 'flag',
            title: 'No tribes yet',
            message:
                'Tribes are smaller groups by model, region or interest inside a community.',
          ),
        for (final (i, t) in tribes.indexed)
          FadeIn(index: i, child: CommunityCard(community: t)),
      ],
    );
  }
}

// ───────────────────────────────── Polls ─────────────────────────────────

class _PollsTab extends StatelessWidget {
  const _PollsTab({required this.community});

  final Community community;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final list = state.proposalsOf(community.id);
    return Column(
      children: [
        if (state.canPropose(community))
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: AppButton(
              label: 'New proposal or poll',
              icon: 'add',
              expand: true,
              onTap: () => showNewProposalSheet(context, community),
            ),
          ),
        if (list.isEmpty)
          const EmptyState(
            icon: 'vote',
            title: 'No proposals yet',
            message:
                'Proposals and polls let the group decide openly, with a deadline and a quorum.',
          ),
        for (final (i, p) in list.indexed)
          FadeIn(index: i, child: _ProposalCard(proposal: p)),
      ],
    );
  }
}

class _ProposalCard extends StatelessWidget {
  const _ProposalCard({required this.proposal});

  final Proposal proposal;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final p = proposal;
    final open = state.isOpen(p);
    final tally = VotingRules.tally(p);
    final voted = p.votes.containsKey(state.me.id);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        onTap: () => pushScreen(context, ProposalDetailScreen(proposalId: p.id)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                Tag(open ? 'Open · closes ${timeLeft(p.deadline)}' : 'Closed',
                    tone: open ? Tone.success : Tone.neutral),
                Tag(p.ranked ? 'Ranked choice' : 'Single choice'),
                if (voted) const Tag('You voted', tone: Tone.pink, icon: 'check'),
              ],
            ),
            const SizedBox(height: 10),
            Text(p.title, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: (tally.totalVotes / p.quorum).clamp(0, 1).toDouble(),
                minHeight: 7,
                backgroundColor: AppColors.skySoft,
                color: tally.quorumMet ? AppColors.success : AppColors.sky,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${plural(tally.totalVotes, 'vote')} of ${p.quorum} needed for quorum',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (p.outcome != null) ...[
              const SizedBox(height: 8),
              Text('Outcome: ${p.outcome}',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
            ],
          ],
        ),
      ),
    );
  }
}

// ───────────────────────────── Community Voice ─────────────────────────────

class _VoiceTab extends StatelessWidget {
  const _VoiceTab({required this.community});

  final Community community;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final c = community;
    final concerns = state.concernsOf(c.id);
    final published = state.summariesOf(c.id);
    final member = state.isMemberOf(c);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const NoticeBox(
          'Community Voice gathers members\' concerns. Support the ones that affect you, and leaders compile them into a dated position summary.',
          icon: 'megaphone',
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            if (member && state.canParticipate)
              Expanded(
                child: AppButton(
                  label: 'File a concern',
                  icon: 'add',
                  onTap: () => showFileConcernSheet(context, c),
                ),
              ),
            if (state.canManage(c)) ...[
              const SizedBox(width: 10),
              Expanded(
                child: AppButton(
                  label: 'Compile',
                  icon: 'document',
                  kind: AppButtonKind.sky,
                  onTap: () => pushScreen(
                      context, CompileSummaryScreen(communityId: c.id)),
                ),
              ),
            ],
          ],
        ),
        if (published.isNotEmpty) ...[
          const SectionHeader('Position summaries'),
          for (final s in published)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: AppCard(
                color: AppColors.pinkSoft,
                border: false,
                onTap: () =>
                    pushScreen(context, SummaryScreen(summary: s)),
                child: Row(
                  children: [
                    const AppIcon('document',
                        size: 20, color: AppColors.pinkDeep),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(s.title,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600)),
                          Text(
                            '${fmtDate(s.createdAt)} · ${plural(s.concernCount, 'concern')} · ${plural(s.supportCount, 'supporter')}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    const AppIcon('chevron',
                        size: 16, color: AppColors.pinkDeep),
                  ],
                ),
              ),
            ),
        ],
        const SectionHeader('Concern board'),
        if (concerns.isEmpty)
          const EmptyState(
            icon: 'megaphone',
            title: 'No concerns filed',
            message:
                'Members can file a concern with a category, location and photo.',
          ),
        for (final (i, k) in concerns.indexed)
          FadeIn(
            key: ValueKey(k.id),
            index: i,
            child: ConcernCard(concern: k),
          ),
      ],
    );
  }
}

// ───────────────────────────────── Events ─────────────────────────────────

class _EventsTab extends StatelessWidget {
  const _EventsTab({required this.community});

  final Community community;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final list = state.eventsOf(community.id);
    return Column(
      children: [
        if (state.canManage(community))
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: AppButton(
              label: 'Create an event',
              icon: 'add',
              expand: true,
              onTap: () => pushScreen(
                  context, CreateEventScreen(community: community)),
            ),
          ),
        if (list.isEmpty)
          const EmptyState(
            icon: 'events',
            title: 'No upcoming events',
            message: 'Meetups, convoys, drives and outreach appear here.',
          ),
        for (final (i, e) in list.indexed)
          FadeIn(index: i, child: EventCard(event: e)),
      ],
    );
  }
}

// ───────────────────────────────── Members ─────────────────────────────────

class _MembersTab extends StatelessWidget {
  const _MembersTab({required this.community});

  final Community community;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final c = community;
    final manage = state.canManage(c);
    final leader = state.isLeaderOf(c);
    final members = c.members.entries.toList()
      ..sort((a, b) => a.value.index.compareTo(b.value.index));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (manage && c.joinRequests.isNotEmpty) ...[
          Text('Join requests', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          for (final id in [...c.joinRequests])
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _RequestCard(community: c, userId: id),
            ),
          const SizedBox(height: 10),
        ],
        Text(plural(members.length, 'member'),
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 10),
        for (final (i, entry) in members.indexed)
          FadeIn(
            key: ValueKey(entry.key),
            index: i,
            child: Builder(builder: (context) {
              final user = state.userById(entry.key);
              final isSelf = entry.key == state.me.id;
              final canAct = manage &&
                  !isSelf &&
                  entry.value != GroupRole.leader;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.line),
                ),
                child: Row(
                  children: [
                    Avatar(user?.initials ?? '?', imageUrl: user?.avatarUrl, imageBytes: user?.avatarBytes),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${user?.name ?? 'Former member'}${isSelf ? ' (you)' : ''}',
                            style:
                                const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          Text(
                            (user?.showVehicle ?? true) || manage || isSelf
                                ? user?.vehicle?.name ?? 'No vehicle on profile'
                                : 'Vehicle not shared',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    if (user?.isVerified ?? false) ...[
                      const Tag('Verified', tone: Tone.success, icon: 'check'),
                      const SizedBox(width: 6),
                    ],
                    if (entry.value != GroupRole.member)
                      Tag(entry.value.label, tone: Tone.pink),
                    if (canAct) ...[
                      const SizedBox(width: 6),
                      Builder(
                        builder: (anchor) => Pressable(
                          label: 'Member options',
                          onTap: () async {
                            final v = await showAppMenu<String>(anchor, [
                              if (leader && entry.value == GroupRole.member)
                                const AppMenuItem('officer', 'Make officer',
                                    icon: 'shield'),
                              if (leader && entry.value == GroupRole.officer)
                                const AppMenuItem(
                                    'member', 'Remove officer role',
                                    icon: 'profile'),
                              const AppMenuItem('remove', 'Remove from group',
                                  icon: 'close', danger: true),
                            ]);
                            if (v == 'officer') {
                              state.setRole(c, entry.key, GroupRole.officer);
                            } else if (v == 'member') {
                              state.setRole(c, entry.key, GroupRole.member);
                            } else if (v == 'remove') {
                              state.removeMember(c, entry.key);
                            }
                          },
                          child: const Padding(
                            padding: EdgeInsets.all(6),
                            child: AppIcon('more',
                                size: 18, color: AppColors.inkSoft),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              );
            }),
          ),
      ],
    );
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({required this.community, required this.userId});

  final Community community;
  final String userId;

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    final user = state.userById(userId);
    final c = community;
    final meetsModel = c.criteriaModel == null ||
        user?.vehicle?.name == c.criteriaModel;
    return AppCard(
      color: AppColors.pinkSoft,
      border: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Avatar(user?.initials ?? '?', imageUrl: user?.avatarUrl, imageBytes: user?.avatarBytes, pink: true),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(user?.name ?? 'Unknown',
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    Text(
                      '${user?.vehicle?.name ?? 'No vehicle'} · ${user?.region ?? ''}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              Tag(user?.verification.label ?? 'Not verified',
                  tone: (user?.isVerified ?? false)
                      ? Tone.success
                      : Tone.neutral),
              if (c.criteriaModel != null)
                Tag(
                  meetsModel
                      ? 'Meets model criteria'
                      : 'Different model than ${c.criteriaModel}',
                  tone: meetsModel ? Tone.success : Tone.warning,
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  label: 'Decline',
                  kind: AppButtonKind.soft,
                  small: true,
                  onTap: () =>
                      state.decideRequest(c, userId, approve: false),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: AppButton(
                  label: 'Approve',
                  small: true,
                  onTap: () {
                    state.decideRequest(c, userId, approve: true);
                    showToast(context, '${user?.name ?? 'Member'} approved.');
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

// ───────────────────────────────── About ─────────────────────────────────

class _AboutTab extends StatelessWidget {
  const _AboutTab({required this.community, required this.limited});

  final Community community;
  final bool limited;

  @override
  Widget build(BuildContext context) {
    final c = community;
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (limited && c.status == ApprovalStatus.approved) ...[
          const NoticeBox(
            'Posts, polls, events and the member list are visible to members only.',
            icon: 'lock',
          ),
          const SizedBox(height: 14),
        ],
        Text('About', style: text.titleMedium),
        const SizedBox(height: 6),
        Text(c.description, style: const TextStyle(color: AppColors.inkSoft)),
        const SizedBox(height: 18),
        Text('Membership', style: text.titleMedium),
        const SizedBox(height: 6),
        InfoRow('community', c.joinPolicy == JoinPolicy.open
            ? 'Open: anyone eligible can join right away'
            : 'Approval-based: a leader or officer reviews each request'),
        InfoRow('verified', c.requiresVerification
            ? 'Vehicle ownership must be verified'
            : 'Ownership verification is not required'),
        if (c.criteriaModel != null)
          InfoRow('car', 'Vehicle model: ${c.criteriaModel}'),
        if (c.criteriaRegion != null)
          InfoRow('pin', 'Region: ${c.criteriaRegion}'),
        InfoRow('vote', c.membersCanPropose
            ? 'Members can open proposals and polls'
            : 'Only leaders and officers open proposals and polls'),
        const SizedBox(height: 18),
        Text('Rules', style: text.titleMedium),
        const SizedBox(height: 6),
        Text(c.rules, style: const TextStyle(color: AppColors.inkSoft)),
        const SizedBox(height: 18),
        Text('Created ${fmtDate(c.createdAt)}', style: text.bodySmall),
      ],
    );
  }
}

/// Leader settings: joining, verification and who may open proposals.
class _SettingsForm extends StatefulWidget {
  const _SettingsForm({required this.community});

  final Community community;

  @override
  State<_SettingsForm> createState() => _SettingsFormState();
}

class _SettingsFormState extends State<_SettingsForm> {
  late final _rules = TextEditingController(text: widget.community.rules);

  @override
  void dispose() {
    _rules.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final c = widget.community;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ToggleRow(
          title: 'Approve each join request',
          subtitle: 'Off means anyone eligible joins right away.',
          value: c.joinPolicy == JoinPolicy.approval,
          onChanged: (v) => state.updateGroupSettings(
              c, (g) => g.joinPolicy = v ? JoinPolicy.approval : JoinPolicy.open),
        ),
        ToggleRow(
          title: 'Require verified ownership',
          subtitle: 'Only members with the verified-owner label can join.',
          value: c.requiresVerification,
          onChanged: (v) => state.updateGroupSettings(
              c, (g) => g.requiresVerification = v),
        ),
        ToggleRow(
          title: 'Members can open proposals',
          subtitle: 'Off limits proposals and polls to leaders and officers.',
          value: c.membersCanPropose,
          onChanged: (v) =>
              state.updateGroupSettings(c, (g) => g.membersCanPropose = v),
        ),
        const SizedBox(height: 6),
        AppField(controller: _rules, label: 'Rules', maxLines: 6),
        AppButton(
          label: 'Save rules',
          expand: true,
          onTap: () {
            state.updateGroupSettings(c, (g) => g.rules = _rules.text.trim());
            Navigator.of(context).pop();
            showToast(context, 'Rules saved.');
          },
        ),
      ],
    );
  }
}
