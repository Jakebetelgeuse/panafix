import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'order_chat_page.dart';
import 'order_tracking_page.dart';
import 'payment_page.dart';
import 'rate_technician_page.dart';
import 'services_page.dart';
import '../services/bcv_rate_service.dart';
import '../services/owner_alert_service.dart';

class MyRequestsPage extends StatelessWidget {
  const MyRequestsPage({super.key});

  static const String _supportPhone = '+13854637334';

  Widget _avatar(String? photoUrl, String name) {
    if (photoUrl != null && photoUrl.isNotEmpty) {
      return CircleAvatar(
        radius: 22,
        backgroundImage: NetworkImage(photoUrl),
      );
    }

    return CircleAvatar(
      radius: 22,
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

  Future<void> _createNotification({
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

  Future<void> _createEmergencyReport({
    required String orderId,
    required String technicianId,
    required String technicianName,
    required String service,
    required String status,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await FirebaseFirestore.instance.collection('emergency_reports').add({
      'orderId': orderId,
      'reportedBy': user.uid,
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
      title: 'Emergencia reportada',
      message:
          'Un cliente reporto una situacion urgente en el servicio "$service".',
      type: 'emergency',
      orderId: orderId,
      priority: 'high',
    );
  }

  Future<void> _openWhatsApp() async {
    final uri = Uri.parse('https://wa.me/13854637334');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _callSupport() async {
    final uri = Uri.parse('tel:$_supportPhone');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _showEmergencySheet(
    BuildContext context, {
    required String orderId,
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
                  'Emergencia o problema urgente',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Si te sientes en riesgo o hay un problema grave durante el servicio, usa una de estas opciones.',
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
                        technicianId: technicianId,
                        technicianName: technicianName,
                        service: service,
                        status: status,
                      );
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Reporte urgente enviado a Panafix.',
                          ),
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

  Color _statusColor(String status) {
    switch (status) {
      case 'awaiting_payment':
        return Colors.amber;
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

  String _statusLabel(String status) {
    switch (status) {
      case 'awaiting_payment':
        return 'Esperando pago';
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

  IconData _statusIcon(String status) {
    switch (status) {
      case 'awaiting_payment':
        return Icons.payments_outlined;
      case 'pending':
        return Icons.hourglass_bottom;
      case 'accepted':
        return Icons.check_circle_outline;
      case 'on_the_way':
        return Icons.directions_car;
      case 'arrived':
        return Icons.location_on;
      case 'working':
        return Icons.handyman;
      case 'completed':
        return Icons.task_alt;
      case 'rejected':
        return Icons.cancel_outlined;
      case 'cancelled':
        return Icons.event_busy;
      default:
        return Icons.info_outline;
    }
  }

  String _detailsText(Map<String, dynamic> order) {
    final description = order['description']?.toString() ?? '';
    final details = order['details']?.toString() ?? '';

    if (description.trim().isNotEmpty) {
      return description;
    }

    if (details.trim().isNotEmpty) {
      return details;
    }

    return 'Sin descripcion adicional.';
  }

  Color _paymentColor(String paymentStatus) {
    switch (paymentStatus) {
      case 'pending':
        return Colors.grey;
      case 'review':
      case 'payment_review':
        return Colors.purple;
      case 'paid':
        return Colors.green;
      case 'released':
        return Colors.teal;
      case 'refund_pending':
      case 'refund_requested':
        return Colors.deepOrange;
      case 'partial_payment':
        return Colors.amber.shade800;
      default:
        return Colors.grey;
    }
  }

  String _paymentLabel(String paymentStatus) {
    switch (paymentStatus) {
      case 'pending':
        return 'Pago pendiente';
      case 'review':
      case 'payment_review':
        return 'Pago en revision';
      case 'paid':
        return 'Pago aprobado';
      case 'released':
        return 'Pago liberado';
      case 'refund_pending':
        return 'Pago retenido para devolucion';
      case 'refund_requested':
        return 'Devolucion solicitada';
      case 'partial_payment':
        return 'Pago incompleto';
      default:
        return paymentStatus;
    }
  }

  int _statusStep(String status) {
    switch (status) {
      case 'awaiting_payment':
        return 0;
      case 'pending':
        return 1;
      case 'accepted':
        return 2;
      case 'on_the_way':
        return 3;
      case 'arrived':
      case 'working':
        return 4;
      case 'completed':
        return 5;
      default:
        return -1;
    }
  }

  String _statusHeadline(String status) {
    switch (status) {
      case 'awaiting_payment':
        return 'Falta completar el pago para activar el servicio.';
      case 'pending':
        return 'Tu solicitud esta siendo revisada.';
      case 'accepted':
        return 'Tu tecnico ya acepto el servicio.';
      case 'on_the_way':
        return 'Tu tecnico va en camino.';
      case 'arrived':
        return 'El tecnico ya llego al punto de servicio.';
      case 'working':
        return 'El trabajo esta en progreso.';
      case 'completed':
        return 'El servicio fue completado.';
      case 'cancelled':
        return 'La solicitud fue cancelada.';
      case 'rejected':
        return 'El tecnico no pudo tomar esta solicitud. Puedes pedir otro tecnico de inmediato.';
      default:
        return 'Sigue el estado de tu solicitud.';
    }
  }

  DateTime _addBusinessDays(DateTime start, int days) {
    var result = start;
    var added = 0;

    while (added < days) {
      result = result.add(const Duration(days: 1));
      if (result.weekday <= DateTime.friday) {
        added++;
      }
    }

    return result;
  }

  Future<void> _showRefundRequestSheet({
    required BuildContext context,
    required String orderId,
    required Map<String, dynamic> order,
    required String service,
    required double amountUsd,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final nameController = TextEditingController(
      text: order['refundPaymentMobileName']?.toString() ??
          order['clientName']?.toString() ??
          '',
    );
    final phoneController = TextEditingController(
      text: order['refundPaymentMobilePhone']?.toString() ?? '',
    );
    final bankController = TextEditingController(
      text: order['refundPaymentMobileBank']?.toString() ?? '',
    );
    final identityController = TextEditingController(
      text: order['refundPaymentMobileIdentity']?.toString() ??
          order['identityDocument']?.toString() ??
          '',
    );

    try {
      final bcvRate = await BcvRateService.getRate(forceRefresh: true);
      if (!context.mounted) return;

      final amountVes = bcvRate.usdToVes(amountUsd);
      final estimatedPaymentDate = _addBusinessDays(DateTime.now(), 3);

      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        builder: (sheetContext) {
          var isSaving = false;

          return StatefulBuilder(
            builder: (context, setSheetState) {
              Future<void> submit() async {
                final name = nameController.text.trim();
                final phone = phoneController.text.trim();
                final bank = bankController.text.trim();
                final identity = identityController.text.trim();

                if (name.isEmpty ||
                    phone.isEmpty ||
                    bank.isEmpty ||
                    identity.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Completa los datos del pago movil.'),
                    ),
                  );
                  return;
                }

                if (!bcvRate.isAvailable) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'No hay tasa BCV disponible. Intenta mas tarde o contacta soporte.',
                      ),
                    ),
                  );
                  return;
                }

                setSheetState(() {
                  isSaving = true;
                });

                final refundData = {
                  'orderId': orderId,
                  'clientId': user.uid,
                  'clientName': order['clientName']?.toString() ?? name,
                  'service': service,
                  'status': 'requested',
                  'amountUsd': amountUsd,
                  'bcvRate': bcvRate.rate,
                  'amountVes': amountVes,
                  'bcvSource': bcvRate.source,
                  'bcvRateDate': bcvRate.rateDate,
                  'paymentMobileName': name,
                  'paymentMobilePhone': phone,
                  'paymentMobileBank': bank,
                  'paymentMobileIdentity': identity,
                  'expectedBusinessDays': 3,
                  'estimatedPaymentAt': Timestamp.fromDate(estimatedPaymentDate),
                  'createdAt': FieldValue.serverTimestamp(),
                  'updatedAt': FieldValue.serverTimestamp(),
                };

                final batch = FirebaseFirestore.instance.batch();
                final orderRef =
                    FirebaseFirestore.instance.collection('orders').doc(orderId);
                final refundRef = FirebaseFirestore.instance
                    .collection('client_refund_requests')
                    .doc(orderId);

                batch.set(refundRef, refundData, SetOptions(merge: true));
                batch.set(
                  orderRef,
                  {
                    'paymentStatus': 'refund_requested',
                    'refundStatus': 'requested',
                    'refundRequestedAt': FieldValue.serverTimestamp(),
                    'refundAmountUsd': amountUsd,
                    'refundBcvRate': bcvRate.rate,
                    'refundAmountVes': amountVes,
                    'refundBcvSource': bcvRate.source,
                    'refundBcvRateDate': bcvRate.rateDate,
                    'refundEstimatedPaymentAt':
                        Timestamp.fromDate(estimatedPaymentDate),
                    'refundPaymentMobileName': name,
                    'refundPaymentMobilePhone': phone,
                    'refundPaymentMobileBank': bank,
                    'refundPaymentMobileIdentity': identity,
                    'updatedAt': FieldValue.serverTimestamp(),
                  },
                  SetOptions(merge: true),
                );
                batch.set(
                  FirebaseFirestore.instance.collection('owner_alerts').doc(),
                  {
                    'title': 'Solicitud de devolucion',
                    'message':
                        '$name solicito devolucion de $service por Bs ${amountVes.toStringAsFixed(2)}.',
                    'type': 'client_refund',
                    'orderId': orderId,
                    'clientId': user.uid,
                    'amountUsd': amountUsd,
                    'amountVes': amountVes,
                    'bcvRate': bcvRate.rate,
                    'paymentMobileName': name,
                    'paymentMobilePhone': phone,
                    'paymentMobileBank': bank,
                    'paymentMobileIdentity': identity,
                    'status': 'unread',
                    'isRead': false,
                    'createdAt': FieldValue.serverTimestamp(),
                  },
                );

                await batch.commit();

                if (!context.mounted) return;
                Navigator.pop(sheetContext);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Solicitud enviada. Panafix verificara y pagara en hasta 3 dias habiles.',
                    ),
                  ),
                );
              }

              return Padding(
                padding: EdgeInsets.only(
                  left: 18,
                  right: 18,
                  top: 18,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 18,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Solicitar devolucion',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        bcvRate.isAvailable
                            ? 'Monto disponible al BCV: \$${amountUsd.toStringAsFixed(2)} x ${bcvRate.rate.toStringAsFixed(2)} = Bs ${amountVes.toStringAsFixed(2)}'
                            : 'No hay tasa BCV disponible en este momento.',
                        style: const TextStyle(
                          color: Color(0xFF6D5E4F),
                          height: 1.35,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Pago estimado: hasta 3 dias habiles luego de verificar tus datos.',
                        style: TextStyle(
                          color: Colors.orange.shade800,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: nameController,
                        decoration: const InputDecoration(
                          labelText: 'Nombre del pago movil',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: identityController,
                        decoration: const InputDecoration(
                          labelText: 'Cedula',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'Telefono pago movil',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: bankController,
                        decoration: const InputDecoration(
                          labelText: 'Banco',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: isSaving ? null : submit,
                          icon: const Icon(Icons.account_balance_wallet_outlined),
                          label: Text(
                            isSaving
                                ? 'Enviando...'
                                : 'Solicitar devolucion por pago movil',
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.deepOrange,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      );
    } finally {
      nameController.dispose();
      phoneController.dispose();
      bankController.dispose();
      identityController.dispose();
    }
  }

  Widget _timeline(String status) {
    final currentStep = _statusStep(status);
    const labels = [
      'Pago',
      'Revision',
      'Aceptada',
      'En camino',
      'Servicio',
      'Listo',
    ];

    if (status == 'cancelled' || status == 'rejected') {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _statusColor(status).withOpacity(0.08),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(
          _statusLabel(status),
          textAlign: TextAlign.center,
          style: TextStyle(
            color: _statusColor(status),
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }

    return Row(
      children: List.generate(labels.length, (index) {
        final done = currentStep >= index;
        return Expanded(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: done
                            ? const Color(0xFFFF7A00)
                            : const Color(0xFFE7E1D8),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        done ? Icons.check : Icons.circle,
                        size: done ? 15 : 8,
                        color: done ? Colors.white : const Color(0xFFB8AEA3),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      labels[index],
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: done ? FontWeight.w700 : FontWeight.w500,
                        color: done
                            ? const Color(0xFF8A4700)
                            : const Color(0xFF8C8176),
                      ),
                    ),
                  ],
                ),
              ),
              if (index < labels.length - 1)
                Expanded(
                  child: Container(
                    height: 3,
                    margin: const EdgeInsets.only(bottom: 22),
                    color: currentStep > index
                        ? const Color(0xFFFFB15C)
                        : const Color(0xFFE7E1D8),
                  ),
                ),
            ],
          ),
        );
      }),
    );
  }

  Future<void> _cancelOrder(
    BuildContext context,
    String orderId,
    String technicianId,
    String service,
  ) async {
    try {
      await FirebaseFirestore.instance.collection('orders').doc(orderId).update({
        'status': 'cancelled',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (technicianId.isNotEmpty) {
        await _createNotification(
          userId: technicianId,
          title: 'Servicio cancelado',
          message: 'El cliente cancelo el servicio "$service".',
          type: 'request',
          orderId: orderId,
        );
      }

      await OwnerAlertService.createAlert(
        title: 'Solicitud cancelada',
        message: 'Un cliente cancelo el servicio "$service".',
        type: 'request',
        orderId: orderId,
      );

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Solicitud cancelada correctamente.')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al cancelar la solicitud: $e')),
      );
    }
  }

  bool _canCreateClaim(Map<String, dynamic> order) {
    final status = (order['status'] ?? '').toString();
    if (status != 'completed') return false;

    final claimStatus = (order['claimStatus'] ?? '').toString();
    if (claimStatus == 'open') return false;

    final completedAt =
        (order['completedAt'] ?? order['updatedAt'] ?? order['createdAt'])
            as Timestamp?;
    if (completedAt == null) return true;

    final limit = completedAt.toDate().toLocal().add(const Duration(days: 7));
    return DateTime.now().isBefore(limit);
  }

  Future<void> _createServiceClaim({
    required BuildContext context,
    required String orderId,
    required String technicianId,
    required String technicianName,
    required String service,
    required String problem,
    String? evidenceUrl,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await FirebaseFirestore.instance.collection('service_claims').add({
      'orderId': orderId,
      'clientId': user.uid,
      'technicianId': technicianId,
      'technicianName': technicianName,
      'service': service,
      'problem': problem,
      'evidenceUrl': evidenceUrl ?? '',
      'status': 'open',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await FirebaseFirestore.instance.collection('orders').doc(orderId).set({
      'claimStatus': 'open',
      'claimedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await OwnerAlertService.createAlert(
      title: 'Reclamo de servicio',
      message:
          'Un cliente reporto un problema posterior en el servicio "$service".',
      type: 'request',
      orderId: orderId,
      priority: 'high',
    );

    if (technicianId.isNotEmpty) {
      await _createNotification(
        userId: technicianId,
        title: 'Reclamo del cliente',
        message:
            'El cliente reporto un problema con el servicio "$service".',
        type: 'request',
        orderId: orderId,
      );
    }

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Reclamo enviado. Panafix revisara el caso.'),
      ),
    );
  }

  Future<String?> _uploadClaimEvidence(String orderId) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );

    if (result == null || result.files.isEmpty) {
      return null;
    }

    final file = result.files.single;
    final bytes = file.bytes;
    if (bytes == null) {
      throw Exception('No se pudo leer la imagen seleccionada.');
    }

    if (bytes.length > 8 * 1024 * 1024) {
      throw Exception('La imagen no debe superar los 8 MB.');
    }

    final extension = (file.extension ?? 'jpg').toLowerCase();
    final ref = FirebaseStorage.instance
        .ref()
        .child('service_claim_evidence/$orderId/evidence.$extension');

    await ref.putData(
      bytes,
      SettableMetadata(contentType: 'image/$extension'),
    );

    return ref.getDownloadURL();
  }

  Future<void> _showClaimSheet(
    BuildContext context, {
    required String orderId,
    required String technicianId,
    required String technicianName,
    required String service,
  }) async {
    final controller = TextEditingController();
    String? evidenceUrl;
    String? evidenceName;
    bool isUploading = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                20,
                20,
                MediaQuery.of(sheetContext).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Reportar problema con el servicio',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Usa este formulario si el tecnico arreglo algo y volvio a fallar o si el resultado no fue el esperado.',
                    style: TextStyle(
                      color: Color(0xFF6D5E4F),
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: controller,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Describe el problema',
                      hintText:
                          'Ej: el arreglo funciono por unas horas y luego volvio a fallar.',
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: isUploading
                        ? null
                        : () async {
                            try {
                              setModalState(() {
                                isUploading = true;
                              });
                              final uploadedUrl =
                                  await _uploadClaimEvidence(orderId);
                              if (uploadedUrl != null) {
                                setModalState(() {
                                  evidenceUrl = uploadedUrl;
                                  evidenceName = 'Foto adjunta';
                                });
                              }
                            } catch (e) {
                              if (!sheetContext.mounted) return;
                              ScaffoldMessenger.of(sheetContext).showSnackBar(
                                SnackBar(content: Text('$e')),
                              );
                            } finally {
                              setModalState(() {
                                isUploading = false;
                              });
                            }
                          },
                    icon: isUploading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.add_a_photo_outlined),
                    label: Text(
                      evidenceUrl == null
                          ? 'Adjuntar foto como evidencia'
                          : evidenceName ?? 'Foto adjunta',
                    ),
                  ),
                  if (evidenceUrl != null) ...[
                    const SizedBox(height: 8),
                    const Text(
                      'La imagen se enviara junto con el reclamo.',
                      style: TextStyle(
                        color: Color(0xFF6D5E4F),
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: isUploading
                          ? null
                          : () async {
                              final text = controller.text.trim();
                              if (text.isEmpty) return;

                              Navigator.pop(sheetContext);
                              await _createServiceClaim(
                                context: context,
                                orderId: orderId,
                                technicianId: technicianId,
                                technicianName: technicianName,
                                service: service,
                                problem: text,
                                evidenceUrl: evidenceUrl,
                              );
                            },
                      icon: const Icon(Icons.report_problem_outlined),
                      label: const Text('Enviar reclamo'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFB91C1C),
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(
          child: Text('Debes iniciar sesion.'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis solicitudes'),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('orders')
            .where('clientId', isEqualTo: user.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Ocurrio un error: ${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final orders = snapshot.data?.docs ?? [];

          orders.sort((a, b) {
            final aTime = a.data()['createdAt'] as Timestamp?;
            final bTime = b.data()['createdAt'] as Timestamp?;

            if (aTime == null && bTime == null) return 0;
            if (aTime == null) return 1;
            if (bTime == null) return -1;
            return bTime.compareTo(aTime);
          });

          if (orders.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Todavia no has hecho solicitudes.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18),
                ),
              ),
            );
          }

          final activeOrders = orders.where((doc) {
            final status = (doc.data()['status'] ?? '').toString();
            return status != 'completed' &&
                status != 'cancelled' &&
                status != 'rejected';
          }).length;

          final completedOrders = orders.where((doc) {
            final status = (doc.data()['status'] ?? '').toString();
            return status == 'completed';
          }).length;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF111827),
                      Color(0xFF1D4ED8),
                      Color(0xFF60A5FA),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(32),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Tu actividad',
                      style: TextStyle(
                        color: Color(0xFFDBEAFE),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Sigue tus servicios, pagos y avances en un solo lugar.',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _SummaryCard(
                            title: 'Activas',
                            value: activeOrders.toString(),
                            color: const Color(0x33FFFFFF),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _SummaryCard(
                            title: 'Completadas',
                            value: completedOrders.toString(),
                            color: const Color(0x1AFFFFFF),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              ...List.generate(orders.length, (index) {
              final doc = orders[index];
              final order = doc.data();

              final technicianName =
                  order['technicianName']?.toString() ?? 'Tecnico';
              final technicianId = order['technicianId']?.toString() ?? '';
              final technicianPhotoUrl =
                  order['technicianPhotoUrl']?.toString() ?? '';
              final category = order['category']?.toString() ?? '';
              final service =
                  (order['service'] ?? order['serviceName'] ?? 'Servicio')
                      .toString();
              final city = order['city']?.toString() ?? '';
              final status = order['status']?.toString() ?? 'pending';
              final reviewed = order['reviewed'] == true;
              final claimStatus = order['claimStatus']?.toString() ?? '';
              final detailsText = _detailsText(order);

              final price =
                  ((order['finalPrice'] ?? order['priceFrom'] ?? 0) as num)
                      .toDouble();

              final paymentStatus =
                  order['paymentStatus']?.toString() ?? 'pending';
              final releaseStatus =
                  order['releaseStatus']?.toString() ?? 'pending';

              final waitingOwnerRelease = status == 'completed' &&
                  paymentStatus == 'paid' &&
                  releaseStatus != 'released';

              final alreadyReleased = releaseStatus == 'released' ||
                  paymentStatus == 'released';

              return Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 22,
                      offset: const Offset(0, 16),
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
                            service,
                            style: const TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: _statusColor(status).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _statusIcon(status),
                                size: 16,
                                color: _statusColor(status),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _statusLabel(status),
                                style: TextStyle(
                                  color: _statusColor(status),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _timeline(status),
                    const SizedBox(height: 14),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: _statusColor(status).withOpacity(0.08),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Text(
                        _statusHeadline(status),
                        style: TextStyle(
                          color: _statusColor(status),
                          fontWeight: FontWeight.w700,
                          height: 1.35,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        _avatar(technicianPhotoUrl, technicianName),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Tecnico: $technicianName',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    if (category.isNotEmpty) Text('Categoria: $category'),
                    if (category.isNotEmpty) const SizedBox(height: 6),
                    if (city.isNotEmpty) Text('Ciudad: $city'),
                    if (city.isNotEmpty) const SizedBox(height: 6),
                    if (price > 0)
                      Text(
                        'Precio: \$${price.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: Colors.green,
                        ),
                      ),
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF7F4EF),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        detailsText,
                        style: const TextStyle(
                          color: Color(0xFF3B3129),
                          height: 1.4,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: _paymentColor(paymentStatus).withOpacity(0.10),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.payments_outlined,
                            size: 18,
                            color: _paymentColor(paymentStatus),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _paymentLabel(paymentStatus),
                              style: TextStyle(
                                color: _paymentColor(paymentStatus),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    if (status == 'on_the_way' ||
                        status == 'arrived' ||
                        status == 'working') ...[
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () => _showEmergencySheet(
                            context,
                            orderId: doc.id,
                            technicianId: technicianId,
                            technicianName: technicianName,
                            service: service,
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
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => OrderTrackingPage(
                                  orderId: doc.id,
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.location_on),
                          label: const Text('Ver aproximacion'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                    if (technicianId.isNotEmpty && status == 'on_the_way') ...[
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => OrderChatPage(
                                  orderId: doc.id,
                                  otherUserId: technicianId,
                                  otherUserName: technicianName,
                                  serviceName: service,
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.chat_bubble_outline),
                          label: const Text('Abrir chat'),
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                    if (status == 'awaiting_payment' &&
                        paymentStatus == 'pending') ...[
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => PaymentPage(
                                  orderId: doc.id,
                                  orderData: order,
                                  amount: price,
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.payments_outlined),
                          label: const Text('Completar pago'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                    if (status == 'rejected') ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Text(
                          'Ese tecnico no pudo tomar el trabajo. No pasa nada: puedes buscar otro ahora mismo.',
                          style: TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.w800,
                            height: 1.35,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: category.isEmpty
                              ? null
                              : () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => ServicesPage(
                                        category: category,
                                      ),
                                    ),
                                  );
                                },
                          icon: const Icon(Icons.search_rounded),
                          label: const Text('Solicitar otro tecnico'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFF7A00),
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                    if (paymentStatus == 'partial_payment') ...[
                      Builder(
                        builder: (context) {
                          final missingAmountBs =
                              ((order['missingAmountBs'] ?? 0) as num?)
                                      ?.toDouble() ??
                                  0;
                          final missingAmountUsd =
                              ((order['missingAmountUsd'] ?? 0) as num?)
                                      ?.toDouble() ??
                                  0;
                          final creditedAmountBs =
                              ((order['creditedAmountBs'] ?? 0) as num?)
                                      ?.toDouble() ??
                                  0;

                          return Column(
                            children: [
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: Colors.amber.withOpacity(0.14),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Text(
                          'Tu abono quedo guardado como saldo Panafix anclado al BCV. Falta completar Bs ${missingAmountBs.toStringAsFixed(2)}.',
                                  style: TextStyle(
                                    color: Colors.amber.shade900,
                                    fontWeight: FontWeight.w800,
                                    height: 1.35,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: missingAmountUsd <= 0
                                      ? null
                                      : () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => PaymentPage(
                                                orderId: doc.id,
                                                orderData: order,
                                                amount: missingAmountUsd,
                                              ),
                                            ),
                                          );
                                        },
                                  icon: const Icon(Icons.add_card_outlined),
                                  label: const Text('Completar diferencia'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.amber.shade800,
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 10),
                    ],
                    if (status == 'awaiting_payment' ||
                        status == 'pending' ||
                        status == 'accepted') ...[
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () => _cancelOrder(
                            context,
                            doc.id,
                            technicianId,
                            service,
                          ),
                          icon: const Icon(Icons.cancel_outlined),
                          label: const Text('Cancelar solicitud'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                    if (paymentStatus == 'review' ||
                        paymentStatus == 'payment_review')
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.purple.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Text(
                          'Tu pago esta siendo revisado.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.purple,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    if (paymentStatus == 'refund_pending') ...[
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.deepOrange.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Text(
                          'Tu pago quedo como saldo Panafix anclado al BCV. Puedes usarlo automaticamente en tu proximo servicio o pedir devolucion por pago movil.',
                          style: TextStyle(
                            color: Colors.deepOrange,
                            fontWeight: FontWeight.w800,
                            height: 1.35,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () => _showRefundRequestSheet(
                            context: context,
                            orderId: doc.id,
                            order: order,
                            service: service,
                            amountUsd: price,
                          ),
                          icon: const Icon(Icons.account_balance_wallet_outlined),
                          label: const Text('Solicitar devolucion por pago movil'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.deepOrange,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                    ],
                    if (paymentStatus == 'refund_requested') ...[
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.deepOrange.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Text(
                          'Devolucion solicitada. Panafix verificara tus datos y hara el pago movil en hasta 3 dias habiles.',
                          style: TextStyle(
                            color: Colors.deepOrange,
                            fontWeight: FontWeight.w800,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                    if (waitingOwnerRelease) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.10),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Text(
                          'Trabajo completado. Panafix revisara y liberara el pago al tecnico.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.orange,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                    if (alreadyReleased)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.teal.withOpacity(0.10),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Text(
                          'Pago liberado correctamente.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.teal,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    if (claimStatus == 'open') ...[
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Text(
                          'Tienes un reclamo abierto para este servicio. Panafix esta revisando el caso.',
                          style: TextStyle(
                            color: Color(0xFFB91C1C),
                            fontWeight: FontWeight.w700,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                    if (status == 'completed' && !reviewed)
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: technicianId.isEmpty
                              ? null
                              : () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => RateTechnicianPage(
                                        orderId: doc.id,
                                        technicianId: technicianId,
                                        technicianName: technicianName,
                                        technicianPhotoUrl: technicianPhotoUrl,
                                      ),
                                    ),
                                  );
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Calificar tecnico'),
                        ),
                      ),
                    if (_canCreateClaim(order)) ...[
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () => _showClaimSheet(
                            context,
                            orderId: doc.id,
                            technicianId: technicianId,
                            technicianName: technicianName,
                            service: service,
                          ),
                          icon: const Icon(Icons.report_problem_outlined),
                          label: const Text('Reportar problema con el servicio'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFB91C1C),
                            side: const BorderSide(
                              color: Color(0xFFEF4444),
                            ),
                          ),
                        ),
                      ),
                    ],
                    if (status == 'completed' && reviewed)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.10),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Text(
                          'Ya calificaste este servicio.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),
              );
              }),
            ],
          );
        },
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final Color color;

  const _SummaryCard({
    required this.title,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFFE5EDFF),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
