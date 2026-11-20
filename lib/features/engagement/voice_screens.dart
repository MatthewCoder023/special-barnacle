import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_motion.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/basics.dart';
import '../../core/widgets/overlays.dart';
import '../../data/models.dart';
import '../../data/seed_data.dart';
import '../../state/app_state.dart';
import '../charging/station_detail_screen.dart';
import '../shared/shared_widgets.dart';

/// M2 Community Voice: one concern on the board. The card expands in place
/// to show its details instead of opening a separate screen (UI rule 12).
class ConcernCard extends StatefulWidget {
  const ConcernCard({super.key, required this.concern});

  final Concern concern;

  @override
  State<ConcernCard> createState() => _ConcernCardState();
}

class _ConcernCardState extends State<ConcernCard> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final k = widget.concern;
    final c = state.communityById(k.communityId);
    final station = state.stationById(k.stationId);
    final mine = k.supporters.contains(state.me.id);
    final canSupport = state.canParticipate && c != null && state.isMemberOf(c);
    final duration = AppMotion.of(context, AppMotion.standard);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        onTap: () => setState(() => _open = !_open),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        k.title,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          Tag(k.category),
                          Tag(k.location, tone: Tone.neutral, icon: 'pin'),
                          if (k.hasPhoto)
                            const Tag(
                              'Photo',
                              tone: Tone.neutral,
                              icon: 'camera',
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Pressable(
                  onTap: canSupport ? () => state.toggleSupport(k) : null,
                  label: mine ? 'Withdraw support' : 'Support this concern',
                  child: AnimatedContainer(
                    duration: AppMotion.of(context, AppMotion.fast),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: mine ? AppColors.pink : AppColors.pinkSoft,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      children: [
                        Text(
                          '+${k.supporters.length}',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: mine ? AppColors.white : AppColors.pinkDeep,
                          ),
                        ),
                        Text(
                          mine ? 'Supported' : 'Support',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: mine ? AppColors.white : AppColors.pinkDeep,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            AnimatedSize(
              duration: duration,
              curve: AppMotion.move,
              alignment: Alignment.topCenter,
              child: !_open
                  ? const SizedBox(width: double.infinity)
                  : Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            k.details,
                            style: const TextStyle(color: AppColors.inkSoft),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Filed by ${state.userName(k.authorId)} · ${fmtDate(k.createdAt)}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          if (k.hasPhoto)
                            Container(
                              margin: const EdgeInsets.only(top: 10),
                              height: 90,
                              width: double.infinity,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: AppColors.skyMist,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: AppColors.line),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  AppIcon(
                                    'camera',
                                    size: 18,
                                    color: AppColors.inkFaint,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    'Evidence photo attached',
                                    style: TextStyle(
                                      color: AppColors.inkSoft,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              if (station != null)
                                AppButton(
                                  label: station.name,
                                  icon: 'charging',
                                  kind: AppButtonKind.soft,
                                  small: true,
                                  onTap: () => pushScreen(
                                    context,
                                    StationDetailScreen(stationId: station.id),
                                  ),
                                ),
                              const Spacer(),
                              Pressable(
                                label: 'Report this concern',
                                onTap: () => showReportSheet(
                                  context,
                                  type: 'concern',
                                  id: k.id,
                                  title:
                                      'Concern "${k.title}" by ${state.userName(k.authorId)}',
                                  communityId: k.communityId,
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
          ],
        ),
      ),
    );
  }
}

/// Opens the form to file a concern.
void showFileConcernSheet(BuildContext context, Community community) {
  showAppSheet<void>(
    context,
    title: 'File a concern',
    builder: (_) => _ConcernForm(
      community: community,
      onDone: () => showToast(context, 'Concern filed on the board.'),
    ),
  );
}

class _ConcernForm extends StatefulWidget {
  const _ConcernForm({required this.community, required this.onDone});

  final Community community;
  final VoidCallback onDone;

  @override
  State<_ConcernForm> createState() => _ConcernFormState();
}

class _ConcernFormState extends State<_ConcernForm> {
  final _title = TextEditingController();
  final _details = TextEditingController();
  final _location = TextEditingController();
  String _category = SeedData.concernCategories.first;
  Station? _station;
  bool _photo = false;

  @override
  void dispose() {
    _title.dispose();
    _details.dispose();
    _location.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    final ready =
        _title.text.trim().isNotEmpty &&
        _details.text.trim().isNotEmpty &&
        _location.text.trim().isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const FieldLabel('Category'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final cat in SeedData.concernCategories)
              ChoicePill(
                label: cat,
                selected: cat == _category,
                onTap: () => setState(() => _category = cat),
              ),
          ],
        ),
        const SizedBox(height: 14),
        AppField(
          controller: _title,
          label: 'Concern',
          hint: 'One line that states the problem',
          onChanged: (_) => setState(() {}),
        ),
        AppField(
          controller: _details,
          label: 'Details',
          hint: 'What happened, when and how often',
          maxLines: 4,
          onChanged: (_) => setState(() {}),
        ),
        const FieldLabel('Station (optional)'),
        Builder(
          builder: (anchor) => Pressable(
            onTap: () async {
              final picked = await pickOption<Station>(
                anchor,
                title: 'Link a station',
                options: state.stations,
                label: (s) => s.name,
                subtitle: (s) => s.city,
                selected: _station,
              );
              if (picked != null) {
                setState(() {
                  _station = picked;
                  if (_location.text.trim().isEmpty) {
                    _location.text = picked.city;
                  }
                });
              }
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: AppColors.skyMist,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.line),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _station?.name ?? 'Choose a station',
                      style: TextStyle(
                        color: _station == null
                            ? AppColors.inkFaint
                            : AppColors.ink,
                      ),
                    ),
                  ),
                  const AppIcon('chevron', size: 16, color: AppColors.inkFaint),
                ],
              ),
            ),
          ),
        ),
        AppField(
          controller: _location,
          label: 'Location',
          hint: 'City or area',
          onChanged: (_) => setState(() {}),
        ),
        ToggleRow(
          title: 'Attach an evidence photo',
          subtitle: 'Photo upload connects to Supabase Storage; this marks the concern as having one.',
          value: _photo,
          onChanged: (v) => setState(() => _photo = v),
        ),
        const SizedBox(height: 6),
        AppButton(
          label: 'File concern',
          expand: true,
          onTap: !ready
              ? null
              : () {
                  state.fileConcern(
                    widget.community,
                    category: _category,
                    title: _title.text.trim(),
                    details: _details.text.trim(),
                    location: _location.text.trim(),
                    stationId: _station?.id,
                    hasPhoto: _photo,
                  );
                  Navigator.of(context).pop();
                  widget.onDone();
                },
        ),
      ],
    );
  }
}

