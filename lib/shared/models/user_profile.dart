import 'package:freezed_annotation/freezed_annotation.dart';

part 'user_profile.freezed.dart';
part 'user_profile.g.dart';

@freezed
class UserProfile with _$UserProfile {
  const factory UserProfile({
    required String id,
    required String tenantId,
    required String fullName,
    required String employeeId,
    required String designation,
    String? phone,
    String? avatarUrl,
    required String orgUnitId,
    required String orgUnitName,
    @Default([]) List<String> permissions,
  }) = _UserProfile;

  factory UserProfile.fromJson(Map<String, dynamic> json) =>
      _$UserProfileFromJson(json);
}
