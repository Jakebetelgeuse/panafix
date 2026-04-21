import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/owner_alert_service.dart';

class OrderTrackingPage extends StatelessWidget {
  final String orderId;
  static const String _supportPhone = '+13854637334';

  const OrderTrackingPage({
    super.key,
    required this.orderId,
  });

  String getStatusLabel(String status) {
    switch (status) {
      case 'pending':
        return 'Pendiente';
      case 'accepted':
        return 'Aceptada';
      case 'on_the_way':
        return 'En camino';
      case 'arrived':
        return 'El tecnico llego';
      case 'working':
        return 'Trabajando';
      case 'completed':
        return 'Completada';
      case 'rejected':
        return 'Rechazada';
      case 'cancelled':
        return 'Cancelada';
      default:
        return status;
    }
  }

  Color getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.blueGrey;
      case 'accepted':
        return Colors.orange;
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
      case 'cancelled':
        return Colors.redAccent;
      default:
        return Colors.grey;
    }
  }

  double _progressValue(String status) {
    switch (status) {
      case 'accepted':
        return 0.25;
      case 'on_the_way':
        return 0.5;
      case 'arrived':
        return 0.72;
      case 'working':
        return 0.88;
      case 'completed':
        return 1;
      default:
        return 0.12;
    }
  }

  String _statusMessage(String status, bool hasTechnicianLocation) {
    switch (status) {
      case 'accepted':
        return 'Tu tecnico acepto el servicio y esta preparando la salida.';
      case 'on_the_way':
        return hasTechnicianLocation
            ? 'El tecnico ya va en camino y su aproximacion se actualiza en vivo.'
            : 'El tecnico ya va en camino.';
      case 'arrived':
        return 'El tecnico ya llego al punto de servicio.';
      case 'working':
        return 'El servicio esta en progreso.';
      case 'completed':
        return 'El servicio fue completado.';
      default:
        return 'Sigue el estado de tu servicio desde aqui.';
    }
  }

  Widget _avatar(String? photoUrl, String name) {
    if (photoUrl != null && photoUrl.isNotEmpty) {
      return CircleAvatar(
        radius: 18,
        backgroundImage: NetworkImage(photoUrl),
      );
    }

    return CircleAvatar(
      radius: 18,
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

  Future<void> _createEmergencyReport({
    required String orderId,
    required String clientId,
    required String technicianId,
    required String technicianName,
    required String service,
    required String status,
  }) async {
    await FirebaseFirestore.instance.collection('emergency_reports').add({
      'orderId': orderId,
      'reportedBy': clientId,
      'reportedByRole': 'client',
      'technicianId': technicianId,
      'technicianName': technicianName,
      'service': service,
      'status': status,
      'priority': 'urgent',
      'resolved': false,
      'createdAt': FieldValue.serverTimestamp(),
    });

    await OwnerAlertService.createAlert(
      title: 'Emergencia desde tracking',
      message:
          'Se reporto una emergencia durante el seguimiento del servicio "$service".',
      type: 'emergency',
      orderId: orderId,
      priority: 'high',
    );
  }

  Future<void> _callSupport() async {
    await launchUrl(
      Uri.parse('tel:$_supportPhone'),
      mode: LaunchMode.externalApplication,
    );
  }

  Future<void> _openWhatsApp() async {
    await launchUrl(
      Uri.parse('https://wa.me/13854637334'),
      mode: LaunchMode.externalApplication,
    );
  }

  Future<void> _showEmergencySheet(
    BuildContext context, {
    required String clientId,
    required String technicianId,
    required String technicianName,
    required String service,
    required String status,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Boton de emergencia',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Usa esta seccion si hay un problema serio durante el servicio o si necesitas ayuda inmediata de Panafix.',
                  style: TextStyle(
                    color: Color(0xFF6D5E4F),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      Navigator.pop(sheetContext);
                      await _callSupport();
                    },
                    icon: const Icon(Icons.call),
                    label: const Text('Llamar a soporte'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFB91C1C),
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      Navigator.pop(sheetContext);
                      await _openWhatsApp();
                    },
                    icon: const Icon(Icons.chat_outlined),
                    label: const Text('Escribir por WhatsApp'),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      Navigator.pop(sheetContext);
                      await _createEmergencyReport(
                        orderId: orderId,
                        clientId: clientId,
                        technicianId: technicianId,
                        technicianName: technicianName,
                        service: service,
                        status: status,
                      );
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Reporte urgente enviado.'),
                        ),
                      );
                    },
                    icon: const Icon(Icons.warning_amber_rounded),
                    label: const Text('Reportar problema urgente'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Aproximacion en mapa'),
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('orders')
            .doc(orderId)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          final data = snapshot.data!.data();

          if (data == null) {
            return const Center(
              child: Text('No se encontro la orden'),
            );
          }

          final clientLat = (data['latitude'] as num?)?.toDouble();
          final clientLng = (data['longitude'] as num?)?.toDouble();
          final technicianLat =
              (data['technicianLatitude'] as num?)?.toDouble();
          final technicianLng =
              (data['technicianLongitude'] as num?)?.toDouble();
          final status = (data['status'] ?? '').toString();
          final technicianName = (data['technicianName'] ?? 'Tecnico').toString();
          final technicianPhotoUrl =
              (data['technicianPhotoUrl'] ?? '').toString();
          final clientName = (data['clientName'] ?? 'Cliente').toString();
          final serviceName =
              (data['service'] ?? data['serviceName'] ?? 'Servicio').toString();
          final clientId = (data['clientId'] ?? '').toString();
          final technicianId = (data['technicianId'] ?? '').toString();

          if (clientLat == null || clientLng == null) {
            return const Center(
              child: Text('La orden no tiene ubicacion del cliente'),
            );
          }

          final clientPosition = LatLng(clientLat, clientLng);

          final Set<Marker> markers = {
            Marker(
              markerId: const MarkerId('client'),
              position: clientPosition,
              infoWindow: InfoWindow(title: clientName),
            ),
          };

          final Set<Polyline> polylines = {};

          LatLng initialTarget = clientPosition;

          if (technicianLat != null && technicianLng != null) {
            final technicianPosition = LatLng(technicianLat, technicianLng);

            markers.add(
              Marker(
                markerId: const MarkerId('technician'),
                position: technicianPosition,
                infoWindow: InfoWindow(title: technicianName),
              ),
            );

            polylines.add(
              Polyline(
                polylineId: const PolylineId('route_line'),
                points: [technicianPosition, clientPosition],
                width: 5,
                color: Colors.blue,
              ),
            );

            initialTarget = technicianPosition;
          }

          return Stack(
            children: [
              Positioned.fill(
                child: GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: initialTarget,
                    zoom: 14,
                  ),
                  markers: markers,
                  polylines: polylines,
                  myLocationEnabled: false,
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: false,
                ),
              ),
              Positioned(
                top: 12,
                left: 12,
                right: 12,
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(26),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.10),
                        blurRadius: 24,
                        offset: const Offset(0, 14),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              serviceName,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: getStatusColor(status).withOpacity(0.10),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              getStatusLabel(status),
                              style: TextStyle(
                                color: getStatusColor(status),
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(
                          value: _progressValue(status),
                          minHeight: 8,
                          backgroundColor: const Color(0xFFE5E7EB),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            getStatusColor(status),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _statusMessage(
                          status,
                          technicianLat != null && technicianLng != null,
                        ),
                        style: const TextStyle(
                          color: Color(0xFF5B6472),
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: 12,
                right: 12,
                bottom: 12,
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.14),
                        blurRadius: 28,
                        offset: const Offset(0, 14),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _avatar(technicianPhotoUrl, technicianName),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  technicianName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  clientName,
                                  style: const TextStyle(
                                    color: Color(0xFF6D5E4F),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF6F7FB),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              technicianLat != null && technicianLng != null
                                  ? 'En vivo'
                                  : 'Sin GPS',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF1D4ED8),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _showEmergencySheet(
                                context,
                                clientId: clientId,
                                technicianId: technicianId,
                                technicianName: technicianName,
                                service: serviceName,
                                status: status,
                              ),
                              icon: const Icon(Icons.sos_outlined),
                              label: const Text('Emergencia'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFFB91C1C),
                                side: const BorderSide(
                                  color: Color(0xFFEF4444),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _callSupport,
                              icon: const Icon(Icons.support_agent),
                              label: const Text('Soporte'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF111827),
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
