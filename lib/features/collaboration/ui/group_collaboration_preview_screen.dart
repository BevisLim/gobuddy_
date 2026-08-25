import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

import 'package:flutter_mvvm_riverpod/features/collaboration/ui/state/collaboration_preview_state.dart';
import 'package:flutter_mvvm_riverpod/features/collaboration/ui/view_model/collaboration_preview_view_model.dart';
import 'package:flutter_mvvm_riverpod/features/collaboration/ui/widgets/friend_management_sheet.dart';
import 'package:flutter_mvvm_riverpod/features/collaboration/repository/jitsi_call_repository.dart';

const _categories = [
  'Dining',
  'Sightseeing',
  'Transport',
  'Accommodation',
  'Flight',
];
const _statuses = ['Proposed', 'Confirmed', 'Cancelled'];
const _fileCategories = [
  'Boarding Pass',
  'Hotel Voucher',
  'Receipt',
  'ID/Passport',
  'Map',
];

class _PreviewTripDetails {
  const _PreviewTripDetails({
    required this.id,
    required this.destination,
    required this.title,
    required this.dates,
    required this.travellers,
  });

  final String id;
  final String destination;
  final String title;
  final String dates;
  final String travellers;

  factory _PreviewTripDetails.fromTripId(String tripId) {
    switch (tripId.toLowerCase()) {
      case 'bali':
        return const _PreviewTripDetails(
          id: 'bali',
          destination: 'Bali, Indonesia',
          title: 'Bali Adventure',
          dates: 'Sep 5–15, 2026 • 10 days',
          travellers: '3 travellers • Planning together',
        );
      case 'paris':
        return const _PreviewTripDetails(
          id: 'paris',
          destination: 'Paris, France',
          title: 'Paris Getaway',
          dates: 'Oct 2–6, 2026 • 5 days',
          travellers: '2 travellers • Planning together',
        );
      case 'kyoto':
        return const _PreviewTripDetails(
          id: 'kyoto',
          destination: 'Kyoto, Japan',
          title: 'Kyoto Culture Trip',
          dates: 'Nov 12–16, 2026 • 5 days',
          travellers: '4 travellers • Planning together',
        );
      default:
        return const _PreviewTripDetails(
          id: 'tokyo',
          destination: 'Tokyo, Japan',
          title: 'Tokyo Adventure',
          dates: 'Aug 10–12, 2026 • 3 days',
          travellers: '3 travellers • Planning together',
        );
    }
  }

  String dayTitle(int day) {
    final themes = id == 'bali'
        ? const ['Arrival in Bali', 'Ubud & Waterfalls', 'Seminyak Beach Day']
        : id == 'paris'
        ? const ['Arrival & Check-in', 'Paris Landmarks', 'Cafés & Departure']
        : id == 'kyoto'
        ? const ['Arrival in Kyoto', 'Temples & Gion', 'Arashiyama Day']
        : const ['Arrival & Check-in', 'Tokyo Sightseeing', 'Departure Day'];
    return 'Day $day — ${themes[day - 1]}';
  }

  String dayDate(int day) {
    final dates = id == 'bali'
        ? const ['Sep 5', 'Sep 6', 'Sep 7']
        : id == 'paris'
        ? const ['Oct 2', 'Oct 3', 'Oct 4']
        : id == 'kyoto'
        ? const ['Nov 12', 'Nov 13', 'Nov 14']
        : const ['Aug 10', 'Aug 11', 'Aug 12'];
    return dates[day - 1];
  }

  String get shareLink => 'gobuddy://trip/$id';
}

class GroupCollaborationPreviewScreen extends ConsumerWidget {
  const GroupCollaborationPreviewScreen({this.tripId = '', super.key});

