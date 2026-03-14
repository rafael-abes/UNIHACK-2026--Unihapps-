import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';
import '../repositories/user_repositories.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final Completer<GoogleMapController> _googleMapController = Completer();

  final Location _location = Location();
  LocationData? locationData;

  final UserRepository _userRepository = UserRepository();
  final String userId = 'exampleUserId'; // Replace with actual user ID

  final List<String> statuses = ['offline', 'free', 'busy', 'in-class'];
  final Map<String, Color> statusColors = {
  'offline': Colors.grey,
  'free': Colors.green,
  'busy': Colors.red,
  'in-class': Colors.blue,
  };

  String currentStatus = 'offline';//Default status

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

      _location.onLocationChanged.listen((LocationData newLocationData) async{
        
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
        });

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

    try {
      await _userRepository.updateUserStatus(userId, newStatus);
    } catch (e) {
      print('Error updating status: $e');
    }
  }
 
  @override
  void initState() {
    super.initState();
    getCurrentLocation();
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
                    markers: {
                      Marker(
                        markerId: const MarkerId('currentLocation'),
                        position: LatLng(
                            locationData!.latitude!, locationData!.longitude!),
                      ),
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
