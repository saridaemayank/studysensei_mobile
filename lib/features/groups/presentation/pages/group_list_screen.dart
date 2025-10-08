import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:study_sensei/features/auth/providers/user_provider.dart';
import 'package:study_sensei/features/groups/data/models/group_model.dart';
import 'package:study_sensei/features/groups/presentation/bloc/simple_group_bloc.dart';
import 'package:study_sensei/features/groups/presentation/bloc/assignment/assignment_bloc.dart';
import 'package:study_sensei/features/groups/presentation/pages/group_details_screen.dart';
import 'package:study_sensei/features/groups/presentation/widgets/group_card.dart';
import 'package:study_sensei/features/groups/presentation/widgets/loading_overlay.dart';
import 'package:provider/provider.dart';

class GroupListScreen extends StatefulWidget {
  final String userId;

  const GroupListScreen({super.key, required this.userId});

  @override
  State<GroupListScreen> createState() => _GroupListScreenState();
}

class _GroupListScreenState extends State<GroupListScreen>
    with WidgetsBindingObserver {
  final TextEditingController _searchController = TextEditingController();
  late SimpleGroupBloc _groupBloc;
  bool _isLoading = false;
  String? _errorMessage;

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
    _groupBloc.add(LoadUserGroups(widget.userId));
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

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(8.0),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.primary,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(8.0),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    return LoadingOverlay(
      isLoading: _isLoading,
      loadingMessage: 'Loading dojos...',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Search bar
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: TextField(
                  controller: _searchController,
                  enabled: !_isLoading,
                  onChanged: _onSearchChanged,
                  decoration: InputDecoration(
                    hintText: 'Search dojos...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12.0),
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: _isLoading
                                ? null
                                : () {
                                    _searchController.clear();
                                    _onSearchChanged('');
                                  },
                          )
                        : null,
                  ),
                ),
              ),

              // Error message
              if (_errorMessage != null) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12.0),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.error_outline,
                          color: Theme.of(context).colorScheme.onErrorContainer,
                        ),
                        const SizedBox(width: 12.0),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: TextStyle(
                              color: Theme.of(
                                context,
                              ).colorScheme.onErrorContainer,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => setState(() => _errorMessage = null),
                          color: Theme.of(context).colorScheme.onErrorContainer,
                          iconSize: 20.0,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8.0),
              ],

              // Groups list
              Expanded(
                child: BlocBuilder<SimpleGroupBloc, GroupState>(
                  builder: (context, state) {
                    if (state is GroupFailure) {
                      _showErrorSnackBar(state.errorMessage);
                    } else if (state is GroupOperationSuccess) {
                      _showSuccessSnackBar(state.message);
                    }

                    if (state is GroupLoadSuccess || state is GroupLoading) {
                      final groups = (state as dynamic).groups ?? [];
                      if (groups.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.group_off,
                                size: 64.0,
                                color: Theme.of(context).colorScheme.outline,
                              ),
                              const SizedBox(height: 16.0),
                              Text(
                                'No groups found',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 8.0),
                              Text(
                                _searchController.text.isNotEmpty
                                    ? 'Try a different search term'
                                    : 'Create a new group to get started',
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                    ),
                              ),
                            ],
                          ),
                        );
                      }

                      return RefreshIndicator(
                        onRefresh: () async {
                          _groupBloc.add(LoadUserGroups(widget.userId));
                          await _groupBloc.stream.firstWhere(
                            (state) => state is! GroupLoading,
                          );
                        },
                        child: ListView.builder(
                          padding: const EdgeInsets.only(bottom: 16.0),
                          itemCount: groups.length,
                          itemBuilder: (context, index) {
                            final group = groups[index];
                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16.0,
                                vertical: 8.0,
                              ),
                              child: GroupCard(
                                group: group,
                                onTap: () =>
                                    _navigateToGroupDetails(context, group),
                                isLoading: _isLoading,
                              ),
                            );
                          },
                        ),
                      );
                    }
                    return const SizedBox();
                  },
                ),
              ),
            ],
      ),
    );
  }
}