  final String tripId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trip = _PreviewTripDetails.fromTripId(tripId);
    ref.listen<CollaborationPreviewState>(
      collaborationPreviewViewModelProvider,
      (previous, next) {
        if (next.message != null && next.message != previous?.message)
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(next.message!)));
      },
    );
    final state = ref.watch(collaborationPreviewViewModelProvider);
    final viewModel = ref.read(collaborationPreviewViewModelProvider.notifier);
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${trip.destination} Travel Group'),
              const Text(
                'Group Communication & Collaboration',
                style: TextStyle(fontSize: 12),
              ),
            ],
          ),
          actions: [
            IconButton(
              onPressed: () => _showCallSheet(
                context,
                viewModel,
                PreviewCallType.voice,
                trip.id,
              ),
              icon: const Icon(Icons.call),
              tooltip: 'Start voice call',
            ),
            IconButton(
              onPressed: () => _showCallSheet(
                context,
                viewModel,
                PreviewCallType.video,
                trip.id,
              ),
              icon: const Icon(Icons.videocam),
              tooltip: 'Start video call',
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.chat_bubble_outline), text: 'Chat'),
              Tab(icon: Icon(Icons.event_note), text: 'Timeline'),
              Tab(icon: Icon(Icons.folder_outlined), text: 'Files'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _ChatTab(state: state, viewModel: viewModel),
            _TimelineTab(state: state, viewModel: viewModel, trip: trip),
            _FilesTab(state: state, viewModel: viewModel),
          ],
        ),
      ),
    );
  }
}

class _ChatTab extends ConsumerStatefulWidget {
  const _ChatTab({required this.state, required this.viewModel});
  final CollaborationPreviewState state;
  final CollaborationPreviewViewModel viewModel;
  @override
  ConsumerState<_ChatTab> createState() => _ChatTabState();
}

class _ChatTabState extends ConsumerState<_ChatTab> {
  final _messageController = TextEditingController();
  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      Row(
        children: [
          const Expanded(
            child: Text(
              'Member Management',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          TextButton.icon(
            onPressed: () => showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              builder: (_) => const FriendManagementSheet(),
            ),
            icon: const Icon(Icons.person_add_outlined),
            label: const Text('Add friend'),
          ),
        ],
      ),
      if (widget.state.members.isEmpty)
        const Card(
          child: ListTile(
            leading: Icon(Icons.person_remove_outlined),
            title: Text('Aina Rahman was removed'),
            subtitle: Text('This member no longer has access to the group.'),
          ),
        )
      else
        Card(
          child: ListTile(
            leading: const CircleAvatar(child: Text('A')),
            title: const Text('Aina Rahman'),
            subtitle: Text(
              widget.state.memberMuted ? 'Trip member • Muted' : 'Trip member',
            ),
            trailing: PopupMenuButton<String>(
              tooltip: 'Member options',
              icon: const Icon(Icons.more_vert),
              onSelected: (choice) {
                if (choice == 'mute')
                  _showMuteDialog(
                    context,
                    widget.viewModel,
                    widget.state.members.first,
                  );
                if (choice == 'unmute')
                  widget.viewModel.unmuteMember(widget.state.members.first.id);
                if (choice == 'remove')
                  _showRemoveDialog(
                    context,
                    widget.viewModel,
                    widget.state.members.first,
                  );
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: widget.state.members.first.isMuted ? 'unmute' : 'mute',
                  child: Text(
                    widget.state.members.first.isMuted
                        ? 'Unmute member'
                        : 'Mute member',
                  ),
                ),
                const PopupMenuItem(
                  value: 'remove',
                  child: Text('Remove member'),
                ),
              ],
            ),
          ),
        ),
      ...widget.state.members
          .skip(1)
          .map(
            (member) => Card(
              child: ListTile(
                leading: CircleAvatar(
                  child: Text(member.name.substring(0, 1).toUpperCase()),
                ),
                title: Text(member.name),
                subtitle: Text(
                  member.isMuted ? '${member.email} • Muted' : member.email,
                ),
                trailing: PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert),
                  onSelected: (choice) {
                    if (choice == 'mute')
                      _showMuteDialog(context, widget.viewModel, member);
                    if (choice == 'unmute')
                      widget.viewModel.unmuteMember(member.id);
                    if (choice == 'remove')
                      _showRemoveDialog(context, widget.viewModel, member);
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: member.isMuted ? 'unmute' : 'mute',
                      child: Text(
                        member.isMuted ? 'Unmute member' : 'Mute member',
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'remove',
                      child: Text('Remove member'),
                    ),
                  ],
                ),
              ),
            ),
          ),
      const SizedBox(height: 14),
      const Text(
        'Group Chat',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 8),
      ...widget.state.chatMessages.map(
        (message) => Card(
          child: ListTile(
            title: Text(message.sender),
            subtitle: Text(message.body),
          ),
        ),
      ),
      TextField(
        controller: _messageController,
        decoration: InputDecoration(
          hintText: 'Message group',
          suffixIcon: IconButton(
            icon: const Icon(Icons.send),
            onPressed: () {
              widget.viewModel.sendMessage(_messageController.text);
              _messageController.clear();
            },
          ),
          border: const OutlineInputBorder(),
        ),
      ),
    ],
  );
}

