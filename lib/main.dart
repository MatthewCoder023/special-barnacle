import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import 'core/theme/app_colors.dart';
import 'core/theme/app_motion.dart';
import 'core/theme/app_theme.dart';
import 'data/remote/supabase_store.dart';
import 'features/auth/onboarding_screen.dart';
import 'features/shell/app_shell.dart';
import 'state/app_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // With Supabase settings the app uses the backend; without them it runs on
  // the bundled sample data. See README.md.
  final AppState state;
  if (SupabaseConfig.isConfigured) {
    state = AppState.remote(await SupabaseStore.connect());
    state.restoreSession();
  } else {
    state = AppState();
  }

  runApp(ChangeNotifierProvider.value(value: state, child: const EvyaheApp()));
}

class EvyaheApp extends StatelessWidget {
  const EvyaheApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EVYAHE',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: const _Root(),
    );
  }
}

/// Shows the welcome flow when signed out and the app shell when signed in.
/// The two crossfade so there is never a blank frame between them.
class _Root extends StatelessWidget {
  const _Root();

  @override
  Widget build(BuildContext context) {
    final user = context.select<AppState, String?>((s) => s.currentUser?.id);
    // A saved session is being restored: wait instead of flashing the
    // welcome screen.
    final restoring = context.select<AppState, bool>(
      (s) => s.loading && s.currentUser == null,
    );
    return AnimatedSwitcher(
      duration: AppMotion.of(context, AppMotion.slow),
      switchInCurve: AppMotion.enter,
      switchOutCurve: AppMotion.leave,
      child: user != null
          ? AppShell(key: ValueKey(user))
          : restoring
          ? const _Loading(key: ValueKey('loading'))
          : const WelcomeScreen(key: ValueKey('welcome')),
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: AppColors.sky),
            SizedBox(height: 16),
            Text(
              'Loading your communities',
              style: TextStyle(color: AppColors.inkSoft),
            ),
          ],
        ),
      ),
    );
  }
}
