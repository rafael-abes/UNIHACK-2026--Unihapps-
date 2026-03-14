import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final _formKey = GlobalKey<FormState>();
  bool _obscurePassword = true;

  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

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
                    const Text('Start', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: 4),
                    _TimeInputRow(hourCtrl: startHourCtrl, minCtrl: startMinCtrl),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('End', style: TextStyle(fontSize: 12, color: Colors.grey)),
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

  /// Converts the local schedule state into Map<String, List<String>> for the model.
  /// Each time block becomes a "HH:MM-HH:MM" string.
  Map<String, List<String>> get _scheduleForModel {
    return _schedule.map(
      (day, blocks) => MapEntry(
        day.toLowerCase(),
        blocks.map((b) => '${b['start']}-${b['end']}').toList(),
      ),
    );
  }

  void _submit() {
    setState(() {
      _preferenceError = _selectedPreferences.isEmpty;
    });

    if (_formKey.currentState!.validate() && !_preferenceError) {
      // TODO: handle sign up — use _selectedPreferences.toList() and _scheduleForModel
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sign Up')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _firstNameController,
                decoration: const InputDecoration(labelText: 'First Name'),
                textCapitalization: TextCapitalization.words,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'First name is required';
                  if (v.trim().length < 2) return 'Must be at least 2 characters';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _lastNameController,
                decoration: const InputDecoration(labelText: 'Last Name'),
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
                decoration: const InputDecoration(labelText: 'Username'),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Username is required';
                  if (v.trim().length < 3) return 'Must be at least 3 characters';
                  if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(v.trim())) {
                    return 'Only letters, numbers, and underscores allowed';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'Email'),
                keyboardType: TextInputType.emailAddress,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Email is required';
                  if (!RegExp(r'^[\w.+\-]+@[\w\-]+\.[a-zA-Z]{2,}$').hasMatch(v.trim())) {
                    return 'Enter a valid email address';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                decoration: InputDecoration(
                  labelText: 'Password',
                  suffixIcon: IconButton(
                    icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
                obscureText: _obscurePassword,
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Password is required';
                  if (v.length < 8) return 'Must be at least 8 characters';
                  if (!RegExp(r'[A-Z]').hasMatch(v)) return 'Must contain an uppercase letter';
                  if (!RegExp(r'[0-9]').hasMatch(v)) return 'Must contain a number';
                  return null;
                },
              ),

              // ── Preferences ──────────────────────────────────────────────
              const SizedBox(height: 32),
              Text('Preferences', style: Theme.of(context).textTheme.titleMedium),
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
              Text('Availability', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              const Text(
                'Add your available time blocks (24-hour format)',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 8),
              ..._weekdays.map((day) => _DayScheduleTile(
                    day: day,
                    blocks: _schedule[day]!,
                    onAdd: () => _addTimeBlock(day),
                    onRemove: (i) => _removeTimeBlock(day, i),
                  )),

              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _submit,
                  child: const Text('Create Account'),
                ),
              ),
            ],
          ),
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
              child: Text(day, style: const TextStyle(fontWeight: FontWeight.w500)),
            ),
            if (blocks.isEmpty)
              const Text('No blocks', style: TextStyle(color: Colors.grey, fontSize: 13)),
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
