import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';

// Top-level function for compute() — must be outside the class
List<String> _extractPhoneNumbers(List<Contact> contacts) {
  return contacts
      .expand((c) =>
          c.phones.map((p) => p.number.replaceAll(RegExp(r'\s|-|\(|\)'), '')))
      .toSet()
      .toList();
}

class FriendsPage extends StatefulWidget {
  const FriendsPage({super.key});

  @override
  State<FriendsPage> createState() => _FriendsPageState();
}

class _FriendsPageState extends State<FriendsPage>
    with SingleTickerProviderStateMixin {
  final _searchController = TextEditingController();
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  List<Map<String, dynamic>> _searchResults = [];
  List<Map<String, dynamic>> _contactMatches = [];

  bool _isSearching = false;
  bool _isSyncingContacts = false;
  bool _hasSearched = false;
  bool _isLoadingFriends = true;

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  // Search users by username
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

  // Add friend
  Future<void> _addFriend(String friendUid) async {
    final currentUid = _auth.currentUser?.uid;
    if (currentUid == null) return;

    await _firestore.collection('users').doc(currentUid).set({
      'friends': FieldValue.arrayUnion([friendUid]),
    }, SetOptions(merge: true));

    await _firestore.collection('users').doc(friendUid).set({
      'friends': FieldValue.arrayUnion([currentUid]),
    }, SetOptions(merge: true));

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Friend added!')),
    );
  }

  // Sync contacts
  Future<void> _syncContacts() async {
    if (!mounted) return;
    setState(() => _isSyncingContacts = true);

    // Check current permission status
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

    // Permission granted — fetch contacts
    try {
      final contacts =
          await FlutterContacts.getContacts(withProperties: true);

      // Process off main thread
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

      // Batch in groups of 10 — Firestore whereIn limit
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

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(matches.isEmpty
              ? 'No contacts found on UniHapps yet'
              : '${matches.length} contact(s) found on UniHapps!'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSyncingContacts = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error syncing contacts: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F6FF),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8F6FF),
        elevation: 0,
        title: const Text(
          'Friends',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 24,
            color: Color(0xFF1A1A2E),
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.deepPurple,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Colors.deepPurple,
          tabs: const [
            Tab(text: 'Find Friends'),
            Tab(text: 'My Friends'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildFindFriendsTab(),
          _buildMyFriendsTab(),
        ],
      ),
    );
  }

  Widget _buildFindFriendsTab() {
    return Column(
      children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _searchController,
            onChanged: _searchByUsername,
            decoration: InputDecoration(
              hintText: 'Search by username...',
              prefixIcon:
                  const Icon(Icons.search, color: Colors.deepPurple),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        _searchByUsername('');
                      },
                    )
                  : null,
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(
                    color: Colors.deepPurple, width: 1.5),
              ),
            ),
          ),
        ),

        // Sync contacts button
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _isSyncingContacts ? null : _syncContacts,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                side: const BorderSide(color: Colors.deepPurple),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: _isSyncingContacts
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.contacts, color: Colors.deepPurple),
              label: Text(
                _isSyncingContacts ? 'Syncing...' : 'Sync Contacts',
                style: const TextStyle(color: Colors.deepPurple),
              ),
            ),
          ),
        ),

        const SizedBox(height: 16),

        Expanded(child: _buildSearchResults()),
      ],
    );
  }

  Widget _buildSearchResults() {
    // Contact matches after sync
    if (!_hasSearched && _contactMatches.isNotEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'People you may know',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Color(0xFF1A1A2E),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              itemCount: _contactMatches.length,
              itemBuilder: (context, index) =>
                  _buildUserTile(_contactMatches[index]),
            ),
          ),
        ],
      );
    }

    if (_isSearching) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_hasSearched && _searchResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.person_search, size: 64, color: Colors.grey),
            const SizedBox(height: 12),
            Text(
              'No users found for "${_searchController.text}"',
              style: const TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    if (_searchResults.isNotEmpty) {
      return ListView.builder(
        itemCount: _searchResults.length,
        itemBuilder: (context, index) =>
            _buildUserTile(_searchResults[index]),
      );
    }

    // Default empty state
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.group_add, size: 64, color: Colors.deepPurple),
          SizedBox(height: 12),
          Text(
            'Search for friends by username\nor sync your contacts',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey, fontSize: 15),
          ),
        ],
      ),
    );
  }

  // My Friends tab — uses StreamBuilder for live updates
  Widget _buildMyFriendsTab() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return const SizedBox();

    return StreamBuilder<DocumentSnapshot>(
      stream: _firestore.collection('users').doc(uid).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final friendIds =
            List<String>.from(snapshot.data?.get('friends') ?? []);

        if (friendIds.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.people_outline, size: 64, color: Colors.grey),
                SizedBox(height: 12),
                Text(
                  'No friends yet\nSearch to add some!',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey, fontSize: 15),
                ),
              ],
            ),
          );
        }

        return FutureBuilder<List<Map<String, dynamic>>>(
          future: Future.wait(
            friendIds.map((id) => _firestore
                .collection('users')
                .doc(id)
                .get()
                .then((doc) => {'uid': doc.id, ...?doc.data()})),
          ),
          builder: (context, friendsSnapshot) {
            if (friendsSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final friends = friendsSnapshot.data ?? [];

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: friends.length,
              itemBuilder: (context, index) =>
                  _buildUserTile(friends[index], showAddButton: false),
            );
          },
        );
      },
    );
  }

  Widget _buildUserTile(
    Map<String, dynamic> user, {
    bool showAddButton = true,
  }) {
    final uid = _auth.currentUser?.uid;
    final displayName =
        '${user['firstName'] ?? ''} ${user['lastName'] ?? ''}'.trim();
    final username = user['username'] ?? '';
    final initials = displayName.isNotEmpty
        ? displayName.split(' ').map((e) => e[0]).take(2).join()
        : '?';

    return StreamBuilder<DocumentSnapshot>(
      stream: uid != null
          ? _firestore.collection('users').doc(uid).snapshots()
          : const Stream.empty(),
      builder: (context, snapshot) {
        final friendIds =
            List<String>.from(snapshot.data?.get('friends') ?? []);
        final alreadyFriend = friendIds.contains(user['uid']);

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.deepPurple.withOpacity(0.06),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: CircleAvatar(
              radius: 24,
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
            title: Text(
              displayName.isNotEmpty ? displayName : username,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              '@$username',
              style: const TextStyle(color: Colors.grey, fontSize: 13),
            ),
            trailing: showAddButton
                ? alreadyFriend
                    ? const Chip(
                        label: Text('Friends',
                            style: TextStyle(color: Colors.deepPurple)),
                        backgroundColor: Color(0xFFEDE7F6),
                      )
                    : ElevatedButton(
                        onPressed: () => _addFriend(user['uid']),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepPurple,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding:
                              const EdgeInsets.symmetric(horizontal: 16),
                        ),
                        child: const Text('Add'),
                      )
                : null,
          ),
        );
      },
    );
  }
}

