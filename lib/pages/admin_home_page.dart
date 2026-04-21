import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'auth_service.dart';

class AdminHomePage extends StatefulWidget {
  const AdminHomePage({super.key});

  @override
  State<AdminHomePage> createState() => _AdminHomePageState();
}

class _AdminHomePageState extends State<AdminHomePage> {
  String selectedAdminSection = 'orders';
  String selectedFilter = 'all';
  String selectedVerificationFilter = 'all';
  String searchTerm = '';

  Future<void> _markTechnicianPayoutAsPaid(
    BuildContext context, {
    required String technicianId,
    required String technicianName,
    required String payoutName,
    required String payoutPhone,
    required String payoutBank,
    required String payoutDocumentId,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> orders,
    required double totalAmount,
  }) async {
    if (orders.isEmpty) return;

    try {
      final batch = FirebaseFirestore.instance.batch();
      final payoutRef =
          FirebaseFirestore.instance.collection('technician_payouts').doc();

      for (final order in orders) {
        batch.update(order.reference, {
          'payoutStatus': 'paid_out',
          'payoutSentAt': FieldValue.serverTimestamp(),
          'payoutRecordId': payoutRef.id,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      batch.set(payoutRef, {
        'technicianId': technicianId,
        'technicianName': technicianName,
        'orderIds': orders.map((order) => order.id).toList(),
        'ordersCount': orders.length,
        'totalAmount': totalAmount,
        'status': 'paid_out',
        'payoutAccountName': payoutName,
        'payoutMobilePhone': payoutPhone,
        'payoutBank': payoutBank,
        'payoutDocumentId': payoutDocumentId,
        'createdAt': FieldValue.serverTimestamp(),
      });

      final notificationRef =
          FirebaseFirestore.instance.collection('notifications').doc();
      batch.set(notificationRef, {
        'userId': technicianId,
        'title': 'Pago procesado',
        'message':
            'Panafix marco tu pago por \$${totalAmount.toStringAsFixed(2)} como enviado.',
        'type': 'payment',
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
        'expiresAt': Timestamp.fromDate(
          DateTime.now().add(const Duration(days: 30)),
        ),
      });

      await batch.commit();

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Pago a $technicianName marcado como realizado.',
          ),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo registrar el pago: $e')),
      );
    }
  }

  Future<void> _updatePaymentStatus(
    BuildContext context, {
    required String orderId,
    required String clientId,
    required String technicianId,
    required String service,
    required String paymentStatus,
  }) async {
    final callable = FirebaseFunctions.instance.httpsCallable('reviewPayment');
    await callable.call({
      'orderId': orderId,
      'paymentStatus': paymentStatus,
      'clientId': clientId,
      'technicianId': technicianId,
      'service': service,
    });

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          paymentStatus == 'paid'
              ? 'Pago aprobado correctamente.'
              : 'Pago rechazado correctamente.',
        ),
      ),
    );
  }

  Future<void> _openProof(
    BuildContext context,
    String proofUrl,
  ) async {
    if (proofUrl.isEmpty) return;

    final opened = await launchUrl(
      Uri.parse(proofUrl),
      mode: LaunchMode.externalApplication,
    );

    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo abrir el comprobante.')),
      );
    }
  }

  Future<void> _signOut() async {
    await AuthService().signOut();
  }

  Color _paymentColor(String paymentStatus) {
    switch (paymentStatus) {
      case 'paid':
        return const Color(0xFF16A34A);
      case 'released':
        return const Color(0xFF0F766E);
      case 'review':
        return const Color(0xFFFF7A00);
      case 'pending':
        return const Color(0xFF6B7280);
      default:
        return const Color(0xFFDC2626);
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'accepted':
        return const Color(0xFF2563EB);
      case 'on_the_way':
        return const Color(0xFF7C3AED);
      case 'arrived':
        return const Color(0xFFDB2777);
      case 'working':
        return const Color(0xFF0F766E);
      case 'completed':
        return const Color(0xFF16A34A);
      case 'cancelled':
        return const Color(0xFFDC2626);
      case 'awaiting_payment':
        return const Color(0xFFFF7A00);
      default:
        return const Color(0xFF6B7280);
    }
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _applyFilter(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    var result = docs;

    if (selectedFilter != 'all') {
      result = result.where((doc) {
        final data = doc.data();
        final paymentStatus = (data['paymentStatus'] ?? 'pending').toString();
        return paymentStatus == selectedFilter;
      }).toList();
    }

    if (searchTerm.trim().isEmpty) return result;

    final query = searchTerm.toLowerCase().trim();
    return result.where((doc) {
      final data = doc.data();
      final service =
          (data['service'] ?? data['serviceName'] ?? '').toString().toLowerCase();
      final client = (data['clientName'] ?? '').toString().toLowerCase();
      final technician =
          (data['technicianName'] ?? '').toString().toLowerCase();
      return service.contains(query) ||
          client.contains(query) ||
          technician.contains(query);
    }).toList();
  }

  bool _hasActivePromotion(Map<String, dynamic> data) {
    final status = (data['subscriptionStatus'] ?? '').toString();
    final promotedUntil = data['promotedUntil'] as Timestamp?;

    return status == 'active' &&
        promotedUntil != null &&
        promotedUntil.toDate().isAfter(DateTime.now());
  }

  String _subscriptionCountdown(Timestamp? promotedUntil, String status) {
    if (status != 'active' || promotedUntil == null) {
      return 'Sin promocion activa';
    }

    final difference = promotedUntil.toDate().difference(DateTime.now());
    if (difference.isNegative) {
      return 'Vencida';
    }

    if (difference.inDays >= 1) {
      return '${difference.inDays + 1} dias restantes';
    }

    return 'Vence hoy';
  }

  Color _subscriptionColor(String plan, bool isActive) {
    if (!isActive) return const Color(0xFF6B7280);
    if (plan == 'premium') return const Color(0xFFFF7A00);
    if (plan == 'pro') return const Color(0xFF0F766E);
    return const Color(0xFF2563EB);
  }

  String _formatDate(Timestamp? value) {
    if (value == null) return 'Sin fecha';
    final date = value.toDate().toLocal();
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  String _nextPayoutLabel() {
    final now = DateTime.now();
    final daysUntilFriday = (DateTime.friday - now.weekday + 7) % 7;
    final payoutDate = now.add(
      Duration(days: daysUntilFriday == 0 ? 7 : daysUntilFriday),
    );

    return '${payoutDate.day.toString().padLeft(2, '0')}/'
        '${payoutDate.month.toString().padLeft(2, '0')}/'
        '${payoutDate.year}';
  }

  bool get _showDashboard => selectedAdminSection == 'dashboard';

  bool get _showTechnicians =>
      selectedAdminSection == 'dashboard' ||
      selectedAdminSection == 'technicians';

  bool get _showPayouts =>
      selectedAdminSection == 'dashboard' ||
      selectedAdminSection == 'payouts';

  bool get _showOrders =>
      selectedAdminSection == 'dashboard' ||
      selectedAdminSection == 'orders';

  @override
  Widget build(BuildContext context) {
    final ordersStream = FirebaseFirestore.instance
        .collection('orders')
        .orderBy('createdAt', descending: true)
        .snapshots();
    final techniciansStream = FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'technician')
        .snapshots();
    final payoutsStream = FirebaseFirestore.instance
        .collection('orders')
        .where('paymentStatus', isEqualTo: 'released')
        .snapshots();
    final emergencyReportsStream = FirebaseFirestore.instance
        .collection('emergency_reports')
        .snapshots();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Panel admin'),
        actions: [
          IconButton(
            tooltip: 'Cerrar sesion',
            onPressed: _signOut,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: ordersStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Error cargando ordenes: ${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final docs = snapshot.data?.docs ?? [];
          final filteredDocs = _applyFilter(docs);

          final reviewCount = docs.where((doc) {
            final paymentStatus = (doc.data()['paymentStatus'] ?? '').toString();
            return paymentStatus == 'review' || paymentStatus == 'pending';
          }).length;

          final approvedCount = docs.where((doc) {
            final paymentStatus = (doc.data()['paymentStatus'] ?? '').toString();
            return paymentStatus == 'paid' || paymentStatus == 'released';
          }).length;

          final cancelledCount = docs.where((doc) {
            final status = (doc.data()['status'] ?? '').toString();
            return status == 'cancelled';
          }).length;

          return SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFF111827),
                        Color(0xFF1F2937),
                        Color(0xFFFF8A1F),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(34),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Control operativo',
                        style: TextStyle(
                          color: Color(0xFFFFDDB7),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Aprueba pagos, vigila incidencias y mantén el flujo de Panafix bajo control.',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 27,
                          fontWeight: FontWeight.w800,
                          height: 1.15,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          _MetricCard(
                            label: 'Solicitudes',
                            value: docs.length.toString(),
                          ),
                          _MetricCard(
                            label: 'Pagos por revisar',
                            value: reviewCount.toString(),
                          ),
                          _MetricCard(
                            label: 'Pagos listos',
                            value: approvedCount.toString(),
                          ),
                          _MetricCard(
                            label: 'Canceladas',
                            value: cancelledCount.toString(),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _FilterChipButton(
                      label: 'Pagos',
                      selected: selectedAdminSection == 'orders',
                      onTap: () =>
                          setState(() => selectedAdminSection = 'orders'),
                    ),
                    _FilterChipButton(
                      label: 'Cortes',
                      selected: selectedAdminSection == 'payouts',
                      onTap: () =>
                          setState(() => selectedAdminSection = 'payouts'),
                    ),
                    _FilterChipButton(
                      label: 'Tecnicos',
                      selected: selectedAdminSection == 'technicians',
                      onTap: () =>
                          setState(() => selectedAdminSection = 'technicians'),
                    ),
                  ],
                ),
                if (_showDashboard) ...[
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(26),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Centro de control',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Usa estas secciones para revisar el negocio mas rapido: tecnicos destacados, cortes pendientes y ordenes por cobrar.',
                          style: TextStyle(
                            color: Color(0xFF756B61),
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Alertas urgentes',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: emergencyReportsStream,
                    builder: (context, emergencySnapshot) {
                      if (emergencySnapshot.connectionState ==
                          ConnectionState.waiting) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }

                      if (emergencySnapshot.hasError) {
                        return Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: Text(
                            'No se pudieron cargar las alertas: ${emergencySnapshot.error}',
                          ),
                        );
                      }

                      final reports = [...(emergencySnapshot.data?.docs ?? [])]
                        ..sort((a, b) {
                          final aTime = a.data()['createdAt'] as Timestamp?;
                          final bTime = b.data()['createdAt'] as Timestamp?;
                          return (bTime?.millisecondsSinceEpoch ?? 0)
                              .compareTo(aTime?.millisecondsSinceEpoch ?? 0);
                        });

                      if (reports.isEmpty) {
                        return Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: const Text(
                            'No hay reportes urgentes en este momento.',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        );
                      }

                      return Column(
                        children: reports.take(5).map((doc) {
                          final data = doc.data();
                          final service =
                              (data['service'] ?? 'Servicio').toString();
                          final technicianName =
                              (data['technicianName'] ?? 'Tecnico').toString();
                          final status =
                              (data['status'] ?? 'pendiente').toString();
                          final resolved = data['resolved'] == true;

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: resolved
                                    ? const Color(0xFFE5E7EB)
                                    : const Color(0xFFFCA5A5),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Expanded(
                                      child: Text(
                                        'Reporte de emergencia',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ),
                                    _StatusPill(
                                      label: resolved ? 'resuelto' : 'urgente',
                                      color: resolved
                                          ? const Color(0xFF0F766E)
                                          : const Color(0xFFB91C1C),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text('Servicio: $service'),
                                const SizedBox(height: 4),
                                Text('Tecnico: $technicianName'),
                                const SizedBox(height: 4),
                                Text('Estado de la orden: $status'),
                              ],
                            ),
                          );
                        }).toList(),
                      );
                    },
                  ),
                ],
                if (_showTechnicians) ...[
                  const SizedBox(height: 18),
                const Text(
                  'Tecnicos y verificacion',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: techniciansStream,
                  builder: (context, techSnapshot) {
                    if (techSnapshot.connectionState == ConnectionState.waiting) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }

                    if (techSnapshot.hasError) {
                      return Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Text(
                          'No se pudieron cargar las suscripciones: ${techSnapshot.error}',
                        ),
                      );
                    }

                    final technicians = techSnapshot.data?.docs ?? [];
                    final highlighted = [...technicians]
                      ..sort((a, b) {
                        final aData = a.data();
                        final bData = b.data();
                        final activeCompare = (_hasActivePromotion(bData) ? 1 : 0)
                            .compareTo(_hasActivePromotion(aData) ? 1 : 0);
                        if (activeCompare != 0) return activeCompare;
                        return ((bData['subscriptionPriority'] as num?)?.toInt() ?? 0)
                            .compareTo(
                          (aData['subscriptionPriority'] as num?)?.toInt() ?? 0,
                        );
                      });

                    final visibleTechnicians = highlighted.where((doc) {
                      if (selectedVerificationFilter == 'all') return true;
                      final status =
                          (doc.data()['verificationStatus'] ?? 'not_submitted')
                              .toString();
                      return status == selectedVerificationFilter;
                    }).toList();

                    if (visibleTechnicians.isEmpty) {
                      return Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: const Text(
                          'No hay tecnicos para ese filtro en este momento.',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      );
                    }

                    return Column(
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _FilterChipButton(
                              label: 'Todos',
                              selected: selectedVerificationFilter == 'all',
                              onTap: () => setState(
                                () => selectedVerificationFilter = 'all',
                              ),
                            ),
                            _FilterChipButton(
                              label: 'Verificados',
                              selected:
                                  selectedVerificationFilter == 'approved',
                              onTap: () => setState(
                                () => selectedVerificationFilter = 'approved',
                              ),
                            ),
                            _FilterChipButton(
                              label: 'En revision',
                              selected:
                                  selectedVerificationFilter == 'pending',
                              onTap: () => setState(
                                () => selectedVerificationFilter = 'pending',
                              ),
                            ),
                            _FilterChipButton(
                              label: 'No verificados',
                              selected:
                                  selectedVerificationFilter == 'rejected',
                              onTap: () => setState(
                                () => selectedVerificationFilter = 'rejected',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ...visibleTechnicians.take(8).map((doc) {
                        final data = doc.data();
                        final name = (data['name'] ?? 'Tecnico').toString();
                        final city = (data['city'] ?? 'Sin ciudad').toString();
                        final plan =
                            (data['subscriptionPlan'] ?? 'basic').toString();
                        final status =
                            (data['subscriptionStatus'] ?? 'inactive').toString();
                        final promotedUntil = data['promotedUntil'] as Timestamp?;
                        final payoutName =
                            (data['payoutAccountName'] ?? '').toString();
                        final payoutPhone =
                            (data['payoutMobilePhone'] ?? '').toString();
                        final payoutId =
                            (data['payoutDocumentId'] ?? '').toString();
                        final payoutBank = (data['payoutBank'] ?? '').toString();
                        final verificationStatus =
                            (data['verificationStatus'] ?? 'not_submitted')
                                .toString();
                        final idDocumentUrl =
                            (data['idDocumentUrl'] ?? '').toString();
                        final credentialDocumentUrl =
                            (data['credentialDocumentUrl'] ?? '').toString();
                        final isActive = _hasActivePromotion(data);
                        final color = _subscriptionColor(plan, isActive);

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(26),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CircleAvatar(
                                radius: 24,
                                backgroundColor: color.withOpacity(0.12),
                                child: Icon(
                                  plan == 'premium'
                                      ? Icons.workspace_premium
                                      : Icons.rocket_launch_outlined,
                                  color: color,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      name,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      city,
                                      style: const TextStyle(
                                        color: Color(0xFF756B61),
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: [
                                        _StatusPill(
                                          label: plan.toUpperCase(),
                                          color: color,
                                        ),
                                        _StatusPill(
                                          label: isActive ? 'activa' : status,
                                          color: isActive
                                              ? const Color(0xFF16A34A)
                                              : const Color(0xFF6B7280),
                                        ),
                                        _StatusPill(
                                          label: verificationStatus == 'approved'
                                              ? 'verificado'
                                              : verificationStatus == 'pending'
                                                  ? 'revision'
                                                  : verificationStatus ==
                                                          'rejected'
                                                      ? 'rechazado'
                                                      : 'sin verificar',
                                          color: verificationStatus ==
                                                  'approved'
                                              ? const Color(0xFF16A34A)
                                              : verificationStatus == 'pending'
                                                  ? const Color(0xFFFF7A00)
                                                  : verificationStatus ==
                                                          'rejected'
                                                      ? const Color(0xFFDC2626)
                                                      : const Color(0xFF6B7280),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      'Vence: ${_formatDate(promotedUntil)}',
                                      style: const TextStyle(
                                        color: Color(0xFF3B3129),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _subscriptionCountdown(
                                        promotedUntil,
                                        status,
                                      ),
                                      style: const TextStyle(
                                        color: Color(0xFF756B61),
                                      ),
                                    ),
                                    if (payoutPhone.isNotEmpty ||
                                        payoutBank.isNotEmpty) ...[
                                      const SizedBox(height: 10),
                                      Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF7F4EF),
                                          borderRadius:
                                              BorderRadius.circular(18),
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                              'Datos para pagarle',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                            if (payoutName.isNotEmpty) ...[
                                              const SizedBox(height: 6),
                                              Text('Titular: $payoutName'),
                                            ],
                                            if (payoutPhone.isNotEmpty) ...[
                                              const SizedBox(height: 4),
                                              Text('Pago movil: $payoutPhone'),
                                            ],
                                            if (payoutId.isNotEmpty) ...[
                                              const SizedBox(height: 4),
                                              Text('Documento: $payoutId'),
                                            ],
                                            if (payoutBank.isNotEmpty) ...[
                                              const SizedBox(height: 4),
                                              Text('Banco: $payoutBank'),
                                            ],
                                          ],
                                        ),
                                      ),
                                    ],
                                    const SizedBox(height: 10),
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF7F4EF),
                                        borderRadius:
                                            BorderRadius.circular(18),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'Documentos opcionales',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                          if (idDocumentUrl.isNotEmpty) ...[
                                            const SizedBox(height: 6),
                                            OutlinedButton.icon(
                                              onPressed: () => _openProof(
                                                context,
                                                idDocumentUrl,
                                              ),
                                              icon:
                                                  const Icon(Icons.badge_outlined),
                                              label: const Text('Ver cedula'),
                                            ),
                                          ],
                                          if (credentialDocumentUrl.isNotEmpty)
                                            OutlinedButton.icon(
                                              onPressed: () => _openProof(
                                                context,
                                                credentialDocumentUrl,
                                              ),
                                              icon: const Icon(
                                                Icons.description_outlined,
                                              ),
                                              label: const Text(
                                                'Ver soporte profesional',
                                              ),
                                            ),
                                          if (idDocumentUrl.isEmpty &&
                                              credentialDocumentUrl.isEmpty) ...[
                                            const SizedBox(height: 6),
                                            const Text(
                                              'Este tecnico aun no ha subido documentos.',
                                              style: TextStyle(
                                                color: Color(0xFF756B61),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: ElevatedButton(
                                            onPressed: () async {
                                              await FirebaseFirestore.instance
                                                  .collection('users')
                                                  .doc(doc.id)
                                                  .set({
                                                'verificationStatus':
                                                    'approved',
                                                'verificationReviewedAt':
                                                    FieldValue
                                                        .serverTimestamp(),
                                                'updatedAt': FieldValue
                                                    .serverTimestamp(),
                                              }, SetOptions(merge: true));

                                              if (!context.mounted) return;
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                    '$name marcado como verificado.',
                                                  ),
                                                ),
                                              );
                                            },
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor:
                                                  const Color(0xFF16A34A),
                                              foregroundColor: Colors.white,
                                            ),
                                            child: const Text('Verificar'),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: ElevatedButton(
                                            onPressed: () async {
                                              await FirebaseFirestore.instance
                                                  .collection('users')
                                                  .doc(doc.id)
                                                  .set({
                                                'verificationStatus':
                                                    'rejected',
                                                'verificationReviewedAt':
                                                    FieldValue
                                                        .serverTimestamp(),
                                                'updatedAt': FieldValue
                                                    .serverTimestamp(),
                                              }, SetOptions(merge: true));

                                              if (!context.mounted) return;
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                    '$name marcado como no verificado.',
                                                  ),
                                                ),
                                              );
                                            },
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor:
                                                  const Color(0xFFDC2626),
                                              foregroundColor: Colors.white,
                                            ),
                                            child:
                                                const Text('No verificar'),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
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
                ],
                if (_showPayouts) ...[
                  const SizedBox(height: 18),
                const Text(
                  'Corte de pagos a tecnicos',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: payoutsStream,
                  builder: (context, payoutSnapshot) {
                    if (payoutSnapshot.connectionState == ConnectionState.waiting) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }

                    if (payoutSnapshot.hasError) {
                      return Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Text(
                          'No se pudo cargar el corte de pagos: ${payoutSnapshot.error}',
                        ),
                      );
                    }

                    final orders = payoutSnapshot.data?.docs ?? [];
                    final pendingOrders = orders.where((doc) {
                      final data = doc.data();
                      return (data['payoutStatus'] ?? '').toString() !=
                          'paid_out';
                    }).toList();

                    final Map<String, List<QueryDocumentSnapshot<Map<String, dynamic>>>>
                        grouped = {};

                    for (final doc in pendingOrders) {
                      final data = doc.data();
                      final technicianId =
                          (data['technicianId'] ?? '').toString().trim();
                      if (technicianId.isEmpty) continue;
                      grouped.putIfAbsent(technicianId, () => []).add(doc);
                    }

                    if (grouped.isEmpty) {
                      return Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Text(
                          'No hay pagos pendientes por corte. Proximo corte sugerido: ${_nextPayoutLabel()}.',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      );
                    }

                    return Column(
                      children: grouped.entries.map((entry) {
                        final technicianId = entry.key;
                        final techOrders = entry.value;
                        final orderTechnicianName = techOrders.first
                                .data()['technicianName']
                                ?.toString() ??
                            'Tecnico';
                        final totalAmount =
                            techOrders.fold<double>(0, (sum, doc) {
                          final data = doc.data();
                          final amount =
                              ((data['finalPrice'] ?? data['priceFrom'] ?? 0)
                                      as num)
                                  .toDouble();
                          return sum + amount;
                        });

                        return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                          future: FirebaseFirestore.instance
                              .collection('users')
                              .doc(technicianId)
                              .get(),
                          builder: (context, technicianSnapshot) {
                            final techData = technicianSnapshot.data?.data() ?? {};
                            final technicianName =
                                techData['name']?.toString() ??
                                    orderTechnicianName;
                            final payoutName =
                                (techData['payoutAccountName'] ?? '').toString();
                            final payoutPhone =
                                (techData['payoutMobilePhone'] ?? '').toString();
                            final payoutBank =
                                (techData['payoutBank'] ?? '').toString();
                            final payoutDocumentId =
                                (techData['payoutDocumentId'] ?? '').toString();

                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(18),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(26),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const CircleAvatar(
                                        radius: 22,
                                        backgroundColor: Color(0xFFFFF1E6),
                                        child: Icon(
                                          Icons.payments_outlined,
                                          color: Color(0xFFFF7A00),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              technicianName,
                                              style: const TextStyle(
                                                fontSize: 17,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              '${techOrders.length} trabajos listos para pagar',
                                              style: const TextStyle(
                                                color: Color(0xFF756B61),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Text(
                                        '\$${totalAmount.toStringAsFixed(2)}',
                                        style: const TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.w900,
                                          color: Color(0xFF0F766E),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF7F4EF),
                                      borderRadius: BorderRadius.circular(18),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Datos para pagarle',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                        if (payoutName.isNotEmpty) ...[
                                          const SizedBox(height: 6),
                                          Text('Titular: $payoutName'),
                                        ],
                                        if (payoutPhone.isNotEmpty) ...[
                                          const SizedBox(height: 4),
                                          Text('Pago movil: $payoutPhone'),
                                        ],
                                        if (payoutDocumentId.isNotEmpty) ...[
                                          const SizedBox(height: 4),
                                          Text('Documento: $payoutDocumentId'),
                                        ],
                                        if (payoutBank.isNotEmpty) ...[
                                          const SizedBox(height: 4),
                                          Text('Banco: $payoutBank'),
                                        ],
                                        if (payoutName.isEmpty &&
                                            payoutPhone.isEmpty &&
                                            payoutBank.isEmpty &&
                                            payoutDocumentId.isEmpty) ...[
                                          const SizedBox(height: 6),
                                          const Text(
                                            'Este tecnico aun no ha llenado sus datos de pago movil.',
                                            style: TextStyle(
                                              color: Color(0xFF756B61),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton.icon(
                                      onPressed: () => _markTechnicianPayoutAsPaid(
                                        context,
                                        technicianId: technicianId,
                                        technicianName: technicianName,
                                        payoutName: payoutName,
                                        payoutPhone: payoutPhone,
                                        payoutBank: payoutBank,
                                        payoutDocumentId: payoutDocumentId,
                                        orders: techOrders,
                                        totalAmount: totalAmount,
                                      ),
                                      icon: const Icon(Icons.check_circle_outline),
                                      label: const Text('Marcar pago realizado'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF0F766E),
                                        foregroundColor: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        );
                      }).toList(),
                    );
                  },
                ),
                ],
                if (_showOrders) ...[
                  const SizedBox(height: 18),
                const Text(
                  'Pagos y comprobantes',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _FilterChipButton(
                      label: 'Todos',
                      selected: selectedFilter == 'all',
                      onTap: () => setState(() => selectedFilter = 'all'),
                    ),
                    _FilterChipButton(
                      label: 'Revision',
                      selected: selectedFilter == 'review',
                      onTap: () => setState(() => selectedFilter = 'review'),
                    ),
                    _FilterChipButton(
                      label: 'Pendientes',
                      selected: selectedFilter == 'pending',
                      onTap: () => setState(() => selectedFilter = 'pending'),
                    ),
                    _FilterChipButton(
                      label: 'Aprobados',
                      selected: selectedFilter == 'paid',
                      onTap: () => setState(() => selectedFilter = 'paid'),
                    ),
                    _FilterChipButton(
                      label: 'Rechazados',
                      selected: selectedFilter == 'rejected',
                      onTap: () => setState(() => selectedFilter = 'rejected'),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                TextField(
                  onChanged: (value) {
                    setState(() {
                      searchTerm = value;
                    });
                  },
                  decoration: const InputDecoration(
                    hintText: 'Buscar por cliente, tecnico o servicio',
                    prefixIcon: Icon(Icons.search),
                  ),
                ),
                const SizedBox(height: 18),
                if (filteredDocs.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: const Text(
                      'No hay ordenes para este filtro.',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  )
                  else
                    ...filteredDocs.map((doc) {
                    final data = doc.data();

                    final service =
                        (data['service'] ?? data['serviceName'] ?? 'Servicio')
                            .toString();
                    final clientName =
                        (data['clientName'] ?? 'Cliente').toString();
                    final technicianName =
                        (data['technicianName'] ?? 'Tecnico').toString();
                    final status = (data['status'] ?? 'pending').toString();
                    final paymentStatus =
                        (data['paymentStatus'] ?? 'pending').toString();
                    final clientId = (data['clientId'] ?? '').toString();
                    final technicianId = (data['technicianId'] ?? '').toString();
                    final amount =
                        ((data['finalPrice'] ?? data['priceFrom'] ?? 0) as num)
                            .toDouble();
                    final paymentMethod =
                        (data['paymentMethod'] ?? 'Sin metodo').toString();
                    final paymentReference =
                        (data['paymentReference'] ?? '').toString();
                    final payerName = (data['payerName'] ?? '').toString();
                    final paymentPhone =
                        (data['payerPhone'] ?? data['paymentPhone'] ?? '')
                            .toString();
                    final payerDocument =
                        (data['payerDocument'] ?? '').toString();
                    final paymentProofUrl =
                        (data['paymentProofUrl'] ?? '').toString();

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
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      service,
                                      style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'Cliente: $clientName',
                                      style: const TextStyle(
                                        color: Color(0xFF756B61),
                                      ),
                                    ),
                                    Text(
                                      'Tecnico: $technicianName',
                                      style: const TextStyle(
                                        color: Color(0xFF756B61),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  _StatusPill(
                                    label: paymentStatus,
                                    color: _paymentColor(paymentStatus),
                                  ),
                                  const SizedBox(height: 8),
                                  _StatusPill(
                                    label: status,
                                    color: _statusColor(status),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF7F4EF),
                              borderRadius: BorderRadius.circular(22),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Monto: \$${amount.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text('Metodo: $paymentMethod'),
                                if (payerName.isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  Text('Titular: $payerName'),
                                ],
                                if (paymentPhone.isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  Text('Pago movil: $paymentPhone'),
                                ],
                                if (payerDocument.isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  Text('Documento: $payerDocument'),
                                ],
                                if (paymentReference.isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  Text('Referencia: $paymentReference'),
                                ],
                              ],
                            ),
                          ),
                          if (paymentProofUrl.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: () => _openProof(
                                  context,
                                  paymentProofUrl,
                                ),
                                icon: const Icon(Icons.open_in_new),
                                label: const Text('Ver comprobante'),
                              ),
                            ),
                          ],
                          if (paymentStatus == 'pending' ||
                              paymentStatus == 'review') ...[
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: () => _updatePaymentStatus(
                                      context,
                                      orderId: doc.id,
                                      clientId: clientId,
                                      technicianId: technicianId,
                                      service: service,
                                      paymentStatus: 'paid',
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF16A34A),
                                    ),
                                    child: const Text('Aprobar'),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: () => _updatePaymentStatus(
                                      context,
                                      orderId: doc.id,
                                      clientId: clientId,
                                      technicianId: technicianId,
                                      service: service,
                                      paymentStatus: 'rejected',
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFFDC2626),
                                    ),
                                    child: const Text('Rechazar'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    );
                  }),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;

  const _MetricCard({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 150,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFFF8D8B6),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChipButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChipButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFFFE2BF) : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? const Color(0xFFFFB15C) : const Color(0xFFE3DDD5),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? const Color(0xFF8A4700) : const Color(0xFF3B3129),
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusPill({
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}
