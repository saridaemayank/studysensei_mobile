import 'dart:async';
import 'package:bloc/bloc.dart';
import 'package:dartz/dartz.dart';
import 'package:study_sensei/core/error/failures.dart';
import 'package:study_sensei/features/groups/data/models/group_model.dart';
import 'package:study_sensei/features/groups/domain/repositories/group_repository.dart';
import 'group_event.dart';
import 'group_state.dart';

class GroupBloc extends Bloc<GroupEvent, GroupState> {
  final GroupRepository groupRepository;
  StreamSubscription? _groupsSubscription;

  GroupBloc({required this.groupRepository}) : super(const GroupInitial()) {
    on<LoadUserGroups>(_onLoadUserGroups);
    on<LoadGroup>(_onLoadGroup);
    on<CreateGroup>(_onCreateGroup);
    on<UpdateGroup>(_onUpdateGroup);
    on<DeleteGroup>(_onDeleteGroup);
    on<AddGroupMember>(_onAddGroupMember);
    on<RemoveGroupMember>(_onRemoveGroupMember);
    on<AddGroupAdmin>(_onAddGroupAdmin);
    on<RemoveGroupAdmin>(_onRemoveGroupAdmin);
    on<InviteToGroup>(_onInviteToGroup);
    on<CancelInvite>(_onCancelInvite);
    on<SearchGroups>(_onSearchGroups);
  }

  @override
  Future<void> close() {
    _groupsSubscription?.cancel();
    return super.close();
  }

  // Event Handlers
  Future<void> _onLoadUserGroups(
    LoadUserGroups event,
    Emitter<GroupState> emit,
  ) async {
    emit(
      GroupLoading(
        groups: state.groups,
        selectedGroup: state.selectedGroup,
        searchResults: state.searchResults,
      ),
    );

    _groupsSubscription?.cancel();
    _groupsSubscription = groupRepository
        .getUserGroups(event.userId)
        .listen(
          (groups) => emit(
            GroupsLoadSuccess(
              groups,
              selectedGroup: state.selectedGroup,
              searchResults: state.searchResults,
            ),
          ),
          onError: (error) => emit(
            GroupFailure(
              errorMessage: error.toString(),
              groups: state.groups,
              selectedGroup: state.selectedGroup,
              searchResults: state.searchResults,
            ),
          ),
        );
  }

  Future<void> _onLoadGroup(LoadGroup event, Emitter<GroupState> emit) async {
    final currentState = state;
    emit(
      GroupLoading(
        groups: currentState.groups,
        selectedGroup: currentState.selectedGroup,
        searchResults: currentState.searchResults,
      ),
    );

    final result = await groupRepository.getGroup(event.groupId);
    result.fold(
      (failure) => emit(
        GroupFailure(
          errorMessage: failure.message,
          groups: currentState.groups,
          selectedGroup: currentState.selectedGroup,
          searchResults: currentState.searchResults,
        ),
      ),
      (group) => emit(
        GroupLoadSuccess(
          group,
          currentState.groups,
          searchResults: currentState.searchResults,
        ),
      ),
    );
  }

  Future<void> _onCreateGroup(
    CreateGroup event,
    Emitter<GroupState> emit,
  ) async {
    final currentState = state;
    emit(
      GroupLoading(
        groups: currentState.groups,
        selectedGroup: currentState.selectedGroup,
        searchResults: currentState.searchResults,
      ),
    );

    try {
      final result = await groupRepository.createGroup(event.group);
      result.fold(
        (failure) => emit(
          GroupFailure(
            errorMessage: failure.message,
            groups: currentState.groups,
            selectedGroup: currentState.selectedGroup,
            searchResults: currentState.searchResults,
          ),
        ),
        (group) {
          final updatedGroups = List<Group>.from(currentState.groups)
            ..add(group);
          emit(
            GroupOperationSuccess(
              message: 'Group created successfully',
              groups: updatedGroups,
              selectedGroup: group,
              searchResults: currentState.searchResults,
            ),
          );
        },
      );
    } catch (e) {
      emit(
        GroupFailure(
          errorMessage: 'Failed to create group: $e',
          groups: currentState.groups,
          selectedGroup: currentState.selectedGroup,
          searchResults: currentState.searchResults,
        ),
      );
    }
  }

  Future<void> _onUpdateGroup(
    UpdateGroup event,
    Emitter<GroupState> emit,
  ) async {
    final currentState = state;
    emit(
      GroupLoading(
        groups: currentState.groups,
        selectedGroup: currentState.selectedGroup,
        searchResults: currentState.searchResults,
      ),
    );

    try {
      final result = await groupRepository.updateGroup(event.group);
      result.fold(
        (failure) => emit(
          GroupFailure(
            errorMessage: failure.message,
            groups: currentState.groups,
            selectedGroup: currentState.selectedGroup,
            searchResults: currentState.searchResults,
          ),
        ),
        (_) {
          final updatedGroups = currentState.groups.map((g) {
            return g.id == event.group.id ? event.group : g;
          }).toList();

          final updatedSelectedGroup = 
              currentState.selectedGroup?.id == event.group.id 
                  ? event.group 
                  : currentState.selectedGroup;

          emit(
            GroupOperationSuccess(
              message: 'Group updated successfully',
              groups: updatedGroups,
              selectedGroup: updatedSelectedGroup,
              searchResults: currentState.searchResults,
            ),
          );
        },
      );
    } catch (e) {
      emit(
        GroupFailure(
          errorMessage: 'Failed to update group: $e',
          groups: currentState.groups,
          selectedGroup: currentState.selectedGroup,
          searchResults: currentState.searchResults,
        ),
      );
    }
  }

