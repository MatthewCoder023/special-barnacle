import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_motion.dart';
import '../../core/widgets/basics.dart';
import '../../data/models.dart';

enum MarkerKind { station, stop, destination }

/// A pin on the map.
class MapMarker {
  const MapMarker({
    required this.place,
    required this.kind,
    this.tone = Tone.sky,
    this.dim = false,
    this.onTap,
  });

  final Place place;
  final MarkerKind kind;
  final Tone tone;

  /// Shown faded, for stations the vehicle cannot plug into.
  final bool dim;
  final VoidCallback? onTap;
}

/// Map for the Route tab.
///
/// THIS IS A STAND-IN. It draws a schematic map (a road grid, not real
/// streets) and places everything by latitude and longitude at true scale.
/// It supports drag and pinch, markers, route lines and a moving position
/// marker, which is the same contract `google_maps_flutter` offers. When the
/// Google Maps key is available, replace this widget with a `GoogleMap` that
/// takes the same inputs: markers become `Marker`s, [routes] become
/// `Polyline`s, and [fitTo] becomes a camera update.
class EvMapView extends StatefulWidget {
  const EvMapView({
    super.key,
    required this.origin,
    required this.markers,
    this.routes = const [],
    this.selectedRoute = 0,
    this.progress,
    this.bottomInset = 0,
  });

  /// The driver's location.
  final Place origin;
  final List<MapMarker> markers;

  /// Route lines, each a list of points.
  final List<List<Place>> routes;
  final int selectedRoute;

  /// Position along the selected route from 0 to 1, while navigating.
  final double? progress;

  /// Height covered by the bottom panel, so the map centers above it.
  final double bottomInset;

  @override
  State<EvMapView> createState() => EvMapViewState();
}

