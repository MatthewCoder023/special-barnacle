import 'package:evyahe/data/models.dart';
import 'package:evyahe/data/seed_data.dart';
import 'package:evyahe/domain/charging_rules.dart';
import 'package:evyahe/domain/route_planner.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 11, 16, 12);
  final seed = SeedData(now);
  final atto = SeedData.vehicles.first;
  const origin = SeedData.userPlace;
  final batangas = SeedData.places[10];
  const service = EstimatedRouteService();

  Future<List<RouteOption>> plan(
    Vehicle? vehicle,
    double battery, {
    double reserve = 10,
    double chargeTo = 80,
    Place? from,
  }) => service.plan(
    origin: from ?? origin,
    destination: batangas,
    vehicle: vehicle,
    batteryPct: battery,
    stations: seed.stations,
    now: now,
    reservePct: reserve,
    chargeToPct: chargeTo,
  );

  test('in range: direct comes first and is feasible', () async {
    final options = await plan(atto, 80);
    expect(options.first.label, 'Direct');
    expect(options.first.feasible, isTrue);
    expect(options.first.batteryOnArrival, greaterThanOrEqualTo(10));
    expect(options.first.detourKm, 0);
  });

  test(
    'beyond range: a route with stops leads, direct is marked infeasible',
    () async {
      final options = await plan(atto, 25);
      expect(options.first.stops, isNotEmpty);
      expect(options.first.feasible, isTrue);
      expect(options.last.label, 'Direct');
      expect(options.last.feasible, isFalse);
    },
  );

  test('when a stop is needed, a charger near the start is offered', () async {
    // Makati to Alabang: the only chargers are 1.2 km from the start and at
    // the destination itself. At 15% the car cannot arrive above the 10%
    // reserve, so it should be told to charge before setting off.
    final alabang = SeedData.places.firstWhere(
      (p) => p.name.startsWith('Alabang'),
    );
    final options = await service.plan(
      origin: origin,
      destination: alabang,
      vehicle: atto,
      batteryPct: 15,
      stations: seed.stations,
      now: now,
    );
    final first = options.first;
    expect(first.feasible, isTrue);
    expect(first.stops.single.station.id, 's1');
    expect(first.batteryOnArrival, greaterThanOrEqualTo(10));
    // The charger at the destination is never a stop.
    expect(
      options.expand((o) => o.stops).any((s) => s.station.id == 's6'),
      isFalse,
    );
  });

  test('the safety reserve is kept at every stop and on arrival', () async {
    for (final reserve in [0.0, 10.0, 20.0]) {
      for (final battery in [25.0, 40.0, 60.0]) {
        final options = await plan(atto, battery, reserve: reserve);
        for (final o in options.where((o) => o.feasible)) {
          for (final s in o.stops) {
            expect(
              s.arriveBattery,
              greaterThanOrEqualTo(reserve - 0.01),
              reason: '${o.label} at $battery% with $reserve% reserve',
            );
          }
          expect(o.batteryOnArrival, greaterThanOrEqualTo(reserve - 0.01));
        }
      }
    }
  });

  test('a reserve can make an otherwise reachable trip need a stop', () async {
    // 117 km direct. At 35% the battery covers it, but not with 20% to spare.
    final without = await plan(atto, 35, reserve: 0);
    final withReserve = await plan(atto, 35, reserve: 20);
    expect(without.first.label, 'Direct');
    expect(without.first.feasible, isTrue);
    final direct = withReserve.firstWhere((o) => o.label == 'Direct');
    expect(direct.feasible, isFalse);
    expect(direct.note, contains('safety reserve'));
  });

  test(
    'stops are compatible, make progress, and stay within the limits',
    () async {
      for (final battery in [20.0, 25.0, 40.0, 80.0]) {
        final options = await plan(atto, battery);
        expect(
          options.length,
          lessThanOrEqualTo(EstimatedRouteService.maxOptions),
        );
        for (final o in options) {
          expect(
            o.stops.length,
            lessThanOrEqualTo(EstimatedRouteService.maxStops),
          );
          expect(o.points.length, o.stops.length + 2);
          var legs = 0.0;
          for (final s in o.stops) {
            expect(ChargingRules.compatible(atto, s.station), isTrue);
            expect(s.kmFromPrevious, greaterThanOrEqualTo(3));
            expect(s.chargeToPct, greaterThanOrEqualTo(s.arriveBattery));
            legs += s.kmFromPrevious;
          }
          expect(o.km, greaterThanOrEqualTo(legs));
          expect(o.detourKm, greaterThanOrEqualTo(0));
          expect(o.minutes, closeTo(o.driveMinutes + o.chargeMinutes, 0.001));
        }
        // No two options use the same stops.
        final keys = [
          for (final o in options) o.stops.map((s) => s.station.id).join(','),
        ];
        expect(keys.toSet().length, keys.length);
      }
    },
  );

  test('progress helpers follow the legs', () async {
    final options = await plan(atto, 25);
    final o = options.first;
    expect(o.nextAt(0).stop, o.stops.first);
    expect(o.nextAt(0).km, closeTo(o.stops.first.kmFromPrevious, 0.001));
    expect(o.nextAt(1).stop, isNull);
    expect(o.nextAt(1).km, closeTo(0, 0.001));
    expect(o.batteryAt(0, 25), closeTo(25, 0.001));
    expect(o.batteryAt(1, 25), closeTo(o.batteryOnArrival!, 0.001));
  });

  test('a chosen starting point changes the route', () async {
    final fromAlabang = await plan(atto, 80, from: SeedData.places[4]);
    final fromMakati = await plan(atto, 80);
    expect(fromAlabang.first.km, lessThan(fromMakati.first.km));
  });

  test('without a vehicle: one direct option and no battery figures', () async {
    final options = await plan(null, 50);
    expect(options.length, 1);
    expect(options.single.batteryOnArrival, isNull);
  });

  test('results are flagged as estimates', () {
    expect(service.isEstimate, isTrue);
  });
}
