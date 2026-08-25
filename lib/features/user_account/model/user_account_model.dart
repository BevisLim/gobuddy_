enum UserAccountPage { profile, editProfile, security }

class UserAccount {
  final String uid;
  final String email;
  final String phoneNumber;
  final String? backgroundPhoto;
  final String? profilePhoto;
  final String username;
  final String? fullName;
  final String? gender;
  final DateTime? dateOfBirth;
  final DateTime? joinedAt;
  final String? country;
  final String bio;
  final bool isVerified;

  const UserAccount({
    required this.uid,
    required this.email,
    required this.phoneNumber,
    required this.username,
    this.backgroundPhoto,
    this.profilePhoto,
    this.fullName,
    this.gender,
    this.dateOfBirth,
    this.joinedAt,
    this.country,
    this.bio = '',
    this.isVerified = false,
  });

  UserAccount copyWith({
    String? uid,
    String? email,
    String? phoneNumber,
    String? backgroundPhoto,
    String? profilePhoto,
    String? username,
    String? fullName,
    String? gender,
    DateTime? dateOfBirth,
    DateTime? joinedAt,
    String? country,
    String? bio,
    bool? isVerified,
  }) {
    return UserAccount(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      backgroundPhoto: backgroundPhoto ?? this.backgroundPhoto,
      profilePhoto: profilePhoto ?? this.profilePhoto,
      username: username ?? this.username,
      fullName: fullName ?? this.fullName,
      gender: gender ?? this.gender,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      joinedAt: joinedAt ?? this.joinedAt,
      country: country ?? this.country,
      bio: bio ?? this.bio,
      isVerified: isVerified ?? this.isVerified,
    );
  }
}

class UserAccountProfileUpdate {
  const UserAccountProfileUpdate({
    required this.username,
    required this.bio,
    this.backgroundPhoto,
    this.profilePhoto,
    this.gender,
    this.country,
  });

  final String? backgroundPhoto;
  final String? profilePhoto;
  final String username;
  final String? gender;
  final String? country;
  final String bio;
}

class IdentityVerificationResult {
  const IdentityVerificationResult({
    required this.fullName,
    required this.dateOfBirth,
  });

  final String fullName;
  final DateTime dateOfBirth;
}
