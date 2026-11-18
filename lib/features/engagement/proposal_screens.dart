import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_motion.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/basics.dart';
import '../../core/widgets/overlays.dart';
import '../../data/models.dart';
import '../../domain/community_rules.dart';
import '../../state/app_state.dart';

/// M2: vote on a proposal or poll and see the visible results.
class ProposalDetailScreen extends StatefulWidget {
  const ProposalDetailScreen({super.key, required this.proposalId});

  final String proposalId;

  @override
  State<ProposalDetailScreen> createState() => _ProposalDetailScreenState();
}

class _ProposalDetailScreenState extends State<ProposalDetailScreen> {
  /// Options chosen so far, in order of preference for ranked choice.
  List<int>? _choice;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final p =
        state.proposals.where((x) => x.id == widget.proposalId).firstOrNull;
    final c = p == null ? null : state.communityById(p.communityId);
    if (p == null || c == null) {
      return const DetailScaffold(title: 'Proposal', children: [
        EmptyState(icon: 'vote', title: 'This proposal is not available'),
      ]);
    }
    final open = state.isOpen(p);
    final canVote = open && state.canParticipate && state.isMemberOf(c);
    final saved = p.votes[state.me.id];
    final choice = _choice ?? saved ?? const <int>[];
    final tally = VotingRules.tally(p);
    final complete =
        p.ranked ? choice.length == p.options.length : choice.length == 1;
    final changed = !_same(choice, saved);
    final text = Theme.of(context).textTheme;

