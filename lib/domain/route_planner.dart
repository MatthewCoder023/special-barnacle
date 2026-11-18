import 'dart:math' as math;

import '../data/models.dart';
import 'charging_rules.dart';

/// One charging stop on a route.
class ChargingStop {
  ChargingStop({
    required this.station,
    required this.kmFromPrevious,
    required this.arriveBattery,
    required this.chargeToPct,
    required this.chargeMinutes,
  });

  final Station station;

  /// Road distance from the previous point (the start, or the stop before).
  final double kmFromPrevious;

  /// Battery level on reaching the stop, and the level charged to there.
  final double arriveBattery;
  final double chargeToPct;

  /// Estimated time on the charger.
  final double chargeMinutes;

  Place get place => Place(station.name, station.lat, station.lng);
}

/// One way to reach a destination.
class RouteOption {
  RouteOption({
    required this.label,
    required this.points,
    required this.km,
    required this.driveMinutes,
    required this.feasible,
    this.stops = const [],
    this.batteryOnArrival,
    this.detourKm = 0,
    this.note,
  });

  /// "Direct", "Via" a station, or "2 stops".
  final String label;

  /// Points of the route line: start, each stop, destination. A real
  /// routing service returns the full road polyline here.
  final List<Place> points;
  final double km;
  final double driveMinutes;

  /// False when the vehicle cannot complete this route while keeping the
  /// safety reserve.
  final bool feasible;
  final List<ChargingStop> stops;

  /// Battery level on arrival. Null when the user has no vehicle.
  final double? batteryOnArrival;

  /// Extra distance compared with driving direct.
  final double detourKm;

  /// Short explanation, for example why the option is not feasible.
  final String? note;

  double get chargeMinutes =>
      stops.fold<double>(0, (sum, s) => sum + s.chargeMinutes);

  /// Driving time plus charging time.
  double get minutes => driveMinutes + chargeMinutes;

  /// The next point ahead at progress [t] (0 to 1 along the route): the next
  /// charging stop, or null when only the destination remains, with the
  /// distance to it.
  ({ChargingStop? stop, double km}) nextAt(double t) {
    final done = km * t.clamp(0.0, 1.0);
    var mark = 0.0;
    for (final s in stops) {
      mark += s.kmFromPrevious;
      if (done < mark) return (stop: s, km: mark - done);
    }
    return (stop: null, km: km - done);
  }

  /// Battery level at progress [t], starting from [startPct]. It falls
  /// along each leg and steps up at each charging stop.
  double? batteryAt(double t, double startPct) {
    final arrival = batteryOnArrival;
    if (arrival == null) return null;
    final done = km * t.clamp(0.0, 1.0);
    var legStart = 0.0;
    var from = startPct;
    for (final s in stops) {
      final legEnd = legStart + s.kmFromPrevious;
      if (done < legEnd) {
        final f = s.kmFromPrevious == 0
            ? 1.0
            : (done - legStart) / s.kmFromPrevious;
        return from + (s.arriveBattery - from) * f;
      }
      legStart = legEnd;
      from = math.max(s.arriveBattery, s.chargeToPct);
    }
    final last = km - legStart;
    final f = last <= 0 ? 1.0 : (done - legStart) / last;
    return from + (arrival - from) * f;
  }
}

/// Plans routes for the Route tab.
///
/// The screens depend only on this interface. [EstimatedRouteService] is the
/// stand-in used until Google Maps is connected. The real implementation
/// calls a Supabase Edge Function that uses the Google Routes API for road
/// distances, traffic-aware times, alternatives and polylines, and Route
/// Matrix for the distances to candidate stations. The stop-selection rules
/// below stay the same; only the distances become real.
abstract class RouteService {
  /// Whether results are estimates rather than real road data. The screens
  /// label estimated results so users are not misled.
  bool get isEstimate;

  /// Route options from [origin] to [destination].
  ///
  /// [reservePct] is the battery level the driver wants to keep in hand:
  /// the vehicle must reach every stop and the destination at or above it.
  /// [chargeToPct] is the level charged to at each stop.
  Future<List<RouteOption>> plan({
    required Place origin,
    required Place destination,
    required Vehicle? vehicle,
    required double batteryPct,
    required List<Station> stations,
    required DateTime now,
    double chargeToPct = 80,
    double reservePct = 10,
  });
}

