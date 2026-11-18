import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_motion.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/basics.dart';
import '../../core/widgets/overlays.dart';
import '../../data/models.dart';
import '../../state/app_state.dart';
import '../home/notifications_screen.dart';
import '../shared/shared_widgets.dart';
import 'profile_settings_screens.dart';

/// Profile: who the user is, then everything they can customize, grouped
/// into a short menu. Each row opens its own screen.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final me = state.me;
    final text = Theme.of(context).textTheme;
    final ownsVehicle =
        me.role == PlatformRole.member || me.role == PlatformRole.guest;
    final joins =
        me.role == PlatformRole.member || me.role == PlatformRole.guest;
    final steps = state.profileSteps;

    return TabPage(
      title: 'Profile',
      actions: [
        IconSquare(
          icon: 'notifications',
          label: 'Notifications',
          dot: state.unreadCount > 0,
          onTap: () => pushScreen(context, const NotificationsScreen()),
        ),
      ],
      children: [
        AppCard(
          color: AppColors.sky,
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Builder(
                builder: (anchor) => Pressable(
                  onTap: () => changePhoto(anchor),
                  label: 'Change profile photo',
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(
                            color: AppColors.white, shape: BoxShape.circle),
                        child: Avatar(
                          me.initials,
                          size: 70,
                          imageUrl: me.avatarUrl,
                          imageBytes: me.avatarBytes,
                        ),
                      ),
                      Positioned(
                        right: -2,
                        bottom: -2,
                        child: Container(
                          width: 28,
                          height: 28,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: AppColors.pink,
                            shape: BoxShape.circle,
                            border:
                                Border.all(color: AppColors.white, width: 2),
                          ),
                          child: const AppIcon('camera',
                              size: 13, color: AppColors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(me.name, style: text.titleLarge),
                    Text(
                      [
                        if (me.username != null) '@${me.username}',
                        if (me.region.trim().isNotEmpty) me.region,
                      ].join(' · '),
                      style: const TextStyle(fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        Tag(me.role.label, tone: Tone.pink),
                        if (me.isVerified)
                          const Tag('Verified owner',
                              tone: Tone.success, icon: 'check'),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        AnimatedSize(
          duration: AppMotion.of(context, AppMotion.standard),
          curve: AppMotion.move,
          alignment: Alignment.topCenter,
          child: steps.isEmpty
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: NoticeBox(
                    'Finish your profile: ${steps.join(', ').toLowerCase()}.',
                    tone: Tone.pink,
                    icon: 'profile',
                  ),
                ),
        ),
        const SizedBox(height: 16),
        _MenuGroup(rows: [
          _MenuRow(
            icon: 'edit',
            title: 'Edit profile',
            detail: 'Name, username and city',
            onTap: () => pushScreen(context, const EditProfileScreen()),
          ),
          if (ownsVehicle)
            _MenuRow(
              icon: 'car',
              title: 'My EV',
              detail: me.vehicle == null
                  ? 'Add your vehicle and charging preferences'
                  : '${me.vehicle!.name} · charge to ${me.chargeToPct}%, keep ${me.reservePct}%',
              onTap: () => pushScreen(context, const VehicleScreen()),
            ),
          if (joins)
            _MenuRow(
              icon: 'community',
              title: 'Communities and activity',
              detail:
                  '${plural(state.myGroups.length, 'group')} · ${plural(state.myDiscussions.length + state.myReplyCount, 'post')}',
              onTap: () => pushScreen(context, const MyActivityScreen()),
            ),
        ]),
        const SizedBox(height: 12),
        _MenuGroup(rows: [
          _MenuRow(
            icon: 'notifications',
            title: 'Notifications',
            detail: _summary({
              'Community': me.notifyCommunity,
              'Events': me.notifyEvents,
              'Polls': me.notifyPolls,
            }),
            onTap: () =>
                pushScreen(context, const NotificationSettingsScreen()),
          ),
          _MenuRow(
            icon: 'lock',
            title: 'Privacy',
            detail: 'What other members can see',
            onTap: () => pushScreen(context, const PrivacyScreen()),
          ),
          _MenuRow(
            icon: 'shield',
            title: 'Password and security',
            detail: 'Change your password',
            onTap: () => pushScreen(context, const ChangePasswordScreen()),
          ),
        ]),
        const SizedBox(height: 12),
        _MenuGroup(rows: [
          if (!state.isRemote)
            _MenuRow(
              icon: 'profile',
              title: 'Switch sample account',
              onTap: () => _switchAccount(context),
            ),
          _MenuRow(
            icon: 'logout',
            title: 'Sign out',
            danger: true,
            onTap: () async {
              final ok = await confirmAction(
                context,
                title: 'Sign out?',
                message: 'You can sign back in at any time.',
                confirmLabel: 'Sign out',
              );
              if (ok) state.signOut();
            },
          ),
        ]),
        const SizedBox(height: 14),
        Text(
          state.isRemote
              ? 'EVYAHE · pull down on any tab to reload.'
              : 'EVYAHE · sample data for development.',
          textAlign: TextAlign.center,
          style: text.bodySmall,
        ),
      ],
    );
  }

  /// "All on", "All off", or the kinds that are on.
  static String _summary(Map<String, bool> kinds) {
    final on = [
      for (final e in kinds.entries)
        if (e.value) e.key,
    ];
    if (on.length == kinds.length) return 'All on';
    if (on.isEmpty) return 'All off';
    return '${on.join(', ')} on';
  }

  Future<void> _switchAccount(BuildContext context) async {
    final state = context.read<AppState>();
    final picked = await pickOption<AppUser>(
      context,
      title: 'Switch sample account',
      options: state.demoAccounts,
      label: (u) => u.name,
      subtitle: (u) => u.role == PlatformRole.member &&
              state.communities.any(
                  (c) => !c.isTribe && c.members[u.id] == GroupRole.leader)
          ? 'Community leader'
          : u.role.label,
      selected: state.me,
    );
    if (picked != null) state.signIn(picked);
  }
}

/// A group of menu rows on one glass card, separated by hairlines.
class _MenuGroup extends StatelessWidget {
  const _MenuGroup({required this.rows});

  final List<Widget> rows;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Column(
        children: [
          for (final (i, row) in rows.indexed) ...[
            if (i > 0) const Divider(),
            row,
          ],
        ],
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.icon,
    required this.title,
    required this.onTap,
    this.detail,
    this.danger = false,
  });

  final String icon;
  final String title;
  final String? detail;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger ? AppColors.danger : AppColors.ink;
    return Pressable(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 13),
        child: Row(
          children: [
            AppIcon(icon,
                size: 19, color: danger ? AppColors.danger : AppColors.skyDeep),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: color)),
                  if (detail != null)
                    Text(detail!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            if (!danger)
              const AppIcon('chevron', size: 16, color: AppColors.inkFaint),
          ],
        ),
      ),
    );
  }
}
