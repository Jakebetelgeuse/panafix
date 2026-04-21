import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class NearbyTechniciansMap extends StatefulWidget {
  const NearbyTechniciansMap({super.key});

  @override
  State<NearbyTechniciansMap> createState() => _NearbyTechniciansMapState();
}

class _NearbyTechniciansMapState extends State<NearbyTechniciansMap> {

  final Set<Marker> markers = {};

  Future<void> loadTechnicians() async {

    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'technician')
        .get();

    for (var doc in snapshot.docs) {

      final data = doc.data();

      final lat = data['latitude'];
      final lng = data['longitude'];

      if (lat != null && lng != null) {

        markers.add(
          Marker(
            markerId: MarkerId(doc.id),
            position: LatLng(lat, lng),
            infoWindow: InfoWindow(
              title: data['name'] ?? 'Técnico',
              snippet: data['category'] ?? '',
            ),
          ),
        );
      }
    }

    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    loadTechnicians();
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: AppBar(
        title: const Text('Técnicos cercanos'),
      ),

      body: GoogleMap(
        initialCameraPosition: const CameraPosition(
          target: LatLng(33.7490, -84.3880),
          zoom: 12,
        ),
        markers: markers,
      ),
    );
  }
}
