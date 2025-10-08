import 'dart:async';
import 'package:bloc/bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';
import 'package:study_sensei/features/groups/data/models/group_model.dart';

// Events
abstract class GroupEvent extends Equatable {
  const GroupEvent();
  @override
  List<Object> get props => [];
}

class CreateGroup extends GroupEvent {
  final Group group;
  
  const CreateGroup({required this.group});
  
  @override
  List<Object> get props => [group];
}

// States
abstract class GroupState extends Equatable {
  const GroupState();
  
  @override
  List<Object> get props => [];
}

class GroupInitial extends GroupState {}

class GroupLoading extends GroupState {}

class GroupOperationSuccess extends GroupState {
  final Group group;
  
  const GroupOperationSuccess(this.group);
  
  @override
  List<Object> get props => [group];
}

class GroupFailure extends GroupState {
  final String errorMessage;
  
  const GroupFailure(this.errorMessage);
  
  @override
  List<Object> get props => [errorMessage];
}

// Bloc
class GroupBloc extends Bloc<GroupEvent, GroupState> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  GroupBloc() : super(GroupInitial()) {
    on<CreateGroup>(_onCreateGroup);
  }
  
  Future<void> _onCreateGroup(CreateGroup event, Emitter<GroupState> emit) async {
    try {
      emit(GroupLoading());
      
      // Create a batch to ensure atomic operations
      final batch = _firestore.batch();
      final groupsRef = _firestore.collection('groups');
      
      // Add the group to Firestore
      final groupData = event.group.toMap();
      final groupRef = groupsRef.doc();
      batch.set(groupRef, groupData);
      
      // Add group reference to each member's groups subcollection
      for (final memberId in event.group.memberIds) {
        final userGroupsRef = _firestore
            .collection('users')
            .doc(memberId)
            .collection('groups')
            .doc(groupRef.id);
            
        batch.set(userGroupsRef, {
          'groupId': groupRef.id,
          'joinedAt': FieldValue.serverTimestamp(),
          'isAdmin': event.group.adminIds.contains(memberId),
        });
      }
      
      // Commit the batch
      await batch.commit();
      
      // Get the created group with its ID
      final createdGroup = event.group.copyWith(id: groupRef.id);
      
      emit(GroupOperationSuccess(createdGroup));
    } catch (e, stackTrace) {
      print('Error creating group: $e');
      print('Stack trace: $stackTrace');
      emit(GroupFailure('Failed to create group: ${e.toString()}'));
    }
  }
}
