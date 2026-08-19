import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutter_mvvm_riverpod/features/collaboration/ui/state/collaboration_preview_state.dart';
import 'package:flutter_mvvm_riverpod/features/collaboration/ui/view_model/collaboration_preview_view_model.dart';
import 'package:flutter_mvvm_riverpod/features/collaboration/ui/widgets/friend_management_sheet.dart';

const _categories = ['Dining', 'Sightseeing', 'Transport', 'Accommodation', 'Flight'];
const _statuses = ['Proposed', 'Confirmed', 'Cancelled'];
const _fileCategories = ['Boarding Pass', 'Hotel Voucher', 'Receipt', 'ID/Passport', 'Map'];

class GroupCollaborationPreviewScreen extends ConsumerWidget {
  const GroupCollaborationPreviewScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<CollaborationPreviewState>(collaborationPreviewViewModelProvider, (previous, next) {
      if (next.message != null && next.message != previous?.message) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(next.message!)));
    });
    final state = ref.watch(collaborationPreviewViewModelProvider);
    final viewModel = ref.read(collaborationPreviewViewModelProvider.notifier);
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Tokyo Travel Group'), Text('Group Communication & Collaboration', style: TextStyle(fontSize: 12))]),
          actions: [
            IconButton(onPressed: () => _showCallSheet(context, viewModel, PreviewCallType.voice), icon: const Icon(Icons.call), tooltip: 'Start voice call'),
            IconButton(onPressed: () => _showCallSheet(context, viewModel, PreviewCallType.video), icon: const Icon(Icons.videocam), tooltip: 'Start video call'),
          ],
          bottom: const TabBar(tabs: [Tab(icon: Icon(Icons.chat_bubble_outline), text: 'Chat'), Tab(icon: Icon(Icons.event_note), text: 'Timeline'), Tab(icon: Icon(Icons.folder_outlined), text: 'Files')]),
        ),
        body: TabBarView(children: [_ChatTab(state: state, viewModel: viewModel), _TimelineTab(state: state, viewModel: viewModel), _FilesTab(state: state, viewModel: viewModel)]),
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
  void dispose() { _messageController.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(16), children: [
    Row(children: [const Expanded(child: Text('Member Management', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))), TextButton.icon(onPressed: () => showModalBottomSheet<void>(context: context, isScrollControlled: true, builder: (_) => const FriendManagementSheet()), icon: const Icon(Icons.person_add_outlined), label: const Text('Add friend'))]),
    if (widget.state.members.isEmpty)
      const Card(child: ListTile(leading: Icon(Icons.person_remove_outlined), title: Text('Aina Rahman was removed'), subtitle: Text('This member no longer has access to the group.')))
    else Card(child: ListTile(leading: const CircleAvatar(child: Text('A')), title: const Text('Aina Rahman'), subtitle: Text(widget.state.memberMuted ? 'Trip member • Muted' : 'Trip member'), trailing: PopupMenuButton<String>(
      tooltip: 'Member options', icon: const Icon(Icons.more_vert),
      onSelected: (choice) { if (choice == 'mute') _showMuteDialog(context, widget.viewModel, widget.state.members.first); if (choice == 'unmute') widget.viewModel.unmuteMember(widget.state.members.first.id); if (choice == 'remove') _showRemoveDialog(context, widget.viewModel, widget.state.members.first); },
      itemBuilder: (_) => [PopupMenuItem(value: widget.state.members.first.isMuted ? 'unmute' : 'mute', child: Text(widget.state.members.first.isMuted ? 'Unmute member' : 'Mute member')), const PopupMenuItem(value: 'remove', child: Text('Remove member'))],
    ))),
    ...widget.state.members.skip(1).map((member) => Card(child: ListTile(leading: CircleAvatar(child: Text(member.name.substring(0, 1).toUpperCase())), title: Text(member.name), subtitle: Text(member.isMuted ? '${member.email} • Muted' : member.email), trailing: PopupMenuButton<String>(icon: const Icon(Icons.more_vert), onSelected: (choice) { if (choice == 'mute') _showMuteDialog(context, widget.viewModel, member); if (choice == 'unmute') widget.viewModel.unmuteMember(member.id); if (choice == 'remove') _showRemoveDialog(context, widget.viewModel, member); }, itemBuilder: (_) => [PopupMenuItem(value: member.isMuted ? 'unmute' : 'mute', child: Text(member.isMuted ? 'Unmute member' : 'Mute member')), const PopupMenuItem(value: 'remove', child: Text('Remove member'))])))),
    const SizedBox(height: 14), const Text('Group Chat', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), const SizedBox(height: 8),
    ...widget.state.chatMessages.map((message) => Card(child: ListTile(title: Text(message.sender), subtitle: Text(message.body)))),
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
  ]);
}

