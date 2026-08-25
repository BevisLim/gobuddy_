import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../common/remote/supabase_client.dart';
import '../model/location_data.dart';

final liveLocationRepositoryProvider = Provider<LiveLocationRepository>(
  (ref) => SupabaseLiveLocationRepository(supabase),
);

abstract interface class LiveLocationRepository {
  Future<List<ShareableTrip>> getActiveTrips(String userId);
  Future<String> startShare({
    required String userId,
    required String tripId,
    required DateTime expiresAt,
    required LocationData location,
  });
  Future<void> updateLocation(String shareId, LocationData location);
  Future<void> stopShare(String shareId);
}

class SupabaseLiveLocationRepository implements LiveLocationRepository {
  const SupabaseLiveLocationRepository(this._client);
  final SupabaseClient _client;

  @override
  Future<List<ShareableTrip>> getActiveTrips(String userId) async {
    _requireUser(userId);
    final memberships = await _client
        .from('matchmaking_trip_members')
        .select('trip_id')
        .eq('user_id', userId);
    final memberIds = memberships
        .map((row) => row['trip_id'] as String)
        .toSet()
        .toList(growable: false);
    final owned = await _client
        .from('matchmaking_trips')
        .select('id,destination,end_date')
        .eq('owner_id', userId)
        .eq('status', 'active');
    final rows = <dynamic>[...owned];
    if (memberIds.isNotEmpty) {
      rows.addAll(await _client
          .from('matchmaking_trips')
          .select('id,destination,end_date')
          .inFilter('id', memberIds)
          .eq('status', 'active'));
    }
    final unique = <String, ShareableTrip>{};
    for (final row in rows) {
      final id = row['id'] as String;
      unique[id] = ShareableTrip(
        id: id,
        destination: row['destination'] as String,
        endDate: DateTime.parse(row['end_date'] as String),
      );
    }
    return unique.values.toList(growable: false);
  }

  @override
  Future<String> startShare({
    required String userId,
    required String tripId,
    required DateTime expiresAt,
    required LocationData location,
  }) async {
    _requireUser(userId);
    final row = await _client.from('live_location_shares').upsert({
      'user_id': userId,
      'trip_id': tripId,
      'latitude': location.latitude,
      'longitude': location.longitude,
      'accuracy': location.accuracy,
      'recorded_at': location.timestamp.toUtc().toIso8601String(),
      'expires_at': expiresAt.toUtc().toIso8601String(),
      'is_active': true,
    }, onConflict: 'user_id,trip_id').select('id').single();
    return row['id'] as String;
  }

  @override
  Future<void> updateLocation(String shareId, LocationData location) async {
    await _client.from('live_location_shares').update({
      'latitude': location.latitude,
      'longitude': location.longitude,
      'accuracy': location.accuracy,
      'recorded_at': location.timestamp.toUtc().toIso8601String(),
    }).eq('id', shareId).eq('user_id', _currentUserId());
  }

  @override
  Future<void> stopShare(String shareId) async {
    await _client
        .from('live_location_shares')
        .update({'is_active': false})
        .eq('id', shareId)
        .eq('user_id', _currentUserId());
  }

  void _requireUser(String userId) {
    if (_currentUserId() != userId) {
      throw StateError('Sign in to share your live location.');
    }
  }

  String _currentUserId() =>
      _client.auth.currentUser?.id ??
      (throw StateError('Sign in to share your live location.'));
}
