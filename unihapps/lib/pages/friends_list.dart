import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'home_page.dart';
import 'profile_page.dart';

// Top-level function for compute() — must be outside the class
List<String> _extractPhoneNumbers(List<Contact> contacts) {
  return contacts
      .expand((c) => c.phones.map((p) {
            String number = p.number.replaceAll(RegExp(r'\s|-|\(|\)'), '');
            if (number.startsWith('0')) {
              number = '+61${number.substring(1)}';
            }
            return number;
          }))
      .toSet()
      .toList();
}

class FriendsPage extends StatefulWidget {
  const FriendsPage({super.key});

  @override
  State<FriendsPage> createState() => _FriendsPageState();
}

class _FriendsPageState extends State<FriendsPage> {
  final _searchController = TextEditingController();
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  List<Map<String, dynamic>> _searchResults = [];
  List<Map<String, dynamic>> _contactMatches = [];
  List<String> _friendIds = [];

  bool _isSearching = false;
  bool _hasSearched = false;
  bool _isSyncingContacts = false;

  @override
  void initState() {
    super.initState();
    _loadFriendIds();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadFriendIds() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    final doc = await _firestore.collection('users').doc(uid).get();
    if (!mounted) return;

    setState(() {
      _friendIds = List<String>.from(doc.data()?['friends'] ?? []);
    });
  }

  Future<void> _searchByUsername(String query) async {
    if (query.trim().isEmpty) {
      if (!mounted) return;
      setState(() {
        _searchResults = [];
        _hasSearched = false;
      });
      return;
    }

    if (!mounted) return;
    setState(() {
      _isSearching = true;
      _hasSearched = true;
    });

    final currentUid = _auth.currentUser?.uid;

    final result = await _firestore
        .collection('users')
        .where('username', isGreaterThanOrEqualTo: query.trim())
        .where('username', isLessThanOrEqualTo: '${query.trim()}\uf8ff')
        .limit(10)
        .get();

    final results = result.docs
        .where((doc) => doc.id != currentUid)
        .map((doc) => {'uid': doc.id, ...doc.data()})
        .toList();

    if (!mounted) return;
    setState(() {
      _searchResults = results;
      _isSearching = false;
    });
  }

