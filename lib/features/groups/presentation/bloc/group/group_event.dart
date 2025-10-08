import 'package:equatable/equatable.dart';
import 'package:study_sensei/features/groups/data/models/group_model.dart';

abstract class GroupEvent extends Equatable {
  const GroupEvent();

  @override
  List<Object?> get props => [];
}

// Load events
class LoadUserGroups extends GroupEvent {
  final String userId;

  const LoadUserGroups(this.userId);

  @override
  List<Object> get props => [userId];
}

class LoadGroup extends GroupEvent {
  final String groupId;

  const LoadGroup(this.groupId);

  @override
  List<Object> get props => [groupId];
}

// Create, Update, Delete
class CreateGroup extends GroupEvent {
  final Group group;

  const CreateGroup(this.group);

  @override
  List<Object> get props => [group];
}

class UpdateGroup extends GroupEvent {
  final Group group;

  const UpdateGroup(this.group);

  @override
  List<Object> get props => [group];
}

class DeleteGroup extends GroupEvent {
  final String groupId;

  const DeleteGroup(this.groupId);

  @override
  List<Object> get props => [groupId];
}

// Member management
class AddGroupMember extends GroupEvent {
  final String groupId;
  final String userId;

  const AddGroupMember({required this.groupId, required this.userId});

  @override
  List<Object> get props => [groupId, userId];
}

class RemoveGroupMember extends GroupEvent {
  final String groupId;
  final String userId;

  const RemoveGroupMember({required this.groupId, required this.userId});

  @override
  List<Object> get props => [groupId, userId];
}

class AddGroupAdmin extends GroupEvent {
  final String groupId;
  final String userId;

  const AddGroupAdmin({required this.groupId, required this.userId});

  @override
  List<Object> get props => [groupId, userId];
}

class RemoveGroupAdmin extends GroupEvent {
  final String groupId;
  final String userId;

  const RemoveGroupAdmin({required this.groupId, required this.userId});

  @override
  List<Object> get props => [groupId, userId];
}

class InviteToGroup extends GroupEvent {
  final String groupId;
  final String email;

  const InviteToGroup({required this.groupId, required this.email});

  @override
  List<Object> get props => [groupId, email];
}

// Invitation management
class CancelInvite extends GroupEvent {
  final String groupId;
  final String email;

  const CancelInvite({required this.groupId, required this.email});

  @override
  List<Object> get props => [groupId, email];
}

// Search
class SearchGroups extends GroupEvent {
  final String query;

  const SearchGroups(this.query);

  @override
  List<Object> get props => [query];
}
