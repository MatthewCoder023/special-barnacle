import 'dart:math' as math;

import '../data/models.dart';

/// Distance helpers.
///
/// The proposal takes road distance and travel time from the Google Routes API
/// through a Supabase Edge Function. Until that is connected, [roadKm] and
/// [travelMinutes] estimate them from the straight-line distance, and the
/// screens label the figures as estimates.
class Geo {
  Geo._();

  static const _earthKm = 6371.0;

  /// Straight-line distance by the haversine formula.
  static double haversineKm(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    final dLat = _rad(lat2 - lat1);
    final dLng = _rad(lng2 - lng1);
    final a =
        math.pow(math.sin(dLat / 2), 2) +
        math.cos(_rad(lat1)) *
            math.cos(_rad(lat2)) *
            math.pow(math.sin(dLng / 2), 2);
    return 2 * _earthKm * math.asin(math.sqrt(a));
  }

  /// Estimated road distance: straight line times a detour factor.
  static double roadKm(double lat1, double lng1, double lat2, double lng2) =>
      haversineKm(lat1, lng1, lat2, lng2) * 1.3;

  /// Estimated travel time at an average of 35 km/h.
  static double travelMinutes(double roadKm) => roadKm / 35 * 60;

  /// Shortest distance from a point to the straight segment A–B, in km.
  static double distanceToSegmentKm(
    double lat,
    double lng,
    double aLat,
    double aLng,
    double bLat,
    double bLng,
  ) {
    // Local flat projection is accurate enough over these distances.
    final kx = 111.32 * math.cos(_rad((aLat + bLat) / 2));
    const ky = 110.57;
    final px = (lng - aLng) * kx, py = (lat - aLat) * ky;
    final bx = (bLng - aLng) * kx, by = (bLat - aLat) * ky;
    final len2 = bx * bx + by * by;
    final t = len2 == 0 ? 0.0 : ((px * bx + py * by) / len2).clamp(0.0, 1.0);
    final dx = px - bx * t, dy = py - by * t;
    return math.sqrt(dx * dx + dy * dy);
  }

  static double _rad(double deg) => deg * math.pi / 180;
}

/// Latest status of a station, from reports in the last 24 hours.
enum StationCondition {
  working('Reported working'),
  unknown('No recent report'),
  notWorking('Reported not working');

  const StationCondition(this.label);
  final String label;
}

/// One station evaluated for the driver's vehicle and battery level.
class StationOption {
  StationOption({
    required this.station,
    required this.roadKm,
    required this.minutes,
    required this.passes,
    required this.batteryAfterRoundTrip,
    required this.batteryOnArrival,
    required this.condition,
    required this.waiting,
  });

  final Station station;
  final double roadKm;
  final double minutes;

  /// True when the remaining range covers the road distance there and back.
  final bool passes;
  final double batteryAfterRoundTrip;
  final double batteryOnArrival;
  final StationCondition condition;
  final int waiting;
}

class Recommendation {
  Recommendation(this.options, {this.fallback});

  /// Up to five stations that pass the round-trip check, best first.
  final List<StationOption> options;

  /// When nothing passes: the nearest compatible station reachable one way.
  final StationOption? fallback;
}

class RangeCheck {
  RangeCheck({
    required this.roadKm,
    required this.rangeKm,
    required this.passes,
    required this.batteryOnArrival,
    required this.batteryAfterRoundTrip,
  });

  final double roadKm;
  final double rangeKm;
  final bool passes;
  final double batteryOnArrival;
  final double batteryAfterRoundTrip;
}

enum TripResult { direct, withStop, notFeasible }

class TripPlan {
  TripPlan({
    required this.result,
    required this.roadKm,
    required this.rangeKm,
    this.batteryOnArrival = 0,
    this.stop,
    this.kmToStop = 0,
    this.kmFromStop = 0,
    this.batteryAtStop = 0,
    this.batteryAtDestination = 0,
  });

