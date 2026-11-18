import 'dart:typed_data';

import 'package:evyahe/data/models.dart';
import 'package:evyahe/data/remote/remote_store.dart';
import 'package:evyahe/data/remote/row_mapping.dart';
import 'package:evyahe/state/app_state.dart';
import 'package:flutter_test/flutter_test.dart';

const _me = '11111111-1111-4111-8111-111111111111';
const _leader = '22222222-2222-4222-8222-222222222222';
const _community = '33333333-3333-4333-8333-333333333333';
const _vehicle = '44444444-4444-4444-8444-444444444444';
const _station = '55555555-5555-4555-8555-555555555555';
const _discussion = '66666666-6666-4666-8666-666666666666';
const _proposal = '77777777-7777-4777-8777-777777777777';
const _closedGroup = '88888888-8888-4888-8888-888888888888';
const _stamp = '2026-11-10T08:00:00+00:00';

/// Rows as PostgREST returns them, for a member in one open community.
Map<String, List<Row>> _tables() => {
      'vehicles': [
        {
          'id': _vehicle, 'brand': 'BYD', 'model': 'Atto 3', 'type': 'bev',
          'connectors': ['ccs2', 'type2'], 'battery_kwh': 60.5, 'kwh_per_km': 0.156,
        },
      ],
      'profiles': [
        {'id': _me, 'name': 'Mika Santos', 'role': 'member', 'region': 'Makati', 'vehicle_id': _vehicle, 'verification': 'verified'},
        {'id': _leader, 'name': 'Rafael Cruz', 'role': 'member', 'region': 'Taguig', 'vehicle_id': null, 'verification': 'none'},
      ],
      'communities': [
        {
          'id': _community, 'parent_id': null, 'name': 'Metro EV Owners Circle', 'type': 'region',
          'description': 'd', 'rules': 'r', 'join_policy': 'open', 'requires_verification': false,
          'criteria_model': null, 'criteria_region': 'Metro Manila', 'members_can_propose': true,
          'status': 'approved', 'created_by': _leader, 'created_at': _stamp,
        },
        {
          'id': _closedGroup, 'parent_id': null, 'name': 'Atto 3 Drivers PH', 'type': 'model',
          'description': 'd', 'rules': 'r', 'join_policy': 'approval', 'requires_verification': true,
          'criteria_model': 'BYD Atto 3', 'criteria_region': null, 'members_can_propose': false,
          'status': 'approved', 'created_by': _leader, 'created_at': _stamp,
        },
      ],
      'community_members': [
        {'community_id': _community, 'user_id': _leader, 'role': 'leader', 'joined_at': _stamp},
        {'community_id': _community, 'user_id': _me, 'role': 'member', 'joined_at': _stamp},
        {'community_id': _closedGroup, 'user_id': _leader, 'role': 'leader', 'joined_at': _stamp},
      ],
      'discussions': [
        {
          'id': _discussion, 'community_id': _community, 'author_id': _leader, 'title': 't', 'body': 'b',
          'topic': 'Charging', 'vehicle_model': null, 'is_question': true, 'created_at': _stamp,
        },
      ],
      'helpful_votes': [
        {'target_type': 'discussion', 'target_id': _discussion, 'user_id': _leader},
      ],
      'proposals': [
        {
          'id': _proposal, 'community_id': _community, 'author_id': _leader, 'title': 'p', 'description': '',
          'options': ['A', 'B'], 'ranked': false, 'deadline': '2099-01-01T00:00:00+00:00', 'quorum': 2,
          'closed': false, 'outcome': null, 'created_at': _stamp,
        },
      ],
      'votes': [
        {'proposal_id': _proposal, 'user_id': _leader, 'choice': [1], 'updated_at': _stamp},
      ],
      'stations': [
        {
          'id': _station, 'name': 'Makati CBD Charging Hub', 'operator': 'Metro Charge', 'address': 'a',
          'city': 'Makati', 'lat': 14.5547, 'lng': 121.0244,
          'connectors': [{'type': 'ccs2', 'power_kw': 60}, {'type': 'type2', 'power_kw': 22}],
          'fee': '₱28 per kWh', 'fee_date': '2026-10-27', 'hours': '24 hours', 'parking': 'p',
          'source': 'Sample data', 'source_date': '2026-10-27',
        },
      ],
      'status_reports': [
        {'id': 'x', 'station_id': _station, 'user_id': _leader, 'working': true, 'note': '', 'created_at': _stamp},
      ],
    };

