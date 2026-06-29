import 'package:freezed_annotation/freezed_annotation.dart';

part 'user.freezed.dart';
part 'user.g.dart';

/// Domain model for an EasySplit user.
@freezed
abstract class User with _$User {
  const factory User({
    required String id,
    required String email,
    String? name,
    @Default('avatar_1') String? avatarId,
    @Default('INR') String currency,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) = _User;

  factory User.fromJson(Map<String, dynamic> json) => _$UserFromJson(json);
}

/// Lightweight user reference (used inside lists)
@freezed
abstract class UserRef with _$UserRef {
  const factory UserRef({
    required String id,
    required String name,
    String? email,
    @Default('avatar_1') String? avatarId,
  }) = _UserRef;

  factory UserRef.fromJson(Map<String, dynamic> json) => _$UserRefFromJson(json);
}
