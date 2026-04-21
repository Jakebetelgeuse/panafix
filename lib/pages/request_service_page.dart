import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'map_picker_page.dart';
import 'payment_page.dart';
import '../services/bcv_rate_service.dart';

class RequestServicePage extends StatefulWidget {
  final String technicianId;
  final String technicianName;
  final String category;
  final String service;
  final String city;
  final double priceFrom;

  const RequestServicePage({
    super.key,
    required this.technicianId,
    required this.technicianName,
    required this.category,
    required this.service,
    required this.city,
    required this.priceFrom,
  });

  @override
  State<RequestServicePage> createState() => _RequestServicePageState();
}

class _RequestServicePageState extends State<RequestServicePage> {
  final TextEditingController detailsController = TextEditingController();
  final TextEditingController addressController = TextEditingController();
  bool isSaving = false;
  PlatformFile? selectedProblemPhoto;
  String? selectedProblemPhotoName;

  String? selectedCity;
  LatLng? selectedLocation;

  final List<String> venezuelaCities = const [
    'Caracas',
    'Maracaibo',
    'Valencia',
    'Barquisimeto',
    'Maracay',
    'Puerto La Cruz',
    'Maturin',
    'Ciudad Guayana',
    'San Cristobal',
    'Merida',
    'Cumana',
    'Barcelona',
    'Cabimas',
    'Punto Fijo',
    'Los Teques',
    'Guarenas',
    'Guatire',
    'Acarigua',
    'Puerto Ordaz',
    'La Guaira',
  ];

  @override
  void initState() {
    super.initState();
    selectedCity = venezuelaCities.contains(widget.city) ? widget.city : null;
  }

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

