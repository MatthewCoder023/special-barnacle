import 'dart:math';

import 'package:flutter/foundation.dart';

import '../core/utils/format.dart';
import '../data/models.dart';
import '../data/remote/remote_store.dart';
import '../data/remote/row_mapping.dart';
import '../data/seed_data.dart';
import '../domain/charging_rules.dart';

/// Single source of app data and actions.
///
/// It holds the records in memory and applies the role rules (RBAC). Without
/// a backend it runs on the bundled sample data. With one ([AppState.remote])
/// it loads the records after sign-in and sends every change to the server,
/// where row-level security enforces the same rules.
class AppState extends ChangeNotifier {
  /// Runs on the bundled sample data, with no backend.
  AppState() : this._(SeedData(DateTime.now()));

  AppState._(SeedData seed)
    : remote = null,
      vehicleCatalog = [...SeedData.vehicles],
      users = seed.users,
      communities = seed.communities,
      announcements = seed.announcements,
      discussions = seed.discussions,
      reviews = seed.reviews,
      proposals = seed.proposals,
      concerns = seed.concerns,
      summaries = seed.summaries,
      reports = seed.reports,
      events = seed.events,
      stations = seed.stations,
      providers = seed.providers,
      audit = seed.audit,
      referenceData = seed.referenceData,
      notifications = seed.notifications,
      news = seed.news;

  /// Runs against the backend. Records load after sign-in.
  AppState.remote(RemoteStore this.remote)
    : vehicleCatalog = [],
      users = [],
      communities = [],
      announcements = [],
      discussions = [],
      reviews = [],
      proposals = [],
      concerns = [],
      summaries = [],
      reports = [],
      events = [],
      stations = [],
      providers = [],
      audit = [],
      referenceData = [],
      notifications = [],
      news = [] {
    remote!.signedIn.listen((_) {
      if (currentUser == null) refresh();
    });
  }

  /// The backend, or null when running on sample data.
  final RemoteStore? remote;

  /// Vehicle models a user can choose for their profile.
  final List<Vehicle> vehicleCatalog;
  final List<AppUser> users;
  final List<Community> communities;
  final List<Announcement> announcements;
  final List<Discussion> discussions;
  final List<Review> reviews;
  final List<Proposal> proposals;
  final List<Concern> concerns;
  final List<PositionSummary> summaries;
  final List<ContentReport> reports;
  final List<CommunityEvent> events;
  final List<Station> stations;
  final List<ServiceProvider> providers;
  final List<AuditEntry> audit;
  final List<ReferenceData> referenceData;
  final List<AppNotification> notifications;

  /// EV news for the Home feed, newest first.
  final List<NewsArticle> news;

  AppUser? currentUser;

  /// Battery level the driver enters for charging features.
  double batteryPct = 62;

  /// Driver location. A fixed demo point until device location is connected.
  final Place location = SeedData.userPlace;

  DateTime get now => DateTime.now();

  static final _random = Random.secure();

  /// New record id (UUID v4). It is generated on the device so a record has
  /// the same id here and in the database.
  String _newId() {
    final b = List<int>.generate(16, (_) => _random.nextInt(256));
    b[6] = (b[6] & 0x0f) | 0x40;
    b[8] = (b[8] & 0x3f) | 0x80;
    final h = b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
    return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-'
        '${h.substring(16, 20)}-${h.substring(20)}';
  }

  // ─────────────────────────────── Backend ───────────────────────────────

  bool get isRemote => remote != null;

  /// True while records are loading from the backend.
  bool loading = false;

  /// Message from the last failed load or save, until the screen shows it.
  String? syncError;

  void clearSyncError() => syncError = null;

  /// Restores a saved session when the app starts.
  Future<void> restoreSession() async {
    if (remote?.userId != null) await refresh();
  }

  /// Signs in with email and password. Throws [RemoteException] on failure.
  Future<void> signInWithPassword(String email, String password) async {
    await remote!.signIn(email, password);
    await refresh();
    if (currentUser == null) {
      throw RemoteException(syncError ?? 'Could not load your profile.');
    }
  }

  /// Registers an account. Returns true when signed in straight away, false
  /// when the email must be confirmed first. Throws [RemoteException].
  Future<bool> register({
    required String email,
    required String password,
    required String name,
    required String region,
    required PlatformRole role,
  }) async {
    final signedIn = await remote!.signUp(
      email: email,
      password: password,
      name: name,
      region: region,
      role: role,
    );
    if (signedIn) await refresh();
    return signedIn && currentUser != null;
  }

  /// Sign-in providers the backend has switched on ('google', 'apple').
  Future<Set<String>> oauthProviders() async {
    try {
      return await remote?.oauthProviders() ?? {};
    } on RemoteException {
      return {};
    }
  }

  /// Opens the browser for Google or Apple sign-in. The app signs in when
  /// the browser returns. Throws [RemoteException] if it cannot start.
  Future<void> signInWithOAuth(String provider) =>
      remote!.signInWithOAuth(provider);

  Future<void>? _refreshing;

  /// Reloads every record the signed-in user may see. Calls made while a
  /// reload is running share it instead of starting another.
  Future<void> refresh() =>
      _refreshing ??= _reload().whenComplete(() => _refreshing = null);

