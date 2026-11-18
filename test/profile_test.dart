import 'dart:typed_data';

import 'package:evyahe/data/remote/remote_store.dart';
import 'package:evyahe/state/app_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppState state;

  setUp(() {
    state = AppState();
    state.signIn(state.userById('u1')!); // sample member
  });

  group('edit profile', () {
    test('saves name, city and a normalized username', () {
      final error = state.updateProfile(
          name: 'Mika S.', region: 'Pasig', username: ' Mika_Ev ');
      expect(error, isNull);
      expect(state.me.name, 'Mika S.');
      expect(state.me.region, 'Pasig');
      expect(state.me.username, 'mika_ev');
    });

    test('rejects a malformed username and leaves the profile unchanged', () {
      final before = state.me.name;
      for (final bad in ['ab', 'has space', 'way_too_long_for_a_username_x', 'né']) {
        expect(
          state.updateProfile(name: 'Changed', region: '', username: bad),
          isNotNull,
          reason: bad,
        );
      }
      expect(state.me.name, before);
    });

    test('rejects a username another user already has', () {
      state.userById('u2')!.username = 'rafael';
      expect(state.updateProfile(name: 'Mika', region: '', username: 'Rafael'),
          'That username is taken.');
    });

    test('an empty username clears it', () {
      state.updateProfile(name: 'Mika', region: '', username: 'mika');
      state.updateProfile(name: 'Mika', region: '', username: '');
      expect(state.me.username, isNull);
    });
  });

  test('profile photo is kept and removed on sample data', () async {
    await state.setAvatar(Uint8List.fromList([1, 2, 3]), contentType: 'image/png');
    expect(state.me.avatarBytes, isNotNull);
    await state.removeAvatar();
    expect(state.me.avatarBytes, isNull);
    expect(state.me.avatarUrl, isNull);
  });

  test('charging preferences change independently', () {
    state.setChargingPrefs(reservePct: 20);
    expect((state.me.reservePct, state.me.chargeToPct), (20, 80));
    state.setChargingPrefs(chargeToPct: 90);
    expect((state.me.reservePct, state.me.chargeToPct), (20, 90));
  });

  test('sample accounts cannot change a password', () {
    expect(
      state.changePassword('a', 'bbbbbbbb'),
      throwsA(isA<RemoteException>()),
    );
  });

  group('preferences are respected', () {
    int notesFor(String userId) =>
        state.notifications.where((n) => n.userId == userId).length;

    test('a muted kind is not delivered, other kinds and people still are',
        () {
      // u1 mutes community notices; u5 is another member of the same group.
      state.setPreferences(notifyCommunity: false);
      state.signIn(state.userById('u2')!); // the group's leader
      final group = state.communityById('c1')!;
      final u1Before = notesFor('u1'), u5Before = notesFor('u5');

      state.postAnnouncement(group, 'Hello', 'Body', pinned: false);
      expect(notesFor('u1'), u1Before);
      expect(notesFor('u5'), u5Before + 1);

      // Events are a different kind, still on for u1. Created without an
      // announcement so the event notice itself is what gets sent.
      final e = state.createEvent(
        community: group,
        title: 'Meetup',
        type: state.events.first.type,
        description: '',
        start: state.now.add(const Duration(days: 3)),
        venue: state.events.first.venue,
        capacity: 10,
        visibility: state.events.first.visibility,
        announce: false,
      );
      expect(e.title, 'Meetup');
      expect(notesFor('u1'), u1Before + 1);
    });

    test('station activity hides a name when its owner asks', () {
      expect(state.stationName('u2'), 'Rafael Cruz');
      state.userById('u2')!.showNameOnStations = false;
      expect(state.stationName('u2'), 'A member');
      // You always see your own name.
      state.setPreferences(showNameOnStations: false);
      expect(state.stationName('u1'), state.me.name);
    });
  });
}
