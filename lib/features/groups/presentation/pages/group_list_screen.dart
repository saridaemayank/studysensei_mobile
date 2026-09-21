import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:study_sensei/features/auth/providers/user_provider.dart';
import 'package:study_sensei/features/groups/data/models/group_model.dart';
import 'package:study_sensei/features/groups/presentation/bloc/simple_group_bloc.dart';
import 'package:study_sensei/features/groups/presentation/bloc/assignment/assignment_bloc.dart';
import 'package:study_sensei/features/groups/presentation/pages/group_details_screen.dart';
import 'package:study_sensei/features/groups/presentation/widgets/group_card.dart';
import 'package:study_sensei/features/groups/presentation/widgets/dojo_empty_state.dart';
import 'package:provider/provider.dart';

class GroupListScreen extends StatefulWidget {
  final String userId;
  final VoidCallback? onCreate;

  const GroupListScreen({super.key, required this.userId, this.onCreate});

  @override
  State<GroupListScreen> createState() => _GroupListScreenState();
}

class _GroupListScreenState extends State<GroupListScreen>
    with WidgetsBindingObserver {
  final TextEditingController _searchController = TextEditingController();
  late SimpleGroupBloc _groupBloc;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _groupBloc = context.read<SimpleGroupBloc>();
    _loadGroups();
  }

  void _loadGroups() {
    _groupBloc.add(LoadUserGroups(widget.userId));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadGroups();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    setState(() {});
  }

  void _navigateToGroupDetails(BuildContext context, Group group) {
    final currentUser = Provider.of<UserProvider>(context, listen: false).user;
    if (currentUser != null) {
      final assignmentBloc = AssignmentBloc();
      assignmentBloc.add(LoadAssignments(group.id));

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => BlocProvider.value(
            value: assignmentBloc,
            child: GroupDetailsScreen(
              group: group,
              currentUserId: currentUser.uid,
            ),
          ),
        ),
      ).then((_) {
        assignmentBloc.close();
      });
    }
  }

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: TextField(
                  controller: _searchController,
                  onChanged: _onSearchChanged,
                  decoration: InputDecoration(
                      hintText: 'Search your Dojos',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchController.text.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Clear search',
                              icon: const Icon(Icons.close),
                              onPressed: () {
                                _searchController.clear();
                                _onSearchChanged('');
                              })))),
          Expanded(child: BlocBuilder<SimpleGroupBloc, GroupState>(
              builder: (context, state) {
            if (state is GroupFailure) {
              return Center(
                  child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        const Text("Couldn't load your Dojos.",
                            textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        OutlinedButton(
                            onPressed: _loadGroups, child: const Text('Retry')),
                      ])));
            }
            final groups = switch (state) {
              GroupLoadSuccess() => state.groups,
              GroupLoading() => state.groups,
              _ => <Group>[],
            };
            if (groups.isEmpty &&
                (state is GroupLoading || state is GroupInitial)) {
              return const Center(child: CircularProgressIndicator());
            }
            if (groups.isEmpty) {
              return DojoEmptyState(onCreate: widget.onCreate);
            }
            final query = _searchController.text.trim().toLowerCase();
            final visible = groups
                .where((group) => group.name.toLowerCase().contains(query))
                .toList();
            if (visible.isEmpty) {
              return const Center(
                  child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('No matching Dojos. Try another name.',
                          textAlign: TextAlign.center)));
            }
            return RefreshIndicator(
                onRefresh: () async {
                  _groupBloc.add(LoadUserGroups(widget.userId));
                  await _groupBloc.stream
                      .firstWhere((state) => state is! GroupLoading);
                },
                child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 96),
                    itemCount: visible.length,
                    itemBuilder: (context, index) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: GroupCard(
                            group: visible[index],
                            onTap: () => _navigateToGroupDetails(
                                context, visible[index])))));
          })),
        ],
      );
}