/// How the planner chooses between stations that all qualify.
enum _Prefer { progress, power, status }

/// Estimates routes from straight-line distance (see [Geo]). No network.
class EstimatedRouteService implements RouteService {
  const EstimatedRouteService();

  @override
  bool get isEstimate => true;

  /// Most charging stops a route may have. The proposal's stated limit is
  /// one; two is offered here at the team's request, and the paper's
  /// limitation needs updating to match.
  static const maxStops = 2;

  /// Options offered in total, including the direct route.
  static const maxOptions = 3;

  @override
  Future<List<RouteOption>> plan({
    required Place origin,
    required Place destination,
    required Vehicle? vehicle,
    required double batteryPct,
    required List<Station> stations,
    required DateTime now,
    double chargeToPct = 80,
    double reservePct = 10,
  }) async {
    final directKm = _road(origin, destination);

    if (vehicle == null) {
      return [
        RouteOption(
          label: 'Direct',
          points: [origin, destination],
          km: directKm,
          driveMinutes: Geo.travelMinutes(directKm),
          feasible: true,
          note: 'Add a vehicle in Profile to check battery and charging stops.',
        ),
      ];
    }

    final arrival = ChargingRules.pctAfter(vehicle, batteryPct, directKm);
    final range = ChargingRules.remainingRangeKm(vehicle, batteryPct);
    final directFeasible =
        _usableKm(vehicle, batteryPct, reservePct) >= directKm;
    final direct = RouteOption(
      label: 'Direct',
      points: [origin, destination],
      km: directKm,
      driveMinutes: Geo.travelMinutes(directKm),
      feasible: directFeasible,
      batteryOnArrival: arrival,
      note: directFeasible
          ? null
          : range >= directKm
          ? 'Arrives below your ${reservePct.round()}% safety reserve.'
          : vehicle.hasEngine
          ? 'Beyond electric range; the engine covers the rest.'
          : 'Beyond your remaining range of ${range.round()} km.',
    );

    RouteOption? build(_Prefer prefer, {bool forceStop = false}) => _withStops(
      origin: origin,
      destination: destination,
      vehicle: vehicle,
      batteryPct: batteryPct,
      stations: stations,
      now: now,
      chargeToPct: chargeToPct,
      reservePct: reservePct,
      directKm: directKm,
      prefer: prefer,
      forceStop: forceStop,
    );

    final options = <RouteOption>[];
    void add(RouteOption? option) {
      if (option == null || options.length >= maxOptions) return;
      final key = option.stops.map((s) => s.station.id).join(',');
      final seen = options.any(
        (o) => o.stops.map((s) => s.station.id).join(',') == key,
      );
      if (!seen) options.add(option);
    }

    if (directFeasible) {
      // Direct works. Also offer a top-up on the way, to arrive with more.
      add(direct);
      add(build(_Prefer.status, forceStop: true));
      add(build(_Prefer.power, forceStop: true));
    } else {
      add(build(_Prefer.progress)); // fewest stops
      add(build(_Prefer.power)); // fastest chargers
      add(build(_Prefer.status)); // most reliable by recent reports
      add(direct); // shown last, marked as not feasible
    }
    return options;
  }

  static double _road(Place a, Place b) =>
      Geo.roadKm(a.lat, a.lng, b.lat, b.lng);

  /// Distance the vehicle can cover and still arrive at the reserve.
  static double _usableKm(Vehicle v, double batteryPct, double reservePct) =>
      ChargingRules.remainingRangeKm(v, math.max(0.0, batteryPct - reservePct));

