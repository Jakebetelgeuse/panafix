import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class MapPickerPage extends StatefulWidget {
  const MapPickerPage({super.key});

  @override
  State<MapPickerPage> createState() => _MapPickerPageState();
}

class _MapPickerPageState extends State<MapPickerPage> {
  LatLng selectedLocation = const LatLng(10.4806, -66.9036);
  GoogleMapController? mapController;
  bool isLoadingLocation = true;
  bool locationPermissionGranted = false;
  String? locationMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      loadClientLocation();
    });
  }

  Future<void> loadClientLocation() async {
    setState(() {
      isLoadingLocation = true;
      locationMessage = null;
    });

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          isLoadingLocation = false;
          locationPermissionGranted = false;
          locationMessage =
              'Activa la ubicacion del telefono para detectar donde estas.';
        });
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        setState(() {
          isLoadingLocation = false;
          locationPermissionGranted = false;
          locationMessage =
              'No se pudo usar tu ubicacion. Puedes mover el pin manualmente.';
        });
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      final currentLocation = LatLng(position.latitude, position.longitude);

      setState(() {
        selectedLocation = currentLocation;
        isLoadingLocation = false;
        locationPermissionGranted = true;
        locationMessage =
            'Ubicacion detectada. Mueve el pin si el punto no esta exacto.';
      });

      await mapController?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: currentLocation, zoom: 17),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        isLoadingLocation = false;
        locationPermissionGranted = false;
        locationMessage =
            'No se pudo detectar tu ubicacion. Puedes mover el pin manualmente.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Confirma tu ubicacion'),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          GoogleMap(
            onMapCreated: (controller) {
              mapController = controller;
            },
            initialCameraPosition: CameraPosition(
              target: selectedLocation,
              zoom: 14,
            ),
            onTap: (LatLng position) {
              setState(() {
                selectedLocation = position;
              });
            },
            markers: {
              Marker(
                markerId: const MarkerId('selected_location'),
                position: selectedLocation,
              ),
            },
            myLocationButtonEnabled: false,
            myLocationEnabled: locationPermissionGranted,
            zoomControlsEnabled: true,
          ),
          Positioned(
            left: 16,
            right: 16,
            top: 16,
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.10),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: const Text(
                'Primero detectamos tu ubicacion. Si el punto no esta exacto, toca el mapa para mover el pin.',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
          if (locationMessage != null)
            Positioned(
              left: 16,
              right: 16,
              bottom: 96,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.75),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  locationMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          if (isLoadingLocation)
            Container(
              color: Colors.black.withOpacity(0.12),
              child: const Center(
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.all(18),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 12),
                        Text('Detectando tu ubicacion...'),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.pop(context, selectedLocation);
        },
        icon: const Icon(Icons.check),
        label: const Text('Si, es aqui'),
      ),
    );
  }
}
