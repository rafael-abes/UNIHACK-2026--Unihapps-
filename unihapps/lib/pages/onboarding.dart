import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../repositories/user_repositories.dart';
import 'home_page.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class OnboardingPage extends StatefulWidget {
  final String? prefillDisplayName; // from Google sign in
  final String? prefillEmail;

  const OnboardingPage({super.key, this.prefillDisplayName, this.prefillEmail});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final _formKey = GlobalKey<FormState>();
  final _userRepo = UserRepository();
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  late final TextEditingController _firstNameController;
  late final TextEditingController _lastNameController;
  final _usernameController = TextEditingController();

  bool _isLoading = false;
  int _currentStep = 0; // 0 = name/username, 1 = preferences, 2 = schedule

  // Preferences
  static const List<String> _availablePreferences = [
    'Food',
    'Study',
    'Sports',
    'Music',
    'Art',
    'Gaming',
    'Travel',
    'Fitness',
    'Tech',
    'Social',
  ];
  final Set<String> _selectedPreferences = {};

  // Schedule
  static const List<String> _weekdays = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
  ];
  static const Map<String, String> _dayAbbreviations = {
    'Monday': 'mon',
    'Tuesday': 'tues',
    'Wednesday': 'wed',
    'Thursday': 'thurs',
    'Friday': 'fri',
  };
  final Map<String, List<Map<String, String>>> _schedule = {
    'Monday': [],
    'Tuesday': [],
    'Wednesday': [],
    'Thursday': [],
    'Friday': [],
  };

  @override
  void initState() {
    super.initState();
    // Pre-fill name from Google if available
    final nameParts = (widget.prefillDisplayName ?? '').split(' ');
    _firstNameController = TextEditingController(
      text: nameParts.isNotEmpty ? nameParts.first : '',
    );
    _lastNameController = TextEditingController(
      text: nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '',
    );
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  String _formatTime(int hour, int minute) =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  Map<String, List<String>> get _scheduleForModel {
    return _schedule.map(
      (day, blocks) => MapEntry(
        _dayAbbreviations[day]!,
        blocks
            .map((b) => '{"start": "${b['start']}", "end": "${b['end']}"}')
            .toList(),
      ),
    );
  }

  Future<void> _addTimeBlock(String day) async {
    final startHourCtrl = TextEditingController();
    final startMinCtrl = TextEditingController();
    final endHourCtrl = TextEditingController();
    final endMinCtrl = TextEditingController();
    final dialogFormKey = GlobalKey<FormState>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Add block — $day'),
        content: Form(
          key: dialogFormKey,
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Start',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 4),
                    _TimeInputRow(
                      hourCtrl: startHourCtrl,
                      minCtrl: startMinCtrl,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'End',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 4),
                    _TimeInputRow(hourCtrl: endHourCtrl, minCtrl: endMinCtrl),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (dialogFormKey.currentState!.validate()) {
                Navigator.pop(context, true);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final startH = int.parse(startHourCtrl.text);
    final startM = int.parse(startMinCtrl.text);
    final endH = int.parse(endHourCtrl.text);
    final endM = int.parse(endMinCtrl.text);

    if (endH * 60 + endM <= startH * 60 + startM) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('End time must be after start time')),
        );
      }
      return;
    }

    setState(() {
      _schedule[day]!.add({
        'start': _formatTime(startH, startM),
        'end': _formatTime(endH, endM),
      });
    });
  }

  void _removeTimeBlock(String day, int index) {
    setState(() => _schedule[day]!.removeAt(index));
  }

  Future<void> _finish() async {
    setState(() => _isLoading = true);

    // Get FCM token for push notifications
    String token = '';
    try {
      token = await FirebaseMessaging.instance.getToken() ?? '';
      debugPrint('FCM Token: $token');
    } catch (e) {
      debugPrint('FCM token fetch failed: $e');
    }
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final userModel = UserModel(
        id: user.uid,
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        username: _usernameController.text.trim(),
        email: widget.prefillEmail ?? user.email ?? '',
        phone: user.phoneNumber ?? '',
        friends: [],
        friendRequests: [],
        sentRequests: [],
        preferences: _selectedPreferences.toList(),
        schedule: _scheduleForModel,
        status: 'offline',
        fcmToken: token,
      );

      await _userRepo.createUser(userModel);

      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const HomePage()),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error saving profile: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F6FF),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8F6FF),
        elevation: 0,
        automaticallyImplyLeading: false, // no back button
        title: Text(
          _currentStep == 0
              ? 'Your Profile'
              : _currentStep == 1
              ? 'Your Interests'
              : 'Your Availability',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF1A1A2E),
          ),
        ),
      ),
      body: Column(
        children: [
          // Progress indicator
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Row(
              children: List.generate(3, (i) {
                return Expanded(
                  child: Container(
                    height: 4,
                    margin: EdgeInsets.only(right: i < 2 ? 6 : 0),
                    decoration: BoxDecoration(
                      color: i <= _currentStep
                          ? Colors.deepPurple
                          : Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                );
              }),
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: [
                _buildStep0(),
                _buildStep1(),
                _buildStep2(),
              ][_currentStep],
            ),
          ),

          // Bottom navigation
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                if (_currentStep > 0)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => setState(() => _currentStep--),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: const BorderSide(color: Colors.deepPurple),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        'Back',
                        style: TextStyle(color: Colors.deepPurple),
                      ),
                    ),
                  ),
                if (_currentStep > 0) const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleNext,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF5C35C9),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.5,
                            ),
                          )
                        : Text(
                            _currentStep == 2 ? 'Finish' : 'Next',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _handleNext() {
    if (_currentStep == 0) {
      if (!_formKey.currentState!.validate()) return;
      setState(() => _currentStep++);
    } else if (_currentStep == 1) {
      // Preferences optional — just go next
      setState(() => _currentStep++);
    } else {
      // Schedule optional — finish
      _finish();
    }
  }

  // Step 0 — Name + Username (required)
  Widget _buildStep0() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Tell us about yourself',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A2E),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'This is how other UniHapps users will find you',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 32),
          TextFormField(
            controller: _firstNameController,
            decoration: _inputDecoration('First Name'),
            textCapitalization: TextCapitalization.words,
            validator: (v) {
              if (v == null || v.trim().isEmpty)
                return 'First name is required';
              if (v.trim().length < 2) return 'Must be at least 2 characters';
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _lastNameController,
            decoration: _inputDecoration('Last Name'),
            textCapitalization: TextCapitalization.words,
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Last name is required';
              if (v.trim().length < 2) return 'Must be at least 2 characters';
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _usernameController,
            decoration: _inputDecoration('Username'),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Username is required';
              if (v.trim().length < 3) return 'Must be at least 3 characters';
              if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(v.trim()))
                return 'Only letters, numbers, and underscores';
              return null;
            },
          ),
        ],
      ),
    );
  }

  // Step 1 — Preferences (optional)
  Widget _buildStep1() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'What are you into?',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1A1A2E),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Optional — helps us suggest relevant happs',
          style: TextStyle(color: Colors.grey),
        ),
        const SizedBox(height: 32),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _availablePreferences.map((pref) {
            final selected = _selectedPreferences.contains(pref);
            return FilterChip(
              label: Text(pref),
              selected: selected,
              selectedColor: Colors.deepPurple.shade100,
              checkmarkColor: Colors.deepPurple,
              onSelected: (on) {
                setState(() {
                  if (on) {
                    _selectedPreferences.add(pref);
                  } else {
                    _selectedPreferences.remove(pref);
                  }
                });
              },
            );
          }).toList(),
        ),
        if (_selectedPreferences.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            '${_selectedPreferences.length} selected',
            style: const TextStyle(
              color: Colors.deepPurple,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }

  // Step 2 — Schedule (optional)
  Widget _buildStep2() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'When are you free?',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1A1A2E),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Optional — helps friends know when you\'re available',
          style: TextStyle(color: Colors.grey),
        ),
        const SizedBox(height: 32),
        ..._weekdays.map(
          (day) => _DayScheduleTile(
            day: day,
            blocks: _schedule[day]!,
            onAdd: () => _addTimeBlock(day),
            onRemove: (i) => _removeTimeBlock(day, i),
          ),
        ),
      ],
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFF5C35C9), width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
    );
  }
}

