import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';
import 'package:study_sensei/features/groups/data/models/group_assignment_model.dart';
import 'package:study_sensei/features/groups/data/models/group_model.dart';
import 'package:study_sensei/features/groups/presentation/bloc/assignment/assignment_bloc.dart';
import 'package:study_sensei/features/groups/presentation/widgets/assignment_list.dart';
import 'package:study_sensei/features/groups/presentation/widgets/add_assignment_dialog.dart';
import 'package:study_sensei/core/services/push_notification_service.dart';
import 'package:study_sensei/features/groups/presentation/widgets/group_chat_tab.dart';
import 'package:study_sensei/features/auth/providers/user_provider.dart';

class GroupDetailsScreen extends StatefulWidget {
  final Group group;
  final String currentUserId;
  final Function(Group)? onGroupUpdated;

  const GroupDetailsScreen({
    super.key,
    required this.group,
    required this.currentUserId,
    this.onGroupUpdated,
  });

  @override
  State<GroupDetailsScreen> createState() => _GroupDetailsScreenState();
}

class _GroupDetailsScreenState extends State<GroupDetailsScreen>
    with SingleTickerProviderStateMixin {
  final Map<String, dynamic> _membersCache = {};
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    print('GroupDetailsScreen - initState');
    _tabController = TabController(length: 3, vsync: this);
    _loadMemberDetails();

    // Listen to tab changes
    _tabController.addListener(_handleTabChange);
    PushNotificationService.instance.trackActiveGroup(widget.group.id);
  }

  Future<void> _loadMemberDetails() async {
    for (final memberId in widget.group.memberIds) {
      if (!_membersCache.containsKey(memberId)) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(memberId)
            .get();
        if (userDoc.exists && mounted) {
          setState(() {
            _membersCache[memberId] = userDoc.data();
          });
        }
      }
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    PushNotificationService.instance.trackActiveGroup(null);
    super.dispose();
  }

  void _handleTabChange() {
    if (!mounted) return;

    if (_tabController.index == 0) {
      _loadAssignments();
    }
    setState(() {});
  }

  void _loadAssignments() {
    print('GroupDetailsScreen - Dispatching LoadAssignments event');
    context.read<AssignmentBloc>().add(LoadAssignments(widget.group.id));
  }

  @override
  Widget build(BuildContext context) {
    // Create a new AssignmentBloc for this screen
    return BlocProvider(
      create: (context) =>
          AssignmentBloc()..add(LoadAssignments(widget.group.id)),
      child: BlocListener<AssignmentBloc, AssignmentState>(
        listener: (context, state) {
          if (state is AssignmentError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message)),
            );
          }
        },
        child: DefaultTabController(
          length: 3,
          child: Scaffold(
            appBar: AppBar(
              title: Text('${widget.group.name} Dojo'),
              bottom: TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(icon: Icon(Icons.assignment), text: 'Assignments'),
                  Tab(icon: Icon(Icons.people), text: 'Members'),
                  Tab(icon: Icon(Icons.chat), text: 'Chat'),
                ],
              ),
            ),
            body: TabBarView(
              controller: _tabController,
              children: [
                _buildAssignmentsTab(),
                _buildMembersTab(),
                _buildChatTab(context),
              ],
            ),
            floatingActionButton: _buildFloatingActionButton(),
          ),
        ),
      ),
    );
  }

  Widget _buildAssignmentsTab() {
    return BlocBuilder<AssignmentBloc, AssignmentState>(
      builder: (context, state) {
        debugPrint(
          'GroupDetailsScreen - Building assignments tab with state: ${state.runtimeType}',
        );

        if (state is AssignmentLoadSuccess) {
          if (state.assignments.isEmpty) {
            debugPrint('GroupDetailsScreen - No assignments to display');
            return const Center(child: Text('No assignments yet'));
          }

          return AssignmentList(
            groupId: widget.group.id,
            isAdmin: widget.group.adminIds.contains(widget.currentUserId),
            currentUserId: widget.currentUserId,
            assignments: state.assignments,
          );
        }

        if (state is AssignmentLoading) {
          debugPrint('GroupDetailsScreen - Loading assignments...');
          return const Center(child: CircularProgressIndicator());
        }

        if (state is AssignmentError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Error loading assignments: ${state.message}'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _loadAssignments,
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        return const Center(child: Text('No assignments yet'));
      },
    );
  }

  Widget _buildMembersTab() {
    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: widget.group.memberIds.length,
      itemBuilder: (context, index) {
        final memberId = widget.group.memberIds[index];
        final isAdmin = widget.group.adminIds.contains(memberId);
        final memberData = _membersCache[memberId] ?? {};

        return ListTile(
          leading: CircleAvatar(
            backgroundColor: Theme.of(context).primaryColor,
            child: memberData['photoUrl'] != null
                ? ClipOval(
                    child: Image.network(
                      memberData['photoUrl'],
                      fit: BoxFit.cover,
                      width: 40,
                      height: 40,
                    ),
                  )
                : Text(
                    memberData['name']?.substring(0, 1).toUpperCase() ?? '?',
                    style: const TextStyle(color: Colors.white),
                  ),
          ),
          title: Text(memberData['name'] ?? 'Unknown User'),
          subtitle: isAdmin ? const Text('Admin') : const Text('Member'),
          trailing: widget.group.adminIds.contains(widget.currentUserId)
              ? IconButton(
                  icon: const Icon(Icons.more_vert),
                  onPressed: () => _showMemberOptions(memberId, isAdmin),
                )
              : null,
        );
      },
    );
  }

  Widget _buildChatTab(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final userPreferences = userProvider.userPreferences;
    final memberData =
        _membersCache[widget.currentUserId] as Map<String, dynamic>? ?? {};

    final chatUserName = (userPreferences?.name?.trim().isNotEmpty ?? false)
        ? userPreferences!.name!.trim()
        : memberData['name']?.toString() ??
            memberData['displayName']?.toString() ??
            userProvider.user?.displayName ??
            'Dojo Member';

    final chatUserPhotoUrl = userPreferences?.photoUrl ??
        memberData['photoUrl']?.toString() ??
        userProvider.user?.photoURL;

    return GroupChatTab(
      groupId: widget.group.id,
      currentUserId: widget.currentUserId,
      currentUserName: chatUserName,
      currentUserPhotoUrl: chatUserPhotoUrl,
      isCurrentUserAdmin: widget.group.adminIds.contains(widget.currentUserId),
    );
  }

  Widget? _buildFloatingActionButton() {
    // Show FAB on assignments tab for all users
    if (_tabController.index != 0) {
      return null;
    }

    return FloatingActionButton(
      onPressed: _showAddAssignmentDialog,
      child: const Icon(Icons.add),
    );
  }

  void _showAddAssignmentDialog() {
    // Get the BuildContext from the navigator to ensure we have the right context
    final BuildContext dialogContext = context;

    showDialog(
      context: context,
      builder: (context) => BlocProvider.value(
        value: BlocProvider.of<AssignmentBloc>(dialogContext),
        child: AddAssignmentDialog(
          groupId: widget.group.id,
          currentUserId: widget.currentUserId,
          memberIds: widget.group.memberIds,
          onAssignmentAdded: (assignment) {
            // Add the assignment using the bloc
            BlocProvider.of<AssignmentBloc>(dialogContext).add(
              CreateAssignment(assignment, widget.group.id),
            );
          },
        ),
      ),
    );
  }

  void _navigateToGroupSettings() {
    // TODO: Implement dojo settings navigation
  }

  void _showMemberOptions(String memberId, bool isAdmin) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!isAdmin)
            ListTile(
              leading: const Icon(Icons.admin_panel_settings),
              title: const Text('Make Admin'),
              onTap: () {
                // TODO: Implement make admin
                Navigator.pop(context);
              },
            ),
          ListTile(
            leading: const Icon(Icons.person_remove, color: Colors.red),
            title: const Text(
              'Remove from Dojo',
              style: TextStyle(color: Colors.red),
            ),
            onTap: () {
              // TODO: Implement remove from dojo
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }
}
