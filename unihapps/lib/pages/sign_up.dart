import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_services.dart';
import 'phone_login.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../repositories/user_repositories.dart';
import 'friends_list.dart';
import 'home_page.dart';
import 'package:flutter/services.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final _formKey = GlobalKey<FormState>();
  final UserRepository _userRepository = UserRepository();
  bool _obscurePassword = true;
  bool _isLoading = false;

  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  final AuthService _authService = AuthService();

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
  bool _preferenceError = false;

  // Schedule: day -> list of {start, end} maps
  static const List<String> _weekdays = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
  ];
  final Map<String, List<Map<String, String>>> _schedule = {
    'Monday': [],
    'Tuesday': [],
    'Wednesday': [],
    'Thursday': [],
    'Friday': [],
  };

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String _formatTime(int hour, int minute) {
    return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
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
    setState(() {
      _schedule[day]!.removeAt(index);
    });
  }

  static const Map<String, String> _dayAbbreviations = {
    'Monday': 'mon',
    'Tuesday': 'tues',
    'Wednesday': 'wed',
    'Thursday': 'thurs',
    'Friday': 'fri',
  };

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

  // Email sign up
  Future<void> _submit() async {
    print("=== SUBMIT PRESSED ==="); // ← add here
    if (!_formKey.currentState!.validate()) {
      print("=== VALIDATION FAILED ==="); // ← add here
      return;
    }
    setState(() => _isLoading = true);
    try {
      final credential = await _authService.signUpWithEmail(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        displayName:
            '${_firstNameController.text.trim()} ${_lastNameController.text.trim()}',
      );
      final uid = credential.user?.uid;
      if (uid != null) {
        final token =
            await FirebaseMessaging.instance.getToken() ?? ''; // ← move here
        print("FCM Token: $token");
        final user = UserModel(
          id: uid,
          firstName: _firstNameController.text.trim(),
          lastName: _lastNameController.text.trim(),
          username: _usernameController.text.trim(),
          email: _emailController.text.trim(),
          phone: '',
          friends: [],
          friendRequests: [],
          sentRequests: [],
          preferences: _selectedPreferences.toList(),
          schedule: _scheduleForModel,
          status: 'offline',
          fcmToken: token, // ← add this
        );
        await _userRepository.createUser(user);
        print("User saved to Firestore!");
      }
      // AuthWrapper stream handles navigation automatically
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message ?? 'Sign up failed')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Google sign in
  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);
    try {
      await _authService.signInWithGoogle();
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const HomePage()),
        (route) => false,
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sign Up')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // ── Email/Password Form ──
            Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    controller: _firstNameController,
                    decoration: const InputDecoration(labelText: 'First Name'),
                    textCapitalization: TextCapitalization.words,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty)
                        return 'First name is required';
                      if (v.trim().length < 2)
                        return 'Must be at least 2 characters';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _lastNameController,
                    decoration: const InputDecoration(labelText: 'Last Name'),
                    textCapitalization: TextCapitalization.words,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty)
                        return 'Last name is required';
                      if (v.trim().length < 2)
                        return 'Must be at least 2 characters';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _usernameController,
                    decoration: const InputDecoration(labelText: 'Username'),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty)
                        return 'Username is required';
                      if (v.trim().length < 3)
                        return 'Must be at least 3 characters';
                      if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(v.trim()))
                        return 'Only letters, numbers, and underscores allowed';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _emailController,
                    decoration: const InputDecoration(labelText: 'Email'),
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty)
                        return 'Email is required';
                      if (!RegExp(
                        r'^[\w.+\-]+@[\w\-]+\.[a-zA-Z]{2,}$',
                      ).hasMatch(v.trim()))
                        return 'Enter a valid email address';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passwordController,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                        ),
                        onPressed: () => setState(
                          () => _obscurePassword = !_obscurePassword,
                        ),
                      ),
                    ),
                    obscureText: _obscurePassword,
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Password is required';
                      if (v.length < 8) return 'Must be at least 8 characters';
                      if (!RegExp(r'[A-Z]').hasMatch(v))
                        return 'Must contain an uppercase letter';
                      if (!RegExp(r'[0-9]').hasMatch(v))
                        return 'Must contain a number';
                      return null;
                    },
                  ),

                  // ── Preferences ──────────────────────────────────────────────
                  const SizedBox(height: 32),
                  Text(
                    'Preferences',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Select one or more interests',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: _availablePreferences.map((pref) {
                      final selected = _selectedPreferences.contains(pref);
                      return FilterChip(
                        label: Text(pref),
                        selected: selected,
                        onSelected: (on) {
                          setState(() {
                            if (on) {
                              _selectedPreferences.add(pref);
                            } else {
                              _selectedPreferences.remove(pref);
                            }
                            _preferenceError = _selectedPreferences.isEmpty;
                          });
                        },
                      );
                    }).toList(),
                  ),
                  if (_preferenceError)
                    const Padding(
                      padding: EdgeInsets.only(top: 6, left: 12),
                      child: Text(
                        'Please select at least one preference',
                        style: TextStyle(color: Colors.red, fontSize: 12),
                      ),
                    ),

                  // ── Schedule ─────────────────────────────────────────────────
                  const SizedBox(height: 32),
                  Text(
                    'Availability',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Add your available time blocks (24-hour format)',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  ..._weekdays.map(
                    (day) => _DayScheduleTile(
                      day: day,
                      blocks: _schedule[day]!,
                      onAdd: () => _addTimeBlock(day),
                      onRemove: (i) => _removeTimeBlock(day, i),
                    ),
                  ),

                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _submit,
                      child: _isLoading
                          ? const CircularProgressIndicator()
                          : const Text('Create Account'),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ── Divider ──
            const Row(
              children: [
                Expanded(child: Divider()),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    'or continue with',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
                Expanded(child: Divider()),
              ],
            ),

            const SizedBox(height: 24),

            // ── Google Sign In ──
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _isLoading ? null : _signInWithGoogle,
                icon: const Icon(Icons.g_mobiledata, size: 28),
                label: const Text('Continue with Google'),
              ),
            ),

            const SizedBox(height: 12),

            // ── Phone Sign In ──
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _isLoading
                    ? null
                    : () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const PhoneLoginPage(),
                        ),
                      ),
                icon: const Icon(Icons.phone),
                label: const Text('Continue with Phone'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

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
              tooltip: 'Add time block',
              onPressed: onAdd,
            ),
          ],
        ),
        const Divider(height: 8),
      ],
    );
  }
}
