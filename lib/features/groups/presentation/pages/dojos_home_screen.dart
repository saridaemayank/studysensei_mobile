import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:study_sensei/features/groups/data/models/group_model.dart';
import 'package:study_sensei/features/groups/presentation/bloc/simple_group_bloc.dart';
import 'package:study_sensei/features/groups/presentation/pages/group_list_screen.dart';
import 'package:study_sensei/features/groups/presentation/pages/create_group_screen.dart';

class DojosHomeScreen extends StatefulWidget {
  final String userId;

  const DojosHomeScreen({super.key, required this.userId});

  @override
  State<DojosHomeScreen> createState() => _DojosHomeScreenState();
}

class _DojosHomeScreenState extends State<DojosHomeScreen> {
  SimpleGroupBloc? _groupBloc;

  @override
  void initState() {
    super.initState();
    if (widget.userId.isEmpty) {
      throw Exception('User ID cannot be empty');
    }
    _groupBloc = SimpleGroupBloc()..add(LoadUserGroups(widget.userId));
  }

  @override
  void dispose() {
    _groupBloc?.close();
    super.dispose();
  }

  void _navigateToCreateGroup() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => BlocProvider.value(
          value: _groupBloc!,
          child: CreateGroupScreen(userId: widget.userId),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _groupBloc!,
      child: Scaffold(
        body: GroupListScreen(userId: widget.userId),
        floatingActionButton: FloatingActionButton(
          heroTag: 'create_group_fab',
          backgroundColor: Colors.orange,
          onPressed: _navigateToCreateGroup,
          tooltip: 'Create Dojo',
          child: const Icon(Icons.add, color: Colors.white),
        ),
      ),
    );
  }
}
