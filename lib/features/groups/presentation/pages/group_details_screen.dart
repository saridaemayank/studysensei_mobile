import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';
import 'package:study_sensei/core/theme/app_colors.dart';
import 'package:study_sensei/core/theme/app_typography.dart';
import 'package:study_sensei/features/groups/data/models/group_model.dart';
import 'package:study_sensei/features/groups/presentation/bloc/assignment/assignment_bloc.dart';
import 'package:study_sensei/features/groups/presentation/widgets/assignment_list.dart';
import 'package:study_sensei/features/groups/presentation/widgets/add_assignment_dialog.dart';
import 'package:study_sensei/core/services/push_notification_service.dart';
import 'package:study_sensei/features/groups/presentation/widgets/group_chat_tab.dart';
import 'package:study_sensei/features/groups/presentation/widgets/dojo_resources_tab.dart';
import 'package:study_sensei/features/auth/providers/user_provider.dart';
import 'package:study_sensei/features/groups/data/services/dojo_engagement_service.dart';
import 'package:study_sensei/features/groups/presentation/pages/dojo_announcements_screen.dart';

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
    _tabController = TabController(length: 4, initialIndex: 0, vsync: this);
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

    if (_tabController.index == 1) {
      _loadAssignments();
    }
    setState(() {});
  }

  void _loadAssignments() {
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
              const SnackBar(
                  content: Text("Couldn’t update assignments. Try again.")),
            );
          }
        },
        child: DefaultTabController(
          length: 4,
          child: Scaffold(
            appBar: AppBar(
              toolbarHeight:
                  64 * MediaQuery.textScalerOf(context).scale(16) / 16,
              title: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.group.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.sectionTitle),
                    Text('${widget.group.memberCount} members',
                        style: AppTypography.caption),
                  ]),
              actions: _isCurrentUserAdmin
                  ? [
                      PopupMenuButton<String>(
                        tooltip: 'Dojo management',
                        onSelected: (action) {
                          if (action == 'createAnnouncement') {
                            _showAnnouncementDialog();
                          } else if (action == 'manageAnnouncements') {
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => DojoAnnouncementsScreen(
                                  group: widget.group,
                                ),
                              ),
                            );
                          }
                        },
                        itemBuilder: (context) => const [
                          PopupMenuItem(
                            value: 'createAnnouncement',
                            child: Text('Create announcement'),
                          ),
                          PopupMenuItem(
                            value: 'manageAnnouncements',
                            child: Text('Manage Announcements'),
                          ),
                        ],
                      ),
                    ]
                  : null,
              bottom: TabBar(
                controller: _tabController,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                labelColor: AppColors.primaryLight,
                unselectedLabelColor: AppColors.textSecondary,
                dividerColor: Colors.transparent,
                tabs: const [
                  Tab(text: 'Chat'),
                  Tab(text: 'Assignments'),
                  Tab(text: 'Resources'),
                  Tab(text: 'Members'),
                ],
              ),
            ),
            body: TabBarView(
              controller: _tabController,
              children: [
                _buildChatTab(context),
                _buildAssignmentsTab(),
                _buildResourcesTab(),
                _buildMembersTab(),
              ],
            ),
            floatingActionButton: _buildFloatingActionButton(),
          ),
        ),
      ),
    );
  }

  bool get _isCurrentUserAdmin =>
      widget.group.adminIds.contains(widget.currentUserId) ||
      widget.group.createdBy == widget.currentUserId;

  Widget _buildAssignmentsTab() {
    return BlocBuilder<AssignmentBloc, AssignmentState>(
      builder: (context, state) {
        debugPrint(
          'GroupDetailsScreen - Building assignments tab with state: ${state.runtimeType}',
        );

        if (state is AssignmentLoadSuccess) {
          if (state.assignments.isEmpty) {
            debugPrint('GroupDetailsScreen - No assignments to display');
            return const Center(child: Text('No shared assignments yet.'));
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
                Text("Couldn’t load assignments right now."),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _loadAssignments,
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        return const Center(child: Text('No shared assignments yet.'));
      },
    );
  }

  Widget _buildResourcesTab() {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final userPreferences = userProvider.userPreferences;
    final memberData =
        _membersCache[widget.currentUserId] as Map<String, dynamic>? ?? {};
    final uploaderName = (userPreferences?.name?.trim().isNotEmpty ?? false)
        ? userPreferences!.name!.trim()
        : memberData['name']?.toString() ??
            memberData['displayName']?.toString() ??
            userProvider.user?.displayName ??
            'Dojo member';

    return DojoResourcesTab(
      group: widget.group,
      currentUserId: widget.currentUserId,
      currentUserName: uploaderName,
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
        final displayName = memberData['name']?.toString() ?? 'Dojo member';
        final subtitle = isAdmin ? 'Admin' : 'Member';

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: AppColors.surfaceElevated,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.borderSubtle),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 8,
            ),
            leading: CircleAvatar(
              backgroundColor: AppColors.primary.withValues(alpha: 0.14),
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
                      displayName.trim().isNotEmpty
                          ? displayName.characters.first.toUpperCase()
                          : '?',
                      style: const TextStyle(color: AppColors.primaryLight),
                    ),
            ),
            title: Text(displayName, style: AppTypography.cardTitle),
            subtitle: Text(
              subtitle,
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
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
      isCurrentUserAdmin: _isCurrentUserAdmin,
      showEngagement: true,
      group: widget.group,
    );
  }

  Future<void> _showAnnouncementDialog() async {
    final title = TextEditingController();
    final body = TextEditingController();
    final posted = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
                title: const Text('Create announcement'),
                content: Column(mainAxisSize: MainAxisSize.min, children: [
                  TextField(
                      controller: title,
                      decoration: const InputDecoration(labelText: 'Title')),
                  TextField(
                      controller: body,
                      maxLines: 4,
                      decoration: const InputDecoration(labelText: 'Body'))
                ]),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      child: const Text('Cancel')),
                  TextButton(
                      onPressed: () async {
                        if (title.text.trim().isEmpty ||
                            body.text.trim().isEmpty) {
                          return;
                        }
                        final user =
                            Provider.of<UserProvider>(context, listen: false);
                        final name = user.userPreferences?.name ??
                            user.user?.displayName ??
                            'Dojo admin';
                        await DojoEngagementService().createAnnouncement(
                            group: widget.group,
                            title: title.text,
                            body: body.text,
                            name: name);
                        if (dialogContext.mounted) {
                          Navigator.pop(dialogContext, true);
                        }
                      },
                      child: const Text('Post Announcement'))
                ]));
    title.dispose();
    body.dispose();
    if (posted == true && mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Announcement posted.')));
    }
  }

  Widget? _buildFloatingActionButton() {
    // Assignments is the second Dojo tab.
    if (_tabController.index != 1) {
      return null;
    }

    return FloatingActionButton(
      tooltip: 'Add assignment',
      backgroundColor: AppColors.primary,
      foregroundColor: AppColors.textPrimary,
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
}