class _TimelineTab extends StatelessWidget {
  const _TimelineTab({
    required this.state,
    required this.viewModel,
    required this.trip,
  });
  final CollaborationPreviewState state;
  final CollaborationPreviewViewModel viewModel;
  final _PreviewTripDetails trip;
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      _TripSummaryCard(trip: trip),
      const SizedBox(height: 16),
      Row(
        children: [
          const Expanded(
            child: Text(
              'Itinerary',
              style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
            ),
          ),
          TextButton.icon(
            onPressed: () =>
                _showActivityForm(context, viewModel, proposal: true),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add activity'),
          ),
        ],
      ),
      const SizedBox(height: 6),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (var day = 1; day <= 3; day++)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Day $day',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        trip.dayDate(day),
                        style: const TextStyle(fontSize: 11),
                      ),
                    ],
                  ),
                  selected: state.selectedDay == day,
                  selectedColor: const Color(0xFF149B8A),
                  labelStyle: TextStyle(
                    color: state.selectedDay == day
                        ? Colors.white
                        : const Color(0xFF293840),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  onSelected: (_) => viewModel.selectDay(day),
                ),
              ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFF3F7F6),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                trip.dayTitle(state.selectedDay),
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            TextButton.icon(
              onPressed: () =>
                  _showActivityForm(context, viewModel, proposal: true),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add activity'),
            ),
          ],
        ),
      ),
      const SizedBox(height: 8),
      ..._activitiesForTrip(trip, state).asMap().entries.map((entry) {
        final key = _activityKey(
          trip.id,
          state.selectedDay,
          entry.key,
          entry.value.title,
        );
        final activity = state.activityOverrides[key] ?? entry.value;
        return _activityCard(
          context,
          activity,
          state.pinnedActivityKeys.contains(key),
          viewModel,
          activityKey: key,
        );
      }),
      if (state.selectedDay == 1)
        ...state.proposals.asMap().entries.map((entry) {
          final key = _activityKey(
            trip.id,
            1,
            entry.key + 100,
            entry.value.title,
          );
          final activity = state.activityOverrides[key] ?? entry.value;
          return _activityCard(
            context,
            activity,
            state.pinnedActivityKeys.contains(key),
            viewModel,
            activityKey: key,
          );
        }),
      const SizedBox(height: 16),
      Row(
        children: [
          const Expanded(
            child: Text(
              'Activity Poll',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          TextButton.icon(
            onPressed: () => _showPollForm(context, viewModel),
            icon: const Icon(Icons.add_chart),
            label: const Text('Create poll'),
          ),
        ],
      ),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                state.poll.question,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              ...state.poll.options.map(
                (option) => state.poll.allowMultipleChoice
                    ? CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        value: state.poll.selectedOptions.contains(option),
                        title: Text(option),
                        onChanged: (_) => viewModel.selectVote(option),
                      )
                    : RadioListTile<String>(
                        contentPadding: EdgeInsets.zero,
                        value: option,
                        groupValue: state.poll.selectedOptions.isEmpty
                            ? null
                            : state.poll.selectedOptions.first,
                        title: Text(option),
                        onChanged: (_) => viewModel.selectVote(option),
                      ),
              ),
            ],
          ),
        ),
      ),
    ],
  );

  Widget _activityCard(
    BuildContext context,
    PreviewActivity activity,
    bool pinned,
    CollaborationPreviewViewModel viewModel, {
    required String activityKey,
  }) => Card(
    child: ListTile(
      leading: Icon(pinned ? Icons.push_pin : Icons.event_outlined),
      title: Text(activity.title),
      subtitle: Text(
        '${activity.category} • ${activity.location}\n${activity.date?.day ?? 14}/${activity.date?.month ?? 5} • ${activity.time} • RM ${activity.budget.toStringAsFixed(2)}\n${activity.status}${activity.isLocked ? ' • Locked' : ''}',
      ),
      isThreeLine: true,
      trailing: Wrap(
        spacing: 0,
        children: [
          IconButton(
            onPressed: () => _confirmPin(context, viewModel, activityKey),
            icon: Icon(pinned ? Icons.push_pin : Icons.push_pin_outlined),
            tooltip: 'Pin activity',
          ),
          IconButton(
            onPressed: activity.isLocked
                ? null
                : () => _showActivityForm(
                    context,
                    viewModel,
                    existing: activity,
                    activityKey: activityKey,
                  ),
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit activity',
          ),
          IconButton(
            onPressed: () => viewModel.setActivityLock(
              activityKey,
              activity,
              !activity.isLocked,
            ),
            icon: Icon(
              activity.isLocked ? Icons.lock : Icons.lock_open_outlined,
            ),
            tooltip: 'Lock activity (admin)',
          ),
        ],
      ),
    ),
  );

  String _dayTitle(int day) => switch (day) {
    1 => 'Day 1 — Arrival & Check-in',
    2 => 'Day 2 — Tokyo Sightseeing',
    _ => 'Day 3 — Departure Day',
  };
  List<PreviewActivity> _dayActivities(CollaborationPreviewState state) =>
      switch (state.selectedDay) {
        1 => [state.activity],
        2 => const [
          PreviewActivity(
            title: 'Senso-ji Temple',
            category: 'Sightseeing',
            location: 'Asakusa',
            time: '9:30 AM',
            budget: 0,
            notes: 'Meet at hotel lobby.',
            status: 'Confirmed',
          ),
          PreviewActivity(
            title: 'Ramen lunch',
            category: 'Dining',
            location: 'Shibuya',
            time: '1:00 PM',
            budget: 45,
            notes: 'Group reservation for four.',
            status: 'Proposed',
          ),
          PreviewActivity(
            title: 'Shibuya Crossing walk',
            category: 'Sightseeing',
            location: 'Shibuya',
            time: '4:00 PM',
            budget: 0,
            notes: 'Bring a camera.',
            status: 'Confirmed',
          ),
        ],
        _ => const [
          PreviewActivity(
            title: 'Hotel check-out',
            category: 'Accommodation',
            location: 'Shinjuku',
            time: '10:00 AM',
            budget: 0,
            notes: 'Leave luggage at reception.',
            status: 'Confirmed',
          ),
          PreviewActivity(
            title: 'Narita Express',
            category: 'Transport',
            location: 'Tokyo Station',
            time: '12:30 PM',
            budget: 95,
            notes: 'Arrive 30 minutes early.',
            status: 'Confirmed',
          ),
          PreviewActivity(
            title: 'Flight home',
            category: 'Flight',
            location: 'Narita Airport',
            time: '4:45 PM',
            budget: 0,
            notes: 'Check passport and boarding pass.',
            status: 'Confirmed',
          ),
        ],
      };
}

