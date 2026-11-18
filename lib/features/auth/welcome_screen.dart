import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/basics.dart';
import '../../core/widgets/overlays.dart';
import '../../data/models.dart';
import '../../state/app_state.dart';

/// Demo sign-in: one sample account per role. Supabase Auth replaces this
/// list once the backend is connected.
class SignInScreen extends StatelessWidget {
  const SignInScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    return DetailScaffold(
      title: 'Sign in',
      children: [
        Text(
          'Choose an account',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 6),
        Text(
          'Each sample account shows the app as one of the user roles in the proposal.',
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(color: AppColors.inkSoft),
        ),
        const SizedBox(height: 18),
        for (final (i, user) in state.demoAccounts.indexed)
          FadeIn(
            index: i,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: AppCard(
                onTap: () {
                  Navigator.of(context).popUntil((r) => r.isFirst);
                  state.signIn(user);
                },
                child: Row(
                  children: [
                    Avatar(user.initials, size: 46, pink: i.isOdd),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user.name,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _describe(state, user),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    const AppIcon(
                      'chevron',
                      size: 18,
                      color: AppColors.inkFaint,
                    ),
                  ],
                ),
              ),
            ),
          ),
        const SizedBox(height: 6),
        const NoticeBox(
          'These are sample accounts with sample data. Run the app with your Supabase settings to register and sign in with email.',
        ),
      ],
    );
  }

  static String _describe(AppState state, AppUser user) {
    final leads = state.communities
        .where((c) => c.members[user.id] == GroupRole.leader && !c.isTribe)
        .map((c) => c.name);
    return switch (user.role) {
      PlatformRole.admin =>
        'Platform administrator · approvals, moderation, reference data',
      PlatformRole.provider =>
        'Service provider · manages listings, reads feedback',
      PlatformRole.guest => 'Guest · prospective owner, read-only',
      PlatformRole.member =>
        leads.isNotEmpty
            ? 'Community leader · ${leads.first}'
            : 'Member · ${user.vehicle?.name ?? 'no vehicle'}',
    };
  }
}
