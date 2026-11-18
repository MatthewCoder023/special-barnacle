import 'package:image_picker/image_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_motion.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/basics.dart';
import '../../core/widgets/overlays.dart';
import '../../data/models.dart';
import '../../data/remote/remote_store.dart';
import '../../domain/charging_rules.dart';
import '../../state/app_state.dart';
import '../community/community_detail_screen.dart';
import '../engagement/discussion_screens.dart';
import '../events/event_detail_screen.dart';

// ───────────────────────────── Profile photo ─────────────────────────────

/// Opens a menu on the control behind [anchor] to choose or remove the
/// profile photo. The photo is resized on the device before it is stored.
Future<void> changePhoto(BuildContext anchor) async {
  final state = anchor.read<AppState>();
  final hasPhoto = state.me.avatarUrl != null || state.me.avatarBytes != null;
  final choice = await showAppMenu<String>(anchor, [
    const AppMenuItem('choose', 'Choose a photo', icon: 'camera'),
    if (hasPhoto)
      const AppMenuItem('remove', 'Remove photo', icon: 'close', danger: true),
  ]);
  if (choice == null || !anchor.mounted) return;
  try {
    if (choice == 'remove') {
      await state.removeAvatar();
      if (anchor.mounted) showToast(anchor, 'Photo removed.');
      return;
    }
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 600,
      maxHeight: 600,
      imageQuality: 82,
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    await state.setAvatar(bytes, contentType: file.mimeType ?? 'image/jpeg');
    if (anchor.mounted) showToast(anchor, 'Profile photo updated.');
  } on RemoteException catch (e) {
    if (anchor.mounted) showToast(anchor, e.message, success: false);
  } catch (_) {
    if (anchor.mounted) {
      showToast(anchor, 'Could not open your photos.', success: false);
    }
  }
}