  Future<void> _onDeleteGroup(
    DeleteGroup event,
    Emitter<GroupState> emit,
  ) async {
    final currentState = state;
    emit(
      GroupLoading(
        groups: currentState.groups,
        selectedGroup: currentState.selectedGroup,
        searchResults: currentState.searchResults,
      ),
    );

    try {
      final result = await groupRepository.deleteGroup(event.groupId);
      result.fold(
        (failure) => emit(
          GroupFailure(
            errorMessage: failure.message,
            groups: currentState.groups,
            selectedGroup: currentState.selectedGroup,
            searchResults: currentState.searchResults,
          ),
        ),
        (_) {
          final updatedGroups = currentState.groups
              .where((group) => group.id != event.groupId)
              .toList();
          
          final updatedSelectedGroup = 
              currentState.selectedGroup?.id == event.groupId
                  ? null
                  : currentState.selectedGroup;

          emit(
            GroupOperationSuccess(
              message: 'Group deleted successfully',
              groups: updatedGroups,
              selectedGroup: updatedSelectedGroup,
              searchResults: currentState.searchResults,
            ),
          );
        },
      );
    } catch (e) {
      emit(
        GroupFailure(
          errorMessage: 'Failed to delete group: $e',
          groups: currentState.groups,
          selectedGroup: currentState.selectedGroup,
          searchResults: currentState.searchResults,
        ),
      );
    }
  }

  Future<void> _onAddGroupMember(
    AddGroupMember event,
    Emitter<GroupState> emit,
  ) async {
    final currentState = state;
    emit(
      GroupLoading(
        groups: currentState.groups,
        selectedGroup: currentState.selectedGroup,
        searchResults: currentState.searchResults,
      ),
    );

    try {
      final result = await groupRepository.addGroupMember(
        event.groupId,
        event.userId,
      );

      await _handleMemberOperationResult(
        result,
        'Member added successfully',
        emit,
      );
    } catch (e) {
      emit(
        GroupFailure(
          errorMessage: 'Failed to add group member: $e',
          groups: currentState.groups,
          selectedGroup: currentState.selectedGroup,
          searchResults: currentState.searchResults,
        ),
      );
    }
  }

  Future<void> _onRemoveGroupMember(
    RemoveGroupMember event,
    Emitter<GroupState> emit,
  ) async {
    final currentState = state;
    emit(
      GroupLoading(
        groups: currentState.groups,
        selectedGroup: currentState.selectedGroup,
        searchResults: currentState.searchResults,
      ),
    );

    try {
      final result = await groupRepository.removeGroupMember(
        event.groupId,
        event.userId,
      );

      await _handleMemberOperationResult(
        result,
        'Member removed successfully',
        emit,
      );
    } catch (e) {
      emit(
        GroupFailure(
          errorMessage: 'Failed to remove group member: $e',
          groups: currentState.groups,
          selectedGroup: currentState.selectedGroup,
          searchResults: currentState.searchResults,
        ),
      );
    }
  }

  Future<void> _onAddGroupAdmin(
    AddGroupAdmin event,
    Emitter<GroupState> emit,
  ) async {
    final currentState = state;
    emit(
      GroupLoading(
        groups: currentState.groups,
        selectedGroup: currentState.selectedGroup,
        searchResults: currentState.searchResults,
      ),
    );

    try {
      final result = await groupRepository.addGroupAdmin(
        event.groupId,
        event.userId,
      );

      await _handleMemberOperationResult(
        result,
        'Admin added successfully',
        emit,
      );
    } catch (e) {
      emit(
        GroupFailure(
          errorMessage: 'Failed to add group admin: $e',
          groups: currentState.groups,
          selectedGroup: currentState.selectedGroup,
          searchResults: currentState.searchResults,
        ),
      );
    }
  }

  Future<void> _onRemoveGroupAdmin(
    RemoveGroupAdmin event,
    Emitter<GroupState> emit,
  ) async {
    final currentState = state;
    emit(
      GroupLoading(
        groups: currentState.groups,
        selectedGroup: currentState.selectedGroup,
        searchResults: currentState.searchResults,
      ),
    );

    try {
      final result = await groupRepository.removeGroupAdmin(
        event.groupId,
        event.userId,
      );

      await _handleMemberOperationResult(
        result,
        'Admin removed successfully',
        emit,
      );
    } catch (e) {
      emit(
        GroupFailure(
          errorMessage: 'Failed to remove group admin: $e',
          groups: currentState.groups,
          selectedGroup: currentState.selectedGroup,
          searchResults: currentState.searchResults,
        ),
      );
    }
  }

