import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:flutter_mvvm_riverpod/core/routing/routes.dart';
import 'package:flutter_mvvm_riverpod/core/theme/app_colors.dart';
import 'package:flutter_mvvm_riverpod/core/theme/app_theme.dart';
import 'package:flutter_mvvm_riverpod/features/common/ui/widgets/app_module_navigation.dart';
import 'package:flutter_mvvm_riverpod/features/matchmaking/model/matchmaking_models.dart';
import 'package:flutter_mvvm_riverpod/features/matchmaking/ui/state/matchmaking_state.dart';
import 'package:flutter_mvvm_riverpod/features/matchmaking/ui/view_model/matchmaking_view_model.dart';

class MessagesScreen extends ConsumerWidget {
  const MessagesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(matchmakingViewModelProvider);
    final trips = _groupTrips(state);
    return Scaffold(
      appBar: AppBar(title: Text('Messages', style: AppTheme.title20)),
      body: trips.isEmpty
          ? const _EmptyMessages()
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: trips.length + 1,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return const Padding(
                    padding: EdgeInsets.only(bottom: 4),
                    child: Text('Your trip groups',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700)),
                  );
                }
                final trip = trips[index - 1];
                return _TripConversationCard(trip: trip);
              },
            ),
      bottomNavigationBar: const AppModuleNavigation(selectedIndex: 2),
    );
  }

  List<MatchmakingTrip> _groupTrips(MatchmakingState state) {
    final acceptedIds = state.requests
        .where((request) =>
            request.applicantId == 'current-user' &&
            request.decision == ApplicantDecision.accepted)
        .map((request) => request.tripId)
        .toSet();
    return state.trips
        .where((trip) => trip.isOwned || acceptedIds.contains(trip.id))
        .toList(growable: false);
  }
}

class _TripConversationCard extends StatelessWidget {
  const _TripConversationCard({required this.trip});
  final MatchmakingTrip trip;

  @override
  Widget build(BuildContext context) => Card(
        elevation: 0,
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: AppColors.brandSurface,
            child: Text(trip.hostInitials.isEmpty
                ? trip.destination.substring(0, 1)
                : trip.hostInitials.substring(0, 1)),
          ),
          title: Text(trip.destination,
              style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text(
              '${_date(trip.startDate)} – ${_date(trip.endDate)} • ${trip.joined} travellers'),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () {
            final path = '${Routes.groupCollaboration}?tripId=${trip.id}';
            context.push(path);
          },
        ),
      );

  String _date(DateTime value) => '${value.day}/${value.month}/${value.year}';
}

class _EmptyMessages extends StatelessWidget {
  const _EmptyMessages();

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.chat_bubble_outline_rounded,
                size: 56, color: AppColors.brandSurface),
            const SizedBox(height: 16),
            Text('No trip chats yet', style: AppTheme.title20),
            const SizedBox(height: 8),
            Text('Trips you create or join will appear here.',
                textAlign: TextAlign.center,
                style:
                    AppTheme.body16.copyWith(color: AppColors.brandTextMuted)),
          ]),
        ),
      );
}
