import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_motion.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/basics.dart';
import '../../core/widgets/overlays.dart';
import '../../data/models.dart';
import '../../domain/charging_rules.dart';
import '../../state/app_state.dart';
import '../shell/app_shell.dart';

/// Layout for a top-level tab: large title, optional actions, scrolling body.
class TabPage extends StatelessWidget {
  const TabPage({
    super.key,
    required this.title,
    this.subtitle,
    this.actions = const [],
    required this.children,
  });

  final String title;
  final String? subtitle;
  final List<Widget> actions;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    final list = _buildList(context);
    return SafeArea(
      bottom: false,
      // With a backend, pulling down reloads the records.
      child: state.isRemote
          ? RefreshIndicator(
              color: AppColors.pinkDeep,
              onRefresh: state.refresh,
              child: list,
            )
          : list,
    );
  }

  Widget _buildList(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 14, 20, tabBarClearance),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  if (subtitle != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        subtitle!,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                ],
              ),
            ),
            for (final a in actions) ...[const SizedBox(width: 8), a],
          ],
        ),
        const SizedBox(height: 16),
        ...children,
      ],
    );
  }
}

/// Crossfades between the bodies of a segmented view (UI rule 10).
class Swap extends StatelessWidget {
  const Swap({super.key, required this.id, required this.child});

  final Object id;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: AppMotion.of(context, AppMotion.standard),
      reverseDuration: AppMotion.of(
        context,
        AppMotion.exitOf(AppMotion.standard),
      ),
      switchInCurve: AppMotion.enter,
      switchOutCurve: AppMotion.leave,
      layoutBuilder: (current, previous) => Stack(
        alignment: Alignment.topCenter,
        children: [...previous, ?current],
      ),
      child: KeyedSubtree(key: ValueKey(id), child: child),
    );
  }
}

/// Author line with badges: verified owner, and leader or officer of the
/// community the content belongs to.
class AuthorLine extends StatelessWidget {
  const AuthorLine({
    super.key,
    required this.userId,
    required this.at,
    this.community,
  });

