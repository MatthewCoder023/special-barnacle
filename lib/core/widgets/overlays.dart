import 'package:material_ui/material_ui.dart';

import '../theme/app_colors.dart';
import '../theme/app_motion.dart';

import 'dart:ui';

import 'basics.dart';
import 'glass.dart';

/// Where on screen the widget behind [context] sits, as an [Alignment].
/// Overlays use it as their transform origin so they open from, and close
/// toward, the control that triggered them (UI rules 3 and 8).
Alignment triggerAlignment(BuildContext context) {
  final box = context.findRenderObject() as RenderBox?;
  final size = MediaQuery.sizeOf(context);
  if (box == null || !box.hasSize) return Alignment.center;
  final center = box.localToGlobal(box.size.center(Offset.zero));
  return Alignment(
    (center.dx / size.width * 2 - 1).clamp(-1.0, 1.0).toDouble(),
    (center.dy / size.height * 2 - 1).clamp(-1.0, 1.0).toDouble(),
  );
}

class AppMenuItem<T> {
  const AppMenuItem(this.value, this.label, {this.icon, this.danger = false});

  final T value;
  final String label;
  final String? icon;
  final bool danger;
}

/// Opens a menu anchored to the widget behind [context].
///
/// The menu fades in from opacity 0 and scale 0.95, grows out of the trigger,
/// and its items stagger by 30 ms. Tapping outside, pressing Escape or the
/// system back button closes it.
Future<T?> showAppMenu<T>(BuildContext context, List<AppMenuItem<T>> items) {
  final box = context.findRenderObject() as RenderBox;
  final origin = box.localToGlobal(Offset.zero);
  final rect = origin & box.size;
  return Navigator.of(context).push<T>(_MenuRoute<T>(rect, items));
}

class _MenuRoute<T> extends PopupRoute<T> {
  _MenuRoute(this.anchor, this.items);

  final Rect anchor;
  final List<AppMenuItem<T>> items;

  @override
  Color? get barrierColor => AppColors.ink.withValues(alpha: 0.08);

  @override
  bool get barrierDismissible => true;

  @override
  String? get barrierLabel => 'Close menu';

  @override
  Duration get transitionDuration => const Duration(milliseconds: 180);

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 144);

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    final screen = MediaQuery.sizeOf(context);
    final openUp = anchor.bottom + 56.0 * items.length + 24 > screen.height;
    final right = (screen.width - anchor.right)
        .clamp(12.0, screen.width)
        .toDouble();
    final curved = CurvedAnimation(
      parent: animation,
      curve: AppMotion.enter,
      reverseCurve: AppMotion.leave,
    );
    final reduced = AppMotion.reduced(context);

    Widget menu = Glass(
      radius: 20,
      opacity: 0.78,
      child: Material(
        type: MaterialType.transparency,
        child: Container(
          constraints: const BoxConstraints(minWidth: 190, maxWidth: 260),
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: IntrinsicWidth(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < items.length; i++)
                  _MenuRow<T>(
                    item: items[i],
                    animation: animation,
                    start: reduced
                        ? 0
                        : (i *
                                  AppMotion.stagger.inMilliseconds /
                                  transitionDuration.inMilliseconds)
                              .clamp(0.0, 0.6)
                              .toDouble(),
                  ),
              ],
            ),
          ),
        ),
      ),
    );

    menu = FadeTransition(
      opacity: curved,
      child: reduced
          ? menu
          : ScaleTransition(
              scale: Tween(begin: 0.95, end: 1.0).animate(curved),
              alignment: openUp ? Alignment.bottomRight : Alignment.topRight,
              child: menu,
            ),
    );

    return Stack(
      children: [
        Positioned(
          right: right,
          top: openUp ? null : anchor.bottom + 6,
          bottom: openUp ? screen.height - anchor.top + 6 : null,
          child: menu,
        ),
      ],
    );
  }
}

class _MenuRow<T> extends StatelessWidget {
  const _MenuRow({
    required this.item,
    required this.animation,
    required this.start,
  });

  final AppMenuItem<T> item;
  final Animation<double> animation;
  final double start;

