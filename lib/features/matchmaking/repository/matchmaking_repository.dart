import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../common/remote/supabase_client.dart';
import '../model/matchmaking_models.dart';
import '../model/matchmaking_validation.dart';
import '../model/matchmaking_notification.dart';

final matchmakingRepositoryProvider = Provider<MatchmakingRepository>(
  (ref) => const MatchmakingRepository(),
);

class MatchmakingRepository {
  const MatchmakingRepository();

  String get currentUserId {
    try {
      return supabase.auth.currentUser?.id ?? '';
    } catch (_) {
      return '';
    }
  }

  bool get hasAuthenticatedUser {
    try {
      return supabase.auth.currentUser != null;
    } catch (_) {
      return false;
    }
  }

  Future<List<MatchmakingTrip>> fetchTrips() async {
    final user = _requireUser();
    final blockRows = await supabase
        .from('user_blocks')
        .select('blocked_id')
        .eq('blocker_id', user.id);
    final blockedUserIds = {
      for (final row in blockRows) row['blocked_id'] as String,
    };
    final today = _date(DateTime.now());
    final tripResults = await Future.wait([
      supabase
          .from('matchmaking_trips')
          .select()
          .eq('status', 'active')
          .gte('start_date', today)
          .order('created_at')
          .limit(50),
      supabase
          .from('matchmaking_trips')
          .select()
          .eq('owner_id', user.id)
          .order('created_at')
          .limit(100),
    ]);
    final tripsById = <String, Map<String, dynamic>>{};
    for (final rows in tripResults) {
      for (final row in rows) {
        tripsById[row['id'] as String] = Map<String, dynamic>.from(row);
      }
    }
    final tripRows = tripsById.values.toList(growable: false);
    if (tripRows.isEmpty) return const [];

    final tripIds = tripRows.map((row) => row['id'] as String).toList();
    final ownerIds = tripRows
        .map((row) => row['owner_id'] as String)
        .toSet()
        .toList(growable: false);
    final relatedRows = await Future.wait([
      supabase
          .from('matchmaking_trip_styles')
          .select()
          .inFilter('trip_id', tripIds),
      supabase
          .from('matchmaking_trip_members')
          .select()
          .inFilter('trip_id', tripIds),
      supabase.from('matchmaking_profiles').select().inFilter('id', ownerIds),
    ]);
    final styleRows = relatedRows[0];
    final memberRows = relatedRows[1];
    final profileRows = relatedRows[2];
    final stylesByTrip = <String, Set<String>>{};
    for (final row in styleRows) {
      stylesByTrip
          .putIfAbsent(row['trip_id'] as String, () => <String>{})
          .add(row['style'] as String);
    }
    final membersByTrip = <String, int>{};
    for (final row in memberRows) {
      final id = row['trip_id'] as String;
      membersByTrip[id] = (membersByTrip[id] ?? 0) + 1;
    }
    final profiles = <String, Map<String, dynamic>>{
      for (final row in profileRows)
        row['id'] as String: Map<String, dynamic>.from(row),
    };
    return tripRows.where((row) {
      return !blockedUserIds.contains(row['owner_id'] as String);
    }).map((row) {
      final data = Map<String, dynamic>.from(row);
      final ownerId = data['owner_id'] as String;
      final profile = profiles[ownerId];
      final hostName = profile?['display_name'] as String? ?? 'Traveller';
      return MatchmakingTrip(
          id: data['id'] as String,
          destination: data['destination'] as String,
          startDate: DateTime.parse(data['start_date'] as String),
          endDate: DateTime.parse(data['end_date'] as String),
          budget: (data['budget'] as num).round(),
          styles: stylesByTrip[data['id']] ?? const <String>{},
          hostId: ownerId,
          hostName: hostName,
          hostInitials: _initials(hostName),
          imageUrl: data['cover_image_url'] as String? ?? _bali,
          gender: data['preferred_gender'] as String,
          minAge: data['minimum_age'] as int,
          maxAge: data['maximum_age'] as int,
          vacancies: data['vacancies'] as int,
          joined: membersByTrip[data['id']] ?? 0,
          description: data['description'] as String,
          verifiedHost: profile?['verification_status'] == 'verified',
          status: TripStatus.values.byName(data['status'] as String),
          isOwned: ownerId == user.id);
    }).toList(growable: false);
  }

  Future<Set<String>> fetchSavedTripIds() async {
    final user = _requireUser();
    final rows = await supabase
        .from('matchmaking_saved_trips')
        .select('trip_id')
        .eq('user_id', user.id);
    return {for (final row in rows) row['trip_id'] as String};
  }

  Future<Set<String>> fetchJoinedTripIds() async {
    final user = _requireUser();
    final rows = await supabase
        .from('matchmaking_trip_members')
        .select('trip_id')
        .eq('user_id', user.id);
    return {for (final row in rows) row['trip_id'] as String};
  }

  Future<List<JoinRequest>> fetchJoinRequests() async {
    _requireUser();
    final rows = await supabase
        .from('matchmaking_join_requests')
        .select()
        .order('created_at');
    return rows
        .map((row) => JoinRequest(
              id: row['id'] as String,
              tripId: row['trip_id'] as String,
              applicantId: row['applicant_id'] as String,
              message: row['message'] as String,
              decision:
                  ApplicantDecision.values.byName(row['status'] as String),
            ))
        .toList(growable: false);
  }