class _TimelineTab extends StatelessWidget {
  const _TimelineTab({required this.state, required this.viewModel});
  final CollaborationPreviewState state;
  final CollaborationPreviewViewModel viewModel;
  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(16), children: [
    const _TripSummaryCard(),
    const SizedBox(height: 16),
    Row(children: [const Expanded(child: Text('Itinerary', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800))), TextButton.icon(onPressed: () => _showActivityForm(context, viewModel, proposal: true), icon: const Icon(Icons.add, size: 18), label: const Text('Add activity'))]),
    const SizedBox(height: 6),
    SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [for (var day = 1; day <= 3; day++) Padding(padding: const EdgeInsets.only(right: 8), child: ChoiceChip(label: Column(mainAxisSize: MainAxisSize.min, children: [Text('Day $day', style: const TextStyle(fontWeight: FontWeight.bold)), Text(day == 1 ? 'Aug 10' : day == 2 ? 'Aug 11' : 'Aug 12', style: const TextStyle(fontSize: 11))]), selected: state.selectedDay == day, selectedColor: const Color(0xFF149B8A), labelStyle: TextStyle(color: state.selectedDay == day ? Colors.white : const Color(0xFF293840)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), onSelected: (_) => viewModel.selectDay(day)))])),
    const SizedBox(height: 12),
    Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10), decoration: BoxDecoration(color: const Color(0xFFF3F7F6), borderRadius: BorderRadius.circular(12)), child: Row(children: [Expanded(child: Text(_dayTitle(state.selectedDay), style: const TextStyle(fontWeight: FontWeight.w800))), TextButton.icon(onPressed: () => _showActivityForm(context, viewModel, proposal: true), icon: const Icon(Icons.add, size: 16), label: const Text('Add activity'))])),
    const SizedBox(height: 8),
    ..._dayActivities(state).map((activity) => _activityCard(context, activity, state.selectedDay == 1 && activity.title == state.activity.title ? state.isPinned : false, viewModel, editable: state.selectedDay == 1 && activity.title == state.activity.title)),
    if (state.selectedDay == 1) ...state.proposals.map((activity) => _activityCard(context, activity, false, viewModel, editable: false)),
    const SizedBox(height: 16), Row(children: [const Expanded(child: Text('Activity Poll', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))), TextButton.icon(onPressed: () => _showPollForm(context, viewModel), icon: const Icon(Icons.add_chart), label: const Text('Create poll'))]),
    Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(state.poll.question, style: const TextStyle(fontWeight: FontWeight.w600)), const SizedBox(height: 8),
      ...state.poll.options.map((option) => state.poll.allowMultipleChoice ? CheckboxListTile(contentPadding: EdgeInsets.zero, value: state.poll.selectedOptions.contains(option), title: Text(option), onChanged: (_) => viewModel.selectVote(option)) : RadioListTile<String>(contentPadding: EdgeInsets.zero, value: option, groupValue: state.poll.selectedOptions.isEmpty ? null : state.poll.selectedOptions.first, title: Text(option), onChanged: (_) => viewModel.selectVote(option))),
    ]))),
  ]);

  Widget _activityCard(BuildContext context, PreviewActivity activity, bool pinned, CollaborationPreviewViewModel viewModel, {required bool editable}) => Card(child: ListTile(
    leading: Icon(pinned ? Icons.push_pin : Icons.event_outlined), title: Text(activity.title),
    subtitle: Text('${activity.category} • ${activity.location}\n${activity.date?.day ?? 14}/${activity.date?.month ?? 5} • ${activity.time} • RM ${activity.budget.toStringAsFixed(2)}\n${activity.status}${activity.isLocked ? ' • Locked' : ''}'), isThreeLine: true,
    trailing: editable ? Wrap(spacing: 0, children: [
      IconButton(onPressed: () => _confirmPin(context, viewModel), icon: Icon(pinned ? Icons.push_pin : Icons.push_pin_outlined), tooltip: 'Pin activity'),
      IconButton(onPressed: activity.isLocked ? null : () => _showActivityForm(context, viewModel, existing: activity), icon: const Icon(Icons.edit_outlined), tooltip: 'Edit activity'),
      IconButton(onPressed: () => viewModel.setLock(!activity.isLocked), icon: Icon(activity.isLocked ? Icons.lock : Icons.lock_open_outlined), tooltip: 'Lock activity (admin)'),
    ]) : const Icon(Icons.pending_actions_outlined),
  ));

  String _dayTitle(int day) => switch (day) { 1 => 'Day 1 — Arrival & Check-in', 2 => 'Day 2 — Tokyo Sightseeing', _ => 'Day 3 — Departure Day' };
  List<PreviewActivity> _dayActivities(CollaborationPreviewState state) => switch (state.selectedDay) {
    1 => [state.activity],
    2 => const [PreviewActivity(title: 'Senso-ji Temple', category: 'Sightseeing', location: 'Asakusa', time: '9:30 AM', budget: 0, notes: 'Meet at hotel lobby.', status: 'Confirmed'), PreviewActivity(title: 'Ramen lunch', category: 'Dining', location: 'Shibuya', time: '1:00 PM', budget: 45, notes: 'Group reservation for four.', status: 'Proposed'), PreviewActivity(title: 'Shibuya Crossing walk', category: 'Sightseeing', location: 'Shibuya', time: '4:00 PM', budget: 0, notes: 'Bring a camera.', status: 'Confirmed')],
    _ => const [PreviewActivity(title: 'Hotel check-out', category: 'Accommodation', location: 'Shinjuku', time: '10:00 AM', budget: 0, notes: 'Leave luggage at reception.', status: 'Confirmed'), PreviewActivity(title: 'Narita Express', category: 'Transport', location: 'Tokyo Station', time: '12:30 PM', budget: 95, notes: 'Arrive 30 minutes early.', status: 'Confirmed'), PreviewActivity(title: 'Flight home', category: 'Flight', location: 'Narita Airport', time: '4:45 PM', budget: 0, notes: 'Check passport and boarding pass.', status: 'Confirmed')],
  };
}