List<PreviewActivity> _activitiesForTrip(
  _PreviewTripDetails trip,
  CollaborationPreviewState state,
) {
  if (trip.id == 'bali') {
    return switch (state.selectedDay) {
      1 => const [
        PreviewActivity(
          title: 'Arrive at Ngurah Rai Airport',
          category: 'Flight',
          location: 'Denpasar',
          time: '9:00 AM',
          budget: 0,
          notes: 'Meet at the arrival gate.',
          status: 'Confirmed',
        ),
        PreviewActivity(
          title: 'Check-in: The Layr Villa',
          category: 'Accommodation',
          location: 'Canggu',
          time: '12:00 PM',
          budget: 220,
          notes: 'Keep passports ready for check-in.',
          status: 'Confirmed',
        ),
        PreviewActivity(
          title: 'Seminyak Beach walk + lunch',
          category: 'Dining',
          location: 'Seminyak',
          time: '2:00 PM',
          budget: 55,
          notes: 'Beachfront lunch and sunset walk.',
          status: 'Proposed',
        ),
      ],
      2 => const [
        PreviewActivity(
          title: 'Tegalalang Rice Terrace',
          category: 'Sightseeing',
          location: 'Ubud',
          time: '9:00 AM',
          budget: 25,
          notes: 'Bring water and comfortable shoes.',
          status: 'Confirmed',
        ),
        PreviewActivity(
          title: 'Tegenungan Waterfall',
          category: 'Sightseeing',
          location: 'Gianyar',
          time: '1:30 PM',
          budget: 20,
          notes: 'Swimming is optional.',
          status: 'Confirmed',
        ),
        PreviewActivity(
          title: 'Ubud market dinner',
          category: 'Dining',
          location: 'Ubud',
          time: '6:30 PM',
          budget: 60,
          notes: 'Vote for restaurant in the poll.',
          status: 'Proposed',
        ),
      ],
      _ => const [
        PreviewActivity(
          title: 'Surf lesson',
          category: 'Sightseeing',
          location: 'Seminyak Beach',
          time: '9:00 AM',
          budget: 90,
          notes: 'Beginner lesson, equipment included.',
          status: 'Confirmed',
        ),
        PreviewActivity(
          title: 'Tanah Lot sunset',
          category: 'Sightseeing',
          location: 'Beraban',
          time: '4:30 PM',
          budget: 15,
          notes: 'Leave before traffic gets busy.',
          status: 'Confirmed',
        ),
        PreviewActivity(
          title: 'Farewell dinner',
          category: 'Dining',
          location: 'Canggu',
          time: '7:30 PM',
          budget: 80,
          notes: 'Final group dinner.',
          status: 'Proposed',
        ),
      ],
    };
  }
  return switch (state.selectedDay) {
    1 => [state.activity],
    2 => const [
      PreviewActivity(
        title: 'Senso-ji Temple',
        category: 'Sightseeing',
        location: 'Asakusa',
        time: '9:30 AM',
        budget: 0,
        notes: 'Meet at hotel lobby.',
        status: 'Confirmed',
      ),
      PreviewActivity(
        title: 'Ramen lunch',
        category: 'Dining',
        location: 'Shibuya',
        time: '1:00 PM',
        budget: 45,
        notes: 'Group reservation for four.',
        status: 'Proposed',
      ),
    ],
    _ => const [
      PreviewActivity(
        title: 'Hotel check-out',
        category: 'Accommodation',
        location: 'Shinjuku',
        time: '10:00 AM',
        budget: 0,
        notes: 'Leave luggage at reception.',
        status: 'Confirmed',
      ),
      PreviewActivity(
        title: 'Flight home',
        category: 'Flight',
        location: 'Narita Airport',
        time: '4:45 PM',
        budget: 0,
        notes: 'Check passport and boarding pass.',
        status: 'Confirmed',
      ),
    ],
  };
}

