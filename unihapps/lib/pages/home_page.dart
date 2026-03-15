import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';
import 'friends_list.dart';
import 'profile_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'group_detail.dart';
import 'group_list.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../repositories/user_repositories.dart';
import 'package:firebase_auth/firebase_auth.dart';

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

      final GoogleMapController controller = await _googleMapController.future;

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

         // STORE LOCATION IN FIRESTORE
          // if (userId != null) {
          //   await _userRepository.updateUserLocation(
          //     userId!,
          //     newLocationData.latitude!,
          //     newLocationData.longitude!,
          //   );
          // }
        });
    }
    catch (e) {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('UniHapps'),
        backgroundColor: statusColors[currentStatus] ?? Colors.grey,
        elevation: 0,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(10),
            // child: SegmentedButton<String>(
            //   segments: const [
            //     ButtonSegment(value: 'offline', label: Text('Offline')),
            //     ButtonSegment(value: 'free', label: Text('Free')),
            //     ButtonSegment(value: 'busy', label: Text('Busy')),
            //     ButtonSegment(value: 'in-class', label: Text('In-class')),
            //   ],
            //   selected: {currentStatus},
            //   onSelectionChanged: (newSelection) {
            //     _setStatus(newSelection.first);
            //   },
            // ),
          ),
          Expanded(
            child: locationData == null
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
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 1,
        onTap: (index) {
          if (index == 0) {
            _showFriendsSheet();
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
            label: 'Home',
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
                // People tab
                uid == null
                    ? const SizedBox()
                    : StreamBuilder<DocumentSnapshot>(
                        stream: _firestore
                            .collection('users')
                            .doc(uid)
                            .snapshots(),
                        builder: (context, snapshot) {
                          final friendIds = (snapshot.data?.exists ?? false)
                              ? List<String>.from(
                                  (snapshot.data?.data()
                                          as Map<
                                            String,
                                            dynamic
                                          >?)?['friends'] ??
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

                          return FutureBuilder<List<Map<String, dynamic>>>(
                            future: Future.wait(
                              friendIds.map(
                                (id) => _firestore
                                    .collection('users')
                                    .doc(id)
                                    .get()
                                    .then(
                                      (doc) => {'uid': doc.id, ...?doc.data()},
                                    ),
                              ),
                            ),
                            builder: (context, friendsSnap) {
                              if (!friendsSnap.hasData) {
                                return const Center(
                                  child: CircularProgressIndicator(),
                                );
                              }

                              return ListView.builder(
                                padding: const EdgeInsets.all(12),
                                itemCount: friendsSnap.data!.length,
                                itemBuilder: (context, index) {
                                  final friend = friendsSnap.data![index];
                                  final displayName =
                                      '${friend['firstName'] ?? ''} ${friend['lastName'] ?? ''}'
                                          .trim();
                                  final username = friend['username'] ?? '';
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
                                          color: Colors.deepPurple.withOpacity(
                                            0.04,
                                          ),
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
                                          initials,
                                          style: const TextStyle(
                                            color: Colors.deepPurple,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
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

                // Groups tab
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
                            return Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.group_outlined,
                                    size: 48,
                                    color: Colors.grey,
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'No groups yet',
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
                                          builder: (_) => const GroupsPage(),
                                        ),
                                      );
                                    },
                                    child: const Text('Create Group'),
                                  ),
                                ],
                              ),
                            );
                          }

                          return ListView.builder(
                            padding: const EdgeInsets.all(12),
                            itemCount: groups.length,
                            itemBuilder: (context, index) {
                              final data =
                                  groups[index].data() as Map<String, dynamic>;
                              final name = data['name'] as String? ?? '';
                              final memberCount =
                                  (data['members'] as List?)?.length ?? 0;

                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(14),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.deepPurple.withOpacity(
                                        0.04,
                                      ),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: Colors.blue.shade100,
                                    child: Text(
                                      name.isNotEmpty
                                          ? name[0].toUpperCase()
                                          : '?',
                                      style: const TextStyle(
                                        color: Colors.blue,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  title: Text(
                                    name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  subtitle: Text(
                                    '$memberCount member${memberCount != 1 ? 's' : ''}',
                                    style: const TextStyle(
                                      color: Colors.grey,
                                      fontSize: 13,
                                    ),
                                  ),
                                  trailing: const Icon(
                                    Icons.chevron_right,
                                    color: Colors.grey,
                                  ),
                                  onTap: () {
                                    Navigator.pop(context);
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => GroupDetailPage(
                                          groupId: groups[index].id,
                                        ),
                                      ),
                                    );
                                  },
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
