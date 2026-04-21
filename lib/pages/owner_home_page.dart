import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/bcv_rate_service.dart';
import 'auth_service.dart';

class OwnerHomePage extends StatefulWidget {
  const OwnerHomePage({super.key});

  @override
  State<OwnerHomePage> createState() => _OwnerHomePageState();
}

class _OwnerHomePageState extends State<OwnerHomePage> {
  String selectedSection = 'payouts';
  String movementSearch = '';
  String selectedCityFilter = 'Todas';
  String subscriptionSearch = '';
  String subscriptionStatusFilter = 'pending_review';
  String technicianSubscriptionStatusFilter = 'Todos';
  bool isSavingBcv = false;

  final TextEditingController bcvRateController = TextEditingController();
  final TextEditingController bcvApiUrlController =
      TextEditingController(text: BcvRateService.defaultApiUrl);
  final TextEditingController bcvApiKeyController = TextEditingController();

  bool get _showOverview => selectedSection == 'overview';
  bool get _showAlerts =>
      selectedSection == 'overview' || selectedSection == 'alerts';
  bool get _showEmergencies =>
      selectedSection == 'overview' || selectedSection == 'emergencies';
  bool get _showPayouts =>
      selectedSection == 'overview' || selectedSection == 'payouts';
  bool get _showSubscriptions =>
      selectedSection == 'overview' || selectedSection == 'subscriptions';
  bool get _showClientPayments =>
      selectedSection == 'overview' || selectedSection == 'client_payments';

  Timestamp get _notificationExpiry => Timestamp.fromDate(
        DateTime.now().add(const Duration(days: 30)),
      );

  @override
  void dispose() {
    bcvRateController.dispose();
    bcvApiUrlController.dispose();
    bcvApiKeyController.dispose();
    super.dispose();
  }

  String _subscriptionStatusLabel(String status) {
    switch (status) {
      case 'pending_review':
        return 'Pendiente';
      case 'approved':
        return 'Aprobada';
      case 'rejected':
        return 'Rechazada';
      case 'active':
        return 'Activa';
      case 'inactive':
        return 'Basico';
      case 'manual':
        return 'Manual';
      default:
        return status.isEmpty ? 'Sin estado' : status;
    }
  }

  bool _matchesSubscriptionSearch(Map<String, dynamic> data) {
    final query = subscriptionSearch.trim().toLowerCase();
    if (query.isEmpty) return true;
    final searchable = [
      data['technicianName'],
      data['name'],
      data['payerName'],
      data['planTitle'],
      data['paymentReference'],
      data['technicianId'],
      data['subscriptionTitle'],
    ].whereType<Object>().join(' ').toLowerCase();
    return searchable.contains(query);
  }

  bool _matchesTechnicianSubscriptionStatus(Map<String, dynamic> data) {
    final status = (data['subscriptionStatus'] ?? 'inactive').toString();
    final paymentStatus =
        (data['subscriptionPaymentStatus'] ?? '').toString();
    switch (technicianSubscriptionStatusFilter) {
      case 'Activos':
        return status == 'active';
      case 'Pendientes':
        return paymentStatus == 'pending_review' || paymentStatus == 'pending';
      case 'Basico':
        return status != 'active';
      default:
        return true;
    }
  }

  String _formatVes(num amount) {
    return 'Bs ${amount.toDouble().toStringAsFixed(2)}';
  }

  Future<void> _saveBcvRate(BuildContext context) async {
    final rateText = bcvRateController.text.trim().replaceAll(',', '.');
    final rate = double.tryParse(rateText);

    if (rate == null || rate <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Coloca una tasa BCV valida.')),
      );
      return;
    }