class EvMapViewState extends State<EvMapView>
    with SingleTickerProviderStateMixin {
  /// Pixels per kilometer, and the drag offset in pixels.
  double _ppk = 26;
  Offset _pan = Offset.zero;
  double _ppkAtStart = 26;

  late final AnimationController _fly =
      AnimationController(vsync: this, duration: AppMotion.slow);
  double _fromPpk = 26, _toPpk = 26;
  Offset _fromPan = Offset.zero, _toPan = Offset.zero;
  Size _size = Size.zero;

  @override
  void initState() {
    super.initState();
    _fly.addListener(() {
      final t = AppMotion.move.transform(_fly.value);
      setState(() {
        _ppk = _fromPpk + (_toPpk - _fromPpk) * t;
        _pan = Offset.lerp(_fromPan, _toPan, t)!;
      });
    });
  }

  @override
  void dispose() {
    _fly.dispose();
    super.dispose();
  }

  double get _kx =>
      111.32 * math.cos(widget.origin.lat * math.pi / 180);
  static const _ky = 110.57;

  /// Position in kilometers east and south of the driver.
  Offset _world(Place p) => Offset(
        (p.lng - widget.origin.lng) * _kx,
        -(p.lat - widget.origin.lat) * _ky,
      );

  Offset get _center => Offset(
        _size.width / 2,
        (_size.height - widget.bottomInset) * 0.52,
      );

  Offset _screen(Place p) => _center + _pan + _world(p) * _ppk;

  /// Moves the camera so every point in [points] is visible.
  void fitTo(List<Place> points) {
    if (points.isEmpty || _size == Size.zero) return;
    final w = [for (final p in points) _world(p)];
    final minX = w.map((o) => o.dx).reduce(math.min);
    final maxX = w.map((o) => o.dx).reduce(math.max);
    final minY = w.map((o) => o.dy).reduce(math.min);
    final maxY = w.map((o) => o.dy).reduce(math.max);
    final spanX = math.max(maxX - minX, 1.5);
    final spanY = math.max(maxY - minY, 1.5);
    final usableH = (_size.height - widget.bottomInset) * 0.62;
    final ppk = math
        .min((_size.width - 110) / spanX, usableH / spanY)
        .clamp(1.5, 300.0)
        .toDouble();
    final mid = Offset((minX + maxX) / 2, (minY + maxY) / 2);
    _flyTo(ppk, -mid * ppk);
  }

  /// Returns to the driver's position at the default zoom.
  void recenter() => _flyTo(26, Offset.zero);

  void _flyTo(double ppk, Offset pan) {
    _fromPpk = _ppk;
    _fromPan = _pan;
    _toPpk = ppk;
    _toPan = pan;
    if (AppMotion.reduced(context)) {
      setState(() {
        _ppk = ppk;
        _pan = pan;
      });
    } else {
      _fly.forward(from: 0);
    }
  }

  /// Point at fraction [t] along a route line.
  static Offset _along(List<Offset> line, double t) {
    if (line.length < 2) return line.first;
    final lengths = [
      for (var i = 0; i < line.length - 1; i++) (line[i + 1] - line[i]).distance,
    ];
    final total = lengths.fold<double>(0, (a, b) => a + b);
    var remaining = total * t.clamp(0.0, 1.0);
    for (var i = 0; i < lengths.length; i++) {
      if (remaining <= lengths[i] || i == lengths.length - 1) {
        final f = lengths[i] == 0 ? 0.0 : remaining / lengths[i];
        return Offset.lerp(line[i], line[i + 1], f.clamp(0.0, 1.0))!;
      }
      remaining -= lengths[i];
    }
    return line.last;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _size = constraints.biggest;
        final lines = [
          for (final r in widget.routes) [for (final p in r) _screen(p)],
        ];
        final selected = widget.selectedRoute < lines.length
            ? lines[widget.selectedRoute]
            : null;
        final progress = widget.progress;
        final here = progress != null && selected != null
            ? _along(selected, progress)
            : _screen(widget.origin);

        return GestureDetector(
          onScaleStart: (_) {
            _fly.stop();
            _ppkAtStart = _ppk;
          },
          // The map tracks the fingers directly, with no smoothing lag.
          onScaleUpdate: (d) => setState(() {
            final next = (_ppkAtStart * d.scale).clamp(1.5, 300.0).toDouble();
            // Zoom about the focal point so it stays under the fingers.
            final focal = d.localFocalPoint - _center - _pan;
            _pan += d.focalPointDelta + focal * (1 - next / _ppk);
            _ppk = next;
          }),
          child: Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _MapPainter(
                    origin: _center + _pan,
                    ppk: _ppk,
                    lines: lines,
                    selected: widget.selectedRoute,
                    progressPoint: progress == null ? null : here,
                    progress: progress,
                  ),
                ),
              ),
              for (final m in widget.markers)
                _positioned(
                  _screen(m.place),
                  m.kind == MarkerKind.station ? 34 : 44,
                  _Pin(marker: m),
                ),
              _positioned(here, 46, const _DriverMarker()),
            ],
          ),
        );
      },
    );
  }

  Widget _positioned(Offset at, double size, Widget child) => Positioned(
        left: at.dx - size / 2,
        top: at.dy - size / 2,
        width: size,
        height: size,
        child: child,
      );
}

class _Pin extends StatelessWidget {
  const _Pin({required this.marker});

  final MapMarker marker;

