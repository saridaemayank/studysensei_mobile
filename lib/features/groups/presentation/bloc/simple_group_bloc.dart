import 'dart:async';
import 'package:bloc/bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:meta/meta.dart';
import 'package:study_sensei/features/groups/data/models/group_model.dart';

// Events
abstract class GroupEvent {}

class LoadUserGroups extends GroupEvent {
  final String userId;
  LoadUserGroups(this.userId);
}

class CreateGroup extends GroupEvent {
  final Group group;
  CreateGroup(this.group);
}

// States
abstract class GroupState {}

class GroupInitial extends GroupState {}

class GroupLoading extends GroupState {
  final List<Group> groups;
  final Group? selectedGroup;
  final List<Group> searchResults;

  GroupLoading({
    this.groups = const [],
    this.selectedGroup,
    this.searchResults = const [],
  });
}

class GroupLoadSuccess extends GroupState {
  final List<Group> groups;
  GroupLoadSuccess({required this.groups});
}

class GroupOperationSuccess extends GroupState {
  final String message;
  GroupOperationSuccess({required this.message});
}

class GroupFailure extends GroupState {
  final String errorMessage;
  GroupFailure({required this.errorMessage});
}

class SimpleGroupBloc extends Bloc<GroupEvent, GroupState> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  SimpleGroupBloc() : super(GroupInitial()) {
    on<LoadUserGroups>(_onLoadUserGroups);
    on<CreateGroup>(_onCreateGroup);
  }

  Future<void> _onLoadUserGroups(
    LoadUserGroups event,
    Emitter<GroupState> emit,
  ) async {
    try {
      emit(
        GroupLoading(
          groups: state is GroupLoadSuccess
              ? (state as GroupLoadSuccess).groups
              : [],
        ),
      );

      // Get groups where user is a member (from the groups collection)
      final groupsQuery = await _firestore
          .collection('groups')
          .where('memberIds', arrayContains: event.userId)
          .get();

      // Also get groups from user's groups subcollection (for backward compatibility)
      final userGroupsSnapshot = await _firestore
          .collection('users')
          .doc(event.userId)
          .collection('groups')
          .get();

      // Combine both sources and remove duplicates
      final groupIds = <String>{};
      final groups = <Group>[];

      // Add groups from groups collection
      for (final doc in groupsQuery.docs) {
        if (!groupIds.contains(doc.id)) {
          groups.add(Group.fromMap(doc.id, doc.data()));
          groupIds.add(doc.id);
        }
      }

      // Add groups from user's groups subcollection (if not already added)
      for (final doc in userGroupsSnapshot.docs) {
        final groupId = doc.data()['groupId'] as String?;
        if (groupId != null && !groupIds.contains(groupId)) {
          final groupDoc = await _firestore
              .collection('groups')
              .doc(groupId)
              .get();
          if (groupDoc.exists) {
            groups.add(Group.fromMap(groupId, groupDoc.data()!));
            groupIds.add(groupId);
          }
        }
      }

      emit(GroupLoadSuccess(groups: groups));
    } catch (e) {
      print('Error loading groups: $e');
      emit(GroupFailure(errorMessage: 'Failed to load groups: $e'));
    }
  }

  Future<void> _onCreateGroup(
    CreateGroup event,
    Emitter<GroupState> emit,
  ) async {
    try {
      emit(
        GroupLoading(
          groups: state is GroupLoadSuccess
              ? (state as GroupLoadSuccess).groups
              : [],
        ),
      );

      // Add the group to Firestore
      final groupRef = await _firestore
          .collection('groups')
          .add(event.group.toMap());

      // Add group reference to user's groups subcollection
      await _firestore
          .collection('users')
          .doc(event.group.createdBy)
          .collection('groups')
          .doc(groupRef.id)
          .set({
            'groupId': groupRef.id,
            'joinedAt': FieldValue.serverTimestamp(),
            'isAdmin': true,
          });

      // Add group reference to each member's groups subcollection
      for (final memberId in event.group.memberIds) {
        if (memberId != event.group.createdBy) {
          await _firestore
              .collection('users')
              .doc(memberId)
              .collection('groups')
              .doc(groupRef.id)
              .set({
                'groupId': groupRef.id,
                'joinedAt': FieldValue.serverTimestamp(),
                'isAdmin': event.group.adminIds.contains(memberId),
              });
        }
      }

      // Reload groups
      add(LoadUserGroups(event.group.createdBy));

      emit(GroupOperationSuccess(message: 'Group created successfully'));
    } catch (e) {
      emit(GroupFailure(errorMessage: 'Failed to create group: $e'));
      rethrow;
    }
  }
}
