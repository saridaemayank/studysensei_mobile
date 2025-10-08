import 'package:equatable/equatable.dart';
import 'package:study_sensei/features/groups/data/models/group_model.dart';

enum GroupStatus { initial, loading, success, failure }

class GroupState extends Equatable {
  final GroupStatus status;
  final List<Group> groups;
  final Group? selectedGroup;
  final String? error;
  final List<Group>? searchResults;

  const GroupState({
    this.status = GroupStatus.initial,
    this.groups = const [],
    this.selectedGroup,
    this.error,
    this.searchResults,
  });

  GroupState copyWith({
    GroupStatus? status,
    List<Group>? groups,
    Group? selectedGroup,
    String? error,
    List<Group>? searchResults,
  }) {
    return GroupState(
      status: status ?? this.status,
      groups: groups ?? this.groups,
      selectedGroup: selectedGroup ?? this.selectedGroup,
      error: error,
      searchResults: searchResults ?? this.searchResults,
    );
  }

  @override
  List<Object?> get props => [status, groups, selectedGroup, error, searchResults];

  bool get isLoading => status == GroupStatus.loading;
  bool get isSuccess => status == GroupStatus.success;
  bool get isFailure => status == GroupStatus.failure;
  bool get hasError => error != null;
  bool get hasSelectedGroup => selectedGroup != null;
  bool get hasSearchResults => searchResults?.isNotEmpty ?? false;
}

// Initial state
class GroupInitial extends GroupState {
  const GroupInitial() : super();
}

// Loading states
class GroupsLoading extends GroupState {
  const GroupsLoading() : super(status: GroupStatus.loading);
}

class GroupLoading extends GroupState {
  final List<Group> groups;
  final Group? selectedGroup;
  final List<Group>? searchResults;

  const GroupLoading({
    required this.groups,
    this.selectedGroup,
    this.searchResults,
  }) : super(
          status: GroupStatus.loading,
          groups: groups,
          selectedGroup: selectedGroup,
          searchResults: searchResults,
        );
}

// Success states
class GroupsLoadSuccess extends GroupState {
  const GroupsLoadSuccess(
    List<Group> groups, {
    Group? selectedGroup,
    List<Group>? searchResults,
  }) : super(
          status: GroupStatus.success,
          groups: groups,
          selectedGroup: selectedGroup,
          searchResults: searchResults,
        );

  @override
  List<Object?> get props => [groups, selectedGroup, searchResults];
}

class GroupLoadSuccess extends GroupState {
  const GroupLoadSuccess(
    Group group,
    List<Group> groups, {
    List<Group>? searchResults,
  }) : super(
          status: GroupStatus.success,
          groups: groups,
          selectedGroup: group,
          searchResults: searchResults,
        );

  @override
  List<Object?> get props => [groups, selectedGroup, searchResults];
}

class GroupOperationSuccess extends GroupState {
  final String message;

  const GroupOperationSuccess({
    required this.message,
    required List<Group> groups,
    Group? selectedGroup,
    List<Group>? searchResults,
  }) : super(
          status: GroupStatus.success,
          groups: groups,
          selectedGroup: selectedGroup,
          searchResults: searchResults,
        );

  @override
  List<Object?> get props => [message, groups, selectedGroup, searchResults];
}

// Failure states
class GroupFailure extends GroupState {
  final String errorMessage;

  const GroupFailure({
    required this.errorMessage,
    List<Group> groups = const [],
    Group? selectedGroup,
    List<Group>? searchResults,
  }) : super(
          status: GroupStatus.failure,
          error: errorMessage,
          groups: groups,
          selectedGroup: selectedGroup,
          searchResults: searchResults,
        );

  @override
  List<Object?> get props => [errorMessage, groups, selectedGroup, searchResults];
}

// Search states
class GroupSearchResults extends GroupState {
  final String query;
  
  const GroupSearchResults({
    required this.query,
    required List<Group> results,
    List<Group> groups = const [],
    Group? selectedGroup,
  }) : super(
          status: GroupStatus.success,
          searchResults: results,
          groups: groups,
          selectedGroup: selectedGroup,
        );
        
  @override
  List<Object?> get props => [query, groups, selectedGroup, searchResults];
}
