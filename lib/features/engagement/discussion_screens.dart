import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_motion.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/basics.dart';
import '../../core/widgets/overlays.dart';
import '../../data/models.dart';
import '../../data/seed_data.dart';
import '../../state/app_state.dart';
import '../shared/shared_widgets.dart';

/// M2: discussion summary in the community feed.
class DiscussionCard extends StatelessWidget {
  const DiscussionCard({
    super.key,
    required this.discussion,
    required this.community,
  });

  final Discussion discussion;
  final Community community;

  @override
  Widget build(BuildContext context) {
    final d = discussion;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        onTap: () =>
            pushScreen(context, DiscussionDetailScreen(discussionId: d.id)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AuthorLine(
              userId: d.authorId,
              at: d.createdAt,
              community: community,
            ),
            const SizedBox(height: 10),
            Text(d.title, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 4),
            Text(
              d.body,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppColors.inkSoft, fontSize: 13.5),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      Tag(d.topic),
                      if (d.isQuestion) const Tag('Question', tone: Tone.pink),
                      if (d.vehicleModel != null)
                        Tag(d.vehicleModel!, tone: Tone.neutral, icon: 'car'),
                    ],
                  ),
                ),
                const AppIcon('chat', size: 15, color: AppColors.inkFaint),
                const SizedBox(width: 4),
                Text(
                  '${d.replies.length}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(width: 12),
                const AppIcon('thumb', size: 15, color: AppColors.inkFaint),
                const SizedBox(width: 4),
                Text(
                  '${d.helpful.length}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class DiscussionDetailScreen extends StatefulWidget {
  const DiscussionDetailScreen({super.key, required this.discussionId});

  final String discussionId;

  @override
  State<DiscussionDetailScreen> createState() => _DiscussionDetailScreenState();
}

class _DiscussionDetailScreenState extends State<DiscussionDetailScreen> {
  final _reply = TextEditingController();

  @override
  void dispose() {
    _reply.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final d = state.discussions
        .where((x) => x.id == widget.discussionId)
        .firstOrNull;
    if (d == null) {
      return const DetailScaffold(
        title: 'Discussion',
        children: [
          EmptyState(icon: 'chat', title: 'This discussion was removed'),
        ],
      );
    }
    final c = state.communityById(d.communityId);
    final canReply = state.canParticipate && c != null && state.isMemberOf(c);
    // Most helpful replies first, then oldest first.
    final replies = [...d.replies]
      ..sort((a, b) {
        final byVotes = b.helpful.length.compareTo(a.helpful.length);
        return byVotes != 0 ? byVotes : a.createdAt.compareTo(b.createdAt);
      });

    return DetailScaffold(
      title: d.isQuestion ? 'Question' : 'Discussion',
      actions: [
        IconSquare(
          icon: 'flag',
          label: 'Report this discussion',
          onTap: () => showReportSheet(
            context,
            type: 'discussion',
            id: d.id,
            title: '"${d.title}" by ${state.userName(d.authorId)}',
            communityId: d.communityId,
          ),
        ),
      ],
      bottom: canReply
          ? Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _reply,
                    minLines: 1,
                    maxLines: 3,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      hintText: 'Write a reply',
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                AppButton(
                  label: 'Reply',
                  onTap: _reply.text.trim().isEmpty
                      ? null
                      : () {
                          state.addReply(d, _reply.text.trim());
                          _reply.clear();
                          FocusScope.of(context).unfocus();
                          setState(() {});
                        },
                ),
              ],
            )
          : null,
      children: [
        AuthorLine(userId: d.authorId, at: d.createdAt, community: c),
        const SizedBox(height: 14),
        Text(d.title, style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 10),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            Tag(d.topic),
            if (d.isQuestion) const Tag('Question', tone: Tone.pink),
            if (d.vehicleModel != null)
              Tag(d.vehicleModel!, tone: Tone.neutral, icon: 'car'),
          ],
        ),
        const SizedBox(height: 14),
        Text(d.body, style: Theme.of(context).textTheme.bodyLarge),
        const SizedBox(height: 14),
        Align(
          alignment: Alignment.centerLeft,
          child: HelpfulButton(votes: d.helpful, type: 'discussion', id: d.id),
        ),
        SectionHeader(plural(replies.length, 'reply', 'replies')),
        if (replies.isEmpty)
          EmptyState(
            icon: 'chat',
            title: 'No replies yet',
            message: canReply
                ? 'Be the first to answer.'
                : 'Members of this group can reply.',
          ),
        for (final (i, r) in replies.indexed)
          FadeIn(
            key: ValueKey(r.id),
            index: i,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AuthorLine(
                      userId: r.authorId,
                      at: r.createdAt,
                      community: c,
                    ),
                    const SizedBox(height: 10),
                    Text(r.body),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        HelpfulButton(
                          votes: r.helpful,
                          type: 'reply',
                          id: r.id,
                        ),
                        const Spacer(),
                        Pressable(
                          label: 'Report this reply',
                          onTap: () => showReportSheet(
                            context,
                            type: 'reply',
                            id: r.id,
                            title:
                                'Reply by ${state.userName(r.authorId)} in "${d.title}"',
                            communityId: d.communityId,
                          ),
                          child: const Padding(
                            padding: EdgeInsets.all(6),
                            child: AppIcon(
                              'flag',
                              size: 16,
                              color: AppColors.inkFaint,
                            ),
                          ),
                        ),
                      ],
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

/// Opens the form for a new announcement (leaders and officers) or a new
/// discussion (members).
void showNewPostSheet(
  BuildContext context,
  Community community, {
  required bool announcement,
}) {
  showAppSheet<void>(
    context,
    title: announcement ? 'New announcement' : 'New post',
    builder: (_) => _PostForm(
      community: community,
      announcement: announcement,
      onDone: (message) => showToast(context, message),
    ),
  );
}

class _PostForm extends StatefulWidget {
  const _PostForm({
    required this.community,
    required this.announcement,
    required this.onDone,
  });

  final Community community;
  final bool announcement;
  final ValueChanged<String> onDone;

  @override
  State<_PostForm> createState() => _PostFormState();
}

class _PostFormState extends State<_PostForm> {
  final _title = TextEditingController();
  final _body = TextEditingController();
  String _topic = SeedData.topics.first;
  bool _flag = false; // pinned for announcements, question for discussions
  bool _tagModel = false;

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    final vehicle = state.me.vehicle;
    final ready = _title.text.trim().isNotEmpty && _body.text.trim().isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppField(
          controller: _title,
          label: 'Title',
          onChanged: (_) => setState(() {}),
        ),
        AppField(
          controller: _body,
          label: widget.announcement ? 'Message' : 'Details',
          maxLines: 5,
          onChanged: (_) => setState(() {}),
        ),
        if (widget.announcement)
          ToggleRow(
            title: 'Pin to the top',
            subtitle: 'Pinned announcements also show on members\' Home.',
            value: _flag,
            onChanged: (v) => setState(() => _flag = v),
          )
        else ...[
          const FieldLabel('Topic'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final t in SeedData.topics)
                ChoicePill(
                  label: t,
                  selected: t == _topic,
                  onTap: () => setState(() => _topic = t),
                ),
            ],
          ),
          const SizedBox(height: 14),
          ToggleRow(
            title: 'This is a question',
            value: _flag,
            onChanged: (v) => setState(() => _flag = v),
          ),
          if (vehicle != null)
            ToggleRow(
              title: 'Tag my vehicle model',
              subtitle: vehicle.name,
              value: _tagModel,
              onChanged: (v) => setState(() => _tagModel = v),
            ),
        ],
        const SizedBox(height: 6),
        AppButton(
          label: widget.announcement ? 'Post announcement' : 'Post',
          expand: true,
          onTap: !ready
              ? null
              : () {
                  if (widget.announcement) {
                    state.postAnnouncement(
                      widget.community,
                      _title.text.trim(),
                      _body.text.trim(),
                      pinned: _flag,
                    );
                  } else {
                    state.postDiscussion(
                      widget.community,
                      title: _title.text.trim(),
                      body: _body.text.trim(),
                      topic: _topic,
                      isQuestion: _flag,
                      vehicleModel: _tagModel ? vehicle?.name : null,
                    );
                  }
                  Navigator.of(context).pop();
                  widget.onDone(
                    widget.announcement
                        ? 'Announcement posted. Members were notified.'
                        : 'Posted to ${widget.community.name}.',
                  );
                },
        ),
      ],
    );
  }
}
