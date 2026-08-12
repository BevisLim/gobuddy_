import '../constants/app_constants.dart';

/// Temporary development context. Teammates can replace this provider later.
class AppSession {
  const AppSession({
    this.currentTripId = AppConstants.currentTripId,
    this.currentUserId = AppConstants.currentUserId,
  });

  final int currentTripId;
  final int currentUserId;
}