class _TripSummaryCard extends StatelessWidget {
  const _TripSummaryCard();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: const Color(0xFF149B8A), borderRadius: BorderRadius.circular(18)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [const Icon(Icons.flight_takeoff, color: Colors.white), const SizedBox(width: 8), const Expanded(child: Text('Tokyo Adventure', style: TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w800))), FilledButton.tonal(onPressed: () {}, style: FilledButton.styleFrom(backgroundColor: Colors.white24, foregroundColor: Colors.white), child: const Text('Share'))]),
      const SizedBox(height: 4),
      const Text('Aug 10–12, 2026 • 3 days', style: TextStyle(color: Colors.white70)),
      const SizedBox(height: 12),
      const Row(children: [CircleAvatar(radius: 13, child: Text('T')), SizedBox(width: 4), CircleAvatar(radius: 13, child: Text('A')), SizedBox(width: 8), Text('3 travellers • Planning together', style: TextStyle(color: Colors.white70, fontSize: 12))]),
      const SizedBox(height: 12),
      const Row(children: [Expanded(child: Text('Planning progress', style: TextStyle(color: Colors.white70, fontSize: 12))), Text('60%', style: TextStyle(color: Colors.white70, fontSize: 12))]),
      const SizedBox(height: 5),
      const LinearProgressIndicator(value: .6, minHeight: 5, borderRadius: BorderRadius.all(Radius.circular(6)), color: Colors.white, backgroundColor: Colors.white30),
    ]),
  );
}

