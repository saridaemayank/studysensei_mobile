import 'package:flutter/material.dart';
import 'package:study_sensei/features/friends/data/models/user_model.dart';

class UserListTile extends StatelessWidget {
  final UserModel user;
  final VoidCallback onAddFriend;
  final bool showAddButton;

  const UserListTile({
    Key? key,
    required this.user,
    required this.onAddFriend,
    this.showAddButton = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: Theme.of(context).primaryColor.withOpacity(0.2),
        backgroundImage: (user.photoUrl != null && user.photoUrl!.isNotEmpty)
            ? NetworkImage(user.photoUrl!)
            : null,
        child: (user.photoUrl == null || user.photoUrl!.isEmpty)
            ? Text(
                user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                style: TextStyle(
                  color: Theme.of(context).primaryColor,
                  fontWeight: FontWeight.bold,
                ),
              )
            : null,
      ),
      title: Text(
        user.name,
        style: const TextStyle(fontWeight: FontWeight.w500),
      ),
      subtitle: Text(
        user.email,
        style: TextStyle(color: Colors.grey[600]),
        overflow: TextOverflow.ellipsis,
      ),
      trailing: showAddButton
          ? IconButton(
              icon: const Icon(Icons.person_add_alt_1),
              onPressed: () {
                // Dismiss the keyboard
                FocusScope.of(context).unfocus();
                onAddFriend();
              },
              tooltip: 'Add Friend',
            )
          : null,
      onTap: () {
        // Navigate to user profile or show user details
      },
    );
  }
}
