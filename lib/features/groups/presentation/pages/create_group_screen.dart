import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:study_sensei/features/friends/data/models/friend_model.dart';
import 'package:study_sensei/features/friends/presentation/bloc/friend_bloc.dart';
import 'package:study_sensei/features/friends/presentation/bloc/friend_event.dart';
import 'package:study_sensei/features/friends/presentation/bloc/friend_state.dart';
import 'package:study_sensei/features/groups/data/enums/group_privacy.dart';
import 'package:study_sensei/features/groups/data/models/group_model.dart';
import 'package:study_sensei/features/groups/presentation/bloc/group_bloc.dart';

class CreateGroupScreen extends StatefulWidget {
  final String userId;
  final Function(Group)? onGroupCreated;

  const CreateGroupScreen({
    super.key,
    required this.userId,
    this.onGroupCreated,
  });

  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  bool _isSubmitting = false;
  final List<String> _selectedMembers = [];
  List<Friend> _friends = [];
  String? _selectedFriendId;

  @override
  void initState() {
    super.initState();
    print('Initializing CreateGroupScreen with user ID: ${widget.userId}');

    // Load friends when the screen initializes
    final friendBloc = context.read<FriendBloc>();

    // Check if we already have friends loaded
    if (friendBloc.state is! FriendsLoadSuccess) {
      print('No friends loaded yet, dispatching LoadFriends event');
      friendBloc.add(LoadFriends());
    } else {
      // If friends are already loaded, update the local state
      final state = friendBloc.state as FriendsLoadSuccess;
      print('Friends already loaded: ${state.friends.length} friends');
      setState(() {
        _friends = state.friends;
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _addSelectedFriend() {
    if (_selectedFriendId != null &&
        !_selectedMembers.contains(_selectedFriendId) &&
        _friends.any((f) => f.id == _selectedFriendId)) {
      setState(() {
        _selectedMembers.add(_selectedFriendId!);
        _selectedFriendId = null; // Reset the dropdown
      });
    }
  }

  Future<void> _createGroup() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    // Include current user as admin and member
    final memberIds = List<String>.from(_selectedMembers)..add(widget.userId);

    final group = Group(
      id: '', // Will be set by Firestore
      name: _nameController.text.trim(),
      description: _descriptionController.text.trim(),
      createdBy: widget.userId,
      createdAt: DateTime.now(),
      privacy: GroupPrivacy.private,
      adminIds: [widget.userId],
      memberIds: memberIds,
    );

    // Dispatch the event to create the group
    if (!mounted) return;
    context.read<GroupBloc>().add(CreateGroup(group: group));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Dojo')),
      body: BlocListener<GroupBloc, GroupState>(
        listener: (context, state) {
          if (state is GroupOperationSuccess) {
            setState(() => _isSubmitting = false);
            // Only pop if we're still mounted and haven't already navigated
            if (mounted) {
              if (widget.onGroupCreated != null) {
                widget.onGroupCreated!(state.group);
              }
              Navigator.of(context).pop(true);
            }
          } else if (state is GroupFailure) {
            setState(() => _isSubmitting = false);
            if (mounted) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text(state.errorMessage)));
            }
          }
        },
        child: BlocConsumer<FriendBloc, FriendState>(
          listener: (context, state) {
            if (state is FriendsLoadSuccess) {
              print('Friends loaded: ${state.friends.length} friends');
              for (var friend in state.friends) {
                print(
                  'Friend - ID: ${friend.id}, Name: ${friend.name}, Email: ${friend.email}',
                );
              }
              setState(() {
                _friends = state.friends;
              });
            } else if (state is FriendOperationFailure) {
              print('Error loading friends: ${state.message}');
            }
          },
          builder: (context, state) {
            // Show loading indicator if we're loading and don't have any friends yet
            if (state is FriendLoadInProgress && _friends.isEmpty) {
              return const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Loading your friends to add to the dojo...'),
                  ],
                ),
              );
            }

            // Show error message if we have an error and no friends to show
            if (state is FriendOperationFailure && _friends.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: Colors.red,
                        size: 48,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Failed to load friends: ${state.message}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.red),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: () => context.read<FriendBloc>().add(
                          const LoadFriends(forceRefresh: true),
                        ),
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              );
            }

            return SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Dojo Name
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Dojo Name',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter a dojo name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16.0),

                    // Description
                    TextFormField(
                      controller: _descriptionController,
                      decoration: const InputDecoration(
                        labelText: 'Description (Optional)',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 3,
                    ),

                    // Add Friends Section
                    const SizedBox(height: 24.0),
                    // Friends Dropdown
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Add Friends to Group',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8.0),
                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey[300]!),
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12.0,
                            vertical: 4.0,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: _selectedFriendId,
                                    hint: const Text('Select a friend'),
                                    isExpanded: true,
                                    icon: const Icon(
                                      Icons.arrow_drop_down,
                                      size: 28,
                                    ),
                                    items: _friends.isEmpty
                                        ? [
                                            const DropdownMenuItem<String>(
                                              value: null,
                                              enabled: false,
                                              child: Text(
                                                'No friends available',
                                              ),
                                            ),
                                          ]
                                        : _friends
                                              .where(
                                                (friend) => !_selectedMembers
                                                    .contains(friend.id),
                                              )
                                              .map<DropdownMenuItem<String>>((
                                                friend,
                                              ) {
                                                return DropdownMenuItem<String>(
                                                  value: friend.id,
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      Text(
                                                        friend.name.isNotEmpty
                                                            ? friend.name
                                                            : 'Unknown',
                                                        style: const TextStyle(
                                                          fontWeight:
                                                              FontWeight.w500,
                                                        ),
                                                      ),
                                                      Text(
                                                        friend.email,
                                                        style: TextStyle(
                                                          fontSize: 12,
                                                          color:
                                                              Colors.grey[600],
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                );
                                              })
                                              .toList(),
                                    onChanged: (value) {
                                      setState(() {
                                        _selectedFriendId = value;
                                      });
                                    },
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8.0),
                              IconButton(
                                onPressed: _selectedFriendId != null
                                    ? _addSelectedFriend
                                    : null,
                                icon: const Icon(
                                  Icons.add_circle_outline,
                                  size: 28,
                                ),
                                tooltip: 'Add friend',
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    // Selected members chips
                    if (_selectedMembers.isNotEmpty) ...[
                      const SizedBox(height: 12.0),
                      const Text(
                        'Selected Members:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8.0),
                      Container(
                        padding: const EdgeInsets.all(8.0),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey[300]!),
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                        child: Wrap(
                          spacing: 8.0,
                          runSpacing: 8.0,
                          children: _selectedMembers.map((memberId) {
                            final friend = _friends.firstWhere(
                              (f) => f.id == memberId,
                              orElse: () => Friend(
                                id: memberId,
                                name: 'Loading...',
                                email: '',
                              ),
                            );
                            return Container(
                              margin: const EdgeInsets.only(
                                right: 4.0,
                                bottom: 4.0,
                              ),
                              child: Chip(
                                label: Text(
                                  friend.name,
                                  style: const TextStyle(fontSize: 14),
                                ),
                                deleteIcon: const Icon(Icons.close, size: 16),
                                onDeleted: () {
                                  setState(() {
                                    _selectedMembers.remove(memberId);
                                  });
                                },
                                backgroundColor: Theme.of(
                                  context,
                                ).colorScheme.primaryContainer,
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 16.0),
                    ],

                    // Create Dojo Button
                    const SizedBox(height: 24.0),
                    ElevatedButton(
                      onPressed: _isSubmitting ? null : _createGroup,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16.0),
                        textStyle: const TextStyle(fontSize: 16.0),
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : const Text('Create Dojo'),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
