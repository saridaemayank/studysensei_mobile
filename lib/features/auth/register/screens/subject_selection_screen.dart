import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:study_sensei/features/auth/services/auth_service.dart';
import 'package:study_sensei/features/routes/app_routes.dart';

class SubjectSelectionScreen extends StatefulWidget {
  const SubjectSelectionScreen({Key? key}) : super(key: key);

  @override
  _SubjectSelectionScreenState createState() => _SubjectSelectionScreenState();
}

class _SubjectSelectionScreenState extends State<SubjectSelectionScreen> {
  final List<String> _commonSubjects = [
    'Mathematics',
    'Physics',
    'Chemistry',
    'Biology',
    'Computer Science',
    'English',
    'History',
    'Geography',
    'Economics',
  ];

  final List<String> _selectedSubjects = [];
  final TextEditingController _customSubjectController = TextEditingController();
  final AuthService _authService = AuthService();
  bool _isLoading = false;

  @override
  void dispose() {
    _customSubjectController.dispose();
    super.dispose();
  }

  void _toggleSubject(String subject) {
    setState(() {
      if (_selectedSubjects.contains(subject)) {
        _selectedSubjects.remove(subject);
      } else {
        _selectedSubjects.add(subject);
      }
    });
  }

  void _addCustomSubject() {
    final subject = _customSubjectController.text.trim();
    if (subject.isNotEmpty && !_selectedSubjects.contains(subject)) {
      setState(() {
        _selectedSubjects.add(subject);
        _customSubjectController.clear();
      });
    }
  }

  Future<void> _saveSubjects() async {
    if (_selectedSubjects.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one subject')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = _authService.currentUser;
      if (user != null) {
        // Create a batch to update user data and subjects
        final batch = FirebaseFirestore.instance.batch();
        final userRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
        final subjectsRef = userRef.collection('subjects');
        
        // Update user document
        batch.set(userRef, {
          'name': user.displayName ?? '',
          'email': user.email ?? '',
          'grade': 'N/A',
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        
        // Clear existing subjects
        final existingSubjects = await subjectsRef.get();
        for (var doc in existingSubjects.docs) {
          batch.delete(doc.reference);
        }
        
        // Add new subjects
        for (var subject in _selectedSubjects) {
          batch.set(subjectsRef.doc(), {
            'name': subject,
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
        
        await batch.commit();
      }
      
      if (mounted) {
        Navigator.pushReplacementNamed(context, AppRoutes.home);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving subjects: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Your Subjects'),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Select your subjects',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16.0),
                  const Text('Common Subjects:'),
                  const SizedBox(height: 8.0),
                  Wrap(
                    spacing: 8.0,
                    children: _commonSubjects.map((subject) {
                      final isSelected = _selectedSubjects.contains(subject);
                      return FilterChip(
                        label: Text(subject),
                        selected: isSelected,
                        onSelected: (_) => _toggleSubject(subject),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24.0),
                  const Text('Custom Subject:'),
                  const SizedBox(height: 8.0),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _customSubjectController,
                          decoration: const InputDecoration(
                            hintText: 'Add a custom subject',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12.0),
                          ),
                          onFieldSubmitted: (_) => _addCustomSubject(),
                        ),
                      ),
                      const SizedBox(width: 8.0),
                      ElevatedButton(
                        onPressed: _addCustomSubject,
                        child: const Text('Add'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16.0),
                  if (_selectedSubjects.isNotEmpty) ...[
                    const Text('Selected Subjects:'),
                    const SizedBox(height: 8.0),
                    Wrap(
                      spacing: 8.0,
                      children: _selectedSubjects.map((subject) {
                        return Chip(
                          label: Text(subject),
                          onDeleted: () => _toggleSubject(subject),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24.0),
                  ],
                  ElevatedButton(
                    onPressed: _isLoading ? null : _saveSubjects,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16.0),
                    ),
                    child: const Text('Complete Registration'),
                  ),
                ],
              ),
            ),
    );
  }
}
