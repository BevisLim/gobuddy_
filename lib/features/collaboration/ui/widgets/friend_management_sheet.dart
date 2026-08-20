import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutter_mvvm_riverpod/features/collaboration/ui/state/collaboration_preview_state.dart';
import 'package:flutter_mvvm_riverpod/features/collaboration/ui/view_model/collaboration_preview_view_model.dart';

class FriendManagementSheet extends ConsumerStatefulWidget {
  const FriendManagementSheet({super.key});

  @override
  ConsumerState<FriendManagementSheet> createState() => _FriendManagementSheetState();
}

class _FriendManagementSheetState extends ConsumerState<FriendManagementSheet> with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final _search = TextEditingController();

  @override
  void initState() { super.initState(); _tabs = TabController(length: 3, vsync: this); }
  @override
  void dispose() { _tabs.dispose(); _search.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(collaborationPreviewViewModelProvider);
    final viewModel = ref.read(collaborationPreviewViewModelProvider.notifier);
    return SafeArea(child: SizedBox(height: MediaQuery.sizeOf(context).height * .82, child: Column(children: [
      Padding(padding: const EdgeInsets.fromLTRB(20, 16, 12, 4), child: Row(children: [const Expanded(child: Text('Friends', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800))), IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close))])),
      TabBar(controller: _tabs, tabs: const [Tab(text: 'Find friends'), Tab(text: 'Requests'), Tab(text: 'Invite to group')]),
      Expanded(child: TabBarView(controller: _tabs, children: [_FindFriends(search: _search, state: state, viewModel: viewModel), _Requests(state: state, viewModel: viewModel), _InviteFriends(state: state, viewModel: viewModel)])),
    ])));
  }
}

class _FindFriends extends StatefulWidget {
  const _FindFriends({required this.search, required this.state, required this.viewModel});
  final TextEditingController search;
  final CollaborationPreviewState state;
  final CollaborationPreviewViewModel viewModel;
  @override
  State<_FindFriends> createState() => _FindFriendsState();
}

class _FindFriendsState extends State<_FindFriends> {
  @override
  void initState() { super.initState(); widget.search.addListener(_changed); }
  @override
  void dispose() { widget.search.removeListener(_changed); super.dispose(); }
  void _changed() => setState(() {});
  @override
  Widget build(BuildContext context) {
    final query = widget.search.text.toLowerCase();
    final results = widget.state.friendDirectory.where((friend) => query.isEmpty || friend.name.toLowerCase().contains(query) || friend.username.toLowerCase().contains(query) || friend.email.toLowerCase().contains(query)).toList();
    return ListView(padding: const EdgeInsets.all(16), children: [
      TextField(controller: widget.search, decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Username, email, or phone number', border: OutlineInputBorder())),
      const SizedBox(height: 10),
      Row(children: [Expanded(child: OutlinedButton.icon(onPressed: () => _showQr(context, title: 'Scan Friend QR Code'), icon: const Icon(Icons.qr_code_scanner), label: const Text('Scan QR'))), const SizedBox(width: 8), Expanded(child: OutlinedButton.icon(onPressed: () => _showQr(context, title: 'My QR Code'), icon: const Icon(Icons.qr_code_2), label: const Text('My QR Code')))]),
      const SizedBox(height: 8),
      OutlinedButton.icon(onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Phone contacts synced. Matching GoBuddy users are shown below.'))), icon: const Icon(Icons.contacts_outlined), label: const Text('Sync Phone Contacts')),
      const SizedBox(height: 16), const Text('People you may know', style: TextStyle(fontWeight: FontWeight.w800)), const SizedBox(height: 6),
      ...results.map((friend) { final sent = widget.state.sentRequestIds.contains(friend.id); return Card(child: ListTile(leading: CircleAvatar(child: Text(friend.name.substring(0, 1))), title: Text(friend.name), subtitle: Text('@${friend.username}\n${friend.email}'), isThreeLine: true, trailing: sent ? const Chip(label: Text('Request Sent')) : FilledButton(onPressed: () => widget.viewModel.sendFriendRequest(friend.id), child: const Text('Add Friend')))); }),
    ]);
  }
}

class _Requests extends StatelessWidget {
  const _Requests({required this.state, required this.viewModel});
  final CollaborationPreviewState state;
  final CollaborationPreviewViewModel viewModel;
  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(16), children: [
    const Text('Friend requests', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)), const SizedBox(height: 8),
    if (state.receivedRequests.isEmpty) const Padding(padding: EdgeInsets.all(24), child: Center(child: Text('No pending friend requests.'))),
    ...state.receivedRequests.map(
      (friend) => Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            CircleAvatar(child: Text(friend.name.substring(0, 1))),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(friend.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                  Text('@${friend.username}'),
                ],
              ),
            ),
            OutlinedButton(onPressed: () => viewModel.declineFriendRequest(friend.id), child: const Text('Decline')),
            const SizedBox(width: 6),
            FilledButton(onPressed: () => viewModel.acceptFriendRequest(friend), child: const Text('Accept')),
          ]),
        ),
      ),
    ),
  ]);
}

class _InviteFriends extends StatelessWidget {
  const _InviteFriends({required this.state, required this.viewModel});
  final CollaborationPreviewState state;
  final CollaborationPreviewViewModel viewModel;
  @override
  Widget build(BuildContext context) => Column(children: [
    const Padding(padding: EdgeInsets.fromLTRB(16, 16, 16, 4), child: Align(alignment: Alignment.centerLeft, child: Text('Select friends to invite to Tokyo Travel Group', style: TextStyle(fontWeight: FontWeight.w700)))),
    Expanded(child: ListView(children: state.friendDirectory.map((friend) => CheckboxListTile(value: state.selectedFriendIds.contains(friend.id), onChanged: (_) => viewModel.toggleFriendSelection(friend.id), secondary: CircleAvatar(child: Text(friend.name.substring(0, 1))), title: Text(friend.name), subtitle: Text('@${friend.username}'))).toList())),
    Padding(padding: const EdgeInsets.all(16), child: SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: state.selectedFriendIds.isEmpty ? null : () { viewModel.inviteSelectedFriends(); Navigator.pop(context); }, icon: const Icon(Icons.group_add_outlined), label: Text('Invite Selected Friends to Group (${state.selectedFriendIds.length})')))),
  ]);
}

void _showQr(BuildContext context, {required String title}) => showDialog<void>(context: context, builder: (_) => AlertDialog(title: Text(title), content: const Column(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.qr_code_2, size: 180), SizedBox(height: 8), Text('Use the camera scanner in the mobile app to connect with a friend.', textAlign: TextAlign.center)]), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))]));
