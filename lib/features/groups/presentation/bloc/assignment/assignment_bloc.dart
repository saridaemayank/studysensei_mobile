import 'dart:async';
import 'package:bloc/bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';
import 'package:study_sensei/features/groups/data/models/group_assignment_model.dart';

// Events
abstract class AssignmentEvent extends Equatable {
  const AssignmentEvent();
}

class UpdateAssignments extends AssignmentEvent {
  final List<GroupAssignment> assignments;
  
  const UpdateAssignments(this.assignments);
  
  @override
  List<Object> get props => [assignments];
}

class CreateAssignment extends AssignmentEvent {
  final GroupAssignment assignment;
  final String groupId;

  const CreateAssignment(this.assignment, this.groupId);

  @override
  List<Object?> get props => [assignment, groupId];
}

class LoadAssignments extends AssignmentEvent {
  final String groupId;

  const LoadAssignments(this.groupId);

  @override
  List<Object?> get props => [groupId];
}

class CompleteAssignment extends AssignmentEvent {
  final String assignmentId;
  final String groupId;
  final String userId;
  final bool isCompleted;

  const CompleteAssignment({
    required this.assignmentId,
    required this.groupId,
    required this.userId,
    this.isCompleted = true,
  });

  @override
  List<Object?> get props => [assignmentId, groupId, userId, isCompleted];
}

// States
abstract class AssignmentState extends Equatable {
  const AssignmentState();
}

class AssignmentInitial extends AssignmentState {
  @override
  List<Object?> get props => [];
}

class AssignmentLoading extends AssignmentState {
  @override
  List<Object?> get props => [];
}

class AssignmentLoadSuccess extends AssignmentState {
  final List<GroupAssignment> assignments;

  const AssignmentLoadSuccess(this.assignments);

  @override
  List<Object> get props => [assignments];
}

class AssignmentOperationSuccess extends AssignmentState {
  @override
  List<Object?> get props => [];
}

class AssignmentError extends AssignmentState {
  final String message;

  const AssignmentError(this.message);

  @override
  List<Object?> get props => [message];
}

