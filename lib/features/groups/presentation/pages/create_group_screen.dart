import 'package:flutter/material.dart';
import 'package:study_sensei/core/theme/app_colors.dart';
import 'package:study_sensei/core/theme/app_typography.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:study_sensei/features/friends/data/models/friend_model.dart';
import 'package:study_sensei/features/friends/presentation/bloc/friend_bloc.dart';
import 'package:study_sensei/features/friends/presentation/bloc/friend_event.dart';
import 'package:study_sensei/features/friends/presentation/bloc/friend_state.dart';
import 'package:study_sensei/features/groups/data/enums/group_privacy.dart';
import 'package:study_sensei/features/groups/data/models/group_model.dart';
import 'package:study_sensei/features/groups/presentation/bloc/group_bloc.dart';
import 'package:study_sensei/features/common/widgets/sensei_card.dart';
import 'package:study_sensei/features/common/widgets/sensei_primary_button.dart';

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

    // Load friends when the screen initializes
    final friendBloc = context.read<FriendBloc>();

    // Check if we already have friends loaded
    if (friendBloc.state is! FriendsLoadSuccess) {
      friendBloc.add(LoadFriends());
    } else {
      // If friends are already loaded, update the local state
      final state = friendBloc.state as FriendsLoadSuccess;
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
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("Couldn't create your Dojo. Try again."),
                ),
              );
            }
          }
        },
        child: BlocConsumer<FriendBloc, FriendState>(
          listener: (context, state) {
            if (state is FriendsLoadSuccess) {
              setState(() {
                _friends = state.friends;
              });
            } else if (state is FriendOperationFailure) {}
          },
          builder: (context, state) {
            // Show loading indicator if we're loading and don't have any friends yet
            if (state is FriendLoadInProgress && _friends.isEmpty) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text(
                      'Loading friends...',
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
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
                        color: AppColors.error,
                        size: 48,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        "Couldn’t load friends right now.",
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.error),
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
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Start a study space',
                      style: AppTypography.sectionTitle,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Create a clean place for questions, notes, and shared assignments.',
                      style: AppTypography.bodyLarge.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Dojo name',
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter a dojo name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16.0),
                    TextFormField(
                      controller: _descriptionController,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                        hintText: 'What will this Dojo focus on?',
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 24.0),
                    SenseiCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Invite your friends',
                            style: AppTypography.cardTitle,
                          ),
                          const SizedBox(height: 8.0),
                          Text(
                            'You can add more people later.',
                            style: AppTypography.bodyMedium.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Container(
                            decoration: BoxDecoration(
                              border: Border.all(color: AppColors.borderSubtle),
                              borderRadius: BorderRadius.circular(20),
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
                                      itemHeight: null,
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
                                                      CrossAxisAlignment.start,
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
                                                      style: const TextStyle(
                                                        fontSize: 14,
                                                        color: AppColors
                                                            .textSecondary,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              );
                                            }).toList(),
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
                                  constraints: const BoxConstraints(
                                      minWidth: 48, minHeight: 48),
                                ),
                              ],
                            ),
                          ),
                          if (_selectedMembers.isNotEmpty) ...[
                            const SizedBox(height: 16.0),
                            const Text(
                              'Selected members',
                              style: AppTypography.caption,
                            ),
                            const SizedBox(height: 8.0),
                            Wrap(
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
                                return Chip(
                                  label: Text(friend.name),
                                  deleteIcon: const Icon(Icons.close, size: 16),
                                  onDeleted: () {
                                    setState(() {
                                      _selectedMembers.remove(memberId);
                                    });
                                  },
                                );
                              }).toList(),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 24.0),
                    SenseiPrimaryButton(
                      text: 'Create Dojo',
                      onPressed: _isSubmitting ? null : _createGroup,
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