/// In-memory stand-in for Supabase that records every write.
class FakeStore implements RemoteStore {
  final writes = <(String op, String table, Map<String, dynamic> data)>[];
  bool isSignedIn = false;

  /// Table whose writes fail, to exercise the error path.
  String? rejectTable;
  int loads = 0;

  @override
  String? get userId => isSignedIn ? _me : null;

  @override
  Future<void> signIn(String email, String password) async {
    if (password != 'correct-horse') throw RemoteException('Invalid login credentials');
    isSignedIn = true;
  }

  @override
  Future<bool> signUp({
    required String email,
    required String password,
    required String name,
    required String region,
    required PlatformRole role,
  }) async => false; // email confirmation required

  @override
  Future<void> signOut() async => isSignedIn = false;

  @override
  Future<Set<String>> oauthProviders() async => {'google'};

  @override
  Future<void> signInWithOAuth(String provider) async {}

  @override
  Stream<void> get signedIn => const Stream.empty();

  @override
  Future<String> uploadAvatar(Uint8List bytes, String contentType) async =>
      'https://example.invalid/avatar';

  @override
  Future<void> removeAvatar() async {}

  @override
  Future<void> changePassword(String current, String next) async {
    if (current != 'correct-horse') {
      throw RemoteException('Your current password is not correct.');
    }
  }

  @override
  Future<RemoteSnapshot> load() async {
    loads++;
    return buildSnapshot(_tables());
  }

  Future<void> _record(String op, String table, Map<String, dynamic> data) async {
    if (table == rejectTable) throw RemoteException('You do not have permission to do that.');
    writes.add((op, table, data));
  }

  @override
  Future<void> insert(String table, Map<String, dynamic> row) => _record('insert', table, row);

  @override
  Future<void> upsert(String table, Map<String, dynamic> row) => _record('upsert', table, row);

  @override
  Future<void> update(String table, Map<String, dynamic> values, Map<String, Object> match) =>
      _record('update', table, {...values, ...match});

  @override
  Future<void> delete(String table, Map<String, Object> match) => _record('delete', table, match);
}

/// Lets queued writes finish.
Future<void> _settle() => Future<void>.delayed(Duration.zero);

