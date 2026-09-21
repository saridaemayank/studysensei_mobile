enum SenseiHelpMode {
  explain,
  checkWork,
  hint;

  String get apiValue => switch (this) {
        explain => 'explain',
        checkWork => 'check_work',
        hint => 'hint',
      };

  String get displayTitle => switch (this) {
        explain => 'Explain this',
        checkWork => 'Check my work',
        hint => 'Give me a hint',
      };

  String get description => switch (this) {
        explain => 'Understand this step or concept clearly.',
        checkWork => 'Find the mistake and show me the right next step.',
        hint => 'Give me a small nudge without revealing the answer.',
      };
}