/// Leader tool: compile concerns into a dated position summary with counts,
/// locations and linked station reports, then publish or share it.
class CompileSummaryScreen extends StatefulWidget {
  const CompileSummaryScreen({super.key, required this.communityId});

  final String communityId;

  @override
  State<CompileSummaryScreen> createState() => _CompileSummaryScreenState();
}

class _CompileSummaryScreenState extends State<CompileSummaryScreen> {
  int _category = 0;
  final _title = TextEditingController();
  final _ask = TextEditingController();

  @override
  void dispose() {
    _title.dispose();
    _ask.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final c = state.communityById(widget.communityId)!;
    final categories = ['All', ...SeedData.concernCategories];
    final category = categories[_category];
    final concerns = state
        .concernsOf(c.id)
        .where((k) => _category == 0 || k.category == category)
        .toList();

    final supporters = <String>{for (final k in concerns) ...k.supporters};
    final byLocation = <String, int>{};
    for (final k in concerns) {
      byLocation[k.location] = (byLocation[k.location] ?? 0) + 1;
    }
    final locations = byLocation.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // Station reports linked through the concerns' stations (last 30 days).
    final stationLines = <String>[];
    for (final id in {for (final k in concerns) ?k.stationId}) {
      final s = state.stationById(id);
      if (s == null) continue;
      final recent = s.reports.where(
        (r) => state.now.difference(r.createdAt).inDays <= 30,
      );
      final down = recent.where((r) => !r.working).length;
      stationLines.add(
        '${s.name}: $down of ${plural(recent.length, 'status report')} in the last 30 days said not working',
      );
    }

    final text = StringBuffer()
      ..writeln('Position of ${c.name}')
      ..writeln('Date: ${fmtDate(state.now)}')
      ..writeln('Subject: ${category == 'All' ? 'Member concerns' : category}')
      ..writeln()
      ..writeln(
        '${plural(concerns.length, 'concern')} filed by members, supported by ${plural(supporters.length, 'member')} of ${c.memberCount}.',
      )
      ..writeln()
      ..writeln('Locations affected:');
    for (final l in locations) {
      text.writeln('- ${l.key}: ${plural(l.value, 'concern')}');
    }
    text
      ..writeln()
      ..writeln('Concerns:');
    for (final k in concerns) {
      text.writeln(
        '- ${k.title} (${k.location}, ${plural(k.supporters.length, 'supporter')})',
      );
    }
    if (stationLines.isNotEmpty) {
      text
        ..writeln()
        ..writeln('Linked station reports:');
      for (final line in stationLines) {
        text.writeln('- $line');
      }
    }
    if (_ask.text.trim().isNotEmpty) {
      text
        ..writeln()
        ..writeln('What we ask: ${_ask.text.trim()}');
    }
    final body = text.toString().trim();
    final title = _title.text.trim().isEmpty
        ? '${category == 'All' ? 'Member concerns' : category}, ${fmtDate(state.now)}'
        : _title.text.trim();

    return DetailScaffold(
      title: 'Position summary',
      bottom: Row(
        children: [
          Expanded(
            child: AppButton(
              label: 'Copy to share',
              icon: 'copy',
              kind: AppButtonKind.soft,
              onTap: concerns.isEmpty
                  ? null
                  : () async {
                      await Clipboard.setData(ClipboardData(text: body));
                      if (context.mounted) {
                        showToast(context, 'Summary copied.');
                      }
                    },
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: AppButton(
              label: 'Publish',
              icon: 'check',
              onTap: concerns.isEmpty
                  ? null
                  : () {
                      state.publishSummary(
                        c,
                        title,
                        category,
                        body,
                        concerns.length,
                        supporters.length,
                      );
                      Navigator.of(context).pop();
                      showToast(
                        context,
                        'Summary published. Members were notified.',
                      );
                    },
            ),
          ),
        ],
      ),
      children: [
        const FieldLabel('Concerns to include'),
        PillRow(
          padding: EdgeInsets.zero,
          labels: categories,
          index: _category,
          onChanged: (i) => setState(() => _category = i),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: StatTile(
                icon: 'megaphone',
                value: '${concerns.length}',
                label: 'Concerns',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: StatTile(
                icon: 'community',
                value: '${supporters.length}',
                label: 'Members affected',
                pink: true,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: StatTile(
                icon: 'pin',
                value: '${locations.length}',
                label: 'Locations',
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        AppField(
          controller: _title,
          label: 'Title',
          hint: title,
          onChanged: (_) => setState(() {}),
        ),
        AppField(
          controller: _ask,
          label: 'What the community asks for',
          hint: 'e.g. Post outage notices at the unit and in the app',
          maxLines: 3,
          onChanged: (_) => setState(() {}),
        ),
        const FieldLabel('Preview'),
        if (concerns.isEmpty)
          const EmptyState(
            icon: 'megaphone',
            title: 'No concerns in this category',
          )
        else
          AppCard(
            color: AppColors.skyMist,
            child: Text(body, style: const TextStyle(fontSize: 13.5)),
          ),
      ],
    );
  }
}

/// A published position summary, with a copy action for sharing.
class SummaryScreen extends StatelessWidget {
  const SummaryScreen({super.key, required this.summary});

  final PositionSummary summary;

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    final s = summary;
    return DetailScaffold(
      title: 'Position summary',
      bottom: AppButton(
        label: 'Copy to share',
        icon: 'copy',
        expand: true,
        onTap: () async {
          await Clipboard.setData(ClipboardData(text: s.text));
          if (context.mounted) showToast(context, 'Summary copied.');
        },
      ),
      children: [
        Text(s.title, style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 8),
        Text(
          'Published ${fmtDate(s.createdAt)} by ${state.userName(s.authorId)}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            Tag(s.category),
            Tag(plural(s.concernCount, 'concern'), tone: Tone.neutral),
            Tag(plural(s.supportCount, 'supporter'), tone: Tone.pink),
          ],
        ),
        const SizedBox(height: 16),
        AppCard(color: AppColors.skyMist, child: Text(s.text)),
      ],
    );
  }
}
