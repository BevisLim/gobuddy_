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
    this.members = const [PreviewMember(id: 'aina', name: 'Aina Rahman', email: 'aina@example.com')],
    this.friendDirectory = const [
      PreviewFriend(id: 'nora', name: 'Nora Lim', username: 'noralim', email: 'nora@example.com'),
      PreviewFriend(id: 'david', name: 'David Tan', username: 'davidtan', email: 'david@example.com'),
      PreviewFriend(id: 'mei', name: 'Mei Wong', username: 'meiw', email: 'mei@example.com'),
    ],
    this.receivedRequests = const [PreviewFriend(id: 'farah', name: 'Farah Aziz', username: 'farahaziz', email: 'farah@example.com')],
    this.sentRequestIds = const [], this.selectedFriendIds = const [],
    this.pinnedActivityKeys = const [], this.activityOverrides = const {},
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
  final List<PreviewMember> members;
  final List<PreviewFriend> friendDirectory;
  final List<PreviewFriend> receivedRequests;
  final List<String> sentRequestIds;
  final List<String> selectedFriendIds;
  final List<String> pinnedActivityKeys;
  final Map<String, PreviewActivity> activityOverrides;
  CollaborationPreviewState copyWith({bool? isPinned, int? primaryPollVotes, PreviewActivity? activity, List<PreviewActivity>? proposals, List<PreviewSharedFile>? sharedFiles, PreviewPoll? poll, PreviewCallType? activeCall, bool clearCall = false, bool? microphoneMuted, bool? cameraOn, bool? frontCamera, String? message, List<PreviewChatMessage>? chatMessages, bool? memberMuted, bool? memberRemoved, int? selectedDay, List<PreviewMember>? members, List<PreviewFriend>? friendDirectory, List<PreviewFriend>? receivedRequests, List<String>? sentRequestIds, List<String>? selectedFriendIds, List<String>? pinnedActivityKeys, Map<String, PreviewActivity>? activityOverrides}) => CollaborationPreviewState(
    isPinned: isPinned ?? this.isPinned, primaryPollVotes: primaryPollVotes ?? this.primaryPollVotes,
    activity: activity ?? this.activity, proposals: proposals ?? this.proposals, sharedFiles: sharedFiles ?? this.sharedFiles,
    poll: poll ?? this.poll, activeCall: clearCall ? null : (activeCall ?? this.activeCall),
    microphoneMuted: microphoneMuted ?? this.microphoneMuted, cameraOn: cameraOn ?? this.cameraOn,
    frontCamera: frontCamera ?? this.frontCamera, message: message, chatMessages: chatMessages ?? this.chatMessages,
    memberMuted: memberMuted ?? this.memberMuted, memberRemoved: memberRemoved ?? this.memberRemoved,
    selectedDay: selectedDay ?? this.selectedDay, members: members ?? this.members,
    friendDirectory: friendDirectory ?? this.friendDirectory, receivedRequests: receivedRequests ?? this.receivedRequests,
    sentRequestIds: sentRequestIds ?? this.sentRequestIds, selectedFriendIds: selectedFriendIds ?? this.selectedFriendIds,
    pinnedActivityKeys: pinnedActivityKeys ?? this.pinnedActivityKeys, activityOverrides: activityOverrides ?? this.activityOverrides,
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

class PreviewMember {
  const PreviewMember({required this.id, required this.name, required this.email, this.isMuted = false});
  final String id;
  final String name;
  final String email;
  final bool isMuted;
  PreviewMember copyWith({bool? isMuted}) => PreviewMember(id: id, name: name, email: email, isMuted: isMuted ?? this.isMuted);
}

class PreviewFriend {
  const PreviewFriend({required this.id, required this.name, required this.username, required this.email});
  final String id;
  final String name;
  final String username;
  final String email;
}
