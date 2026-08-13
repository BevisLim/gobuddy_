class Traveller {
  const Traveller({
    required this.userId,
    required this.name,
    this.email,
    this.profilePhoto,
    String? initials,
  }) : initials = initials ?? '';

  final int userId;
  final String name;
  final String? email;
  final String? profilePhoto;
  final String initials;

  factory Traveller.fromMap(Map<String, Object?> map) => Traveller(
        userId: map['user_id']! as int,
        name: map['name']! as String,
        email: map['email'] as String?,
        profilePhoto: map['profile_photo'] as String?,
        initials: map['initials'] as String?,
      );
}
