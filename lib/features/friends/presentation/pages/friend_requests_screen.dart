import 'package:flutter/material.dart';
import 'package:study_sensei/core/theme/app_colors.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:study_sensei/features/friends/data/repositories/friend_repository_impl.dart';
import 'package:study_sensei/features/friends/presentation/bloc/friend_requests/friend_requests_bloc.dart';

class FriendRequestsScreen extends StatelessWidget {
  const FriendRequestsScreen({super.key});

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
                      ).primaryColor.withValues(alpha: 0.2),
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
                    title: Text(request.senderName,
                        maxLines: 2, overflow: TextOverflow.ellipsis),
                    subtitle: Text(request.senderEmail,
                        maxLines: 2, overflow: TextOverflow.ellipsis),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'Accept request',
                          icon: const Icon(
                            Icons.check_circle,
                            color: AppColors.success,
                          ),
                          onPressed: () => _respondToRequest(
                            context,
                            request.requestId,
                            true,
                            request.senderId,
                          ),
                        ),
                        IconButton(
                          tooltip: 'Decline request',
                          icon:
                              const Icon(Icons.cancel, color: AppColors.error),
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
              return Center(
                  child: const Text(
                      "Couldn't load this right now. Please try again."));
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
