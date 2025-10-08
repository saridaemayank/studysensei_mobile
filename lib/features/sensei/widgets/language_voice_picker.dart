import 'package:flutter/material.dart';

class LanguageVoicePicker extends StatefulWidget {
  final String initialLanguage;
  final String initialVoice;
  final Function(String language, String voice) onChanged;

  const LanguageVoicePicker({
    super.key,
    required this.initialLanguage,
    required this.initialVoice,
    required this.onChanged,
  });

  @override
  State<LanguageVoicePicker> createState() => _LanguageVoicePickerState();
}

class _LanguageVoicePickerState extends State<LanguageVoicePicker> {
  late String _selectedLanguage;
  late String _selectedVoice;
  
  // In a real app, these would come from a service
  final Map<String, List<String>> _languageVoices = {
    'English': ['Emma (Neural)', 'Brian (Neural)', 'Amy (Neural)'],
    'Spanish': ['Lucia (Neural)', 'Sofía (Neural)', 'Diego (Neural)'],
    'French': ['Léa (Neural)', 'Rémi (Neural)', 'Céline (Neural)'],
    'German': ['Vicki (Neural)', 'Daniel (Neural)', 'Marlene (Neural)'],
    'Japanese': ['Takumi (Neural)', 'Kazuha (Neural)', 'Tomoko (Neural)'],
  };

  @override
  void initState() {
    super.initState();
    _selectedLanguage = widget.initialLanguage;
    _selectedVoice = widget.initialVoice;
    
    // If the initial voice isn't in the selected language's voices, select the first one
    if (!_languageVoices[_selectedLanguage]!.contains(_selectedVoice)) {
      _selectedVoice = _languageVoices[_selectedLanguage]!.first;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceVariant.withOpacity(0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.outlineVariant,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Lesson Language & Voice',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          
          // Language dropdown
          DropdownButtonFormField<String>(
            value: _selectedLanguage,
            decoration: InputDecoration(
              labelText: 'Language',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
            ),
            items: _languageVoices.keys.map((language) {
              return DropdownMenuItem(
                value: language,
                child: Text(language),
              );
            }).toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  _selectedLanguage = value;
                  _selectedVoice = _languageVoices[value]!.first;
                });
                widget.onChanged(_selectedLanguage, _selectedVoice);
              }
            },
          ),
          
          const SizedBox(height: 16),
          
          // Voice dropdown
          DropdownButtonFormField<String>(
            value: _selectedVoice,
            decoration: InputDecoration(
              labelText: 'Voice',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              prefixIcon: const Icon(Icons.record_voice_over_outlined),
            ),
            items: _languageVoices[_selectedLanguage]!.map((voice) {
              return DropdownMenuItem(
                value: voice,
                child: Text(voice),
              );
            }).toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  _selectedVoice = value;
                });
                widget.onChanged(_selectedLanguage, _selectedVoice);
              }
            },
          ),
          
          // Preview button
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () {
              // Play preview of the selected voice
              _playVoicePreview();
            },
            icon: const Icon(Icons.play_arrow_rounded),
            label: const Text('Preview Voice'),
            style: OutlinedButton.styleFrom(
              foregroundColor: colorScheme.primary,
              side: BorderSide(color: colorScheme.primary),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ],
      ),
    );
  }
  
  void _playVoicePreview() {
    // In a real app, this would play a preview of the selected voice
    // For now, we'll just show a snackbar
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Playing preview of $_selectedVoice...'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
}
