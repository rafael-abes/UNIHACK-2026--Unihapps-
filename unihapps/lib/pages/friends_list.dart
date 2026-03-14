import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';
import '../repositories/user_repositories.dart';
import 'home_page.dart';
import 'profile_page.dart';

// Top-level function for compute()
List<String> _extractPhoneNumbers(List<Contact> contacts) {
  return contacts
      .expand(
        (c) => c.phones.map((p) {
          String number = p.number.replaceAll(RegExp(r'\s|-|\(|\)'), '');
          if (number.startsWith('0')) {
            number = '+61${number.substring(1)}';
          }
          return number;
        }),
      )
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
  final _userRepo = UserRepository();

  List<Map<String, dynamic>> _searchResults = [];
  List<Map<String, dynamic>> _contactMatches = [];
  List<String> _friendIds = [];
  List<String> _sentRequestIds = []; // ← track sent requests
  List<String> _incomingRequestIds = []; // ← track incoming requests

  bool _isSearching = false;
  bool _hasSearched = false;
  bool _isSyncingContacts = false;
  bool _hasSearched = false;

  Timer? _debounceTimer;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this); // ← 3 tabs now
    _loadUserData();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    final doc = await _firestore.collection('users').doc(uid).get();
    if (!mounted) return;

    if (doc.exists) {
      setState(() {
        _friendIds = List<String>.from(doc.data()?['friends'] ?? []);
        _sentRequestIds = List<String>.from(doc.data()?['sentRequests'] ?? []);
        _incomingRequestIds = List<String>.from(
          doc.data()?['friendRequests'] ?? [],
        );
      });
    }
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

  // Send friend request
  Future<void> _sendFriendRequest(String targetUid) async {
    final currentUid = _auth.currentUser?.uid;
    if (currentUid == null) return;

    await _userRepo.sendFriendRequest(currentUid, targetUid);

    if (!mounted) return;
    setState(() => _sentRequestIds.add(targetUid));

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Friend request sent!')));
  }

  // Cancel sent request
  Future<void> _cancelRequest(String targetUid) async {
    final currentUid = _auth.currentUser?.uid;
    if (currentUid == null) return;

    await _userRepo.cancelFriendRequest(currentUid, targetUid);

    if (!mounted) return;
    setState(() => _sentRequestIds.remove(targetUid));

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Friend request cancelled')));
  }

  // Accept incoming request
  Future<void> _acceptRequest(String requesterUid) async {
    final currentUid = _auth.currentUser?.uid;
    if (currentUid == null) return;

    await _userRepo.acceptFriendRequest(currentUid, requesterUid);

    if (!mounted) return;
    setState(() {
      _incomingRequestIds.remove(requesterUid);
      _friendIds.add(requesterUid);
    });

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Friend request accepted!')));
  }

  // Decline incoming request
  Future<void> _declineRequest(String requesterUid) async {
    final currentUid = _auth.currentUser?.uid;
    if (currentUid == null) return;

    await _userRepo.declineFriendRequest(currentUid, requesterUid);

    if (!mounted) return;
    setState(() => _incomingRequestIds.remove(requesterUid));

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Friend request declined')));
  }

  Future<void> _syncContacts() async {
    if (!mounted) return;
    setState(() => _isSyncingContacts = true);

    try {
      final status = await Permission.contacts.request();

      if (!status.isGranted) {
        if (!mounted) return;
        setState(() => _isSyncingContacts = false);
        if (status.isPermanentlyDenied) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Enable contacts in settings'),
              action: SnackBarAction(
                label: 'Open Settings',
                onPressed: () => openAppSettings(),
              ),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Contacts permission denied')),
          );
        }
        return;
      }

      final contacts = await FlutterContacts.getContacts(
        withProperties: true,
        withPhoto: false,
        withGroups: false,
        withAccounts: false,
      );

      if (contacts.isEmpty) {
        if (!mounted) return;
        setState(() => _isSyncingContacts = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No contacts found on device')),
        );
        return;
      }

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

        matches.addAll(
          result.docs
              .where((doc) => doc.id != currentUid)
              .map((doc) => {'uid': doc.id, ...doc.data()}),
        );
      }

      if (!mounted) return;
      setState(() {
        _contactMatches = matches;
        _isSyncingContacts = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            matches.isEmpty
                ? 'No contacts found on UniHapps yet'
                : '${matches.length} contact(s) found on UniHapps!',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSyncingContacts = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error syncing contacts: $e')));
    }
  }

  List<Map<String, dynamic>> get _displayList =>
      _hasSearched ? _searchResults : _contactMatches;

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
          tabs: [
            const Tab(text: 'Find Friends'),
            const Tab(text: 'My Friends'),
            // Show badge on requests tab if incoming requests exist
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Requests'),
                  if (_incomingRequestIds.isNotEmpty) ...[
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.redAccent,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${_incomingRequestIds.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildFindFriendsTab(),
          _buildMyFriendsTab(),
          _buildRequestsTab(), // ← new tab
        ],
      ),
    );
  }

  Widget _buildFindFriendsTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _searchController,
            onChanged: (value) {
              _debounceTimer?.cancel();
              _debounceTimer = Timer(
                const Duration(milliseconds: 500),
                () => _searchByUsername(value),
              );
            },
            decoration: InputDecoration(
              hintText: 'Search by username...',
              prefixIcon: const Icon(Icons.search, color: Colors.deepPurple),
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
                  color: Colors.deepPurple,
                  width: 1.5,
                ),
              ),
            ),
          ),
        ),
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

  Widget _buildBody() {
    if (_isSearching) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_hasSearched) {
      if (_searchResults.isEmpty) {
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
      return ListView.builder(
        itemCount: _searchResults.length,
        itemBuilder: (context, index) => _buildUserTile(_searchResults[index]),
      );
    }

    if (_contactMatches.isNotEmpty) {
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

  // My Friends tab
  Widget _buildMyFriendsTab() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return const SizedBox();

    return StreamBuilder<DocumentSnapshot>(
      stream: _firestore.collection('users').doc(uid).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final friendIds = (snapshot.data?.exists ?? false)
            ? List<String>.from(snapshot.data?.get('friends') ?? [])
            : <String>[];

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
            friendIds.map(
              (id) => _firestore
                  .collection('users')
                  .doc(id)
                  .get()
                  .then((doc) => {'uid': doc.id, ...?doc.data()}),
            ),
          ),
          builder: (context, friendsSnapshot) {
            if (friendsSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final friends = friendsSnapshot.data ?? [];

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: friends.length,
              itemBuilder: (context, index) => _buildFriendTile(friends[index]),
            );
          },
        );
      },
    );
  }

  // Requests tab — incoming and sent
  Widget _buildRequestsTab() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return const SizedBox();

    return StreamBuilder<DocumentSnapshot>(
      stream: _firestore.collection('users').doc(uid).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final incoming = (snapshot.data?.exists ?? false)
            ? List<String>.from(snapshot.data?.get('friendRequests') ?? [])
            : <String>[];

        final sent = (snapshot.data?.exists ?? false)
            ? List<String>.from(snapshot.data?.get('sentRequests') ?? [])
            : <String>[];

        if (incoming.isEmpty && sent.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.mark_email_unread_outlined,
                  size: 64,
                  color: Colors.grey,
                ),
                SizedBox(height: 12),
                Text(
                  'No pending requests',
                  style: TextStyle(color: Colors.grey, fontSize: 15),
                ),
              ],
            ),
          );
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Incoming requests
            if (incoming.isNotEmpty) ...[
              const Text(
                'Incoming Requests',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Color(0xFF1A1A2E),
                ),
              ),
              const SizedBox(height: 8),
              ...incoming.map(
                (requesterUid) => _buildIncomingRequestTile(requesterUid),
              ),
              const SizedBox(height: 24),
            ],

            // Sent requests
            if (sent.isNotEmpty) ...[
              const Text(
                'Sent Requests',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Color(0xFF1A1A2E),
                ),
              ),
              const SizedBox(height: 8),
              ...sent.map((targetUid) => _buildSentRequestTile(targetUid)),
            ],
          ],
        );
      },
    );
  }

  // Incoming request tile with accept/decline
  Widget _buildIncomingRequestTile(String requesterUid) {
    return FutureBuilder<DocumentSnapshot>(
      future: _firestore.collection('users').doc(requesterUid).get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox();

        final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};
        final displayName =
            '${data['firstName'] ?? ''} ${data['lastName'] ?? ''}'.trim();
        final username = data['username'] ?? '';
        final initials = displayName.isNotEmpty
            ? displayName.split(' ').map((e) => e[0]).take(2).join()
            : '?';

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
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
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 8,
            ),
            leading: CircleAvatar(
              radius: 24,
              backgroundColor: Colors.deepPurple.shade100,
              child: Text(
                initials,
                style: const TextStyle(
                  color: Colors.deepPurple,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            title: Text(
              displayName.isNotEmpty ? displayName : username,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              '@$username',
              style: const TextStyle(color: Colors.grey, fontSize: 13),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Accept
                IconButton(
                  icon: const Icon(Icons.check_circle, color: Colors.green),
                  onPressed: () => _acceptRequest(requesterUid),
                ),
                // Decline
                IconButton(
                  icon: const Icon(Icons.cancel, color: Colors.redAccent),
                  onPressed: () => _declineRequest(requesterUid),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Sent request tile with cancel option
  Widget _buildSentRequestTile(String targetUid) {
    return FutureBuilder<DocumentSnapshot>(
      future: _firestore.collection('users').doc(targetUid).get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox();

        final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};
        final displayName =
            '${data['firstName'] ?? ''} ${data['lastName'] ?? ''}'.trim();
        final username = data['username'] ?? '';
        final initials = displayName.isNotEmpty
            ? displayName.split(' ').map((e) => e[0]).take(2).join()
            : '?';

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
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
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 8,
            ),
            leading: CircleAvatar(
              radius: 24,
              backgroundColor: Colors.grey.shade200,
              child: Text(
                initials,
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            title: Text(
              displayName.isNotEmpty ? displayName : username,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              '@$username',
              style: const TextStyle(color: Colors.grey, fontSize: 13),
            ),
            trailing: OutlinedButton(
              onPressed: () => _cancelRequest(targetUid),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.grey),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
          ),
        );
      },
    );
  }

  // Search result / contact match tile
  Widget _buildUserTile(Map<String, dynamic> user) {
    final displayName = '${user['firstName'] ?? ''} ${user['lastName'] ?? ''}'
        .trim();
    final username = user['username'] ?? '';
    final uid = user['uid'] as String? ?? '';
    final initials = displayName.isNotEmpty
        ? displayName.split(' ').map((e) => e[0]).take(2).join()
        : '?';

    final alreadyFriend = _friendIds.contains(uid);
    final requestSent = _sentRequestIds.contains(uid);
    final requestReceived = _incomingRequestIds.contains(uid);

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
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          radius: 24,
          backgroundColor: Colors.deepPurple.shade100,
          child: Text(
            initials,
            style: const TextStyle(
              color: Colors.deepPurple,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          displayName.isNotEmpty ? displayName : username,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          '@$username',
          style: const TextStyle(color: Colors.grey, fontSize: 13),
        ),
        trailing: alreadyFriend
            ? const Chip(
                label: Text(
                  'Friends',
                  style: TextStyle(color: Colors.deepPurple),
                ),
                backgroundColor: Color(0xFFEDE7F6),
              )
            : requestReceived
            // They sent you a request — show accept/decline
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.check_circle, color: Colors.green),
                    onPressed: () => _acceptRequest(uid),
                  ),
                  IconButton(
                    icon: const Icon(Icons.cancel, color: Colors.redAccent),
                    onPressed: () => _declineRequest(uid),
                  ),
                ],
              )
            : requestSent
            // You sent them a request — show pending/cancel
            ? OutlinedButton(
                onPressed: () => _cancelRequest(uid),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.grey),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  'Pending',
                  style: TextStyle(color: Colors.grey),
                ),
              )
            // No relationship — show add button
            : ElevatedButton(
                onPressed: () => _sendFriendRequest(uid),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                ),
                child: const Text('Add'),
              ),
      ),
    );
  }

  // Friends list tile — no add button
  Widget _buildFriendTile(Map<String, dynamic> user) {
    final displayName = '${user['firstName'] ?? ''} ${user['lastName'] ?? ''}'
        .trim();
    final username = user['username'] ?? '';
    final initials = displayName.isNotEmpty
        ? displayName.split(' ').map((e) => e[0]).take(2).join()
        : '?';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
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
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          radius: 24,
          backgroundColor: Colors.deepPurple.shade100,
          child: Text(
            initials,
            style: const TextStyle(
              color: Colors.deepPurple,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          displayName.isNotEmpty ? displayName : username,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          '@$username',
          style: const TextStyle(color: Colors.grey, fontSize: 13),
        ),
      ),
    );
  }
}
