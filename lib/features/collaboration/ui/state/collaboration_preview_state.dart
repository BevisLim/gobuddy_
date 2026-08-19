enum PreviewCallType { voice, video }

class CollaborationPreviewState {
  const CollaborationPreviewState({
    this.isPinned = true, this.primaryPollVotes = 2,
    this.activity = const PreviewActivity(), this.proposals = const [],
    this.sharedFiles = const [], this.poll = const PreviewPoll(), this.activeCall,
    this.microphoneMuted = false, this.cameraOn = true, this.frontCamera = true, this.message,
    this.chatMessages = const [
      PreviewChatMessage(sender: 'Aina', body: 'I found a great ramen place near Shibuya.'),
      PreviewChatMessage(sender: 'You', body: "Let's vote on it in the timeline."),
    ],
    this.memberMuted = false, this.memberRemoved = false, this.selectedDay = 1,
  });
  final bool isPinned;
  final int primaryPollVotes;
  final PreviewActivity activity;
  final List<PreviewActivity> proposals;
  final List<PreviewSharedFile> sharedFiles;
  final PreviewPoll poll;
  final PreviewCallType? activeCall;
  final bool microphoneMuted;
  final bool cameraOn;
  final bool frontCamera;
  final String? message;
  final List<PreviewChatMessage> chatMessages;
  final bool memberMuted;
  final bool memberRemoved;
  final int selectedDay;
  CollaborationPreviewState copyWith({bool? isPinned, int? primaryPollVotes, PreviewActivity? activity, List<PreviewActivity>? proposals, List<PreviewSharedFile>? sharedFiles, PreviewPoll? poll, PreviewCallType? activeCall, bool clearCall = false, bool? microphoneMuted, bool? cameraOn, bool? frontCamera, String? message, List<PreviewChatMessage>? chatMessages, bool? memberMuted, bool? memberRemoved, int? selectedDay}) => CollaborationPreviewState(
    isPinned: isPinned ?? this.isPinned, primaryPollVotes: primaryPollVotes ?? this.primaryPollVotes,
    activity: activity ?? this.activity, proposals: proposals ?? this.proposals, sharedFiles: sharedFiles ?? this.sharedFiles,
    poll: poll ?? this.poll, activeCall: clearCall ? null : (activeCall ?? this.activeCall),
    microphoneMuted: microphoneMuted ?? this.microphoneMuted, cameraOn: cameraOn ?? this.cameraOn,
    frontCamera: frontCamera ?? this.frontCamera, message: message, chatMessages: chatMessages ?? this.chatMessages,
    memberMuted: memberMuted ?? this.memberMuted, memberRemoved: memberRemoved ?? this.memberRemoved,
    selectedDay: selectedDay ?? this.selectedDay,
  );
}

class PreviewActivity {
  const PreviewActivity({this.title = 'Hotel check-in', this.category = 'Accommodation', this.date, this.time = '3:00 PM', this.location = 'Shinjuku', this.budget = 80, this.notes = 'Bring the booking confirmation.', this.status = 'Confirmed', this.isLocked = false});
  final String title;
  final String category;
  final DateTime? date;
  final String time;
  final String location;
  final double budget;
  final String notes;
  final String status;
  final bool isLocked;
}

class PreviewPoll {
  const PreviewPoll({this.question = 'What should we do on Saturday afternoon?', this.options = const ['Visit teamLab Planets', 'Explore Asakusa'], this.allowMultipleChoice = false, this.selectedOptions = const []});
  final String question;
  final List<String> options;
  final bool allowMultipleChoice;
  final List<String> selectedOptions;
}

class PreviewSharedFile {
  const PreviewSharedFile({required this.name, required this.title, required this.category, required this.sizeBytes});
  final String name;
  final String title;
  final String category;
  final int sizeBytes;
}

class PreviewChatMessage {
  const PreviewChatMessage({required this.sender, required this.body});
  final String sender;
  final String body;
}
