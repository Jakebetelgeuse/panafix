import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'map_picker_page.dart';
import 'payment_page.dart';
import '../services/bcv_rate_service.dart';

class RequestPage extends StatefulWidget {
  final String technicianId;
  final String serviceName;
  final String technicianName;
  final double priceFrom;
  final String? categoryName;
  final String? city;

  const RequestPage({
    super.key,
    required this.technicianId,
    required this.serviceName,
    required this.technicianName,
    required this.priceFrom,
    this.categoryName,
    this.city,
  });

  @override
  State<RequestPage> createState() => _RequestPageState();
}

class _RequestPageState extends State<RequestPage> {
  static const double appCommissionPercent = 0.15;

  LatLng? selectedLocation;
  bool isSending = false;
  PlatformFile? selectedProblemPhoto;
  String? selectedProblemPhotoName;
  final TextEditingController detailsController = TextEditingController();
  final TextEditingController addressController = TextEditingController();

  Future<void> pickLocation() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const MapPickerPage(),
      ),
    );

    if (result != null && result is LatLng) {
      setState(() {
        selectedLocation = result;
      });
    }
  }

  Future<void> pickProblemPhoto() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );

    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    if (file.bytes == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo leer la foto seleccionada')),
      );
      return;
    }

    if (file.bytes!.lengthInBytes > 8 * 1024 * 1024) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('La foto debe pesar menos de 8 MB')),
      );
      return;
    }

    setState(() {
      selectedProblemPhoto = file;
      selectedProblemPhotoName = file.name;
    });
  }

  Future<String?> uploadProblemPhoto(String orderId) async {
    final file = selectedProblemPhoto;
    final bytes = file?.bytes;
    if (file == null || bytes == null) return null;

    final extension = (file.extension ?? 'jpg').toLowerCase();
    final ref = FirebaseStorage.instance.ref().child(
          'request_problem_photos/$orderId/problem.$extension',
        );

    await ref.putData(
      bytes,
      SettableMetadata(contentType: 'image/$extension'),
    );

    return ref.getDownloadURL();
  }

  Future<void> continueToPayment() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Debes iniciar sesion')),
      );
      return;
    }

    if (selectedLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona una ubicacion en el mapa')),
      );
      return;
    }

    final details = detailsController.text.trim();
    final address = addressController.text.trim();

    if (details.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Describe el trabajo o problema')),
      );
      return;
    }

    if (address.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Escribe la direccion del servicio')),
      );
      return;
    }

    setState(() {
      isSending = true;
    });

    try {
      final clientDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final technicianDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.technicianId)
          .get();

      final clientData = clientDoc.data();
      final technicianData = technicianDoc.data() ?? {};
      final clientCity = (clientData?['city'] ?? widget.city ?? '').toString();
      final clientPhotoUrl =
          (clientData?['profilePhotoUrl'] ?? user.photoURL ?? '').toString();
      final expiresAt = DateTime.now().add(const Duration(hours: 24));

      final double basePrice = widget.priceFrom;
      final double appCommission =
          double.parse((basePrice * appCommissionPercent).toStringAsFixed(2));
      final double finalPrice =
          double.parse((basePrice + appCommission).toStringAsFixed(2));
      final bcvRate = await BcvRateService.getRate();
      final finalPriceBs =
          bcvRate.isAvailable ? bcvRate.usdToVes(finalPrice) : 0.0;
      final basePriceBs =
          bcvRate.isAvailable ? bcvRate.usdToVes(basePrice) : 0.0;
      final appCommissionBs =
          bcvRate.isAvailable ? bcvRate.usdToVes(appCommission) : 0.0;

      final orderData = {
        'clientId': user.uid,
        'clientName': clientData?['name'] ?? user.email ?? 'Cliente',
        'clientEmail': user.email ?? '',
        'clientPhotoUrl': clientPhotoUrl,
        'technicianId': widget.technicianId,
        'technicianName': widget.technicianName,
        'technicianPhotoUrl': technicianData['profilePhotoUrl'] ?? '',
        'category': widget.categoryName ?? '',
        'city': clientCity,
        'serviceName': widget.serviceName,
        'service': widget.serviceName,
        'details': details,
        'description': details,
        'clientAddress': address,
        'address': address,
        'basePrice': basePrice,
        'basePriceUsd': basePrice,
        'basePriceBs': basePriceBs,
        'appCommission': appCommission,
        'appCommissionUsd': appCommission,
        'appCommissionBs': appCommissionBs,
        'appCommissionPercent': 15,
        'finalPrice': finalPrice,
        'finalPriceUsd': finalPrice,
        'finalPriceBs': finalPriceBs,
        'technicianEarning': basePrice,
        'technicianEarningUsd': basePrice,
        'technicianEarningBs': basePriceBs,
        'priceFrom': finalPrice,
        'currency': bcvRate.isAvailable ? 'VES' : 'USD',
        'currencyBase': 'USD',
        'bcvRate': bcvRate.rate,
        'bcvRateSource': bcvRate.source,
        'bcvRateDate': bcvRate.rateDate,
        'bcvRateSyncedOnline': bcvRate.fromInternet,
        'paymentMethod': '',
        'paymentReference': '',
        'paymentProofUrl': '',
        'paymentStatus': 'pending',
        'releaseStatus': 'pending',
        'status': 'awaiting_payment',
        'latitude': selectedLocation!.latitude,
        'longitude': selectedLocation!.longitude,
        'requestExpiresAt': Timestamp.fromDate(expiresAt),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      final orderDoc = await FirebaseFirestore.instance
          .collection('orders')
          .add(orderData);
      final problemPhotoUrl = await uploadProblemPhoto(orderDoc.id);
      if (problemPhotoUrl != null) {
        orderData['problemPhotoUrl'] = problemPhotoUrl;
        await orderDoc.update({
          'problemPhotoUrl': problemPhotoUrl,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      if (!mounted) return;

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PaymentPage(
            orderId: orderDoc.id,
            orderData: orderData,
            amount: finalPrice,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al continuar al pago: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          isSending = false;
        });
      }
    }
  }

  @override
  void dispose() {
    detailsController.dispose();
    addressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double displayedPrice =
        double.parse((widget.priceFrom * 1.15).toStringAsFixed(2));

    final locationText = selectedLocation == null
        ? 'No has seleccionado ubicacion'
        : 'Lat: ${selectedLocation!.latitude.toStringAsFixed(5)} | '
            'Lng: ${selectedLocation!.longitude.toStringAsFixed(5)}';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Confirmar solicitud'),
        centerTitle: true,
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.technicianName,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Text('Servicio: ${widget.serviceName}'),
            const SizedBox(height: 8),
            Text('Precio final: \$${displayedPrice.toStringAsFixed(2)}'),
            const SizedBox(height: 6),
            const Text(
              'Referencia en USD. El pago se congela en bolivares con la tasa BCV al momento de pagar.',
              style: TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: detailsController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Describe el trabajo',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: addressController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Direccion exacta',
                hintText: 'Ej: edificio, casa, piso, punto de referencia...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Ubicacion',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(locationText),
            const SizedBox(height: 6),
            const Text(
              'Confirma si el punto esta correcto. Si no, mueve el marcador en el mapa.',
              style: TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: pickLocation,
                icon: const Icon(Icons.map_outlined),
                label: const Text('Seleccionar ubicacion en mapa'),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: pickProblemPhoto,
                icon: const Icon(Icons.add_a_photo_outlined),
                label: Text(
                  selectedProblemPhotoName == null
                      ? 'Agregar foto del problema'
                      : 'Foto: $selectedProblemPhotoName',
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'La solicitud se elimina automaticamente si no avanza en 24 horas.',
              style: TextStyle(color: Colors.black54, fontSize: 12),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isSending ? null : continueToPayment,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: isSending
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Continuar al pago'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
