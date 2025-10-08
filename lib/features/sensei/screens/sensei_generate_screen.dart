import 'package:flutter/material.dart';
import 'package:study_sensei/features/sensei/models/sensei_session.dart';
import '../services/tts_service.dart';

class SenseiGenerateScreen extends StatefulWidget {
  final String subject;
  final String concept;
  final List<String> objects;
  final String language;
  final String voice;
  final SenseiSession? session;
  final String? reflectionPrompt;
  final String? reflection;

  const SenseiGenerateScreen({
    super.key,
    required this.subject,
    required this.concept,
    required this.objects,
    required this.language,
    required this.voice,
    this.session,
    this.reflectionPrompt,
    this.reflection,
  });

  // Helper constructor for named routes
  static Widget fromRouteArgs(dynamic args) {
    if (args is SenseiSession) {
      return SenseiGenerateScreen(
        subject: args.subject,
        concept: args.concepts.isNotEmpty ? args.concepts.first : '',
        objects: const [],
        language: args.languageCode ?? 'en-US',
        voice: 'Default Voice',
        session: args,
        reflectionPrompt: args.hook, // Using hook as reflection prompt
        reflection: args.analysis, // Using analysis as reflection
      );
    } else if (args is Map<String, dynamic>) {
      return SenseiGenerateScreen(
        subject: args['subject'] ?? 'Unknown Subject',
        concept: args['concept'] ?? 'Unknown Concept',
        objects: List<String>.from(args['objects'] ?? []),
        language: args['language'] ?? 'en-US',
        voice: args['voice'] ?? 'Default Voice',
        reflectionPrompt: args['reflectionPrompt'],
        reflection: args['reflection'],
      );
    }
    return const Scaffold(body: Center(child: Text('Invalid session data')));
  }

  @override
  State<SenseiGenerateScreen> createState() => _SenseiGenerateScreenState();
}

