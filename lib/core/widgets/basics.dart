import 'dart:typed_data';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/app_colors.dart';
import '../theme/app_motion.dart';
import '../theme/app_theme.dart';
import 'glass.dart';

/// Stroke icon from `assets/icons/<name>.svg`, tinted with [color].
class AppIcon extends StatelessWidget {
  const AppIcon(this.name, {super.key, this.size = 22, this.color});

  final String name;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      'assets/icons/$name.svg',
      width: size,
      height: size,
      colorFilter:
          ColorFilter.mode(color ?? AppColors.ink, BlendMode.srcIn),
    );
  }
}

/// Wraps any tappable surface. Scales to 0.97 while pressed and returns
/// straight away on release (UI rule 4).
class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    required this.child,
    required this.onTap,
    this.label,
  });

  final Widget child;
  final VoidCallback? onTap;
  final String? label;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  void _set(bool value) {
    if (_down != value && mounted) setState(() => _down = value);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: enabled ? (_) => _set(true) : null,
        onTapUp: enabled ? (_) => _set(false) : null,
        onTapCancel: enabled ? () => _set(false) : null,
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _down && !AppMotion.reduced(context) ? 0.97 : 1,
          duration: _down ? AppMotion.press : const Duration(milliseconds: 40),
          curve: AppMotion.enter,
          child: AnimatedOpacity(
            opacity: enabled ? 1 : 0.5,
            duration: AppMotion.fast,
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

enum AppButtonKind { primary, sky, soft, ghost, danger }

class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.kind = AppButtonKind.primary,
    this.expand = false,
    this.small = false,
  });

  final String label;
  final VoidCallback? onTap;
  final String? icon;
  final AppButtonKind kind;
  final bool expand;
  final bool small;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (kind) {
      AppButtonKind.primary => (AppColors.pink, AppColors.white),
      AppButtonKind.sky => (AppColors.sky, AppColors.ink),
      AppButtonKind.soft => (AppColors.skySoft, AppColors.ink),
      AppButtonKind.ghost => (Colors.transparent, AppColors.skyDeep),
      AppButtonKind.danger => (AppColors.dangerSoft, AppColors.danger),
    };
    return Pressable(
      onTap: onTap,
      child: Container(
        width: expand ? double.infinity : null,
        padding: EdgeInsets.symmetric(
          horizontal: small ? 14 : 20,
          vertical: small ? 9 : 14,
        ),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(small ? 12 : 16),
          boxShadow: kind == AppButtonKind.primary && onTap != null
              ? [
                  BoxShadow(
                    color: AppColors.pink.withValues(alpha: 0.28),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              AppIcon(icon!, size: small ? 16 : 18, color: fg),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: fg,
                  fontWeight: FontWeight.w600,
                  fontSize: small ? 13 : 15,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Square icon button with rounded corners, as in the inspiration headers.
class IconSquare extends StatelessWidget {
  const IconSquare({
    super.key,
    required this.icon,
    required this.onTap,
    required this.label,
    this.filled = false,
    this.dot = false,
  });

  final String icon;
  final VoidCallback? onTap;
  final String label;
  final bool filled;
  final bool dot;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      label: label,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Glass(
            radius: 16,
            blur: 14,
            tint: filled ? AppColors.sky : AppColors.white,
            opacity: filled ? 0.78 : 0.6,
            child: SizedBox(
              width: 44,
              height: 44,
              child: Center(child: AppIcon(icon, size: 20)),
            ),
          ),
          if (dot)
            Positioned(
              right: 9,
              top: 9,
              child: Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  color: AppColors.pink,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.white, width: 1.5),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(16),
    this.color = AppColors.white,
    this.border = true,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets padding;
  final Color color;
  final bool border;

  @override
  Widget build(BuildContext context) {
    final card = Container(
      width: double.infinity,
      padding: padding,
      // Translucent glass surface without blur, so long lists scroll smoothly.
      decoration: glassCard(color: color, radius: AppTheme.radius),
      child: child,
    );
    return onTap == null ? card : Pressable(onTap: onTap, child: card);
  }
}

enum Tone { sky, pink, success, warning, danger, neutral }

/// Small label pill. The text always carries the meaning; color only supports.
class Tag extends StatelessWidget {
  const Tag(this.label, {super.key, this.tone = Tone.sky, this.icon});

  final String label;
  final Tone tone;
  final String? icon;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (tone) {
      Tone.sky => (AppColors.skySoft, AppColors.skyDeep),
      Tone.pink => (AppColors.pinkSoft, AppColors.pinkDeep),
      Tone.success => (AppColors.successSoft, AppColors.success),
      Tone.warning => (AppColors.warningSoft, AppColors.warning),
      Tone.danger => (AppColors.dangerSoft, AppColors.danger),
      Tone.neutral => (const Color(0xFFF1F4F7), AppColors.inkSoft),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            AppIcon(icon!, size: 12, color: fg),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
                color: fg, fontSize: 11.5, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

/// Selectable option, used for filters and choices in forms. It has no
/// outline: the selected one gets a soft sky wash and heavier type.
class ChoicePill extends StatelessWidget {
  const ChoicePill({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final duration = AppMotion.of(context, AppMotion.fast);
    return Pressable(
      onTap: onTap,
      child: Semantics(
        selected: selected,
        child: AnimatedContainer(
          duration: duration,
          curve: AppMotion.move,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.sky.withValues(alpha: 0.45)
                : AppColors.sky.withValues(alpha: 0),
            borderRadius: BorderRadius.circular(11),
          ),
          child: AnimatedDefaultTextStyle(
            duration: duration,
            style: DefaultTextStyle.of(context).style.copyWith(
                  fontSize: 13.5,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  color: selected ? AppColors.ink : AppColors.inkSoft,
                ),
            child: Text(label),
          ),
        ),
      ),
    );
  }
}

/// Text navigation for a module's functions, scrolling sideways when there
/// are many. The active one is set in heavier, darker type with a short
/// accent line under it; there are no outlines or containers.
class PillRow extends StatelessWidget {
  const PillRow({
    super.key,
    required this.labels,
    required this.index,
    required this.onChanged,
    this.padding = const EdgeInsets.symmetric(horizontal: 20),
  });

  final List<String> labels;
  final int index;
  final ValueChanged<int> onChanged;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < labels.length; i++) ...[
            if (i > 0) const SizedBox(width: 22),
            _TextTab(
              label: labels[i],
              selected: i == index,
              onTap: () => onChanged(i),
            ),
          ],
        ],
      ),
    );
  }
}

class _TextTab extends StatelessWidget {
  const _TextTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final duration = AppMotion.of(context, AppMotion.standard);
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AnimatedDefaultTextStyle(
                duration: duration,
                curve: AppMotion.move,
                style: DefaultTextStyle.of(context).style.copyWith(
                      fontSize: 15,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      color: selected ? AppColors.ink : AppColors.inkFaint,
                    ),
                child: Text(label),
              ),
              const SizedBox(height: 6),
              // The accent line grows out from the left under the active tab.
              AnimatedContainer(
                duration: duration,
                curve: AppMotion.move,
                height: 3,
                width: selected ? 22 : 0,
                decoration: BoxDecoration(
                  color: AppColors.pink,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Two- or three-way switch between views, as equal-width text tabs over a
/// hairline. A short accent line slides under the active one.
class SegmentedTabs extends StatelessWidget {
  const SegmentedTabs({
    super.key,
    required this.labels,
    required this.index,
    required this.onChanged,
  });

  final List<String> labels;
  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final n = labels.length;
    final duration = AppMotion.of(context, AppMotion.standard);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            for (var i = 0; i < n; i++)
              Expanded(
                child: Semantics(
                  button: true,
                  selected: i == index,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onChanged(i),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Center(
                        child: AnimatedDefaultTextStyle(
                          duration: duration,
                          curve: AppMotion.move,
                          style: DefaultTextStyle.of(context).style.copyWith(
                                fontSize: 15,
                                fontWeight: i == index
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: i == index
                                    ? AppColors.ink
                                    : AppColors.inkFaint,
                              ),
                          child: Text(labels[i]),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        SizedBox(
          height: 3,
          child: Stack(
            children: [
              Align(
                alignment: Alignment.bottomCenter,
                child: Container(
                  height: 1,
                  color: AppColors.ink.withValues(alpha: 0.08),
                ),
              ),
              AnimatedAlign(
                alignment: Alignment(n == 1 ? 0 : -1 + 2 * index / (n - 1), 0),
                duration: duration,
                curve: AppMotion.move,
                child: FractionallySizedBox(
                  widthFactor: 1 / n,
                  child: Center(
                    child: Container(
                      width: 30,
                      height: 3,
                      decoration: BoxDecoration(
                        color: AppColors.pink,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class Avatar extends StatelessWidget {
  const Avatar(
    this.initials, {
    super.key,
    this.size = 40,
    this.pink = false,
    this.imageUrl,
    this.imageBytes,
  });

  final String initials;
  final double size;
  final bool pink;

  /// Profile photo, from the network or from memory. Initials show while it
  /// loads, when there is none, or when it fails.
  final String? imageUrl;
  final Uint8List? imageBytes;

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: pink ? AppColors.pinkSoft : AppColors.skySoft,
        shape: BoxShape.circle,
      ),
      child: Text(
        initials,
        style: TextStyle(
          fontSize: size * 0.36,
          fontWeight: FontWeight.w700,
          color: pink ? AppColors.pinkDeep : AppColors.skyDeep,
        ),
      ),
    );
    final bytes = imageBytes;
    final url = imageUrl;
    if (bytes == null && url == null) return fallback;
    return ClipOval(
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          fit: StackFit.expand,
          children: [
            fallback,
            if (bytes != null)
              Image.memory(bytes, fit: BoxFit.cover, gaplessPlayback: true)
            else
              Image.network(
                url!,
                fit: BoxFit.cover,
                gaplessPlayback: true,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
          ],
        ),
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.action, this.onAction});

  final String title;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 22, bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(title, style: Theme.of(context).textTheme.titleMedium),
          ),
          if (action != null)
            Pressable(
              onTap: onAction,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  action!,
                  style: const TextStyle(
                    color: AppColors.pinkDeep,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Number tile, as in the "Delivery Status" row of the inspiration.
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
    this.onTap,
    this.pink = false,
  });

  final String icon;
  final String value;
  final String label;
  final VoidCallback? onTap;
  final bool pink;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
      child: Column(
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: pink ? AppColors.pinkSoft : AppColors.skySoft,
              shape: BoxShape.circle,
            ),
            child: AppIcon(icon,
                size: 17,
                color: pink ? AppColors.pinkDeep : AppColors.skyDeep),
          ),
          const SizedBox(height: 8),
          AnimatedSwitcher(
            duration: AppMotion.of(context, AppMotion.standard),
            child: Text(
              value,
              key: ValueKey(value),
              style:
                  const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11.5),
          ),
        ],
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
  });

  final String icon;
  final String title;
  final String? message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
                color: AppColors.skySoft, shape: BoxShape.circle),
            child: AppIcon(icon, size: 24, color: AppColors.skyDeep),
          ),
          const SizedBox(height: 14),
          Text(title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleSmall),
          if (message != null) ...[
            const SizedBox(height: 6),
            Text(message!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall),
          ],
        ],
      ),
    );
  }
}

/// Icon and text on one line, used for facts such as venue or fees.
class InfoRow extends StatelessWidget {
  const InfoRow(this.icon, this.text, {super.key, this.color});

  final String icon;
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: AppIcon(icon, size: 15, color: color ?? AppColors.inkSoft),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                  fontSize: 13.5, color: color ?? AppColors.inkSoft, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

/// Banner for notices such as read-only access or estimates.
class NoticeBox extends StatelessWidget {
  const NoticeBox(this.text, {super.key, this.tone = Tone.sky, this.icon = 'info'});

  final String text;
  final Tone tone;
  final String icon;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (tone) {
      Tone.pink => (AppColors.pinkSoft, AppColors.pinkDeep),
      Tone.success => (AppColors.successSoft, AppColors.success),
      Tone.warning => (AppColors.warningSoft, AppColors.warning),
      Tone.danger => (AppColors.dangerSoft, AppColors.danger),
      _ => (AppColors.skySoft, AppColors.skyDeep),
    };
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: AppIcon(icon, size: 16, color: fg),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text,
                style: const TextStyle(
                    fontSize: 12.5, color: AppColors.ink, height: 1.4)),
          ),
        ],
      ),
    );
  }
}