  Future<void> _addFriend(String friendUid) async {
    final currentUid = _auth.currentUser?.uid;
    if (currentUid == null) return;

    await _firestore.collection('users').doc(currentUid).set(
      {'friends': FieldValue.arrayUnion([friendUid])},
      SetOptions(merge: true),
    );
    await _firestore.collection('users').doc(friendUid).set(
      {'friends': FieldValue.arrayUnion([currentUid])},
      SetOptions(merge: true),
    );

    if (!mounted) return;
    setState(() => _friendIds.add(friendUid));

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Friend added!')),
    );
  }

  Future<void> _syncContacts() async {
    if (!mounted) return;
    setState(() => _isSyncingContacts = true);

    final status = await Permission.contacts.status;

    if (status.isPermanentlyDenied) {
      if (!mounted) return;
      setState(() => _isSyncingContacts = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Enable contacts permission in settings'),
          action: SnackBarAction(
            label: 'Open Settings',
            onPressed: () => openAppSettings(),
          ),
        ),
      );
      return;
    }

    if (status.isDenied) {
      final result = await Permission.contacts.request();
      if (!result.isGranted) {
        if (!mounted) return;
        setState(() => _isSyncingContacts = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Contacts permission denied')),
        );
        return;
      }
    }

    try {
      final contacts = await FlutterContacts.getContacts(withProperties: true);
      final phoneNumbers = await compute(_extractPhoneNumbers, contacts);

      if (phoneNumbers.isEmpty) {
        if (!mounted) return;
        setState(() => _isSyncingContacts = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No phone numbers found in contacts')),
        );
        return;
      }

      final currentUid = _auth.currentUser?.uid;
      final List<Map<String, dynamic>> matches = [];

      for (int i = 0; i < phoneNumbers.length; i += 10) {
        final batch = phoneNumbers.sublist(
          i,
          i + 10 > phoneNumbers.length ? phoneNumbers.length : i + 10,
        );

        final result = await _firestore
            .collection('users')
            .where('phone', whereIn: batch)
            .get();

        matches.addAll(result.docs
            .where((doc) => doc.id != currentUid)
            .map((doc) => {'uid': doc.id, ...doc.data()}));
      }

      if (!mounted) return;
      setState(() {
        _contactMatches = matches;
        _isSyncingContacts = false;
      });

      if (matches.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No contacts found on UniHapps yet')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSyncingContacts = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error syncing contacts: $e')),
      );
    }
  }

  List<Map<String, dynamic>> get _displayList =>
      _hasSearched ? _searchResults : _contactMatches;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      size: 20,
                      color: Color(0xFF1A1A2E),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Add Friends',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1A2E),
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: _isSyncingContacts ? null : _syncContacts,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: _isSyncingContacts
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text(
                              'Link Contacts',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF1A1A2E),
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),

            // Search bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: TextField(
                controller: _searchController,
                onChanged: _searchByUsername,
                decoration: InputDecoration(
                  hintText: 'Search',
                  hintStyle: TextStyle(color: Colors.grey.shade400),
                  prefixIcon: Icon(
                    Icons.search,
                    color: Colors.grey.shade400,
                    size: 20,
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),

            // Body
            Expanded(child: _buildBody()),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 0,
        backgroundColor: Colors.white,
        elevation: 8,
        selectedItemColor: const Color(0xFF3DB54A),
        unselectedItemColor: Colors.black,
        onTap: (index) {
          if (index == 1) {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => const HomePage()),
              (route) => false,
            );
          } else if (index == 2) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ProfilePage()),
            );
          }
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.people_outline),
            activeIcon: Icon(Icons.people),
            label: 'Friends',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.celebration_outlined),
            activeIcon: Icon(Icons.celebration),
            label: 'Happs',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Me',
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isSearching) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_hasSearched && _searchResults.isEmpty) {
      return Center(
        child: Text(
          'No users found',
          style: TextStyle(color: Colors.grey.shade400, fontSize: 15),
        ),
      );
    }

    if (_displayList.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Text(
            _hasSearched ? 'Results' : 'You May Know',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1A1A2E),
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: _displayList.length,
            itemBuilder: (context, index) =>
                _buildUserTile(_displayList[index]),
          ),
        ),
      ],
    );
  }

  Widget _buildUserTile(Map<String, dynamic> user) {
    final firstName = user['firstName'] ?? '';
    final lastName = user['lastName'] ?? '';
    final displayName = '$firstName $lastName'.trim();
    final username = user['username'] ?? '';
    final label =
        displayName.isNotEmpty ? displayName : username;
    final initials = label.isNotEmpty
        ? label
            .split(' ')
            .where((String e) => e.isNotEmpty)
            .map((String e) => e[0].toUpperCase())
            .take(2)
            .join()
        : '?';
    final alreadyFriend = _friendIds.contains(user['uid']);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          // Avatar
          CircleAvatar(
            radius: 26,
            backgroundColor: Colors.deepPurple.shade100,
            backgroundImage: user['photoURL'] != null
                ? NetworkImage(user['photoURL'])
                : null,
            child: user['photoURL'] == null
                ? Text(
                    initials,
                    style: const TextStyle(
                      color: Colors.deepPurple,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 14),

          // Name
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1A1A2E),
              ),
            ),
          ),

          // Request / Friends button
          alreadyFriend
              ? Text(
                  'Friends',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade500,
                    fontWeight: FontWeight.w500,
                  ),
                )
              : GestureDetector(
                  onTap: () => _addFriend(user['uid']),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.add_circle_outline,
                        size: 20,
                        color: Colors.grey.shade600,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Request',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
        ],
      ),
    );
  }
}
