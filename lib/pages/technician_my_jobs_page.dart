import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'order_chat_page.dart';
import 'order_tracking_page.dart';
import 'rate_client_page.dart';

class TechnicianMyJobsPage extends StatelessWidget {
  const TechnicianMyJobsPage({super.key});

  User? get user => FirebaseAuth.instance.currentUser;

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

  Future<void> updateOrderStatus(String orderId, String newStatus) async {
    final data = <String, dynamic>{
      'status': newStatus,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (newStatus == 'completed') {
      data['completedAt'] = FieldValue.serverTimestamp();
      data['trackingActive'] = false;
    }

    if (newStatus == 'accepted') {
      data['requestExpiresAt'] = null;
    }

    await FirebaseFirestore.instance
        .collection('orders')
        .doc(orderId)
        .update(data);
  }

  Future<void> openInGoogleMaps(double latitude, double longitude) async {
    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude',
    );
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> openExternalUrl(String url) async {
    if (url.isEmpty) return;
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Color getStatusColor(String status) {
    switch (status) {
      case 'accepted':
        return Colors.green;
      case 'on_the_way':
        return Colors.blue;
      case 'arrived':
        return Colors.orange;
      case 'working':
        return Colors.teal;
      case 'completed':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  String getStatusLabel(String status) {
    switch (status) {
      case 'accepted':
        return 'Aceptado';
      case 'on_the_way':
        return 'En camino';
      case 'arrived':
        return 'Llegó';
      case 'completed':
        return 'Completado';
      default:
        return status;
    }
  }

  IconData getServiceIcon(String service) {
    final s = service.toLowerCase();

    if (s.contains('plom')) return Icons.plumbing;
    if (s.contains('electric')) return Icons.electrical_services;
    if (s.contains('aire')) return Icons.ac_unit;
    if (s.contains('pint')) return Icons.format_paint;
    if (s.contains('cerra')) return Icons.lock;
    if (s.contains('limp')) return Icons.cleaning_services;
    if (s.contains('carpin')) return Icons.handyman;

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

  Future<void> takeJob(String orderId) async {
    if (user == null) return;

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .get();
    final userData = userDoc.data() ?? {};

    await FirebaseFirestore.instance.collection('orders').doc(orderId).update({
      'technicianId': user!.uid,
      'technicianName':
          (userData['name'] ?? user!.displayName ?? 'Tecnico').toString(),
      'technicianPhotoUrl':
          (userData['profilePhotoUrl'] ?? user!.photoURL ?? '').toString(),
      'status': 'accepted',
      'requestExpiresAt': null,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Widget buildActionButtons(
      BuildContext context,
      String orderId,
      String status,
      String paymentStatus,
      String clientId,
      String clientName,
      String clientPhotoUrl,
      bool clientReviewedByTechnician,
      String service,
      ) {
    if (status == 'accepted') {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          onPressed: () async {
            if (paymentStatus != 'paid' &&
                paymentStatus != 'released') {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'No puedes ir en camino hasta que el pago este aprobado.',
                    ),
                  ),
                );
              }
              return;
            }

            try {
              await updateOrderStatus(orderId, 'on_the_way');
              if (clientId.isNotEmpty) {
                await createNotification(
                  userId: clientId,
                  title: 'Tecnico en camino',
                  message:
                      'Tu tecnico va en camino para el servicio "$service".',
                  type: 'job',
                  orderId: orderId,
                );
              }

              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Marcado como en camino')),
                );
              }
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: $e')),
                );
              }
            }
          },
          child: const Text('En camino'),
        ),
      );
    }

    if (status == 'on_the_way') {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          onPressed: () async {
            try {
              await updateOrderStatus(orderId, 'arrived');

              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Marcado como llegado')),
                );
              }
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: $e')),
                );
              }
            }
          },
          child: const Text('Llegué'),
        ),
      );
    }

    if (status == 'arrived') {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.teal,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          onPressed: () async {
            try {
              await updateOrderStatus(orderId, 'working');

              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Trabajo en progreso')),
                );
              }
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: $e')),
                );
              }
            }
          },
          child: const Text('Iniciar trabajo'),
        ),
      );
    }

    if (status == 'working') {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          onPressed: () async {
            try {
              await updateOrderStatus(orderId, 'completed');
              if (clientId.isNotEmpty) {
                await createNotification(
                  userId: clientId,
                  title: 'Servicio completado',
                  message:
                      'El tecnico marco como completado el servicio "$service".',
                  type: 'job',
                  orderId: orderId,
                );
              }

              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Trabajo completado')),
                );
                if (clientId.isNotEmpty) {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => RateClientPage(
                        orderId: orderId,
                        clientId: clientId,
                        clientName: clientName,
                        clientPhotoUrl: clientPhotoUrl,
                        serviceName: service,
                      ),
                    ),
                  );
                }
              }
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: $e')),
                );
              }
            }
          },
          child: const Text('Completar trabajo'),
        ),
      );
    }

    if (status == 'completed' && !clientReviewedByTechnician) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: clientId.isEmpty
              ? null
              : () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => RateClientPage(
                        orderId: orderId,
                        clientId: clientId,
                        clientName: clientName,
                        clientPhotoUrl: clientPhotoUrl,
                        serviceName: service,
                      ),
                    ),
                  );
                },
          icon: const Icon(Icons.verified_user_outlined),
          label: const Text('Evaluar cliente'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: null,
        style: ElevatedButton.styleFrom(
          disabledBackgroundColor: Colors.purple.withOpacity(0.15),
          disabledForegroundColor: Colors.purple,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: const Text(
          'Trabajo completado',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget buildOrderCard(DocumentSnapshot orderDoc, BuildContext context) {
    final data = orderDoc.data() as Map<String, dynamic>? ?? {};

    final service = (data['service'] ?? 'Servicio sin nombre').toString();
    final city = (data['city'] ?? 'Ciudad no indicada').toString();
    final description = (data['description'] ?? data['details'] ?? 'Sin descripción').toString();
    final clientAddress =
        (data['clientAddress'] ?? data['address'] ?? '').toString();
    final problemPhotoUrl = (data['problemPhotoUrl'] ?? '').toString();
    final clientName = (data['clientName'] ?? 'Cliente').toString();
    final clientPhotoUrl = (data['clientPhotoUrl'] ?? '').toString();
    final clientId = (data['clientId'] ?? '').toString();
    final clientReviewedByTechnician =
        data['clientReviewedByTechnician'] == true;
    final status = (data['status'] ?? 'accepted').toString();
    final paymentStatus = (data['paymentStatus'] ?? 'pending').toString();
    final technicianEarning = data['technicianEarningBs'] ??
        data['basePriceBs'] ??
        data['technicianEarning'] ??
        data['basePrice'];
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
                  backgroundColor: Colors.orange.withOpacity(0.12),
                  child: Icon(
                    getServiceIcon(service),
                    color: Colors.orange,
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
                    color: getStatusColor(status).withOpacity(0.12),
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
            Text(
              'Ciudad: $city',
              style: const TextStyle(fontSize: 15),
            ),
            if (clientAddress.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                'Direccion: $clientAddress',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            const SizedBox(height: 6),
            Text(
              'Descripción: $description',
              style: const TextStyle(fontSize: 15),
            ),
            const SizedBox(height: 6),
            if (technicianEarning != null)
              Text(
                'Tu ganancia estimada: ${formatTechnicianEarning(data)}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
            const SizedBox(height: 6),
            Text(
              paymentStatus == 'paid' || paymentStatus == 'released'
                  ? 'Pago aprobado y retenido'
                  : paymentStatus == 'review'
                      ? 'Pago enviado, pendiente por aprobacion'
                      : 'Pago pendiente',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: paymentStatus == 'paid' || paymentStatus == 'released'
                    ? Colors.green
                    : Colors.orange,
              ),
            ),
            const SizedBox(height: 12),
            if (clientId.isNotEmpty && status == 'on_the_way')
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => OrderChatPage(
                          orderId: orderDoc.id,
                          otherUserId: clientId,
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
            if (latitude != null && longitude != null) ...[
              const SizedBox(height: 8),
              Text(
                'Destino: ${latitude.toStringAsFixed(5)}, ${longitude.toStringAsFixed(5)}',
                style: const TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 12),
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
                  icon: const Icon(Icons.map_outlined),
                  label: const Text('Abrir ubicacion del cliente'),
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
              const SizedBox(height: 12),
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
            ],
            if (problemPhotoUrl.isNotEmpty) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => openExternalUrl(problemPhotoUrl),
                  icon: const Icon(Icons.image_outlined),
                  label: const Text('Ver foto del problema'),
                ),
              ),
            ],
            if (latitude == null || longitude == null) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Text(
                  'Esta solicitud no tiene ubicacion exacta guardada. Pidele al cliente contactar soporte para actualizarla.',
                  style: TextStyle(
                    color: Colors.orange,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            buildActionButtons(
              context,
              orderDoc.id,
              status,
              paymentStatus,
              clientId,
              clientName,
              clientPhotoUrl,
              clientReviewedByTechnician,
              service,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (user == null) {
      return const Scaffold(
        body: Center(
          child: Text('No hay técnico autenticado'),
        ),
      );
    }

    final jobsStream = FirebaseFirestore.instance
        .collection('orders')
        .where('technicianId', isEqualTo: user!.uid)
        .snapshots();

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text('Mis trabajos'),
        centerTitle: true,
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: jobsStream,
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
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          final docs = (snapshot.data?.docs ?? []).where((doc) {
            final data = doc.data() as Map<String, dynamic>? ?? {};
            final status = (data['status'] ?? '').toString();
            return status == 'accepted' ||
                status == 'on_the_way' ||
                status == 'arrived' ||
                status == 'working' ||
                status == 'completed';
          }).toList();

          if (docs.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text(
                  'Todavía no tienes trabajos aceptados',
                  style: TextStyle(fontSize: 16),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              return buildOrderCard(docs[index], context);
            },
          );
        },
      ),
    );
  }
}