/// Fades and lifts a child into place. List items pass their [index] so the
/// entrances stagger by 30 ms (UI rule 3). Reduced motion shows it at once.
class FadeIn extends StatefulWidget {
  const FadeIn({super.key, required this.child, this.index = 0});

  final Widget child;
  final int index;

  @override
  State<FadeIn> createState() => _FadeInState();
}

class _FadeInState extends State<FadeIn> with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: AppMotion.slow);
  late final Animation<double> _curve =
      CurvedAnimation(parent: _controller, curve: AppMotion.enter);

  @override
  void initState() {
    super.initState();
    final delay = AppMotion.stagger * widget.index.clamp(0, 8);
    Future.delayed(delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (AppMotion.reduced(context)) return widget.child;
    return FadeTransition(
      opacity: _curve,
      child: SlideTransition(
        position: Tween(begin: const Offset(0, 0.04), end: Offset.zero)
            .animate(_curve),
        child: widget.child,
      ),
    );
  }
}

/// Simple horizontal bars for dashboards and poll results.
class BarList extends StatelessWidget {
  const BarList({super.key, required this.items, this.pinkIndex});

  /// Label and value pairs.
  final List<(String, num)> items;

  /// Index of the bar to highlight, if any.
  final int? pinkIndex;

  @override
  Widget build(BuildContext context) {
    final max = items.fold<num>(0, (m, e) => e.$2 > m ? e.$2 : m);
    return Column(
      children: [
        for (var i = 0; i < items.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(items[i].$1,
                          style: const TextStyle(fontSize: 13)),
                    ),
                    Text(
                      items[i].$2 is int
                          ? '${items[i].$2}'
                          : items[i].$2.toStringAsFixed(0),
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    height: 8,
                    color: AppColors.skySoft,
                    alignment: Alignment.centerLeft,
                    child: AnimatedFractionallySizedBox(
                      duration: AppMotion.of(context, AppMotion.slow),
                      curve: AppMotion.move,
                      widthFactor:
                          max == 0 ? 0 : (items[i].$2 / max).clamp(0, 1).toDouble(),
                      heightFactor: 1,
                      child: Container(
                        color:
                            i == pinkIndex ? AppColors.pink : AppColors.sky,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Row of rating stars (read-only when [onChanged] is null).
class Stars extends StatelessWidget {
  const Stars(this.rating, {super.key, this.size = 14, this.onChanged});

  final double rating;
  final double size;
  final ValueChanged<int>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '${rating.toStringAsFixed(1)} out of 5 stars',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 1; i <= 5; i++)
            GestureDetector(
              onTap: onChanged == null ? null : () => onChanged!(i),
              child: Padding(
                padding: EdgeInsets.only(right: onChanged == null ? 1 : 6),
                child: AppIcon(
                  'star',
                  size: size,
                  color: i <= rating.round()
                      ? AppColors.pink
                      : AppColors.line,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
