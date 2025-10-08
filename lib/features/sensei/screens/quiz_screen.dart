import 'package:flutter/material.dart';
import '../../common/widgets/custom_app_bar.dart';
import '../models/sensei_lesson.dart';

class QuizScreen extends StatefulWidget {
  final SenseiLesson lesson;

  const QuizScreen({super.key, required this.lesson});

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  int _currentQuestionIndex = 0;
  int? _selectedOptionIndex;
  bool _showResult = false;
  bool _isCorrect = false;
  int _score = 0;
  late final List<bool> _questionResults;

  @override
  void initState() {
    super.initState();
    _questionResults = List.filled(widget.lesson.quizQuestions.length, false);
  }

  void _selectOption(int index) {
    if (_showResult) return;

    setState(() {
      _selectedOptionIndex = index;
      _showResult = true;
      
      final isCorrect = widget.lesson.quizQuestions[_currentQuestionIndex]
          .isCorrect(index);
      
      if (isCorrect) {
        _score++;
        _questionResults[_currentQuestionIndex] = true;
      }
      
      _isCorrect = isCorrect;
    });
  }

  void _nextQuestion() {
    if (_currentQuestionIndex < widget.lesson.quizQuestions.length - 1) {
      setState(() {
        _currentQuestionIndex++;
        _selectedOptionIndex = null;
        _showResult = false;
      });
    } else {
      _showQuizResults();
    }
  }

  void _showQuizResults() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Quiz Completed!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Your Score: $_score/${widget.lesson.quizQuestions.length}',
              style: theme.textTheme.headlineSmall?.copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: LinearProgressIndicator(
                value: _score / widget.lesson.quizQuestions.length,
                backgroundColor: colorScheme.surfaceVariant,
                color: colorScheme.primary,
                minHeight: 10,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              _getResultMessage(),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(context)
                ..pop()
                ..pop(); // Go back to lesson screen
            },
            child: const Text('Review Lesson'),
          ),
        ],
      ),
    );
  }

  String _getResultMessage() {
    final percentage = _score / widget.lesson.quizQuestions.length;
    if (percentage >= 0.8) {
      return 'Excellent work! You have a strong understanding of this topic.';
    } else if (percentage >= 0.5) {
      return 'Good job! You understand the basics, but could use some more practice.';
    } else {
      return 'Keep practicing! Review the lesson and try the quiz again.';
    }
  }

  Widget _buildOptionButton({
    required BuildContext context,
    required String option,
    required int index,
    required bool isSelected,
    required bool isCorrect,
    required ThemeData theme,
    required ColorScheme colorScheme,
  }) {
    Color? borderColor;
    Color? backgroundColor;
    
    if (_showResult) {
      if (isSelected) {
        backgroundColor = isCorrect 
            ? Colors.green.withOpacity(0.1) 
            : Colors.red.withOpacity(0.1);
        borderColor = isCorrect ? Colors.green : Colors.red;
      } else if (isCorrect) {
        backgroundColor = Colors.green.withOpacity(0.1);
        borderColor = Colors.green;
      }
    } else if (isSelected) {
      backgroundColor = colorScheme.primary.withOpacity(0.1);
      borderColor = colorScheme.primary;
    }
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: OutlinedButton(
        onPressed: () => _selectOption(index),
        style: OutlinedButton.styleFrom(
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: borderColor ?? colorScheme.outline,
              width: 1.5,
            ),
          ),
          backgroundColor: backgroundColor,
          foregroundColor: theme.colorScheme.onSurface,
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
                  color: borderColor ?? colorScheme.outline,
                  width: 2,
                ),
                color: isSelected 
                    ? borderColor ?? colorScheme.primary 
                    : null,
              ),
              child: isSelected
                  ? Icon(
                      _isCorrect ? Icons.check : Icons.close,
                      size: 16,
                      color: Colors.white,
                    )
                  : null,
            ),
            Expanded(
              child: Text(
                option,
                style: theme.textTheme.bodyLarge,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExplanation(String? explanation) {
    if (!_showResult || explanation == null) return const SizedBox.shrink();
    
    return Padding(
      padding: const EdgeInsets.only(top: 16.0, bottom: 24.0),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _isCorrect 
              ? Colors.green.withOpacity(0.1) 
              : Colors.red.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _isCorrect ? Colors.green : Colors.red,
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _isCorrect ? 'Correct!' : 'Incorrect',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: _isCorrect ? Colors.green : Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              explanation,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final question = widget.lesson.quizQuestions[_currentQuestionIndex];

    return Scaffold(
      appBar: CustomAppBar(
        title: 'Quiz',
        showBackButton: true,
      ),
      body: Column(
        children: [
          // Progress indicator
          ClipRRect(
            child: LinearProgressIndicator(
              value: (_currentQuestionIndex + 1) / widget.lesson.quizQuestions.length,
              backgroundColor: colorScheme.surfaceVariant,
              color: colorScheme.primary,
              minHeight: 4,
            ),
          ),
          
          // Question counter
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Question ${_currentQuestionIndex + 1}/${widget.lesson.quizQuestions.length}',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Score: $_score',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          
          // Question card
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Question text
                  Card(
                    elevation: 0,
                    color: colorScheme.surfaceVariant.withOpacity(0.5),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        question.question,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Options
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: question.options.length,
                    itemBuilder: (context, index) {
                      final isSelected = _selectedOptionIndex == index;
                      final isCorrect = question.isCorrect(index);
                      
                      return _buildOptionButton(
                        context: context,
                        option: question.options[index],
                        index: index,
                        isSelected: isSelected,
                        isCorrect: isCorrect,
                        theme: theme,
                        colorScheme: colorScheme,
                      );
                    },
                  ),
                  
                  // Explanation
                  _buildExplanation(question.explanation),
                ],
              ),
            ),
          ),
          
          // Next button
          if (_showResult)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: FilledButton(
                onPressed: _nextQuestion,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  _currentQuestionIndex < widget.lesson.quizQuestions.length - 1
                      ? 'Next Question' 
                      : 'See Results',
                ),
              ),
            )
          else if (_selectedOptionIndex != null)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: FilledButton(
                onPressed: _nextQuestion,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Continue'),
              ),
            ),
        ],
      ),
    );
  }
}