  /// Builds one route with charging stops, or null when no such route works.
  ///
  /// From the current point: if the destination is within usable range, the
  /// route is done. Otherwise pick a compatible station near the remaining
  /// route that the vehicle can reach above the reserve and that brings it
  /// closer to the destination, charge there, and repeat.
  RouteOption? _withStops({
    required Place origin,
    required Place destination,
    required Vehicle vehicle,
    required double batteryPct,
    required List<Station> stations,
    required DateTime now,
    required double chargeToPct,
    required double reservePct,
    required double directKm,
    required _Prefer prefer,
    required bool forceStop,
  }) {
    // An optional top-up right at the start or the end adds nothing. When a
    // stop is needed, a charger near the start is the right advice (charge
    // before setting off), so only a charger at the destination itself is
    // left out: the driver reaches it anyway.
    final edge = math.max(3.0, directKm * 0.1);
    const atDestinationKm = 1.0;
    final stops = <ChargingStop>[];
    var here = origin;
    var battery = batteryPct;
    var mustStop = forceStop;

    while (true) {
      final toDestination = _road(here, destination);
      final usable = _usableKm(vehicle, battery, reservePct);
      if (!mustStop && usable >= toDestination) break;
      if (stops.length >= maxStops) return null;

      final candidates = stations.where((s) {
        if (stops.any((x) => x.station.id == s.id)) return false;
        if (!ChargingRules.compatible(vehicle, s)) return false;
        final offRoute = Geo.distanceToSegmentKm(
          s.lat,
          s.lng,
          here.lat,
          here.lng,
          destination.lat,
          destination.lng,
        );
        if (offRoute > ChargingRules.stopCorridorKm) return false;
        final leg = Geo.roadKm(here.lat, here.lng, s.lat, s.lng);
        final remaining = Geo.roadKm(
          s.lat,
          s.lng,
          destination.lat,
          destination.lng,
        );
        final minLeg = mustStop ? edge : 0.0;
        final minRemaining = mustStop ? edge : atDestinationKm;
        return leg >= minLeg &&
            leg <= usable &&
            remaining >= minRemaining &&
            remaining < toDestination;
      }).toList();
      if (candidates.isEmpty) return null;

      double remainingAfter(Station s) =>
          Geo.roadKm(s.lat, s.lng, destination.lat, destination.lng);
      int rank(Station s) => ChargingRules.condition(s, now).index;
      // Stations reported not working in the last 24 hours go last whatever
      // the preference.
      candidates.sort((a, b) {
        final aDown = rank(a) == StationCondition.notWorking.index ? 1 : 0;
        final bDown = rank(b) == StationCondition.notWorking.index ? 1 : 0;
        if (aDown != bDown) return aDown.compareTo(bDown);
        switch (prefer) {
          case _Prefer.progress:
            return remainingAfter(a).compareTo(remainingAfter(b));
          case _Prefer.power:
            final byPower = b.maxPowerKw.compareTo(a.maxPowerKw);
            return byPower != 0
                ? byPower
                : remainingAfter(a).compareTo(remainingAfter(b));
          case _Prefer.status:
            final byStatus = rank(a).compareTo(rank(b));
            if (byStatus != 0) return byStatus;
            final byQueue = ChargingRules.waitingCount(
              a,
              now,
            ).compareTo(ChargingRules.waitingCount(b, now));
            return byQueue != 0
                ? byQueue
                : remainingAfter(a).compareTo(remainingAfter(b));
        }
      });

      final s = candidates.first;
      final leg = Geo.roadKm(here.lat, here.lng, s.lat, s.lng);
      final arrive = ChargingRules.pctAfter(vehicle, battery, leg);
      final target = math.max(arrive, chargeToPct);
      final kwh = (target - arrive) / 100 * vehicle.batteryKwh;
      // Average charging power is taken as 80% of the station's maximum.
      final chargeMinutes = s.maxPowerKw <= 0
          ? 0.0
          : kwh / (s.maxPowerKw * 0.8) * 60;
      stops.add(
        ChargingStop(
          station: s,
          kmFromPrevious: leg,
          arriveBattery: arrive,
          chargeToPct: target,
          chargeMinutes: chargeMinutes,
        ),
      );
      here = Place(s.name, s.lat, s.lng);
      battery = target;
      mustStop = false;
    }

    final lastLeg = _road(here, destination);
    final km =
        stops.fold<double>(0, (sum, s) => sum + s.kmFromPrevious) + lastLeg;
    return RouteOption(
      label: stops.length == 1
          ? 'Via ${stops.single.station.name}'
          : '${stops.length} stops',
      points: [origin, for (final s in stops) s.place, destination],
      km: km,
      driveMinutes: Geo.travelMinutes(km),
      feasible: true,
      stops: stops,
      batteryOnArrival: ChargingRules.pctAfter(vehicle, battery, lastLeg),
      detourKm: math.max(0.0, km - directKm),
    );
  }
}

/// The route service the app uses. Swap this one line for the Google-backed
/// implementation when the Maps integration is ready.
const RouteService routeService = EstimatedRouteService();
