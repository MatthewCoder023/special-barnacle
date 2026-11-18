import 'package:material_ui/material_ui.dart';

import '../theme/app_colors.dart';
import '../theme/app_motion.dart';
import 'basics.dart';
import 'glass.dart';

class AppTab {
  const AppTab(this.icon, this.label);

  final String icon;

  /// Not shown, but read by screen readers and used to find a tab by name.
  final String label;
}

/// Floating glass tab bar with icons only. Content scrolls underneath and
/// shows through the blur. A sky disc slides behind the active icon with an
/// ease-in-out move, the active icon darkens and grows slightly, and a small
/// accent dot sits under it.
class AppTabBar extends StatelessWidget {
  const AppTabBar({
    super.key,
    required this.tabs,
    required this.index,
    required this.onChanged,
  });

  final List<AppTab> tabs;
  final int index;
  final ValueChanged<int> onChanged;

  static const height = 62.0;
  static const _disc = 48.0;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final duration = AppMotion.of(context, AppMotion.slow);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        26,
        0,
        26,
        bottomInset > 0 ? bottomInset : 14,
      ),
      child: Glass(
        radius: height / 2,
        blur: 22,
        opacity: 0.56,
        child: SizedBox(
          height: height,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final slot = constraints.maxWidth / tabs.length;
              return Stack(
                children: [
                  AnimatedPositioned(
                    duration: duration,
                    curve: AppMotion.move,
                    left: slot * index + (slot - _disc) / 2,
                    top: (height - _disc) / 2,
                    width: _disc,
                    height: _disc,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: AppColors.sky.withValues(alpha: 0.6),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.white.withValues(alpha: 0.85),
                        ),
                      ),
                    ),
                  ),
                  // Fill the bar so each icon centres on its disc and the
                  // whole slot is tappable.
                  Positioned.fill(
                    child: Row(
                      children: [
                        for (var i = 0; i < tabs.length; i++)
                          Expanded(
                            child: Semantics(
                              button: true,
                              selected: i == index,
                              label: tabs[i].label,
                              child: Tooltip(
                                message: tabs[i].label,
                                excludeFromSemantics: true,
                                child: GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: () => onChanged(i),
                                  child: _TabIcon(
                                    icon: tabs[i].icon,
                                    active: i == index,
                                    duration: duration,
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
            },
          ),
        ),
      ),
    );
  }
}

class _TabIcon extends StatelessWidget {
  const _TabIcon({
    required this.icon,
    required this.active,
    required this.duration,
  });

  final String icon;
  final bool active;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SizedBox.expand(
        child: Stack(
          alignment: Alignment.center,
          children: [
            AnimatedScale(
              scale: active ? 1.08 : 1,
              duration: duration,
              curve: AppMotion.move,
              child: TweenAnimationBuilder<Color?>(
                tween: ColorTween(
                  end: active ? AppColors.ink : AppColors.inkSoft,
                ),
                duration: duration,
                curve: AppMotion.move,
                builder: (_, color, _) => AppIcon(icon, size: 24, color: color),
              ),
            ),
            // Accent dot under the active icon, so the state does not rely on
            // the disc's color alone.
            Positioned(
              bottom: 9,
              child: AnimatedOpacity(
                opacity: active ? 1 : 0,
                duration: duration,
                child: Container(
                  width: 4,
                  height: 4,
                  decoration: const BoxDecoration(
                    color: AppColors.pink,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
