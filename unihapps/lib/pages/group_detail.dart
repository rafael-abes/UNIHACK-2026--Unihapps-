import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/group_model.dart';
import '../repositories/group_repositories.dart';

class GroupDetailPage extends StatefulWidget {
  final GroupModel group;
  const GroupDetailPage({super.key, required this.group});

  @override
  State<GroupDetailPage> createState() => _GroupDetailPageState();
}

class _GroupDetailPageState extends State<GroupDetailPage> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  final _groupRepo = GroupRepository();

  // Load member profiles
  Future<List<Map<String, dynamic>>> _loadMembers() async {
    final docs = await Future.wait(
      widget.group.members.map((uid) =>
          _firestore.collection('users').doc(uid).get()),
    );
    return docs
        .where((doc) => doc.exists)
        .map((doc) => {'uid': doc.id, ...?doc.data()})
        .toList();
  }

  // Show dialog to add a friend to the group
  void _showAddMemberDialog() {
    final currentUid = _auth.currentUser?.uid;
    if (currentUid == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.6,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                'Add Friends to Group',
                style: TextStyle(
                    fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),

            // Load current user's friends and show ones not in group
            Expanded(
              child: FutureBuilder<DocumentSnapshot>(
                future: _firestore
                    .collection('users')
                    .doc(currentUid)
                    .get(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(
                        child: CircularProgressIndicator());
                  }

                  final friendIds = List<String>.from(
                      snapshot.data?.get('friends') ?? []);

                  // Filter out already members
                  final addableFriends = friendIds
                      .where((id) =>
                          !widget.group.members.contains(id))
                      .toList();

                  if (addableFriends.isEmpty) {
                    return const Center(
                      child: Text(
                        'All your friends are already in this group',
                        style: TextStyle(color: Colors.grey),
                        textAlign: TextAlign.center,
                      ),
                    );
                  }

                  return FutureBuilder<List<Map<String, dynamic>>>(
                    future: Future.wait(
                      addableFriends.map((id) => _firestore
                          .collection('users')
                          .doc(id)
                          .get()
                          .then((doc) =>
                              {'uid': doc.id, ...?doc.data()})),
                    ),
                    builder: (context, friendsSnapshot) {
                      if (!friendsSnapshot.hasData) {
                        return const Center(
                            child: CircularProgressIndicator());
                      }

                      return ListView.builder(
                        itemCount: friendsSnapshot.data!.length,
                        itemBuilder: (context, index) {
                          final friend =
                              friendsSnapshot.data![index];
                          final displayName =
                              '${friend['firstName'] ?? ''} ${friend['lastName'] ?? ''}'
                                  .trim();

                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor:
                                  Colors.deepPurple.shade100,
                              child: Text(
                                displayName.isNotEmpty
                                    ? displayName[0]
                                    : '?',
                                style: const TextStyle(
                                    color: Colors.deepPurple),
                              ),
                            ),
                            title: Text(displayName),
                            subtitle: Text(
                                '@${friend['username'] ?? ''}'),
                            trailing: ElevatedButton(
                              onPressed: () async {
                                await _groupRepo.addMember(
                                    widget.group.id, friend['uid']);
                                if (!context.mounted) return;
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context)
                                    .showSnackBar(
                                  SnackBar(
                                      content: Text(
                                          '$displayName added to group!')),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    const Color(0xFF5C35C9),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(10),
                                ),
                              ),
                              child: const Text('Add'),
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUid = _auth.currentUser?.uid;
    final isAdmin = widget.group.admins.contains(currentUid);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F6FF),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8F6FF),
        elevation: 0,
        title: Text(
          widget.group.name,
          style: const TextStyle(
              fontWeight: FontWeight.bold, color: Color(0xFF1A1A2E)),
        ),
        actions: [
          // Any member can add friends
          IconButton(
            icon: const Icon(Icons.person_add, color: Color(0xFF5C35C9)),
            onPressed: _showAddMemberDialog,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Group info card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.group.description.isNotEmpty) ...[
                    Text(
                      widget.group.description,
                      style: const TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 8),
                  ],
                  Text(
                    '${widget.group.members.length} member${widget.group.members.length != 1 ? 's' : ''}',
                    style: const TextStyle(
                      color: Colors.deepPurple,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            const Text(
              'Members',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A2E),
              ),
            ),

            const SizedBox(height: 12),

            // Members list
            Expanded(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: _loadMembers(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState ==
                      ConnectionState.waiting) {
                    return const Center(
                        child: CircularProgressIndicator());
                  }

                  final members = snapshot.data ?? [];

                  return ListView.builder(
                    itemCount: members.length,
                    itemBuilder: (context, index) {
                      final member = members[index];
                      final displayName =
                          '${member['firstName'] ?? ''} ${member['lastName'] ?? ''}'
                              .trim();
                      final isCreator =
                          member['uid'] == widget.group.createdBy;
                      final memberIsAdmin =
                          widget.group.admins.contains(member['uid']);
                      final isCurrentUser =
                          member['uid'] == currentUid;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color:
                                  Colors.deepPurple.withOpacity(0.04),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor:
                                Colors.deepPurple.shade100,
                            child: Text(
                              displayName.isNotEmpty
                                  ? displayName[0]
                                  : '?',
                              style: const TextStyle(
                                  color: Colors.deepPurple,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                          title: Text(
                            isCurrentUser
                                ? '$displayName (You)'
                                : displayName,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                              '@${member['username'] ?? ''}',
                              style:
                                  const TextStyle(color: Colors.grey)),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (isCreator)
                                const Chip(
                                  label: Text('Creator',
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.deepPurple)),
                                  backgroundColor: Color(0xFFEDE7F6),
                                  padding: EdgeInsets.zero,
                                )
                              else if (memberIsAdmin)
                                const Chip(
                                  label: Text('Admin',
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.green)),
                                  backgroundColor: Color(0xFFE8F5E9),
                                  padding: EdgeInsets.zero,
                                ),
                              // Admin can remove non-creator members
                              if (isAdmin &&
                                  !isCreator &&
                                  !isCurrentUser)
                                IconButton(
                                  icon: const Icon(Icons.remove_circle,
                                      color: Colors.redAccent,
                                      size: 20),
                                  onPressed: () async {
                                    await _groupRepo.removeMember(
                                        widget.group.id, member['uid']);
                                    if (!context.mounted) return;
                                    ScaffoldMessenger.of(context)
                                        .showSnackBar(
                                      const SnackBar(
                                          content:
                                              Text('Member removed')),
                                    );
                                    Navigator.pop(context);
                                  },
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),

            // Leave group button
            if (currentUid != widget.group.createdBy)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    await _groupRepo.removeMember(
                        widget.group.id, currentUid!);
                    if (!context.mounted) return;
                    Navigator.pop(context);
                  },
                  icon: const Icon(Icons.exit_to_app,
                      color: Colors.redAccent),
                  label: const Text('Leave Group',
                      style: TextStyle(color: Colors.redAccent)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.redAccent),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),

            // Delete group button — creator only
            if (currentUid == widget.group.createdBy) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    await _groupRepo.deleteGroup(widget.group.id);
                    if (!context.mounted) return;
                    Navigator.pop(context);
                  },
                  icon: const Icon(Icons.delete_outline,
                      color: Colors.redAccent),
                  label: const Text('Delete Group',
                      style: TextStyle(color: Colors.redAccent)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.redAccent),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}