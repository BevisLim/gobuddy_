import 'package:url_launcher/url_launcher.dart';

/// Opens a room on the public Jitsi Meet service.
///
/// The room name is deterministic, so every member of the same trip joins the
/// same call. A production deployment can replace the base URL with a private
/// Jitsi server without changing the UI or view model.
class JitsiCallRepository {
  const JitsiCallRepository();

  Uri roomUri({required String tripId, required String callType}) {
    final roomName = roomNameForTrip(tripId);
    final query = callType == 'voice'
        ? 'config.startWithVideoMuted=true&config.prejoinPageEnabled=true'
        : 'config.prejoinPageEnabled=true';
    return Uri.parse('https://meet.jit.si/$roomName#$query');
  }

  String roomNameForTrip(String tripId) {
    final safeTripId = tripId.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '-');
    return 'gobuddy-trip-$safeTripId';
  }

  Future<void> joinTripCall({
    required String tripId,
    required String callType,
  }) async {
    final uri = roomUri(tripId: tripId, callType: callType);

    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw StateError('Could not open the $callType call. Please try again.');
    }
  }
}