class _FilesTab extends StatelessWidget {
  const _FilesTab({required this.state, required this.viewModel});
  final CollaborationPreviewState state;
  final CollaborationPreviewViewModel viewModel;
  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(16), children: [
    FilledButton.icon(onPressed: () => _chooseFile(context, viewModel), icon: const Icon(Icons.upload_file), label: const Text('Choose file')),
    const SizedBox(height: 12), const Card(child: ListTile(leading: Icon(Icons.picture_as_pdf_outlined), title: Text('Hotel booking.pdf'), subtitle: Text('Hotel Voucher • Shared by Sophia'))),
    const Card(child: ListTile(leading: Icon(Icons.image_outlined), title: Text('Tokyo food map.jpg'), subtitle: Text('Map • Shared by Aina'))),
    ...state.sharedFiles.map((file) => Card(child: ListTile(leading: const Icon(Icons.insert_drive_file_outlined), title: Text(file.title), subtitle: Text('${file.category} • ${file.name}\n${(file.sizeBytes / 1024).toStringAsFixed(1)} KB • Shared by you'), isThreeLine: true))),
  ]);
}

Future<void> _showActivityForm(BuildContext context, CollaborationPreviewViewModel viewModel, {bool proposal = false, PreviewActivity? existing}) async {
  final current = existing ?? const PreviewActivity(title: '', location: '', notes: '', status: 'Proposed');
  final title = TextEditingController(text: current.title); final location = TextEditingController(text: current.location); final budget = TextEditingController(text: current.budget == 80 && proposal ? '' : current.budget.toString()); final notes = TextEditingController(text: current.notes);
  var category = current.category; var status = current.status; var date = current.date ?? DateTime.now().add(const Duration(days: 1)); var time = TimeOfDay.now(); var locked = current.isLocked;
  await showDialog<void>(context: context, builder: (dialogContext) => StatefulBuilder(builder: (context, setState) => AlertDialog(
    title: Text(proposal ? 'Propose Activity' : 'Edit Activity'), content: SizedBox(width: 420, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
      TextField(controller: title, decoration: const InputDecoration(labelText: 'Activity Title')), DropdownButtonFormField<String>(value: category, decoration: const InputDecoration(labelText: 'Category'), items: _categories.map((item) => DropdownMenuItem(value: item, child: Text(item))).toList(), onChanged: (value) => setState(() => category = value!)),
      ListTile(contentPadding: EdgeInsets.zero, title: Text('Proposed date: ${date.day}/${date.month}/${date.year}'), trailing: const Icon(Icons.calendar_today_outlined), onTap: () async { final selected = await showDatePicker(context: context, initialDate: date, firstDate: DateTime.now().subtract(const Duration(days: 1)), lastDate: DateTime(2030)); if (selected != null) setState(() => date = selected); }),
      ListTile(contentPadding: EdgeInsets.zero, title: Text('Proposed start time: ${time.format(context)}'), trailing: const Icon(Icons.access_time), onTap: () async { final selected = await showTimePicker(context: context, initialTime: time); if (selected != null) setState(() => time = selected); }),
      TextField(controller: location, decoration: const InputDecoration(labelText: 'Location / Address')), TextField(controller: budget, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Estimated Budget per Person (RM)')), TextField(controller: notes, maxLines: 3, decoration: const InputDecoration(labelText: 'Description / Notes')),
      if (!proposal) ...[DropdownButtonFormField<String>(value: status, decoration: const InputDecoration(labelText: 'Activity Status'), items: _statuses.map((item) => DropdownMenuItem(value: item, child: Text(item))).toList(), onChanged: (value) => setState(() => status = value!)), SwitchListTile(contentPadding: EdgeInsets.zero, value: locked, title: const Text('Lock Activity (Admin only)'), onChanged: (value) => setState(() => locked = value)), TextField(decoration: const InputDecoration(labelText: 'Change Note / Reason for Edit'))],
    ]))), actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')), FilledButton(onPressed: () { if (title.text.trim().isEmpty || location.text.trim().isEmpty) return; final activity = PreviewActivity(title: title.text.trim(), category: category, date: date, time: time.format(context), location: location.text.trim(), budget: double.tryParse(budget.text) ?? 0, notes: notes.text.trim(), status: status, isLocked: locked); proposal ? viewModel.addProposal(activity) : viewModel.saveActivity(activity); Navigator.pop(dialogContext); }, child: Text(proposal ? 'Submit Proposal' : 'Save Changes'))],
  )));
  title.dispose(); location.dispose(); budget.dispose(); notes.dispose();
}

