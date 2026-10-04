class UserPreference {
  final String userId;
  final List<String> followedTags;
  final List<String> mutedDomains;

  const UserPreference({
    required this.userId,
    required this.followedTags,
    required this.mutedDomains,
  });

  factory UserPreference.fromJson(Map<String, dynamic> json) {
    return UserPreference(
      userId: json['user_id'] as String? ?? '',
      followedTags: (json['followed_tags'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      mutedDomains: (json['muted_domains'] as List<dynamic>?)
              ?.map((e) => e.toString().toLowerCase())
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'followed_tags': followedTags,
      'muted_domains': mutedDomains,
    };
  }

  UserPreference copyWith({
    String? userId,
    List<String>? followedTags,
    List<String>? mutedDomains,
  }) {
    return UserPreference(
      userId: userId ?? this.userId,
      followedTags: followedTags ?? this.followedTags,
      mutedDomains: mutedDomains ?? this.mutedDomains,
    );
  }
}
