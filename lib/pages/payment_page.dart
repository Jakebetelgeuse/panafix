import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/payment_service.dart';
import '../services/owner_alert_service.dart';
import '../services/bcv_rate_service.dart';

class PaymentPage extends StatefulWidget {
  final String orderId;
  final Map<String, dynamic> orderData;
  final double amount;

  const PaymentPage({
    super.key,
    required this.orderId,
    required this.orderData,
    required this.amount,
  });

  @override
  State<PaymentPage> createState() => _PaymentPageState();
}

class _PaymentPageState extends State<PaymentPage> {
  final PaymentService _paymentService = PaymentService();
  final TextEditingController referenceController = TextEditingController();
  final TextEditingController payerNameController = TextEditingController();
  final TextEditingController payerPhoneController = TextEditingController();
  final TextEditingController payerIdController = TextEditingController();

  bool isLoading = false;
  String paymentMethod = 'Pago Movil';
  String? uploadedProofUrl;
  BcvRate? bcvRate;
  double walletBalanceUsd = 0;

  Future<void> createNotification({
    required String userId,
    required String title,
    required String message,
    required String type,
  }) async {
    await FirebaseFirestore.instance.collection('notifications').add({
      'userId': userId,
      'title': title,
      'message': message,
      'type': type,
      'isRead': false,
      'orderId': widget.orderId,
      'createdAt': FieldValue.serverTimestamp(),
      'expiresAt': Timestamp.fromDate(
        DateTime.now().add(const Duration(days: 30)),
      ),
    });
  }

  @override
  void initState() {
    super.initState();
    _loadSavedPaymentData();
    _loadBcvRate();
    paymentMethod = (widget.orderData['paymentMethod']?.toString().isNotEmpty ??
            false)
        ? widget.orderData['paymentMethod'].toString()
        : 'Pago Movil';
    uploadedProofUrl = widget.orderData['paymentProofUrl']?.toString().isNotEmpty ==
            true
        ? widget.orderData['paymentProofUrl']?.toString()
        : null;
  }

  Future<void> _loadBcvRate() async {
    final rate = await BcvRateService.getRate();
    if (!mounted) return;
    setState(() {
      bcvRate = rate;
    });
  }

