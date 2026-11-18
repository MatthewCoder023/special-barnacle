import 'package:evyahe/data/models.dart';
import 'package:evyahe/data/seed_data.dart';
import 'package:evyahe/domain/charging_rules.dart';
import 'package:evyahe/domain/community_rules.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 11, 16, 12);
  final seed = SeedData(now);
  const atto = Vehicle(
    brand: 'BYD',
    model: 'Atto 3',
    type: VehicleType.bev,
    connectors: [ConnectorType.ccs2, ConnectorType.type2],
    batteryKwh: 60.5,
    kwhPerKm: 0.156,
  );

  group('ChargingRules', () {
    test('remaining range is energy left divided by energy use', () {
      expect(ChargingRules.remainingRangeKm(atto, 50), closeTo(193.9, 0.1));
    });

    test('recommends at most five compatible stations that pass', () {
      final rec = ChargingRules.recommend(
        vehicle: atto,
        batteryPct: 60,
        lat: SeedData.userPlace.lat,
        lng: SeedData.userPlace.lng,
        stations: seed.stations,
        now: now,
      );
      expect(rec.options, isNotEmpty);
      expect(rec.options.length, lessThanOrEqualTo(5));
      for (final o in rec.options) {
        expect(o.passes, isTrue);
        expect(ChargingRules.compatible(atto, o.station), isTrue);
      }
      // Stations reported not working never rank above working ones.
      final conditions = [for (final o in rec.options) o.condition.index];
      expect(conditions, orderedEquals([...conditions]..sort()));
    });

    test('falls back to a one-way station when nothing passes', () {
      final rec = ChargingRules.recommend(
        vehicle: atto,
        batteryPct: 0.6,
        lat: SeedData.userPlace.lat,
        lng: SeedData.userPlace.lng,
        stations: seed.stations,
        now: now,
      );
      expect(rec.options, isEmpty);
      expect(rec.fallback, isNotNull);
    });

    test('trip beyond range gets one stop within 2 km of the route', () {
      final plan = ChargingRules.planTrip(
        vehicle: atto,
        batteryPct: 15,
        lat: SeedData.userPlace.lat,
        lng: SeedData.userPlace.lng,
        destination: SeedData.places[10], // Batangas City
        stations: seed.stations,
        now: now,
      );
      expect(plan.result, isNot(TripResult.direct));
      if (plan.result == TripResult.withStop) {
        expect(plan.kmToStop, lessThanOrEqualTo(plan.rangeKm));
      }
    });
  });

  group('VotingRules', () {
    Proposal poll({required bool ranked, required Map<String, List<int>> votes}) =>
        Proposal(
          id: 'p',
          communityId: 'c',
          authorId: 'u',
          title: 't',
          description: '',
          options: ['A', 'B', 'C'],
          ranked: ranked,
          deadline: now,
          quorum: 3,
          createdAt: now,
          votes: votes,
        );

    test('single choice: most votes wins and quorum is checked', () {
      final t = VotingRules.tally(poll(ranked: false, votes: {
        'a': [1],
        'b': [1],
        'c': [0],
      }));
      expect(t.winner, 1);
      expect(t.quorumMet, isTrue);
    });

    test('single choice tie has no winner', () {
      final t = VotingRules.tally(poll(ranked: false, votes: {
        'a': [0],
        'b': [1],
      }));
      expect(t.winner, isNull);
      expect(t.quorumMet, isFalse);
    });

    test('ranked choice transfers votes by instant runoff', () {
      // First choices: A 2, B 2, C 1. C is eliminated and its ballot moves to B.
      final t = VotingRules.tally(poll(ranked: true, votes: {
        'a': [0, 1, 2],
        'b': [0, 2, 1],
        'c': [1, 0, 2],
        'd': [1, 2, 0],
        'e': [2, 1, 0],
      }));
      expect(t.winner, 1);
      expect(t.rounds, 2);
    });
  });

  group('EventRules', () {
    test('flags a BEV that cannot reach the stop, notes a PHEV', () {
      final event = seed.events.first; // BGC to Tagaytay with a stop
      final stop = seed.stations.firstWhere((s) => s.id == event.stopStationId);
      final route = EventRoute.of(event, stop)!;
      final low = Rsvp(userId: 'x', vehicle: atto, startBatteryPct: 5);
      final full = Rsvp(userId: 'y', vehicle: atto, startBatteryPct: 90);
      final phev = Rsvp(
          userId: 'z', vehicle: SeedData.vehicles[2], startBatteryPct: 20);
      expect(EventRules.check(low, route).result, Feasibility.flagged);
      expect(EventRules.check(full, route).result, Feasibility.ok);
      expect(EventRules.check(phev, route).result, Feasibility.engine);
    });
  });

  test('CostRules: PHEV mixes electricity and fuel by electric share', () {
    final r = CostRules.compare(
      monthlyKm: 1000,
      kwhPerKm: 0.2,
      homeRate: 10,
      publicRate: 30,
      fuelPrice: 60,
      fuelKmPerLiter: 12,
      electricShare: 0.5,
    );
    expect(r.home, closeTo(500 * 0.2 * 10 + 500 / 12 * 60, 0.01));
    expect(r.fuel, closeTo(1000 / 12 * 60, 0.01));
  });
}
