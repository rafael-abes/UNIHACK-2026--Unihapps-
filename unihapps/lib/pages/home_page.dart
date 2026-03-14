import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  LatLng currentLocation = LatLng(37.33500926, -122.03272188);
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Home')),
      body: GoogleMap(
        initialCameraPosition: CameraPosition(
          target: currentLocation,
          zoom: 14.5,
        ),
        markers: {
          Marker(
            markerId: const MarkerId('currentLocation'),
            position: currentLocation,
          ),
        },
      ),
    );
  }
}
