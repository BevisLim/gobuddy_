import 'package:flutter_riverpod/flutter_riverpod.dart';

final matchmakingRepositoryProvider = Provider<MatchmakingRepository>(
  (ref) => const MatchmakingRepository(),
);

class MatchmakingRepository {
  const MatchmakingRepository();

  List<String> get discoveryFilters => const [
        'All',
        'Adventure',
        'Culture',
        'Luxury',
        'Nature',
        'Foodie',
      ];
}
