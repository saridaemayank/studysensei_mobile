import 'package:study_sensei/features/groups/data/enums/group_privacy.dart';

abstract class GroupEvent {
  const GroupEvent();
}

class CreateGroup extends GroupEvent {
  final String name;
  final String? description;
  final List<String> memberIds;
  final String adminId;
  final GroupPrivacy privacy;

  const CreateGroup({
    required this.name,
    this.description,
    required this.memberIds,
    required this.adminId,
    this.privacy = GroupPrivacy.private,
  });
}