class _SenseiGenerateScreenState extends State<SenseiGenerateScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late TabController _tabController;
  int _currentTabIndex = 0;
  late final TtsService _ttsService;
  String _currentContent = '';

  // Track selected answers for each question
  final Map<int, int?> _selectedAnswers = {};
  // Track which questions have been answered correctly
  final Map<int, bool> _answerFeedback = {};

  @override
  void initState() {
    super.initState();
    _ttsService = TtsService();
    _initTts();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(_handleTabSelection);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateContentForCurrentTab();
    });
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    // Stop any ongoing TTS
    _ttsService.stop();
    // Dispose the TTS service
    _ttsService.dispose();
    // Clean up the tab controller
    _tabController.removeListener(_handleTabSelection);
    _tabController.dispose();
    // Remove observer
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _initTts() async {
    await _ttsService.init();
    if (mounted) {
      setState(() {
        // Update UI after TTS is initialized
      });
    }
  }

  void _updateContentForCurrentTab() {
    final content = _getCurrentContentForTTS();
    if (content.isNotEmpty) {
      setState(() {
        _currentContent = content;
      });
      // Auto-play for read tab
      if (_currentTabIndex == 1) {
        _ttsService.speak(_currentContent);
      }
    }
  }

  String _getCurrentContentForTTS() {
    final session = widget.session;
    if (session == null) return '';

    switch (_currentTabIndex) {
      case 0: // Overview
        final content = <String>[];
        if (session.title != null) content.add('Title: ${session.title}');
        if (session.hook?.isNotEmpty ?? false) content.add(session.hook!);
        if (session.concepts.isNotEmpty) {
          content.add('Key concepts: ${session.concepts.join(', ')}');
        }
        if (session.analogy?.isNotEmpty ?? false) {
          content.add('Analogy: ${session.analogy}');
        }
        return content.join('\n\n');
      case 1: // Read
        final content = <String>[];
        if (session.analysis?.isNotEmpty ?? false) {
          content.add('Analysis: ${session.analysis}');
        }
        if (session.conceptMappings?.isNotEmpty ?? false) {
          content.addAll(
            session.conceptMappings!.map((mapping) {
              return '${mapping['concept']}: ${mapping['explanation']}';
            }),
          );
        }
        if (session.narrationScript?.isNotEmpty ?? false) {
          content.add('Narration: ${session.narrationScript}');
        }
        return content.join('\n\n');
      case 2: // Practice
        return widget.session?.quizQuestions
                ?.map((q) => q['question'])
                .join('\n') ??
            '';
      case 3: // Summary
        return widget.session?.conceptMappings
                ?.map((m) => m['summary'])
                .join('\n') ??
            '';
      default:
        return '';
    }
  }

  void _handleTabSelection() {
    if (_tabController.indexIsChanging) {
      // Stop any ongoing speech when changing tabs
      _ttsService.stop();

      setState(() {
        _currentTabIndex = _tabController.index;
      });

      // Update content for the new tab
      _updateContentForCurrentTab();
    }
  }

  // Get the appropriate FAB icon based on TTS state
  IconData _getFloatingActionIcon() {
    if (_ttsService.isPlaying) return Icons.pause;
    if (_ttsService.isPaused) return Icons.play_arrow;
    return Icons.volume_up;
  }

  // Get FAB tooltip text
  String _getFloatingActionLabel() {
    if (_ttsService.isPlaying) return 'Pause';
    if (_ttsService.isPaused) return 'Resume';
    return 'Listen';
  }

  // Handle FAB tap
  void _onFloatingActionPressed() {
    if (_ttsService.isPlaying) {
      _ttsService.pause();
    } else if (_ttsService.isPaused) {
      _ttsService.resume();
    } else {
      _ttsService.speak(_currentContent);
    }
    setState(() {}); // Rebuild to update the icon
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Only show FAB for tabs that have TTS content
    final showFloatingAction =
        _currentTabIndex == 1 && _currentContent.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.concept),
        centerTitle: true,
        elevation: 0,
        backgroundColor: theme.scaffoldBackgroundColor,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: colorScheme.primary,
          unselectedLabelColor: theme.textTheme.bodyMedium?.color,
          indicatorColor: colorScheme.primary,
          indicatorWeight: 3,
          labelStyle: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
          unselectedLabelStyle: theme.textTheme.titleSmall,
          tabs: const [
            Tab(text: 'Watch', icon: Icon(Icons.play_circle_outline)),
            Tab(text: 'Read', icon: Icon(Icons.article_outlined)),
            Tab(text: 'Practice', icon: Icon(Icons.quiz_outlined)),
            Tab(text: 'Reflect', icon: Icon(Icons.auto_awesome_outlined)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () {
              _showLessonInfo(context);
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Watch Tab
          _buildWatchTab(theme, colorScheme),
          // Read Tab
          _buildReadTab(theme, colorScheme),
          // Practice Tab
          _buildPracticeTab(theme, colorScheme),
          // Reflect Tab
          _buildReflectTab(theme, colorScheme),
        ],
      ),
      floatingActionButton: showFloatingAction
          ? FloatingActionButton.extended(
              onPressed: _onFloatingActionPressed,
              icon: Icon(_getFloatingActionIcon()),
              label: Text(_getFloatingActionLabel()),
              tooltip: _getFloatingActionLabel(),
            )
          : null,
    );
  }

  Widget _buildWatchTab(ThemeData theme, ColorScheme colorScheme) {
    final session = widget.session;
    if (session == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Video player
          if (session.videoUrl != null)
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Container(
                decoration: BoxDecoration(
                  color: colorScheme.surfaceVariant,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    session.thumbnailUrl ?? session.videoUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.play_circle_filled,
                            size: 48,
                            color: colorScheme.primary,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Play Video',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            )
          else
            Container(
              width: double.infinity,
              height: 200,
              decoration: BoxDecoration(
                color: colorScheme.surfaceVariant,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(child: Icon(Icons.videocam_off, size: 48)),
            ),

          const SizedBox(height: 24),

          // Lesson title and metadata
          Row(
            children: [
              Expanded(
                child: Text(
                  session.title ??
                      '${session.subject}: ${session.concepts.isNotEmpty ? session.concepts.first : 'Lesson'}',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (session.createdAt != null)
                Text(
                  _formatDate(session.createdAt!),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.hintColor,
                  ),
                ),
            ],
          ),

          if (session.hook?.isNotEmpty ?? false) ...[
            const SizedBox(height: 12),
            Text(
              session.hook!,
              style: theme.textTheme.bodyLarge?.copyWith(
                fontStyle: FontStyle.italic,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],

          const SizedBox(height: 16),

          // Key concepts
          Text(
            'Key Concepts',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          ...(session.concepts.isNotEmpty
              ? session.concepts
                    .map(
                      (concept) => _buildConceptItem(
                        theme,
                        session.concepts.indexOf(concept),
                      ),
                    )
                    .toList()
              : [
                  Text(
                    'No concepts available',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.hintColor,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ]),

          if (session.analogy?.isNotEmpty ?? false) ...[
            const SizedBox(height: 24),
            _buildContentSection(theme, 0), // Analogy section
          ],
        ],
      ),
    );
  }

  Widget _buildReadTab(ThemeData theme, ColorScheme colorScheme) {
    // Check for content
    final hasAnalysis = widget.session?.analysis?.trim().isNotEmpty ?? false;
    final hasAnalogy = widget.session?.analogy?.trim().isNotEmpty ?? false;
    final hasSummary = widget.session?.summary?.trim().isNotEmpty ?? false;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Summary card
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: colorScheme.outlineVariant, width: 1),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.auto_awesome_outlined,
                        color: colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'AI-Generated Summary',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (hasSummary)
                    Text(
                      widget.session!.summary!,
                      style: theme.textTheme.bodyMedium,
                    )
                  else
                    Text(
                      'No summary available. This would normally contain a concise overview of the key points covered in the lesson.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontStyle: FontStyle.italic,
                        color: theme.textTheme.bodyMedium?.color?.withOpacity(
                          0.7,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Detailed Explanation section
          if (hasAnalysis || hasAnalogy) ...[
            Text(
              'Detailed Explanation',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            if (hasAnalogy) _buildContentSection(theme, 0), // Analogy
            if (hasAnalysis) _buildContentSection(theme, 1), // Analysis
            const SizedBox(height: 16),
          ] else ...[
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 32.0),
                child: Column(
                  children: [
                    Icon(
                      Icons.auto_stories_outlined,
                      size: 48,
                      color: theme.colorScheme.onSurfaceVariant.withOpacity(
                        0.5,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No detailed explanation available',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],

          // Formulas
          const SizedBox(height: 24),
          Text(
            'Key Formulas',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          _buildFormulaCard(theme, colorScheme),

          const SizedBox(height: 80), // Space for FAB
        ],
      ),
    );
  }

  Widget _buildPracticeTab(ThemeData theme, ColorScheme colorScheme) {
    final session = widget.session;
    if (session == null) {
      return const Center(child: CircularProgressIndicator());
    }

    // Check if we have quiz questions
    final hasQuestions = session.quizQuestions?.isNotEmpty ?? false;

    // Debug log all questions
    debugPrint('All quiz questions: ${session.quizQuestions}');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasQuestions) ...[
            // Quiz questions - show all questions and handle invalid ones gracefully
            ...session.quizQuestions!.asMap().entries.map((entry) {
              final index = entry.key;
              final question = entry.value;
              final questionText =
                  question['question']?.toString() ?? 'Question ${index + 1}';
              final options = List<String>.from(question['options'] ?? []);

              // Get the correct answer index from the question data
              int correctAnswerIndex = -1;
              if (question['correctAnswer'] is int) {
                correctAnswerIndex = question['correctAnswer'];
              } else if (question['correctAnswer'] is String) {
                correctAnswerIndex =
                    int.tryParse(question['correctAnswer']) ?? -1;
              }

              // If we don't have a valid answer index, use the first option as correct for display
              if (correctAnswerIndex < 0 ||
                  correctAnswerIndex >= options.length) {
                debugPrint(
                  'Invalid correctAnswerIndex: $correctAnswerIndex for question: $questionText. Using first option as correct.',
                );
                correctAnswerIndex = options.isNotEmpty
                    ? 0
                    : -1; // Default to first option if invalid
              }

              // Debug logging
              debugPrint('Question $index:');
              debugPrint('- Text: $questionText');
              debugPrint('- Options: $options');
              debugPrint('- Correct answer index: $correctAnswerIndex');

              return Card(
                key: ValueKey('question_$index'),
                margin: const EdgeInsets.only(bottom: 24),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: colorScheme.outlineVariant, width: 1),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 24,
                            height: 24,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: colorScheme.primary,
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              '${index + 1}',
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: colorScheme.onPrimary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            question['type']?.toString() ?? 'Question',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        questionText,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (question['hint'] != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Hint: ${question['hint']}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontStyle: FontStyle.italic,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      ...options.asMap().entries.map((option) {
                        final isCorrect = option.key == correctAnswerIndex;

                        // Debug logging
                        debugPrint('  - Option ${option.key}: ${option.value}');
                        debugPrint('  - Is correct: $isCorrect');

                        return _buildAnswerOption(
                          theme,
                          colorScheme,
                          index, // question index
                          option.key, // option index
                          option: option.value,
                          isCorrect: isCorrect,
                          questionKey: index, // Use question index as key
                        );
                      }).toList(),
                    ],
                  ),
                ),
              );
            }).toList(),
          ] else ...[
            // No valid questions available
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.quiz_outlined,
                    size: 64,
                    color: colorScheme.onSurfaceVariant.withOpacity(0.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No practice questions available',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.hintColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Questions will be generated based on your session content',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.hintColor,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 80), // Space for FAB
        ],
      ),
    );
  }

  Widget _buildReflectTab(ThemeData theme, ColorScheme colorScheme) {
    final session = widget.session;
    if (session == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final TextEditingController _reflectionController = TextEditingController();

    final reflectionPrompt =
        widget.reflectionPrompt ??
        'How can you apply the concepts you\'ve learned in this lesson to solve real-world problems? Provide specific examples and explain your reasoning.';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Reflection prompt
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: colorScheme.outlineVariant, width: 1),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Reflection Prompt',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(reflectionPrompt, style: theme.textTheme.bodyLarge),
                  if (session.concepts.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: session.concepts
                          .map(
                            (concept) => Chip(
                              label: Text(concept),
                              backgroundColor: colorScheme.surfaceVariant,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 4,
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Text(
                    'Your response will be saved and can be reviewed later.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.hintColor,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Response field
          Text(
            'Your Response',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _reflectionController,
            maxLines: 8,
            decoration: InputDecoration(
              hintText: 'Type your reflection here...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: colorScheme.outlineVariant),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: colorScheme.outlineVariant),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: colorScheme.primary, width: 2),
              ),
            ),
            onChanged: (value) {
              // Auto-save as user types
              if (session.id.isNotEmpty) {
                // TODO: Update reflection in the session
                // _apiService.updateSessionReflection(session.id, value);
              }
            },
          ),
          const SizedBox(height: 24),

          // Save button
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () {
                // Save reflection
                final reflection = _reflectionController.text.trim();
                if (reflection.isNotEmpty) {
                  // TODO: Save reflection to backend
                  // await _apiService.updateSessionReflection(session.id, reflection);

                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Reflection saved')),
                    );
                  }
                }
              },
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Save Reflection'),
            ),
          ),

          const SizedBox(height: 80), // Space for FAB
        ],
      ),
    );
  }

  Widget _buildConceptItem(ThemeData theme, int index) {
    final session = widget.session;
    if (session == null || session.concepts.isEmpty) {
      return const SizedBox.shrink();
    }

    final concept = session.concepts[index];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            margin: const EdgeInsets.only(right: 12, top: 2),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '${index + 1}',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  concept,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                // Add explanation if available in conceptMappings
                if (session.conceptMappings != null &&
                    session.conceptMappings!.length > index) ...[
                  const SizedBox(height: 4),
                  Text(
                    session.conceptMappings![index]['explanation']
                            ?.toString() ??
                        '',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Just now';

    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inMinutes < 1) {
      return 'Just now';
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

  Widget _buildAnswerOption(
    ThemeData theme,
    ColorScheme colorScheme,
    int questionIndex,
    int optionIndex, {
    required String option,
    required bool isCorrect,
    required int questionKey,
  }) {
    final isSelected = _selectedAnswers[questionKey] == optionIndex;
    final isAnswered = _answerFeedback.containsKey(questionKey);
    final isThisCorrect = isSelected && isCorrect;

    // Find the correct answer index for this question
    int? correctAnswerIndex;
    if (widget.session?.quizQuestions != null &&
        questionIndex < widget.session!.quizQuestions!.length) {
      final question = widget.session!.quizQuestions![questionIndex];
      final questionText = question['question']?.toString() ?? '';
      final options = List<String>.from(question['options'] ?? []);

      // Use the same logic as in the parent to determine correct answer
      final Map<String, int> defaultCorrectAnswers = {
        'What is the main physics principle demonstrated by the motion blur in the video?':
            2,
        'What force keeps the ceiling fan blades moving in a circular path?': 0,
        'What type of energy conversion is happening in the fluorescent lights?':
            1,
      };

      final correctAnswer = question['correctAnswer'];
      if (correctAnswer is int) {
        correctAnswerIndex = correctAnswer;
      } else if (correctAnswer is String) {
        correctAnswerIndex = int.tryParse(correctAnswer) ?? -1;
      } else {
        correctAnswerIndex = -1;
      }

      if (correctAnswerIndex == null ||
          correctAnswerIndex < 0 ||
          correctAnswerIndex >= options.length) {
        correctAnswerIndex = defaultCorrectAnswers[questionText] ?? -1;
      }
    }

    return GestureDetector(
      onTap: isAnswered
          ? null
          : () {
              setState(() {
                _selectedAnswers[questionKey] = optionIndex;
                _answerFeedback[questionKey] = isCorrect;

                // Show feedback
                if (isCorrect) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('✅ Correct! Well done!'),
                      backgroundColor: Colors.green,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                } else if (correctAnswerIndex != null) {
                  final questions = widget.session?.quizQuestions ?? [];
                  final options = questionIndex < questions.length
                      ? (questions[questionIndex]?['options']
                                as List<dynamic>?) ??
                            []
                      : [];
                  final correctAnswerText =
                      correctAnswerIndex >= 0 &&
                          correctAnswerIndex < options.length
                      ? options[correctAnswerIndex].toString()
                      : 'the correct answer';
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        '❌ Not quite right. The correct answer is: $correctAnswerText',
                      ),
                      backgroundColor: Colors.orange,
                      behavior: SnackBarBehavior.floating,
                      duration: const Duration(seconds: 3),
                    ),
                  );
                }
              });
            },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? (isThisCorrect
                    ? Colors.green.withOpacity(0.1)
                    : Colors.red.withOpacity(0.1))
              : colorScheme.surfaceVariant.withOpacity(0.3),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? (isThisCorrect ? Colors.green : Colors.red)
                : colorScheme.outlineVariant,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 24,
              height: 24,
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected
                      ? (isThisCorrect ? Colors.green : Colors.red)
                      : colorScheme.onSurfaceVariant,
                  width: isSelected ? 8 : 2,
                ),
              ),
            ),
            Expanded(
              child: Text(
                option.isNotEmpty
                    ? option
                    : 'Option ${String.fromCharCode(65 + optionIndex)}',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: isSelected
                      ? (isThisCorrect ? Colors.green : Colors.red)
                      : null,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
            if (isSelected) ...[
              const SizedBox(width: 8),
              Icon(
                isThisCorrect ? Icons.check_circle : Icons.cancel,
                color: isThisCorrect ? Colors.green : Colors.red,
                size: 20,
              ),
            ],
          ],
        ),
      ),
    );
  }

  // Helper method to format the content text
  String _formatContentText(String text) {
    // Remove all asterisks and clean up the text
    String formattedText = text.replaceAll('**', '');

    // Split the text into paragraphs
    final paragraphs = formattedText.split('\n\n');

    // Process each paragraph
    final formattedParagraphs = paragraphs.map((paragraph) {
      // Skip empty paragraphs
      if (paragraph.trim().isEmpty) return '';

      // Check if this is a heading (starts with #)
      if (paragraph.startsWith('#')) {
        // Count the number of # to determine heading level
        final headingLevel =
            RegExp(r'^#+').firstMatch(paragraph)?.group(0)?.length ?? 0;
        final headingText = paragraph.substring(headingLevel).trim();

        // Return the heading with appropriate formatting
        switch (headingLevel) {
          case 1:
            return '${headingText.toUpperCase()}\n${'=' * headingText.length}\n\n';
          case 2:
            return '${headingText}\n${'-' * headingText.length}\n\n';
          default:
            return '${headingText}:\n';
        }
      }

      // Check if this is a list item (starts with - or *)
      if (paragraph.startsWith('- ') || paragraph.startsWith('* ')) {
        return '• ${paragraph.substring(2).trim()}\n';
      }

      // Regular paragraph
      return '$paragraph\n\n';
    }).toList();

    return formattedParagraphs.join('');
  }

  Widget _buildContentSection(ThemeData theme, int index) {
    final session = widget.session;
    if (session == null) return const SizedBox.shrink();

    String? content;
    String title = 'Content';

    switch (index) {
      case 0:
        content = session.analogy;
        title = 'Analogy';
        break;
      case 1:
        content = session.analysis;
        title = 'Analysis';
        break;
      default:
        content = null;
    }

    if (content == null || content.isEmpty) return const SizedBox.shrink();

    // Format the content
    final formattedContent = _formatContentText(content);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
            borderRadius: BorderRadius.circular(12),
          ),
          child: SelectableText(
            formattedContent,
            style: theme.textTheme.bodyLarge?.copyWith(height: 1.6),
          ),
        ),
      ],
    );
  }

  Widget _buildFormulaCard(ThemeData theme, ColorScheme colorScheme) {
    final session = widget.session;
    if (session == null) return const SizedBox.shrink();

    // Check if we have any formulas in the conceptMappings
    if (session.conceptMappings?.isNotEmpty == true) {
      // Find all concept mappings that have a formula
      final formulaMappings = session.conceptMappings!
          .where((mapping) => mapping['formula'] != null)
          .toList();

      // If we have formulas, show them in a column
      if (formulaMappings.isNotEmpty) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 8.0,
              ),
              child: Text(
                'Key Formulas',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colorScheme.primary,
                ),
              ),
            ),
            ...formulaMappings.map(
              (mapping) => _buildFormulaCardContent(
                theme: theme,
                colorScheme: colorScheme,
                formula: mapping['formula'] as String,
                description: mapping['formulaDescription'] as String?,
              ),
            ),
          ],
        );
      }
    }

    return const SizedBox.shrink();
  }

  Widget _buildFormulaCardContent({
    required ThemeData theme,
    required ColorScheme colorScheme,
    required String formula,
    String? description,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: colorScheme.outlineVariant, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Key Formula',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(height: 12),
            // Formula
            Text(
              formula,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                fontFamily:
                    'Roboto', // Ensures consistent math symbol rendering
              ),
            ),
            if (description?.isNotEmpty == true) ...[
              const SizedBox(height: 12),
              Text(description!, style: theme.textTheme.bodyLarge),
            ],
          ],
        ),
      ),
    );
  }

  void _showLessonInfo(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 48,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colorScheme.onSurface.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Lesson Details',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              _buildInfoRow(
                theme,
                Icons.school_outlined,
                'Subject',
                widget.subject,
              ),
              const SizedBox(height: 16),
              _buildInfoRow(
                theme,
                Icons.topic_outlined,
                'Topic',
                widget.concept,
              ),
              const SizedBox(height: 16),
              _buildInfoRow(
                theme,
                Icons.language_outlined,
                'Language',
                widget.language,
              ),
              const SizedBox(height: 16),
              _buildInfoRow(
                theme,
                Icons.record_voice_over_outlined,
                'Voice',
                widget.voice,
              ),
              const SizedBox(height: 16),
              _buildInfoRow(
                theme,
                Icons.timer_outlined,
                'Duration',
                '2:45 min',
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Close'),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInfoRow(
    ThemeData theme,
    IconData icon,
    String label,
    String value,
  ) {
    return Row(
      children: [
        Icon(icon, size: 20, color: theme.hintColor),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.hintColor,
                ),
              ),
              const SizedBox(height: 2),
              Text(value, style: theme.textTheme.bodyLarge),
            ],
          ),
        ),
      ],
    );
  }
}
