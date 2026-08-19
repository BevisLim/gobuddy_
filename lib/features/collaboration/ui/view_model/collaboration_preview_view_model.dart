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
  void muteMember(String duration) => state = state.copyWith(memberMuted: true, message: 'Aina has been muted for $duration.');
  void unmuteMember() => state = state.copyWith(memberMuted: false, message: 'Aina has been unmuted.');
  void removeMember() => state = state.copyWith(memberRemoved: true, message: 'Aina was removed from the group.');
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
