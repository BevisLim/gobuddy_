import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../common/remote/supabase_client.dart';
import '../model/matchmaking_models.dart';

final matchmakingRepositoryProvider = Provider<MatchmakingRepository>(
  (ref) => const MatchmakingRepository(),
);

class MatchmakingRepository {
  const MatchmakingRepository();

  bool get hasAuthenticatedUser {
    try {
      return supabase.auth.currentUser != null;
    } catch (_) {
      return false;
    }
  }

  Future<List<MatchmakingTrip>> fetchTrips() async {
    final user = _requireUser();
    final tripRows =
        await supabase.from('matchmaking_trips').select().order('created_at');
    final styleRows = await supabase.from('matchmaking_trip_styles').select();
    final memberRows = await supabase.from('matchmaking_trip_members').select();
    final profileRows = await supabase.from('matchmaking_profiles').select();
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
    return tripRows.map((row) {
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

  Future<void> saveTrip(MatchmakingTrip trip) async {
    final user = _requireUser();
    await supabase.from('matchmaking_trips').upsert({
      'id': trip.id,
      'owner_id': user.id,
      'destination': trip.destination,
      'start_date': _date(trip.startDate),
      'end_date': _date(trip.endDate),
      'budget': trip.budget,
      'vacancies': trip.vacancies,
      'preferred_gender': trip.gender,
      'minimum_age': trip.minAge,
      'maximum_age': trip.maxAge,
      'description': trip.description,
      'cover_image_url': trip.imageUrl.isEmpty ? null : trip.imageUrl,
      'status': trip.status.name,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
    await supabase
        .from('matchmaking_trip_styles')
        .delete()
        .eq('trip_id', trip.id);
    if (trip.styles.isNotEmpty) {
      await supabase.from('matchmaking_trip_styles').insert([
        for (final style in trip.styles) {'trip_id': trip.id, 'style': style}
      ]);
    }
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

  List<MatchmakingTrip> get trips => [
        MatchmakingTrip(
            id: 'tokyo',
            destination: 'Tokyo, Japan',
            startDate: DateTime(2026, 5, 14),
            endDate: DateTime(2026, 5, 21),
            budget: 1800,
            styles: const {'Adventure', 'Nature'},
            hostId: 'sophia',
            hostName: 'Sophia Lee',
            hostInitials: 'SL',
            imageUrl: _tokyo,
            gender: 'Any',
            minAge: 24,
            maxAge: 38,
            vacancies: 6,
            joined: 3,
            description:
                'Hiking mountain passes, quiet alpine stays, and long Italian lunches. Looking for kind, curious people who love early starts.'),
        MatchmakingTrip(
            id: 'kyoto',
            destination: 'Kyoto, Japan',
            startDate: DateTime(2026, 10, 8),
            endDate: DateTime(2026, 10, 15),
            budget: 1400,
            styles: const {'Culture', 'Foodie'},
            hostId: 'james',
            hostName: 'James Park',
            hostInitials: 'JP',
            imageUrl: _kyoto,
            gender: 'Any',
            minAge: 25,
            maxAge: 40,
            vacancies: 4,
            joined: 2,
            description:
                'Autumn temples, tea ceremonies, bamboo groves, and local food. Looking for thoughtful travellers who enjoy a relaxed pace.'),
        MatchmakingTrip(
            id: 'bali',
            destination: 'Bali, Indonesia',
            startDate: DateTime(2026, 9, 5),
            endDate: DateTime(2026, 9, 15),
            budget: 1200,
            styles: const {'Nature', 'Adventure'},
            hostId: 'current-user',
            hostName: 'Morgan Lee',
            hostInitials: 'ML',
            imageUrl: _bali,
            gender: 'Any',
            minAge: 22,
            maxAge: 35,
            vacancies: 5,
            joined: 2,
            description:
                'Ubud, waterfalls, beaches, and a flexible island itinerary.',
            isOwned: true),
        MatchmakingTrip(
            id: 'paris',
            destination: 'Paris, France',
            startDate: DateTime(2026, 10, 1),
            endDate: DateTime(2026, 10, 8),
            budget: 2500,
            styles: const {'Luxury', 'Culture'},
            hostId: 'current-user',
            hostName: 'Morgan Lee',
            hostInitials: 'ML',
            imageUrl: _paris,
            gender: 'Female',
            minAge: 28,
            maxAge: 40,
            vacancies: 2,
            joined: 0,
            description: 'Museums, neighbourhood walks, and memorable dining.',
            status: TripStatus.closed,
            isOwned: true),
      ];

  List<MatchmakingApplicant> get applicants => const [
        MatchmakingApplicant(
            id: 'priya',
            name: 'Priya Sharma',
            initials: 'PS',
            age: 28,
            gender: 'Female',
            languages: {'English', 'Hindi', 'Tamil'},
            styles: {'Culture', 'Foodie'},
            trips: 12,
            rating: 4.9,
            bio:
                'Solo traveller from Mumbai. Visited 18 countries. Love markets, museums, and late-night street food adventures.',
            introduction:
                'Your trip sounds perfect. I am easy-going, punctual, and love exploring local places.'),
        MatchmakingApplicant(
            id: 'lucas',
            name: 'Lucas Mendes',
            initials: 'LM',
            age: 31,
            gender: 'Male',
            languages: {'English', 'Portuguese', 'Spanish'},
            styles: {'Adventure', 'Backpacker'},
            trips: 8,
            rating: 4.7,
            bio:
                'Brazilian nomad who prefers active days and local experiences.',
            introduction: 'I am flexible and love spontaneous travel plans.'),
        MatchmakingApplicant(
            id: 'yuki',
            name: 'Yuki Tanaka',
            initials: 'YT',
            age: 26,
            gender: 'Female',
            languages: {'English', 'Japanese'},
            styles: {'Culture', 'Nature'},
            trips: 5,
            rating: 4.8,
            bio:
                'Based in Osaka. I travel for quiet moments and local culture.',
            introduction: 'I know hidden gems that most visitors miss.',
            verified: false),
      ];

  List<JoinRequest> get requests => const [
        JoinRequest(
            id: 'request-priya',
            tripId: 'bali',
            applicantId: 'priya',
            message: 'I would love to join.'),
        JoinRequest(
            id: 'request-lucas',
            tripId: 'bali',
            applicantId: 'lucas',
            message: 'The itinerary sounds great.',
            decision: ApplicantDecision.accepted),
        JoinRequest(
            id: 'request-yuki',
            tripId: 'bali',
            applicantId: 'yuki',
            message: 'I can help with planning.',
            decision: ApplicantDecision.held),
      ];
}

const _tokyo =
    'https://images.unsplash.com/photo-1518005020951-eccb494ad742?auto=format&fit=crop&w=1200&q=85';
const _kyoto =
    'https://images.unsplash.com/photo-1493976040374-85c8e12f0c0e?auto=format&fit=crop&w=900&q=85';
const _bali =
    'https://images.unsplash.com/photo-1537996194471-e657df975ab4?auto=format&fit=crop&w=900&q=85';
const _paris =
    'https://images.unsplash.com/photo-1502602898657-3e91760cbb34?auto=format&fit=crop&w=900&q=85';