class _TripSummaryCard extends StatelessWidget {
  const _TripSummaryCard({required this.trip});

  final _PreviewTripDetails trip;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0xFF149B8A),
      borderRadius: BorderRadius.circular(18),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.flight_takeoff, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                trip.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            FilledButton.tonal(
              onPressed: () => _showShareTripDialog(context, trip),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white24,
                foregroundColor: Colors.white,
              ),
              child: const Text('Share'),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(trip.dates, style: const TextStyle(color: Colors.white70)),
        const SizedBox(height: 12),
        Row(
          children: [
            const CircleAvatar(radius: 13, child: Text('T')),
            const SizedBox(width: 4),
            const CircleAvatar(radius: 13, child: Text('A')),
            const SizedBox(width: 8),
            Text(
              trip.travellers,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
      ],
    ),
  );
}

Future<void> _showShareTripDialog(
  BuildContext context,
  _PreviewTripDetails trip,
) => showDialog<void>(
  context: context,
  builder: (dialogContext) => AlertDialog(
    title: const Row(
      children: [
        Icon(Icons.ios_share_outlined),
        SizedBox(width: 10),
        Text('Share trip'),
      ],
    ),
    content: SizedBox(
      width: 420,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            trip.title,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
          ),
          const SizedBox(height: 4),
          Text('${trip.dates} • ${trip.destination}'),
          const SizedBox(height: 16),
          const Text(
            'Invite link',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black12,
              borderRadius: BorderRadius.circular(10),
            ),
            child: SelectableText(trip.shareLink),
          ),
          const SizedBox(height: 12),
          const Text(
            'Anyone you invite can view the itinerary and join the group conversation.',
            style: TextStyle(fontSize: 13),
          ),
        ],
      ),
    ),
    actions: [
      TextButton.icon(
        onPressed: () async {
          await Clipboard.setData(ClipboardData(text: trip.shareLink));
          if (dialogContext.mounted)
            ScaffoldMessenger.of(dialogContext).showSnackBar(
              const SnackBar(content: Text('Trip invitation link copied.')),
            );
        },
        icon: const Icon(Icons.copy_outlined),
        label: const Text('Copy link'),
      ),
      FilledButton.icon(
        onPressed: () {
          Navigator.pop(dialogContext);
          showModalBottomSheet<void>(
            context: context,
            isScrollControlled: true,
            builder: (_) => const FriendManagementSheet(),
          );
        },
        icon: const Icon(Icons.person_add_outlined),
        label: const Text('Invite friends'),
      ),
    ],
  ),
);

