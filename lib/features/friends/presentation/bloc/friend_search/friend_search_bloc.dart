import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:study_sensei/features/friends/domain/repositories/friend_repository.dart';
import 'package:study_sensei/features/friends/data/models/user_model.dart';

// Events
abstract class FriendSearchEvent extends Equatable {
  const FriendSearchEvent();

  @override
  List<Object> get props => [];
}

class SearchUsers extends FriendSearchEvent {
  final String query;

  const SearchUsers(this.query);

  @override
  List<Object> get props => [query];
}

class LoadFriends extends FriendSearchEvent {
  const LoadFriends();

  @override
  List<Object> get props => [];
}

class RefreshFriends extends FriendSearchEvent {
  const RefreshFriends();

  @override
  List<Object> get props => [];
}

// States
abstract class FriendSearchState extends Equatable {
  const FriendSearchState();

  @override
  List<Object> get props => [];
}

class FriendSearchInitial extends FriendSearchState {}

class FriendSearchLoading extends FriendSearchState {}

class FriendSearchLoaded extends FriendSearchState {
  final List<UserModel> users;
  final List<UserModel> friends;
  final bool isSearching;

  const FriendSearchLoaded({
    this.users = const [],
    this.friends = const [],
    this.isSearching = false,
  });

  FriendSearchLoaded copyWith({
    List<UserModel>? users,
    List<UserModel>? friends,
    bool? isSearching,
  }) {
    return FriendSearchLoaded(
      users: users ?? this.users,
      friends: friends ?? this.friends,
      isSearching: isSearching ?? this.isSearching,
    );
  }

  @override
  List<Object> get props => [users, friends, isSearching];
}

class FriendSearchError extends FriendSearchState {
  final String message;

  const FriendSearchError(this.message);

  @override
  List<Object> get props => [message];
}

// BLoC
class FriendSearchBloc extends Bloc<FriendSearchEvent, FriendSearchState> {
  final FriendRepository friendRepository;

  FriendSearchBloc({required this.friendRepository}) : super(FriendSearchInitial()) {
    on<SearchUsers>(_onSearchUsers);
    on<LoadFriends>(_onLoadFriends);
    on<RefreshFriends>(_onRefreshFriends);
  }

  Future<void> _onSearchUsers(
    SearchUsers event,
    Emitter<FriendSearchState> emit,
  ) async {
    print('[FriendSearchBloc] Search query: "${event.query}"');
    
    if (event.query.trim().isEmpty) {
      print('[FriendSearchBloc] Empty query, clearing results');
      emit(const FriendSearchLoaded(users: []));
      return;
    }

    print('[FriendSearchBloc] Starting search...');
    emit(FriendSearchLoading());

    try {
      print('[FriendSearchBloc] Calling friendRepository.searchUsers()');
      final users = await friendRepository.searchUsers(event.query);
      print('[FriendSearchBloc] Search completed. Found ${users.length} users');
      
      if (users.isNotEmpty) {
        for (var user in users) {
          print('[FriendSearchBloc] Found user: ${user.name} (${user.email})');
        }
      } else {
        print('[FriendSearchBloc] No users found matching the query');
      }
      
      emit(FriendSearchLoaded(users: users, isSearching: true));
    } catch (e, stackTrace) {
      print('[FriendSearchBloc] Error searching users: $e');
      print('Stack trace: $stackTrace');
      emit(FriendSearchError('Failed to search users: $e'));
    }
  }

  Future<void> _onLoadFriends(
    LoadFriends event,
    Emitter<FriendSearchState> emit,
  ) async {
    emit(FriendSearchLoading());
    try {
      final friends = await friendRepository.getFriends();
      emit(FriendSearchLoaded(friends: friends));
    } catch (e) {
      emit(FriendSearchError('Failed to load friends'));
    }
  }

  Future<void> _onRefreshFriends(
    RefreshFriends event,
    Emitter<FriendSearchState> emit,
  ) async {
    if (state is FriendSearchLoaded) {
      try {
        final currentState = state as FriendSearchLoaded;
        final friends = await friendRepository.getFriends();
        emit(currentState.copyWith(friends: friends));
      } catch (e) {
        emit(FriendSearchError('Failed to refresh friends'));
      }
    }
  }
}
