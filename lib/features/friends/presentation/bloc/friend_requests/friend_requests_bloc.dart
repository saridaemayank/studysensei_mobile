import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:study_sensei/features/friends/data/models/friend_request_model.dart';
import 'package:study_sensei/features/friends/domain/repositories/friend_repository.dart';

// Events
abstract class FriendRequestsEvent extends Equatable {
  const FriendRequestsEvent();
  @override
  List<Object> get props => [];
}

class LoadFriendRequests extends FriendRequestsEvent {}

class RespondToFriendRequest extends FriendRequestsEvent {
  final String requestId;
  final bool isAccepted;
  final String senderId;

  const RespondToFriendRequest({
    required this.requestId,
    required this.isAccepted,
    required this.senderId,
  });

  @override
  List<Object> get props => [requestId, isAccepted, senderId];
}

// States
abstract class FriendRequestsState extends Equatable {
  const FriendRequestsState();
  @override
  List<Object> get props => [];
}

class FriendRequestsLoading extends FriendRequestsState {}

class FriendRequestsLoaded extends FriendRequestsState {
  final List<FriendRequestModel> requests;
  const FriendRequestsLoaded(this.requests);
  @override
  List<Object> get props => [requests];
}

class FriendRequestsError extends FriendRequestsState {
  final String message;
  const FriendRequestsError(this.message);
  @override
  List<Object> get props => [message];
}

class FriendRequestsBloc extends Bloc<FriendRequestsEvent, FriendRequestsState> {
  final FriendRepository friendRepository;

  FriendRequestsBloc({required this.friendRepository}) : super(FriendRequestsLoading()) {
    on<LoadFriendRequests>(_onLoadFriendRequests);
    on<RespondToFriendRequest>(_onRespondToFriendRequest);
  }

  Future<void> _onLoadFriendRequests(
    LoadFriendRequests event,
    Emitter<FriendRequestsState> emit,
  ) async {
    emit(FriendRequestsLoading());
    try {
      final requests = await friendRepository.getFriendRequests();
      emit(FriendRequestsLoaded(requests));
    } catch (e) {
      emit(FriendRequestsError('Failed to load friend requests'));
    }
  }

  Future<void> _onRespondToFriendRequest(
    RespondToFriendRequest event,
    Emitter<FriendRequestsState> emit,
  ) async {
    try {
      await friendRepository.respondToFriendRequest(
        requestId: event.requestId,
        isAccepted: event.isAccepted,
        senderId: event.senderId,
      );
      // Reload requests after responding
      add(LoadFriendRequests());
    } catch (e) {
      emit(FriendRequestsError('Failed to process friend request'));
    }
  }
}