// BLoC
class AssignmentBloc extends Bloc<AssignmentEvent, AssignmentState> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  StreamSubscription? _subscription;
  final Map<String, List<GroupAssignment>> _assignmentsCache = {};

  AssignmentBloc() : super(AssignmentLoading()) {
    print('AssignmentBloc - Initialized');
    on<CreateAssignment>(_onCreateAssignment);
    on<LoadAssignments>(_onLoadAssignments);
    on<UpdateAssignments>((event, emit) {
      emit(AssignmentLoadSuccess(event.assignments));
    });
    on<CompleteAssignment>(_onCompleteAssignment);
    
    // Log state changes
    stream.listen((state) {
      if (state is AssignmentError) {
        print('AssignmentBloc - State changed to Error: ${state.message}');
      } else if (state is AssignmentLoadSuccess) {
        print('AssignmentBloc - State changed to LoadSuccess with ${state.assignments.length} assignments');
      } else if (state is AssignmentLoading) {
        print('AssignmentBloc - State changed to Loading');
      }
    });
  }

  Future<void> _onCreateAssignment(
    CreateAssignment event,
    Emitter<AssignmentState> emit,
  ) async {
    try {
      final assignment = event.assignment;
      final docRef = _firestore
          .collection('groups')
          .doc(event.groupId)
          .collection('assignments')
          .doc(assignment.id);

      await docRef.set(assignment.toMap());
      
      // Update local cache
      final assignments = _assignmentsCache[event.groupId] ?? [];
      _assignmentsCache[event.groupId] = [assignment, ...assignments];
      
      emit(AssignmentOperationSuccess());
      emit(AssignmentLoadSuccess(_assignmentsCache[event.groupId]!));
    } catch (e) {
      emit(AssignmentError('Failed to create assignment: $e'));
    }
  }

  Future<void> _onCompleteAssignment(
    CompleteAssignment event,
    Emitter<AssignmentState> emit,
  ) async {
    try {
      final assignmentRef = _firestore
          .collection('groups')
          .doc(event.groupId)
          .collection('assignments')
          .doc(event.assignmentId);

      // Update the UI optimistically
      final currentState = state;
      if (currentState is AssignmentLoadSuccess) {
        final updatedAssignments = currentState.assignments.map((a) {
          if (a.id == event.assignmentId) {
            return a.copyWithUserCompletion(event.userId, event.isCompleted);
          }
          return a;
        }).toList();
        
        emit(AssignmentLoadSuccess(updatedAssignments));
      }

      // Update Firestore
      await _firestore.runTransaction((transaction) async {
        final doc = await transaction.get(assignmentRef);
        if (!doc.exists) {
          throw Exception('Assignment not found');
        }

        final data = doc.data()!;
        final userCompletion = Map<String, bool>.from(data['userCompletion'] ?? {});
        userCompletion[event.userId] = event.isCompleted;
        
        print('Updating completion for user ${event.userId} to ${event.isCompleted}');
        
        // Get the list of all assigned users
        final assignedTo = List<String>.from(data['assignedTo'] ?? []);
        
        // Check if all assigned users have completed the assignment
        final allCompleted = assignedTo.isNotEmpty && 
            assignedTo.every((userId) => userCompletion[userId] == true);
            
        // Update the status based on completion
        String newStatus = 'inProgress';
        if (allCompleted) {
          newStatus = 'completed';
        } else if (assignedTo.any((userId) => userCompletion[userId] == true)) {
          newStatus = 'inProgress';
        } else {
          newStatus = 'notStarted';
        }

        // Prepare update data
        final updateData = {
          'userCompletion': userCompletion,
          'status': newStatus,
          'updatedAt': FieldValue.serverTimestamp(),
        };

        print('Updating assignment with data: $updateData');
        transaction.update(assignmentRef, updateData);
      });

      // Reload the latest state
      add(LoadAssignments(event.groupId));
    } catch (e) {
      // Revert on error
      if (state is AssignmentLoadSuccess) {
        emit(AssignmentLoadSuccess((state as AssignmentLoadSuccess).assignments));
      }
      emit(AssignmentError('Failed to update assignment: $e'));
    }
  }

  Future<void> _onLoadAssignments(
    LoadAssignments event,
    Emitter<AssignmentState> emit,
  ) async {
    print('AssignmentBloc - Handling LoadAssignments for group ${event.groupId}');
    
    // Only emit loading state if we don't have cached data
    if (_assignmentsCache[event.groupId] == null) {
      emit(AssignmentLoading());
    }

    try {
      // Cancel any existing subscription
      await _subscription?.cancel();
      
      // Initial load
      final querySnapshot = await _firestore
          .collection('groups')
          .doc(event.groupId)
          .collection('assignments')
          .orderBy('createdAt', descending: true)
          .get();

      final assignments = querySnapshot.docs
          .map((doc) => GroupAssignment.fromMap(doc.id, doc.data()))
          .toList();

      _assignmentsCache[event.groupId] = assignments;
      emit(AssignmentLoadSuccess(assignments));
      
      // Set up real-time updates
      _subscription = _firestore
          .collection('groups')
          .doc(event.groupId)
          .collection('assignments')
          .orderBy('createdAt', descending: true)
          .snapshots()
          .listen((snapshot) {
            if (isClosed) return;
            
            try {
              final updatedAssignments = snapshot.docs
                  .map((doc) => GroupAssignment.fromMap(doc.id, doc.data()))
                  .toList();
                  
              _assignmentsCache[event.groupId] = updatedAssignments;
              add(UpdateAssignments(updatedAssignments));
            } catch (e) {
              print('AssignmentBloc - Error parsing assignments: $e');
              if (!isClosed) {
                emit(AssignmentError('Error updating assignments: $e'));
              }
            }
          }, onError: (e) {
            print('AssignmentBloc - Firestore error: $e');
            if (!isClosed) {
              emit(AssignmentError('Failed to update assignments: $e'));
            }
          });
      
    } catch (e) {
      print('AssignmentBloc - Error in _onLoadAssignments: $e');
      if (!isClosed) {
        emit(AssignmentError('Failed to load assignments: $e'));
      }
    }
  }

  @override
  Future<void> close() {
    _subscription?.cancel();
    return super.close();
  }
}
