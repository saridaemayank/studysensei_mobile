import 'package:flutter/material.dart';
import 'package:study_sensei/features/friends/presentation/pages/friend_search_screen.dart';
import 'package:study_sensei/features/groups/presentation/pages/dojos_home_screen.dart';

/// Legacy route name retained; Dojos is the landing content.
class CommunityScreen extends StatelessWidget {
  final String userId;
  const CommunityScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context) => DefaultTabController(
        length: 2,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Dojos'),
            bottom: const TabBar(
              tabs: [Tab(text: 'My Dojos'), Tab(text: 'Friends')],
            ),
          ),
          body: userId.isEmpty
              ? const Center(child: Text('Sign in to see your Dojos.'))
              : TabBarView(
                  children: [
                    DojosHomeScreen(userId: userId),
                    FriendSearchScreen(showAppBar: false),
                  ],
                ),
        ),
      );
}