Future<void> _showPollForm(BuildContext context, CollaborationPreviewViewModel viewModel) async {
  final question = TextEditingController(); final options = [TextEditingController(), TextEditingController()]; var multiple = false;
  await showDialog<void>(context: context, builder: (dialogContext) => StatefulBuilder(builder: (context, setState) => AlertDialog(title: const Text('Create Poll'), content: SizedBox(width: 400, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [TextField(controller: question, decoration: const InputDecoration(labelText: 'Poll Question / Prompt')), ...options.asMap().entries.map((entry) => TextField(controller: entry.value, decoration: InputDecoration(labelText: 'Poll Option ${entry.key + 1}'))), TextButton.icon(onPressed: () => setState(() => options.add(TextEditingController())), icon: const Icon(Icons.add), label: const Text('Add Option')), SwitchListTile(value: multiple, title: const Text('Allow Multiple Choice'), onChanged: (value) => setState(() => multiple = value))]))), actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')), FilledButton(onPressed: () { final values = options.map((item) => item.text.trim()).where((item) => item.isNotEmpty).toList(); if (question.text.trim().isEmpty || values.length < 2) return; viewModel.createPoll(question: question.text.trim(), options: values, multiple: multiple); Navigator.pop(dialogContext); }, child: const Text('Create Poll'))])));
  question.dispose(); for (final option in options) { option.dispose(); }
}

Future<void> _chooseFile(BuildContext context, CollaborationPreviewViewModel viewModel) async {
  final result = await FilePicker.platform.pickFiles(withData: true, type: FileType.custom, allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'doc', 'docx']);
  if (result == null || result.files.isEmpty) return; final file = result.files.first; final label = TextEditingController(text: file.name); var category = _fileCategories.first;
  await showDialog<void>(context: context, builder: (dialogContext) => StatefulBuilder(builder: (context, setState) => AlertDialog(title: const Text('Share File'), content: Column(mainAxisSize: MainAxisSize.min, children: [Text(file.name), TextField(controller: label, decoration: const InputDecoration(labelText: 'Document Title / Label')), DropdownButtonFormField<String>(value: category, decoration: const InputDecoration(labelText: 'File Category'), items: _fileCategories.map((item) => DropdownMenuItem(value: item, child: Text(item))).toList(), onChanged: (value) => setState(() => category = value!))]), actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')), FilledButton(onPressed: () { viewModel.addSharedFile(PreviewSharedFile(name: file.name, title: label.text.trim().isEmpty ? file.name : label.text.trim(), category: category, sizeBytes: file.size)); Navigator.pop(dialogContext); }, child: const Text('Upload & Send'))])));
  label.dispose();
}

Future<void> _confirmPin(BuildContext context, CollaborationPreviewViewModel viewModel) => showDialog<void>(context: context, builder: (dialogContext) => AlertDialog(title: const Text('Pin activity'), content: const Text('Pin to top of itinerary?'), actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('No')), FilledButton(onPressed: () { viewModel.togglePin(); Navigator.pop(dialogContext); }, child: const Text('Yes'))]));
Future<void> _showMuteDialog(BuildContext context, CollaborationPreviewViewModel viewModel, PreviewMember member) async { var duration = '1 Hour'; await showDialog<void>(context: context, builder: (dialogContext) => StatefulBuilder(builder: (context, setState) => AlertDialog(title: Text('Mute ${member.name}'), content: DropdownButtonFormField<String>(value: duration, decoration: const InputDecoration(labelText: 'Mute duration'), items: const ['1 Hour', '24 Hours', 'Until Unmuted'].map((item) => DropdownMenuItem(value: item, child: Text(item))).toList(), onChanged: (value) => setState(() => duration = value!)), actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')), FilledButton(onPressed: () { viewModel.muteMember(member.id, duration); Navigator.pop(dialogContext); }, child: const Text('Mute Member'))]))); }
Future<void> _showRemoveDialog(BuildContext context, CollaborationPreviewViewModel viewModel, PreviewMember member) => showDialog<void>(context: context, builder: (dialogContext) => AlertDialog(title: const Text('Remove member'), content: Text('Are you sure you want to remove ${member.name} from the group?'), actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')), FilledButton(style: FilledButton.styleFrom(backgroundColor: Colors.red), onPressed: () { viewModel.removeMember(member.id); Navigator.pop(dialogContext); }, child: const Text('Remove Member'))]));
Future<void> _showAddFriendDialog(BuildContext context, CollaborationPreviewViewModel viewModel) async { final name = TextEditingController(); final email = TextEditingController(); await showDialog<void>(context: context, builder: (dialogContext) => AlertDialog(title: const Text('Add Friend'), content: Column(mainAxisSize: MainAxisSize.min, children: [TextField(controller: name, decoration: const InputDecoration(labelText: 'Friend name')), TextField(controller: email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email address'))]), actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')), FilledButton(onPressed: () { if (name.text.trim().isEmpty || email.text.trim().isEmpty) return; viewModel.addFriend(name: name.text.trim(), email: email.text.trim()); Navigator.pop(dialogContext); }, child: const Text('Add Friend'))])); name.dispose(); email.dispose(); }
void _showCallSheet(BuildContext context, CollaborationPreviewViewModel viewModel, PreviewCallType type) { viewModel.startCall(type); showModalBottomSheet<void>(context: context, builder: (_) => _CallControls(type: type, viewModel: viewModel)); }
class _CallControls extends ConsumerWidget { const _CallControls({required this.type, required this.viewModel}); final PreviewCallType type; final CollaborationPreviewViewModel viewModel; @override Widget build(BuildContext context, WidgetRef ref) { final state = ref.watch(collaborationPreviewViewModelProvider); return SafeArea(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(type == PreviewCallType.video ? Icons.videocam : Icons.call, size: 52), const SizedBox(height: 8), Text(type == PreviewCallType.video ? 'Video Call' : 'Voice Call', style: Theme.of(context).textTheme.titleLarge), const Text('Tokyo Travel Group'), const SizedBox(height: 20), Wrap(spacing: 16, children: [IconButton.filledTonal(onPressed: viewModel.toggleMicrophone, icon: Icon(state.microphoneMuted ? Icons.mic_off : Icons.mic), tooltip: 'Mute / unmute microphone'), if (type == PreviewCallType.video) ...[IconButton.filledTonal(onPressed: viewModel.toggleCamera, icon: Icon(state.cameraOn ? Icons.videocam : Icons.videocam_off), tooltip: 'Turn camera on / off'), IconButton.filledTonal(onPressed: viewModel.switchCamera, icon: const Icon(Icons.cameraswitch), tooltip: 'Switch front / rear camera')], IconButton.filled(onPressed: () { viewModel.endCall(); Navigator.pop(context); }, icon: const Icon(Icons.call_end), color: Colors.white, style: IconButton.styleFrom(backgroundColor: Colors.red), tooltip: 'End call')])]))); } }
