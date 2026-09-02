import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../collaboration/model/collaboration_models.dart';
import '../model/shared_live_location.dart';
import '../repository/live_location_repository.dart';

class TripLiveLocationsScreen extends ConsumerStatefulWidget {
  const TripLiveLocationsScreen({
    required this.tripId,
    required this.members,
    required this.currentUserId,
    super.key,
  });

  final String tripId;
  final List<CollaborationMember> members;
  final String currentUserId;

  @override
  ConsumerState<TripLiveLocationsScreen> createState() =>
      _TripLiveLocationsScreenState();
}

class _TripLiveLocationsScreenState
    extends ConsumerState<TripLiveLocationsScreen> {
  Timer? _freshnessTimer;
  late final Stream<List<SharedLiveLocation>> _locations;

  @override
  void initState() {
    super.initState();
    _locations = ref
        .read(liveLocationRepositoryProvider)
        .watchTripShares(widget.tripId);
    _freshnessTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _freshnessTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Live locations')),
      body: StreamBuilder<List<SharedLiveLocation>>(
        stream: _locations,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Could not load live locations: ${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final now = DateTime.now();
          final active = snapshot.data!
              .where((share) => share.isActiveAt(now))
              .toList(growable: false);
          if (active.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.location_off_outlined, size: 52),
                    SizedBox(height: 12),
                    Text(
                      'No trip members are sharing their live location.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: active.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) => _LocationCard(
              share: active[index],
              member: _member(active[index].userId),
              isCurrentUser: active[index].userId == widget.currentUserId,
            ),
          );
        },
      ),
    );
  }

  CollaborationMember? _member(String userId) => widget.members
      .where((member) => member.userId == userId)
      .firstOrNull;
}

class _LocationCard extends StatelessWidget {
  const _LocationCard({
    required this.share,
    required this.member,
    required this.isCurrentUser,
  });

  final SharedLiveLocation share;
  final CollaborationMember? member;
  final bool isCurrentUser;

  @override
  Widget build(BuildContext context) {
    final name = isCurrentUser
        ? 'You'
        : member?.displayName?.trim().isNotEmpty == true
        ? member!.displayName!
        : 'Trip member';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  foregroundImage: member?.profilePhotoUrl == null
                      ? null
                      : NetworkImage(member!.profilePhotoUrl!),
                  child: member?.profilePhotoUrl == null
                      ? Text(name.characters.first.toUpperCase())
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        'Updated ${_relativeTime(share.recordedAt)} · '
                        'accurate to about ${share.accuracy.round()} m',
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.location_on, color: Colors.green),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => _openMaps(context),
                icon: const Icon(Icons.map_outlined),
                label: const Text('Open in Maps'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openMaps(BuildContext context) async {
    final uri = Uri.https('www.google.com', '/maps/search/', {
      'api': '1',
      'query': '${share.latitude},${share.longitude}',
    });
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) &&
        context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the maps app.')),
      );
    }
  }

  static String _relativeTime(DateTime value) {
    final difference = DateTime.now().difference(value);
    if (difference.inSeconds < 45) return 'just now';
    if (difference.inMinutes < 60) return '${difference.inMinutes} min ago';
    if (difference.inHours < 24) return '${difference.inHours} hr ago';
    return '${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago';
  }
}
