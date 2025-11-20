import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:study_sensei/features/sensei/widgets/subject_chip.dart';
import '../../auth/presentation/pages/phone_verification_screen.dart';
import '../../auth/providers/user_provider.dart';
import '../../calendar/services/firebase_service.dart';
import '../models/sensei_session.dart';
import '../services/sensei_api_service.dart';
import 'camera_screen.dart';
import 'sensei_generate_screen.dart';

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
  SharedPreferences? _prefs;
  int? _remainingSenseiSessions;
  bool _sessionAllowanceInitialized = false;
  DateTime? _sessionWeekStartUtc;

  static const int _freeWeeklySessionLimit = 2;
  static const int _premiumWeeklySessionLimit = -1; // unlimited indicator

  void _ensureInitialized(UserProvider userProvider) {
    if (_isInitialized || !userProvider.isAuthenticated) {
      return;
    }

    final preferences = userProvider.userPreferences;
    final isVerified = preferences?.phoneVerified ?? false;
    final subscriptionPlan =
        preferences?.subscriptionPlan.toLowerCase() ?? 'free';
    final isProUser = subscriptionPlan == 'premium';
    if (!isVerified) {
      return;
    }

    _apiService = SenseiApiService(user: userProvider.user);
    _loadSessions();
    _loadSubjects();
    _isInitialized = true;
    Future.microtask(
      () => _initializeSessionAllowance(isPro: isProUser),
    );
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
              selectedSubject =
                  _subjects.isNotEmpty ? _subjects.first : 'Physics';
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

    final preferences = context.read<UserProvider>().userPreferences;
    final isProUser =
        (preferences?.subscriptionPlan.toLowerCase() ?? 'free') == 'premium';

    await _initializeSessionAllowance(isPro: isProUser);

    if (!isProUser) {
      final remaining = _remainingSenseiSessions ?? _freeWeeklySessionLimit;
      if (remaining <= 0) {
        await _showSenseiUpgradeDialog();
        return;
      }
      setState(() {
        _remainingSenseiSessions =
            (remaining - 1).clamp(0, _freeWeeklySessionLimit);
      });
      await _persistSessionAllowance(_remainingSenseiSessions!);
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

    _ensureInitialized(userProvider);

    // Redirect to login if not authenticated
    if (!userProvider.isAuthenticated) {
      Future.microtask(() {
        Navigator.of(context).pushReplacementNamed('/login');
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final preferences = userProvider.userPreferences;
    final isPhoneVerified = preferences?.phoneVerified ?? false;
    final subscriptionPlan =
        preferences?.subscriptionPlan.toLowerCase() ?? 'free';
    final isProUser = subscriptionPlan == 'premium';

    if (isProUser && _remainingSenseiSessions != null) {
      Future.microtask(
        () => _initializeSessionAllowance(isPro: true, forceReload: true),
      );
    } else if (!isProUser && !_sessionAllowanceInitialized) {
      Future.microtask(
        () => _initializeSessionAllowance(isPro: false, forceReload: true),
      );
    }
    if (!isPhoneVerified) {
      return _buildPhoneVerificationRequired();
    }

    return Scaffold(
      appBar: AppBar(
        surfaceTintColor: Colors.transparent,
        backgroundColor: Colors.orange[100],
        elevation: 0,
        title: const Text(
          'Sensei',
          style: TextStyle(
            fontFamily: 'DancingScript',
            fontSize: 36,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        centerTitle: true,
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
              _SenseiUsageSummary(
                isPro: isProUser,
                remainingSessions: _remainingSenseiSessions,
                maxSessions: _freeWeeklySessionLimit,
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

  Widget _buildPhoneVerificationRequired() {
    return Scaffold(
      appBar: AppBar(
        surfaceTintColor: Colors.transparent,
        backgroundColor: Colors.orange[100],
        elevation: 0,
        title: const Text(
          'Sensei',
          style: TextStyle(
            fontFamily: 'DancingScript',
            fontSize: 36,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Verify your phone number',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            Text(
              'A verified phone number keeps Study Sensei safe from abuse. Verify once to unlock Sensei and Satori.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  await Navigator.of(context)
                      .pushNamed(PhoneVerificationScreen.routeName);
                  if (!mounted) return;
                  setState(() {});
                },
                child: const Text('Verify Phone Number'),
              ),
            ),
          ],
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

  String _senseiWeekKey(String uid) => 'sensei_week_start_$uid';
  String _senseiRemainingKey(String uid) => 'sensei_week_sessions_$uid';

  DateTime _weekStart(DateTime utcNow) {
    final midnight = DateTime.utc(utcNow.year, utcNow.month, utcNow.day);
    final daysFromMonday = (midnight.weekday - DateTime.monday) % 7;
    return midnight.subtract(Duration(days: daysFromMonday));
  }

  Future<void> _initializeSessionAllowance({
    required bool isPro,
    bool forceReload = false,
  }) async {
    if (isPro) {
      if (_sessionAllowanceInitialized &&
          _remainingSenseiSessions == null &&
          !forceReload) {
        return;
      }
      if (mounted) {
        setState(() {
          _remainingSenseiSessions = null;
          _sessionAllowanceInitialized = true;
        });
      } else {
        _remainingSenseiSessions = null;
        _sessionAllowanceInitialized = true;
      }
      return;
    }

    if (_sessionAllowanceInitialized && !forceReload) {
      return;
    }

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      setState(() {
        _remainingSenseiSessions = _freeWeeklySessionLimit;
        _sessionAllowanceInitialized = true;
      });
      return;
    }

    _prefs ??= await SharedPreferences.getInstance();
    final nowUtc = DateTime.now().toUtc();
    final weekStart = _weekStart(nowUtc);
    _sessionWeekStartUtc = weekStart;

    final storedWeekMs = _prefs!.getInt(_senseiWeekKey(uid));
    final storedRemaining = _prefs!.getInt(_senseiRemainingKey(uid));

    if (storedWeekMs == null ||
        storedRemaining == null ||
        storedWeekMs < weekStart.millisecondsSinceEpoch) {
      _remainingSenseiSessions = _freeWeeklySessionLimit;
      await _persistSessionAllowance(_freeWeeklySessionLimit);
    } else {
      _remainingSenseiSessions = storedRemaining;
    }

    if (mounted) {
      setState(() {
        _sessionAllowanceInitialized = true;
      });
    } else {
      _sessionAllowanceInitialized = true;
    }
  }

  Future<void> _persistSessionAllowance(int remaining) async {
    if (_remainingSenseiSessions == null) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    _prefs ??= await SharedPreferences.getInstance();
    final weekStart =
        _sessionWeekStartUtc ?? _weekStart(DateTime.now().toUtc());
    _sessionWeekStartUtc = weekStart;

    final clamped = remaining.clamp(0, _freeWeeklySessionLimit);

    await _prefs!.setInt(
      _senseiWeekKey(uid),
      weekStart.millisecondsSinceEpoch,
    );
    await _prefs!.setInt(
      _senseiRemainingKey(uid),
      clamped,
    );
  }

  Future<void> _showSenseiUpgradeDialog() async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Weekly limit reached'),
        content: const Text(
          'You have used all Sensei sessions for this week on the free plan. Upgrade to Premium for unlimited sessions.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Maybe later'),
          ),
          FilledButton(
            onPressed: () {
              final navigator = Navigator.of(context, rootNavigator: true);
              navigator.pop();
              navigator.pushNamed('/profile');
            },
            child: const Text('Explore Premium'),
          ),
        ],
      ),
    );
  }
}

class _SenseiUsageSummary extends StatelessWidget {
  const _SenseiUsageSummary({
    required this.isPro,
    this.remainingSessions,
    required this.maxSessions,
  });

  final bool isPro;
  final int? remainingSessions;
  final int maxSessions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (isPro) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.9),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          children: [
            const Icon(Icons.all_inclusive, color: Color(0xFF7C5CFF), size: 28),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                'Premium plan active · Enjoy unlimited Sensei sessions each week.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF30324F),
                ),
              ),
            ),
          ],
        ),
      );
    }

    final remaining = (remainingSessions ?? maxSessions).clamp(0, maxSessions);
    final used = (maxSessions - remaining).clamp(0, maxSessions);
    final progress = maxSessions == 0 ? 0.0 : used / maxSessions;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Free plan · $remaining of $maxSessions sessions left this week',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: const Color(0xFF30324F),
            ),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: const Color(0xFFE4E6FF),
              valueColor: const AlwaysStoppedAnimation<Color>(
                Color(0xFF7C5CFF),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Upgrade to Premium for unlimited Sensei sessions.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
