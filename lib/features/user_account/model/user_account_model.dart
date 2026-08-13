enum UserAccountPage { profile, editProfile, settings, security }

class UserAccount {
  final String uid;
  final String name;
  final String email;
  final String phoneNumber;

  const UserAccount({
    required this.uid,
    required this.name,
    required this.email,
    required this.phoneNumber,
  });

  UserAccount copyWith({
    String? uid,
    String? name,
    String? email,
    String? phoneNumber,
  }) {
    return UserAccount(
      uid: uid ?? this.uid,
      name: name ?? this.name,
      email: email ?? this.email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
    );
  }
}