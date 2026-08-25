import 'package:url_launcher/url_launcher.dart';

/// Opens a room on the public Jitsi Meet service.
///
/// The room name is deterministic, so every member of the same trip joins the
/// same call. A production deployment can replace the base URL with a private
/// Jitsi server without changing the UI or view model.
class JitsiCallRepository {
  const JitsiCallRepository();

  Future<void> joinTripCall({
    required String tripId,
    required String callType,
  }) async {
    final safeTripId = tripId.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '-');
    final roomName = 'gobuddy-trip-$safeTripId';
    final query = callType == 'voice'
        ? 'config.startWithVideoMuted=true&config.prejoinPageEnabled=true'
        : 'config.prejoinPageEnabled=true';
    final uri = Uri.parse('https://meet.jit.si/$roomName#$query');

    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw StateError('Could not open the $callType call. Please try again.');
    }
  }
}
