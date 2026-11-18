import 'dart:ui';

import 'package:material_ui/material_ui.dart';

import '../theme/app_colors.dart';

/// Liquid Glass building blocks.
///
/// Two levels, chosen for performance:
///
/// - [Glass] blurs whatever is behind it. Blur is costly, so it is used only
///   where content really passes underneath: the tab bar, floating controls,
///   sheets, menus and pinned bottom bars.
/// - [glassCard] is a translucent fill with a light edge and no blur. Cards
///   in long lists use it, so scrolling stays smooth on mid-range phones.
///
/// Both sit on [AppBackdrop], the soft sky-and-pink wash that gives the glass
/// something to show through.
class Glass extends StatelessWidget {
  const Glass({
    super.key,
    required this.child,
    this.radius = 22,
    this.blur = 18,
    this.tint = AppColors.white,
    this.opacity = 0.62,
    this.padding,
    this.shadow = true,
  });

  final Widget child;
  final double radius;
  final double blur;
  final Color tint;
  final double opacity;
  final EdgeInsetsGeometry? padding;
  final bool shadow;

  @override
  Widget build(BuildContext context) {
    final shape = BorderRadius.circular(radius);
    // Reduced transparency is an accessibility setting; honor it by dropping
    // the blur and making the surface nearly opaque.
    final solid = MediaQuery.maybeOf(context)?.highContrast ?? false;
    final surface = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: shape,
        border: Border.all(color: AppColors.white.withValues(alpha: 0.75)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            tint.withValues(alpha: solid ? 0.97 : opacity + 0.12),
            tint.withValues(alpha: solid ? 0.97 : opacity - 0.06),
          ],
        ),
      ),
      child: Padding(padding: padding ?? EdgeInsets.zero, child: child),
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: shape,
        boxShadow: shadow
            ? [
                BoxShadow(
                  color: AppColors.ink.withValues(alpha: 0.10),
                  blurRadius: 26,
                  offset: const Offset(0, 10),
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: shape,
        child: solid
            ? surface
            : BackdropFilter(
                filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
                child: surface,
              ),
      ),
    );
  }
}

/// Translucent card surface without blur.
BoxDecoration glassCard({
  Color color = AppColors.white,
  double radius = 22,
  bool shadow = true,
}) {
  final white = color == AppColors.white;
  return BoxDecoration(
    borderRadius: BorderRadius.circular(radius),
    color: color.withValues(alpha: white ? 0.74 : 0.86),
    border: Border.all(
      color: AppColors.white.withValues(alpha: white ? 0.95 : 0.55),
    ),
    boxShadow: shadow && white
        ? [
            BoxShadow(
              color: AppColors.ink.withValues(alpha: 0.055),
              blurRadius: 22,
              offset: const Offset(0, 8),
            ),
          ]
        : null,
  );
}

/// Soft sky-and-pink wash behind every screen. It is static (no animation or
/// blur), so it costs almost nothing to paint.
class AppBackdrop extends StatelessWidget {
  const AppBackdrop({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(color: AppColors.white),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(-1.1, -1.0),
            radius: 1.25,
            colors: [
              AppColors.sky.withValues(alpha: 0.42),
              AppColors.sky.withValues(alpha: 0.0),
            ],
          ),
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(1.2, 0.35),
              radius: 1.0,
              colors: [
                AppColors.pink.withValues(alpha: 0.16),
                AppColors.pink.withValues(alpha: 0.0),
              ],
            ),
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(-0.6, 1.25),
                radius: 1.0,
                colors: [
                  AppColors.sky.withValues(alpha: 0.30),
                  AppColors.sky.withValues(alpha: 0.0),
                ],
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