class _FilesTab extends StatelessWidget {
  const _FilesTab({required this.state, required this.viewModel});
  final CollaborationPreviewState state;
  final CollaborationPreviewViewModel viewModel;
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      FilledButton.icon(
        onPressed: () => _chooseFile(context, viewModel),
        icon: const Icon(Icons.upload_file),
        label: const Text('Choose file'),
      ),
      const SizedBox(height: 12),
      const Card(
        child: ListTile(
          leading: Icon(Icons.picture_as_pdf_outlined),
          title: Text('Hotel booking.pdf'),
          subtitle: Text('Hotel Voucher • Shared by Sophia'),
        ),
      ),
      const Card(
        child: ListTile(
          leading: Icon(Icons.image_outlined),
          title: Text('Tokyo food map.jpg'),
          subtitle: Text('Map • Shared by Aina'),
        ),
      ),
      ...state.sharedFiles.map(
        (file) => Card(
          child: ListTile(
            leading: const Icon(Icons.insert_drive_file_outlined),
            title: Text(file.title),
            subtitle: Text(
              '${file.category} • ${file.name}\n${(file.sizeBytes / 1024).toStringAsFixed(1)} KB • Shared by you',
            ),
            isThreeLine: true,
          ),
        ),
      ),
    ],
  );
}

String _activityKey(String tripId, int day, int index, String title) =>
    '$tripId-$day-$index-$title';

Future<void> _showActivityForm(
  BuildContext context,
  CollaborationPreviewViewModel viewModel, {
  bool proposal = false,
  PreviewActivity? existing,
  String? activityKey,
}) async {
  final current =
      existing ??
      const PreviewActivity(
        title: '',
        location: '',
        notes: '',
        status: 'Proposed',
      );
  final title = TextEditingController(text: current.title);
  final location = TextEditingController(text: current.location);
  final budget = TextEditingController(
    text: current.budget == 80 && proposal ? '' : current.budget.toString(),
  );
  final notes = TextEditingController(text: current.notes);
  var category = current.category;
  var status = current.status;
  var date = current.date ?? DateTime.now().add(const Duration(days: 1));
  var time = TimeOfDay.now();
  var locked = current.isLocked;
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: Text(proposal ? 'Propose Activity' : 'Edit Activity'),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: title,
                  decoration: const InputDecoration(
                    labelText: 'Activity Title',
                  ),
                ),
                DropdownButtonFormField<String>(
                  value: category,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: _categories
                      .map(
                        (item) =>
                            DropdownMenuItem(value: item, child: Text(item)),
                      )
                      .toList(),
                  onChanged: (value) => setState(() => category = value!),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    'Proposed date: ${date.day}/${date.month}/${date.year}',
                  ),
                  trailing: const Icon(Icons.calendar_today_outlined),
                  onTap: () async {
                    final selected = await showDatePicker(
                      context: context,
                      initialDate: date,
                      firstDate: DateTime.now().subtract(
                        const Duration(days: 1),
                      ),
                      lastDate: DateTime(2030),
                    );
                    if (selected != null) setState(() => date = selected);
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Proposed start time: ${time.format(context)}'),
                  trailing: const Icon(Icons.access_time),
                  onTap: () async {
                    final selected = await showTimePicker(
                      context: context,
                      initialTime: time,
                    );
                    if (selected != null) setState(() => time = selected);
                  },
                ),
                TextField(
                  controller: location,
                  decoration: const InputDecoration(
                    labelText: 'Location / Address',
                  ),
                ),
                TextField(
                  controller: budget,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Estimated Budget per Person (RM)',
                  ),
                ),
                TextField(
                  controller: notes,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Description / Notes',
                  ),
                ),
                if (!proposal) ...[
                  DropdownButtonFormField<String>(
                    value: status,
                    decoration: const InputDecoration(
                      labelText: 'Activity Status',
                    ),
                    items: _statuses
                        .map(
                          (item) =>
                              DropdownMenuItem(value: item, child: Text(item)),
                        )
                        .toList(),
                    onChanged: (value) => setState(() => status = value!),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: locked,
                    title: const Text('Lock Activity (Admin only)'),
                    onChanged: (value) => setState(() => locked = value),
                  ),
                  TextField(
                    decoration: const InputDecoration(
                      labelText: 'Change Note / Reason for Edit',
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (title.text.trim().isEmpty || location.text.trim().isEmpty)
                return;
              final activity = PreviewActivity(
                title: title.text.trim(),
                category: category,
                date: date,
                time: time.format(context),
                location: location.text.trim(),
                budget: double.tryParse(budget.text) ?? 0,
                notes: notes.text.trim(),
                status: status,
                isLocked: locked,
              );
              if (proposal) {
                viewModel.addProposal(activity);
              } else if (activityKey != null) {
                viewModel.saveActivityForKey(activityKey, activity);
              } else {
                viewModel.saveActivity(activity);
              }
              Navigator.pop(dialogContext);
            },
            child: Text(proposal ? 'Submit Proposal' : 'Save Changes'),
          ),
        ],
      ),
    ),
  );
  title.dispose();
  location.dispose();
  budget.dispose();
  notes.dispose();
}