// ───────────────────────────── Edit profile ─────────────────────────────

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late final AppUser _me = context.read<AppState>().me;
  late final _name = TextEditingController(text: _me.name);
  late final _username = TextEditingController(text: _me.username ?? '');
  late final _region = TextEditingController(text: _me.region);
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _username.dispose();
    _region.dispose();
    super.dispose();
  }

  void _save() {
    final error = context.read<AppState>().updateProfile(
          name: _name.text.trim(),
          username: _username.text,
          region: _region.text.trim(),
        );
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    Navigator.of(context).pop();
    showToast(context, 'Profile saved.');
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final me = state.me;
    final ready = _name.text.trim().length >= 2;
    final hasPhoto = me.avatarUrl != null || me.avatarBytes != null;
    return DetailScaffold(
      title: 'Edit profile',
      bottom: AppButton(
        label: 'Save',
        expand: true,
        onTap: ready ? _save : null,
      ),
      children: [
        Center(
          child: Avatar(
            me.initials,
            size: 96,
            imageUrl: me.avatarUrl,
            imageBytes: me.avatarBytes,
          ),
        ),
        const SizedBox(height: 10),
        Center(
          child: Builder(
            builder: (anchor) => AppButton(
              label: hasPhoto ? 'Change photo' : 'Add a photo',
              icon: 'camera',
              kind: AppButtonKind.ghost,
              small: true,
              onTap: () => changePhoto(anchor),
            ),
          ),
        ),
        const SizedBox(height: 14),
        if (_error != null) ...[
          NoticeBox(_error!, tone: Tone.danger, icon: 'alert'),
          const SizedBox(height: 14),
        ],
        AppField(
          controller: _name,
          label: 'Display name',
          hint: 'Shown on your posts and reviews',
          onChanged: (_) => setState(() {}),
        ),
        AppField(
          controller: _username,
          label: 'Username (optional)',
          hint: '3 to 20 letters, digits or underscores',
          onChanged: (_) => setState(() => _error = null),
        ),
        AppField(
          controller: _region,
          label: 'City or region',
          hint: 'e.g. Makati, Metro Manila',
        ),
        Text(
          'EVYAHE keeps only what its features use: your name on posts, and your city for regional communities.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

// ──────────────────────────────── My EV ────────────────────────────────

/// The user's vehicle, its specifications, charging preferences and
/// ownership verification.
class VehicleScreen extends StatelessWidget {
  const VehicleScreen({super.key});

  Future<void> _choose(BuildContext context) async {
    final state = context.read<AppState>();
    final current = state.me.vehicle;
    final picked = await pickOption<Vehicle>(
      context,
      title: 'Your vehicle',
      options: state.vehicleCatalog,
      label: (v) => v.name,
      subtitle: (v) =>
          '${v.type.label} · ${v.batteryKwh} kWh · ${v.connectors.map((c) => c.label).join(', ')}',
      selected: state.vehicleCatalog
          .where((v) => v.name == current?.name)
          .firstOrNull,
    );
    if (picked == null || !context.mounted) return;
    final changed = picked.name != current?.name;
    state.setVehicle(picked);
    if (changed) {
      showToast(
        context,
        current == null
            ? 'Vehicle added.'
            : 'Vehicle changed. Ownership needs to be verified again.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final me = state.me;
    final v = me.vehicle;
    final text = Theme.of(context).textTheme;
    return DetailScaffold(
      title: 'My EV',
      children: [
        Builder(
          builder: (anchor) => AppCard(
            color: AppColors.sky,
            onTap: () => _choose(anchor),
            child: Row(
              children: [
                const AppIcon('car', size: 24),
                const SizedBox(width: 14),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: AppMotion.of(context, AppMotion.standard),
                    layoutBuilder: (current, previous) => Stack(
                      alignment: Alignment.centerLeft,
                      children: [...previous, ?current],
                    ),
                    child: Column(
                      key: ValueKey(v?.name),
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(v?.name ?? 'Add your vehicle',
                            style: text.titleMedium),
                        Text(
                          v == null
                              ? 'Needed for range, compatible chargers and event route checks'
                              : 'Tap to change',
                          style: const TextStyle(fontSize: 12.5),
                        ),
                      ],
                    ),
                  ),
                ),
                const AppIcon('edit', size: 17),
              ],
            ),
          ),
        ),
        if (v != null) ...[
          const SectionHeader('Specifications'),
          AppCard(
            child: Column(
              children: [
                _Spec('Type', switch (v.type) {
                  VehicleType.bev => 'Battery electric (BEV)',
                  VehicleType.phev => 'Plug-in hybrid (PHEV)',
                  VehicleType.reev => 'Range-extended (REEV)',
                }),
                _Spec('Battery capacity', '${v.batteryKwh} kWh'),
                _Spec('Rated energy use',
                    '${(v.kwhPerKm * 100).toStringAsFixed(1)} kWh per 100 km'),
                _Spec('Rated range',
                    '${v.fullRangeKm.round()} km${v.hasEngine ? ' electric' : ''}'),
                _Spec('Connectors',
                    v.connectors.map((c) => c.label).join(', '),
                    last: true),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              'Specifications come from the reference list for this model. BEV, PHEV and REEV are supported; conventional hybrids are outside the study scope.',
              style: text.bodySmall,
            ),
          ),
          const SectionHeader('Charging preferences'),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FieldLabel('Charge to ${me.chargeToPct}% at a stop'),
                Slider(
                  value: me.chargeToPct.toDouble(),
                  min: 50,
                  max: 100,
                  divisions: 10,
                  semanticFormatterCallback: (x) =>
                      'Charge to ${x.round()} percent',
                  onChanged: (x) =>
                      state.setChargingPrefs(chargeToPct: x.round()),
                ),
                FieldLabel(
                    'Safety reserve: ${me.reservePct}% · about ${ChargingRules.remainingRangeKm(v, me.reservePct.toDouble()).round()} km'),
                Slider(
                  value: me.reservePct.toDouble(),
                  min: 0,
                  max: 30,
                  divisions: 6,
                  semanticFormatterCallback: (x) =>
                      '${x.round()} percent reserve',
                  onChanged: (x) =>
                      state.setChargingPrefs(reservePct: x.round()),
                ),
                Text(
                  'Route planning keeps the reserve in hand at every stop and on arrival, and assumes you charge to the level above.',
                  style: text.bodySmall,
                ),
              ],
            ),
          ),
        ],
        if (me.role == PlatformRole.member && v != null) ...[
          const SectionHeader('Ownership verification'),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AnimatedSwitcher(
                  duration: AppMotion.of(context, AppMotion.standard),
                  child: Tag(
                    me.verification.label,
                    key: ValueKey(me.verification),
                    tone: switch (me.verification) {
                      VerificationStatus.verified => Tone.success,
                      VerificationStatus.pending => Tone.warning,
                      VerificationStatus.rejected => Tone.danger,
                      VerificationStatus.none => Tone.neutral,
                    },
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  switch (me.verification) {
                    VerificationStatus.verified =>
                      'Your posts and reviews show the verified-owner label, and you can join groups that require it.',
                    VerificationStatus.pending =>
                      'The platform administrator is reviewing your proof. The document is deleted after the decision.',
                    _ =>
                      'Some communities and tribes admit verified owners only. Submit minimal proof of ownership, such as the name and plate lines of your registration.',
                  },
                  style: const TextStyle(
                      fontSize: 13.5, color: AppColors.inkSoft),
                ),
                if (me.verification == VerificationStatus.none ||
                    me.verification == VerificationStatus.rejected) ...[
                  const SizedBox(height: 12),
                  AppButton(
                    label: 'Submit proof of ownership',
                    icon: 'document',
                    kind: AppButtonKind.sky,
                    small: true,
                    onTap: () {
                      state.submitVerification();
                      showToast(context, 'Proof submitted for review.');
                    },
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Document upload is not connected yet. This records the request only.',
                    style: text.bodySmall,
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _Spec extends StatelessWidget {
  const _Spec(this.label, this.value, {this.last = false});

  final String label;
  final String value;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      fontSize: 13.5, color: AppColors.inkSoft)),
              const SizedBox(width: 16),
              Expanded(
                child: Text(value,
                    textAlign: TextAlign.right,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
        if (!last) const Divider(),
      ],
    );
  }
}

// ─────────────────────── Communities and activity ───────────────────────

class MyActivityScreen extends StatefulWidget {
  const MyActivityScreen({super.key});

  @override
  State<MyActivityScreen> createState() => _MyActivityScreenState();
}

class _MyActivityScreenState extends State<MyActivityScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final groups = [...state.myGroups, ...state.myPendingCommunities];
    final posts = state.myDiscussions;
    final reviews = state.myReviews;
    final concerns = state.myConcerns;
    final events = state.myEvents;
    final text = Theme.of(context).textTheme;

    return DetailScaffold(
      title: 'Communities and activity',
      children: [
        SegmentedTabs(
          labels: const ['Memberships', 'Activity'],
          index: _tab,
          onChanged: (i) => setState(() => _tab = i),
        ),
        const SizedBox(height: 16),
        AnimatedSwitcher(
          duration: AppMotion.of(context, AppMotion.standard),
          switchInCurve: AppMotion.enter,
          switchOutCurve: AppMotion.leave,
          layoutBuilder: (current, previous) => Stack(
            alignment: Alignment.topCenter,
            children: [...previous, ?current],
          ),
          child: _tab == 0
              ? Column(
                  key: const ValueKey('memberships'),
                  children: [
                    if (groups.isEmpty)
                      const EmptyState(
                        icon: 'community',
                        title: 'No memberships yet',
                        message:
                            'Join a community or tribe from the Community tab.',
                      ),
                    for (final (i, c) in groups.indexed)
                      FadeIn(
                        index: i,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: AppCard(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 12),
                            onTap: () => pushScreen(context,
                                CommunityDetailScreen(communityId: c.id)),
                            child: Row(
                              children: [
                                AppIcon(c.isTribe ? 'flag' : 'community',
                                    size: 18, color: AppColors.skyDeep),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(c.name,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w600)),
                                      Text(
                                        c.status == ApprovalStatus.pending
                                            ? 'Waiting for admin approval'
                                            : 'Joined ${fmtDate(c.joinedAt[state.me.id] ?? c.createdAt)}',
                                        style: text.bodySmall,
                                      ),
                                    ],
                                  ),
                                ),
                                Tag(state.roleIn(c)?.label ?? 'Member',
                                    tone: state.canManage(c)
                                        ? Tone.pink
                                        : Tone.neutral),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                )
              : Column(
                  key: const ValueKey('activity'),
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: StatTile(
                              icon: 'chat',
                              value: '${posts.length + state.myReplyCount}',
                              label: 'Posts and replies'),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: StatTile(
                              icon: 'star',
                              value: '${reviews.length}',
                              label: 'Reviews',
                              pink: true),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: StatTile(
                              icon: 'megaphone',
                              value: '${concerns.length}',
                              label: 'Concerns'),
                        ),
                      ],
                    ),
                    if (posts.isEmpty &&
                        events.isEmpty &&
                        reviews.isEmpty &&
                        concerns.isEmpty)
                      const EmptyState(
                        icon: 'chat',
                        title: 'Nothing yet',
                        message:
                            'Your posts, reviews, concerns and RSVPs appear here.',
                      ),
                    if (posts.isNotEmpty) const SectionHeader('Your posts'),
                    for (final d in posts.take(6))
                      _ActivityRow(
                        icon: 'chat',
                        title: d.title,
                        detail:
                            '${state.communityById(d.communityId)?.name ?? ''} · ${timeAgo(d.createdAt)}',
                        onTap: () => pushScreen(context,
                            DiscussionDetailScreen(discussionId: d.id)),
                      ),
                    if (events.isNotEmpty) const SectionHeader('Your RSVPs'),
                    for (final e in events.take(6))
                      _ActivityRow(
                        icon: 'events',
                        title: e.title,
                        detail: fmtDateTime(e.start),
                        onTap: () => pushScreen(
                            context, EventDetailScreen(eventId: e.id)),
                      ),
                    if (reviews.isNotEmpty) const SectionHeader('Your reviews'),
                    for (final r in reviews.take(6))
                      _ActivityRow(
                        icon: 'star',
                        title: r.target == ReviewTarget.station
                            ? state.stationById(r.targetId)?.name ?? 'Station'
                            : state.providerById(r.targetId)?.name ??
                                'Provider',
                        detail:
                            '${r.rating} of 5 · ${timeAgo(r.createdAt)}',
                      ),
                    if (concerns.isNotEmpty)
                      const SectionHeader('Your concerns'),
                    for (final k in concerns.take(6))
                      _ActivityRow(
                        icon: 'megaphone',
                        title: k.title,
                        detail:
                            '${plural(k.supporters.length, 'supporter')} · ${timeAgo(k.createdAt)}',
                        onTap: () => pushScreen(
                          context,
                          CommunityDetailScreen(
                              communityId: k.communityId, initialTab: 'Voice'),
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({
    required this.icon,
    required this.title,
    required this.detail,
    this.onTap,
  });

  final String icon;
  final String title;
  final String detail;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        children: [
          AppIcon(icon, size: 17, color: AppColors.skyDeep),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                Text(detail, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          if (onTap != null)
            const AppIcon('chevron', size: 15, color: AppColors.inkFaint),
        ],
      ),
    );
    return onTap == null ? row : Pressable(onTap: onTap, child: row);
  }
}

// ─────────────────────── Notifications and privacy ───────────────────────

class NotificationSettingsScreen extends StatelessWidget {
  const NotificationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final me = state.me;
    return DetailScaffold(
      title: 'Notifications',
      children: [
        AppCard(
          child: Column(
            children: [
              ToggleRow(
                title: 'Community',
                subtitle: 'Announcements, join requests and role changes',
                value: me.notifyCommunity,
                onChanged: (v) => state.setPreferences(notifyCommunity: v),
              ),
              ToggleRow(
                title: 'Events',
                subtitle: 'New events and cancellations',
                value: me.notifyEvents,
                onChanged: (v) => state.setPreferences(notifyEvents: v),
              ),
              ToggleRow(
                title: 'Polls',
                subtitle: 'Published poll results',
                value: me.notifyPolls,
                onChanged: (v) => state.setPreferences(notifyPolls: v),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        const NoticeBox(
          'Account notices are always sent: approvals, ownership verification and reviews of your listings. Notifications appear in the app; push notifications to the phone are not set up yet.',
        ),
      ],
    );
  }
}

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final me = state.me;
    return DetailScaffold(
      title: 'Privacy',
      children: [
        AppCard(
          child: Column(
            children: [
              ToggleRow(
                title: 'Show my vehicle to other members',
                subtitle: 'On the member lists of groups you belong to',
                value: me.showVehicle,
                onChanged: (v) => state.setPreferences(showVehicle: v),
              ),
              ToggleRow(
                title: 'Show my name on station activity',
                subtitle: 'On queue check-ins and status reports',
                value: me.showNameOnStations,
                onChanged: (v) => state.setPreferences(showNameOnStations: v),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        const NoticeBox(
          'Always visible to other members: your display name and photo on posts and reviews, and the verified-owner label. Leaders and officers of your groups always see your vehicle, because they check membership criteria and event routes with it.',
          icon: 'lock',
        ),
      ],
    );
  }
}

// ──────────────────────────── Change password ────────────────────────────

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  /// What the form still needs, or null when it can be submitted.
  String? get _missing {
    if (_busy) return null;
    if (_current.text.isEmpty) return 'Enter your current password.';
    if (_next.text.length < 8) {
      return 'The new password needs at least 8 characters.';
    }
    if (_next.text == _current.text) {
      return 'Choose a password different from the current one.';
    }
    if (_confirm.text != _next.text) return 'The two new passwords do not match.';
    return null;
  }

  Future<void> _submit() async {
    final state = context.read<AppState>();
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await state.changePassword(_current.text, _next.text);
      if (!mounted) return;
      Navigator.of(context).pop();
      showToast(context, 'Password changed.');
    } on RemoteException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _field(TextEditingController controller, String label) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FieldLabel(label),
            TextField(
              controller: controller,
              obscureText: true,
              onChanged: (_) => setState(() {}),
            ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final remote = context.read<AppState>().isRemote;
    final missing = _missing;
    return DetailScaffold(
      title: 'Password and security',
      bottom: !remote
          ? null
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (missing != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Text(missing,
                        style: Theme.of(context).textTheme.bodySmall),
                  ),
                AppButton(
                  label: _busy ? 'Please wait' : 'Change password',
                  expand: true,
                  onTap: !_busy && missing == null ? _submit : null,
                ),
              ],
            ),
      children: [
        if (!remote)
          const NoticeBox(
            'Sample accounts have no password. Sign in with a real account to change it.',
          )
        else ...[
          if (_error != null) ...[
            NoticeBox(_error!, tone: Tone.danger, icon: 'alert'),
            const SizedBox(height: 14),
          ],
          _field(_current, 'Current password'),
          _field(_next, 'New password'),
          _field(_confirm, 'Confirm new password'),
          const NoticeBox(
            'Your current password is checked first, so no one can change it from an unlocked phone without knowing it.',
            icon: 'shield',
          ),
        ],
      ],
    );
  }
}
