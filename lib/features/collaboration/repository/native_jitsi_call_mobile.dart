import 'package:jitsi_meet_flutter_sdk/jitsi_meet_flutter_sdk.dart';

class NativeJitsiCall {
  const NativeJitsiCall();

  Future<bool> join({
    required String room,
    required String callType,
    String? displayName,
  }) async {
    final options = JitsiMeetConferenceOptions(
      serverURL: 'https://meet.jit.si',
      room: room,
      configOverrides: {
        'startWithAudioMuted': false,
        'startWithVideoMuted': callType == 'voice',
        'prejoinPageEnabled': true,
        'subject': 'GoBuddy group call',
      },
      featureFlags: {'unsaferoomwarning.enabled': false},
      userInfo: JitsiMeetUserInfo(displayName: displayName ?? 'GoBuddy member'),
    );
    await JitsiMeet().join(options);
    return true;
  }
}
