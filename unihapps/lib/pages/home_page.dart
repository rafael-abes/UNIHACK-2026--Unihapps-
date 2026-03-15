import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final Completer<GoogleMapController> _googleMapController = Completer();

  final Location _location = Location();
  LocationData? locationData;

  BitmapDescriptor profileIcon = BitmapDescriptor.defaultMarker;

  void setCustomIcon() async {
    try {
      final iconsResult = await Future.wait([
        BitmapDescriptor.fromAssetImage(
        const ImageConfiguration(size: Size(15, 15)),
        'unihapps/assets/profilepicture.png',
    )
      ]);

      setState(() {
        profileIcon = iconsResult[0];
      });

    } catch (e) {
      print('Error loading custom icon: $e');
    }
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
 
  @override
  void initState() {
    super.initState();
    getCurrentLocation();
  }

  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Home')),

      body: locationData == null
          ? const Center(child: CircularProgressIndicator())
          : GoogleMap(
          onMapCreated: (controller) => _googleMapController.complete(controller),
          initialCameraPosition: CameraPosition(
            target: LatLng(locationData!.latitude!, locationData!.longitude!),
            zoom: 14.5,
          ),
          markers: {
            if (locationData != null)
              Marker(
                markerId: const MarkerId('currentLocation'),
                position: LatLng(locationData!.latitude!, locationData!.longitude!),
              ),
          },
      ),
    );
  }
}
