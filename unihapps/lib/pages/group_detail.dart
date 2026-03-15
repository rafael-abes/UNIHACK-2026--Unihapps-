import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/group_model.dart';
import '../repositories/group_repositories.dart';

class GroupDetailPage extends StatefulWidget {
  final String groupId; // ← pass ID instead of model so it stays live
  const GroupDetailPage({super.key, required this.groupId});

  @override
  State<GroupDetailPage> createState() => _GroupDetailPageState();
}

class _GroupDetailPageState extends State<GroupDetailPage> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  final _groupRepo = GroupRepository();

  // Track selected friends for multi-select add
  final Set<String> _selectedFriendUids = {};

  @override
  Widget build(BuildContext context) {
    final currentUid = _auth.currentUser?.uid;

    // StreamBuilder on group — live updates, no manual reload needed
    return StreamBuilder<DocumentSnapshot>(
      stream: _firestore.collection('groups').doc(widget.groupId).snapshots(),
      builder: (context, groupSnapshot) {
        if (groupSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (!groupSnapshot.hasData || !groupSnapshot.data!.exists) {
          return const Scaffold(body: Center(child: Text('Group not found')));
        }

        // Rebuild every time group changes — no manual reload needed
        final group = GroupModel.fromMap(
          groupSnapshot.data!.id,
          groupSnapshot.data!.data() as Map<String, dynamic>,
        );

        final isAdmin = group.admins.contains(currentUid);

        return Scaffold(
          backgroundColor: const Color(0xFFF8F6FF),
          appBar: AppBar(
            backgroundColor: const Color(0xFFF8F6FF),
            elevation: 0,
            title: Text(
              group.name,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A2E),
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.person_add, color: Color(0xFF5C35C9)),
                onPressed: () => _showAddMembersDialog(group),
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
                      if (group.description.isNotEmpty) ...[
                        Text(
                          group.description,
                          style: const TextStyle(color: Colors.grey),
                        ),
                        const SizedBox(height: 8),
                      ],
                      Text(
                        '${group.members.length} member${group.members.length != 1 ? 's' : ''}',
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

                // Members list — live from stream
                Expanded(
                  child: FutureBuilder<List<Map<String, dynamic>>>(
                    future: _loadMembers(group.members),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final members = snapshot.data ?? [];

                      return ListView.builder(
                        itemCount: members.length,
                        itemBuilder: (context, index) {
                          final member = members[index];
                          final displayName =
                              '${member['firstName'] ?? ''} ${member['lastName'] ?? ''}'
                                  .trim();
                          final isCreator = member['uid'] == group.createdBy;
                          final memberIsAdmin = group.admins.contains(
                            member['uid'],
                          );
                          final isCurrentUser = member['uid'] == currentUid;

                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.deepPurple.withOpacity(0.04),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Colors.deepPurple.shade100,
                                child: Text(
                                  displayName.isNotEmpty ? displayName[0] : '?',
                                  style: const TextStyle(
                                    color: Colors.deepPurple,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              title: Text(
                                isCurrentUser
                                    ? '$displayName (You)'
                                    : displayName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              subtitle: Text(
                                '@${member['username'] ?? ''}',
                                style: const TextStyle(color: Colors.grey),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (isCreator)
                                    const Chip(
                                      label: Text(
                                        'Creator',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.deepPurple,
                                        ),
                                      ),
                                      backgroundColor: Color(0xFFEDE7F6),
                                      padding: EdgeInsets.zero,
                                    )
                                  else if (memberIsAdmin)
                                    const Chip(
                                      label: Text(
                                        'Admin',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.green,
                                        ),
                                      ),
                                      backgroundColor: Color(0xFFE8F5E9),
                                      padding: EdgeInsets.zero,
                                    ),
                                  // Admin can remove non-creator members
                                  // without leaving the page
                                  if (isAdmin && !isCreator && !isCurrentUser)
                                    IconButton(
                                      icon: const Icon(
                                        Icons.remove_circle,
                                        color: Colors.redAccent,
                                        size: 20,
                                      ),
                                      onPressed: () => _removeMember(
                                        group,
                                        member['uid'],
                                        displayName,
                                      ),
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

                // Leave group — non-creators only
                if (currentUid != group.createdBy) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _leaveGroup(group, currentUid!),
                      icon: const Icon(
                        Icons.exit_to_app,
                        color: Colors.redAccent,
                      ),
                      label: const Text(
                        'Leave Group',
                        style: TextStyle(color: Colors.redAccent),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.redAccent),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                ],

                // Delete group — creator only
                if (currentUid == group.createdBy) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _deleteGroup(group),
                      icon: const Icon(
                        Icons.delete_outline,
                        color: Colors.redAccent,
                      ),
                      label: const Text(
                        'Delete Group',
                        style: TextStyle(color: Colors.redAccent),
                      ),
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
      },
    );
  }

  Future<List<Map<String, dynamic>>> _loadMembers(
    List<String> memberIds,
  ) async {
    final docs = await Future.wait(
      memberIds.map((uid) => _firestore.collection('users').doc(uid).get()),
    );
    return docs
        .where((doc) => doc.exists)
        .map((doc) => {'uid': doc.id, ...?doc.data()})
        .toList();
  }

  // Remove member WITHOUT navigating away
  Future<void> _removeMember(
    GroupModel group,
    String uid,
    String displayName,
  ) async {
    await _groupRepo.removeMember(group.id, uid);

    // StreamBuilder auto-updates the list — no pop needed
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$displayName removed from group')));
  }

  // Leave group — navigate back after
  Future<void> _leaveGroup(GroupModel group, String uid) async {
    await _groupRepo.removeMember(group.id, uid);
    if (!mounted) return;
    Navigator.pop(context);
  }

  // Delete group — navigate back after
  Future<void> _deleteGroup(GroupModel group) async {
    await _groupRepo.deleteGroup(group.id);
    if (!mounted) return;
    Navigator.pop(context);
  }

  // Multi-select add members dialog
  void _showAddMembersDialog(GroupModel group) {
    _selectedFriendUids.clear(); // reset selection each time

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          height: MediaQuery.of(context).size.height * 0.65,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Add Friends to Group',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    // Add selected button — only shows when someone selected
                    if (_selectedFriendUids.isNotEmpty)
                      ElevatedButton(
                        onPressed: () => _addSelectedMembers(group, context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF5C35C9),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: Text('Add (${_selectedFriendUids.length})'),
                      ),
                  ],
                ),
              ),

              const Divider(),

              // Friends list with checkboxes
              Expanded(
                child: FutureBuilder<DocumentSnapshot>(
                  future: _firestore
                      .collection('users')
                      .doc(_auth.currentUser?.uid)
                      .get(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final friendIds = List<String>.from(
                      snapshot.data?.get('friends') ?? [],
                    );

                    // Filter out already members
                    final addableFriends = friendIds
                        .where((id) => !group.members.contains(id))
                        .toList();

                    if (addableFriends.isEmpty) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                            'All your friends are already in this group',
                            style: TextStyle(color: Colors.grey),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      );
                    }

                    return FutureBuilder<List<Map<String, dynamic>>>(
                      future: Future.wait(
                        addableFriends.map(
                          (id) => _firestore
                              .collection('users')
                              .doc(id)
                              .get()
                              .then((doc) => {'uid': doc.id, ...?doc.data()}),
                        ),
                      ),
                      builder: (context, friendsSnapshot) {
                        if (!friendsSnapshot.hasData) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }

                        return ListView.builder(
                          itemCount: friendsSnapshot.data!.length,
                          itemBuilder: (context, index) {
                            final friend = friendsSnapshot.data![index];
                            final displayName =
                                '${friend['firstName'] ?? ''} ${friend['lastName'] ?? ''}'
                                    .trim();
                            final uid = friend['uid'] as String? ?? '';
                            final isSelected = _selectedFriendUids.contains(
                              uid,
                            );

                            return CheckboxListTile(
                              value: isSelected,
                              activeColor: const Color(0xFF5C35C9),
                              onChanged: (checked) {
                                setModalState(() {
                                  if (checked == true) {
                                    _selectedFriendUids.add(uid);
                                  } else {
                                    _selectedFriendUids.remove(uid);
                                  }
                                });
                              },
                              secondary: CircleAvatar(
                                backgroundColor: Colors.deepPurple.shade100,
                                child: Text(
                                  displayName.isNotEmpty ? displayName[0] : '?',
                                  style: const TextStyle(
                                    color: Colors.deepPurple,
                                  ),
                                ),
                              ),
                              title: Text(
                                displayName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              subtitle: Text(
                                '@${friend['username'] ?? ''}',
                                style: const TextStyle(color: Colors.grey),
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
      ),
    );
  }

  // Add all selected friends at once
  Future<void> _addSelectedMembers(
    GroupModel group,
    BuildContext modalContext,
  ) async {
    if (_selectedFriendUids.isEmpty) return;

    // Add all selected in parallel
    await Future.wait(
      _selectedFriendUids.map((uid) => _groupRepo.addMember(group.id, uid)),
    );

    // Close the modal
    if (!modalContext.mounted) return;
    Navigator.pop(modalContext);

    // StreamBuilder auto-updates member list — no manual reload
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${_selectedFriendUids.length} friend(s) added to group!',
        ),
      ),
    );

    _selectedFriendUids.clear();
  }
}
