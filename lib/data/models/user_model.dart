import 'package:equatable/equatable.dart';

class UserModel extends Equatable {
  final String id;
  final String name;
  final String username;
  final String role;
  final String groupId;

  const UserModel({
    required this.id,
    required this.name,
    required this.username,
    required this.role,
    required this.groupId,
  });

  bool get isHost => role == 'host';

  String get sosTopic => 'sos_group_$groupId';

  factory UserModel.fromJson(
    Map<String, dynamic> json, {
    String fallbackUsername = '',
  }) {
    final resolvedUsername =
        json['username']?.toString().trim().isNotEmpty == true
            ? json['username'].toString()
            : fallbackUsername;
    final resolvedName = json['name']?.toString().trim().isNotEmpty == true
        ? json['name'].toString()
        : (resolvedUsername.isNotEmpty ? resolvedUsername : 'User');

    return UserModel(
      id: json['id']?.toString() ?? '',
      name: resolvedName,
      username: resolvedUsername,
      role: json['role']?.toString() ?? 'user',
      groupId: json['group_id']?.toString() ?? 'default',
    );
  }

  @override
  List<Object> get props => [id, name, username, role, groupId];
}
