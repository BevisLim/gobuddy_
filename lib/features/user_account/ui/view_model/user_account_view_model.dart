import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../model/user_account_model.dart';
import '../../repository/user_account_repository.dart';
import '../state/user_account_state.dart';

// 1. Modern NotifierProvider definition matching your team template
final userAccountViewModelProvider =
    NotifierProvider<UserAccountViewModel, UserAccountState>(
      UserAccountViewModel.new,
    );

// 2. The modern Notifier class managing your module state lifecycle
class UserAccountViewModel extends Notifier<UserAccountState> {
  @override
  UserAccountState build() {
    // Fire off async data initialization so it doesn't block layout threads
    _initLoad();

    // Return standard initial loading state immediately
    return const UserAccountState(isLoading: true);
  }

  /// Private initialization method to load profile data seamlessly
  Future<void> _initLoad() async {
    // Let Riverpod finish initializing the notifier before mutating state.
    await Future<void>.delayed(Duration.zero);
    await _loadProfile();
  }

  Future<void> refresh() async {
    if (state.isLoading) return;
    await _loadProfile();
  }

  Future<void> _loadProfile() async {
    final repository = ref.read(userAccountRepositoryProvider);
    state = state.copyWith(isLoading: true, clearError: true, clearUser: true);
    try {
      // A missing row is represented by an authenticated empty draft so the
      // first profile save can create it with an upsert.
      final initialUser = await repository.fetchCurrentAccount();
      state = state.copyWith(user: initialUser, isLoading: false);
    } catch (error) {
      state = state.copyWith(error: error.toString(), isLoading: false);
    }
  }

  /// Change the currently active sub-page within the user account module
  void goTo(UserAccountPage page) => state = state.copyWith(page: page);

  Future<bool> updateProfile(UserAccountProfileUpdate update) async {
    if (state.user == null || update.username.trim().isEmpty) return false;

    state = state.copyWith(isLoading: true, clearError: true);
    final repository = ref.read(userAccountRepositoryProvider);

    try {
      final updatedUser = await repository.updateProfile(
        state.user!.uid,
        update,
      );
      state = state.copyWith(
        user: updatedUser,
        page: UserAccountPage.profile,
        isLoading: false,
      );
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
      return false;
    }
  }

  Future<String?> selectProfileImage() async {
    if (state.user == null || state.isLoading) return null;

    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final image = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (image == null) {
        state = state.copyWith(isLoading: false);
        return null;
      }

      final repository = ref.read(userAccountRepositoryProvider);
      final updatedUser = await repository.updateProfilePhoto(image.path);
      state = state.copyWith(user: updatedUser, isLoading: false);
      return updatedUser.profilePhoto;
    } catch (error) {
      state = state.copyWith(
        error: error is ProfilePhotoUpdateException
            ? error.message
            : 'Unable to update profile photo. Please try again.',
        isLoading: false,
      );
      return null;
    }
  }

  Future<String?> startIdentityVerification() async {
    final user = state.user;
    if (user == null || state.isLoading) return null;

    state = state.copyWith(isLoading: true, clearError: true);
    final repository = ref.read(userAccountRepositoryProvider);

    try {
      final verificationUrl = await repository.createDiditSession();
      state = state.copyWith(isLoading: false);
      return verificationUrl;
    } catch (error) {
      state = state.copyWith(error: error.toString(), isLoading: false);
      return null;
    }
  }
}
