import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:study_sensei/features/friends/presentation/bloc/friend_search/friend_search_bloc.dart';
import 'package:study_sensei/features/friends/data/repositories/friend_repository_impl.dart';
import 'package:study_sensei/features/friends/data/models/user_model.dart';
import 'package:study_sensei/features/friends/presentation/widgets/user_list_tile.dart';
import 'package:study_sensei/features/friends/presentation/pages/friend_detail_screen.dart';

class FriendSearchScreen extends StatefulWidget {
  final bool showAppBar;
  
  const FriendSearchScreen({
    Key? key,
    this.showAppBar = true,
  }) : super(key: key);

  @override
  _FriendSearchScreenState createState() => _FriendSearchScreenState();
}

class _FriendSearchScreenState extends State<FriendSearchScreen>
    with WidgetsBindingObserver {
  final _searchController = TextEditingController();
  late final FriendSearchBloc _friendSearchBloc;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _friendSearchBloc = FriendSearchBloc(
      friendRepository: FriendRepositoryImpl(),
    );
    // Load friends when the screen initializes
    _friendSearchBloc.add(const LoadFriends());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      // Refresh friends list when the app comes back to the foreground
      _friendSearchBloc.add(const RefreshFriends());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _searchController.dispose();
    _friendSearchBloc.close();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    print('Search query: $query');
    if (query.length >= 2) {
      // Only search if query is at least 2 characters
      _friendSearchBloc.add(SearchUsers(query));
    } else if (query.isEmpty) {
      // Clear search results and show friends list
      _friendSearchBloc.add(const LoadFriends());
    }
  }

  @override
  Widget build(BuildContext context) {
    print('Building FriendSearchScreen');
    return Scaffold(
      appBar: widget.showAppBar
          ? AppBar(
              surfaceTintColor: Colors.transparent,
              backgroundColor: Colors.orange[100],
              elevation: 0,
              title: const Text(
                'Add Friends',
                style: TextStyle(
                  fontFamily: 'DancingScript',
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            )
          : null,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 16.0),
            child: TextField(
              controller: _searchController,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Search by name or email',
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey[200],
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                hintStyle: TextStyle(color: Colors.grey[600]),
              ),
              onChanged: _onSearchChanged,
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: BlocBuilder<FriendSearchBloc, FriendSearchState>(
              bloc: _friendSearchBloc,
              builder: (context, state) {
                if (state is FriendSearchInitial) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (state is FriendSearchLoading) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (state is FriendSearchError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text('Error: ${state.message}'),
                    ),
                  );
                }

                if (state is FriendSearchLoaded) {
                  // Show search results if searching
                  if (state.isSearching) {
                    if (state.users.isEmpty) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Text(
                            'No users found. Try a different search query.',
                          ),
                        ),
                      );
                    }

                    return ListView.builder(
                      itemCount: state.users.length,
                      itemBuilder: (context, index) {
                        final user = state.users[index];
                        return UserListTile(
                          user: user,
                          onAddFriend: () => _sendFriendRequest(user.id),
                        );
                      },
                    );
                  }

                  // Show friends list when not searching
                  return _buildFriendsList(state.friends);
                }

                return const SizedBox.shrink();
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _sendFriendRequest(String userId) async {
    try {
      print('Sending friend request to user ID: $userId');
      final repository = FriendRepositoryImpl();
      await repository.sendFriendRequest(userId);
      print('Friend request sent successfully');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Friend request sent')));
      }
    } catch (e, stackTrace) {
      print('Error sending friend request: $e');
      print('Stack trace: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
      }
    }
  }

  Widget _buildFriendsList(List<UserModel> friends) {
    if (friends.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Text(
            'You have no friends yet. Search for friends to add them!',
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 16.0, top: 8.0, bottom: 8.0),
          child: Text(
            'Your Friends',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: friends.length,
            itemBuilder: (context, index) {
              final friend = friends[index];
              return ListTile(
                leading: _buildFriendAvatar(friend),
                title: Text(friend.name),
                subtitle: Text(friend.email),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => FriendDetailScreen(friend: friend),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFriendAvatar(UserModel friend) {
    final theme = Theme.of(context);
    final photoUrl = friend.photoUrl;
    if (photoUrl != null && photoUrl.isNotEmpty) {
      return CircleAvatar(
        backgroundImage: NetworkImage(photoUrl),
        backgroundColor: Colors.transparent,
      );
    }
    return CircleAvatar(
      backgroundColor: theme.primaryColor,
      child: Text(
        friend.name.isNotEmpty ? friend.name[0].toUpperCase() : '?',
        style: const TextStyle(color: Colors.white),
      ),
    );
  }
}
