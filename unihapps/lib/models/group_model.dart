import 'dart:convert';

class GroupModel {
  final String id;
  final String createdBy;
  final String name;
  final String description;
  final List<String>
  admins; //for extension of when we want to use it to hold large public events
  final List<String> members;
  final String iconColor;
  // final Map<String, List<String>> Plans; => for plans that day/week => all shows up in the group cal!?
  // later on feature though -> bit like the group messaging being an extension as well

  GroupModel({
    required this.id,
    required this.createdBy,
    required this.name,
    required this.description,
    this.members = const [],
    this.admins = const [],
    this.iconColor = 'deepGreen',
  });

  factory GroupModel.fromMap(String id, Map<String, dynamic> map) {
    return GroupModel(
      id: id,
      name: map['name'] as String? ?? '',
      description: map['description'] as String? ?? '',
      createdBy: map['createdBy'] as String? ?? '',
      members: List<String>.from(map['members'] ?? []),
      admins: List<String>.from(map['admins'] ?? []),
      iconColor: map['iconColor'] as String? ?? 'deepPurple',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'createdBy': createdBy,
      'members': members,
      'admins': admins,
      'iconColor': iconColor,
    };
  }
}