  final TripResult result;
  final double roadKm;
  final double rangeKm;
  final double batteryOnArrival;
  final Station? stop;
  final double kmToStop;
  final double kmFromStop;
  final double batteryAtStop;
  final double batteryAtDestination;
}

/// Rule-based charging recommendations, range checks and one-stop trip checks,
/// as specified in the proposal's design architecture. These are plain
/// functions so they can move into a Supabase Edge Function unchanged.
class ChargingRules {
  ChargingRules._();

  /// A queue check-in that is not closed expires after this long.
  static const checkInExpiry = Duration(hours: 2);

  /// A trip stop must lie within this distance of the route.
  static const stopCorridorKm = 2.0;

  /// Remaining range from the battery level: energy left divided by the
  /// vehicle's energy use per kilometer. No separate safety reserve is taken;
  /// the battery level left after the trip is shown instead.
  static double remainingRangeKm(Vehicle v, double batteryPct) =>
      batteryPct / 100 * v.batteryKwh / v.kwhPerKm;

  static double pctAfter(Vehicle v, double batteryPct, double km) =>
      (batteryPct - km * v.kwhPerKm / v.batteryKwh * 100)
          .clamp(0.0, 100.0)
          .toDouble();

  static bool compatible(Vehicle v, Station s) =>
      s.connectors.any((c) => v.connectors.contains(c.type));

  static StatusReport? latestReport(Station s) {
    if (s.reports.isEmpty) return null;
    return s.reports.reduce((a, b) => a.createdAt.isAfter(b.createdAt) ? a : b);
  }

  static StationCondition condition(Station s, DateTime now) {
    final latest = latestReport(s);
    if (latest == null || now.difference(latest.createdAt).inHours >= 24) {
      return StationCondition.unknown;
    }
    return latest.working
        ? StationCondition.working
        : StationCondition.notWorking;
  }

  static List<CheckIn> activeCheckIns(Station s, DateTime now) => s.checkIns
      .where((c) => now.difference(c.createdAt) < checkInExpiry)
      .toList();

  static int waitingCount(Station s, DateTime now) =>
      activeCheckIns(s, now).where((c) => !c.charging).length;

  static StationOption evaluate(
    Vehicle v,
    double batteryPct,
    double lat,
    double lng,
    Station s,
    DateTime now,
  ) {
    final road = Geo.roadKm(lat, lng, s.lat, s.lng);
    final range = remainingRangeKm(v, batteryPct);
    return StationOption(
      station: s,
      roadKm: road,
      minutes: Geo.travelMinutes(road),
      passes: range >= road * 2,
      batteryAfterRoundTrip: pctAfter(v, batteryPct, road * 2),
      batteryOnArrival: pctAfter(v, batteryPct, road),
      condition: condition(s, now),
      waiting: waitingCount(s, now),
    );
  }

  /// Ranking: working stations first, unknown next, not-working last; then
  /// no queue before a queue; then travel time; ties by the more recent
  /// report and then the higher charging power.
  static int compare(StationOption a, StationOption b) {
    final byCondition = a.condition.index.compareTo(b.condition.index);
    if (byCondition != 0) return byCondition;
    final byQueue = (a.waiting > 0 ? 1 : 0).compareTo(b.waiting > 0 ? 1 : 0);
    if (byQueue != 0) return byQueue;
    final byTime = a.minutes.round().compareTo(b.minutes.round());
    if (byTime != 0) return byTime;
    final ra = latestReport(a.station)?.createdAt;
    final rb = latestReport(b.station)?.createdAt;
    if (ra != null && rb != null && ra != rb) return rb.compareTo(ra);
    return b.station.maxPowerKw.compareTo(a.station.maxPowerKw);
  }

