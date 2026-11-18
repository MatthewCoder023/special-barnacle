import 'dart:typed_data';

import '../models.dart';

/// Everything the app loads from the backend in one pass.
class RemoteSnapshot {
  RemoteSnapshot({
    required this.users,
    required this.vehicles,
    required this.communities,
    required this.announcements,
    required this.discussions,
    required this.reviews,
    required this.proposals,
    required this.concerns,
    required this.summaries,
    required this.reports,
    required this.events,
    required this.stations,
    required this.providers,
    required this.audit,
    required this.referenceData,
    required this.notifications,
    required this.news,
  });

  final List<AppUser> users;
  final List<Vehicle> vehicles;
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
  final List<NewsArticle> news;
}

/// A backend failure with a message that can be shown to the user.
class RemoteException implements Exception {
  RemoteException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// The backend, as the app sees it. `SupabaseStore` implements it; `AppState`
/// depends only on this interface, so the rules stay testable without a
/// network and the backend can change without touching the screens.
///
/// Every method throws [RemoteException] on failure.
abstract class RemoteStore {
  /// Id of the signed-in user, or null when signed out.
  String? get userId;

  Future<void> signIn(String email, String password);

  /// Registers an account. Returns true when the user is signed in straight
  /// away, false when they must confirm their email first.
  Future<bool> signUp({
    required String email,
    required String password,
    required String name,
    required String region,
    required PlatformRole role,
  });

  Future<void> signOut();

  /// Sign-in providers switched on at the backend, for example 'google' and
  /// 'apple'. The app only offers the ones listed here.
  Future<Set<String>> oauthProviders();

  /// Starts sign-in with [provider] in the browser. The session arrives
  /// later through [signedIn].
  Future<void> signInWithOAuth(String provider);

  /// Stores the user's profile photo and returns its public link.
  Future<String> uploadAvatar(Uint8List bytes, String contentType);

  Future<void> removeAvatar();

  /// Changes the password. [current] is checked first, so someone holding
  /// an unlocked phone cannot change it without knowing it.
  Future<void> changePassword(String current, String next);

  /// Fires whenever a session starts, including after an OAuth redirect.
  Stream<void> get signedIn;

  /// Loads every record the signed-in user is allowed to see.
  Future<RemoteSnapshot> load();

  Future<void> insert(String table, Map<String, dynamic> row);

  /// Inserts the row, or updates it when its primary key already exists.
  Future<void> upsert(String table, Map<String, dynamic> row);

  Future<void> update(
    String table,
    Map<String, dynamic> values,
    Map<String, Object> match,
  );

  Future<void> delete(String table, Map<String, Object> match);
}