  final String userId;
  final DateTime at;
  final Community? community;

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    final user = state.userById(userId);
    final role = community?.members[userId];
    return Row(
      children: [
        Avatar(
          user?.initials ?? '?',
          imageUrl: user?.avatarUrl,
          imageBytes: user?.avatarBytes,
          size: 30,
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            user?.name ?? 'Former member',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ),
        if (user?.isVerified ?? false) ...[
          const SizedBox(width: 6),
          const Tag('Verified owner', tone: Tone.success, icon: 'check'),
        ],
        if (role == GroupRole.leader || role == GroupRole.officer) ...[
          const SizedBox(width: 6),
          Tag(role!.label, tone: Tone.pink),
        ],
        const SizedBox(width: 8),
        Text(timeAgo(at), style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

/// "Helpful" vote button with a count.
class HelpfulButton extends StatelessWidget {
  const HelpfulButton({
    super.key,
    required this.votes,
    required this.type,
    required this.id,
  });

  final Set<String> votes;

  /// What is being voted on: 'discussion', 'reply' or 'review', and its id.
  final String type;
  final String id;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final mine = votes.contains(state.me.id);
    return Pressable(
      onTap: state.canParticipate
          ? () => state.toggleHelpful(votes, type: type, id: id)
          : null,
      label: 'Mark as helpful',
      child: AnimatedContainer(
        duration: AppMotion.of(context, AppMotion.fast),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: mine ? AppColors.pinkSoft : AppColors.skyMist,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppIcon(
              'thumb',
              size: 14,
              color: mine ? AppColors.pinkDeep : AppColors.inkSoft,
            ),
            const SizedBox(width: 6),
            Text(
              'Helpful · ${votes.length}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: mine ? AppColors.pinkDeep : AppColors.inkSoft,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Opens the report-content form for any piece of content.
Future<void> showReportSheet(
  BuildContext context, {
  required String type,
  required String id,
  required String title,
  String? communityId,
}) async {
  const reasons = [
    'Spam or selling',
    'Inaccurate information',
    'Harassment or abuse',
    'Off-topic',
  ];
  final state = context.read<AppState>();
  final reason = await pickOption<String>(
    context,
    title: 'Report content',
    options: reasons,
    label: (r) => r,
  );
  if (reason == null || !context.mounted) return;
  state.reportContent(
    type: type,
    id: id,
    title: title,
    reason: reason,
    communityId: communityId,
  );
  showToast(
    context,
    communityId == null
        ? 'Report sent to the platform administrator.'
        : 'Report sent to the community officers.',
  );
}

/// Start and end points joined by a dashed line with a car, as in the
/// "Active Shipment" card of the inspiration.
class RouteStrip extends StatelessWidget {
  const RouteStrip({super.key, required this.from, required this.to, this.via});

  final String from;
  final String to;
  final String? via;

  @override
  Widget build(BuildContext context) {
    final small = Theme.of(context).textTheme.bodySmall;
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('From', style: small),
                  Text(
                    from,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('To', style: small),
                  Text(
                    to,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 28,
          child: Stack(
            alignment: Alignment.center,
            children: [
              const Positioned.fill(
                child: CustomPaint(painter: _DashPainter()),
              ),
              const Align(alignment: Alignment.centerLeft, child: _Dot()),
              const Align(
                alignment: Alignment.centerRight,
                child: _Dot(filled: true),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                color: AppColors.white,
                child: via == null
                    ? const AppIcon('car', size: 22, color: AppColors.pink)
                    : Tag('Stop: $via', tone: Tone.pink, icon: 'charging'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({this.filled = false});

  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        color: filled ? AppColors.pink : AppColors.white,
        shape: BoxShape.circle,
        border: Border.all(
          color: filled ? AppColors.pink : AppColors.inkFaint,
          width: 2,
        ),
      ),
    );
  }
}

class _DashPainter extends CustomPainter {
  const _DashPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.inkFaint
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    final y = size.height / 2;
    for (var x = 16.0; x < size.width - 16; x += 8) {
      canvas.drawLine(Offset(x, y), Offset(x + 3, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// One pin on the [StationMap].
class MapPin {
  const MapPin({
    required this.lat,
    required this.lng,
    required this.label,
    this.tone = Tone.sky,
    this.onTap,
  });

  final double lat;
  final double lng;
  final String label;
  final Tone tone;
  final VoidCallback? onTap;
}

/// Schematic map of stations around the driver.
///
/// This stands in for the Google Maps view in the proposal, which needs a
/// Maps Platform key. It places pins by latitude and longitude so the screens
/// and interactions are already in place when the real map replaces it.
class StationMap extends StatelessWidget {
  const StationMap({
    super.key,
    required this.pins,
    required this.me,
    this.route = const [],
    this.height = 210,
  });

  final List<MapPin> pins;
  final Place me;

  /// Points of a route to draw as a dashed line.
  final List<Place> route;
  final double height;

  @override
  Widget build(BuildContext context) {
    final lats = [
      me.lat,
      ...pins.map((p) => p.lat),
      ...route.map((p) => p.lat),
    ];
    final lngs = [
      me.lng,
      ...pins.map((p) => p.lng),
      ...route.map((p) => p.lng),
    ];
    final minLat = lats.reduce(math.min), maxLat = lats.reduce(math.max);
    final minLng = lngs.reduce(math.min), maxLng = lngs.reduce(math.max);
    final midLat = (minLat + maxLat) / 2, midLng = (minLng + maxLng) / 2;
    // Kilometers per degree, so both axes use the same scale.
    final kx = 111.32 * math.cos(midLat * math.pi / 180);
    const ky = 110.57;
    final spanX = math.max((maxLng - minLng) * kx, 2.0);
    final spanY = math.max((maxLat - minLat) * ky, 2.0);

    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: SizedBox(
        height: height,
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Leaves room at the bottom for the caption.
            const pad = 26.0, padBottom = 46.0;
            final w = constraints.maxWidth - pad * 2;
            final h = height - pad - padBottom;
            final scale = math.min(w / spanX, h / spanY);
            Offset at(double lat, double lng) => Offset(
              pad + w / 2 + (lng - midLng) * kx * scale,
              pad + h / 2 - (lat - midLat) * ky * scale,
            );
            final here = at(me.lat, me.lng);
            return Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _MapPainter([
                      for (final p in route) at(p.lat, p.lng),
                    ]),
                  ),
                ),
                for (final pin in pins)
                  Positioned(
                    left: at(pin.lat, pin.lng).dx - 15,
                    top: at(pin.lat, pin.lng).dy - 15,
                    child: Pressable(
                      onTap: pin.onTap,
                      label: pin.label,
                      child: _PinDot(tone: pin.tone),
                    ),
                  ),
                Positioned(
                  left: here.dx - 9,
                  top: here.dy - 9,
                  child: Semantics(
                    label: 'Your location',
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        color: AppColors.ink,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.white, width: 3),
                      ),
                    ),
                  ),
                ),
                const Positioned(
                  left: 10,
                  bottom: 10,
                  child: Tag('Schematic map', tone: Tone.neutral),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _PinDot extends StatelessWidget {
  const _PinDot({required this.tone});

  final Tone tone;

  @override
  Widget build(BuildContext context) {
    final color = switch (tone) {
      Tone.success => AppColors.success,
      Tone.danger => AppColors.danger,
      Tone.pink => AppColors.pink,
      Tone.neutral => AppColors.inkFaint,
      _ => AppColors.skyDeep,
    };
    return Container(
      width: 30,
      height: 30,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.white,
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 2),
        boxShadow: [
          BoxShadow(
            color: AppColors.ink.withValues(alpha: 0.12),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: AppIcon('charging', size: 14, color: color),
    );
  }
}

class _MapPainter extends CustomPainter {
  _MapPainter(this.route);

  final List<Offset> route;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = AppColors.skySoft);
    final road = Paint()
      ..color = AppColors.white
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round;
    // Abstract road grid, only to give the pins some context.
    for (var i = 1; i < 4; i++) {
      final y = size.height * i / 4;
      canvas.drawLine(
        Offset(0, y + i * 6),
        Offset(size.width, y - i * 8),
        road,
      );
      final x = size.width * i / 4;
      canvas.drawLine(
        Offset(x - i * 10, 0),
        Offset(x + i * 6, size.height),
        road,
      );
    }
    if (route.length > 1) {
      final line = Paint()
        ..color = AppColors.pink
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round;
      for (var i = 0; i < route.length - 1; i++) {
        final a = route[i], b = route[i + 1];
        final length = (b - a).distance;
        for (var d = 0.0; d < length; d += 10) {
          final start = a + (b - a) * (d / length);
          final end =
              a + (b - a) * ((d + 5).clamp(0.0, length).toDouble() / length);
          canvas.drawLine(start, end, line);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _MapPainter old) => old.route != route;
}

/// Tone and label for a station's latest condition.
Tone conditionTone(StationCondition c) => switch (c) {
  StationCondition.working => Tone.success,
  StationCondition.unknown => Tone.neutral,
  StationCondition.notWorking => Tone.danger,
};

/// Reviews of a station or provider with a "write a review" action.
class ReviewSection extends StatelessWidget {
  const ReviewSection({
    super.key,
    required this.target,
    required this.targetId,
    required this.tags,
  });

  final ReviewTarget target;
  final String targetId;
  final List<String> tags;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final list = state.reviewsFor(target, targetId);
    final rating = state.ratingFor(target, targetId);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          'Reviews',
          action: state.canParticipate ? 'Write a review' : null,
          onAction: () => _write(context),
        ),
        if (list.isEmpty)
          const EmptyState(
            icon: 'star',
            title: 'No reviews yet',
            message: 'Reviews from members appear here with their tags.',
          )
        else ...[
          Row(
            children: [
              Text(
                rating.toStringAsFixed(1),
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 10),
              Stars(rating, size: 16),
              const SizedBox(width: 8),
              Text(
                plural(list.length, 'review'),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (final (i, r) in list.indexed)
            FadeIn(
              index: i,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AuthorLine(userId: r.authorId, at: r.createdAt),
                      const SizedBox(height: 10),
                      Stars(r.rating.toDouble()),
                      const SizedBox(height: 8),
                      Text(r.body),
                      if (r.tags.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [for (final t in r.tags) Tag(t)],
                        ),
                      ],
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          HelpfulButton(
                            votes: r.helpful,
                            type: 'review',
                            id: r.id,
                          ),
                          const Spacer(),
                          Pressable(
                            onTap: () => showReportSheet(
                              context,
                              type: 'review',
                              id: r.id,
                              title: 'Review by ${state.userName(r.authorId)}',
                            ),
                            label: 'Report this review',
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
      ],
    );
  }

  void _write(BuildContext context) {
    showAppSheet<void>(
      context,
      title: 'Write a review',
      builder: (_) => _ReviewForm(
        tags: tags,
        onSubmit: (rating, chosen, body) {
          context.read<AppState>().addReview(
            target,
            targetId,
            rating,
            chosen,
            body,
          );
          showToast(context, 'Review posted.');
        },
      ),
    );
  }
}

class _ReviewForm extends StatefulWidget {
  const _ReviewForm({required this.tags, required this.onSubmit});

  final List<String> tags;
  final void Function(int rating, List<String> tags, String body) onSubmit;

  @override
  State<_ReviewForm> createState() => _ReviewFormState();
}

class _ReviewFormState extends State<_ReviewForm> {
  final _body = TextEditingController();
  int _rating = 0;
  final _chosen = <String>{};

  @override
  void dispose() {
    _body.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ready = _rating > 0 && _body.text.trim().isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const FieldLabel('Rating'),
        Stars(
          _rating.toDouble(),
          size: 30,
          onChanged: (v) => setState(() => _rating = v),
        ),
        const SizedBox(height: 16),
        const FieldLabel('Tags'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final t in widget.tags)
              ChoicePill(
                label: t,
                selected: _chosen.contains(t),
                onTap: () => setState(() {
                  if (!_chosen.remove(t)) _chosen.add(t);
                }),
              ),
          ],
        ),
        const SizedBox(height: 16),
        AppField(
          controller: _body,
          label: 'Your experience',
          hint: 'What should other owners know?',
          maxLines: 4,
          onChanged: (_) => setState(() {}),
        ),
        AppButton(
          label: 'Post review',
          expand: true,
          onTap: ready
              ? () {
                  Navigator.of(context).pop();
                  widget.onSubmit(_rating, _chosen.toList(), _body.text.trim());
                }
              : null,
        ),
      ],
    );
  }
}