Future<void> _showPollForm(
  BuildContext context,
  CollaborationPreviewViewModel viewModel,
) async {
  final question = TextEditingController();
  final options = [TextEditingController(), TextEditingController()];
  var multiple = false;
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: const Text('Create Poll'),
        content: SizedBox(
          width: 400,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: question,
                  decoration: const InputDecoration(
                    labelText: 'Poll Question / Prompt',
                  ),
                ),
                ...options.asMap().entries.map(
                  (entry) => TextField(
                    controller: entry.value,
                    decoration: InputDecoration(
                      labelText: 'Poll Option ${entry.key + 1}',
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: () =>
                      setState(() => options.add(TextEditingController())),
                  icon: const Icon(Icons.add),
                  label: const Text('Add Option'),
                ),
                SwitchListTile(
                  value: multiple,
                  title: const Text('Allow Multiple Choice'),
                  onChanged: (value) => setState(() => multiple = value),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final values = options
                  .map((item) => item.text.trim())
                  .where((item) => item.isNotEmpty)
                  .toList();
              if (question.text.trim().isEmpty || values.length < 2) return;
              viewModel.createPoll(
                question: question.text.trim(),
                options: values,
                multiple: multiple,
              );
              Navigator.pop(dialogContext);
            },
            child: const Text('Create Poll'),
          ),
        ],
      ),
    ),
  );
  question.dispose();
  for (final option in options) {
    option.dispose();
  }
}

Future<void> _chooseFile(
  BuildContext context,
  CollaborationPreviewViewModel viewModel,
) async {
  final result = await FilePicker.platform.pickFiles(
    withData: true,
    type: FileType.custom,
    allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'doc', 'docx'],
  );
  if (result == null || result.files.isEmpty) return;
  final file = result.files.first;
  final label = TextEditingController(text: file.name);
  var category = _fileCategories.first;
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: const Text('Share File'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(file.name),
            TextField(
              controller: label,
              decoration: const InputDecoration(
                labelText: 'Document Title / Label',
              ),
            ),
            DropdownButtonFormField<String>(
              value: category,
              decoration: const InputDecoration(labelText: 'File Category'),
              items: _fileCategories
                  .map(
                    (item) => DropdownMenuItem(value: item, child: Text(item)),
                  )
                  .toList(),
              onChanged: (value) => setState(() => category = value!),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              viewModel.addSharedFile(
                PreviewSharedFile(
                  name: file.name,
                  title: label.text.trim().isEmpty
                      ? file.name
                      : label.text.trim(),
                  category: category,
                  sizeBytes: file.size,
                ),
              );
              Navigator.pop(dialogContext);
            },
            child: const Text('Upload & Send'),
          ),
        ],
      ),
    ),
  );
  label.dispose();
}

