import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

import 'order_chat_page.dart';
import 'order_tracking_page.dart';

class TechnicianRequestsPage extends StatefulWidget {
  const TechnicianRequestsPage({super.key});

  @override
  State<TechnicianRequestsPage> createState() => _TechnicianRequestsPageState();
}

class _TechnicianRequestsPageState extends State<TechnicianRequestsPage> {
  StreamSubscription<Position>? _positionSubscription;
  String? _trackingOrderId;

  Future<void> createNotification({
    required String userId,
    required String title,
    required String message,
    required String type,
    required String orderId,
  }) async {
    await FirebaseFirestore.instance.collection('notifications').add({
      'userId': userId,
      'title': title,
      'message': message,
      'type': type,
      'isRead': false,
      'orderId': orderId,
      'createdAt': FieldValue.serverTimestamp(),
      'expiresAt': Timestamp.fromDate(
        DateTime.now().add(const Duration(days: 30)),
      ),
    });
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    super.dispose();
  }

  Future<void> updateOrderStatus(String orderId, String newStatus) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      throw Exception('No hay técnico autenticado');
    }

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    final userData = userDoc.data() ?? {};
    final technicianName =
    (userData['name'] ?? user.displayName ?? 'Técnico').toString();

    final technicianPhotoUrl =
        (userData['profilePhotoUrl'] ?? user.photoURL ?? '').toString();

    final updateData = <String, dynamic>{
      'status': newStatus,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (newStatus == 'accepted') {
      updateData['technicianId'] = user.uid;
      updateData['technicianName'] = technicianName;
      updateData['technicianPhotoUrl'] = technicianPhotoUrl;
      updateData['requestExpiresAt'] = null;
    }

    if (newStatus == 'rejected') {
      updateData['technicianId'] = null;
      updateData['technicianName'] = null;
      updateData['trackingActive'] = false;
    }

    if (newStatus == 'completed') {
      updateData['trackingActive'] = false;
      updateData['completedAt'] = FieldValue.serverTimestamp();
    }

    await FirebaseFirestore.instance
        .collection('orders')
        .doc(orderId)
        .update(updateData);
  }

  Future<Map<String, dynamic>> getTechnicianData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return {
        'city': null,
        'services': <String>[],
        'name': null,
        'isAvailable': false,
      };
    }

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    final data = doc.data() ?? {};

    return {
      'city': data['city']?.toString(),
      'services': List<String>.from(data['services'] ?? []),
      'name': (data['name'] ?? user.displayName ?? 'Técnico').toString(),
      'isAvailable': data['isAvailable'] != false,
    };
  }

  Future<void> openInGoogleMaps(double latitude, double longitude) async {
    final Uri url = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude',
    );

    final opened = await launchUrl(
      url,
      mode: LaunchMode.externalApplication,
    );

    if (!opened) {
      throw Exception('No se pudo abrir Google Maps');
    }
  }

  Future<void> openExternalUrl(String url) async {
    if (url.isEmpty) return;
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<bool> _ensureLocationPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;

    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return false;
    }

    return true;
  }

  Future<void> _startTracking(String orderId) async {
    final hasPermission = await _ensureLocationPermission();
    if (!hasPermission) {
      throw Exception('No se pudo obtener permiso de ubicación');
    }

    await _positionSubscription?.cancel();

    _trackingOrderId = orderId;

    await FirebaseFirestore.instance.collection('orders').doc(orderId).update({
      'trackingActive': true,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 20,
      ),
    ).listen((position) async {
      if (_trackingOrderId == null) return;

      await FirebaseFirestore.instance
          .collection('orders')
          .doc(_trackingOrderId)
          .update({
        'technicianLatitude': position.latitude,
        'technicianLongitude': position.longitude,
        'trackingUpdatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> _stopTracking() async {
    await _positionSubscription?.cancel();
    _positionSubscription = null;
    _trackingOrderId = null;
  }

  Widget _personAvatar(String? photoUrl, String name) {
    if (photoUrl != null && photoUrl.isNotEmpty) {
      return CircleAvatar(
        radius: 24,
        backgroundImage: NetworkImage(photoUrl),
      );
    }

    return CircleAvatar(
      radius: 24,
      backgroundColor: const Color(0xFFFFEDD8),
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : '?',
        style: const TextStyle(
          color: Color(0xFFFF7A00),
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Color getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'accepted':
        return Colors.green;
      case 'on_the_way':
        return Colors.blue;
      case 'arrived':
        return Colors.deepOrange;
      case 'working':
        return Colors.teal;
      case 'completed':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String getStatusLabel(String status) {
    switch (status) {
      case 'pending':
        return 'Pendiente';
      case 'accepted':
        return 'Aceptada';
      case 'on_the_way':
        return 'En camino';
      case 'arrived':
        return 'Llegué';
      case 'working':
        return 'Trabajando';
      case 'completed':
        return 'Completada';
      case 'rejected':
        return 'Rechazada';
      default:
        return status;
    }
  }

  IconData getServiceIcon(String service) {
    final s = service.toLowerCase();

    if (s.contains('plom') || s.contains('fontan')) return Icons.plumbing;
    if (s.contains('electric')) return Icons.electrical_services;
    if (s.contains('aire')) return Icons.ac_unit;
    if (s.contains('pint')) return Icons.format_paint;
    if (s.contains('cerra')) return Icons.lock;
    if (s.contains('limp')) return Icons.cleaning_services;
    if (s.contains('carpin')) return Icons.handyman;
    if (s.contains('internet') || s.contains('wifi') || s.contains('tv')) {
      return Icons.wifi;
    }

    return Icons.build;
  }

  String formatPrice(dynamic price) {
    if (price == null) return 'No definido';
    if (price is num) return '\$${price.toStringAsFixed(2)}';
    return '\$$price';
  }

  String formatTechnicianEarning(Map<String, dynamic> data) {
    final earningBs =
        (data['technicianEarningBs'] ?? data['basePriceBs']) as num?;
    if (earningBs != null && earningBs > 0) {
      return 'Bs ${earningBs.toDouble().toStringAsFixed(2)}';
    }

    return formatPrice(data['technicianEarning'] ?? data['basePrice']);
  }

  bool matchesTechnicianServices(
      String orderService,
      List<String> technicianServices,
      ) {
    final normalizedOrderService = orderService.trim().toLowerCase();

    return technicianServices.any(
          (service) => service.trim().toLowerCase() == normalizedOrderService,
    );
  }

  Widget buildOrderCard(DocumentSnapshot orderDoc, BuildContext context) {
    final data = orderDoc.data() as Map<String, dynamic>? ?? {};

    final service = ((data['service'] ?? data['serviceName'] ?? 'Servicio sin nombre'))
        .toString();
    final city = (data['city'] ?? 'Ciudad no indicada').toString();
    final description =
    (data['description'] ?? data['details'] ?? 'Sin descripción').toString();
    final clientAddress =
        (data['clientAddress'] ?? data['address'] ?? '').toString();
    final problemPhotoUrl = (data['problemPhotoUrl'] ?? '').toString();
    final clientName = (data['clientName'] ?? 'Cliente').toString();
    final clientPhotoUrl = (data['clientPhotoUrl'] ?? '').toString();
    final status = (data['status'] ?? 'pending').toString();
    final paymentStatus = (data['paymentStatus'] ?? 'pending').toString();

    final technicianEarning =
        data['technicianEarningBs'] ?? data['basePriceBs'] ?? data['technicianEarning'] ?? data['basePrice'];

    final latitude = (data['latitude'] as num?)?.toDouble();
    final longitude = (data['longitude'] as num?)?.toDouble();

    return Card(
      elevation: 4,
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: Colors.blue.withValues(alpha: 0.12),
                  child: Icon(
                    getServiceIcon(service),
                    color: Colors.blue,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    service,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: getStatusColor(status).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    getStatusLabel(status),
                    style: TextStyle(
                      color: getStatusColor(status),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                _personAvatar(clientPhotoUrl, clientName),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Cliente',
                        style: TextStyle(
                          color: Colors.black54,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        clientName,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text('Ciudad: $city'),
            if (clientAddress.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                'Direccion: $clientAddress',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
            const SizedBox(height: 6),
            Text('Descripción: $description'),
            const SizedBox(height: 6),
            if (technicianEarning != null) ...[
              const SizedBox(height: 4),
              Text(
                'Tu ganancia estimada: ${formatTechnicianEarning(data)}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
            ],
            const SizedBox(height: 6),
            Text(
              paymentStatus == 'paid' || paymentStatus == 'released'
                  ? 'Pago retenido y aprobado'
                  : paymentStatus == 'review'
                      ? 'Pago enviado, pendiente por aprobacion'
                      : 'Pago pendiente',
              style: TextStyle(
                color: paymentStatus == 'paid' || paymentStatus == 'released'
                    ? Colors.green
                    : Colors.orange,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (latitude != null && longitude != null) ...[
              const SizedBox(height: 6),
              Text(
                'Destino: ${latitude.toStringAsFixed(5)}, ${longitude.toStringAsFixed(5)}',
              ),
            ],
            if (problemPhotoUrl.isNotEmpty) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => openExternalUrl(problemPhotoUrl),
                  icon: const Icon(Icons.image_outlined),
                  label: const Text('Ver foto del problema'),
                ),
              ),
            ],
            const SizedBox(height: 16),
            if ((data['clientId'] ?? '').toString().isNotEmpty &&
                status == 'on_the_way')
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => OrderChatPage(
                            orderId: orderDoc.id,
                            otherUserId: (data['clientId'] ?? '').toString(),
                            otherUserName: clientName,
                            serviceName: service,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.chat_bubble_outline),
                    label: const Text('Abrir chat'),
                  ),
                ),
              ),
            if (latitude != null && longitude != null)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    try {
                      await openInGoogleMaps(latitude, longitude);
                    } catch (e) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error al abrir Maps: $e')),
                      );
                    }
                  },
                  icon: const Icon(Icons.map),
                  label: const Text('Abrir en Google Maps'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            if (latitude != null && longitude != null)
              const SizedBox(height: 12),
            if (status == 'on_the_way' ||
                status == 'arrived' ||
                status == 'completed')
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => OrderTrackingPage(orderId: orderDoc.id),
                      ),
                    );
                  },
                  icon: const Icon(Icons.location_on),
                  label: const Text('Ver aproximacion'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            if (status == 'on_the_way' ||
                status == 'arrived' ||
                status == 'completed')
              const SizedBox(height: 12),
            if (status == 'pending')
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        try {
                          await updateOrderStatus(orderDoc.id, 'accepted');
                          final clientId = data['clientId']?.toString() ?? '';
                          if (clientId.isNotEmpty) {
                            await createNotification(
                              userId: clientId,
                              title: 'Solicitud aceptada',
                              message:
                                  'Tu tecnico ya acepto el servicio "$service".',
                              type: 'request',
                              orderId: orderDoc.id,
                            );
                          }
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Trabajo aceptado')),
                          );
                        } catch (e) {
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error al aceptar: $e')),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Aceptar'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        try {
                          final clientId = data['clientId']?.toString() ?? '';
                          final serviceName =
                              (data['service'] ?? data['serviceName'] ?? service)
                                  .toString();
                          await updateOrderStatus(orderDoc.id, 'rejected');
                          if (clientId.isNotEmpty) {
                            await createNotification(
                              userId: clientId,
                              title: 'Tecnico no disponible',
                              message:
                                  'El tecnico no pudo tomar "$serviceName". Puedes solicitar otro tecnico de inmediato.',
                              type: 'request',
                              orderId: orderDoc.id,
                            );
                          }
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Trabajo rechazado')),
                          );
                        } catch (e) {
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error al rechazar: $e')),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Rechazar'),
                    ),
                  ),
                ],
              )
            else if (status == 'accepted')
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    if (paymentStatus != 'paid' &&
                        paymentStatus != 'released') {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'No puedes ir en camino hasta que el pago este aprobado.',
                          ),
                        ),
                      );
                      return;
                    }

                    try {
                      await updateOrderStatus(orderDoc.id, 'on_the_way');
                      await _startTracking(orderDoc.id);
                      final clientId = data['clientId']?.toString() ?? '';
                      if (clientId.isNotEmpty) {
                        await createNotification(
                          userId: clientId,
                          title: 'Tecnico en camino',
                          message:
                              'Tu tecnico va en camino para el servicio "$service".',
                          type: 'job',
                          orderId: orderDoc.id,
                        );
                      }
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Marcado como en camino con tracking'),
                        ),
                      );
                    } catch (e) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error al actualizar: $e')),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Marcar en camino'),
                ),
              )
            else if (status == 'on_the_way')
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      try {
                        await updateOrderStatus(orderDoc.id, 'arrived');
                        await _stopTracking();
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Marcado como llegado')),
                        );
                      } catch (e) {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error al actualizar: $e')),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepOrange,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Marcar llegada'),
                  ),
                )
              else if (status == 'arrived')
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                      try {
                        await updateOrderStatus(orderDoc.id, 'working');
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Trabajo en progreso')),
                          );
                        } catch (e) {
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error al actualizar: $e')),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Iniciar trabajo'),
                    ),
                  )
                else if (status == 'working')
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        try {
                          await updateOrderStatus(orderDoc.id, 'completed');
                          await _stopTracking();
                          final clientId = data['clientId']?.toString() ?? '';
                          if (clientId.isNotEmpty) {
                            await createNotification(
                              userId: clientId,
                              title: 'Servicio completado',
                              message:
                                  'El tecnico marco como completado el servicio "$service".',
                              type: 'job',
                              orderId: orderDoc.id,
                            );
                          }
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Trabajo completado')),
                          );
                        } catch (e) {
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error al actualizar: $e')),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Marcar completado'),
                    ),
                  )
                else
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: null,
                      child: Text(
                        status == 'rejected'
                            ? 'Trabajo rechazado'
                            : status == 'completed'
                            ? 'Trabajo completado'
                            : 'Estado: ${getStatusLabel(status)}',
                      ),
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: getTechnicianData(),
      builder: (context, technicianSnapshot) {
        if (technicianSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (technicianSnapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                'Error al cargar el perfil del técnico:\n${technicianSnapshot.error}',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        final technicianData = technicianSnapshot.data ?? {};
        final technicianCity = technicianData['city']?.toString();
        final technicianServices =
        List<String>.from(technicianData['services'] ?? []);
        final isAvailable = technicianData['isAvailable'] != false;

        if (!isAvailable) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                'Activa tu disponibilidad en el perfil para recibir nuevas solicitudes.',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        if (technicianCity == null || technicianCity.trim().isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                'Primero debes guardar tu ciudad en el perfil del técnico',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        if (technicianServices.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                'Primero debes guardar los servicios que ofreces en tu perfil',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        final currentUser = FirebaseAuth.instance.currentUser;

        final ordersStream = FirebaseFirestore.instance
            .collection('orders')
            .where('city', isEqualTo: technicianCity)
            .snapshots();

        return StreamBuilder<QuerySnapshot>(
          stream: ordersStream,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    'Ocurrió un error:\n${snapshot.error}',
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }

            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final allDocs = snapshot.data?.docs ?? [];

            final filteredDocs = allDocs.where((doc) {
              final data = doc.data() as Map<String, dynamic>? ?? {};

              final orderService =
              ((data['service'] ?? data['serviceName'] ?? '')).toString().trim();
              final status = (data['status'] ?? 'pending').toString();
              final technicianId = (data['technicianId'] ?? '').toString();
              final expiresAt = data['requestExpiresAt'] as Timestamp?;
              final isExpired = expiresAt != null &&
                  expiresAt.toDate().isBefore(DateTime.now());

              if (orderService.isEmpty) return false;
              if (isExpired &&
                  status != 'accepted' &&
                  status != 'on_the_way' &&
                  status != 'arrived' &&
                  status != 'working' &&
                  status != 'completed') {
                return false;
              }

              final matchesService = matchesTechnicianServices(
                orderService,
                technicianServices,
              );

              final isMine = technicianId == currentUser?.uid;

              return matchesService && (status == 'pending' || isMine);
            }).toList();

            if (filteredDocs.isEmpty) {
              return Padding(
                padding: const EdgeInsets.all(20),
                child: Center(
                  child: Text(
                    'No hay solicitudes disponibles en $technicianCity para tus servicios por ahora',
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: filteredDocs.length,
              itemBuilder: (context, index) {
                return buildOrderCard(filteredDocs[index], context);
              },
            );
          },
        );
      },
    );
  }
}