    return DetailScaffold(
      title: 'Proposal',
      bottom: canVote
          ? AppButton(
              label: saved == null ? 'Submit vote' : 'Change vote',
              expand: true,
              onTap: complete && changed
                  ? () {
                      state.castVote(p, choice);
                      setState(() => _choice = null);
                      showToast(context, 'Your vote is recorded.');
                    }
                  : null,
            )
          : null,
      children: [
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            Tag(open ? 'Open' : 'Closed',
                tone: open ? Tone.success : Tone.neutral),
            Tag(p.ranked ? 'Ranked choice' : 'Single choice'),
          ],
        ),
        const SizedBox(height: 10),
        Text(p.title, style: text.headlineMedium),
        const SizedBox(height: 8),
        Text(p.description, style: const TextStyle(color: AppColors.inkSoft)),
        const SizedBox(height: 12),
        InfoRow('profile', 'Proposed by ${state.userName(p.authorId)} in ${c.name}'),
        InfoRow('clock',
            '${open ? 'Closes' : 'Deadline was'} ${fmtDateTime(p.deadline)}'),
        InfoRow('community',
            'Quorum set by the community: ${plural(p.quorum, 'vote')}'),
        if (p.outcome != null) ...[
          const SizedBox(height: 12),
          NoticeBox('Published outcome: ${p.outcome}',
              tone: Tone.success, icon: 'check'),
        ],
        SectionHeader(canVote
            ? (p.ranked ? 'Tap options in order of preference' : 'Choose one')
            : 'Options'),
        for (var i = 0; i < p.options.length; i++)
          _OptionRow(
            label: p.options[i],
            rank: choice.contains(i) ? choice.indexOf(i) + 1 : null,
            ranked: p.ranked,
            onTap: !canVote
                ? null
                : () => setState(() {
                      final next = [...choice];
                      if (p.ranked) {
                        if (!next.remove(i)) next.add(i);
                      } else {
                        next
                          ..clear()
                          ..add(i);
                      }
                      _choice = next;
                    }),
          ),
        if (!canVote && open)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: NoticeBox(
              state.isGuest
                  ? 'Guests cannot vote. Register as a member and join ${c.name} to take part.'
                  : 'Only members of ${c.name} can vote.',
              icon: 'lock',
            ),
          ),
        const SectionHeader('Results so far'),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              BarList(
                items: [
                  for (var i = 0; i < p.options.length; i++)
                    (p.options[i], tally.firstChoice[i]),
                ],
                pinkIndex: tally.winner,
              ),
              const SizedBox(height: 10),
              Text(
                [
                  '${plural(tally.totalVotes, 'vote')} of ${p.quorum} for quorum',
                  if (p.ranked) 'bars show first choices',
                ].join(' · '),
                style: text.bodySmall,
              ),
              const SizedBox(height: 10),
              Text(_resultLine(p, tally),
                  style: const TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
        ),
        if (state.canManage(c) && !p.closed) ...[
          const SizedBox(height: 16),
          Builder(
            builder: (anchor) => AppButton(
              label: 'Close and publish outcome',
              icon: 'check',
              kind: AppButtonKind.sky,
              expand: true,
              onTap: () => _close(anchor, p, tally),
            ),
          ),
        ],
      ],
    );
  }

  static bool _same(List<int> a, List<int>? b) {
    if (b == null || a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  static String _resultLine(Proposal p, Tally t) {
    if (t.totalVotes == 0) return 'No votes yet.';
    final lead = t.winner == null
        ? 'Tied.'
        : '${p.ranked ? 'Instant-runoff leader after ${plural(t.rounds, 'round')}' : 'Leading'}: ${p.options[t.winner!]}.';
    return '$lead ${t.quorumMet ? 'Quorum met.' : 'Quorum not yet met.'}';
  }

  Future<void> _close(BuildContext anchor, Proposal p, Tally t) async {
    final state = context.read<AppState>();
    final suggested = !t.quorumMet
        ? 'No decision: quorum of ${p.quorum} was not met (${plural(t.totalVotes, 'vote')}).'
        : t.winner == null
            ? 'No decision: the vote was tied.'
            : '"${p.options[t.winner!]}" won with ${plural(t.totalVotes, 'vote')} cast.';
    final note = TextEditingController(text: suggested);
    final ok = await showAppDialog<bool>(
      anchor,
      title: 'Publish outcome',
      message: 'Voting ends and members are notified of this outcome.',
      content: TextField(controller: note, maxLines: 3),
      actions: (dialogContext) => [
        AppButton(
          label: 'Cancel',
          kind: AppButtonKind.soft,
          small: true,
          onTap: () => Navigator.of(dialogContext).pop(false),
        ),
        AppButton(
          label: 'Publish',
          small: true,
          onTap: () => Navigator.of(dialogContext).pop(true),
        ),
      ],
    );
    if (ok == true && mounted) {
      state.closeProposal(p, note.text.trim());
      showToast(context, 'Outcome published.');
    }
  }
}

class _OptionRow extends StatelessWidget {
  const _OptionRow({
    required this.label,
    required this.rank,
    required this.ranked,
    required this.onTap,
  });

  final String label;

  /// Position in the voter's choice, or null when not chosen.
  final int? rank;
  final bool ranked;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final selected = rank != null;
    final duration = AppMotion.of(context, AppMotion.fast);
    final row = AnimatedContainer(
      duration: duration,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: selected ? AppColors.skySoft : AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: selected ? AppColors.sky : AppColors.line, width: 1.4),
      ),
      child: Row(
        children: [
          AnimatedContainer(
            duration: duration,
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? AppColors.pink : AppColors.white,
              shape: BoxShape.circle,
              border: Border.all(
                  color: selected ? AppColors.pink : AppColors.inkFaint,
                  width: 1.6),
            ),
            child: AnimatedSwitcher(
              duration: duration,
              child: !selected
                  ? const SizedBox.shrink()
                  : ranked
                      ? Text('$rank',
                          key: ValueKey(rank),
                          style: const TextStyle(
                              color: AppColors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w700))
                      : const AppIcon('check',
                          size: 14, color: AppColors.white),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label,
                style: const TextStyle(fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
    if (onTap == null) return row;
    return Semantics(
      selected: selected,
      child: Pressable(onTap: onTap, child: row),
    );
  }
}

/// Opens the form for a new proposal or poll.
void showNewProposalSheet(BuildContext context, Community community) {
  showAppSheet<void>(
    context,
    title: 'New proposal or poll',
    builder: (_) => _ProposalForm(
      community: community,
      onDone: () => showToast(context, 'Proposal opened for voting.'),
    ),
  );
}

class _ProposalForm extends StatefulWidget {
  const _ProposalForm({required this.community, required this.onDone});

  final Community community;
  final VoidCallback onDone;

  @override
  State<_ProposalForm> createState() => _ProposalFormState();
}

class _ProposalFormState extends State<_ProposalForm> {
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _options = [TextEditingController(), TextEditingController()];
  bool _ranked = false;
  double _days = 5;
  late double _quorum =
      (widget.community.members.length / 2).ceilToDouble().clamp(1, 50).toDouble();

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    for (final o in _options) {
      o.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final members = widget.community.members.length;
    final filled =
        _options.map((o) => o.text.trim()).where((t) => t.isNotEmpty).toList();
    final ready = _title.text.trim().isNotEmpty && filled.length >= 2;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppField(
          controller: _title,
          label: 'Question or proposal',
          onChanged: (_) => setState(() {}),
        ),
        AppField(controller: _description, label: 'Details', maxLines: 3),
        const FieldLabel('Options'),
        for (var i = 0; i < _options.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: TextField(
              controller: _options[i],
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(hintText: 'Option ${i + 1}'),
            ),
          ),
        if (_options.length < 5)
          AppButton(
            label: 'Add option',
            icon: 'add',
            kind: AppButtonKind.ghost,
            small: true,
            onTap: () =>
                setState(() => _options.add(TextEditingController())),
          ),
        const SizedBox(height: 10),
        ToggleRow(
          title: 'Ranked choice',
          subtitle: 'Voters rank every option; counted by instant runoff.',
          value: _ranked,
          onChanged: (v) => setState(() => _ranked = v),
        ),
        FieldLabel('Deadline: ${plural(_days.round(), 'day')} from now'),
        Slider(
          value: _days,
          min: 1,
          max: 14,
          divisions: 13,
          onChanged: (v) => setState(() => _days = v),
        ),
        FieldLabel(
            'Quorum: ${plural(_quorum.round(), 'vote')} of ${plural(members, 'member')}'),
        Slider(
          value: _quorum.clamp(1, members.toDouble()).toDouble(),
          min: 1,
          max: members < 2 ? 2 : members.toDouble(),
          divisions: members < 2 ? 1 : members - 1,
          onChanged: (v) => setState(() => _quorum = v),
        ),
        const SizedBox(height: 8),
        AppButton(
          label: 'Open for voting',
          expand: true,
          onTap: !ready
              ? null
              : () {
                  final state = context.read<AppState>();
                  state.createProposal(
                    widget.community,
                    title: _title.text.trim(),
                    description: _description.text.trim(),
                    options: filled,
                    ranked: _ranked,
                    deadline:
                        state.now.add(Duration(days: _days.round())),
                    quorum: _quorum.round(),
                  );
                  Navigator.of(context).pop();
                  widget.onDone();
                },
        ),
      ],
    );
  }
}
