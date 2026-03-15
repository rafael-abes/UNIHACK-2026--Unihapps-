import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';
import 'friends_list.dart';
import 'profile_page.dart';
import '../repositories/user_repositories.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final Completer<GoogleMapController> _googleMapController = Completer();

  final Location _location = Location();
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

  String currentStatus = 'offline';//Default status

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
        interval: 1000, // Update every 1 second
        distanceFilter: 0, // Update even if the distance change is 0 meters
      );

      LocationData currentLocationData = await _location.getLocation();
      setState(() {
        locationData = currentLocationData;
      });

      final GoogleMapController controller = await _googleMapController.future;

      await controller.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(currentLocationData.latitude!, currentLocationData.longitude!),
            zoom: 14.5,
          ),
        ),
      );

      _location.onLocationChanged.listen((LocationData newLocationData) async {
        controller.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(
              target: LatLng(newLocationData.latitude!, newLocationData.longitude!),
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

    Future<void> setStatus(String newStatus) async {
    setState(() {
      currentStatus = newStatus;
    });

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

  @override
  void dispose() {
    _locationTimer?.cancel();
    _friendsSubscription?.cancel();
    super.dispose();
  }


  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        backgroundColor: statusColors[currentStatus] ?? Colors.grey,
      ),
      body: Column(
        children: [

          Padding(
            padding: const EdgeInsets.all(10),
            child: SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'offline', label: Text('Offline')),
                ButtonSegment(value: 'free', label: Text('Free')),
                ButtonSegment(value: 'busy', label: Text('Busy')),
                ButtonSegment(value: 'in-class', label: Text('In-class')),
              ],
              selected: {currentStatus},
              onSelectionChanged: (newSelection) {
                setStatus(newSelection.first);
              },
            ),
          ),

          Expanded(
            child: locationData == null
                ? const Center(child: CircularProgressIndicator())
                : GoogleMap(
                    onMapCreated: (controller) =>
                        _googleMapController.complete(controller),
                    initialCameraPosition: CameraPosition(
                      target: LatLng(
                          locationData!.latitude!, locationData!.longitude!),
                      zoom: 14.5,
                    ),
                    markers: _markers,
                  ),
          ),
        ],
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
              MaterialPageRoute(builder: (_) => const FriendsPage()),
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
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Me',
          ),
        ],
      ),
    );
  }
}
