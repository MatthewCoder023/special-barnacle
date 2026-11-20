import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:material_ui/material_ui.dart';

/// Motion values from `rules-for-the-ui.md`.
///
/// Standard durations are 150–250 ms, entrances ease out, moving objects ease
/// in and out, and exits run about 20% faster than entrances. Nothing bounces.
class AppMotion {
  AppMotion._();

  static const press = Duration(milliseconds: 80);
  static const fast = Duration(milliseconds: 150);
  static const standard = Duration(milliseconds: 200);
  static const slow = Duration(milliseconds: 250);
  static const stagger = Duration(milliseconds: 30);

  static const enter = Curves.easeOut;
  static const move = Curves.easeInOut;
  static const leave = Curves.easeIn;

  /// Exit duration for a given entrance duration (about 20% faster).
  static Duration exitOf(Duration entrance) =>
      Duration(milliseconds: (entrance.inMilliseconds * 0.8).round());

  /// True when the OS asks for reduced motion.
  static bool reduced(BuildContext context) =>
      MediaQuery.maybeOf(context)?.disableAnimations ?? false;

  /// Returns [d], or zero when reduced motion is on.
  static Duration of(BuildContext context, Duration d) =>
      reduced(context) ? Duration.zero : d;
}

/// Pushes a screen with the app's page transition.
///
/// iOS keeps the native transition so the swipe-back gesture works. Other
/// platforms fade the page in while it rises slightly. With reduced motion the
/// page only fades.
Future<T?> pushScreen<T>(BuildContext context, Widget screen) {
  final navigator = Navigator.of(context);
  if (Theme.of(context).platform == TargetPlatform.iOS) {
    return navigator.push<T>(CupertinoPageRoute<T>(builder: (_) => screen));
  }
  final reduced = AppMotion.reduced(context);
  return navigator.push<T>(
    PageRouteBuilder<T>(
      transitionDuration: AppMotion.slow,
      reverseTransitionDuration: AppMotion.exitOf(AppMotion.slow),
      pageBuilder: (_, _, _) => screen,
      transitionsBuilder: (_, animation, _, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: AppMotion.enter,
          reverseCurve: AppMotion.leave,
        );
        final fade = FadeTransition(opacity: curved, child: child);
        if (reduced) return fade;
        return SlideTransition(
          position: Tween(
            begin: const Offset(0, 0.03),
            end: Offset.zero,
          ).animate(curved),
          child: fade,
        );
      },
    ),
  );
}