  Future<void> createRequest() async {
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Debes iniciar sesion')),
      );
      return;
    }

    if (selectedCity == null || selectedCity!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona una ciudad')),
      );
      return;
    }

    final details = detailsController.text.trim();
    final address = addressController.text.trim();

    if (details.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Describe el problema')),
      );
      return;
    }

    if (address.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Escribe la direccion del servicio')),
      );
      return;
    }

    if (selectedLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona la ubicacion del servicio')),
      );
      return;
    }

    setState(() {
      isSaving = true;
    });

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();

      final userData = userDoc.data() ?? {};
      final clientName =
          (userData['name'] ?? currentUser.email ?? 'Cliente').toString();
      final clientPhotoUrl =
          (userData['profilePhotoUrl'] ?? currentUser.photoURL ?? '').toString();
      final technicianDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.technicianId)
          .get();
      final technicianData = technicianDoc.data() ?? {};
      final expiresAt = DateTime.now().add(const Duration(hours: 24));

      const appCommissionPercent = 15;
      final finalPrice = double.parse(widget.priceFrom.toStringAsFixed(2));
      final basePrice = double.parse((finalPrice / 1.15).toStringAsFixed(2));
      final appCommission =
          double.parse((finalPrice - basePrice).toStringAsFixed(2));
      final bcvRate = await BcvRateService.getRate();
      final finalPriceBs =
          bcvRate.isAvailable ? bcvRate.usdToVes(finalPrice) : 0.0;
      final basePriceBs =
          bcvRate.isAvailable ? bcvRate.usdToVes(basePrice) : 0.0;
      final appCommissionBs =
          bcvRate.isAvailable ? bcvRate.usdToVes(appCommission) : 0.0;

      final orderData = {
        'clientId': currentUser.uid,
        'clientName': clientName,
        'clientEmail': currentUser.email ?? '',
        'clientPhotoUrl': clientPhotoUrl,
        'technicianId': widget.technicianId,
        'technicianName': widget.technicianName,
        'technicianPhotoUrl': technicianData['profilePhotoUrl'] ?? '',
        'category': widget.category,
        'service': widget.service,
        'serviceName': widget.service,
        'city': selectedCity,
        'details': details,
        'description': details,
        'clientAddress': address,
        'address': address,
        'basePrice': basePrice,
        'basePriceUsd': basePrice,
        'basePriceBs': basePriceBs,
        'technicianEarning': basePrice,
        'technicianEarningUsd': basePrice,
        'technicianEarningBs': basePriceBs,
        'finalPrice': finalPrice,
        'finalPriceUsd': finalPrice,
        'finalPriceBs': finalPriceBs,
        'priceFrom': finalPrice,
        'appCommission': appCommission,
        'appCommissionUsd': appCommission,
        'appCommissionBs': appCommissionBs,
        'appCommissionPercent': appCommissionPercent,
        'currency': bcvRate.isAvailable ? 'VES' : 'USD',
        'currencyBase': 'USD',
        'bcvRate': bcvRate.rate,
        'bcvRateSource': bcvRate.source,
        'bcvRateDate': bcvRate.rateDate,
        'bcvRateSyncedOnline': bcvRate.fromInternet,
        'status': 'awaiting_payment',
        'paymentStatus': 'pending',
        'releaseStatus': 'pending',
        'reviewed': false,
        'paymentMethod': '',
        'paymentReference': '',
        'paymentProofUrl': '',
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
        SnackBar(content: Text('Error al crear la solicitud: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          isSaving = false;
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

  Widget _infoRow(String title, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: Text(
              '$title:',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.black54,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final locationText = selectedLocation == null
        ? 'No has seleccionado ubicacion'
        : 'Lat: ${selectedLocation!.latitude.toStringAsFixed(5)} | '
            'Lng: ${selectedLocation!.longitude.toStringAsFixed(5)}';

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      appBar: AppBar(
        title: const Text('Confirmar solicitud'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Material(
              color: Colors.white,
              elevation: 2,
              borderRadius: BorderRadius.circular(22),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Resumen del servicio',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 28,
                          backgroundColor: Colors.orange.withOpacity(0.15),
                          child: const Icon(
                            Icons.person,
                            color: Colors.orange,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.technicianName,
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                widget.service,
                                style: const TextStyle(
                                  color: Colors.black54,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    _infoRow('Categoria', widget.category),
                    _infoRow('Servicio', widget.service),
                    _infoRow(
                      'Precio final',
                      '\$${widget.priceFrom.toStringAsFixed(2)}',
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Referencia en USD. El pago se congela en bolivares con la tasa BCV al momento de pagar.',
                      style: TextStyle(color: Colors.black54),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            Material(
              color: Colors.white,
              elevation: 2,
              borderRadius: BorderRadius.circular(22),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Ubicacion exacta',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      locationText,
                      style: const TextStyle(color: Colors.black54),
                    ),
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
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            Material(
              color: Colors.white,
              elevation: 2,
              borderRadius: BorderRadius.circular(22),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Direccion para el tecnico',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: addressController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Direccion exacta',
                        hintText:
                            'Ej: edificio, casa, piso, referencia, color de porton...',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            Material(
              color: Colors.white,
              elevation: 2,
              borderRadius: BorderRadius.circular(22),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Ciudad del servicio',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: venezuelaCities.contains(selectedCity)
                          ? selectedCity
                          : null,
                      decoration: const InputDecoration(
                        labelText: 'Selecciona una ciudad',
                        border: OutlineInputBorder(),
                      ),
                      items: venezuelaCities.map((city) {
                        return DropdownMenuItem(
                          value: city,
                          child: Text(city),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          selectedCity = value;
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            Material(
              color: Colors.white,
              elevation: 2,
              borderRadius: BorderRadius.circular(22),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Describe el problema',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: detailsController,
                      maxLines: 5,
                      decoration: InputDecoration(
                        hintText:
                            'Ejemplo: el tomacorriente no funciona y huele a quemado...',
                        filled: true,
                        fillColor: const Color(0xFFF7F7F7),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
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
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.08),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Text(
                'Antes de que el tecnico vaya en camino, el pago debe quedar enviado y luego aprobado para mantenerlo retenido en la plataforma.',
                style: TextStyle(
                  color: Colors.black87,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isSaving ? null : createRequest,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: isSaving
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                    : const Text(
                        'Continuar al pago',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
