import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class AddAssignmentPage extends StatefulWidget {
  @override
  _AddAssignmentPageState createState() => _AddAssignmentPageState();
}

class _AddAssignmentPageState extends State<AddAssignmentPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  // Removed the hardcoded default subject
  DateTime _deadline = DateTime.now();

  final List<String> subjects = [];
  final Map<String, Color> subjectColors = {};
  String? _selectedSubject;
  
  // Predefined colors for subjects
  final List<Color> _availableColors = [
    Colors.red,
    Colors.green,
    Colors.blue,
    Colors.orange,
    Colors.purple,
    Colors.teal,
    Colors.pink,
    Colors.amber,
    Colors.cyan,
    Colors.indigo,
  ];
  
  @override
  void initState() {
    super.initState();
    _loadSubjects();
  }
  
  void _loadSubjects() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    
    FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('subjects')
        .orderBy('name')
        .snapshots()
        .listen((snapshot) {
      if (mounted) {
        setState(() {
          subjects.clear();
          for (var doc in snapshot.docs) {
            final subject = doc['name'] as String? ?? '';
            if (subject.isNotEmpty) {
              subjects.add(subject);
              // Assign a color if not already assigned
              if (!subjectColors.containsKey(subject)) {
                subjectColors[subject] = _availableColors[subjects.length % _availableColors.length];
              }
            }
          }
          
          // Set the first subject as selected if none is selected
          if (_selectedSubject == null && subjects.isNotEmpty) {
            _selectedSubject = subjects.first;
          }
        });
      }
    });
  }

  Future<void> _saveAssignment() async {
    if (_formKey.currentState!.validate() && _selectedSubject != null) {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      
      try {
        // Save assignment in user's assignments subcollection
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('assignments')
            .add({
              'name': _nameController.text,
              'subject': _selectedSubject,
              'deadline': Timestamp.fromDate(_deadline),
              'createdAt': FieldValue.serverTimestamp(),
              'isCompleted': false,
            });
            
        if (mounted) {
          Navigator.pop(context, true);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error saving assignment: $e')),
          );
        }
      }
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _deadline,
      firstDate: DateTime.now(),
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != _deadline) {
      setState(() {
        _deadline = DateTime(
          picked.year,
          picked.month,
          picked.day,
          _deadline.hour,
          _deadline.minute,
        );
      });
    }
  }

  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_deadline),
    );
    if (picked != null) {
      setState(() {
        _deadline = DateTime(
          _deadline.year,
          _deadline.month,
          _deadline.day,
          picked.hour,
          picked.minute,
        );
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Assignment'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Assignment Name',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              subjects.isEmpty
                  ? const Text('No subjects found. Please add subjects first.')
                  : DropdownButtonFormField<String>(
                      value: _selectedSubject,
                      decoration: const InputDecoration(
                        labelText: 'Subject',
                        border: OutlineInputBorder(),
                      ),
                      items: subjects.map((subject) {
                        return DropdownMenuItem(
                          value: subject,
                          child: Row(
                            children: [
                              Container(
                                width: 16,
                                height: 16,
                                decoration: BoxDecoration(
                                  color: subjectColors[subject] ?? Colors.grey,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(subject),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _selectedSubject = value;
                          });
                        }
                      },
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please select a subject';
                        }
                        return null;
                      },
                    ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => _selectDate(context),
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Date',
                          border: OutlineInputBorder(),
                        ),
                        child: Text(
                          DateFormat('MMM d, yyyy').format(_deadline),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: InkWell(
                      onTap: () => _selectTime(context),
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Time',
                          border: OutlineInputBorder(),
                        ),
                        child: Text(
                          DateFormat('h:mm a').format(_deadline),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _saveAssignment,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Save Assignment',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