  Future<List<MatchmakingApplicant>> fetchApplicants() async {
    final user = _requireUser();
    final blockRows = await supabase
        .from('user_blocks')
        .select('blocked_id')
        .eq('blocker_id', user.id);
    final blockedUserIds = {
      for (final row in blockRows) row['blocked_id'] as String,
    };
    final rows = await supabase.from('matchmaking_profiles').select();
    return rows.where((row) {
      return !blockedUserIds.contains(row['id'] as String);
    }).map((row) {
      final name = row['display_name'] as String;
      final dateOfBirth = row['date_of_birth'] == null
          ? null
          : DateTime.parse(row['date_of_birth'] as String);
      return MatchmakingApplicant(
        id: row['id'] as String,
        name: name,
        initials: _initials(name),
        age: dateOfBirth == null ? 18 : _age(dateOfBirth),
        gender: row['gender'] as String? ?? 'Prefer not to say',
        languages: const {},
        styles: const {},
        bio: row['bio'] as String? ?? '',
        introduction: '',
        trips: 0,
        rating: 0,
        verified: row['verification_status'] == 'verified',
      );
    }).toList(growable: false);
  }

  Future<void> decideJoinRequest(
      String requestId, ApplicantDecision decision) async {
    _requireUser();
    await supabase.rpc('decide_matchmaking_join_request', params: {
      'p_request_id': requestId,
      'p_status': decision.name,
    });
  }

  Future<void> sendJoinRequest(String tripId, String message) async {
    _requireUser();
    final normalizedMessage =
        MatchmakingValidation.normalizeRequestMessage(message);
    await supabase.rpc('send_matchmaking_join_request', params: {
      'p_trip_id': tripId,
      'p_message': normalizedMessage,
    });
  }

  Future<List<MatchmakingNotification>> fetchNotifications() async {
    final user = _requireUser();
    final rows = await supabase
        .from('matchmaking_notifications')
        .select()
        .eq('user_id', user.id)
        .order('created_at', ascending: false)
        .limit(50);
    return rows
        .map((row) =>
            MatchmakingNotification.fromMap(Map<String, dynamic>.from(row)))
        .toList(growable: false);
  }

  Future<void> markNotificationsRead() async {
    final user = _requireUser();
    await supabase
        .from('matchmaking_notifications')
        .update({'read_at': DateTime.now().toUtc().toIso8601String()})
        .eq('user_id', user.id)
        .filter('read_at', 'is', null);
  }

  Future<void> saveTrip(MatchmakingTrip trip) async {
    MatchmakingValidation.validateTrip(trip);
    _requireUser();
    await supabase.rpc('save_matchmaking_trip', params: {
      'p_id': trip.id,
      'p_destination': trip.destination,
      'p_start_date': _date(trip.startDate),
      'p_end_date': _date(trip.endDate),
      'p_budget': trip.budget,
      'p_vacancies': trip.vacancies,
      'p_preferred_gender': trip.gender,
      'p_minimum_age': trip.minAge,
      'p_maximum_age': trip.maxAge,
      'p_description': trip.description,
      'p_cover_image_url': trip.imageUrl,
      'p_status': trip.status.name,
      'p_styles': trip.styles.toList(growable: false),
    });
  }

  Future<void> cancelJoinRequest(String requestId) async {
    _requireUser();
    await supabase.rpc('cancel_matchmaking_join_request', params: {
      'p_request_id': requestId,
    });
  }

  Future<void> deleteTrip(String id) async {
    _requireUser();
    await supabase.from('matchmaking_trips').delete().eq('id', id);
  }

  Future<void> setTripSaved(String tripId, {required bool saved}) async {
    final user = _requireUser();
    if (saved) {
      await supabase
          .from('matchmaking_saved_trips')
          .upsert({'user_id': user.id, 'trip_id': tripId});
    } else {
      await supabase
          .from('matchmaking_saved_trips')
          .delete()
          .eq('user_id', user.id)
          .eq('trip_id', tripId);
    }
  }

  User _requireUser() {
    final user = supabase.auth.currentUser;
    if (user == null) throw const AuthException('Please sign in first.');
    return user;
  }

  static String _date(DateTime value) =>
      value.toIso8601String().substring(0, 10);
  static int _age(DateTime dateOfBirth) {
    final today = DateTime.now();
    return today.year -
        dateOfBirth.year -
        ((today.month < dateOfBirth.month ||
                (today.month == dateOfBirth.month &&
                    today.day < dateOfBirth.day))
            ? 1
            : 0);
  }

  static String _initials(String name) => name
      .trim()
      .split(RegExp(r'\s+'))
      .take(2)
      .where((word) => word.isNotEmpty)
      .map((word) => word[0].toUpperCase())
      .join();

  List<String> get discoveryFilters => const [
        'All',
        'Adventure',
        'Culture',
        'Luxury',
        'Nature',
        'Foodie',
      ];

  List<String> get travelStyles => const [
        'Adventure',
        'Foodie',
        'Luxury',
        'Backpacker',
        'Nature',
        'Culture',
      ];
}

const _bali =
    'https://images.unsplash.com/photo-1537996194471-e657df975ab4?auto=format&fit=crop&w=900&q=85';
