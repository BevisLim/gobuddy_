class SettingsState {
  const SettingsState({
    this.tripMatchNotificationsEnabled = true,
    this.isSigningOut = false,
    this.error,
  });

  final bool tripMatchNotificationsEnabled;
  final bool isSigningOut;
  final String? error;

  SettingsState copyWith({
    bool? tripMatchNotificationsEnabled,
    bool? isSigningOut,
    String? error,
    bool clearError = false,
  }) {
    return SettingsState(
      tripMatchNotificationsEnabled:
          tripMatchNotificationsEnabled ?? this.tripMatchNotificationsEnabled,
      isSigningOut: isSigningOut ?? this.isSigningOut,
      error: clearError ? null : error ?? this.error,
    );
  }
}