  /// Compatible stations within the remaining range, ranked.
  ///
  /// Keeps compatible stations within half the remaining range in a straight
  /// line (anything farther cannot pass the round-trip check), takes the six
  /// nearest, checks the round trip by road distance and ranks those that
  /// pass. Up to five are returned and the first is the recommended one.
  static Recommendation recommend({
    required Vehicle vehicle,
    required double batteryPct,
    required double lat,
    required double lng,
    required List<Station> stations,
    required DateTime now,
  }) {
    final range = remainingRangeKm(vehicle, batteryPct);
    final compatibleStations =
        stations.where((s) => compatible(vehicle, s)).toList()..sort(
          (a, b) => Geo.haversineKm(
            lat,
            lng,
            a.lat,
            a.lng,
          ).compareTo(Geo.haversineKm(lat, lng, b.lat, b.lng)),
        );

    final nearest = compatibleStations
        .where((s) => Geo.haversineKm(lat, lng, s.lat, s.lng) <= range / 2)
        .take(6)
        .map((s) => evaluate(vehicle, batteryPct, lat, lng, s, now))
        .toList();

    final passing = nearest.where((o) => o.passes).toList()..sort(compare);
    if (passing.isNotEmpty) return Recommendation(passing.take(5).toList());

    // Nothing passes: show the nearest compatible station reachable one way.
    for (final s in compatibleStations) {
      final option = evaluate(vehicle, batteryPct, lat, lng, s, now);
      if (range >= option.roadKm) {
        return Recommendation(const [], fallback: option);
      }
    }
    return Recommendation(const []);
  }

  /// Round-trip range check to any destination.
  static RangeCheck roundTrip({
    required Vehicle vehicle,
    required double batteryPct,
    required double lat,
    required double lng,
    required double destLat,
    required double destLng,
  }) {
    final road = Geo.roadKm(lat, lng, destLat, destLng);
    final range = remainingRangeKm(vehicle, batteryPct);
    return RangeCheck(
      roadKm: road,
      rangeKm: range,
      passes: range >= road * 2,
      batteryOnArrival: pctAfter(vehicle, batteryPct, road),
      batteryAfterRoundTrip: pctAfter(vehicle, batteryPct, road * 2),
    );
  }

  /// Trip check with at most one charging stop.
  ///
  /// If the remaining range covers the route, the trip is feasible. Otherwise
  /// compatible stations within 2 km of the route are ranked with [compare],
  /// and the first one the vehicle can reach, and from which it can reach the
  /// destination after charging to [chargeToPct], is suggested.
  static TripPlan planTrip({
    required Vehicle vehicle,
    required double batteryPct,
    required double lat,
    required double lng,
    required Place destination,
    required List<Station> stations,
    required DateTime now,
    double chargeToPct = 80,
  }) {
    final road = Geo.roadKm(lat, lng, destination.lat, destination.lng);
    final range = remainingRangeKm(vehicle, batteryPct);
    if (range >= road) {
      return TripPlan(
        result: TripResult.direct,
        roadKm: road,
        rangeKm: range,
        batteryOnArrival: pctAfter(vehicle, batteryPct, road),
      );
    }

    final candidates =
        stations
            .where(
              (s) =>
                  compatible(vehicle, s) &&
                  Geo.distanceToSegmentKm(
                        s.lat,
                        s.lng,
                        lat,
                        lng,
                        destination.lat,
                        destination.lng,
                      ) <=
                      stopCorridorKm,
            )
            .map((s) => evaluate(vehicle, batteryPct, lat, lng, s, now))
            .toList()
          ..sort(compare);

    for (final option in candidates) {
      final s = option.station;
      final toStop = option.roadKm;
      final fromStop = Geo.roadKm(
        s.lat,
        s.lng,
        destination.lat,
        destination.lng,
      );
      final rangeAfterCharge = remainingRangeKm(vehicle, chargeToPct);
      if (range >= toStop && rangeAfterCharge >= fromStop) {
        return TripPlan(
          result: TripResult.withStop,
          roadKm: road,
          rangeKm: range,
          stop: s,
          kmToStop: toStop,
          kmFromStop: fromStop,
          batteryAtStop: pctAfter(vehicle, batteryPct, toStop),
          batteryAtDestination: pctAfter(vehicle, chargeToPct, fromStop),
        );
      }
    }
    return TripPlan(
      result: TripResult.notFeasible,
      roadKm: road,
      rangeKm: range,
    );
  }
}