  Future<void> _reload() async {
    final store = remote;
    final userId = store?.userId;
    if (store == null || userId == null) return;
    loading = true;
    notifyListeners();
    try {
      final snap = await store.load();
      void fill<T>(List<T> list, List<T> rows) => list
        ..clear()
        ..addAll(rows);
      fill(vehicleCatalog, snap.vehicles);
      fill(users, snap.users);
      fill(communities, snap.communities);
      fill(announcements, snap.announcements);
      fill(discussions, snap.discussions);
      fill(reviews, snap.reviews);
      fill(proposals, snap.proposals);
      fill(concerns, snap.concerns);
      fill(summaries, snap.summaries);
      fill(reports, snap.reports);
      fill(events, snap.events);
      fill(stations, snap.stations);
      fill(providers, snap.providers);
      fill(audit, snap.audit);
      fill(referenceData, snap.referenceData);
      fill(notifications, snap.notifications);
      fill(news, snap.news);
      currentUser = userById(userId);
      if (currentUser == null) syncError = 'Your profile was not found.';
    } on RemoteException catch (e) {
      syncError = e.message;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> _writes = Future.value();

  /// Sends a change to the backend after it has been applied here. Writes go
  /// out one at a time, in order. If the server rejects one, the error is
  /// surfaced and the records reload so the screen shows what is stored.
  void _push(Future<void> Function(RemoteStore r) write) {
    final store = remote;
    if (store == null) return;
    _writes = _writes.then((_) => write(store)).catchError((Object e) {
      syncError = e is RemoteException
          ? e.message
          : 'Could not save your change.';
      refresh();
    });
  }

  static Map<String, Object> _membership(Community c, String userId) => {
    'community_id': c.id,
    'user_id': userId,
  };

  // ─────────────────────────── Session and roles ───────────────────────────

  /// The signed-in user. After sign-out it keeps returning the last user so
  /// screens that are still fading out can finish building.
  AppUser get me => currentUser ?? _lastUser!;
  AppUser? _lastUser;
  bool get isAdmin => me.role == PlatformRole.admin;
  bool get isGuest => me.role == PlatformRole.guest;
  bool get isProvider => me.role == PlatformRole.provider;

  /// Only members can post, review, RSVP, vote and file concerns. Guests are
  /// read-only apart from joining open communities.
  bool get canParticipate => me.role == PlatformRole.member;

  List<AppUser> get demoAccounts => [
    for (final id in SeedData.demoAccountIds) userById(id)!,
  ];

  void signIn(AppUser user) {
    currentUser = user;
    notifyListeners();
  }

  void signOut() {
    remote?.signOut().catchError((Object _) {});
    _lastUser = currentUser;
    currentUser = null;
    notifyListeners();
  }

  void setBattery(double pct) {
    batteryPct = pct;
    notifyListeners();
  }

  void setVehicle(Vehicle vehicle) {
    if (me.vehicle?.name != vehicle.name) {
      me.verification = VerificationStatus.none;
    }
    me.vehicle = vehicle;
    // The server resets verification when the vehicle changes.
    final id = vehicle.id;
    final userId = me.id;
    if (id != null) {
      _push((r) => r.update('profiles', {'vehicle_id': id}, {'id': userId}));
    }
    notifyListeners();
  }

  // ───────────────────────────────── Lookups ─────────────────────────────────

  AppUser? userById(String id) => users.where((u) => u.id == id).firstOrNull;
  String userName(String id) => userById(id)?.name ?? 'Former member';
  Community? communityById(String id) =>
      communities.where((c) => c.id == id).firstOrNull;
  Station? stationById(String? id) =>
      stations.where((s) => s.id == id).firstOrNull;
  ServiceProvider? providerById(String id) =>
      providers.where((p) => p.id == id).firstOrNull;

  // ─────────────────── M1 Community & Tribe Management ───────────────────

  GroupRole? roleIn(Community c) => c.members[me.id];
  bool isMemberOf(Community c) => c.members.containsKey(me.id);
  bool isLeaderOf(Community c) => roleIn(c) == GroupRole.leader;

  /// Leaders and officers manage their own community or tribe.
  bool canManage(Community c) =>
      roleIn(c) == GroupRole.leader || roleIn(c) == GroupRole.officer;

  bool hasRequested(Community c) => c.joinRequests.contains(me.id);

  List<Community> get approvedCommunities => communities
      .where((c) => !c.isTribe && c.status == ApprovalStatus.approved)
      .toList();

  /// Approved communities and tribes the user belongs to.
  List<Community> get myGroups => communities
      .where((c) => c.status == ApprovalStatus.approved && isMemberOf(c))
      .toList();

  List<Community> get myCommunities =>
      myGroups.where((c) => !c.isTribe).toList();

  /// Communities the user created that still await admin approval.
  List<Community> get myPendingCommunities => communities
      .where((c) => c.status == ApprovalStatus.pending && isMemberOf(c))
      .toList();

  List<Community> get managedGroups => myGroups.where(canManage).toList();

  List<Community> tribesOf(Community c) => communities
      .where((t) => t.parentId == c.id && t.status == ApprovalStatus.approved)
      .toList();

  /// Why the current user cannot join [c], or null when they can.
  String? joinBlockReason(Community c) {
    if (isAdmin || isProvider) {
      return 'Only members and guests can join communities.';
    }
    if (isGuest && c.joinPolicy != JoinPolicy.open) {
      return 'Guests can join open communities only. Register as a member to request access.';
    }
    if (c.requiresVerification && !me.isVerified) {
      return 'This ${c.kind} admits verified owners only. Submit your vehicle proof in Profile.';
    }
    final parent = c.parentId == null ? null : communityById(c.parentId!);
    if (parent != null && !isMemberOf(parent)) {
      return 'Join ${parent.name} first to enter its tribes.';
    }
    return null;
  }

  /// Joins an open group, or files a request for an approval-based one.
  /// Returns true when the user became a member right away.
  bool join(Community c) {
    if (joinBlockReason(c) != null || isMemberOf(c)) return false;
    if (c.joinPolicy == JoinPolicy.open) {
      c.members[me.id] = GroupRole.member;
      c.joinedAt[me.id] = now;
      final row = _membership(c, me.id);
      _push((r) => r.insert('community_members', row));
      notifyListeners();
      return true;
    }
    if (!hasRequested(c)) {
      c.joinRequests.add(me.id);
      final row = _membership(c, me.id);
      _push((r) => r.insert('join_requests', row));
    }
    notifyListeners();
    return false;
  }

  void cancelRequest(Community c) {
    c.joinRequests.remove(me.id);
    final row = _membership(c, me.id);
    _push((r) => r.delete('join_requests', row));
    notifyListeners();
  }

  void leave(Community c) {
    _removeFrom(c, me.id);
    notifyListeners();
  }

  void decideRequest(Community c, String userId, {required bool approve}) {
    if (!canManage(c)) return;
    c.joinRequests.remove(userId);
    final row = _membership(c, userId);
    _push((r) => r.delete('join_requests', row));
    if (approve) {
      c.members[userId] = GroupRole.member;
      c.joinedAt[userId] = now;
      _push((r) => r.insert('community_members', row));
      _notify(userId, 'Request approved', 'You are now a member of ${c.name}.');
    } else {
      _notify(
        userId,
        'Request declined',
        'Your request to join ${c.name} was declined.',
      );
    }
    notifyListeners();
  }

  void removeMember(Community c, String userId) {
    if (!canManage(c) || c.members[userId] == GroupRole.leader) return;
    _removeFrom(c, userId);
    notifyListeners();
  }

  /// Removes a user from a group and from its tribes.
  void _removeFrom(Community c, String userId) {
    for (final g in [c, ...tribesOf(c)]) {
      if (g.members.remove(userId) != null) {
        final row = _membership(g, userId);
        _push((r) => r.delete('community_members', row));
      }
    }
  }

  /// Only the leader assigns officers.
  void setRole(Community c, String userId, GroupRole role) {
    if (!isLeaderOf(c) || role == GroupRole.leader) return;
    c.members[userId] = role;
    final row = _membership(c, userId);
    _push((r) => r.update('community_members', {'role': role.name}, row));
    _notify(
      userId,
      'Role updated',
      'You are now ${role.label.toLowerCase()} of ${c.name}.',
    );
    notifyListeners();
  }

  /// Creates a community (pending admin approval, to prevent impersonation of
  /// real clubs) or a tribe under a community the user manages.
  Community createCommunity({
    required String name,
    required CommunityType type,
    required String description,
    required String rules,
    required JoinPolicy joinPolicy,
    required bool requiresVerification,
    String? criteriaModel,
    String? criteriaRegion,
    Community? parent,
  }) {
    final c = Community(
      id: _newId(),
      parentId: parent?.id,
      name: name,
      type: type,
      description: description,
      rules: rules,
      joinPolicy: joinPolicy,
      requiresVerification: requiresVerification,
      criteriaModel: criteriaModel,
      criteriaRegion: criteriaRegion,
      status: parent == null ? ApprovalStatus.pending : ApprovalStatus.approved,
      createdAt: now,
      members: {me.id: GroupRole.leader},
    );
    communities.add(c);
    // The database adds the creator as leader.
    _push((r) => r.insert('communities', Rows.community(c)));
    notifyListeners();
    return c;
  }

  void updateGroupSettings(Community c, void Function(Community) change) {
    if (!canManage(c)) return;
    change(c);
    _push(
      (r) => r.update('communities', Rows.communitySettings(c), {'id': c.id}),
    );
    notifyListeners();
  }

  /// Saves the user's display name, optional username and city. Returns a
  /// message when the username cannot be used, or null once saved.
  String? updateProfile({
    required String name,
    required String region,
    String? username,
  }) {
    final handle = username?.trim().toLowerCase() ?? '';
    if (handle.isNotEmpty) {
      if (!RegExp(r'^[a-z0-9_]{3,20}$').hasMatch(handle)) {
        return 'Usernames are 3 to 20 letters, digits or underscores.';
      }
      if (users.any((u) => u.id != me.id && u.username == handle)) {
        return 'That username is taken.';
      }
    }
    me
      ..name = name
      ..region = region
      ..username = handle.isEmpty ? null : handle;
    final userId = me.id;
    final row = {'name': name, 'region': region, 'username': me.username};
    _push((r) => r.update('profiles', row, {'id': userId}));
    notifyListeners();
    return null;
  }

  /// Sets the profile photo from image [bytes]. With a backend the image is
  /// uploaded first; on sample data it is kept in memory. Throws
  /// [RemoteException] when the upload fails.
  Future<void> setAvatar(Uint8List bytes, {required String contentType}) async {
    final store = remote;
    final user = me;
    if (store == null) {
      user.avatarBytes = bytes;
    } else {
      final url = await store.uploadAvatar(bytes, contentType);
      user
        ..avatarUrl = url
        ..avatarBytes = null;
      _push((r) => r.update('profiles', {'avatar_url': url}, {'id': user.id}));
    }
    notifyListeners();
  }

  Future<void> removeAvatar() async {
    final user = me;
    await remote?.removeAvatar();
    user
      ..avatarUrl = null
      ..avatarBytes = null;
    _push((r) => r.update('profiles', {'avatar_url': null}, {'id': user.id}));
    notifyListeners();
  }

  /// Changes the password after checking the current one. Throws
  /// [RemoteException] with a message that can be shown.
  Future<void> changePassword(String current, String next) async {
    final store = remote;
    if (store == null) {
      throw RemoteException(
        'Sample accounts have no password. Sign in with a real account to change it.',
      );
    }
    await store.changePassword(current, next);
  }

  /// Charging preferences used by route planning.
  void setChargingPrefs({int? chargeToPct, int? reservePct}) {
    final user = me;
    user
      ..chargeToPct = chargeToPct ?? user.chargeToPct
      ..reservePct = reservePct ?? user.reservePct;
    final row = {
      'charge_to_pct': user.chargeToPct,
      'reserve_pct': user.reservePct,
    };
    _push((r) => r.update('profiles', row, {'id': user.id}));
    notifyListeners();
  }

  /// Notification and privacy preferences.
  void setPreferences({
    bool? notifyCommunity,
    bool? notifyEvents,
    bool? notifyPolls,
    bool? showVehicle,
    bool? showNameOnStations,
  }) {
    final user = me;
    user
      ..notifyCommunity = notifyCommunity ?? user.notifyCommunity
      ..notifyEvents = notifyEvents ?? user.notifyEvents
      ..notifyPolls = notifyPolls ?? user.notifyPolls
      ..showVehicle = showVehicle ?? user.showVehicle
      ..showNameOnStations = showNameOnStations ?? user.showNameOnStations;
    final row = {
      'notify_community': user.notifyCommunity,
      'notify_events': user.notifyEvents,
      'notify_polls': user.notifyPolls,
      'show_vehicle': user.showVehicle,
      'show_name_on_stations': user.showNameOnStations,
    };
    _push((r) => r.update('profiles', row, {'id': user.id}));
    notifyListeners();
  }

  /// Name to show beside a station check-in or status report, respecting
  /// that member's privacy preference.
  String stationName(String userId) {
    final user = userById(userId);
    if (user == null) return 'Former member';
    return user.showNameOnStations || userId == me.id ? user.name : 'A member';
  }

  // What the user has contributed, for the activity view in Profile.
  List<Discussion> get myDiscussions =>
      discussions.where((d) => d.authorId == me.id).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  int get myReplyCount => discussions.fold(
    0,
    (n, d) => n + d.replies.where((r) => r.authorId == me.id).length,
  );
  List<Review> get myReviews =>
      reviews.where((r) => r.authorId == me.id).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  List<Concern> get myConcerns =>
      concerns.where((k) => k.authorId == me.id).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  List<CommunityEvent> get myEvents =>
      events
          .where((e) => !e.cancelled && e.rsvps.any((r) => r.userId == me.id))
          .toList()
        ..sort((a, b) => b.start.compareTo(a.start));

  /// Steps left to complete the profile, in the order they are suggested.
  List<String> get profileSteps => [
    if (me.region.trim().isEmpty) 'Add your city',
    if ((me.role == PlatformRole.member || me.role == PlatformRole.guest) &&
        me.vehicle == null)
      'Add your vehicle',
    if (me.role == PlatformRole.member &&
        me.vehicle != null &&
        me.verification == VerificationStatus.none)
      'Verify ownership',
  ];

  void submitVerification() {
    me.verification = VerificationStatus.pending;
    final userId = me.id;
    _push(
      (r) => r.update('profiles', {'verification': 'pending'}, {'id': userId}),
    );
    notifyListeners();
  }

  // ─────────────── M2 Community Engagement & Governance ───────────────

  List<Announcement> announcementsOf(String communityId) =>
      announcements.where((a) => a.communityId == communityId).toList()
        ..sort((a, b) {
          if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
          return b.createdAt.compareTo(a.createdAt);
        });

  List<Discussion> discussionsOf(String communityId) =>
      discussions.where((d) => d.communityId == communityId).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  /// Pinned announcements from every group the user belongs to.
  List<Announcement> get myPinnedAnnouncements {
    final ids = myGroups.map((c) => c.id).toSet();
    return announcements
        .where((a) => a.pinned && ids.contains(a.communityId))
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  void postAnnouncement(
    Community c,
    String title,
    String body, {
    required bool pinned,
  }) {
    if (!canManage(c)) return;
    final a = Announcement(
      id: _newId(),
      communityId: c.id,
      authorId: me.id,
      title: title,
      body: body,
      pinned: pinned,
      createdAt: now,
    );
    announcements.add(a);
    _push((r) => r.insert('announcements', Rows.announcement(a)));
    for (final id in c.members.keys) {
      if (id != me.id) _notify(id, 'New announcement', '${c.name}: $title');
    }
    notifyListeners();
  }

  void togglePin(Announcement a) {
    a.pinned = !a.pinned;
    _push((r) => r.update('announcements', {'pinned': a.pinned}, {'id': a.id}));
    notifyListeners();
  }

  void postDiscussion(
    Community c, {
    required String title,
    required String body,
    required String topic,
    required bool isQuestion,
    String? vehicleModel,
  }) {
    if (!canParticipate || !isMemberOf(c)) return;
    final d = Discussion(
      id: _newId(),
      communityId: c.id,
      authorId: me.id,
      title: title,
      body: body,
      topic: topic,
      isQuestion: isQuestion,
      vehicleModel: vehicleModel,
      createdAt: now,
    );
    discussions.add(d);
    _push((r) => r.insert('discussions', Rows.discussion(d)));
    notifyListeners();
  }

  void addReply(Discussion d, String body) {
    if (!canParticipate) return;
    final reply = Reply(
      id: _newId(),
      authorId: me.id,
      body: body,
      createdAt: now,
    );
    d.replies.add(reply);
    _push((r) => r.insert('replies', Rows.reply(reply, d.id)));
    notifyListeners();
  }

  /// Toggles the user's helpfulness vote in [votes], the vote set of the
  /// discussion, reply or review with the given [type] and [id].
  void toggleHelpful(
    Set<String> votes, {
    required String type,
    required String id,
  }) {
    if (!canParticipate) return;
    final row = {'target_type': type, 'target_id': id, 'user_id': me.id};
    if (votes.remove(me.id)) {
      _push((r) => r.delete('helpful_votes', row));
    } else {
      votes.add(me.id);
      _push((r) => r.insert('helpful_votes', row));
    }
    notifyListeners();
  }

  List<Review> reviewsFor(ReviewTarget target, String id) =>
      reviews.where((r) => r.target == target && r.targetId == id).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  double ratingFor(ReviewTarget target, String id) {
    final list = reviewsFor(target, id);
    if (list.isEmpty) return 0;
    return list.fold<int>(0, (s, r) => s + r.rating) / list.length;
  }

  void addReview(
    ReviewTarget target,
    String targetId,
    int rating,
    List<String> tags,
    String body,
  ) {
    if (!canParticipate) return;
    final review = Review(
      id: _newId(),
      target: target,
      targetId: targetId,
      authorId: me.id,
      rating: rating,
      tags: tags,
      body: body,
      createdAt: now,
    );
    reviews.add(review);
    _push((r) => r.insert('reviews', Rows.review(review)));
    if (target == ReviewTarget.provider) {
      final p = providerById(targetId);
      if (p != null) {
        _notify(
          p.ownerId,
          'New review',
          '${me.name} reviewed ${p.name}.',
          kind: NotifyKind.account,
        );
      }
    }
    notifyListeners();
  }

  List<Proposal> proposalsOf(String communityId) =>
      proposals.where((p) => p.communityId == communityId).toList()
        ..sort((a, b) {
          if (isOpen(a) != isOpen(b)) return isOpen(a) ? -1 : 1;
          return b.createdAt.compareTo(a.createdAt);
        });

  bool isOpen(Proposal p) => !p.closed && p.deadline.isAfter(now);

  /// Open polls in the user's groups that they have not voted on.
  List<Proposal> get myOpenPolls {
    final ids = myGroups.map((c) => c.id).toSet();
    return proposals
        .where(
          (p) =>
              ids.contains(p.communityId) &&
              isOpen(p) &&
              !p.votes.containsKey(me.id),
        )
        .toList();
  }

  bool canPropose(Community c) =>
      canManage(c) || (canParticipate && isMemberOf(c) && c.membersCanPropose);

  void createProposal(
    Community c, {
    required String title,
    required String description,
    required List<String> options,
    required bool ranked,
    required DateTime deadline,
    required int quorum,
  }) {
    if (!canPropose(c)) return;
    final p = Proposal(
      id: _newId(),
      communityId: c.id,
      authorId: me.id,
      title: title,
      description: description,
      options: options,
      ranked: ranked,
      deadline: deadline,
      quorum: quorum,
      createdAt: now,
    );
    proposals.add(p);
    _push((r) => r.insert('proposals', Rows.proposal(p)));
    notifyListeners();
  }

  void castVote(Proposal p, List<int> choice) {
    final c = communityById(p.communityId);
    if (c == null || !canParticipate || !isMemberOf(c) || !isOpen(p)) return;
    p.votes[me.id] = choice;
    final row = {
      'proposal_id': p.id,
      'user_id': me.id,
      'choice': choice,
      'updated_at': now.toUtc().toIso8601String(),
    };
    _push((r) => r.upsert('votes', row));
    notifyListeners();
  }

  void closeProposal(Proposal p, String outcome) {
    final c = communityById(p.communityId);
    if (c == null || !canManage(c)) return;
    p.closed = true;
    p.outcome = outcome;
    _push(
      (r) => r.update(
        'proposals',
        {'closed': true, 'outcome': outcome},
        {'id': p.id},
      ),
    );
    for (final id in c.members.keys) {
      if (id != me.id) {
        _notify(id, 'Poll result published', p.title, kind: NotifyKind.polls);
      }
    }
    notifyListeners();
  }

  List<Concern> concernsOf(String communityId) =>
      concerns.where((k) => k.communityId == communityId).toList()
        ..sort((a, b) => b.supporters.length.compareTo(a.supporters.length));

  void fileConcern(
    Community c, {
    required String category,
    required String title,
    required String details,
    required String location,
    String? stationId,
    required bool hasPhoto,
  }) {
    if (!canParticipate || !isMemberOf(c)) return;
    final k = Concern(
      id: _newId(),
      communityId: c.id,
      authorId: me.id,
      category: category,
      title: title,
      details: details,
      location: location,
      stationId: stationId,
      hasPhoto: hasPhoto,
      createdAt: now,
      supporters: {me.id},
    );
    concerns.add(k);
    _push((r) async {
      await r.insert('concerns', Rows.concern(k));
      await r.insert('concern_supporters', {
        'concern_id': k.id,
        'user_id': k.authorId,
      });
    });
    notifyListeners();
  }

  void toggleSupport(Concern k) {
    final c = communityById(k.communityId);
    if (c == null || !canParticipate || !isMemberOf(c)) return;
    final row = {'concern_id': k.id, 'user_id': me.id};
    if (k.supporters.remove(me.id)) {
      _push((r) => r.delete('concern_supporters', row));
    } else {
      k.supporters.add(me.id);
      _push((r) => r.insert('concern_supporters', row));
    }
    notifyListeners();
  }

  List<PositionSummary> summariesOf(String communityId) =>
      summaries.where((s) => s.communityId == communityId).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  void publishSummary(
    Community c,
    String title,
    String category,
    String text,
    int concernCount,
    int supportCount,
  ) {
    if (!canManage(c)) return;
    final summary = PositionSummary(
      id: _newId(),
      communityId: c.id,
      authorId: me.id,
      title: title,
      category: category,
      text: text,
      concernCount: concernCount,
      supportCount: supportCount,
      createdAt: now,
    );
    summaries.add(summary);
    _push((r) => r.insert('position_summaries', Rows.summary(summary)));
    for (final id in c.members.keys) {
      if (id != me.id) _notify(id, 'Position summary published', title);
    }
    notifyListeners();
  }

  void reportContent({
    required String type,
    required String id,
    required String title,
    required String reason,
    String? communityId,
  }) {
    final report = ContentReport(
      id: _newId(),
      reporterId: me.id,
      contentType: type,
      contentId: id,
      contentTitle: title,
      reason: reason,
      communityId: communityId,
      // Reviews sit outside communities, so they go straight to the admin.
      status: communityId == null ? ReportStatus.escalated : ReportStatus.open,
      createdAt: now,
    );
    reports.add(report);
    _push((r) => r.insert('content_reports', Rows.report(report)));
    notifyListeners();
  }

  /// Reports a leader or officer reviews: open ones in groups they manage.
  List<ContentReport> reportsForLeader(Community c) => reports
      .where((r) => r.communityId == c.id && r.status == ReportStatus.open)
      .toList();

  /// Reports waiting for the platform admin's final decision.
  List<ContentReport> get reportsForAdmin =>
      reports.where((r) => r.status == ReportStatus.escalated).toList();

  /// Leader review: remove the content, dismiss the report, or escalate it.
  /// The platform admin makes the final decision on escalated reports.
  void decideReport(ContentReport r, ReportStatus decision) {
    r.status = decision;
    _push(
      (s) =>
          s.update('content_reports', {'status': decision.name}, {'id': r.id}),
    );
    if (decision == ReportStatus.removed) _removeContent(r);
    if (isAdmin) {
      _log('${decision.label}: report on ${r.contentTitle}');
    }
    notifyListeners();
  }

  void _removeContent(ContentReport r) {
    const tables = {
      'discussion': 'discussions',
      'reply': 'replies',
      'review': 'reviews',
      'concern': 'concerns',
    };
    final table = tables[r.contentType];
    if (table != null) _push((s) => s.delete(table, {'id': r.contentId}));
    switch (r.contentType) {
      case 'discussion':
        discussions.removeWhere((d) => d.id == r.contentId);
      case 'reply':
        for (final d in discussions) {
          d.replies.removeWhere((x) => x.id == r.contentId);
        }
      case 'review':
        reviews.removeWhere((v) => v.id == r.contentId);
      case 'concern':
        concerns.removeWhere((k) => k.id == r.contentId);
    }
  }

  // ───────────────────── M3 Events & Group Trips ─────────────────────

  /// Whether the current user may see [e], by its visibility setting.
  bool canSee(CommunityEvent e) {
    final group = communityById(e.communityId);
    if (group == null) return false;
    if (isAdmin) return true;
    switch (e.visibility) {
      case EventVisibility.public:
        return true;
      case EventVisibility.tribe:
        return isMemberOf(group);
      case EventVisibility.community:
        final parent = group.parentId == null
            ? group
            : communityById(group.parentId!);
        return isMemberOf(group) || (parent != null && isMemberOf(parent));
    }
  }

  List<CommunityEvent> get visibleEvents =>
      events.where(canSee).toList()..sort((a, b) => a.start.compareTo(b.start));

  List<CommunityEvent> get upcomingEvents =>
      visibleEvents.where((e) => !e.cancelled && e.start.isAfter(now)).toList();

  List<CommunityEvent> eventsOf(String communityId) => visibleEvents
      .where((e) => e.communityId == communityId && e.start.isAfter(now))
      .toList();

  Rsvp? myRsvp(CommunityEvent e) =>
      e.rsvps.where((r) => r.userId == me.id).firstOrNull;

  bool canManageEvent(CommunityEvent e) {
    final c = communityById(e.communityId);
    return c != null && canManage(c);
  }

  CommunityEvent createEvent({
    required Community community,
    required String title,
    required EventType type,
    required String description,
    required DateTime start,
    required Place venue,
    Place? origin,
    required int capacity,
    required EventVisibility visibility,
    bool announce = true,
  }) {
    final e = CommunityEvent(
      id: _newId(),
      communityId: community.id,
      creatorId: me.id,
      title: title,
      type: type,
      description: description,
      start: start,
      venue: venue,
      origin: origin,
      capacity: capacity,
      visibility: visibility,
    );
    events.add(e);
    _push((r) => r.insert('events', Rows.event(e)));
    if (announce) {
      // The announcement also notifies every member.
      postAnnouncement(
        community,
        'New event: $title',
        '${type.label} on ${fmtDateTime(start)} at ${venue.name}. '
            'Open Events to see the details and RSVP.',
        pinned: false,
      );
    } else {
      for (final id in community.members.keys) {
        if (id != me.id) {
          _notify(
            id,
            'New event',
            '${community.name}: $title',
            kind: NotifyKind.events,
          );
        }
      }
    }
    notifyListeners();
    return e;
  }

  void cancelEvent(CommunityEvent e) {
    if (!canManageEvent(e)) return;
    e.cancelled = true;
    _push((r) => r.update('events', {'cancelled': true}, {'id': e.id}));
    for (final r in e.rsvps) {
      if (r.userId != me.id) {
        _notify(r.userId, 'Event cancelled', e.title, kind: NotifyKind.events);
      }
    }
    notifyListeners();
  }

  /// RSVPs with the vehicle on the profile and a starting battery level.
  /// Returns false when the event is full.
  bool rsvp(CommunityEvent e, double startBatteryPct) {
    if (!canParticipate) return false;
    final existing = myRsvp(e);
    if (existing != null) {
      existing.startBatteryPct = startBatteryPct;
    } else {
      if (e.attendeeCount >= e.capacity) return false;
      e.rsvps.add(
        Rsvp(
          userId: me.id,
          vehicle: me.vehicle,
          startBatteryPct: startBatteryPct,
        ),
      );
    }
    final row = {
      'event_id': e.id,
      'user_id': me.id,
      'vehicle_id': (existing?.vehicle ?? me.vehicle)?.id,
      'start_battery_pct': startBatteryPct,
    };
    _push((r) => r.upsert('rsvps', row));
    notifyListeners();
    return true;
  }

  void cancelRsvp(CommunityEvent e) {
    e.rsvps.removeWhere((r) => r.userId == me.id);
    final row = {'event_id': e.id, 'user_id': me.id};
    _push((r) => r.delete('rsvps', row));
    notifyListeners();
  }

  void setEventStop(CommunityEvent e, String? stationId) {
    if (!canManageEvent(e)) return;
    e.stopStationId = stationId;
    _push(
      (r) => r.update('events', {'stop_station_id': stationId}, {'id': e.id}),
    );
    notifyListeners();
  }

  // ───────────────────── M4 EV Charging & Services ─────────────────────

  /// Ranked stations for the user's vehicle, or null without a vehicle.
  Recommendation? get recommendation {
    final v = currentUser?.vehicle;
    if (v == null) return null;
    return ChargingRules.recommend(
      vehicle: v,
      batteryPct: batteryPct,
      lat: location.lat,
      lng: location.lng,
      stations: stations,
      now: now,
    );
  }

  void reportStatus(Station s, {required bool working, String note = ''}) {
    if (!canParticipate) return;
    s.reports.add(
      StatusReport(userId: me.id, working: working, note: note, createdAt: now),
    );
    final row = {
      'station_id': s.id,
      'user_id': me.id,
      'working': working,
      'note': note,
    };
    _push((r) => r.insert('status_reports', row));
    notifyListeners();
  }

  CheckIn? myCheckIn(Station s) => ChargingRules.activeCheckIns(
    s,
    now,
  ).where((c) => c.userId == me.id).firstOrNull;

  void checkIn(Station s, {required bool charging}) {
    if (!canParticipate) return;
    s.checkIns.removeWhere((c) => c.userId == me.id);
    s.checkIns.add(CheckIn(userId: me.id, charging: charging, createdAt: now));
    final row = {
      'station_id': s.id,
      'user_id': me.id,
      'charging': charging,
      'created_at': now.toUtc().toIso8601String(),
    };
    _push((r) => r.upsert('check_ins', row));
    notifyListeners();
  }

  void checkOut(Station s) {
    s.checkIns.removeWhere((c) => c.userId == me.id);
    final row = {'station_id': s.id, 'user_id': me.id};
    _push((r) => r.delete('check_ins', row));
    notifyListeners();
  }

  /// Verified (approved) listings shown in the directory.
  List<ServiceProvider> get directory =>
      providers.where((p) => p.status == ApprovalStatus.approved).toList();

  List<ServiceProvider> get myListings =>
      providers.where((p) => p.ownerId == me.id).toList();

  /// Tribes the user leads or serves as officer, which may endorse providers.
  List<Community> get myManagedTribes =>
      managedGroups.where((c) => c.isTribe).toList();

  void toggleRecommendation(ServiceProvider p, Community tribe) {
    if (!canManage(tribe)) return;
    final row = {'provider_id': p.id, 'tribe_id': tribe.id};
    if (p.recommendedBy.remove(tribe.id)) {
      _push((r) => r.delete('provider_recommendations', row));
    } else {
      p.recommendedBy.add(tribe.id);
      _push((r) => r.insert('provider_recommendations', row));
    }
    notifyListeners();
  }

  /// Saves a provider's own listing. New listings wait for admin approval.
  void saveListing({
    ServiceProvider? existing,
    required String name,
    required ProviderCategory category,
    required String description,
    required List<String> brands,
    required List<String> services,
    required String address,
    required String city,
    required String contact,
  }) {
    if (!isProvider) return;
    if (existing != null) {
      existing
        ..name = name
        ..category = category
        ..description = description
        ..brands = brands
        ..services = services
        ..address = address
        ..city = city
        ..contact = contact;
      _push(
        (r) => r.update('providers', Rows.providerDetails(existing), {
          'id': existing.id,
        }),
      );
    } else {
      final listing = ServiceProvider(
        id: _newId(),
        ownerId: me.id,
        name: name,
        category: category,
        description: description,
        brands: brands,
        services: services,
        address: address,
        city: city,
        lat: location.lat,
        lng: location.lng,
        contact: contact,
        status: ApprovalStatus.pending,
      );
      providers.add(listing);
      _push((r) => r.insert('providers', Rows.provider(listing)));
    }
    notifyListeners();
  }

  // ───────────────────── M5 Admin & Community Insights ─────────────────────

  List<Community> get pendingCommunities =>
      communities.where((c) => c.status == ApprovalStatus.pending).toList();

  List<ServiceProvider> get pendingProviders =>
      providers.where((p) => p.status == ApprovalStatus.pending).toList();

  List<AppUser> get pendingVerifications =>
      users.where((u) => u.verification == VerificationStatus.pending).toList();

  void decideCommunity(Community c, {required bool approve}) {
    if (!isAdmin) return;
    c.status = approve ? ApprovalStatus.approved : ApprovalStatus.rejected;
    _push(
      (r) => r.update('communities', {'status': c.status.name}, {'id': c.id}),
    );
    _log('${approve ? 'Approved' : 'Rejected'} community "${c.name}"');
    for (final id in c.members.keys) {
      _notify(
        id,
        approve ? 'Community approved' : 'Community not approved',
        c.name,
      );
    }
    notifyListeners();
  }

  void decideProvider(ServiceProvider p, {required bool approve}) {
    if (!isAdmin) return;
    p.status = approve ? ApprovalStatus.approved : ApprovalStatus.rejected;
    _push(
      (r) => r.update('providers', {'status': p.status.name}, {'id': p.id}),
    );
    _log('${approve ? 'Verified' : 'Rejected'} provider "${p.name}"');
    _notify(
      p.ownerId,
      approve ? 'Listing approved' : 'Listing not approved',
      p.name,
      kind: NotifyKind.account,
    );
    notifyListeners();
  }

  /// Verifies an owner. The submitted document is deleted after the decision.
  void decideVerification(AppUser u, {required bool approve}) {
    if (!isAdmin) return;
    u.verification = approve
        ? VerificationStatus.verified
        : VerificationStatus.rejected;
    _push(
      (r) => r.update(
        'profiles',
        {'verification': u.verification.name},
        {'id': u.id},
      ),
    );
    _log(
      '${approve ? 'Verified' : 'Declined'} owner ${u.name} and deleted the submitted document',
    );
    _notify(
      u.id,
      approve ? 'Ownership verified' : 'Verification declined',
      approve
          ? 'Your profile now shows the verified-owner label.'
          : 'You can submit a new proof from Profile.',
      kind: NotifyKind.account,
    );
    notifyListeners();
  }

  void _log(String action) {
    audit.add(AuditEntry(me.id, action, now));
    final row = {'actor_id': me.id, 'action': action};
    _push((r) => r.insert('audit_log', row));
  }

  // ─────────────────────────── Notifications ───────────────────────────

  void _notify(
    String userId,
    String title,
    String body, {
    NotifyKind kind = NotifyKind.community,
  }) {
    // Seeded directory entries have no owner to notify.
    if (userId.isEmpty) return;
    // Respect the recipient's notification preferences. Account notices
    // (approvals and verification) are always delivered.
    final to = userById(userId);
    final wanted = switch (kind) {
      NotifyKind.community => to?.notifyCommunity ?? true,
      NotifyKind.events => to?.notifyEvents ?? true,
      NotifyKind.polls => to?.notifyPolls ?? true,
      NotifyKind.account => true,
    };
    if (!wanted) return;
    notifications.add(
      AppNotification(userId: userId, title: title, body: body, at: now),
    );
    final row = {'user_id': userId, 'title': title, 'body': body};
    _push((r) => r.insert('notifications', row));
  }

  List<AppNotification> get myNotifications =>
      notifications.where((n) => n.userId == null || n.userId == me.id).toList()
        ..sort((a, b) => b.at.compareTo(a.at));

  int get unreadCount => myNotifications.where((n) => !n.read).length;

  void markNotificationsRead() {
    for (final n in myNotifications) {
      n.read = true;
    }
    final userId = me.id;
    _push(
      (r) => r.update('notifications', {'read': true}, {'user_id': userId}),
    );
    notifyListeners();
  }
}
