import 'package:equatable/equatable.dart';
import 'package:study_sensei/features/friends/data/models/friend_model.dart';

abstract class FriendState extends Equatable {
  const FriendState();

  @override
  List<Object?> get props => [];
}

class FriendInitial extends FriendState {}

class FriendLoadInProgress extends FriendState {}

class FriendsLoadSuccess extends FriendState {
  final List<Friend> friends;

  const FriendsLoadSuccess(this.friends);

  @override
  List<Object?> get props => [friends];
}

class FriendOperationFailure extends FriendState {
  final String message;

  const FriendOperationFailure(this.message);

  @override
  List<Object?> get props => [message];
}