Future<void> _confirmPin(
  BuildContext context,
  CollaborationPreviewViewModel viewModel,
  String activityKey,
) => showDialog<void>(
  context: context,
  builder: (dialogContext) => AlertDialog(
    title: const Text('Pin activity'),
    content: const Text('Pin to top of itinerary?'),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(dialogContext),
        child: const Text('No'),
      ),
      FilledButton(
        onPressed: () {
          viewModel.toggleActivityPin(activityKey);
          Navigator.pop(dialogContext);
        },
        child: const Text('Yes'),
      ),
    ],
  ),
);
Future<void> _showMuteDialog(
  BuildContext context,
  CollaborationPreviewViewModel viewModel,
  PreviewMember member,
) async {
  var duration = '1 Hour';
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: Text('Mute ${member.name}'),
        content: DropdownButtonFormField<String>(
          value: duration,
          decoration: const InputDecoration(labelText: 'Mute duration'),
          items: const ['1 Hour', '24 Hours', 'Until Unmuted']
              .map((item) => DropdownMenuItem(value: item, child: Text(item)))
              .toList(),
          onChanged: (value) => setState(() => duration = value!),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              viewModel.muteMember(member.id, duration);
              Navigator.pop(dialogContext);
            },
            child: const Text('Mute Member'),
          ),
        ],
      ),
    ),
  );
}

Future<void> _showRemoveDialog(
  BuildContext context,
  CollaborationPreviewViewModel viewModel,
  PreviewMember member,
) => showDialog<void>(
  context: context,
  builder: (dialogContext) => AlertDialog(
    title: const Text('Remove member'),
    content: Text(
      'Are you sure you want to remove ${member.name} from the group?',
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(dialogContext),
        child: const Text('Cancel'),
      ),
      FilledButton(
        style: FilledButton.styleFrom(backgroundColor: Colors.red),
        onPressed: () {
          viewModel.removeMember(member.id);
          Navigator.pop(dialogContext);
        },
        child: const Text('Remove Member'),
      ),
    ],
  ),
);
Future<void> _showAddFriendDialog(
  BuildContext context,
  CollaborationPreviewViewModel viewModel,
) async {
  final name = TextEditingController();
  final email = TextEditingController();
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Add Friend'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: name,
            decoration: const InputDecoration(labelText: 'Friend name'),
          ),
          TextField(
            controller: email,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'Email address'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (name.text.trim().isEmpty || email.text.trim().isEmpty) return;
            viewModel.addFriend(
              name: name.text.trim(),
              email: email.text.trim(),
            );
            Navigator.pop(dialogContext);
          },
          child: const Text('Add Friend'),
        ),
      ],
    ),
  );
  name.dispose();
  email.dispose();
}

Future<void> _showCallSheet(
  BuildContext context,
  CollaborationPreviewViewModel viewModel,
  PreviewCallType type,
  String tripId,
) async {
  viewModel.startCall(type);
  try {
    await const JitsiCallRepository().joinTripCall(
      tripId: tripId,
      callType: type == PreviewCallType.video ? 'video' : 'voice',
    );
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$error')));
    }
  }
  if (!context.mounted) return;
  showModalBottomSheet<void>(
    context: context,
    builder: (_) => _CallControls(type: type, viewModel: viewModel),
  );
}

class _CallControls extends ConsumerWidget {
  const _CallControls({required this.type, required this.viewModel});
  final PreviewCallType type;
  final CollaborationPreviewViewModel viewModel;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(collaborationPreviewViewModelProvider);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              type == PreviewCallType.video ? Icons.videocam : Icons.call,
              size: 52,
            ),
            const SizedBox(height: 8),
            Text(
              type == PreviewCallType.video ? 'Video Call' : 'Voice Call',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const Text('Tokyo Travel Group'),
            const SizedBox(height: 20),
            Wrap(
              spacing: 16,
              children: [
                IconButton.filledTonal(
                  onPressed: viewModel.toggleMicrophone,
                  icon: Icon(state.microphoneMuted ? Icons.mic_off : Icons.mic),
                  tooltip: 'Mute / unmute microphone',
                ),
                if (type == PreviewCallType.video) ...[
                  IconButton.filledTonal(
                    onPressed: viewModel.toggleCamera,
                    icon: Icon(
                      state.cameraOn ? Icons.videocam : Icons.videocam_off,
                    ),
                    tooltip: 'Turn camera on / off',
                  ),
                  IconButton.filledTonal(
                    onPressed: viewModel.switchCamera,
                    icon: const Icon(Icons.cameraswitch),
                    tooltip: 'Switch front / rear camera',
                  ),
                ],
                IconButton.filled(
                  onPressed: () {
                    viewModel.endCall();
                    Navigator.pop(context);
                  },
                  icon: const Icon(Icons.call_end),
                  color: Colors.white,
                  style: IconButton.styleFrom(backgroundColor: Colors.red),
                  tooltip: 'End call',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
