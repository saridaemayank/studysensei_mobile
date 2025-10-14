import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:study_sensei/features/sensei/widgets/subject_chip.dart';
import 'camera_screen.dart';
import 'sensei_generate_screen.dart';
import '../../auth/providers/user_provider.dart';
import '../services/sensei_api_service.dart';
import '../models/sensei_session.dart';
import '../../calendar/services/firebase_service.dart';

class SenseiLandingScreen extends StatefulWidget {
  const SenseiLandingScreen({super.key});

  @override
  State<SenseiLandingScreen> createState() => _SenseiLandingScreenState();
}

class _SenseiLandingScreenState extends State<SenseiLandingScreen> {
  static const List<String> _defaultSubjects = [
    'Physics',
    'Chemistry',
    'Mathematics',
    'Biology',
    'Computer Science',
    'Other',
  ];

  List<String> _subjects = _defaultSubjects;
  String selectedSubject = 'Physics';
  final TextEditingController _conceptController = TextEditingController();
  final FocusNode _conceptFocusNode = FocusNode();
  bool _isLoading = false;
  bool _isLoadingSessions = false;
  bool _isLoadingSubjects = false;
  List<SenseiSession> _sessions = [];
  late SenseiApiService _apiService;

  StreamSubscription<List<SenseiSession>>? _sessionsSubscription;
  StreamSubscription<List<String>>? _subjectsSubscription;
  bool _isInitialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInitialized) {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      if (userProvider.isAuthenticated) {
        _apiService = SenseiApiService(user: userProvider.user);
        _loadSessions();
        _loadSubjects();
        _isInitialized = true;
      } else {
        // Handle unauthenticated state if needed
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please sign in to view your sessions'),
            ),
          );
        }
      }
    }
  }

  @override
  void dispose() {
    _sessionsSubscription?.cancel();
    _subjectsSubscription?.cancel();
    _conceptController.dispose();
    _conceptFocusNode.dispose();
    super.dispose();
  }

  void _loadSessions() {
    if (!mounted) return;

    setState(() {
      _isLoadingSessions = true;
    });

    _sessionsSubscription?.cancel();
    _sessionsSubscription = _apiService.getUserSessions().listen(
      (sessions) {
        if (mounted) {
          setState(() {
            _sessions = sessions;
            _isLoadingSessions = false;
          });
        }
      },
      onError: (e) {
        if (mounted) {
          setState(() {
            _isLoadingSessions = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to load sessions. Please try again.'),
            ),
          );
        }
        debugPrint('Error loading sessions: $e');
      },
    );
  }

  void _loadSubjects() {
    if (!mounted) return;

    setState(() {
      _isLoadingSubjects = true;
    });

    _subjectsSubscription?.cancel();
    _subjectsSubscription = FirebaseService.getUserSubjects().listen(
      (subjects) {
        if (mounted) {
          setState(() {
            _subjects = subjects.isNotEmpty ? subjects : _defaultSubjects;
            _isLoadingSubjects = false;

            // Update selected subject if current selection is not in the new list
            if (!_subjects.contains(selectedSubject)) {
              selectedSubject = _subjects.isNotEmpty
                  ? _subjects.first
                  : 'Physics';
            }
          });
        }
      },
      onError: (e) {
        if (mounted) {
          setState(() {
            _subjects = _defaultSubjects;
            _isLoadingSubjects = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to load subjects. Using default subjects.'),
            ),
          );
        }
        debugPrint('Error loading subjects: $e');
      },
    );
  }

  Future<void> _startLesson() async {
    if (_conceptController.text.trim().isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a concept to learn about'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CameraScreen(
            subject: selectedSubject,
            concept: _conceptController.text,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Navigate to generate screen with session data
  void _navigateToReviewScreen(SenseiSession session) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SenseiGenerateScreen(
          subject: session.subject,
          concept: session.concepts.isNotEmpty ? session.concepts.first : '',
          objects: const [],
          language: session.languageCode ?? 'en-US',
          voice: 'Default Voice',
          session: session,
          reflectionPrompt: session.hook,
          reflection: session.analysis,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final userProvider = Provider.of<UserProvider>(context);
    final user = FirebaseAuth.instance.currentUser;

    // Redirect to login if not authenticated
    if (!userProvider.isAuthenticated) {
      Future.microtask(() {
        Navigator.of(context).pushReplacementNamed('/login');
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        surfaceTintColor: Colors.transparent,
        backgroundColor: Colors.orange[100],
        elevation: 0, // Remove elevation from app bar
        title: const Padding(
          padding: EdgeInsets.only(bottom: 10), // Center the title
          child: Text(
            'Sensei',
            style: TextStyle(
              fontFamily: 'DancingScript',
              fontSize: 40, // Slightly smaller font size
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          _loadSessions();
          _loadSubjects();
        },
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Welcome Section
              Text(
                'Hello, ${user?.displayName ?? 'Learner'}!',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'What would you like to learn today?',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),

              // Subject Selection
              Text(
                'Select a subject',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              _isLoadingSubjects
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  : SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: _subjects
                            .map(
                              (subject) => Padding(
                                padding: const EdgeInsets.only(right: 8.0),
                                child: SubjectChip(
                                  label: subject,
                                  isSelected: selectedSubject == subject,
                                  onSelected: (isSelected) {
                                    if (isSelected) {
                                      setState(() {
                                        selectedSubject = subject;
                                      });
                                    }
                                  },
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ),
              const SizedBox(height: 24),

              // Concept Input
              TextFormField(
                controller: _conceptController,
                focusNode: _conceptFocusNode,
                decoration: InputDecoration(
                  labelText: 'Enter a concept to learn about',
                  hintText: 'e.g., Newton\'s Laws, Photosynthesis, etc.',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _conceptController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _conceptController.clear();
                            setState(() {});
                          },
                        )
                      : null,
                ),
                onChanged: (_) => setState(() {}),
                onFieldSubmitted: (_) => _startLesson(),
              ),
              const SizedBox(height: 32),

              // Start Learning Button
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _startLesson,
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        )
                      : const Text(
                          'Start Learning',
                          style: TextStyle(fontSize: 16),
                        ),
                ),
              ),
              const SizedBox(height: 32),

              // Recent Sessions
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Recent Sessions',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      // TODO: Navigate to all sessions
                    },
                    child: const Text('See All'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _isLoadingSessions
                  ? const Center(child: CircularProgressIndicator())
                  : _sessions.isEmpty
                  ? Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceVariant.withOpacity(
                          0.5,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.history_toggle_off_outlined,
                            size: 48,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No recent sessions',
                            style: theme.textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Your learning sessions will appear here',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _sessions.length,
                      itemBuilder: (context, index) {
                        final session = _sessions[index];
                        return _buildSessionCard(session, theme);
                      },
                    ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSessionCard(SenseiSession session, ThemeData theme) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _navigateToReviewScreen(session),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Thumbnail/Icon
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.play_lesson_outlined,
                  size: 32,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 16),

              // Session Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    Text(
                      session.title ?? '${session.subject} Lesson',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),

                    // Concepts
                    if (session.concepts.isNotEmpty)
                      Text(
                        session.concepts.take(3).join(' • '),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),

                    // Date
                    const SizedBox(height: 4),
                    Text(
                      _formatDate(session.createdAt),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                    ),
                  ],
                ),
              ),

              // More options
              Icon(Icons.chevron_right, color: theme.colorScheme.outline),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 7) {
      return '${date.day}/${date.month}/${date.year}';
    } else if (difference.inDays >= 1) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours >= 1) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes >= 1) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}