// Reusable time input widget
class _TimeInputRow extends StatelessWidget {
  final TextEditingController hourCtrl;
  final TextEditingController minCtrl;

  const _TimeInputRow({required this.hourCtrl, required this.minCtrl});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextFormField(
            controller: hourCtrl,
            decoration: const InputDecoration(
              labelText: 'HH',
              isDense: true,
              counterText: '',
            ),
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            maxLength: 2,
            validator: (v) {
              final n = int.tryParse(v ?? '');
              if (n == null || n < 0 || n > 23) return '0-23';
              return null;
            },
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4),
          child: Text(':', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
        Expanded(
          child: TextFormField(
            controller: minCtrl,
            decoration: const InputDecoration(
              labelText: 'MM',
              isDense: true,
              counterText: '',
            ),
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            maxLength: 2,
            validator: (v) {
              final n = int.tryParse(v ?? '');
              if (n == null || n < 0 || n > 59) return '0-59';
              return null;
            },
          ),
        ),
      ],
    );
  }
}

// Reusable day schedule tile
class _DayScheduleTile extends StatelessWidget {
  final String day;
  final List<Map<String, String>> blocks;
  final VoidCallback onAdd;
  final void Function(int index) onRemove;

  const _DayScheduleTile({
    required this.day,
    required this.blocks,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            SizedBox(
              width: 100,
              child: Text(
                day,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
            if (blocks.isEmpty)
              const Text(
                'No blocks',
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
            ...blocks.asMap().entries.map(
              (entry) => Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Chip(
                  label: Text(
                    '${entry.value['start']}-${entry.value['end']}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  onDeleted: () => onRemove(entry.key),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.add_circle_outline, size: 20),
              onPressed: onAdd,
            ),
          ],
        ),
        const Divider(height: 8),
      ],
    );
  }
}