  @override
  Widget build(BuildContext context) {
    final color = item.danger ? AppColors.danger : AppColors.ink;
    return FadeTransition(
      opacity: CurvedAnimation(
        parent: animation,
        curve: Interval(start, 1, curve: AppMotion.enter),
      ),
      child: InkWell(
        onTap: () => Navigator.of(context).pop(item.value),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          child: Row(
            children: [
              if (item.icon != null) ...[
                AppIcon(item.icon!, size: 17, color: color),
                const SizedBox(width: 12),
              ],
              Flexible(
                child: Text(
                  item.label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "More" button that opens an [showAppMenu] from itself.
class MenuButton<T> extends StatelessWidget {
  const MenuButton({
    super.key,
    required this.items,
    required this.onSelected,
    this.icon = 'more',
    this.label = 'More options',
  });

  final List<AppMenuItem<T>> items;
  final ValueChanged<T> onSelected;
  final String icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (anchor) => IconSquare(
        icon: icon,
        label: label,
        onTap: () async {
          final value = await showAppMenu<T>(anchor, items);
          if (value != null) onSelected(value);
        },
      ),
    );
  }
}

/// Dialog that scales from 0.95 out of the control that opened it.
Future<T?> showAppDialog<T>(
  BuildContext context, {
  required String title,
  String? message,
  Widget? content,
  required List<Widget> Function(BuildContext dialogContext) actions,
}) {
  final origin = triggerAlignment(context);
  final reduced = AppMotion.reduced(context);
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Close dialog',
    barrierColor: AppColors.ink.withValues(alpha: 0.35),
    transitionDuration: AppMotion.standard,
    pageBuilder: (dialogContext, _, _) => Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Material(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleLarge),
                if (message != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    message,
                    style: const TextStyle(
                      color: AppColors.inkSoft,
                      height: 1.45,
                    ),
                  ),
                ],
                if (content != null) ...[const SizedBox(height: 14), content],
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    for (final (i, a) in actions(dialogContext).indexed) ...[
                      if (i > 0) const SizedBox(width: 10),
                      a,
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ),
    transitionBuilder: (_, animation, _, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: AppMotion.enter,
        reverseCurve: AppMotion.leave,
      );
      final fade = FadeTransition(opacity: curved, child: child);
      if (reduced) return fade;
      return ScaleTransition(
        scale: Tween(begin: 0.95, end: 1.0).animate(curved),
        alignment: origin,
        child: fade,
      );
    },
  );
}

/// Asks the user to confirm an action. Returns true when confirmed.
Future<bool> confirmAction(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  bool danger = false,
}) async {
  final result = await showAppDialog<bool>(
    context,
    title: title,
    message: message,
    actions: (dialogContext) => [
      AppButton(
        label: 'Cancel',
        kind: AppButtonKind.soft,
        small: true,
        onTap: () => Navigator.of(dialogContext).pop(false),
      ),
      AppButton(
        label: confirmLabel,
        kind: danger ? AppButtonKind.danger : AppButtonKind.primary,
        small: true,
        onTap: () => Navigator.of(dialogContext).pop(true),
      ),
    ],
  );
  return result ?? false;
}

/// Bottom sheet with a title, used for forms and pickers.
Future<T?> showAppSheet<T>(
  BuildContext context, {
  required String title,
  required WidgetBuilder builder,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    // Keeps the sheet below the status bar when the keyboard pushes it up.
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    elevation: 0,
    barrierColor: AppColors.ink.withValues(alpha: 0.28),
    builder: (sheetContext) => _GlassSheet(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
      ),
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.86,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 10),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.line,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: Theme.of(sheetContext).textTheme.titleLarge,
                      ),
                    ),
                    IconSquare(
                      icon: 'close',
                      label: 'Close',
                      onTap: () => Navigator.of(sheetContext).pop(),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                  child: builder(sheetContext),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// Lets the user pick one option from a list in a bottom sheet.
Future<T?> pickOption<T>(
  BuildContext context, {
  required String title,
  required List<T> options,
  required String Function(T) label,
  String Function(T)? subtitle,
  T? selected,
}) {
  return showAppSheet<T>(
    context,
    title: title,
    builder: (sheetContext) => Column(
      children: [
        for (final (i, o) in options.indexed)
          FadeIn(
            index: i,
            child: Pressable(
              onTap: () => Navigator.of(sheetContext).pop(o),
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: o == selected ? AppColors.skySoft : AppColors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: o == selected ? AppColors.sky : AppColors.line,
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            label(o),
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          if (subtitle != null)
                            Text(
                              subtitle(o),
                              style: Theme.of(sheetContext).textTheme.bodySmall,
                            ),
                        ],
                      ),
                    ),
                    if (o == selected)
                      const AppIcon(
                        'check',
                        size: 18,
                        color: AppColors.skyDeep,
                      ),
                  ],
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

/// Confirmation message. With [success] the check mark pulses once, and only
/// callers that have finished the operation should pass it (UI rules 6, 15).
void showToast(BuildContext context, String message, {bool success = true}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 3),
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 96),
        content: Row(
          children: [
            if (success)
              const _Pulse(
                child: AppIcon('check', size: 18, color: AppColors.sky),
              )
            else
              const AppIcon('info', size: 18, color: AppColors.sky),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
}

class _Pulse extends StatelessWidget {
  const _Pulse({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (AppMotion.reduced(context)) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 320),
      curve: AppMotion.move,
      builder: (_, t, child) {
        // Rises to 1.2 at the midpoint and settles back to 1 with no overshoot.
        final scale = 1 + 0.2 * (1 - (2 * t - 1).abs());
        return Transform.scale(scale: scale, child: child);
      },
      child: child,
    );
  }
}

/// Standard layout for a pushed screen: rounded back button, title, actions.
class DetailScaffold extends StatelessWidget {
  const DetailScaffold({
    super.key,
    required this.title,
    required this.children,
    this.actions = const [],
    this.bottom,
  });

  final String title;
  final List<Widget> children;
  final List<Widget> actions;

  /// Pinned bar at the bottom, for the screen's main action.
  final Widget? bottom;

  @override
  Widget build(BuildContext context) {
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    return Scaffold(
      body: AppBackdrop(
        child: SafeArea(
          bottom: false,
          child: Stack(
            children: [
              Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
                    child: Row(
                      children: [
                        IconSquare(
                          icon: 'back',
                          label: 'Back',
                          filled: true,
                          onTap: () => Navigator.of(context).maybePop(),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                        for (final a in actions) ...[
                          const SizedBox(width: 8),
                          a,
                        ],
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      // Leaves room so the last item clears the glass bar.
                      padding: EdgeInsets.fromLTRB(
                        20,
                        6,
                        20,
                        bottom == null ? 40 : 150,
                      ),
                      children: children,
                    ),
                  ),
                ],
              ),
              // Content scrolls underneath this bar, which blurs it.
              if (bottom != null)
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: safeBottom > 0 ? safeBottom : 12,
                  child: Glass(
                    radius: 26,
                    opacity: 0.7,
                    padding: const EdgeInsets.all(12),
                    child: bottom!,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Rounded-top sheet surface that blurs the screen behind it.
class _GlassSheet extends StatelessWidget {
  const _GlassSheet({required this.padding, required this.child});

  final EdgeInsets padding;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    const shape = BorderRadius.vertical(top: Radius.circular(30));
    return ClipRRect(
      borderRadius: shape,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: shape,
            color: AppColors.white.withValues(alpha: 0.86),
            border: Border(
              top: BorderSide(color: AppColors.white.withValues(alpha: 0.9)),
            ),
          ),
          padding: padding,
          child: child,
        ),
      ),
    );
  }
}

/// Labeled text field.
class AppField extends StatelessWidget {
  const AppField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.maxLines = 1,
    this.keyboardType,
    this.onChanged,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final int maxLines;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: controller,
            maxLines: maxLines,
            keyboardType: keyboardType,
            onChanged: onChanged,
            decoration: InputDecoration(hintText: hint),
          ),
        ],
      ),
    );
  }
}

/// Label above any form control.
class FieldLabel extends StatelessWidget {
  const FieldLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Text(
        text,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
    );
  }
}

/// Switch row for settings inside forms.
class ToggleRow extends StatelessWidget {
  const ToggleRow({
    super.key,
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (subtitle != null)
                  Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}