    setState(() => isSavingBcv = true);
    try {
      await BcvRateService.saveManualRate(
        rate: rate,
        source: 'BCV manual',
        rateDate: DateTime.now().toIso8601String(),
        apiUrl: bcvApiUrlController.text,
        apiKey: bcvApiKeyController.text,
      );

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tasa BCV guardada.')),
      );
      setState(() {});
    } finally {
      if (mounted) setState(() => isSavingBcv = false);
    }
  }

  Future<void> _syncBcvRate(BuildContext context) async {
    setState(() => isSavingBcv = true);
    try {
      final rate = await BcvRateService.getRate(
        forceRefresh: true,
        persistOnlineRate: true,
      );
      if (rate.isAvailable) {
        bcvRateController.text = rate.rate.toStringAsFixed(4);
      }

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            rate.fromInternet
                ? 'BCV actualizado automaticamente.'
                : rate.isAvailable
                    ? 'No se pudo conectar. Se uso la ultima tasa guardada.'
                    : 'No se pudo conectar al BCV. Coloca la tasa manual y toca Guardar respaldo.',
          ),
        ),
      );
      setState(() {});
    } finally {
      if (mounted) setState(() => isSavingBcv = false);
    }
  }

  Future<void> _setManualSubscription({
    required BuildContext context,
    required String technicianId,
    required String technicianName,
    required String planId,
    required String title,
    required String monthlyPrice,
    required int priority,
    required int durationDays,
    required List<String> benefits,
  }) async {
    final promotedUntil = planId == 'basic'
        ? null
        : Timestamp.fromDate(
            DateTime.now().add(Duration(days: durationDays)),
          );

    await FirebaseFirestore.instance.collection('users').doc(technicianId).set({
      'subscriptionPlan': planId,
      'subscriptionTitle': title,
      'subscriptionPriceLabel': monthlyPrice,
      'subscriptionStatus': planId == 'basic' ? 'inactive' : 'active',
      'subscriptionPriority': priority,
      'subscriptionBenefits': benefits,
      'promotedUntil': promotedUntil,
      'subscriptionPaymentStatus': planId == 'basic' ? 'none' : 'manual',
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          planId == 'basic'
              ? 'Plan quitado a $technicianName.'
              : 'Plan $title activado manualmente para $technicianName.',
        ),
      ),
    );
  }

  Future<void> _signOut() async {
    await AuthService().signOut();
  }

  Future<void> _markAlertRead(String alertId) async {
    await FirebaseFirestore.instance.collection('owner_alerts').doc(alertId).set({
      'isRead': true,
      'readAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> _reviewClientPayment({
    required BuildContext context,
    required String orderId,
    required String clientId,
    required String technicianId,
    required String service,
    required String paymentStatus,
  }) async {
    final batch = FirebaseFirestore.instance.batch();
    final approved = paymentStatus == 'paid';
    final refundPending = !approved;
    final nextPaymentStatus = approved ? paymentStatus : 'refund_pending';
    var retainedAmountBs = 0.0;
    var retainedAmountUsd = 0.0;

    if (refundPending) {
      final orderSnapshot = await FirebaseFirestore.instance
          .collection('orders')
          .doc(orderId)
          .get();
      final orderData = orderSnapshot.data() ?? {};
      retainedAmountBs =
          ((orderData['paymentAmountBs'] ?? orderData['finalPriceBs'] ?? 0)
                      as num?)
                  ?.toDouble() ??
              0;
      retainedAmountUsd =
          ((orderData['paymentAmountUsd'] ??
                      orderData['finalPriceUsd'] ??
                      orderData['finalPrice'] ??
                      orderData['priceFrom'] ??
                      0) as num?)
                  ?.toDouble() ??
              0;
      final lockedRate = ((orderData['bcvRate'] ?? 0) as num?)?.toDouble() ?? 0;
      if (retainedAmountUsd <= 0 && retainedAmountBs > 0 && lockedRate > 0) {
        retainedAmountUsd =
            double.parse((retainedAmountBs / lockedRate).toStringAsFixed(2));
      }
    }

    batch.set(
      FirebaseFirestore.instance.collection('orders').doc(orderId),
      {
        'paymentStatus': nextPaymentStatus,
        'paymentReviewedAt': FieldValue.serverTimestamp(),
        if (approved) 'paymentApprovedAt': FieldValue.serverTimestamp(),
        if (!approved) 'paymentRejectedAt': FieldValue.serverTimestamp(),
        if (refundPending) 'refundStatus': 'pending_client_info',
        if (refundPending) 'refundReason': 'payment_rejected',
        if (refundPending) 'walletCreditStatus': 'available',
        if (refundPending) 'walletCreditAmountUsd': retainedAmountUsd,
        if (refundPending) 'walletCreditOriginalAmountBs': retainedAmountBs,
        'paymentReviewedBy': FirebaseAuth.instance.currentUser?.uid ?? '',
        'paymentReviewAction': approved ? 'approved' : 'rejected',
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    if (refundPending && retainedAmountBs > 0) {
      batch.set(
        FirebaseFirestore.instance.collection('users').doc(clientId),
        {
          'appWalletBalanceUsd': FieldValue.increment(retainedAmountUsd),
          'appWalletLastReferenceBs': retainedAmountBs,
          'appWalletUpdatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
      batch.set(
        FirebaseFirestore.instance.collection('client_wallet_transactions').doc(),
        {
          'clientId': clientId,
          'orderId': orderId,
          'type': 'credit',
          'reason': 'payment_rejected_retained',
          'amountBs': retainedAmountBs,
          'amountUsd': retainedAmountUsd,
          'currencyBase': 'USD_BCV',
          'service': service,
          'createdAt': FieldValue.serverTimestamp(),
          'createdBy': FirebaseAuth.instance.currentUser?.uid ?? '',
        },
      );
    }

    batch.set(
      FirebaseFirestore.instance.collection('notifications').doc(),
      {
        'userId': clientId,
        'title': approved ? 'Pago aprobado' : 'Saldo agregado a Panafix',
        'message': approved
            ? 'Panafix aprobo tu pago movil para "$service".'
            : 'No pudimos aprobar el servicio con ese pago, pero Bs ${retainedAmountBs.toStringAsFixed(2)} quedaron como saldo Panafix para usar en otro servicio o solicitar devolucion.',
        'type': 'payment',
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
        'expiresAt': _notificationExpiry,
      },
    );

    if (technicianId.isNotEmpty && approved) {
      batch.set(
        FirebaseFirestore.instance.collection('notifications').doc(),
        {
          'userId': technicianId,
          'title': 'Pago retenido',
          'message':
              'El pago de "$service" fue aprobado y quedo retenido por Panafix.',
          'type': 'payment',
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
          'expiresAt': _notificationExpiry,
        },
      );
    }

    await batch.commit();

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

  Future<void> _markClientPaymentIncomplete({
    required BuildContext context,
    required String orderId,
    required String clientId,
    required String service,
    required double expectedAmountBs,
    required double expectedAmountUsd,
    required double bcvRate,
  }) async {
    final paidController = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        var isSaving = false;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> save() async {
              final paidAmountBs =
                  double.tryParse(paidController.text.trim().replaceAll(',', '.'));

              if (paidAmountBs == null || paidAmountBs <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Ingresa el monto recibido en Bs.')),
                );
                return;
              }

              if (paidAmountBs >= expectedAmountBs) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'El monto recibido cubre el total. Mejor aprueba el pago.',
                    ),
                  ),
                );
                return;
              }

              final missingAmountBs =
                  double.parse((expectedAmountBs - paidAmountBs).toStringAsFixed(2));
              final effectiveRate = bcvRate > 0
                  ? bcvRate
                  : expectedAmountBs > 0 && expectedAmountUsd > 0
                      ? expectedAmountBs / expectedAmountUsd
                      : 0;
              final paidAmountUsd = effectiveRate > 0
                  ? double.parse((paidAmountBs / effectiveRate).toStringAsFixed(2))
                  : 0.0;
              final missingAmountUsd = effectiveRate > 0
                  ? double.parse((missingAmountBs / effectiveRate).toStringAsFixed(2))
                  : 0.0;

              setDialogState(() {
                isSaving = true;
              });

              final batch = FirebaseFirestore.instance.batch();
              batch.set(
                FirebaseFirestore.instance.collection('users').doc(clientId),
                {
                  'appWalletBalanceUsd': FieldValue.increment(paidAmountUsd),
                  'appWalletLastReferenceBs': paidAmountBs,
                  'appWalletUpdatedAt': FieldValue.serverTimestamp(),
                },
                SetOptions(merge: true),
              );
              batch.set(
                FirebaseFirestore.instance.collection('orders').doc(orderId),
                {
                  'paymentStatus': 'partial_payment',
                  'partialPaymentStatus': 'needs_top_up',
                  'creditedAmountBs': paidAmountBs,
                  'missingAmountBs': missingAmountBs,
                  'missingAmountUsd': missingAmountUsd,
                  'partialPaymentMarkedAt': FieldValue.serverTimestamp(),
                  'partialPaymentMarkedBy':
                      FirebaseAuth.instance.currentUser?.uid ?? '',
                  'updatedAt': FieldValue.serverTimestamp(),
                },
                SetOptions(merge: true),
              );
              batch.set(
                FirebaseFirestore.instance
                    .collection('client_wallet_transactions')
                    .doc(),
                {
                  'clientId': clientId,
                  'orderId': orderId,
                  'type': 'credit',
                  'reason': 'partial_payment_credit',
                  'amountBs': paidAmountBs,
                  'amountUsd': paidAmountUsd,
                  'bcvRate': effectiveRate,
                  'currencyBase': 'USD_BCV',
                  'service': service,
                  'createdAt': FieldValue.serverTimestamp(),
                  'createdBy': FirebaseAuth.instance.currentUser?.uid ?? '',
                },
              );
              batch.set(
                FirebaseFirestore.instance.collection('notifications').doc(),
                {
                  'userId': clientId,
                  'title': 'Pago incompleto',
                  'message':
                      'Recibimos parte del pago de "$service". Bs ${paidAmountBs.toStringAsFixed(2)} quedaron como saldo Panafix y falta completar Bs ${missingAmountBs.toStringAsFixed(2)}.',
                  'type': 'payment',
                  'isRead': false,
                  'createdAt': FieldValue.serverTimestamp(),
                  'expiresAt': _notificationExpiry,
                },
              );

              await batch.commit();

              if (!context.mounted) return;
              Navigator.pop(dialogContext);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Abono guardado. Falta Bs ${missingAmountBs.toStringAsFixed(2)}.',
                  ),
                ),
              );
            }

            return AlertDialog(
              title: const Text('Pago incompleto'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Total esperado: ${_formatVes(expectedAmountBs)}'),
                  const SizedBox(height: 12),
                  TextField(
                    controller: paidController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Monto recibido en Bs',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'El monto recibido queda como abono dentro de Panafix y el cliente pagara solo la diferencia.',
                    style: TextStyle(color: Color(0xFF6D5E4F), height: 1.35),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.pop(dialogContext),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: isSaving ? null : save,
                  child: Text(isSaving ? 'Guardando...' : 'Guardar abono'),
                ),
              ],
            );
          },
        );
      },
    );

    paidController.dispose();
  }

  Future<void> _releaseTechnicianPayment({
    required BuildContext context,
    required String orderId,
    required String technicianId,
    required String clientId,
    required String service,
  }) async {
    final batch = FirebaseFirestore.instance.batch();

    batch.set(
      FirebaseFirestore.instance.collection('orders').doc(orderId),
      {
        'paymentStatus': 'released',
        'releaseStatus': 'released',
        'releasedAt': FieldValue.serverTimestamp(),
        'releasedBy': FirebaseAuth.instance.currentUser?.uid ?? '',
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    if (technicianId.isNotEmpty) {
      batch.set(FirebaseFirestore.instance.collection('notifications').doc(), {
        'userId': technicianId,
        'title': 'Pago autorizado',
        'message':
            'Panafix autorizo el pago de "$service". Ya puedes solicitarlo en tu panel.',
        'type': 'payment',
        'isRead': false,
        'orderId': orderId,
        'createdAt': FieldValue.serverTimestamp(),
        'expiresAt': _notificationExpiry,
      });
    }

    if (clientId.isNotEmpty) {
      batch.set(FirebaseFirestore.instance.collection('notifications').doc(), {
        'userId': clientId,
        'title': 'Servicio cerrado',
        'message': 'Panafix cerro el servicio "$service" y autorizo el pago al tecnico.',
        'type': 'payment',
        'isRead': false,
        'orderId': orderId,
        'createdAt': FieldValue.serverTimestamp(),
        'expiresAt': _notificationExpiry,
      });
    }

    await batch.commit();

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Pago autorizado. El tecnico ya puede solicitarlo.'),
      ),
    );
  }

  Future<void> _resolveEmergency(String reportId) async {
    await FirebaseFirestore.instance
        .collection('emergency_reports')
        .doc(reportId)
        .set({
      'resolved': true,
      'resolvedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> _resolveClaim(String claimId, String orderId) async {
    await FirebaseFirestore.instance.collection('service_claims').doc(claimId).set({
      'status': 'resolved',
      'resolvedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await FirebaseFirestore.instance.collection('orders').doc(orderId).set({
      'claimStatus': 'resolved',
      'claimResolvedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> _openExternalUrl(String url) async {
    if (url.isEmpty) return;
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _approveSubscriptionPayment({
    required BuildContext context,
    required String requestId,
    required String technicianId,
    required String planId,
    required String planTitle,
    required String monthlyPrice,
    required int priority,
    required int durationDays,
    required List<dynamic> benefits,
  }) async {
    final promotedUntil = DateTime.now().add(Duration(days: durationDays));

    final batch = FirebaseFirestore.instance.batch();

    batch.set(
      FirebaseFirestore.instance
          .collection('subscription_payment_requests')
          .doc(requestId),
      {
        'status': 'approved',
        'reviewedAt': FieldValue.serverTimestamp(),
        'approvedAt': FieldValue.serverTimestamp(),
        'reviewedBy': FirebaseAuth.instance.currentUser?.uid ?? '',
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    batch.set(
      FirebaseFirestore.instance.collection('users').doc(technicianId),
      {
        'subscriptionPlan': planId,
        'subscriptionTitle': planTitle,
        'subscriptionPriceLabel': monthlyPrice,
        'subscriptionStatus': 'active',
        'subscriptionPriority': priority,
        'subscriptionBenefits': benefits,
        'promotedUntil': Timestamp.fromDate(promotedUntil),
        'subscriptionPaymentStatus': 'approved',
        'subscriptionRequestedPlan': null,
        'subscriptionRequestedTitle': null,
        'subscriptionRequestedPriceLabel': null,
        'subscriptionPriorityRequested': null,
        'subscriptionRequestedBenefits': null,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    batch.set(
      FirebaseFirestore.instance.collection('notifications').doc(),
      {
        'userId': technicianId,
        'title': 'Suscripcion activada',
        'message':
            'Panafix aprobo tu pago movil y tu plan $planTitle ya esta activo.',
        'type': 'payment',
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
        'expiresAt': _notificationExpiry,
      },
    );

    await batch.commit();

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Plan $planTitle activado correctamente.'),
      ),
    );
  }

  Future<void> _rejectSubscriptionPayment({
    required BuildContext context,
    required String requestId,
    required String technicianId,
    required String planTitle,
  }) async {
    final batch = FirebaseFirestore.instance.batch();

    batch.set(
      FirebaseFirestore.instance
          .collection('subscription_payment_requests')
          .doc(requestId),
      {
        'status': 'rejected',
        'reviewedAt': FieldValue.serverTimestamp(),
        'rejectedAt': FieldValue.serverTimestamp(),
        'reviewedBy': FirebaseAuth.instance.currentUser?.uid ?? '',
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    batch.set(
      FirebaseFirestore.instance.collection('users').doc(technicianId),
      {
        'subscriptionPaymentStatus': 'rejected',
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    batch.set(
      FirebaseFirestore.instance.collection('notifications').doc(),
      {
        'userId': technicianId,
        'title': 'Pago de suscripcion rechazado',
        'message':
            'Panafix rechazo la revision de tu pago movil del plan $planTitle.',
        'type': 'payment',
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
        'expiresAt': _notificationExpiry,
      },
    );

    await batch.commit();

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Pago de $planTitle marcado como rechazado.'),
      ),
    );
  }

  Future<void> _markTechnicianPayoutAsPaid({
    required BuildContext context,
    required String requestId,
    required String technicianId,
    required String technicianName,
    required String payoutName,
    required String payoutPhone,
    required String payoutBank,
    required String payoutDocumentId,
    required List<dynamic> orderIds,
    required double totalAmount,
  }) async {
    final batch = FirebaseFirestore.instance.batch();
    final payoutRef =
        FirebaseFirestore.instance.collection('technician_payouts').doc();

    for (final orderId in orderIds) {
      final orderRef =
          FirebaseFirestore.instance.collection('orders').doc(orderId.toString());
      batch.update(orderRef, {
        'payoutStatus': 'paid_out',
        'payoutSentAt': FieldValue.serverTimestamp(),
        'payoutRecordId': payoutRef.id,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    batch.set(payoutRef, {
      'technicianId': technicianId,
      'technicianName': technicianName,
      'orderIds': orderIds,
      'ordersCount': orderIds.length,
      'totalAmount': totalAmount,
      'status': 'paid_out',
      'payoutAccountName': payoutName,
      'payoutMobilePhone': payoutPhone,
      'payoutBank': payoutBank,
      'payoutDocumentId': payoutDocumentId,
      'createdAt': FieldValue.serverTimestamp(),
    });

    batch.set(
      FirebaseFirestore.instance
          .collection('technician_payout_requests')
          .doc(requestId),
      {
        'status': 'paid_out',
        'processedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    batch.set(
      FirebaseFirestore.instance.collection('notifications').doc(),
      {
        'userId': technicianId,
        'title': 'Pago procesado',
        'message':
            'Panafix marco tu pago por \$${totalAmount.toStringAsFixed(2)} como enviado.',
        'type': 'payment',
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
        'expiresAt': _notificationExpiry,
      },
    );

    await batch.commit();

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Pago a $technicianName marcado como realizado.'),
      ),
    );
  }

  Color _alertColor(String type) {
    switch (type) {
      case 'payment':
        return const Color(0xFFFF7A00);
      case 'emergency':
        return const Color(0xFFB91C1C);
      case 'request':
        return const Color(0xFF2563EB);
      default:
        return const Color(0xFF1B130C);
    }
  }

  String _formatDate(Timestamp? value) {
    if (value == null) return 'Ahora mismo';
    final date = value.toDate().toLocal();
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  Widget _buildBcvAutomationCard(BuildContext context) {
    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: FirebaseFirestore.instance
          .collection('app_config')
          .doc('bcv_rate')
          .get(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data() ?? {};
        final rate = (data['rate'] as num?)?.toDouble() ?? 0;
        final apiUrl =
            data['apiUrl']?.toString() ?? BcvRateService.defaultApiUrl;
        final apiKey = data['apiKey']?.toString() ?? '';
        final source = data['source']?.toString() ?? 'BCV';
        final rateDate = data['rateDate']?.toString() ?? '';

        if (bcvRateController.text.isEmpty && rate > 0) {
          bcvRateController.text = rate.toStringAsFixed(4);
        }
        if (bcvApiUrlController.text.isEmpty) {
          bcvApiUrlController.text = apiUrl;
        }
        if (bcvApiKeyController.text.isEmpty && apiKey.isNotEmpty) {
          bcvApiKeyController.text = apiKey;
        }

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: const Color(0xFFFFD6A3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFEDD8),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.currency_exchange,
                      color: Color(0xFFFF7A00),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Tasa BCV',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          rate > 0
                              ? 'Tasa actual: Bs ${rate.toStringAsFixed(4)} por USD'
                              : 'Aun no hay tasa guardada.',
                          style: const TextStyle(
                            color: Color(0xFF6D5E4F),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'Fuente: $source${rateDate.isNotEmpty ? ' | Fecha: $rateDate' : ''}',
                style: const TextStyle(color: Color(0xFF6D5E4F)),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: bcvRateController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Tasa manual de respaldo',
                  prefixIcon: Icon(Icons.price_change_outlined),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: bcvApiUrlController,
                decoration: const InputDecoration(
                  labelText: 'URL de API BCV opcional',
                  prefixIcon: Icon(Icons.link_outlined),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: bcvApiKeyController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'API key opcional',
                  prefixIcon: Icon(Icons.key_outlined),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  ElevatedButton.icon(
                    onPressed:
                        isSavingBcv ? null : () => _syncBcvRate(context),
                    icon: const Icon(Icons.sync),
                    label: const Text('Actualizar automatico'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF7A00),
                      foregroundColor: Colors.white,
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed:
                        isSavingBcv ? null : () => _saveBcvRate(context),
                    icon: const Icon(Icons.save_outlined),
                    label: const Text('Guardar respaldo'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final ordersStream = FirebaseFirestore.instance
        .collection('orders')
        .orderBy('createdAt', descending: true)
        .snapshots();
    final alertsStream = FirebaseFirestore.instance
        .collection('owner_alerts')
        .snapshots();
    final emergenciesStream = FirebaseFirestore.instance
        .collection('emergency_reports')
        .snapshots();
    final payoutRequestsStream = FirebaseFirestore.instance
        .collection('technician_payout_requests')
        .snapshots();
    final techniciansStream = FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'technician')
        .snapshots();
    final technicianPayoutsStream = FirebaseFirestore.instance
        .collection('technician_payouts')
        .snapshots();
    final serviceClaimsStream = FirebaseFirestore.instance
        .collection('service_claims')
        .snapshots();
    final subscriptionPaymentRequestsStream = FirebaseFirestore.instance
        .collection('subscription_payment_requests')
        .snapshots();
    final clientRefundRequestsStream = FirebaseFirestore.instance
        .collection('client_refund_requests')
        .snapshots();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Super admin'),
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
        builder: (context, orderSnapshot) {
          if (orderSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (orderSnapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'No se pudo cargar el panel de control: ${orderSnapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final orders = orderSnapshot.data?.docs ?? [];
          final completedPendingReleaseOrders = orders.where((doc) {
            final data = doc.data();
            final status = (data['status'] ?? '').toString();
            final paymentStatus = (data['paymentStatus'] ?? '').toString();
            final releaseStatus = (data['releaseStatus'] ?? '').toString();
            final claimStatus = (data['claimStatus'] ?? '').toString();
            return status == 'completed' &&
                paymentStatus == 'paid' &&
                releaseStatus != 'released' &&
                claimStatus != 'open';
          }).toList();
          final releasedOrders = orders.where((doc) {
            final paymentStatus = (doc.data()['paymentStatus'] ?? '').toString();
            final payoutStatus = (doc.data()['payoutStatus'] ?? '').toString();
            return paymentStatus == 'released' && payoutStatus != 'paid_out';
          }).length;
          final now = DateTime.now();
          final startOfToday = DateTime(now.year, now.month, now.day);
          final startOfMonth = DateTime(now.year, now.month, 1);

          bool isSamePeriod(Timestamp? value, DateTime periodStart) {
            if (value == null) return false;
            return !value.toDate().toLocal().isBefore(periodStart);
          }

          final paidOrReleasedOrders = orders.where((doc) {
            final paymentStatus = (doc.data()['paymentStatus'] ?? '').toString();
            return paymentStatus == 'paid' || paymentStatus == 'released';
          }).toList();

          double orderAmount(Map<String, dynamic> data) =>
              ((data['finalPriceBs'] ??
                          data['paymentAmountBs'] ??
                          data['finalPrice'] ??
                          data['priceFrom'] ??
                          0)
                      as num?)
                  ?.toDouble() ??
              0;

          double commissionAmount(Map<String, dynamic> data) {
            final explicitCommission =
                ((data['commissionAmountBs'] ??
                            data['appCommissionBs'] ??
                            data['commissionAmount'])
                        as num?)
                    ?.toDouble();
            if (explicitCommission != null && explicitCommission > 0) {
              return explicitCommission;
            }

            final finalPrice = orderAmount(data);
            final technicianEarning =
                ((data['technicianEarningBs'] ??
                            data['basePriceBs'] ??
                            data['technicianEarning'] ??
                            data['basePrice'] ??
                            0)
                        as num?)
                        ?.toDouble() ??
                    0;

            if (finalPrice <= 0) return 0;
            final commission = finalPrice - technicianEarning;
            return commission > 0 ? commission : 0;
          }

          final revenueToday = paidOrReleasedOrders.fold<double>(0, (sum, doc) {
            final data = doc.data();
            final createdAt = data['createdAt'] as Timestamp?;
            return isSamePeriod(createdAt, startOfToday)
                ? sum + orderAmount(data)
                : sum;
          });

          final revenueMonth = paidOrReleasedOrders.fold<double>(0, (sum, doc) {
            final data = doc.data();
            final createdAt = data['createdAt'] as Timestamp?;
            return isSamePeriod(createdAt, startOfMonth)
                ? sum + orderAmount(data)
                : sum;
          });

          final commissionToday =
              paidOrReleasedOrders.fold<double>(0, (sum, doc) {
            final data = doc.data();
            final createdAt = data['createdAt'] as Timestamp?;
            return isSamePeriod(createdAt, startOfToday)
                ? sum + commissionAmount(data)
                : sum;
          });

          final commissionMonth =
              paidOrReleasedOrders.fold<double>(0, (sum, doc) {
            final data = doc.data();
            final createdAt = data['createdAt'] as Timestamp?;
            return isSamePeriod(createdAt, startOfMonth)
                ? sum + commissionAmount(data)
                : sum;
          });

          final paidOutToTechnicians = orders.fold<double>(0, (sum, doc) {
            final data = doc.data();
            final payoutStatus = (data['payoutStatus'] ?? '').toString();
            if (payoutStatus != 'paid_out') return sum;
            final technicianEarning =
                ((data['technicianEarningBs'] ??
                            data['basePriceBs'] ??
                            data['technicianEarning'] ??
                            data['basePrice'] ??
                            0)
                        as num?)
                        ?.toDouble() ??
                    0;
            return sum + technicianEarning;
          });

          final pendingPayoutAmount = orders.fold<double>(0, (sum, doc) {
            final data = doc.data();
            final paymentStatus = (data['paymentStatus'] ?? '').toString();
            final payoutStatus = (data['payoutStatus'] ?? '').toString();
            if (paymentStatus != 'released' || payoutStatus == 'paid_out') {
              return sum;
            }
            final technicianEarning =
                ((data['technicianEarningBs'] ??
                            data['basePriceBs'] ??
                            data['technicianEarning'] ??
                            data['basePrice'] ??
                            0)
                        as num?)
                        ?.toDouble() ??
                    0;
            return sum + technicianEarning;
          });

          final completedToday = orders.where((doc) {
            final data = doc.data();
            final status = (data['status'] ?? '').toString();
            final updatedAt =
                (data['updatedAt'] ?? data['completedAt']) as Timestamp?;
            return status == 'completed' && isSamePeriod(updatedAt, startOfToday);
          }).length;

          final completedMonth = orders.where((doc) {
            final data = doc.data();
            final status = (data['status'] ?? '').toString();
            final updatedAt =
                (data['updatedAt'] ?? data['completedAt']) as Timestamp?;
            return status == 'completed' && isSamePeriod(updatedAt, startOfMonth);
          }).length;

          final latestMovements = [...orders]
            ..sort((a, b) {
              final aData = a.data();
              final bData = b.data();
              final aTime =
                  (aData['updatedAt'] ?? aData['createdAt']) as Timestamp?;
              final bTime =
                  (bData['updatedAt'] ?? bData['createdAt']) as Timestamp?;
              return (bTime?.millisecondsSinceEpoch ?? 0)
                  .compareTo(aTime?.millisecondsSinceEpoch ?? 0);
            });

          final cities = <String>{
            'Todas',
            ...orders
                .map((doc) => (doc.data()['city'] ?? '').toString().trim())
                .where((city) => city.isNotEmpty),
          }.toList();

          final filteredMovements = latestMovements.where((doc) {
            final data = doc.data();
            final city = (data['city'] ?? '').toString();
            final service =
                (data['service'] ?? data['serviceName'] ?? '').toString();
            final technicianName =
                (data['technicianName'] ?? '').toString();
            final clientName = (data['clientName'] ?? '').toString();
            final query = movementSearch.trim().toLowerCase();

            final matchesCity =
                selectedCityFilter == 'Todas' || city == selectedCityFilter;
            final matchesSearch = query.isEmpty ||
                service.toLowerCase().contains(query) ||
                technicianName.toLowerCase().contains(query) ||
                clientName.toLowerCase().contains(query) ||
                city.toLowerCase().contains(query);

            return matchesCity && matchesSearch;
          }).toList();

          final dailyRevenue = List.generate(7, (index) {
            final day = startOfToday.subtract(Duration(days: 6 - index));
            final nextDay = day.add(const Duration(days: 1));
            final total = paidOrReleasedOrders.fold<double>(0, (sum, doc) {
              final data = doc.data();
              final createdAt = data['createdAt'] as Timestamp?;
              final date = createdAt?.toDate().toLocal();
              if (date == null ||
                  date.isBefore(day) ||
                  !date.isBefore(nextDay)) {
                return sum;
              }
              return sum + orderAmount(data);
            });

            final dayLabel =
                '${day.day.toString().padLeft(2, '0')}/${day.month.toString().padLeft(2, '0')}';
            return {'label': dayLabel, 'amount': total};
          });

          final maxDailyRevenue = dailyRevenue.fold<double>(
            0,
            (max, item) => ((item['amount'] as double) > max
                ? (item['amount'] as double)
                : max),
          );

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
                        Color(0xFFDC2626),
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
                        'Control total',
                        style: TextStyle(
                          color: Color(0xFFFECACA),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Vigila alertas, verificaciones, pagos a tecnicos, emergencias y la salud operativa de Panafix desde un solo lugar.',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 25,
                          fontWeight: FontWeight.w900,
                          height: 1.15,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          _OwnerMetric(
                            label: 'Ordenes',
                            value: orders.length.toString(),
                          ),
                          _OwnerMetric(
                            label: 'Cobros retenidos',
                            value: releasedOrders.toString(),
                          ),
                          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                            stream: payoutRequestsStream,
                            builder: (context, payoutSnapshot) {
                              final pendingPayouts = (payoutSnapshot.data?.docs ??
                                      const <QueryDocumentSnapshot<Map<String, dynamic>>>[])
                                  .where((doc) =>
                                      (doc.data()['status'] ?? '').toString() ==
                                      'requested')
                                  .length;

                              return _OwnerMetric(
                                label: 'Solicitudes pago',
                                value: pendingPayouts.toString(),
                              );
                            },
                          ),
                          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                            stream: techniciansStream,
                            builder: (context, techSnapshot) {
                              final pendingVerification = (techSnapshot.data?.docs ??
                                      const <QueryDocumentSnapshot<Map<String, dynamic>>>[])
                                  .where((doc) =>
                                      (doc.data()['verificationStatus'] ?? '')
                                          .toString() ==
                                      'pending')
                                  .length;

                              return _OwnerMetric(
                                label: 'Por verificar',
                                value: pendingVerification.toString(),
                              );
                            },
                          ),
                          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                            stream: subscriptionPaymentRequestsStream,
                            builder: (context, subscriptionSnapshot) {
                              final pendingSubscriptions =
                                  (subscriptionSnapshot.data?.docs ??
                                          const <QueryDocumentSnapshot<
                                              Map<String, dynamic>>>[])
                                      .where((doc) =>
                                          (doc.data()['status'] ?? '')
                                              .toString() ==
                                          'pending_review')
                                      .length;

                              return _OwnerMetric(
                                label: 'Suscripciones',
                                value: pendingSubscriptions.toString(),
                              );
                            },
                          ),
                          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                            stream: clientRefundRequestsStream,
                            builder: (context, refundSnapshot) {
                              final pendingRefunds =
                                  (refundSnapshot.data?.docs ??
                                          const <QueryDocumentSnapshot<
                                              Map<String, dynamic>>>[])
                                      .where((doc) =>
                                          (doc.data()['status'] ?? '')
                                              .toString() ==
                                          'requested')
                                      .length;

                              return _OwnerMetric(
                                label: 'Devoluciones',
                                value: pendingRefunds.toString(),
                              );
                            },
                          ),
                          _OwnerMetric(
                            label: 'Por liberar',
                            value:
                                completedPendingReleaseOrders.length.toString(),
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
                    _OwnerTab(
                      label: 'Resumen',
                      selected: selectedSection == 'overview',
                      onTap: () => setState(() => selectedSection = 'overview'),
                    ),
                    _OwnerTab(
                      label: 'Alertas',
                      selected: selectedSection == 'alerts',
                      onTap: () => setState(() => selectedSection = 'alerts'),
                    ),
                    _OwnerTab(
                      label: 'Pagos tecnicos',
                      selected: selectedSection == 'payouts',
                      onTap: () => setState(() => selectedSection = 'payouts'),
                    ),
                    _OwnerTab(
                      label: 'Pagos clientes',
                      selected: selectedSection == 'client_payments',
                      onTap: () =>
                          setState(() => selectedSection = 'client_payments'),
                    ),
                    _OwnerTab(
                      label: 'Suscripciones',
                      selected: selectedSection == 'subscriptions',
                      onTap: () =>
                          setState(() => selectedSection = 'subscriptions'),
                    ),
                    _OwnerTab(
                      label: 'Emergencias',
                      selected: selectedSection == 'emergencies',
                      onTap: () =>
                          setState(() => selectedSection = 'emergencies'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildBcvAutomationCard(context),
                if (_showOverview) ...[
                  const SizedBox(height: 18),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        stream: alertsStream,
                        builder: (context, alertSnapshot) {
                          final unreadAlerts = (alertSnapshot.data?.docs ??
                                  const <QueryDocumentSnapshot<Map<String, dynamic>>>[])
                              .where((doc) => doc.data()['isRead'] != true)
                              .length;
                          return _UrgentOwnerCard(
                            title: 'Alertas nuevas',
                            value: unreadAlerts.toString(),
                            color: const Color(0xFFDC2626),
                          );
                        },
                      ),
                      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        stream: emergenciesStream,
                        builder: (context, emergencySnapshot) {
                          final unresolved = (emergencySnapshot.data?.docs ??
                                  const <QueryDocumentSnapshot<Map<String, dynamic>>>[])
                              .where((doc) => doc.data()['resolved'] != true)
                              .length;
                          return _UrgentOwnerCard(
                            title: 'Emergencias',
                            value: unresolved.toString(),
                            color: const Color(0xFFB91C1C),
                          );
                        },
                      ),
                      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        stream: serviceClaimsStream,
                        builder: (context, claimSnapshot) {
                          final openClaims = (claimSnapshot.data?.docs ??
                                  const <QueryDocumentSnapshot<Map<String, dynamic>>>[])
                              .where((doc) =>
                                  (doc.data()['status'] ?? '').toString() ==
                                  'open')
                              .length;
                          return _UrgentOwnerCard(
                            title: 'Reclamos',
                            value: openClaims.toString(),
                            color: const Color(0xFFB91C1C),
                          );
                        },
                      ),
                      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        stream: techniciansStream,
                        builder: (context, techSnapshot) {
                          final pendingVerification = (techSnapshot.data?.docs ??
                                  const <QueryDocumentSnapshot<Map<String, dynamic>>>[])
                              .where((doc) =>
                                  (doc.data()['verificationStatus'] ?? '')
                                      .toString() ==
                                  'pending')
                              .length;
                          return _UrgentOwnerCard(
                            title: 'Por verificar',
                            value: pendingVerification.toString(),
                            color: const Color(0xFFFF7A00),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(26),
                    ),
                    child: const Text(
                      'Este panel centraliza lo mas delicado de la operacion para que puedas reaccionar rapido, revisar riesgos y seguir el dinero del negocio.',
                      style: TextStyle(
                        color: Color(0xFF6D5E4F),
                        height: 1.45,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(26),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Ingresos de los ultimos 7 dias',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Vista rapida del ritmo de ingresos recientes de la plataforma.',
                          style: TextStyle(
                            color: Color(0xFF6D5E4F),
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: dailyRevenue.map((item) {
                            final amount = item['amount'] as double;
                            final factor = maxDailyRevenue <= 0
                                ? 0.12
                                : (amount / maxDailyRevenue).clamp(0.12, 1.0);

                            return Expanded(
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 4),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    Text(
                                      amount <= 0
                                          ? '\$0'
                                          : '\$${amount.toStringAsFixed(0)}',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Color(0xFF6D5E4F),
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Container(
                                      height: 120 * factor,
                                      decoration: BoxDecoration(
                                        gradient: const LinearGradient(
                                          colors: [
                                            Color(0xFFFF8A1F),
                                            Color(0xFFFFC56A),
                                          ],
                                          begin: Alignment.bottomCenter,
                                          end: Alignment.topCenter,
                                        ),
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      item['label'] as String,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Color(0xFF6D5E4F),
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(26),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Resumen financiero',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Aqui ves cuanto dinero entro y cuanto te queda por comisiones dentro de la plataforma.',
                          style: TextStyle(
                            color: Color(0xFF6D5E4F),
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            _FinancialOwnerCard(
                              title: 'Ingresos hoy',
                              value: _formatVes(revenueToday),
                              color: const Color(0xFFFF7A00),
                            ),
                            _FinancialOwnerCard(
                              title: 'Ingresos del mes',
                              value: _formatVes(revenueMonth),
                              color: const Color(0xFF2563EB),
                            ),
                            _FinancialOwnerCard(
                              title: 'Comision hoy',
                              value: _formatVes(commissionToday),
                              color: const Color(0xFF16A34A),
                            ),
                            _FinancialOwnerCard(
                              title: 'Comision del mes',
                              value: _formatVes(commissionMonth),
                              color: const Color(0xFF7C3AED),
                            ),
                            _FinancialOwnerCard(
                              title: 'Pagado a tecnicos',
                              value: _formatVes(paidOutToTechnicians),
                              color: const Color(0xFF0F766E),
                            ),
                            _FinancialOwnerCard(
                              title: 'Pendiente por pagar',
                              value: _formatVes(pendingPayoutAmount),
                              color: const Color(0xFFB45309),
                            ),
                            _FinancialOwnerCard(
                              title: 'Completados hoy',
                              value: completedToday.toString(),
                              color: const Color(0xFFDC2626),
                            ),
                            _FinancialOwnerCard(
                              title: 'Completados mes',
                              value: completedMonth.toString(),
                              color: const Color(0xFF1D4ED8),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(26),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Ultimos movimientos',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Aqui ves lo mas reciente que paso dentro de la operacion.',
                          style: TextStyle(
                            color: Color(0xFF6D5E4F),
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          onChanged: (value) {
                            setState(() {
                              movementSearch = value;
                            });
                          },
                          decoration: InputDecoration(
                            hintText:
                                'Buscar por servicio, cliente, tecnico o ciudad',
                            prefixIcon: const Icon(Icons.search),
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(18),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: cities.map((city) {
                              final selected = selectedCityFilter == city;
                              return Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: InkWell(
                                  onTap: () {
                                    setState(() {
                                      selectedCityFilter = city;
                                    });
                                  },
                                  borderRadius: BorderRadius.circular(999),
                                  child: Ink(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 10,
                                    ),
                                    decoration: BoxDecoration(
                                      color: selected
                                          ? const Color(0xFFFFEDD8)
                                          : const Color(0xFFF8FAFC),
                                      borderRadius: BorderRadius.circular(999),
                                      border: Border.all(
                                        color: selected
                                            ? const Color(0xFFFFC56A)
                                            : const Color(0xFFE5E7EB),
                                      ),
                                    ),
                                    child: Text(
                                      city,
                                      style: TextStyle(
                                        color: selected
                                            ? const Color(0xFFB45309)
                                            : const Color(0xFF5D4D40),
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                        const SizedBox(height: 14),
                        if (filteredMovements.isEmpty)
                          const _EmptyOwnerCard(
                            text:
                                'No hay movimientos para esa busqueda o filtro.',
                          )
                        else
                          ...filteredMovements.take(5).map((doc) {
                            final data = doc.data();
                            final service =
                                (data['service'] ?? data['serviceName'] ?? 'Servicio')
                                    .toString();
                            final technicianName =
                                (data['technicianName'] ?? 'Tecnico').toString();
                            final clientName =
                                (data['clientName'] ?? 'Cliente').toString();
                            final status = (data['status'] ?? 'pending').toString();
                            final paymentStatus =
                                (data['paymentStatus'] ?? 'pending').toString();
                            final amount = orderAmount(data);
                            final updatedAt =
                                (data['updatedAt'] ?? data['createdAt']) as Timestamp?;

                            return Container(
                              width: double.infinity,
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(18),
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
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        '\$${amount.toStringAsFixed(2)}',
                                        style: const TextStyle(
                                          color: Color(0xFF0F766E),
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Cliente: $clientName  |  Tecnico: $technicianName',
                                    style: const TextStyle(
                                      color: Color(0xFF6D5E4F),
                                      height: 1.35,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      _OwnerPill(
                                        label: status,
                                        color: const Color(0xFFDC2626),
                                      ),
                                      _OwnerPill(
                                        label: paymentStatus,
                                        color: const Color(0xFF2563EB),
                                      ),
                                      _OwnerPill(
                                        label: _formatDate(updatedAt),
                                        color: const Color(0xFF6B7280),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          }),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(26),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Historial de pagos a tecnicos',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Resumen de los pagos que ya fueron procesados desde la plataforma.',
                          style: TextStyle(
                            color: Color(0xFF6D5E4F),
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 14),
                        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                          stream: technicianPayoutsStream,
                          builder: (context, payoutSnapshot) {
                            if (!payoutSnapshot.hasData) {
                              return const Center(
                                child: CircularProgressIndicator(),
                              );
                            }

                            final payouts = [...payoutSnapshot.data!.docs]
                              ..sort((a, b) {
                                final aTime =
                                    a.data()['createdAt'] as Timestamp?;
                                final bTime =
                                    b.data()['createdAt'] as Timestamp?;
                                return (bTime?.millisecondsSinceEpoch ?? 0)
                                    .compareTo(aTime?.millisecondsSinceEpoch ?? 0);
                              });

                            if (payouts.isEmpty) {
                              return const _EmptyOwnerCard(
                                text: 'Todavia no has procesado pagos a tecnicos.',
                              );
                            }

                            return Column(
                              children: payouts.take(5).map((doc) {
                                final data = doc.data();
                                final technicianName =
                                    (data['technicianName'] ?? 'Tecnico')
                                        .toString();
                                final totalAmount =
                                    (data['totalAmount'] as num?)?.toDouble() ??
                                        0;
                                final ordersCount =
                                    (data['ordersCount'] as num?)?.toInt() ?? 0;
                                final payoutPhone =
                                    (data['payoutMobilePhone'] ?? '').toString();
                                final createdAt =
                                    data['createdAt'] as Timestamp?;

                                return Container(
                                  width: double.infinity,
                                  margin: const EdgeInsets.only(bottom: 10),
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              technicianName,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                          ),
                                          Text(
                                            '\$${totalAmount.toStringAsFixed(2)}',
                                            style: const TextStyle(
                                              color: Color(0xFF0F766E),
                                              fontWeight: FontWeight.w900,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        '$ordersCount trabajos  |  ${_formatDate(createdAt)}',
                                        style: const TextStyle(
                                          color: Color(0xFF6D5E4F),
                                        ),
                                      ),
                                      if (payoutPhone.isNotEmpty) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          'Pago movil: $payoutPhone',
                                          style: const TextStyle(
                                            color: Color(0xFF6D5E4F),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                );
                              }).toList(),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
                if (_showAlerts) ...[
                  const SizedBox(height: 18),
                  const Text(
                    'Alertas clave',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 10),
                  StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: techniciansStream,
                    builder: (context, techSnapshot) {
                      if (!techSnapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final pendingVerification = techSnapshot.data!.docs.where(
                        (doc) =>
                            (doc.data()['verificationStatus'] ?? '').toString() ==
                            'pending',
                      ).toList();

                      if (pendingVerification.isEmpty) {
                        return const SizedBox();
                      }

                      return Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 14),
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: const Color(0xFFFFD2A8)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Solicitudes de verificacion',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Tienes ${pendingVerification.length} tecnicos esperando revision de documentos.',
                              style: const TextStyle(
                                color: Color(0xFF5D4D40),
                                height: 1.35,
                              ),
                            ),
                            const SizedBox(height: 12),
                            ...pendingVerification.take(5).map((doc) {
                              final data = doc.data();
                              final name =
                                  (data['name'] ?? 'Tecnico').toString();
                              final city =
                                  (data['city'] ?? 'Sin ciudad').toString();
                              final submittedAt =
                                  data['verificationSubmittedAt'] as Timestamp?;

                              return Container(
                                width: double.infinity,
                                margin: const EdgeInsets.only(bottom: 10),
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFF7ED),
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                child: Row(
                                  children: [
                                    const CircleAvatar(
                                      backgroundColor: Color(0xFFFFEDD8),
                                      child: Icon(
                                        Icons.verified_user_outlined,
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
                                            name,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '$city  |  ${_formatDate(submittedAt)}',
                                            style: const TextStyle(
                                              color: Color(0xFF756B61),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 10),
                  StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: serviceClaimsStream,
                    builder: (context, claimSnapshot) {
                      if (!claimSnapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final openClaims = [...claimSnapshot.data!.docs]
                        ..sort((a, b) {
                          final aTime = a.data()['createdAt'] as Timestamp?;
                          final bTime = b.data()['createdAt'] as Timestamp?;
                          return (bTime?.millisecondsSinceEpoch ?? 0)
                              .compareTo(aTime?.millisecondsSinceEpoch ?? 0);
                        });

                      final activeClaims = openClaims.where((doc) {
                        return (doc.data()['status'] ?? '').toString() == 'open';
                      }).toList();

                      if (activeClaims.isEmpty) {
                        return const SizedBox();
                      }

                      return Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 14),
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: const Color(0xFFFCA5A5)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Reclamos de servicio',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Tienes ${activeClaims.length} reclamos abiertos que requieren revision.',
                              style: const TextStyle(
                                color: Color(0xFF5D4D40),
                                height: 1.35,
                              ),
                            ),
                            const SizedBox(height: 12),
                            ...activeClaims.take(5).map((doc) {
                              final data = doc.data();
                              final service =
                                  (data['service'] ?? 'Servicio').toString();
                              final technicianName =
                                  (data['technicianName'] ?? 'Tecnico')
                                      .toString();
                              final problem =
                                  (data['problem'] ?? '').toString();
                              final evidenceUrl =
                                  (data['evidenceUrl'] ?? '').toString();
                              final orderId = (data['orderId'] ?? '').toString();

                              return Container(
                                width: double.infinity,
                                margin: const EdgeInsets.only(bottom: 10),
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFF7ED),
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      service,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text('Tecnico: $technicianName'),
                                    if (problem.isNotEmpty) ...[
                                      const SizedBox(height: 6),
                                      Text(
                                        problem,
                                        style: const TextStyle(
                                          color: Color(0xFF6D5E4F),
                                          height: 1.35,
                                        ),
                                      ),
                                    ],
                                    if (evidenceUrl.isNotEmpty) ...[
                                      const SizedBox(height: 8),
                                      Align(
                                        alignment: Alignment.centerLeft,
                                        child: OutlinedButton.icon(
                                          onPressed: () =>
                                              _openExternalUrl(evidenceUrl),
                                          icon: const Icon(
                                            Icons.photo_camera_back_outlined,
                                          ),
                                          label: const Text(
                                            'Ver evidencia',
                                          ),
                                        ),
                                      ),
                                    ],
                                    const SizedBox(height: 8),
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: TextButton(
                                        onPressed: () =>
                                            _resolveClaim(doc.id, orderId),
                                        child: const Text('Marcar resuelto'),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ],
                        ),
                      );
                    },
                  ),
                  StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: alertsStream,
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final alerts = [...snapshot.data!.docs]
                        ..sort((a, b) {
                          final aTime = a.data()['createdAt'] as Timestamp?;
                          final bTime = b.data()['createdAt'] as Timestamp?;
                          return (bTime?.millisecondsSinceEpoch ?? 0)
                              .compareTo(aTime?.millisecondsSinceEpoch ?? 0);
                        });

                      if (alerts.isEmpty) {
                        return _EmptyOwnerCard(
                          text: 'Todavia no tienes alertas registradas.',
                        );
                      }

                      return Column(
                        children: alerts.take(8).map((doc) {
                          final data = doc.data();
                          final title = (data['title'] ?? 'Alerta').toString();
                          final message = (data['message'] ?? '').toString();
                          final type = (data['type'] ?? 'general').toString();
                          final isRead = data['isRead'] == true;
                          final color = _alertColor(type);
                          final createdAt = data['createdAt'] as Timestamp?;

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: isRead
                                    ? const Color(0xFFE5E7EB)
                                    : color.withOpacity(0.30),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        title,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                    if (!isRead)
                                      _OwnerPill(label: 'nuevo', color: color),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  message,
                                  style: const TextStyle(
                                    color: Color(0xFF5D4D40),
                                    height: 1.4,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        _formatDate(createdAt),
                                        style: const TextStyle(
                                          color: Color(0xFF8C8176),
                                        ),
                                      ),
                                    ),
                                    if (!isRead)
                                      TextButton(
                                        onPressed: () => _markAlertRead(doc.id),
                                        child: const Text('Marcar leida'),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      );
                    },
                  ),
                ],
                if (_showPayouts) ...[
                  const SizedBox(height: 18),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFFFF8A1F),
                          Color(0xFFFFB15A),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Pagos a tecnicos',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Aqui recibes las solicitudes de pago, ves el monto retenido y los datos de pago movil del tecnico para procesar el pago desde tu panel.',
                          style: TextStyle(
                            color: Colors.white,
                            height: 1.4,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Trabajos completados por liberar',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (completedPendingReleaseOrders.isEmpty)
                    const _EmptyOwnerCard(
                      text:
                          'No tienes trabajos completados pendientes por liberar.',
                    )
                  else
                    ...completedPendingReleaseOrders.map((doc) {
                      final data = doc.data();
                      final service =
                          (data['service'] ?? data['serviceName'] ?? 'Servicio')
                              .toString();
                      final technicianId =
                          (data['technicianId'] ?? '').toString();
                      final technicianName =
                          (data['technicianName'] ?? 'Tecnico').toString();
                      final clientId = (data['clientId'] ?? '').toString();
                      final clientName =
                          (data['clientName'] ?? 'Cliente').toString();
                      final claimStatus =
                          (data['claimStatus'] ?? '').toString();
                      final completedAt = data['completedAt'] as Timestamp?;
                      final technicianAmount =
                          ((data['technicianEarningBs'] ??
                                      data['basePriceBs'] ??
                                      data['technicianEarning'] ??
                                      data['basePrice'] ??
                                      0)
                                  as num?)
                              ?.toDouble() ??
                              0;
                      final totalAmount = orderAmount(data);
                      final isVes = data['technicianEarningBs'] != null ||
                          data['basePriceBs'] != null ||
                          data['finalPriceBs'] != null;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: const Color(0xFFFFD6A3)),
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
                                      fontSize: 17,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                                _OwnerPill(
                                  label: 'completado',
                                  color: const Color(0xFF16A34A),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text('Cliente: $clientName'),
                            Text('Tecnico: $technicianName'),
                            Text('Completado: ${_formatDate(completedAt)}'),
                            if (claimStatus.isNotEmpty)
                              Text('Reclamo: $claimStatus'),
                            const SizedBox(height: 10),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF7F4EF),
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Total cliente: ${isVes ? _formatVes(totalAmount) : '\$${totalAmount.toStringAsFixed(2)}'}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'A pagar al tecnico: ${isVes ? _formatVes(technicianAmount) : '\$${technicianAmount.toStringAsFixed(2)}'}',
                                    style: const TextStyle(
                                      color: Color(0xFF0F766E),
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: () => _releaseTechnicianPayment(
                                  context: context,
                                  orderId: doc.id,
                                  technicianId: technicianId,
                                  clientId: clientId,
                                  service: service,
                                ),
                                icon: const Icon(Icons.lock_open_outlined),
                                label: const Text('Autorizar pago al tecnico'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF16A34A),
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  const SizedBox(height: 14),
                  const Text(
                    'Solicitudes de pago recibidas',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 10),
                  StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: payoutRequestsStream,
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final requests = [...snapshot.data!.docs]
                        ..sort((a, b) {
                          final aTime = a.data()['requestedAt'] as Timestamp?;
                          final bTime = b.data()['requestedAt'] as Timestamp?;
                          return (bTime?.millisecondsSinceEpoch ?? 0)
                              .compareTo(aTime?.millisecondsSinceEpoch ?? 0);
                        });

                      final openRequests = requests.where((doc) {
                        final status = (doc.data()['status'] ?? '').toString();
                        return status == 'requested';
                      }).toList();

                      final totalPendingAmount = openRequests.fold<double>(
                        0,
                        (sum, doc) => sum +
                            ((doc.data()['totalAmount'] as num?)?.toDouble() ??
                                0),
                      );

                      if (openRequests.isEmpty) {
                        return const _EmptyOwnerCard(
                          text:
                              'No hay solicitudes de pago de tecnicos pendientes en este momento.',
                        );
                      }

                      return Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(22),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Solicitudes pendientes',
                                        style: TextStyle(
                                          color: Color(0xFF756B61),
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        openRequests.length.toString(),
                                        style: const TextStyle(
                                          fontSize: 28,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(22),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Total retenido',
                                        style: TextStyle(
                                          color: Color(0xFF756B61),
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        '\$${totalPendingAmount.toStringAsFixed(2)}',
                                        style: const TextStyle(
                                          fontSize: 28,
                                          fontWeight: FontWeight.w900,
                                          color: Color(0xFF0F766E),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          ...openRequests.map((doc) {
                          final data = doc.data();
                          final technicianId =
                              (data['technicianId'] ?? '').toString();
                          final technicianName =
                              (data['technicianName'] ?? 'Tecnico').toString();
                          final payoutName =
                              (data['payoutAccountName'] ?? '').toString();
                          final payoutPhone =
                              (data['payoutMobilePhone'] ?? '').toString();
                          final payoutBank =
                              (data['payoutBank'] ?? '').toString();
                          final payoutDocumentId =
                              (data['payoutDocumentId'] ?? '').toString();
                          final totalAmount =
                              (data['totalAmount'] as num?)?.toDouble() ?? 0;
                          final currency =
                              (data['currency'] ?? 'USD').toString();
                          final ordersCount =
                              (data['ordersCount'] as num?)?.toInt() ?? 0;
                          final orderIds = List<dynamic>.from(
                            data['orderIds'] ?? const [],
                          );
                          final requestedAt =
                              data['requestedAt'] as Timestamp?;
                          final amountLabel = currency == 'VES'
                              ? _formatVes(totalAmount)
                              : '\$${totalAmount.toStringAsFixed(2)}';
                          final missingPayoutData = payoutName.isEmpty ||
                              payoutPhone.isEmpty ||
                              payoutDocumentId.isEmpty ||
                              payoutBank.isEmpty;

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        technicianName,
                                        style: const TextStyle(
                                          fontSize: 17,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                    _OwnerPill(
                                      label: 'solicitado',
                                      color: const Color(0xFFFF7A00),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Monto retenido al tecnico: $amountLabel',
                                  style: const TextStyle(
                                    color: Color(0xFF0F766E),
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text('Trabajos incluidos: $ordersCount'),
                                const SizedBox(height: 4),
                                Text('Solicitado: ${_formatDate(requestedAt)}'),
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
                                      const SizedBox(height: 8),
                                      Text('Monto a pagar: $amountLabel'),
                                      Text('Titular: ${payoutName.isEmpty ? 'No indicado' : payoutName}'),
                                      Text('Pago movil: ${payoutPhone.isEmpty ? 'No indicado' : payoutPhone}'),
                                      Text('Cedula/RIF: ${payoutDocumentId.isEmpty ? 'No indicado' : payoutDocumentId}'),
                                      Text('Banco: ${payoutBank.isEmpty ? 'No indicado' : payoutBank}'),
                                      Text('ID tecnico: $technicianId'),
                                      if (missingPayoutData) ...[
                                        const SizedBox(height: 8),
                                        const Text(
                                          'Faltan datos de pago movil. Pidele al tecnico actualizar su perfil antes de pagar.',
                                          style: TextStyle(
                                            color: Color(0xFFB91C1C),
                                            fontWeight: FontWeight.w800,
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
                                      context: context,
                                      requestId: doc.id,
                                      technicianId: technicianId,
                                      technicianName: technicianName,
                                      payoutName: payoutName,
                                      payoutPhone: payoutPhone,
                                      payoutBank: payoutBank,
                                      payoutDocumentId: payoutDocumentId,
                                      orderIds: orderIds,
                                      totalAmount: totalAmount,
                                    ),
                                    icon: const Icon(Icons.check_circle_outline),
                                    label: const Text('Registrar pago al tecnico'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF0F766E),
                                      foregroundColor: Colors.white,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton.icon(
                                    onPressed: () => _openExternalUrl(
                                      'https://wa.me/${payoutPhone.replaceAll(RegExp(r'[^0-9]'), '')}',
                                    ),
                                    icon: const Icon(Icons.chat_outlined),
                                    label: const Text('Escribir al tecnico por WhatsApp'),
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
                if (_showClientPayments) ...[
                  const SizedBox(height: 18),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFF7C2D12),
                          Color(0xFFFF7A00),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Pagos moviles de clientes',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Aqui revisas las referencias, datos del pago movil, comprobantes y decides si aprobar o rechazar el pago.',
                          style: TextStyle(
                            color: Colors.white,
                            height: 1.4,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Devoluciones solicitadas',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 10),
                  StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: clientRefundRequestsStream,
                    builder: (context, refundSnapshot) {
                      if (!refundSnapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final refunds = [...refundSnapshot.data!.docs]
                        ..sort((a, b) {
                          final aTime = a.data()['createdAt'] as Timestamp?;
                          final bTime = b.data()['createdAt'] as Timestamp?;
                          return (bTime?.millisecondsSinceEpoch ?? 0)
                              .compareTo(aTime?.millisecondsSinceEpoch ?? 0);
                        });
                      final requestedRefunds = refunds
                          .where((doc) =>
                              (doc.data()['status'] ?? '').toString() ==
                              'requested')
                          .toList();

                      if (requestedRefunds.isEmpty) {
                        return const _EmptyOwnerCard(
                          text:
                              'No hay devoluciones de clientes pendientes por pago movil.',
                        );
                      }

                      return Column(
                        children: requestedRefunds.map((doc) {
                          final data = doc.data();
                          final clientName =
                              (data['clientName'] ?? 'Cliente').toString();
                          final service =
                              (data['service'] ?? 'Servicio').toString();
                          final amountUsd =
                              ((data['amountUsd'] ?? 0) as num?)?.toDouble() ??
                                  0;
                          final amountVes =
                              ((data['amountVes'] ?? 0) as num?)?.toDouble() ??
                                  0;
                          final bcvRate =
                              ((data['bcvRate'] ?? 0) as num?)?.toDouble() ??
                                  0;
                          final paymentName =
                              (data['paymentMobileName'] ?? '').toString();
                          final paymentPhone =
                              (data['paymentMobilePhone'] ?? '').toString();
                          final paymentBank =
                              (data['paymentMobileBank'] ?? '').toString();
                          final paymentIdentity =
                              (data['paymentMobileIdentity'] ?? '').toString();
                          final estimatedPaymentAt =
                              data['estimatedPaymentAt'] as Timestamp?;
                          final createdAt = data['createdAt'] as Timestamp?;

                          return Container(
                            width: double.infinity,
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: const Color(0xFFFFC4A3),
                              ),
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
                                          fontSize: 17,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ),
                                    _OwnerPill(
                                      label: _formatVes(amountVes),
                                      color: const Color(0xFFEA580C),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text('Cliente: $clientName'),
                                Text(
                                  'Monto base: \$${amountUsd.toStringAsFixed(2)} | BCV: ${bcvRate.toStringAsFixed(2)}',
                                ),
                                Text('Solicitado: ${_formatDate(createdAt)}'),
                                Text(
                                  'Pagar maximo: ${_formatDate(estimatedPaymentAt)}',
                                ),
                                const SizedBox(height: 10),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFF7ED),
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Datos para pago movil',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                      if (paymentName.isNotEmpty)
                                        Text('Titular: $paymentName'),
                                      if (paymentIdentity.isNotEmpty)
                                        Text('Cedula: $paymentIdentity'),
                                      if (paymentPhone.isNotEmpty)
                                        Text('Telefono: $paymentPhone'),
                                      if (paymentBank.isNotEmpty)
                                        Text('Banco: $paymentBank'),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      );
                    },
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Pagos por revisar',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Builder(
                    builder: (context) {
                      final paymentOrders = [...orders]
                        ..sort((a, b) {
                          final aTime =
                              (a.data()['paymentUploadedAt'] ??
                                      a.data()['createdAt'])
                                  as Timestamp?;
                          final bTime =
                              (b.data()['paymentUploadedAt'] ??
                                      b.data()['createdAt'])
                                  as Timestamp?;
                          return (bTime?.millisecondsSinceEpoch ?? 0)
                              .compareTo(aTime?.millisecondsSinceEpoch ?? 0);
                        });

                      final reviewPayments = paymentOrders.where((doc) {
                        final paymentStatus =
                            (doc.data()['paymentStatus'] ?? '').toString();
                        return paymentStatus == 'review' ||
                            paymentStatus == 'pending';
                      }).toList();

                      if (reviewPayments.isEmpty) {
                        return const _EmptyOwnerCard(
                          text:
                              'No tienes pagos moviles de clientes pendientes por revisar.',
                        );
                      }

                      return Column(
                        children: reviewPayments.map((doc) {
                          final data = doc.data();
                          final service =
                              (data['service'] ?? 'Servicio').toString();
                          final clientName =
                              (data['clientName'] ?? 'Cliente').toString();
                          final technicianName =
                              (data['technicianName'] ?? 'Tecnico').toString();
                          final clientId = (data['clientId'] ?? '').toString();
                          final technicianId =
                              (data['technicianId'] ?? '').toString();
                          final amount =
                              ((data['finalPriceBs'] ??
                                          data['paymentAmountBs'] ??
                                          data['finalPrice'] ??
                                          data['paymentAmount'] ??
                                          data['priceFrom'] ??
                                          0) as num?)
                                      ?.toDouble() ??
                                  0;
                          final amountUsd =
                              ((data['finalPriceUsd'] ??
                                          data['paymentAmountUsd'] ??
                                          data['finalPrice'] ??
                                          data['paymentAmount'] ??
                                          data['priceFrom'] ??
                                          0) as num?)
                                      ?.toDouble() ??
                                  0;
                          final bcvRate =
                              ((data['bcvRate'] ?? 0) as num?)?.toDouble() ??
                                  0;
                          final paymentMethod =
                              (data['paymentMethod'] ?? 'Pago movil')
                                  .toString();
                          final paymentReference =
                              (data['paymentReference'] ?? '').toString();
                          final payerName =
                              (data['payerName'] ?? '').toString();
                          final payerPhone =
                              (data['payerPhone'] ??
                                      data['paymentPhone'] ??
                                      '')
                                  .toString();
                          final payerDocument =
                              (data['payerDocument'] ?? '').toString();
                          final proofUrl =
                              (data['paymentProofUrl'] ?? '').toString();
                          final uploadedAt =
                              data['paymentUploadedAt'] as Timestamp?;
                          final retainUntil =
                              data['paymentRetainUntil'] as Timestamp?;
                          final reviewedAt =
                              data['paymentReviewedAt'] as Timestamp?;
                          final approvedAt =
                              data['paymentApprovedAt'] as Timestamp?;
                          final rejectedAt =
                              data['paymentRejectedAt'] as Timestamp?;

                          return Container(
                            width: double.infinity,
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: const Color(0xFFFFD6A3),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            service,
                                            style: const TextStyle(
                                              fontSize: 17,
                                              fontWeight: FontWeight.w900,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Cliente: $clientName',
                                            style: const TextStyle(
                                              color: Color(0xFF6D5E4F),
                                            ),
                                          ),
                                          Text(
                                            'Tecnico: $technicianName',
                                            style: const TextStyle(
                                              color: Color(0xFF6D5E4F),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    _OwnerPill(
                                      label: data['finalPriceBs'] != null ||
                                              data['paymentAmountBs'] != null
                                          ? _formatVes(amount)
                                          : '\$${amount.toStringAsFixed(2)}',
                                      color: const Color(0xFFFF7A00),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFF7ED),
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Datos del pago movil',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text('Metodo: $paymentMethod'),
                                      if (payerName.isNotEmpty)
                                        Text('Titular: $payerName'),
                                      if (payerPhone.isNotEmpty)
                                        Text('Pago movil: $payerPhone'),
                                      if (payerDocument.isNotEmpty)
                                        Text('Documento: $payerDocument'),
                                      if (paymentReference.isNotEmpty)
                                        Text('Referencia: $paymentReference'),
                                      Text(
                                        'Subido: ${_formatDate(uploadedAt)}',
                                      ),
                                      if (reviewedAt != null)
                                        Text(
                                          'Revisado: ${_formatDate(reviewedAt)}',
                                        ),
                                      if (approvedAt != null)
                                        Text(
                                          'Aprobado: ${_formatDate(approvedAt)}',
                                        ),
                                      if (rejectedAt != null)
                                        Text(
                                          'Rechazado: ${_formatDate(rejectedAt)}',
                                        ),
                                      Text(
                                        'Guardar hasta: ${_formatDate(retainUntil)}',
                                      ),
                                    ],
                                  ),
                                ),
                                if (proofUrl.isNotEmpty) ...[
                                  const SizedBox(height: 10),
                                  OutlinedButton.icon(
                                    onPressed: () => _openExternalUrl(proofUrl),
                                    icon: const Icon(Icons.open_in_new),
                                    label: const Text('Ver comprobante'),
                                  ),
                                ],
                                const SizedBox(height: 12),
                                SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton.icon(
                                    onPressed: amount <= 0
                                        ? null
                                        : () => _markClientPaymentIncomplete(
                                              context: context,
                                              orderId: doc.id,
                                              clientId: clientId,
                                              service: service,
                                              expectedAmountBs: amount,
                                              expectedAmountUsd: amountUsd,
                                              bcvRate: bcvRate,
                                            ),
                                    icon: const Icon(Icons.savings_outlined),
                                    label: const Text('Falta dinero / guardar abono'),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: const Color(0xFFEA580C),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: () => _reviewClientPayment(
                                          context: context,
                                          orderId: doc.id,
                                          clientId: clientId,
                                          technicianId: technicianId,
                                          service: service,
                                          paymentStatus: 'rejected',
                                        ),
                                        icon: const Icon(Icons.close_rounded),
                                        label: const Text('Rechazar'),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        onPressed: () => _reviewClientPayment(
                                          context: context,
                                          orderId: doc.id,
                                          clientId: clientId,
                                          technicianId: technicianId,
                                          service: service,
                                          paymentStatus: 'paid',
                                        ),
                                        icon: const Icon(
                                          Icons.check_circle_outline,
                                        ),
                                        label: const Text('Aprobar'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor:
                                              const Color(0xFF16A34A),
                                          foregroundColor: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      );
                    },
                  ),
                ],
                if (_showSubscriptions) ...[
                  const SizedBox(height: 18),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFFB45309),
                          Color(0xFFF59E0B),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Suscripciones de tecnicos',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Aqui revisas los pagos moviles enviados por los tecnicos para activar sus planes y darles prioridad dentro de Panafix.',
                          style: TextStyle(
                            color: Colors.white,
                            height: 1.4,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                ),
              ),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFFFFD6A3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Filtro rapido',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      decoration: const InputDecoration(
                        labelText: 'Buscar por nombre, referencia o plan',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (value) {
                        setState(() => subscriptionSearch = value);
                      },
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: technicianSubscriptionStatusFilter,
                            decoration: const InputDecoration(
                              labelText: 'Tecnicos',
                              border: OutlineInputBorder(),
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'Todos',
                                child: Text('Todos'),
                              ),
                              DropdownMenuItem(
                                value: 'Activos',
                                child: Text('Activos'),
                              ),
                              DropdownMenuItem(
                                value: 'Pendientes',
                                child: Text('Pendientes'),
                              ),
                              DropdownMenuItem(
                                value: 'Basico',
                                child: Text('Basico'),
                              ),
                            ],
                            onChanged: (value) {
                              if (value != null) {
                                setState(() {
                                  technicianSubscriptionStatusFilter = value;
                                });
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: subscriptionStatusFilter,
                            decoration: const InputDecoration(
                              labelText: 'Pagos',
                              border: OutlineInputBorder(),
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'pending_review',
                                child: Text('Pendientes'),
                              ),
                              DropdownMenuItem(
                                value: 'approved',
                                child: Text('Aprobados'),
                              ),
                              DropdownMenuItem(
                                value: 'rejected',
                                child: Text('Rechazados'),
                              ),
                              DropdownMenuItem(
                                value: 'all',
                                child: Text('Todos'),
                              ),
                            ],
                            onChanged: (value) {
                              if (value != null) {
                                setState(() {
                                  subscriptionStatusFilter = value;
                                });
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Activacion manual',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 10),
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: techniciansStream,
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final technicians = [...snapshot.data!.docs]
                    ..sort((a, b) {
                      final aName = (a.data()['name'] ?? '').toString();
                      final bName = (b.data()['name'] ?? '').toString();
                      return aName.compareTo(bName);
                    });
                  final filteredTechnicians = technicians.where((doc) {
                    return _matchesSubscriptionSearch(doc.data()) &&
                        _matchesTechnicianSubscriptionStatus(doc.data());
                  }).toList();

                  if (filteredTechnicians.isEmpty) {
                    return const _EmptyOwnerCard(
                      text:
                          'No hay tecnicos que coincidan con ese filtro de suscripcion.',
                    );
                  }

                  return Column(
                    children: filteredTechnicians.take(12).map((doc) {
                      final data = doc.data();
                      final technicianName =
                          (data['name'] ?? 'Tecnico').toString();
                      final currentPlan =
                          (data['subscriptionTitle'] ?? 'Basico').toString();

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    technicianName,
                                    style: const TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                _OwnerPill(
                                  label: currentPlan,
                                  color: const Color(0xFFB45309),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                OutlinedButton(
                                  onPressed: () => _setManualSubscription(
                                    context: context,
                                    technicianId: doc.id,
                                    technicianName: technicianName,
                                    planId: 'pro',
                                    title: 'Empresas',
                                    monthlyPrice: '\$10 / mes',
                                    priority: 1,
                                    durationDays: 30,
                                    benefits: const [
                                      'Mayor posicion en listados',
                                      'Insignia Empresas visible',
                                      'Mas prioridad para cuentas de negocio',
                                      'Mejor visibilidad comercial',
                                    ],
                                  ),
                                  child: const Text('Activar Empresas'),
                                ),
                                ElevatedButton(
                                  onPressed: () => _setManualSubscription(
                                    context: context,
                                    technicianId: doc.id,
                                    technicianName: technicianName,
                                    planId: 'premium',
                                    title: 'Premium',
                                    monthlyPrice: '\$20 / mes',
                                    priority: 2,
                                    durationDays: 30,
                                    benefits: const [
                                      'Prioridad maxima en resultados',
                                      'Insignia Premium visible',
                                      'Mas impulso en categorias y servicios',
                                      'Preferencia comercial frente a otros tecnicos',
                                    ],
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFB45309),
                                    foregroundColor: Colors.white,
                                  ),
                                  child: const Text('Activar Premium'),
                                ),
                                TextButton(
                                  onPressed: () => _setManualSubscription(
                                    context: context,
                                    technicianId: doc.id,
                                    technicianName: technicianName,
                                    planId: 'basic',
                                    title: 'Basico',
                                    monthlyPrice: '',
                                    priority: 0,
                                    durationDays: 0,
                                    benefits: const [],
                                  ),
                                  child: const Text('Quitar plan'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
              const SizedBox(height: 14),
              const Text(
                'Pagos de suscripcion pendientes',
                style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 10),
                  StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: subscriptionPaymentRequestsStream,
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final requests = [...snapshot.data!.docs]
                        ..sort((a, b) {
                          final aTime = a.data()['createdAt'] as Timestamp?;
                          final bTime = b.data()['createdAt'] as Timestamp?;
                          return (bTime?.millisecondsSinceEpoch ?? 0)
                              .compareTo(aTime?.millisecondsSinceEpoch ?? 0);
                        });

                      final pendingRequests = requests.where((doc) {
                        return (doc.data()['status'] ?? '').toString() ==
                            'pending_review';
                      }).toList();
                      final visibleRequests = requests.where((doc) {
                        final data = doc.data();
                        final status = (data['status'] ?? '').toString();
                        final matchesStatus =
                            subscriptionStatusFilter == 'all' ||
                                status == subscriptionStatusFilter;
                        return matchesStatus &&
                            _matchesSubscriptionSearch(data);
                      }).toList();

                      final monthlyTotal = pendingRequests.fold<double>(
                        0,
                        (sum, doc) {
                          final priceLabel =
                              (doc.data()['monthlyPrice'] ?? '').toString();
                          final value = double.tryParse(
                                priceLabel
                                    .replaceAll('\$', '')
                                    .replaceAll('/ mes', '')
                                    .trim(),
                              ) ??
                              0;
                          return sum + value;
                        },
                      );

                      if (visibleRequests.isEmpty) {
                        return const _EmptyOwnerCard(
                          text:
                              'No hay pagos de suscripcion que coincidan con ese filtro.',
                        );
                      }

                      return Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(22),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Solicitudes pendientes',
                                        style: TextStyle(
                                          color: Color(0xFF756B61),
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        pendingRequests.length.toString(),
                                        style: const TextStyle(
                                          fontSize: 28,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(22),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Monto mensual pendiente',
                                        style: TextStyle(
                                          color: Color(0xFF756B61),
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        '\$${monthlyTotal.toStringAsFixed(2)}',
                                        style: const TextStyle(
                                          fontSize: 28,
                                          fontWeight: FontWeight.w900,
                                          color: Color(0xFFB45309),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          ...visibleRequests.map((doc) {
                            final data = doc.data();
                            final status =
                                (data['status'] ?? '').toString();
                            final technicianId =
                                (data['technicianId'] ?? '').toString();
                            final planId = (data['planId'] ?? '').toString();
                            final planTitle =
                                (data['planTitle'] ?? 'Plan').toString();
                            final monthlyPrice =
                                (data['monthlyPrice'] ?? '').toString();
                            final payerName =
                                (data['payerName'] ?? '').toString();
                            final payerPhone =
                                (data['payerPhone'] ?? '').toString();
                            final payerDocument =
                                (data['payerDocument'] ?? '').toString();
                            final paymentReference =
                                (data['paymentReference'] ?? '').toString();
                            final paymentProofUrl =
                                (data['paymentProofUrl'] ?? '').toString();
                            final retainUntil =
                                data['paymentRetainUntil'] as Timestamp?;
                            final reviewedAt =
                                data['reviewedAt'] as Timestamp?;
                            final approvedAt =
                                data['approvedAt'] as Timestamp?;
                            final rejectedAt =
                                data['rejectedAt'] as Timestamp?;
                            final priority =
                                (data['priority'] as num?)?.toInt() ?? 0;
                            final durationDays =
                                (data['durationDays'] as num?)?.toInt() ?? 30;
                            final createdAt = data['createdAt'] as Timestamp?;
                            final benefits = List<dynamic>.from(
                              data['benefits'] ?? const [],
                            );

                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(18),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(24),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          planTitle,
                                          style: const TextStyle(
                                            fontSize: 17,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                      _OwnerPill(
                                        label: _subscriptionStatusLabel(status),
                                        color: const Color(0xFFB45309),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Monto del plan: $monthlyPrice',
                                    style: const TextStyle(
                                      color: Color(0xFFB45309),
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text('Referencia: $paymentReference'),
                                  const SizedBox(height: 4),
                                  Text('Enviado: ${_formatDate(createdAt)}'),
                                  if (reviewedAt != null) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      'Revisado: ${_formatDate(reviewedAt)}',
                                    ),
                                  ],
                                  if (approvedAt != null) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      'Aprobado: ${_formatDate(approvedAt)}',
                                    ),
                                  ],
                                  if (rejectedAt != null) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      'Rechazado: ${_formatDate(rejectedAt)}',
                                    ),
                                  ],
                                  const SizedBox(height: 4),
                                  Text(
                                    'Guardar hasta: ${_formatDate(retainUntil)}',
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
                                          'Datos del pago movil',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                        if (payerName.isNotEmpty) ...[
                                          const SizedBox(height: 6),
                                          Text('Titular: $payerName'),
                                        ],
                                        if (payerPhone.isNotEmpty) ...[
                                          const SizedBox(height: 4),
                                          Text('Pago movil: $payerPhone'),
                                        ],
                                        if (payerDocument.isNotEmpty) ...[
                                          const SizedBox(height: 4),
                                          Text('Documento: $payerDocument'),
                                        ],
                                        if (technicianId.isNotEmpty) ...[
                                          const SizedBox(height: 4),
                                          Text('Tecnico: $technicianId'),
                                        ],
                                      ],
                                    ),
                                  ),
                                  if (paymentProofUrl.isNotEmpty) ...[
                                    const SizedBox(height: 10),
                                    OutlinedButton.icon(
                                      onPressed: () =>
                                          _openExternalUrl(paymentProofUrl),
                                      icon: const Icon(
                                        Icons.receipt_long_outlined,
                                      ),
                                      label: const Text('Ver foto del pago'),
                                    ),
                                  ],
                                  const SizedBox(height: 12),
                                  if (status == 'pending_review')
                                    Row(
                                      children: [
                                        Expanded(
                                          child: OutlinedButton.icon(
                                            onPressed: () =>
                                                _rejectSubscriptionPayment(
                                              context: context,
                                              requestId: doc.id,
                                              technicianId: technicianId,
                                              planTitle: planTitle,
                                            ),
                                            icon:
                                                const Icon(Icons.close_rounded),
                                            label: const Text('Rechazar'),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: ElevatedButton.icon(
                                            onPressed: () =>
                                                _approveSubscriptionPayment(
                                              context: context,
                                              requestId: doc.id,
                                              technicianId: technicianId,
                                              planId: planId,
                                              planTitle: planTitle,
                                              monthlyPrice: monthlyPrice,
                                              priority: priority,
                                              durationDays: durationDays,
                                              benefits: benefits,
                                            ),
                                            icon: const Icon(
                                              Icons.workspace_premium_outlined,
                                            ),
                                            label: const Text('Aprobar'),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor:
                                                  const Color(0xFFB45309),
                                              foregroundColor: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ],
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
                if (_showEmergencies) ...[
                  const SizedBox(height: 18),
                  const Text(
                    'Problemas y emergencias',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 10),
                  StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: emergenciesStream,
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final reports = [...snapshot.data!.docs]
                        ..sort((a, b) {
                          final aTime = a.data()['createdAt'] as Timestamp?;
                          final bTime = b.data()['createdAt'] as Timestamp?;
                          return (bTime?.millisecondsSinceEpoch ?? 0)
                              .compareTo(aTime?.millisecondsSinceEpoch ?? 0);
                        });

                      if (reports.isEmpty) {
                        return const _EmptyOwnerCard(
                          text: 'No hay emergencias registradas.',
                        );
                      }

                      return Column(
                        children: reports.take(8).map((doc) {
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
                                    Expanded(
                                      child: Text(
                                        service,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 17,
                                        ),
                                      ),
                                    ),
                                    _OwnerPill(
                                      label: resolved ? 'resuelto' : 'urgente',
                                      color: resolved
                                          ? const Color(0xFF0F766E)
                                          : const Color(0xFFB91C1C),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text('Tecnico: $technicianName'),
                                const SizedBox(height: 4),
                                Text('Estado del servicio: $status'),
                                const SizedBox(height: 10),
                                if (!resolved)
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: TextButton(
                                      onPressed: () => _resolveEmergency(doc.id),
                                      child: const Text('Marcar resuelto'),
                                    ),
                                  ),
                              ],
                            ),
                          );
                        }).toList(),
                      );
                    },
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _OwnerMetric extends StatelessWidget {
  final String label;
  final String value;

  const _OwnerMetric({
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
            label,
            style: const TextStyle(
              color: Color(0xFFFDE2E2),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _OwnerTab extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _OwnerTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFFEE2E2) : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? const Color(0xFFFCA5A5) : const Color(0xFFE5E7EB),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? const Color(0xFF991B1B) : const Color(0xFF3B3129),
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _OwnerPill extends StatelessWidget {
  final String label;
  final Color color;

  const _OwnerPill({
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _FinancialOwnerCard extends StatelessWidget {
  final String title;
  final String value;
  final Color color;

  const _FinancialOwnerCard({
    required this.title,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 170,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: color.withOpacity(0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF6D5E4F),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _UrgentOwnerCard extends StatelessWidget {
  final String title;
  final String value;
  final Color color;

  const _UrgentOwnerCard({
    required this.title,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 170,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: color.withOpacity(0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyOwnerCard extends StatelessWidget {
  final String text;

  const _EmptyOwnerCard({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFF6D5E4F),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
