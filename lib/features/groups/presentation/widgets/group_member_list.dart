import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:study_sensei/features/groups/data/models/group_model.dart';
import 'package:study_sensei/features/groups/presentation/bloc/group/group_bloc.dart';
import 'package:study_sensei/features/groups/presentation/bloc/group/group_event.dart';
import 'package:study_sensei/features/groups/presentation/bloc/group/group_state.dart';

class GroupMemberList extends StatelessWidget {
  final Group group;
  final String currentUserId;
  final bool isAdmin;

  const GroupMemberList({
    super.key,
    required this.group,
    required this.currentUserId,
    required this.isAdmin,
  });

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<GroupBloc, GroupState>(
      listenWhen: (previous, current) => 
          current is GroupFailure || current is GroupOperationSuccess,
      listener: (context, state) {
        if (state is GroupFailure) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.errorMessage),
              backgroundColor: Theme.of(context).colorScheme.error,
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.all(8.0),
              duration: const Duration(seconds: 3),
            ),
          );
        } else if (state is GroupOperationSuccess) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: Theme.of(context).colorScheme.primary,
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.all(8.0),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      },
      builder: (context, state) {
        // Show loading indicator when operation is in progress
        if (state is GroupLoading) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: CircularProgressIndicator(),
            ),
          );
        }
        
        return Column(
          children: [
            // Pending invites section
            if (isAdmin && group.pendingInvites.isNotEmpty) ..._buildPendingInvites(context),
            
            // Members list
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16.0),
                itemCount: group.memberIds.length,
                itemBuilder: (context, index) {
                final memberId = group.memberIds[index];
                final isCurrentUser = memberId == currentUserId;
                final isMemberAdmin = group.adminIds.contains(memberId);
                
                // TODO: Replace with actual user data from repository
                final username = 'User ${memberId.substring(0, 4)}';
                final email = 'user${memberId.substring(0, 4)}@example.com';
                
                return Card(
                  margin: const EdgeInsets.only(bottom: 8.0),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                        child: Text(username[0].toUpperCase()),
                      ),
                      title: Text(username),
                      subtitle: Text(email),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isMemberAdmin) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8.0,
                                vertical: 2.0,
                              ),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12.0),
                              ),
                              child: Text(
                                'Admin',
                                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                      color: Theme.of(context).colorScheme.primary,
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                            ),
                            const SizedBox(width: 8.0),
                          ],
                          if (isAdmin && !isCurrentUser)
                            PopupMenuButton<String>(
                              itemBuilder: (context) => [
                                if (!isMemberAdmin)
                                  const PopupMenuItem(
                                    value: 'make_admin',
                                    child: Text('Make Admin'),
                                  ),
                                if (isMemberAdmin && group.adminIds.length > 1)
                                  const PopupMenuItem(
                                    value: 'remove_admin',
                                    child: Text('Remove Admin'),
                                  ),
                                const PopupMenuItem(
                                  value: 'remove',
                                  child: Text('Remove from Group'),
                                ),
                              ],
                              onSelected: (value) {
                                _handleMemberAction(context, value, memberId);
                              },
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          
            // Add member button for admins
            if (isAdmin)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: FilledButton.icon(
                  onPressed: () => _showAddMemberDialog(context),
                  icon: const Icon(Icons.person_add),
                  label: const Text('Add Member'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  List<Widget> _buildPendingInvites(BuildContext context) {
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(24.0, 16.0, 24.0, 8.0),
        child: Text(
          'Pending Invites',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
        ),
      ),
      ...group.pendingInvites.map((email) => Card(
        margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: Theme.of(context).colorScheme.secondary.withOpacity(0.1),
            child: const Icon(Icons.mail_outline, size: 20),
          ),
          title: Text(email),
          subtitle: const Text('Invitation pending'),
          trailing: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => _cancelInvite(context, email),
          ),
        ),
      )).toList(),
      const Divider(),
    ];
  }

  void _handleMemberAction(BuildContext context, String action, String memberId) {
    switch (action) {
      case 'make_admin':
        context.read<GroupBloc>().add(AddGroupAdmin(
          groupId: group.id,
          userId: memberId,
        ));
        break;
      case 'remove_admin':
        context.read<GroupBloc>().add(RemoveGroupAdmin(
          groupId: group.id,
          userId: memberId,
        ));
        break;
      case 'remove':
        _confirmRemoveMember(context, memberId);
        break;
    }
  }

  void _confirmRemoveMember(BuildContext context, String memberId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Member'),
        content: const Text('Are you sure you want to remove this member from the group?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              context.read<GroupBloc>().add(RemoveGroupMember(
                groupId: group.id,
                userId: memberId,
              ));
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  void _showAddMemberDialog(BuildContext context) {
    final emailController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Member'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: emailController,
            decoration: const InputDecoration(
              labelText: 'Email',
              hintText: 'Enter member\'s email',
            ),
            keyboardType: TextInputType.emailAddress,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter an email address';
              }
              if (!RegExp(r'^[^@]+@[^\s]+\.[^\s]+$').hasMatch(value)) {
                return 'Please enter a valid email address';
              }
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState?.validate() ?? false) {
                final email = emailController.text.trim();
                context.read<GroupBloc>().add(InviteToGroup(
                      groupId: group.id,
                      email: email,
                    ));
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Sending invitation...')),
                );
              }
            },
            child: const Text('Send Invite'),
          ),
        ],
      ),
    );
  }
  
  void _cancelInvite(BuildContext context, String email) {
    // Dispatch CancelInvite event to the BLoC
    context.read<GroupBloc>().add(CancelInvite(
          groupId: group.id,
          email: email,
        ));
    
    // Show loading message
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Cancelling invitation...')),
    );
  }
}