  Future<void> _onInviteToGroup(
    InviteToGroup event,
    Emitter<GroupState> emit,
  ) async {
    final currentState = state;
    emit(
      GroupLoading(
        groups: currentState.groups,
        selectedGroup: currentState.selectedGroup,
        searchResults: currentState.searchResults,
      ),
    );

    try {
      final result = await groupRepository.inviteToGroup(
        event.groupId,
        event.email,
      );

      await _handleMemberOperationResult(
        result,
        'Invitation sent successfully',
        emit,
      );
    } catch (e) {
      emit(
        GroupFailure(
          errorMessage: 'Failed to send invitation: $e',
          groups: currentState.groups,
          selectedGroup: currentState.selectedGroup,
          searchResults: currentState.searchResults,
        ),
      );
    }
  }

  Future<void> _onCancelInvite(
    CancelInvite event,
    Emitter<GroupState> emit,
  ) async {
    final currentState = state;
    emit(
      GroupLoading(
        groups: currentState.groups,
        selectedGroup: currentState.selectedGroup,
        searchResults: currentState.searchResults,
      ),
    );

    try {
      final result = await groupRepository.cancelInvite(
        event.groupId,
        event.email,
      );

      await _handleMemberOperationResult(
        result,
        'Invitation cancelled successfully',
        emit,
      );
    } catch (e) {
      emit(
        GroupFailure(
          errorMessage: 'Failed to cancel invitation: $e',
          groups: currentState.groups,
          selectedGroup: currentState.selectedGroup,
          searchResults: currentState.searchResults,
        ),
      );
    }
  }

  Future<void> _onSearchGroups(
    SearchGroups event,
    Emitter<GroupState> emit,
  ) async {
    final currentState = state;
    
    if (event.query.isEmpty) {
      emit(
        GroupSearchResults(
          query: event.query,
          results: currentState.searchResults ?? [],
          groups: currentState.groups,
          selectedGroup: currentState.selectedGroup,
        ),
      );
      return;
    }

    try {
      // Listen to the stream of search results
      final subscription = groupRepository.searchGroups(event.query).listen(
        (results) {
          emit(
            GroupSearchResults(
              query: event.query,
              results: results,
              groups: currentState.groups,
              selectedGroup: currentState.selectedGroup,
            ),
          );
        },
        onError: (e) {
          emit(
            GroupFailure(
              errorMessage: 'Failed to search groups: $e',
              groups: currentState.groups,
              selectedGroup: currentState.selectedGroup,
              searchResults: currentState.searchResults,
            ),
          );
        },
      );
      
      // Cancel the subscription when the method is called again
      await subscription.asFuture();
      await subscription.cancel();
    } catch (e) {
      emit(
        GroupSearchResults(
          query: event.query,
          results: [],
          groups: currentState.groups,
          selectedGroup: currentState.selectedGroup,
        ),
      );
      emit(
        GroupFailure(
          errorMessage: 'Failed to search groups: $e',
          groups: currentState.groups,
          selectedGroup: currentState.selectedGroup,
          searchResults: currentState.searchResults,
        ),
      );
    }
  }

  // Helper method to handle member operation results
  Future<void> _handleMemberOperationResult(
    Either<Failure, void> result,
    String successMessage,
    Emitter<GroupState> emit,
  ) async {
    final currentState = state;
    
    // Handle the result without awaiting the fold directly
    result.fold(
      (failure) {
        emit(
          GroupFailure(
            errorMessage: failure.message,
            groups: currentState.groups,
            selectedGroup: currentState.selectedGroup,
            searchResults: currentState.searchResults,
          ),
        );
      },
      (_) async {
        // After a successful operation, we need to refresh the current group
        // to get the latest data from the server
        if (currentState.selectedGroup != null) {
          try {
            final groupResult = await groupRepository.getGroup(currentState.selectedGroup!.id);
            groupResult.fold(
              (failure) => emit(
                GroupFailure(
                  errorMessage: 'Operation successful but failed to refresh group: ${failure.message}',
                  groups: currentState.groups,
                  selectedGroup: currentState.selectedGroup,
                  searchResults: currentState.searchResults,
                ),
              ),
              (updatedGroup) {
                // Update the selected group in the groups list
                final updatedGroups = currentState.groups.map((g) {
                  return g.id == updatedGroup.id ? updatedGroup : g;
                }).toList();
                
                emit(
                  GroupOperationSuccess(
                    message: successMessage,
                    groups: updatedGroups,
                    selectedGroup: updatedGroup,
                    searchResults: currentState.searchResults,
                  ),
                );
              },
            );
          } catch (e) {
            emit(
              GroupFailure(
                errorMessage: 'Operation successful but failed to refresh group: $e',
                groups: currentState.groups,
                selectedGroup: currentState.selectedGroup,
                searchResults: currentState.searchResults,
              ),
            );
          }
        } else {
          // If no group is selected, just emit success with current state
          emit(
            GroupOperationSuccess(
              message: successMessage,
              groups: currentState.groups,
              selectedGroup: currentState.selectedGroup,
              searchResults: currentState.searchResults,
            ),
          );
        }
      },
    );
  }
}
