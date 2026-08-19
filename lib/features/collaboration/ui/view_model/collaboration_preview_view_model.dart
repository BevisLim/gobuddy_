import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutter_mvvm_riverpod/features/collaboration/ui/state/collaboration_preview_state.dart';

final collaborationPreviewViewModelProvider = NotifierProvider<CollaborationPreviewViewModel, CollaborationPreviewState>(CollaborationPreviewViewModel.new);

class CollaborationPreviewViewModel extends Notifier<CollaborationPreviewState> {
  @override
  CollaborationPreviewState build() => const CollaborationPreviewState();

  void startCall(PreviewCallType type) => state = state.copyWith(activeCall: type, message: '${type == PreviewCallType.video ? 'Video' : 'Voice'} call started.');
  void endCall() => state = state.copyWith(clearCall: true, message: 'Call ended.');
  void toggleMicrophone() => state = state.copyWith(microphoneMuted: !state.microphoneMuted);
  void toggleCamera() => state = state.copyWith(cameraOn: !state.cameraOn);
  void switchCamera() => state = state.copyWith(frontCamera: !state.frontCamera);
  void addFriend({required String name, required String email}) {
    final member = PreviewMember(id: DateTime.now().microsecondsSinceEpoch.toString(), name: name, email: email);
    state = state.copyWith(members: [...state.members, member], message: '$name was added to the group.');
  }
  void sendFriendRequest(String friendId) => state = state.copyWith(sentRequestIds: [...state.sentRequestIds, friendId], message: 'Friend request sent.');
  void acceptFriendRequest(PreviewFriend friend) => state = state.copyWith(receivedRequests: state.receivedRequests.where((item) => item.id != friend.id).toList(), friendDirectory: [...state.friendDirectory, friend], message: '${friend.name} is now your friend.');
  void declineFriendRequest(String friendId) => state = state.copyWith(receivedRequests: state.receivedRequests.where((item) => item.id != friendId).toList(), message: 'Friend request declined.');
  void toggleFriendSelection(String friendId) { final selected = List<String>.from(state.selectedFriendIds); selected.contains(friendId) ? selected.remove(friendId) : selected.add(friendId); state = state.copyWith(selectedFriendIds: selected); }
  void inviteSelectedFriends() {
    final selected = state.friendDirectory.where((friend) => state.selectedFriendIds.contains(friend.id));
    final newMembers = [for (final friend in selected) if (!state.members.any((member) => member.id == friend.id)) PreviewMember(id: friend.id, name: friend.name, email: friend.email)];
    state = state.copyWith(members: [...state.members, ...newMembers], selectedFriendIds: const [], message: '${newMembers.length} friend(s) invited to the group.');
  }
  void muteMember(String memberId, String duration) => state = state.copyWith(members: [for (final member in state.members) if (member.id == memberId) member.copyWith(isMuted: true) else member], message: 'Member has been muted for $duration.');
  void unmuteMember(String memberId) => state = state.copyWith(members: [for (final member in state.members) if (member.id == memberId) member.copyWith(isMuted: false) else member], message: 'Member has been unmuted.');
  void removeMember(String memberId) => state = state.copyWith(members: state.members.where((member) => member.id != memberId).toList(), message: 'Member was removed from the group.');
  void sendMessage(String body) {
    if (body.trim().isEmpty) return;
    state = state.copyWith(chatMessages: [...state.chatMessages, PreviewChatMessage(sender: 'You', body: body.trim())], message: 'Message sent.');
  }
  void selectDay(int day) => state = state.copyWith(selectedDay: day);
  void togglePin() => state = state.copyWith(isPinned: !state.isPinned, message: state.isPinned ? 'Activity unpinned.' : 'Activity pinned to the top.');
  void saveActivity(PreviewActivity activity) => state = state.copyWith(activity: activity, message: 'Activity changes saved.');
  void addProposal(PreviewActivity activity) => state = state.copyWith(proposals: [...state.proposals, activity], message: 'Activity proposal submitted.');
  void setLock(bool isLocked) => state = state.copyWith(activity: PreviewActivity(title: state.activity.title, category: state.activity.category, date: state.activity.date, time: state.activity.time, location: state.activity.location, budget: state.activity.budget, notes: state.activity.notes, status: state.activity.status, isLocked: isLocked), message: isLocked ? 'Activity locked.' : 'Activity unlocked.');
  void createPoll({required String question, required List<String> options, required bool multiple}) => state = state.copyWith(poll: PreviewPoll(question: question, options: options, allowMultipleChoice: multiple), message: 'Poll created for the group.');
  void selectVote(String option) {
    final selected = List<String>.from(state.poll.selectedOptions);
    if (state.poll.allowMultipleChoice) { selected.contains(option) ? selected.remove(option) : selected.add(option); } else { selected..clear()..add(option); }
    state = state.copyWith(poll: PreviewPoll(question: state.poll.question, options: state.poll.options, allowMultipleChoice: state.poll.allowMultipleChoice, selectedOptions: selected), message: 'Vote submitted.');
  }
  void addSharedFile(PreviewSharedFile file) => state = state.copyWith(sharedFiles: [...state.sharedFiles, file], message: '${file.title} was uploaded to the group.');
  void _notify(String message) => state = state.copyWith(message: message);
}