  Future<void> _loadSavedPaymentData() async {
    paymentMethod = (widget.orderData['paymentMethod']?.toString().isNotEmpty ??
            false)
        ? widget.orderData['paymentMethod'].toString()
        : 'Pago Movil';
    referenceController.text =
        widget.orderData['paymentReference']?.toString() ?? '';
    payerNameController.text = widget.orderData['payerName']?.toString() ?? '';
    payerPhoneController.text =
        widget.orderData['payerPhone']?.toString() ?? '';
    payerIdController.text =
        widget.orderData['payerDocument']?.toString() ?? '';

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();
      final userData = userDoc.data() ?? {};

      if (payerNameController.text.isEmpty) {
        payerNameController.text =
            userData['lastPayerName']?.toString() ?? '';
      }
      if (payerPhoneController.text.isEmpty) {
        payerPhoneController.text =
            userData['lastPayerPhone']?.toString() ?? '';
      }
      if (payerIdController.text.isEmpty) {
        payerIdController.text =
            userData['lastPayerDocument']?.toString() ?? '';
      }
      if (referenceController.text.isEmpty) {
        referenceController.text =
            userData['lastPaymentReference']?.toString() ?? '';
      }

      walletBalanceUsd =
          ((userData['appWalletBalanceUsd'] ??
                      userData['appWalletBalance'] ??
                      0) as num?)
                  ?.toDouble() ??
              0;

      final savedMethod = userData['lastPaymentMethod']?.toString() ?? '';
      if ((widget.orderData['paymentMethod']?.toString().isEmpty ?? true) &&
          savedMethod.isNotEmpty) {
        paymentMethod = savedMethod;
      }

      if (mounted) {
        setState(() {});
      }
    } catch (_) {
      // Do not block payment flow if reading the saved payment profile fails.
    }
  }

  double _walletAppliedUsdFor(double amountUsd) {
    if (amountUsd <= 0 || walletBalanceUsd <= 0) return 0;
    return walletBalanceUsd >= amountUsd ? amountUsd : walletBalanceUsd;
  }

  double _walletAppliedBsFor(double amountUsd, BcvRate? rate) {
    final appliedUsd = _walletAppliedUsdFor(amountUsd);
    if (appliedUsd <= 0 || rate?.isAvailable != true) return 0;
    return rate!.usdToVes(appliedUsd);
  }

  double _cashDueFor(double amountBs) {
    final walletAppliedBs = _walletAppliedBsFor(widget.amount, bcvRate);
    final due = amountBs - walletAppliedBs;
    return due <= 0 ? 0 : double.parse(due.toStringAsFixed(2));
  }

  @override
  void dispose() {
    referenceController.dispose();
    payerNameController.dispose();
    payerPhoneController.dispose();
    payerIdController.dispose();
    super.dispose();
  }

  Future<void> uploadProof() async {
    try {
      setState(() => isLoading = true);

      final url = await _paymentService.pickAndUploadProof(widget.orderId);

      if (url == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No seleccionaste ningun comprobante')),
        );
        return;
      }

      setState(() {
        uploadedProofUrl = url;
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Comprobante subido correctamente')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al subir comprobante: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  Future<void> submitPayment() async {
    final reference = referenceController.text.trim();
    final payerName = payerNameController.text.trim();
    final payerPhone = payerPhoneController.text.trim();
    final payerId = payerIdController.text.trim();
    final rate = bcvRate ?? await BcvRateService.getRate();
    if (!rate.isAvailable) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No hay tasa BCV guardada. Panafix debe configurar la tasa antes de recibir pagos.',
          ),
        ),
      );
      return;
    }

    final fullAmountBs = rate.usdToVes(widget.amount);
    final walletAppliedUsd = _walletAppliedUsdFor(widget.amount);
    final walletAppliedBs = rate.usdToVes(walletAppliedUsd);
    final cashDueBs = _cashDueFor(fullAmountBs);
    final isWalletOnlyPayment = cashDueBs <= 0;

    if (!isWalletOnlyPayment && payerName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresa el nombre del titular del pago')),
      );
      return;
    }

    if (!isWalletOnlyPayment && payerPhone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresa el telefono del pago movil')),
      );
      return;
    }

    if (!isWalletOnlyPayment && payerId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresa la cedula o documento')),
      );
      return;
    }

    if (!isWalletOnlyPayment && reference.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresa la referencia del pago')),
      );
      return;
    }

    if (!isWalletOnlyPayment && uploadedProofUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Debes subir el comprobante')),
      );
      return;
    }

    try {
      final retainUntil = DateTime.now().add(const Duration(days: 14));
      final amountBs = cashDueBs;
      final isBalancePayment =
          widget.orderData['paymentStatus']?.toString() == 'partial_payment';
      final originalFinalUsd =
          ((widget.orderData['finalPriceUsd'] ??
                      widget.orderData['finalPrice'] ??
                      widget.amount) as num?)
                  ?.toDouble() ??
              widget.amount;
      final originalFinalBs =
          ((widget.orderData['finalPriceBs'] ?? 0) as num?)?.toDouble();
      final baseUsd =
          ((widget.orderData['basePriceUsd'] ??
                      widget.orderData['basePrice'] ??
                      widget.amount) as num?)
                  ?.toDouble() ??
              widget.amount;
      final commissionUsd =
          ((widget.orderData['appCommissionUsd'] ??
                      widget.orderData['appCommission'] ??
                      0) as num?)
                  ?.toDouble() ??
              0;
      final technicianEarningUsd =
          ((widget.orderData['technicianEarningUsd'] ??
                      widget.orderData['technicianEarning'] ??
                      baseUsd) as num?)
                  ?.toDouble() ??
              baseUsd;
      final baseBs = rate.isAvailable ? rate.usdToVes(baseUsd) : 0.0;
      final commissionBs =
          rate.isAvailable ? rate.usdToVes(commissionUsd) : 0.0;
      final technicianEarningBs =
          rate.isAvailable ? rate.usdToVes(technicianEarningUsd) : 0.0;

      setState(() => isLoading = true);

      final currentUser = FirebaseAuth.instance.currentUser;
      final batch = FirebaseFirestore.instance.batch();
      final orderRef =
          FirebaseFirestore.instance.collection('orders').doc(widget.orderId);

      batch.set(orderRef, {
        ...widget.orderData,
        'status': 'pending',
        'paymentStatus': isWalletOnlyPayment ? 'paid' : 'review',
        'releaseStatus': 'pending',
        'paymentMethod': isWalletOnlyPayment ? 'Saldo Panafix' : paymentMethod,
        'paymentReference': isWalletOnlyPayment ? 'wallet' : reference,
        if (!isWalletOnlyPayment) 'paymentProofUrl': uploadedProofUrl!,
        'paymentAmount': isWalletOnlyPayment ? 0 : widget.amount,
        'paymentAmountUsd': isWalletOnlyPayment ? 0 : widget.amount,
        'paymentAmountBs': amountBs,
        'walletAppliedUsd': walletAppliedUsd,
        'walletAppliedBs': walletAppliedBs,
        'walletAppliedBcvRate': rate.rate,
        'walletAppliedAt': walletAppliedBs > 0 ? FieldValue.serverTimestamp() : null,
        'walletPaymentCoveredFull': isWalletOnlyPayment,
        if (isBalancePayment) 'balancePaymentAmountUsd': widget.amount,
        if (isBalancePayment) 'balancePaymentAmountBs': amountBs,
        if (isBalancePayment) 'balancePaymentReference': reference,
        if (isBalancePayment)
          'partialPaymentStatus':
              isWalletOnlyPayment ? 'covered_by_wallet' : 'top_up_review',
        if (!isWalletOnlyPayment) 'payerName': payerName,
        if (!isWalletOnlyPayment) 'payerPhone': payerPhone,
        if (!isWalletOnlyPayment) 'payerDocument': payerId,
        'paymentUploadedAt': FieldValue.serverTimestamp(),
        'paymentRetainUntil': Timestamp.fromDate(retainUntil),
        'paymentRetentionDays': 14,
        'finalPrice': isBalancePayment ? originalFinalUsd : widget.amount,
        'finalPriceUsd': isBalancePayment ? originalFinalUsd : widget.amount,
        'finalPriceBs':
            isBalancePayment ? (originalFinalBs ?? amountBs) : amountBs,
        'basePriceUsd': baseUsd,
        'basePriceBs': baseBs,
        'appCommissionUsd': commissionUsd,
        'appCommissionBs': commissionBs,
        'technicianEarningUsd': technicianEarningUsd,
        'technicianEarningBs': technicianEarningBs,
        'priceFrom': widget.amount,
        'currency': rate.isAvailable ? 'VES' : 'USD',
        'currencyBase': 'USD',
        'bcvRate': rate.rate,
        'bcvRateSource': rate.source,
        'bcvRateDate': rate.rateDate,
        'bcvRateLockedAt': FieldValue.serverTimestamp(),
        'bcvRateSyncedOnline': rate.fromInternet,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (currentUser != null) {
        batch.set(FirebaseFirestore.instance.collection('users').doc(currentUser.uid), {
          if (!isWalletOnlyPayment) 'lastPaymentMethod': paymentMethod,
          if (!isWalletOnlyPayment) 'lastPaymentReference': reference,
          if (!isWalletOnlyPayment) 'lastPayerName': payerName,
          if (!isWalletOnlyPayment) 'lastPayerPhone': payerPhone,
          if (!isWalletOnlyPayment) 'lastPayerDocument': payerId,
          if (walletAppliedBs > 0)
            'appWalletBalanceUsd': FieldValue.increment(-walletAppliedUsd),
          if (walletAppliedBs > 0) 'appWalletLastReferenceBs': cashDueBs,
          if (walletAppliedBs > 0)
            'appWalletUpdatedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        if (walletAppliedBs > 0) {
          batch.set(
            FirebaseFirestore.instance
                .collection('client_wallet_transactions')
                .doc(),
            {
              'clientId': currentUser.uid,
              'orderId': widget.orderId,
              'type': 'debit',
              'reason': 'service_payment',
              'amountBs': walletAppliedBs,
              'amountUsd': walletAppliedUsd,
              'bcvRate': rate.rate,
              'currencyBase': 'USD_BCV',
              'service': (widget.orderData['service'] ??
                      widget.orderData['serviceName'] ??
                      'Servicio')
                  .toString(),
              'createdAt': FieldValue.serverTimestamp(),
            },
          );
        }
      }

      await batch.commit();

      final technicianId = widget.orderData['technicianId']?.toString() ?? '';
      final serviceName =
          (widget.orderData['service'] ?? widget.orderData['serviceName'] ?? 'Servicio')
              .toString();

      if (technicianId.isNotEmpty) {
        await createNotification(
          userId: technicianId,
          title: isWalletOnlyPayment ? 'Pago aprobado' : 'Pago enviado',
          message: isWalletOnlyPayment
              ? 'El cliente pago "$serviceName" con saldo Panafix.'
              : 'El cliente envio el pago de "$serviceName". Queda pendiente por aprobacion.',
          type: 'payment',
        );
      }

      final clientId = widget.orderData['clientId']?.toString() ?? '';
      if (clientId.isNotEmpty) {
        await createNotification(
          userId: clientId,
          title: isWalletOnlyPayment ? 'Pago con saldo aplicado' : 'Pago en revision',
          message: isWalletOnlyPayment
              ? 'Usaste Bs ${walletAppliedBs.toStringAsFixed(2)} de tu saldo Panafix para "$serviceName".'
              : 'Tu pago del servicio "$serviceName" fue enviado y esta en revision.',
          type: 'payment',
        );
      }

      if (!isWalletOnlyPayment) {
        await OwnerAlertService.createAlert(
          title: 'Pago por revisar',
          message:
              'Se subio un comprobante para "$serviceName" y requiere revision.',
          type: 'payment',
          orderId: widget.orderId,
          priority: 'high',
        );
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isWalletOnlyPayment
                ? 'Pago aplicado con tu saldo Panafix.'
                : 'Pago enviado correctamente. Ahora queda en revision.',
          ),
        ),
      );

      Navigator.popUntil(context, (route) => route.isFirst);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al registrar el pago: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  Widget _sectionCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _infoTile({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7F7),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: Colors.orange.withValues(alpha: 0.12),
            child: Icon(icon, color: Colors.orange),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.black54,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          filled: true,
          fillColor: const Color(0xFFF7F7F7),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final amountText = widget.amount.toStringAsFixed(2);
    final rate = bcvRate;
    final amountBs = rate?.isAvailable == true ? rate!.usdToVes(widget.amount) : 0;
    final walletAppliedUsd = _walletAppliedUsdFor(widget.amount);
    final walletAppliedBs = _walletAppliedBsFor(widget.amount, rate);
    final cashDueBs = _cashDueFor(amountBs.toDouble());
    final isWalletOnlyPayment = rate?.isAvailable == true && cashDueBs <= 0;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      appBar: AppBar(
        title: const Text('Pagar servicio'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _sectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Resumen del pago',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFF8C1A), Color(0xFFFFA94D)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Monto a pagar',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          amountBs > 0
                              ? 'Bs ${cashDueBs.toStringAsFixed(2)}'
                              : '\$$amountText',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 30,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          amountBs > 0
                              ? walletAppliedBs > 0
                                  ? 'Total Bs ${amountBs.toStringAsFixed(2)} - saldo Bs ${walletAppliedBs.toStringAsFixed(2)} | BCV ${rate!.rate.toStringAsFixed(4)}'
                                  : 'Referencia: \$$amountText | BCV ${rate!.rate.toStringAsFixed(4)}'
                              : 'Configura la tasa BCV para cobrar en bolivares.',
                          style: const TextStyle(
                            color: Color(0xFFFFE7CC),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (walletBalanceUsd > 0 && amountBs > 0) ...[
              _sectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Saldo Panafix',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                      Text(
                      'Tienes \$${walletBalanceUsd.toStringAsFixed(2)} anclados al BCV. Hoy equivalen a Bs ${rate!.usdToVes(walletBalanceUsd).toStringAsFixed(2)} y se aplican Bs ${walletAppliedBs.toStringAsFixed(2)} (\$${walletAppliedUsd.toStringAsFixed(2)}) a este pago.',
                      style: const TextStyle(
                        color: Colors.black54,
                        height: 1.4,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (isWalletOnlyPayment) ...[
                      const SizedBox(height: 8),
                      const Text(
                        'Tu saldo cubre todo el servicio. No necesitas subir comprobante.',
                        style: TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            _sectionCard(
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Proteccion BCV',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'El servicio esta referenciado en USD, pero se paga en bolivares a la tasa BCV guardada al momento del pago. Cuando Panafix aprueba el comprobante, la tasa y el monto quedan congelados.',
                    style: TextStyle(
                      color: Colors.black54,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (!isWalletOnlyPayment)
              _sectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Datos para pagar',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _infoTile(
                    icon: Icons.account_balance,
                    title: 'Banco',
                    value: 'Banesco',
                  ),
                  _infoTile(
                    icon: Icons.phone_android,
                    title: 'Pago Movil',
                    value: '0412-123-45-67',
                  ),
                  _infoTile(
                    icon: Icons.badge_outlined,
                    title: 'Cedula / RIF',
                    value: 'V-12345678',
                  ),
                  _infoTile(
                    icon: Icons.person_outline,
                    title: 'Beneficiario',
                    value: 'Panafix',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _sectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Confirma tu pago',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    initialValue: paymentMethod,
                    decoration: InputDecoration(
                      labelText: 'Metodo de pago',
                      filled: true,
                      fillColor: const Color(0xFFF7F7F7),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'Pago Movil',
                        child: Text('Pago Movil'),
                      ),
                      DropdownMenuItem(
                        value: 'Transferencia',
                        child: Text('Transferencia'),
                      ),
                      DropdownMenuItem(
                        value: 'Zelle',
                        child: Text('Zelle'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => paymentMethod = value);
                      }
                    },
                  ),
                  const SizedBox(height: 14),
                  _buildTextField(
                    controller: payerNameController,
                    label: 'Nombre del titular',
                    hint: 'Ej: Maria Perez',
                  ),
                  _buildTextField(
                    controller: payerPhoneController,
                    label: 'Telefono del pago movil',
                    hint: 'Ej: 04121234567',
                    keyboardType: TextInputType.phone,
                  ),
                  _buildTextField(
                    controller: payerIdController,
                    label: 'Cedula o documento',
                    hint: 'Ej: V12345678',
                  ),
                  _buildTextField(
                    controller: referenceController,
                    label: 'Referencia del pago',
                    hint: 'Ej: 123456',
                    keyboardType: TextInputType.number,
                  ),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: uploadedProofUrl == null
                          ? const Color(0xFFF7F7F7)
                          : Colors.green.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: uploadedProofUrl == null
                            ? Colors.black12
                            : Colors.green.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          uploadedProofUrl == null
                              ? Icons.upload_file_outlined
                              : Icons.check_circle,
                          color: uploadedProofUrl == null
                              ? Colors.black54
                              : Colors.green,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            uploadedProofUrl == null
                                ? 'Aun no has subido tu comprobante'
                                : 'Comprobante cargado correctamente',
                            style: TextStyle(
                              color: uploadedProofUrl == null
                                  ? Colors.black87
                                  : Colors.green.shade700,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: isLoading ? null : uploadProof,
                      icon: const Icon(Icons.attach_file),
                      label: Text(
                        uploadedProofUrl == null
                            ? 'Subir comprobante'
                            : 'Cambiar comprobante',
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        side: BorderSide(
                          color: Colors.orange.withValues(alpha: 0.4),
                        ),
                        foregroundColor: Colors.orange,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isLoading ? null : submitPayment,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 17),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                child: isLoading
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.4,
                        ),
                      )
                    : Text(
                        isWalletOnlyPayment ? 'Pagar con saldo Panafix' : 'Enviar pago',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Tu pago quedara retenido hasta que confirmes la liberacion del servicio.',
              style: TextStyle(
                color: Colors.black54,
                fontSize: 13,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
