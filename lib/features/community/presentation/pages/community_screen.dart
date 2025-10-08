import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:study_sensei/features/friends/presentation/pages/friend_search_screen.dart';
import 'package:study_sensei/features/groups/presentation/bloc/simple_group_bloc.dart';
import 'package:study_sensei/features/groups/presentation/pages/dojos_home_screen.dart';

class CommunityScreen extends StatefulWidget {
  final String userId;
  
  const CommunityScreen({super.key, required this.userId});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  SimpleGroupBloc? _groupBloc;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    if (widget.userId.isNotEmpty) {
      _groupBloc = SimpleGroupBloc()..add(LoadUserGroups(widget.userId));
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _groupBloc?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        surfaceTintColor: Colors.transparent,
        backgroundColor: Colors.orange[100],
        elevation: 0,
        title: const Text(
          'Community',
          style: TextStyle(
            fontFamily: 'DancingScript',
            fontSize: 40,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.black87,
          unselectedLabelColor: Colors.black54,
          indicatorColor: Colors.orange,
          labelStyle: const TextStyle(
            fontSize: 16.0,
            fontWeight: FontWeight.bold,
            fontFamily: 'SubHeading',
          ),
          unselectedLabelStyle: const TextStyle(
            fontSize: 16.0,
            fontFamily: 'SubHeading',
          ),
          tabs: const [
            Tab(text: 'FRIENDS'),
            Tab(text: 'DOJOS'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Friends Tab
          FriendSearchScreen(showAppBar: false),
          
          // Dojos Tab
          _groupBloc != null
              ? BlocProvider.value(
                  value: _groupBloc!,
                  child: DojosHomeScreen(userId: widget.userId),
                )
              : const Center(child: Text('Please sign in to view dojos')),
        ],
      ),
    );
  }
}
