import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:study_sensei/features/friends/data/repositories/friend_repository_impl.dart';
import 'package:study_sensei/features/friends/presentation/bloc/friend_requests/friend_requests_bloc.dart';

class FriendRequestsScreen extends StatelessWidget {
  const FriendRequestsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Friend Requests'),
      ),
      body: BlocProvider(
        create: (context) => FriendRequestsBloc(
          friendRepository: FriendRepositoryImpl(),
        )..add(LoadFriendRequests()),
        child: BlocBuilder<FriendRequestsBloc, FriendRequestsState>(
          builder: (context, state) {
            if (state is FriendRequestsLoading) {
              return const Center(child: CircularProgressIndicator());
            } else if (state is FriendRequestsLoaded) {
              if (state.requests.isEmpty) {
                return const Center(child: Text('No pending friend requests'));
              }
              return ListView.builder(
                itemCount: state.requests.length,
                itemBuilder: (context, index) {
                  final request = state.requests[index];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Theme.of(
                        context,
                      ).primaryColor.withOpacity(0.2),
                      child: Text(
                        request.senderName.isNotEmpty
                            ? request.senderName[0].toUpperCase()
                            : '?',
                        style: TextStyle(
                          color: Theme.of(context).primaryColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    title: Text(request.senderName),
                    subtitle: Text(request.senderEmail),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.check_circle,
                            color: Colors.green,
                          ),
                          onPressed: () => _respondToRequest(
                            context,
                            request.requestId,
                            true,
                            request.senderId,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.cancel, color: Colors.red),
                          onPressed: () => _respondToRequest(
                            context,
                            request.requestId,
                            false,
                            request.senderId,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            } else if (state is FriendRequestsError) {
              return Center(child: Text('Error: ${state.message}'));
            }
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }

  void _respondToRequest(
    BuildContext context,
    String requestId,
    bool isAccepted,
    String senderId,
  ) {
    context.read<FriendRequestsBloc>().add(
      RespondToFriendRequest(
        requestId: requestId,
        isAccepted: isAccepted,
        senderId: senderId,
      ),
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isAccepted ? 'Friend request accepted' : 'Friend request declined',
        ),
      ),
    );
  }
}

// Add these to your friend_requests_bloc.dart file if not already present
/*
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
      // Handle error
    }
  }
}
*/
