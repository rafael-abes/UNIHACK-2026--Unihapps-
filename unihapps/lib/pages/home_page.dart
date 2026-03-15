import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';

import '../models/happs_model.dart';
import '../repositories/happs_repositories.dart';
import 'friends_list.dart';
import 'profile_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'group_detail.dart';
import 'group_list.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../repositories/user_repositories.dart';
import 'package:firebase_auth/firebase_auth.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

String _formatTime(DateTime dt) {
  final hour = dt.hour == 0 ? 12 : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
  final minute = dt.minute.toString().padLeft(2, '0');
  final period = dt.hour >= 12 ? 'PM' : 'AM';
  return '$hour:$minute$period';
}

// ─────────────────────────────────────────────────────────────────────────────
// HomePage
// ─────────────────────────────────────────────────────────────────────────────

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final Completer<GoogleMapController> _googleMapController = Completer();
  final Location _location = Location();
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  LocationData? locationData;

  StreamSubscription? _friendsSubscription;

  Timer? _locationTimer;

  Set<Marker> _markers = {};

  final UserRepository _userRepository = UserRepository();
  // final String userId = 'exampleUserId'; // Replace with actual user ID
  String? userId;

  final List<String> statuses = ['offline', 'free', 'busy', 'in-class'];
  final Map<String, Color> statusColors = {
    'offline': Colors.grey,
    'free': Colors.green,
    'busy': Colors.red,
    'in-class': Colors.blue,
  };
  String currentStatus = 'offline';

  void initializeUser() {
    final user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      userId = user.uid;
    } else {
      print("No user logged in");
    }
  }

  void startLocationUpdates() {
  _locationTimer = Timer.periodic(
    const Duration(seconds: 30),
    (timer) async {
      final loc = await _location.getLocation();

      if (loc.latitude != null && loc.longitude != null) {
        await _userRepository.updateUserLocation(
          userId!,
          loc.latitude!,
          loc.longitude!,
        );
      }
    },
  );
}

  void getCurrentLocation() async {
    try {
      await _location.changeSettings(
        accuracy: LocationAccuracy.high,
        interval: 1000,
        distanceFilter: 0,
      );

      LocationData currentLocationData = await _location.getLocation();
      setState(() => locationData = currentLocationData);

      final GoogleMapController controller =
          await _googleMapController.future;

      await controller.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(
              currentLocationData.latitude!,
              currentLocationData.longitude!,
            ),
            zoom: 14.5,
          ),
        ),
      );

      _location.onLocationChanged.listen((LocationData newLocationData) async {
        controller.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(
              target: LatLng(
                newLocationData.latitude!,
                newLocationData.longitude!,
              ),
              zoom: 14.5,
            ),
          ),
        );
        setState(() {
          locationData = newLocationData;

          _markers.removeWhere((m) => m.markerId.value == "me");
          _markers.add(
            Marker(
              markerId: const MarkerId("me"),
              position: LatLng(
                newLocationData.latitude!,
                newLocationData.longitude!,
              ),
              infoWindow: const InfoWindow(title: "You"),
            ),
          );
        });
      });
    } catch (e) {
      print('Error getting location: $e');
    }
  }

  Future<void> _setStatus(String newStatus) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    setState(() => currentStatus = newStatus);

    if (userId != null) {
      await _userRepository.updateUserStatus(userId!, newStatus);
    }
  }

  Future<void> listenToFriends() async {
    if (userId == null) return;

    List<String> friendIds = await _userRepository.getFriends(userId!);

    if (friendIds.isEmpty) return;

    _friendsSubscription =
        _userRepository.streamFriendsLocations(friendIds).listen((friends) {
      Set<Marker> friendMarkers = {};

      for (var friend in friends) {
        if (friend.location != null) {
          GeoPoint geo = friend.location!;
          LatLng pos = LatLng(geo.latitude, geo.longitude);

          friendMarkers.add(
            Marker(
              markerId: MarkerId(friend.id),
              position: pos,
              infoWindow: InfoWindow(title: friend.username),
            ),
          );
        }
      }

      setState(() {
        _markers.removeWhere((m) => m.markerId.value != "me");
        _markers.addAll(friendMarkers);
      });
    });
  }

  @override
  void initState() {
    super.initState();
    initializeUser();
    getCurrentLocation();
    listenToFriends();
    startLocationUpdates();
  }

  Future<void> _loadCurrentStatus() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    final doc = await _firestore.collection('users').doc(uid).get();
    if (!mounted) return;
    setState(() {
      currentStatus = doc.data()?['status'] ?? 'offline';
    });
  }

  void _showFriendsSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _FriendsBottomSheet(),
    );
  }

  void _showHappsSheet() {
    print('[HAPPS] _showHappsSheet called — locationData: $locationData');
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _HappsSheet(locationData: locationData),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: locationData == null
          ? const Center(child: CircularProgressIndicator())
          : GoogleMap(
              onMapCreated: (controller) =>
                  _googleMapController.complete(controller),
              initialCameraPosition: CameraPosition(
                target: LatLng(
                  locationData!.latitude!,
                  locationData!.longitude!,
                ),
                zoom: 14.5,
              ),
              markers: _markers,
            ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 1,
        onTap: (index) {
          if (index == 0) {
            _showFriendsSheet();
          } else if (index == 1) {
            _showHappsSheet();
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
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Happs',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

class _FriendsBottomSheet extends StatefulWidget {
  @override
  State<_FriendsBottomSheet> createState() => _FriendsBottomSheetState();
}

class _FriendsBottomSheetState extends State<_FriendsBottomSheet>
    with SingleTickerProviderStateMixin {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showAddOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(16),
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
              'Add',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A2E),
              ),
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () {
                Navigator.pop(ctx);
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const FriendsPage()),
                );
              },
              child: Container(
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F6FF),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.deepPurple.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.deepPurple.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.person_add,
                        color: Colors.deepPurple,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Add Friend',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                              color: Color(0xFF1A1A2E),
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Search by username or sync contacts',
                            style: TextStyle(color: Colors.grey, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: Colors.grey),
                  ],
                ),
              ),
            ),
            GestureDetector(
              onTap: () {
                Navigator.pop(ctx);
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const GroupsPage()),
                );
              },
              child: Container(
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F7FF),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.blue.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.group_add,
                        color: Colors.blue,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'New Group',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                              color: Color(0xFF1A1A2E),
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Create a group with your friends',
                            style: TextStyle(color: Colors.grey, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: Colors.grey),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
  Color _statusColor(String? status) {
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
        return Colors.grey;
    }
  }

  int _statusPriority(String? status) {
    switch (status) {
      case 'Available':
        return 0;
      case 'Busy':
        return 1;
      case 'Away':
        return 2;
      case 'Do Not Disturb':
        return 3;
      default:
        return 4;
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = _auth.currentUser?.uid;

    return Container(
      height: MediaQuery.of(context).size.height * 0.55,
      decoration: const BoxDecoration(
        color: Color(0xFFF8F6FF),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Friends',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A2E),
                  ),
                ),
                GestureDetector(
                  onTap: _showAddOptions,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.deepPurple.shade50,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.add,
                      color: Colors.deepPurple,
                      size: 22,
                    ),
                  ),
                ),
              ],
            ),
          ),

          TabBar(
            controller: _tabController,
            labelColor: Colors.deepPurple,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Colors.deepPurple,
            tabs: const [
              Tab(text: 'People'),
              Tab(text: 'Groups'),
            ],
          ),

          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [

                /// =========================
                /// PEOPLE TAB
                /// =========================

                uid == null
                    ? const SizedBox()
                    : StreamBuilder<DocumentSnapshot>(
                        stream:
                            _firestore.collection('users').doc(uid).snapshots(),
                        builder: (context, snapshot) {
                          final friendIds = (snapshot.data?.exists ?? false)
                              ? List<String>.from(
                                  (snapshot.data?.data()
                                              as Map<String, dynamic>?)?[
                                          'friends'] ??
                                      [],
                                )
                              : <String>[];

                          if (friendIds.isEmpty) {
                            return Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.people_outline,
                                    size: 48,
                                    color: Colors.grey,
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'No friends yet',
                                    style: TextStyle(
                                      color: Colors.grey,
                                      fontSize: 15,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  TextButton(
                                    onPressed: () {
                                      Navigator.pop(context);
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => const FriendsPage(),
                                        ),
                                      );
                                    },
                                    child: const Text('Add Friends'),
                                  ),
                                ],
                              ),
                            );
                          }

                          /// REAL-TIME FRIEND STREAM
                          return StreamBuilder<QuerySnapshot>(
                            stream: _firestore
                                .collection('users')
                                .where(
                                  FieldPath.documentId,
                                  whereIn: friendIds,
                                )
                                .snapshots(),
                            builder: (context, friendSnap) {
                              if (!friendSnap.hasData) {
                                return const Center(
                                  child: CircularProgressIndicator(),
                                );
                              }

                              final friends = friendSnap.data!.docs
                                  .map(
                                    (doc) => {
                                      'uid': doc.id,
                                      ...(doc.data() as Map<String, dynamic>),
                                    },
                                  )
                                  .toList();

                              /// SORT BY STATUS
                              friends.sort((a, b) =>
                                  _statusPriority(a['status'])
                                      .compareTo(_statusPriority(b['status'])));

                              return ListView.builder(
                                padding: const EdgeInsets.all(12),
                                itemCount: friends.length,
                                itemBuilder: (context, index) {
                                  final friend = friends[index];

                                  final displayName =
                                      '${friend['firstName'] ?? ''} ${friend['lastName'] ?? ''}'
                                          .trim();

                                  final username = friend['username'] ?? '';

                                  final status = friend['status'] ?? 'Available';

                                  final initials = displayName.isNotEmpty
                                      ? displayName
                                          .split(' ')
                                          .map((e) => e[0])
                                          .take(2)
                                          .join()
                                      : '?';

                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(14),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.deepPurple
                                              .withOpacity(0.04),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: ListTile(
                                      leading: Stack(
                                        children: [
                                          CircleAvatar(
                                            backgroundColor:
                                                Colors.deepPurple.shade100,
                                            child: Text(
                                              initials,
                                              style: const TextStyle(
                                                color: Colors.deepPurple,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),

                                          /// STATUS DOT
                                          Positioned(
                                            right: 0,
                                            bottom: 0,
                                            child: Container(
                                              width: 12,
                                              height: 12,
                                              decoration: BoxDecoration(
                                                color: _statusColor(status),
                                                shape: BoxShape.circle,
                                                border: Border.all(
                                                  color: Colors.white,
                                                  width: 2,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      title: Text(
                                        displayName.isNotEmpty
                                            ? displayName
                                            : username,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      subtitle: Text(
                                        '@$username',
                                        style: const TextStyle(
                                          color: Colors.grey,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              );
                            },
                          );
                        },
                      ),

                /// =========================
                /// GROUPS TAB (UNCHANGED)
                /// =========================

                uid == null
                    ? const SizedBox()
                    : StreamBuilder<QuerySnapshot>(
                        stream: _firestore
                            .collection('groups')
                            .where('members', arrayContains: uid)
                            .snapshots(),
                        builder: (context, snapshot) {
                          final groups = snapshot.data?.docs ?? [];

                          if (groups.isEmpty) {
                            return const Center(
                              child: Text(
                                'No groups yet',
                                style: TextStyle(color: Colors.grey),
                              ),
                            );
                          }

                          return ListView.builder(
                            padding: const EdgeInsets.all(12),
                            itemCount: groups.length,
                            itemBuilder: (context, index) {
                              final data =
                                  groups[index].data() as Map<String, dynamic>;

                              final name = data['name'] ?? '';
                              final memberCount =
                                  (data['members'] as List?)?.length ?? 0;

                              return ListTile(
                                title: Text(name),
                                subtitle: Text(
                                  '$memberCount member${memberCount != 1 ? 's' : ''}',
                                ),
                              );
                            },
                          );
                        },
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Happs bottom sheet
// ─────────────────────────────────────────────────────────────────────────────

class _HappsSheet extends StatefulWidget {
  final LocationData? locationData;
  const _HappsSheet({required this.locationData});

  @override
  State<_HappsSheet> createState() => _HappsSheetState();
}

class _HappsSheetState extends State<_HappsSheet> {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  final _repo = HappRepository();

  String _getOrganizerId(Map<String, dynamic> data) {
    final v = data['organizer'];
    if (v is DocumentReference) return v.id;
    return v?.toString() ?? '';
  }

  Future<void> _joinHapp(HappsModel happ) async {
    print('[HAPPS] _joinHapp called — happId: ${happ.id}, title: ${happ.title}');
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      print('[HAPPS] _joinHapp aborted — no current user');
      return;
    }
    try {
      final userRef = _firestore.doc('users/$uid');
      await _repo.updateHapp(happ.id, {
        'participants': FieldValue.arrayUnion([userRef]),
      });
      print('[HAPPS] _joinHapp success — uid: $uid joined happ: ${happ.id}');
    } catch (e) {
      print('[HAPPS] _joinHapp ERROR: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not join: $e')),
        );
      }
    }
  }

  void _openAddHapp() {
    print('[HAPPS] _openAddHapp called — locationData: ${widget.locationData}');
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddHappSheet(locationData: widget.locationData),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = _auth.currentUser?.uid;

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      builder: (_, controller) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // Drag handle
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),

            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  const Text(
                    'Happs',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1A2E),
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: _openAddHapp,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.add_circle_outline,
                              size: 16, color: Colors.grey.shade700),
                          const SizedBox(width: 4),
                          Text(
                            'Add Happs',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade700,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Icon(Icons.close,
                        color: Colors.grey.shade600, size: 22),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Happs list
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _firestore.collection('happs').snapshots(),
                builder: (context, snapshot) {
                  print('[HAPPS] StreamBuilder state: ${snapshot.connectionState}, hasError: ${snapshot.hasError}, docCount: ${snapshot.data?.docs.length}');
                  if (snapshot.hasError) {
                    print('[HAPPS] StreamBuilder ERROR: ${snapshot.error}\n${snapshot.stackTrace}');
                  }
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final docs = snapshot.data?.docs ?? [];
                  print('[HAPPS] Loaded ${docs.length} happs docs, uid: $uid');

                  final myHapps = docs
                      .where((d) =>
                          _getOrganizerId(d.data() as Map<String, dynamic>) ==
                          uid)
                      .map((d) {
                        try {
                          return HappsModel.fromMap(d.id, d.data() as Map<String, dynamic>);
                        } catch (e) {
                          print('[HAPPS] fromMap ERROR on doc ${d.id}: $e — data: ${d.data()}');
                          rethrow;
                        }
                      })
                      .toList();
                  final nearbyHapps = docs
                      .where((d) =>
                          _getOrganizerId(d.data() as Map<String, dynamic>) !=
                          uid)
                      .map((d) {
                        try {
                          return HappsModel.fromMap(d.id, d.data() as Map<String, dynamic>);
                        } catch (e) {
                          print('[HAPPS] fromMap ERROR on doc ${d.id}: $e — data: ${d.data()}');
                          rethrow;
                        }
                      })
                      .toList();
                  print('[HAPPS] myHapps: ${myHapps.length}, nearbyHapps: ${nearbyHapps.length}');

                  return ListView(
                    controller: controller,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    children: [
                      if (myHapps.isNotEmpty) ...[
                        const Text(
                          'My Happs',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF3DB54A),
                          ),
                        ),
                        const SizedBox(height: 10),
                        ...myHapps.map((h) => _MyHappTile(
                              happ: h,
                              rawData: docs
                                  .firstWhere((d) => d.id == h.id)
                                  .data() as Map<String, dynamic>,
                            )),
                        const SizedBox(height: 16),
                      ],
                      if (nearbyHapps.isNotEmpty) ...[
                        const Text(
                          'Nearby',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF3DB54A),
                          ),
                        ),
                        const SizedBox(height: 10),
                        ...nearbyHapps.map((h) => _NearbyHappTile(
                              happ: h,
                              rawData: docs
                                  .firstWhere((d) => d.id == h.id)
                                  .data() as Map<String, dynamic>,
                              onJoin: () => _joinHapp(h),
                              currentUid: uid ?? '',
                            )),
                      ],
                      if (myHapps.isEmpty && nearbyHapps.isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 60),
                          child: Column(
                            children: [
                              Icon(Icons.celebration_outlined,
                                  size: 64, color: Colors.grey.shade300),
                              const SizedBox(height: 12),
                              Text(
                                'No happs yet!\nCreate one to get started.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    color: Colors.grey.shade400, fontSize: 15),
                              ),
                            ],
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// My Happ tile
// ─────────────────────────────────────────────────────────────────────────────

class _MyHappTile extends StatelessWidget {
  final HappsModel happ;
  final Map<String, dynamic> rawData;

  const _MyHappTile({required this.happ, required this.rawData});

  @override
  Widget build(BuildContext context) {
    final locationName = rawData['locationName'] as String? ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Organizer avatar
          CircleAvatar(
            radius: 22,
            backgroundColor: Colors.deepPurple.shade100,
            child: const Icon(Icons.person, color: Colors.deepPurple, size: 22),
          ),
          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title row
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        happ.title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A1A2E),
                        ),
                      ),
                    ),
                    Icon(Icons.edit_outlined,
                        size: 16, color: Colors.grey.shade500),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'You',
                  style:
                      TextStyle(fontSize: 12, color: Colors.grey.shade500),
                ),
                const SizedBox(height: 6),

                // Tags + participants row
                Row(
                  children: [
                    Expanded(
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          _TagChip(_formatTime(happ.when)),
                          if (happ.category.isNotEmpty)
                            _TagChip(happ.category),
                          if (locationName.isNotEmpty)
                            _TagChip(locationName),
                        ],
                      ),
                    ),
                    if (happ.participants.isNotEmpty)
                      _ParticipantStack(
                          participantIds: happ.participants),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Nearby Happ tile
// ─────────────────────────────────────────────────────────────────────────────

class _NearbyHappTile extends StatefulWidget {
  final HappsModel happ;
  final Map<String, dynamic> rawData;
  final VoidCallback onJoin;
  final String currentUid;

  const _NearbyHappTile({
    required this.happ,
    required this.rawData,
    required this.onJoin,
    required this.currentUid,
  });

  @override
  State<_NearbyHappTile> createState() => _NearbyHappTileState();
}

class _NearbyHappTileState extends State<_NearbyHappTile> {
  String _organizerName = '';

  @override
  void initState() {
    super.initState();
    _fetchOrganizer();
  }

  Future<void> _fetchOrganizer() async {
    print('[HAPPS] _fetchOrganizer called — organizerId: ${widget.happ.organizerId}, happId: ${widget.happ.id}');
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.happ.organizerId)
          .get();
      if (!mounted) return;
      final data = doc.data();
      if (data != null) {
        final name =
            '${data['firstName'] ?? ''} ${data['lastName'] ?? ''}'.trim();
        final resolved = name.isNotEmpty ? name : 'Unknown';
        print('[HAPPS] _fetchOrganizer resolved name: $resolved');
        setState(() => _organizerName = resolved);
      } else {
        print('[HAPPS] _fetchOrganizer — doc exists: ${doc.exists}, data was null for id: ${widget.happ.organizerId}');
      }
    } catch (e, st) {
      print('[HAPPS] _fetchOrganizer ERROR: $e\n$st');
    }
  }

  @override
  Widget build(BuildContext context) {
    final locationName = widget.rawData['locationName'] as String? ?? '';
    final hasJoined =
        widget.happ.participants.contains(widget.currentUid);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: Colors.orange.shade100,
            child: Icon(Icons.person, color: Colors.orange.shade700, size: 22),
          ),
          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.happ.title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A2E),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _organizerName,
                  style:
                      TextStyle(fontSize: 12, color: Colors.grey.shade500),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    _TagChip(_formatTime(widget.happ.when)),
                    if (widget.happ.category.isNotEmpty)
                      _TagChip(widget.happ.category),
                    if (locationName.isNotEmpty) _TagChip(locationName),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(width: 8),
          GestureDetector(
            onTap: hasJoined ? null : widget.onJoin,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  hasJoined
                      ? Icons.check_circle_outline
                      : Icons.add_circle_outline,
                  size: 18,
                  color:
                      hasJoined ? Colors.green : Colors.grey.shade600,
                ),
                const SizedBox(width: 4),
                Text(
                  hasJoined ? 'Joined' : 'Join',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: hasJoined ? Colors.green : Colors.grey.shade600,
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

// ─────────────────────────────────────────────────────────────────────────────
// Shared small widgets
// ─────────────────────────────────────────────────────────────────────────────

class _TagChip extends StatelessWidget {
  final String label;
  const _TagChip(this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
      ),
    );
  }
}

class _ParticipantStack extends StatelessWidget {
  final List<String> participantIds;
  const _ParticipantStack({required this.participantIds});

  @override
  Widget build(BuildContext context) {
    const avatarSize = 24.0;
    const overlap = 16.0;
    final shown = participantIds.take(3).toList();
    final extra = participantIds.length - shown.length;
    final totalWidth =
        avatarSize + (shown.length - 1) * overlap + (extra > 0 ? overlap : 0);

    return SizedBox(
      width: totalWidth + 20,
      height: avatarSize,
      child: Stack(
        children: [
          for (int i = 0; i < shown.length; i++)
            Positioned(
              left: i * overlap,
              child: Container(
                width: avatarSize,
                height: avatarSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors
                      .primaries[shown[i].hashCode % Colors.primaries.length]
                      .shade200,
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                child: const Icon(Icons.person, size: 12, color: Colors.white),
              ),
            ),
          if (extra > 0)
            Positioned(
              left: shown.length * overlap,
              child: Container(
                width: avatarSize,
                height: avatarSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.grey.shade300,
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                child: Center(
                  child: Text(
                    '+$extra',
                    style: const TextStyle(
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                        color: Colors.black54),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Add Happ bottom sheet
// ─────────────────────────────────────────────────────────────────────────────

class _AddHappSheet extends StatefulWidget {
  final LocationData? locationData;
  const _AddHappSheet({required this.locationData});

  @override
  State<_AddHappSheet> createState() => _AddHappSheetState();
}

class _AddHappSheetState extends State<_AddHappSheet> {
  final _titleController = TextEditingController();
  final _locationController = TextEditingController();
  final _repo = HappRepository();
  final _auth = FirebaseAuth.instance;

  TimeOfDay _selectedTime = TimeOfDay.now();
  String _selectedCategory = 'Food';
  bool _isSubmitting = false;

  final List<String> _categories = ['Food', 'Sport', 'Study', 'Happs'];

  @override
  void dispose() {
    _titleController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked != null) setState(() => _selectedTime = picked);
  }

  Future<void> _submit() async {
    print('[HAPPS] _submit called — title: "${_titleController.text.trim()}", category: $_selectedCategory, time: ${_selectedTime.format(context)}');
    if (_titleController.text.trim().isEmpty) {
      print('[HAPPS] _submit aborted — empty title');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a title')),
      );
      return;
    }

    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      print('[HAPPS] _submit aborted — no current user');
      return;
    }
    print('[HAPPS] _submit uid: $uid');

    setState(() => _isSubmitting = true);

    final now = DateTime.now();
    final when = DateTime(
      now.year,
      now.month,
      now.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );

    final geoPoint = widget.locationData != null
        ? GeoPoint(
            widget.locationData!.latitude!,
            widget.locationData!.longitude!,
          )
        : const GeoPoint(0, 0);
    print('[HAPPS] _submit geoPoint: $geoPoint, when: $when, locationData was ${widget.locationData == null ? "null" : "present"}');

    final happ = HappsModel(
      id: '',
      organizerId: uid,
      title: _titleController.text.trim(),
      when: when,
      category: _selectedCategory,
      location: geoPoint,
      participants: [uid],
    );

    final extraFields = {
      ...happ.toMap(),
      'locationName': _locationController.text.trim(),
    };
    print('[HAPPS] _submit writing to Firestore — fields: ${extraFields.keys.toList()}');

    try {
      final ref = await FirebaseFirestore.instance.collection('happs').add(extraFields);
      print('[HAPPS] _submit success — new doc id: ${ref.id}');
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Happ created!')),
      );
    } catch (e, st) {
      print('[HAPPS] _submit ERROR: $e\n$st');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  String _timeLabel() {
    final hour = _selectedTime.hour == 0
        ? 12
        : (_selectedTime.hour > 12
            ? _selectedTime.hour - 12
            : _selectedTime.hour);
    final minute = _selectedTime.minute.toString().padLeft(2, '0');
    final period = _selectedTime.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                const Text(
                  'New Happ',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A2E),
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Icon(Icons.close, color: Colors.grey.shade600),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Title field
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                hintText: 'Happ Title',
                hintStyle: TextStyle(color: Colors.grey.shade400),
                filled: true,
                fillColor: Colors.grey.shade50,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade200),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade200),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF3DB54A)),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Location field
            TextField(
              controller: _locationController,
              decoration: InputDecoration(
                hintText: 'Add Location',
                hintStyle: TextStyle(color: Colors.grey.shade400),
                filled: true,
                fillColor: Colors.grey.shade50,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade200),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade200),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF3DB54A)),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Date / Time row
            Row(
              children: [
                Text(
                  'Today - Now',
                  style: TextStyle(
                      fontSize: 14, color: Colors.grey.shade600),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: _pickTime,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _timeLabel(),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF1A1A2E),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Category chips
            Wrap(
              spacing: 8,
              children: _categories.map((cat) {
                final selected = cat == _selectedCategory;
                return GestureDetector(
                  onTap: () => setState(() => _selectedCategory = cat),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: selected
                          ? const Color(0xFF1A1A2E)
                          : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (selected) ...[
                          const Icon(Icons.check,
                              size: 14, color: Colors.white),
                          const SizedBox(width: 4),
                        ],
                        Text(
                          cat,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: selected
                                ? Colors.white
                                : Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 24),

            // Invite Friends button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1A1A2E),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  'Invite Friends',
                  style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ),
            ),

            const SizedBox(height: 10),

            // Add Happ button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3DB54A),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2),
                      )
                    : const Text(
                        'Add Happ',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w600),
                      ),
              ),
            ),

            const SizedBox(height: 10),

            // Cancel
            Center(
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Text(
                  'Cancel',
                  style: TextStyle(
                      fontSize: 14, color: Colors.grey.shade500),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