void main() {
  group('buildSnapshot', () {
    final snap = buildSnapshot(_tables());

    test('folds child rows into their parents', () {
      final c = snap.communities.firstWhere((c) => c.id == _community);
      expect(c.members, {_leader: GroupRole.leader, _me: GroupRole.member});
      expect(c.joinedAt[_me], DateTime.parse(_stamp).toLocal());
      expect(c.criteriaRegion, 'Metro Manila');

      expect(snap.discussions.single.helpful, {_leader});
      expect(snap.proposals.single.votes, {_leader: [1]});

      final s = snap.stations.single;
      expect(s.connectors.map((c) => c.type), [ConnectorType.ccs2, ConnectorType.type2]);
      expect(s.maxPowerKw, 60);
      expect(s.reports.single.working, isTrue);
    });

    test('links a profile to its vehicle', () {
      final me = snap.users.firstWhere((u) => u.id == _me);
      expect(me.vehicle?.name, 'BYD Atto 3');
      expect(me.vehicle?.id, _vehicle);
      expect(me.isVerified, isTrue);
    });

    test('tolerates tables that returned no rows', () {
      final empty = buildSnapshot({});
      expect(empty.users, isEmpty);
      expect(empty.stations, isEmpty);
    });
  });

  group('AppState with a backend', () {
    late FakeStore store;
    late AppState state;

    setUp(() async {
      store = FakeStore();
      state = AppState.remote(store);
      await state.signInWithPassword('mika@example.com', 'correct-horse');
    });

    test('sign-in loads records and sets the user', () {
      expect(state.currentUser?.name, 'Mika Santos');
      expect(state.myCommunities.single.name, 'Metro EV Owners Circle');
      expect(state.vehicleCatalog.single.name, 'BYD Atto 3');
      expect(state.loading, isFalse);
    });

    test('wrong password surfaces the server message', () async {
      final other = AppState.remote(FakeStore());
      await expectLater(
        other.signInWithPassword('mika@example.com', 'nope'),
        throwsA(isA<RemoteException>()
            .having((e) => e.message, 'message', 'Invalid login credentials')),
      );
      expect(other.currentUser, isNull);
    });

    test('registration that needs email confirmation does not sign in', () async {
      final other = AppState.remote(FakeStore());
      final signedIn = await other.register(
        email: 'a@b.co', password: 'password1', name: 'A', region: '', role: PlatformRole.member);
      expect(signedIn, isFalse);
      expect(other.currentUser, isNull);
    });

    test('actions are written to the matching tables', () async {
      final c = state.communityById(_community)!;
      state.postDiscussion(c, title: 'Hello', body: 'World', topic: 'Charging', isQuestion: false);
      state.toggleHelpful(state.discussions.first.helpful, type: 'discussion', id: _discussion);
      state.castVote(state.proposals.single, [0]);
      state.reportStatus(state.stations.single, working: false, note: 'Fault');
      state.checkIn(state.stations.single, charging: false);
      await _settle();

      final byTable = {for (final w in store.writes) w.$2: w};
      expect(byTable['discussions']!.$1, 'insert');
      expect(byTable['discussions']!.$3['author_id'], _me);
      expect(byTable['discussions']!.$3['community_id'], _community);
      // Ids are generated on the device as UUIDs.
      expect(byTable['discussions']!.$3['id'],
          matches(RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$')));
      expect(byTable['helpful_votes']!.$3,
          {'target_type': 'discussion', 'target_id': _discussion, 'user_id': _me});
      expect(byTable['votes']!.$1, 'upsert');
      expect(byTable['votes']!.$3['choice'], [0]);
      expect(byTable['status_reports']!.$3['working'], isFalse);
      expect(byTable['check_ins']!.$1, 'upsert');
      // Writes go out in the order the actions happened.
      expect([for (final w in store.writes) w.$2],
          ['discussions', 'helpful_votes', 'votes', 'status_reports', 'check_ins']);
    });

    test('filing a concern also records the author as a supporter', () async {
      state.fileConcern(state.communityById(_community)!,
          category: 'Charging stations', title: 't', details: 'd', location: 'Makati', hasPhoto: false);
      await _settle();
      expect([for (final w in store.writes) w.$2], ['concerns', 'concern_supporters']);
      expect(store.writes.last.$3['concern_id'], store.writes.first.$3['id']);
    });

    test('role rules still apply before anything is sent', () async {
      // Approval-based group: the request is filed, not a membership.
      final closed = state.communityById(_closedGroup)!;
      expect(state.join(closed), isFalse);
      // Members cannot announce.
      state.postAnnouncement(state.communityById(_community)!, 't', 'b', pinned: false);
      await _settle();
      expect([for (final w in store.writes) w.$2], ['join_requests']);
    });

    test('a rejected write shows an error and reloads from the server', () async {
      store.rejectTable = 'discussions';
      final before = store.loads;
      state.postDiscussion(state.communityById(_community)!,
          title: 'Hello', body: 'World', topic: 'Charging', isQuestion: false);
      expect(state.discussions.length, 2); // applied here first
      await _settle();
      await _settle();
      expect(state.syncError, 'You do not have permission to do that.');
      expect(store.loads, before + 1);
      expect(state.discussions.length, 1); // back to what is stored
    });

    test('sample-data mode sends nothing', () {
      final demo = AppState();
      demo.signIn(demo.demoAccounts.first);
      expect(demo.isRemote, isFalse);
      demo.setBattery(40);
      expect(demo.recommendation, isNotNull);
    });
  });
}
