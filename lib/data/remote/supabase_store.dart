import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models.dart';
import 'remote_store.dart';
import 'row_mapping.dart';

/// Supabase project settings, passed at build time so no key is committed:
///
///     flutter run --dart-define-from-file=supabase.json
///
/// Without them the app runs on the bundled sample data.
class SupabaseConfig {
  SupabaseConfig._();

  static const url = String.fromEnvironment('SUPABASE_URL');
  static const publishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
  );

  static bool get isConfigured => url.isNotEmpty && publishableKey.isNotEmpty;
}

/// [RemoteStore] backed by Supabase: Auth for accounts and PostgREST for
/// data. Row-level security on the server decides what each call may do.
class SupabaseStore implements RemoteStore {
  SupabaseStore._(this._client);

  final SupabaseClient _client;

  /// Connects with the settings in [SupabaseConfig] and restores any saved
  /// session.
  static Future<SupabaseStore> connect() async {
    final supabase = await Supabase.initialize(
      url: SupabaseConfig.url,
      publishableKey: SupabaseConfig.publishableKey,
    );
    return SupabaseStore._(supabase.client);
  }

  @override
  String? get userId => _client.auth.currentUser?.id;

  @override
  Future<void> signIn(String email, String password) => _guard(
    () => _client.auth.signInWithPassword(email: email, password: password),
  );

  @override
  Future<bool> signUp({
    required String email,
    required String password,
    required String name,
    required String region,
    required PlatformRole role,
  }) => _guard(() async {
    // The database trigger reads these to create the profile.
    final response = await _client.auth.signUp(
      email: email,
      password: password,
      data: {'name': name, 'region': region, 'role': role.name},
    );
    return response.session != null;
  });

  @override
  Future<void> signOut() => _guard(() => _client.auth.signOut());

  /// Deep link the browser returns to after Google or Apple sign-in. It
  /// must be listed under Authentication > URL Configuration in Supabase and
  /// matches the URL scheme registered in the iOS and Android projects.
  static const oauthRedirect = 'ph.evyahe.evyahe://login-callback';

  @override
  Future<Set<String>> oauthProviders() => _guard(() async {
    final response = await http.get(
      Uri.parse('${SupabaseConfig.url}/auth/v1/settings'),
      headers: {'apikey': SupabaseConfig.publishableKey},
    );
    final external =
        (jsonDecode(response.body) as Map<String, dynamic>)['external']
            as Map<String, dynamic>? ??
        const {};
    return {
      for (final name in const ['google', 'apple'])
        if (external[name] == true) name,
    };
  });

  @override
  Future<void> signInWithOAuth(String provider) => _guard(
    () => _client.auth.signInWithOAuth(
      provider == 'apple' ? OAuthProvider.apple : OAuthProvider.google,
      redirectTo: kIsWeb ? null : oauthRedirect,
    ),
  );

  /// Storage bucket for profile photos. Each user writes only to the folder
  /// named after their own id (see the storage policies in the migration).
  static const _avatars = 'avatars';

  @override
  Future<String> uploadAvatar(Uint8List bytes, String contentType) =>
      _guard(() async {
        final path = '${userId!}/avatar';
        await _client.storage
            .from(_avatars)
            .uploadBinary(
              path,
              bytes,
              fileOptions: FileOptions(contentType: contentType, upsert: true),
            );
        // The path never changes, so add a version so the new photo is not
        // hidden by a cached copy of the old one.
        final url = _client.storage.from(_avatars).getPublicUrl(path);
        return '$url?v=${DateTime.now().millisecondsSinceEpoch}';
      });

  @override
  Future<void> removeAvatar() => _guard(
    () => _client.storage.from(_avatars).remove(['${userId!}/avatar']),
  );

  @override
  Future<void> changePassword(String current, String next) => _guard(() async {
    final email = _client.auth.currentUser?.email;
    if (email == null) {
      throw const AuthException(
        'This account signs in with Google or Apple and has no password here.',
      );
    }
    try {
      await _client.auth.signInWithPassword(email: email, password: current);
    } on AuthException {
      throw const AuthException('Your current password is not correct.');
    }
    await _client.auth.updateUser(UserAttributes(password: next));
  });

  @override
  Stream<void> get signedIn => _client.auth.onAuthStateChange
      .where((change) => change.event == AuthChangeEvent.signedIn)
      .map((_) {});

  @override
  Future<RemoteSnapshot> load() => _guard(() async {
    final results = await Future.wait([
      for (final table in remoteTables) _client.from(table).select(),
    ]);
    final counts = await Future.wait([
      for (final fn in remoteFunctions)
        _client
            .rpc(fn)
            .then(
              (rows) => [
                for (final r in rows as List)
                  Map<String, dynamic>.from(r as Map),
              ],
            ),
    ]);
    return buildSnapshot({
      for (var i = 0; i < remoteTables.length; i++) remoteTables[i]: results[i],
      for (var i = 0; i < remoteFunctions.length; i++)
        remoteFunctions[i]: counts[i],
    });
  });

  @override
  Future<void> insert(String table, Map<String, dynamic> row) =>
      _guard(() => _client.from(table).insert(row));

  @override
  Future<void> upsert(String table, Map<String, dynamic> row) =>
      _guard(() => _client.from(table).upsert(row));

  @override
  Future<void> update(
    String table,
    Map<String, dynamic> values,
    Map<String, Object> match,
  ) => _guard(() => _client.from(table).update(values).match(match));

  @override
  Future<void> delete(String table, Map<String, Object> match) =>
      _guard(() => _client.from(table).delete().match(match));

  /// Turns Supabase errors into [RemoteException]s with a plain message.
  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on AuthException catch (e) {
      throw RemoteException(e.message);
    } on PostgrestException catch (e) {
      // 42501 is PostgreSQL's "insufficient privilege": a policy said no.
      throw RemoteException(
        e.code == '42501'
            ? 'You do not have permission to do that.'
            : e.message,
      );
    } catch (_) {
      throw RemoteException(
        'Could not reach the server. Check your connection and try again.',
      );
    }
  }
}
