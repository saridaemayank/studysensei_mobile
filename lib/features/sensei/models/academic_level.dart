/// User-selected explanation depth. No persistence or AI behavior yet.
enum AcademicLevel {
  /// Intuitive, conceptual language.
  school,

  /// CBSE/NCERT terminology and expected school methods.
  boards,

  /// Concise, analytical problem solving.
  jee;

  String get apiValue => name;

  String get displayTitle => switch (this) {
        school => 'School',
        boards => 'Boards',
        jee => 'JEE',
      };
}
