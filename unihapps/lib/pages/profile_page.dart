import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io';
import '../services/profile_pic_service.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  File? _selectedImage;
  bool _isUploadingPhoto = false;
  final ProfilePictureService _profilePicService = ProfilePictureService();

  bool _invisibleMode = false;
  String _status = 'Available';
  Map<String, dynamic>? _userData;
  bool _isLoading = true;

  final List<String> _statusOptions = [
    'Available',
    'Busy',
    'Away',
    'Do Not Disturb',
  ];

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      setState(() => _isLoading = false);
      return;
    }

    final doc = await _firestore.collection('users').doc(uid).get();
    if (!mounted) return;

    // Patch missing fields
    if (doc.exists) {
      final data = doc.data() ?? {};
      if (!data.containsKey('status') || !data.containsKey('invisibleMode')) {
        await _firestore.collection('users').doc(uid).set({
          'status': 'Available',
          'invisibleMode': false,
        }, SetOptions(merge: true));
      }
    }

    setState(() {
      _userData = doc.data();
      _status = _userData?['status'] ?? 'Available';
      _invisibleMode = _userData?['invisibleMode'] ?? false;
      _isLoading = false;
    });
  }

  Future<void> _updateStatus(String status) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    setState(() => _status = status);
    await _firestore.collection('users').doc(uid).set({
      'status': status,
    }, SetOptions(merge: true));
  }

  Future<void> _toggleInvisibleMode(bool value) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    setState(() => _invisibleMode = value);
    await _firestore.collection('users').doc(uid).set({
      'invisibleMode': value,
    }, SetOptions(merge: true));
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'Available':
        return Colors.green;
      case 'Busy':
        return Colors.red;
      case 'Away':
        return Colors.orange;
      case 'Do Not Disturb':
        return Colors.grey;
      default:
        return Colors.green;
    }
  }

  void _showImagePickerOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Text(
              'Profile Photo',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A2E),
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.deepPurple.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.photo_library,
                  color: Colors.deepPurple,
                ),
              ),
              title: const Text('Choose from Gallery'),
              onTap: () async {
                Navigator.pop(ctx);
                await _pickAndUpload(fromCamera: false);
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.camera_alt, color: Colors.blue),
              ),
              title: const Text('Take a Photo'),
              onTap: () async {
                Navigator.pop(ctx);
                await _pickAndUpload(fromCamera: true);
              },
            ),
            if (_userData?['photoURL'] != null &&
                (_userData?['photoURL'] as String).isNotEmpty)
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.delete_outline,
                    color: Colors.redAccent,
                  ),
                ),
                title: const Text(
                  'Remove Photo',
                  style: TextStyle(color: Colors.redAccent),
                ),
                onTap: () async {
                  Navigator.pop(ctx);
                  await _removePhoto();
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAndUpload({required bool fromCamera}) async {
    try {
      final file = await _profilePicService.pickImage(fromCamera: fromCamera);
      if (file == null) return;

      setState(() {
        _selectedImage = file;
        _isUploadingPhoto = true;
      });

      final url = await _profilePicService.uploadProfilePicture(file);

      if (!mounted) return;
      setState(() {
        _userData?['photoURL'] = url;
        _isUploadingPhoto = false;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Profile photo updated!')));
    } catch (e) {
      if (!mounted) return;
      setState(() => _isUploadingPhoto = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to update photo: $e')));
    }
  }

  Future<void> _removePhoto() async {
    try {
      setState(() => _isUploadingPhoto = true);
      await _profilePicService.deleteProfilePicture();
      if (!mounted) return;
      setState(() {
        _userData?['photoURL'] = '';
        _selectedImage = null;
        _isUploadingPhoto = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Profile photo removed')));
    } catch (e) {
      if (!mounted) return;
      setState(() => _isUploadingPhoto = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;
    final firstName = _userData?['firstName'] ?? '';
    final lastName = _userData?['lastName'] ?? '';
    final displayName = '$firstName $lastName'.trim().isNotEmpty
        ? '$firstName $lastName'.trim()
        : user?.displayName ?? 'User';
    final initials = displayName
        .split(' ')
        .where((String e) => e.isNotEmpty)
        .map((String e) => e[0].toUpperCase())
        .take(2)
        .join();

    return Scaffold(
      backgroundColor: const Color(0xFFF8F6FF),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 24,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Back button
                    Align(
                      alignment: Alignment.centerLeft,
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new_rounded),
                        color: const Color(0xFF1A1A2E),
                        onPressed: () => Navigator.pop(context),
                        padding: EdgeInsets.zero,
                      ),
                    ),

                    // Avatar
                    GestureDetector(
                      onTap: _showImagePickerOptions,
                      child: Stack(
                        children: [
                          CircleAvatar(
                            radius: 52,
                            backgroundColor: const Color(0xFFF4C5C5),
                            backgroundImage: _selectedImage != null
                                ? FileImage(_selectedImage!)
                                : (_userData?['photoURL'] != null &&
                                              (_userData!['photoURL'] as String)
                                                  .isNotEmpty
                                          ? NetworkImage(
                                              _userData!['photoURL'] as String,
                                            )
                                          : null)
                                      as ImageProvider?,
                            child:
                                _selectedImage == null &&
                                    (_userData?['photoURL'] == null ||
                                        (_userData!['photoURL'] as String)
                                            .isEmpty)
                                ? Text(
                                    initials.isNotEmpty ? initials : '?',
                                    style: const TextStyle(
                                      fontSize: 32,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF1A1A2E),
                                    ),
                                  )
                                : null,
                          ),
                          if (_isUploadingPhoto)
                            Positioned.fill(
                              child: CircleAvatar(
                                radius: 52,
                                backgroundColor: Colors.black.withOpacity(0.4),
                                child: const CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              ),
                            ),
                          if (!_isUploadingPhoto)
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: const BoxDecoration(
                                  color: Color.fromARGB(255, 74, 152, 88),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.camera_alt,
                                  color: Colors.white,
                                  size: 16,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Name
                    Text(
                      displayName,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A1A2E),
                      ),
                    ),

                    const SizedBox(height: 6),

                    // Status row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: _statusColor(_status),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _status,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Invisible Mode + Change Status
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Row(
                        children: [
                          Switch(
                            value: _invisibleMode,
                            onChanged: _toggleInvisibleMode,
                            activeColor: const Color(0xFF5C35C9),
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                          ),
                          const SizedBox(width: 4),
                          const Text(
                            'Invisible Mode',
                            style: TextStyle(
                              fontSize: 14,
                              color: Color(0xFF1A1A2E),
                            ),
                          ),
                          const Spacer(),
                          PopupMenuButton<String>(
                            onSelected: _updateStatus,
                            itemBuilder: (context) => _statusOptions
                                .map(
                                  (s) =>
                                      PopupMenuItem(value: s, child: Text(s)),
                                )
                                .toList(),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Change Status',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                                Icon(
                                  Icons.arrow_drop_down,
                                  color: Colors.grey.shade600,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 28),

                    // Menu items
                    _buildMenuItem(
                      icon: Icons.home_outlined,
                      label: 'My Profile',
                      onTap: () {},
                    ),
                    const SizedBox(height: 12),
                    _buildMenuItem(
                      icon: Icons.notifications_outlined,
                      label: 'Notifications',
                      onTap: () {},
                    ),
                    const SizedBox(height: 12),
                    _buildMenuItem(
                      icon: Icons.calendar_today_outlined,
                      label: 'Schedule',
                      onTap: () {},
                    ),
                    const SizedBox(height: 12),
                    _buildMenuItem(
                      icon: Icons.edit_outlined,
                      label: 'Preferences',
                      onTap: () {},
                    ),
                    const SizedBox(height: 12),
                    _buildMenuItem(
                      icon: Icons.menu,
                      label: 'Settings',
                      onTap: () {},
                    ),
                    const SizedBox(height: 12),
                    _buildMenuItem(
                      icon: Icons.logout,
                      label: 'Log Out',
                      onTap: () async {
                        await FirebaseAuth.instance.signOut();
                      },
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: const Color(0xFFEEECEC),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: Colors.grey.shade600, size: 22),
            ),
            const SizedBox(width: 16),
            Text(
              label,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1A1A2E),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
