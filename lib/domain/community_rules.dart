import '../data/models.dart';
import 'charging_rules.dart';

// ───────────────────────── Event route check (M3) ─────────────────────────

enum Feasibility {
  ok('Can make the trip'),
  engine('Needs engine to finish'),
  flagged('May not reach');

  const Feasibility(this.label);
  final String label;
}

class AttendeeCheck {
  AttendeeCheck(this.rsvp, this.result, this.reason);

  final Rsvp rsvp;
  final Feasibility result;
  final String reason;
}

/// Route of a convoy or drive, with the optional single charging stop.
class EventRoute {
  EventRoute({
    required this.totalKm,
    this.stop,
    this.kmToStop = 0,
    this.kmFromStop = 0,
  });

  final double totalKm;
  final Station? stop;
  final double kmToStop;
  final double kmFromStop;

  static EventRoute? of(CommunityEvent e, Station? stop) {
    final origin = e.origin;
    if (origin == null || !e.type.hasRoute) return null;
    if (stop == null) {
      return EventRoute(
        totalKm: Geo.roadKm(origin.lat, origin.lng, e.venue.lat, e.venue.lng),
      );
    }
    final toStop = Geo.roadKm(origin.lat, origin.lng, stop.lat, stop.lng);
    final fromStop = Geo.roadKm(stop.lat, stop.lng, e.venue.lat, e.venue.lng);
    return EventRoute(
      totalKm: toStop + fromStop,
      stop: stop,
      kmToStop: toStop,
      kmFromStop: fromStop,
    );
  }
}

/// Flags attendees whose vehicles may not reach the stop or the destination.
/// Reuses the M4 range rules: range from the starting battery level, and a
/// charge to 80% at the planned stop.
class EventRules {
  EventRules._();

  static const chargeToPct = 80.0;

  static AttendeeCheck check(Rsvp rsvp, EventRoute route) {
    final v = rsvp.vehicle;
    if (v == null) {
      return AttendeeCheck(rsvp, Feasibility.ok, 'Attending without a vehicle');
    }
    final range = ChargingRules.remainingRangeKm(v, rsvp.startBatteryPct);
    final stop = route.stop;

    String? problem;
    if (stop == null) {
      if (range < route.totalKm) {
        problem =
            'Range of ${range.round()} km is short of the ${route.totalKm.round()} km route';
      }
    } else if (range < route.kmToStop) {
      problem =
          'Range of ${range.round()} km is short of the ${route.kmToStop.round()} km to the charging stop';
    } else if (!ChargingRules.compatible(v, stop)) {
      if (range < route.totalKm) {
        problem = 'No compatible connector at the stop, and range is short of the destination';
      }
    } else if (ChargingRules.remainingRangeKm(v, chargeToPct) <
        route.kmFromStop) {
      problem =
          'Even at ${chargeToPct.round()}% the ${route.kmFromStop.round()} km after the stop is out of range';
    }

    if (problem == null) {
      final arrival = stop == null || !ChargingRules.compatible(v, stop)
          ? ChargingRules.pctAfter(v, rsvp.startBatteryPct, route.totalKm)
          : ChargingRules.pctAfter(v, chargeToPct, route.kmFromStop);
      return AttendeeCheck(
        rsvp,
        Feasibility.ok,
        'About ${arrival.round()}% left on arrival',
      );
    }
    // PHEV and REEV are checked on electric-only range, but the engine can
    // extend it, so they are noted rather than flagged.
    if (v.hasEngine) {
      return AttendeeCheck(
        rsvp,
        Feasibility.engine,
        'Electric range ends early; the engine can cover the rest',
      );
    }
    return AttendeeCheck(rsvp, Feasibility.flagged, problem);
  }
}

// ───────────────────────── Voting rules (M2) ─────────────────────────

class Tally {
  Tally({
    required this.firstChoice,
    required this.totalVotes,
    required this.quorum,
    required this.winner,
    required this.rounds,
  });

  /// First-choice votes per option.
  final List<int> firstChoice;
  final int totalVotes;
  final int quorum;

  /// Index of the winning option, or null for a tie or no votes.
  final int? winner;

  /// Counting rounds used for ranked choice (1 for single choice).
  final int rounds;

  bool get quorumMet => totalVotes >= quorum;
}

/// Counts votes. Single choice: most votes wins. Ranked choice: instant
/// runoff, where the option with the fewest votes is eliminated and its
/// ballots move to the next preference until one option has a majority.
class VotingRules {
  VotingRules._();

  static Tally tally(Proposal p) {
    final ballots = p.ballots.where((b) => b.isNotEmpty).toList();
    final first = List<int>.filled(p.options.length, 0);
    for (final b in ballots) {
      first[b.first]++;
    }
    if (ballots.isEmpty) {
      return Tally(
        firstChoice: first,
        totalVotes: 0,
        quorum: p.quorum,
        winner: null,
        rounds: 0,
      );
    }

    int? winner;
    var rounds = 1;
    if (!p.ranked) {
      winner = _topOf(first);
    } else {
      final eliminated = <int>{};
      while (true) {
        final counts = List<int>.filled(p.options.length, 0);
        var live = 0;
        for (final b in ballots) {
          final choice = b.where((o) => !eliminated.contains(o)).firstOrNull;
          if (choice != null) {
            counts[choice]++;
            live++;
          }
        }
        final remaining = [
          for (var i = 0; i < counts.length; i++)
            if (!eliminated.contains(i)) i,
        ];
        final top = remaining.reduce((a, b) => counts[a] >= counts[b] ? a : b);
        if (counts[top] * 2 > live || remaining.length <= 2) {
          final tied =
              remaining.where((i) => counts[i] == counts[top]).length > 1;
          winner = tied ? null : top;
          break;
        }
        final low = remaining.reduce((a, b) => counts[a] <= counts[b] ? a : b);
        eliminated.add(low);
        rounds++;
      }
    }
    return Tally(
      firstChoice: first,
      totalVotes: ballots.length,
      quorum: p.quorum,
      winner: winner,
      rounds: rounds,
    );
  }

  static int? _topOf(List<int> counts) {
    var top = 0;
    for (var i = 1; i < counts.length; i++) {
      if (counts[i] > counts[top]) top = i;
    }
    final tied = counts.where((c) => c == counts[top]).length > 1;
    return tied ? null : top;
  }
}

// ───────────────────────── Cost comparison (M4) ─────────────────────────

class CostResult {
  CostResult(this.home, this.public, this.fuel);

  /// Estimated monthly cost in pesos for each way of running the vehicle.
  final double home;
  final double public;
  final double fuel;
}

/// Monthly running cost: home charging, public charging and fuel.
///
/// For PHEV and REEV, [electricShare] is the fraction of distance driven on
/// electricity; the rest burns fuel at [fuelKmPerLiter].
class CostRules {
  CostRules._();

  static CostResult compare({
    required double monthlyKm,
    required double kwhPerKm,
    required double homeRate,
    required double publicRate,
    required double fuelPrice,
    required double fuelKmPerLiter,
    double electricShare = 1,
  }) {
    final electricKm = monthlyKm * electricShare;
    final engineKm = monthlyKm - electricKm;
    final engineCost = engineKm / fuelKmPerLiter * fuelPrice;
    return CostResult(
      electricKm * kwhPerKm * homeRate + engineCost,
      electricKm * kwhPerKm * publicRate + engineCost,
      monthlyKm / fuelKmPerLiter * fuelPrice,
    );
  }
}