  @override
  Widget build(BuildContext context) {
    final m = marker;
    final color = switch (m.tone) {
      Tone.success => AppColors.success,
      Tone.danger => AppColors.danger,
      Tone.pink => AppColors.pink,
      Tone.neutral => AppColors.inkFaint,
      _ => AppColors.skyDeep,
    };
    final big = m.kind != MarkerKind.station;
    final pin = Container(
      decoration: BoxDecoration(
        color: big ? color : AppColors.white,
        shape: BoxShape.circle,
        border: Border.all(
            color: big ? AppColors.white : color, width: big ? 3 : 2),
        boxShadow: [
          BoxShadow(
            color: AppColors.ink.withValues(alpha: 0.16),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: AppIcon(
        m.kind == MarkerKind.destination ? 'pin' : 'charging',
        size: big ? 19 : 15,
        color: big ? AppColors.white : color,
      ),
    );
    return Opacity(
      opacity: m.dim ? 0.45 : 1,
      child: Pressable(onTap: m.onTap, label: m.place.name, child: pin),
    );
  }
}

/// The driver's position: an arrow in a ringed disc.
class _DriverMarker extends StatelessWidget {
  const _DriverMarker();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Your position',
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.sky.withValues(alpha: 0.35),
          shape: BoxShape.circle,
        ),
        padding: const EdgeInsets.all(7),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.ink,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.white, width: 2.5),
          ),
          alignment: Alignment.center,
          // The arrow icon points up-right; turn it to point up.
          child: Transform.rotate(
            angle: -math.pi / 4,
            child:
                const AppIcon('route', size: 14, color: AppColors.white),
          ),
        ),
      ),
    );
  }
}

class _MapPainter extends CustomPainter {
  _MapPainter({
    required this.origin,
    required this.ppk,
    required this.lines,
    required this.selected,
    required this.progressPoint,
    required this.progress,
  });

  /// Screen position of the driver's real location (world 0,0).
  final Offset origin;
  final double ppk;
  final List<List<Offset>> lines;
  final int selected;
  final Offset? progressPoint;
  final double? progress;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
        Offset.zero & size, Paint()..color = const Color(0xFFE6F2F8));

    // Schematic road grid. The spacing steps with zoom so lines stay a
    // comfortable distance apart on screen.
    const steps = [0.25, 0.5, 1.0, 2.0, 5.0, 10.0, 20.0, 50.0, 100.0];
    final gridKm = steps.firstWhere((s) => s * ppk >= 64, orElse: () => 100.0);
    final spacing = gridKm * ppk;
    final minor = Paint()
      ..color = AppColors.white.withValues(alpha: 0.9)
      ..strokeWidth = 5;
    final major = Paint()
      ..color = AppColors.white
      ..strokeWidth = 10;
    final firstX = ((0 - origin.dx) / spacing).floor();
    final lastX = ((size.width - origin.dx) / spacing).ceil();
    for (var i = firstX; i <= lastX; i++) {
      final x = origin.dx + i * spacing;
      canvas.drawLine(
          Offset(x, 0), Offset(x, size.height), i % 5 == 0 ? major : minor);
    }
    final firstY = ((0 - origin.dy) / spacing).floor();
    final lastY = ((size.height - origin.dy) / spacing).ceil();
    for (var i = firstY; i <= lastY; i++) {
      final y = origin.dy + i * spacing;
      canvas.drawLine(
          Offset(0, y), Offset(size.width, y), i % 5 == 0 ? major : minor);
    }

    // Alternatives first, then the selected route on top.
    for (var i = 0; i < lines.length; i++) {
      if (i != selected) _line(canvas, lines[i], AppColors.inkFaint, 5);
    }
    if (selected < lines.length) {
      final line = lines[selected];
      _line(canvas, line, AppColors.white, 11);
      _line(canvas, line, AppColors.pink, 6.5);
      final at = progressPoint;
      if (at != null && progress != null) {
        _line(canvas, _traveled(line, at), AppColors.skyDeep, 6.5);
      }
    }
  }

  /// The part of [line] from its start up to [at].
  List<Offset> _traveled(List<Offset> line, Offset at) {
    final total = [
      for (var i = 0; i < line.length - 1; i++) (line[i + 1] - line[i]).distance,
    ];
    var remaining = total.fold<double>(0, (a, b) => a + b) * (progress ?? 0);
    final out = [line.first];
    for (var i = 0; i < total.length; i++) {
      if (remaining <= total[i]) break;
      remaining -= total[i];
      out.add(line[i + 1]);
    }
    return out..add(at);
  }

  void _line(Canvas canvas, List<Offset> points, Color color, double width) {
    if (points.length < 2) return;
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final p in points.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant _MapPainter old) => true;
}
