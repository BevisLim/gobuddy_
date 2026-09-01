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
  final String? nationality;
  final String bio;
  final bool isVerified;
  final List<String> galleryPhotos;

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
    this.nationality,
    this.bio = '',
    this.isVerified = false,
    this.galleryPhotos = const [],
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
    String? nationality,
    String? bio,
    bool? isVerified,
    List<String>? galleryPhotos,
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
      nationality: nationality ?? this.nationality,
      bio: bio ?? this.bio,
      isVerified: isVerified ?? this.isVerified,
      galleryPhotos: galleryPhotos ?? this.galleryPhotos,
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
    this.nationality,
    this.dateOfBirth,
  });

  final String? backgroundPhoto;
  final String? profilePhoto;
  final String username;
  final String? gender;
  final String? nationality;
  final DateTime? dateOfBirth;
  final String bio;
}
