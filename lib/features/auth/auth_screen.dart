import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_motion.dart';
import '../../core/widgets/basics.dart';
import '../../core/widgets/overlays.dart';
import '../../data/models.dart';
import '../../data/remote/remote_store.dart';
import '../../state/app_state.dart';

/// Sign-in and registration, used when the app runs with a backend.
///
/// Registration asks for three things only: email, password and a name.
/// City, vehicle and ownership verification are collected later from Home
/// and Profile, when they become useful (progressive profiling). Google and
/// Apple buttons appear when those providers are switched on in Supabase.
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, this.startWithSignIn = false});

  final bool startWithSignIn;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _name = TextEditingController();
  late int _mode = widget.startWithSignIn ? 0 : 1; // 0 sign in, 1 register
  PlatformRole _role = PlatformRole.member;
  bool _chooseRole = false;
  bool _busy = false;
  String? _error;
  String? _notice;
  late final Future<Set<String>> _providers =
      context.read<AppState>().oauthProviders();

  static const _roles = [
    (PlatformRole.member, 'EV owner', 'Join communities, post, vote and RSVP'),
    (PlatformRole.guest, 'Prospective owner', 'Read-only; can join open communities'),
    (PlatformRole.provider, 'Service provider', 'List your shop and read feedback'),
  ];

  @override
  void dispose() {
    for (final c in [_email, _password, _name]) {
      c.dispose();
    }
    super.dispose();
  }

  bool get _registering => _mode == 1;

  /// What the form still needs before it can be submitted, or null.
  String? get _missing {
    if (_busy) return null;
    if (!_email.text.contains('@')) return 'Enter your email address.';
    if (_password.text.length < 8) {
      return 'Enter a password of at least 8 characters.';
    }
    if (_registering && _name.text.trim().length < 2) return 'Enter your name.';
    return null;
  }

  bool get _ready => !_busy && _missing == null;

  Future<void> _submit() async {
    final state = context.read<AppState>();
    final navigator = Navigator.of(context);
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });
    try {
      var signedIn = true;
      if (_registering) {
        signedIn = await state.register(
          email: _email.text.trim(),
          password: _password.text,
          name: _name.text.trim(),
          region: '',
          role: _role,
        );
      } else {
        await state.signInWithPassword(_email.text.trim(), _password.text);
      }
      if (!mounted) return;
      if (signedIn) {
        // The root swaps to the app once a user is set.
        navigator.popUntil((r) => r.isFirst);
      } else {
        setState(() {
          _mode = 0;
          _notice =
              'Account created. Open the link we emailed to ${_email.text.trim()}, then sign in.';
        });
      }
    } on RemoteException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _oauth(String provider) async {
    final state = context.read<AppState>();
    setState(() {
      _error = null;
      _notice = null;
    });
    try {
      // Opens the browser. When it returns, the session arrives and the
      // root swaps to the app.
      await state.signInWithOAuth(provider);
    } on RemoteException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final signedIn =
        context.select<AppState, bool>((s) => s.currentUser != null);
    // A Google or Apple sign-in finished while this screen was open.
    if (signedIn) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
      });
    }
    final roleLabel = _roles.firstWhere((r) => r.$1 == _role).$2;

    return DetailScaffold(
      title: _registering ? 'Create account' : 'Sign in',
      bottom: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Says why the button is not active yet, so it never fails silently.
          if (_missing != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(_missing!, style: text.bodySmall),
            ),
          AppButton(
            label: _busy
                ? 'Please wait'
                : _registering
                    ? 'Create account'
                    : 'Sign in',
            expand: true,
            onTap: _ready ? _submit : null,
          ),
        ],
      ),
      children: [
        SegmentedTabs(
          labels: const ['Sign in', 'Create account'],
          index: _mode,
          onChanged: _busy
              ? (_) {}
              : (i) => setState(() {
                    _mode = i;
                    _error = null;
                  }),
        ),
        const SizedBox(height: 18),
        FutureBuilder<Set<String>>(
          future: _providers,
          builder: (context, snapshot) {
            final providers = snapshot.data ?? const <String>{};
            return AnimatedSize(
              duration: AppMotion.of(context, AppMotion.standard),
              curve: AppMotion.move,
              alignment: Alignment.topCenter,
              child: providers.isEmpty
                  ? const SizedBox(width: double.infinity)
                  : Column(
                      children: [
                        if (providers.contains('google'))
                          _ProviderButton(
                            label: 'Continue with Google',
                            mark: 'G',
                            onTap: () => _oauth('google'),
                          ),
                        if (providers.contains('apple'))
                          _ProviderButton(
                            label: 'Continue with Apple',
                            mark: '',
                            onTap: () => _oauth('apple'),
                          ),
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 10),
                          child: Row(
                            children: [
                              Expanded(child: Divider()),
                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: 12),
                                child: Text('or with email',
                                    style: TextStyle(
                                        fontSize: 12.5,
                                        color: AppColors.inkSoft)),
                              ),
                              Expanded(child: Divider()),
                            ],
                          ),
                        ),
                      ],
                    ),
            );
          },
        ),
        if (_notice != null) ...[
          NoticeBox(_notice!, tone: Tone.success, icon: 'check'),
          const SizedBox(height: 14),
        ],
        if (_error != null) ...[
          NoticeBox(_error!, tone: Tone.danger, icon: 'alert'),
          const SizedBox(height: 14),
        ],
        AppField(
          controller: _email,
          label: 'Email',
          keyboardType: TextInputType.emailAddress,
          onChanged: (_) => setState(() {}),
        ),
        const FieldLabel('Password'),
        TextField(
          controller: _password,
          obscureText: true,
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) => _ready ? _submit() : null,
          decoration: const InputDecoration(hintText: 'At least 8 characters'),
        ),
        const SizedBox(height: 14),
        AnimatedSize(
          duration: AppMotion.of(context, AppMotion.standard),
          curve: AppMotion.move,
          alignment: Alignment.topCenter,
          child: !_registering
              ? const SizedBox(width: double.infinity)
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppField(
                      controller: _name,
                      label: 'Name',
                      hint: 'Shown on your posts',
                      onChanged: (_) => setState(() {}),
                    ),
                    // Most people are owners, so the choice stays folded
                    // away until someone needs it.
                    Pressable(
                      onTap: () => setState(() => _chooseRole = !_chooseRole),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: [
                            Text('Joining as ', style: text.bodyMedium),
                            Text(roleLabel,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600)),
                            const Spacer(),
                            Text(_chooseRole ? 'Done' : 'Change',
                                style: const TextStyle(
                                    color: AppColors.pinkDeep,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13)),
                          ],
                        ),
                      ),
                    ),
                    if (_chooseRole) ...[
                      const SizedBox(height: 6),
                      for (final (role, title, detail) in _roles)
                        Pressable(
                          onTap: () => setState(() => _role = role),
                          child: Semantics(
                            selected: role == _role,
                            child: Container(
                              width: double.infinity,
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 12),
                              decoration: BoxDecoration(
                                color: role == _role
                                    ? AppColors.skySoft
                                    : AppColors.white.withValues(alpha: 0.7),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: role == _role
                                      ? AppColors.sky
                                      : AppColors.white,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(title,
                                            style: const TextStyle(
                                                fontWeight: FontWeight.w600)),
                                        Text(detail, style: text.bodySmall),
                                      ],
                                    ),
                                  ),
                                  if (role == _role)
                                    const AppIcon('check',
                                        size: 18, color: AppColors.skyDeep),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                    const SizedBox(height: 6),
                    Text(
                      'You can add your city, vehicle and ownership proof later from your profile.',
                      style: text.bodySmall,
                    ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _ProviderButton extends StatelessWidget {
  const _ProviderButton({
    required this.label,
    required this.mark,
    required this.onTap,
  });

  final String label;

  /// Letter shown in the round mark; empty for none. The official provider
  /// logos are added with the rest of the brand assets.
  final String mark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Pressable(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 13),
          decoration: BoxDecoration(
            color: AppColors.white.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.white),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (mark.isNotEmpty) ...[
                Container(
                  width: 24,
                  height: 24,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                      color: AppColors.skySoft, shape: BoxShape.circle),
                  child: Text(mark,
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.skyDeep)),
                ),
                const SizedBox(width: 10),
              ],
              Text(label,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}
