import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'auth_service.dart';
import 'notifications_page.dart';
import 'process_guide_page.dart';
import 'support_center_page.dart';
import 'subscription_plans_page.dart';
import 'technician_my_jobs_page.dart';
import 'technician_requests_page.dart';
import 'technician_services_page.dart';

class TechnicianHomePage extends StatefulWidget {
  const TechnicianHomePage({super.key});

  @override
  State<TechnicianHomePage> createState() => _TechnicianHomePageState();
}

class _TechnicianHomePageState extends State<TechnicianHomePage> {
  static const String _supportPhone = '+13854637334';
  final User? user = FirebaseAuth.instance.currentUser;
  final TextEditingController nameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController bioController = TextEditingController();
  final TextEditingController payoutNameController = TextEditingController();
  final TextEditingController payoutPhoneController = TextEditingController();
  final TextEditingController payoutIdController = TextEditingController();
  final TextEditingController payoutBankController = TextEditingController();

  bool isLoading = true;
  bool isSaving = false;
  bool profileCompleted = false;
  bool isAvailable = true;

  int selectedTab = 0;
  double currentRating = 5.0;
  int reviewsCount = 0;

  String? selectedCity;
  String? profilePhotoUrl;
  String verificationStatus = 'not_submitted';
  String? idDocumentUrl;
  String? credentialDocumentUrl;
  String workStart = '08:00';
  String workEnd = '18:00';
  double yearsExperience = 1;
  double serviceRadius = 10;
  String subscriptionPlan = 'basic';
  String subscriptionStatus = 'inactive';
  Timestamp? subscriptionEndsAt;

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

  final List<String> allCategories = const [
    'Electricidad',
    'Fontaneria',
    'Cerrajeria',
    'Internet/TV',
    'Electrodomesticos',
    'Albanileria',
    'Pintura',
    'Carpinteria',
    'Limpieza',
  ];

  final List<String> weekDays = const [
    'Lun',
    'Mar',
    'Mie',
    'Jue',
    'Vie',
    'Sab',
    'Dom',
  ];

  final Map<String, List<String>> servicesByCategory = const {
    'Electricidad': [
      'Revision electrica',
      'Instalacion de lamparas',
      'Tomacorrientes',
      'Corto circuito',
      'Cableado',
    ],
    'Fontaneria': [
      'Destapar tuberias',
      'Reparacion de fugas',
      'Instalacion de grifos',
      'Revision de bano',
      'Tuberias',
    ],
    'Cerrajeria': [
      'Abrir puerta',
      'Cambio de cerradura',
      'Duplicado de llaves',
      'Revision de cerradura',
    ],
    'Internet/TV': [
      'Instalacion de router',
      'Problemas de internet',
      'Configuracion WiFi',
      'Instalacion de TV',
    ],
    'Electrodomesticos': [
      'Reparacion de nevera',
      'Reparacion de lavadora',
      'Reparacion de cocina',
      'Mantenimiento',
    ],
    'Albanileria': [
      'Frisado de pared',
      'Pegar ceramica',
      'Reparacion de pared',
      'Trabajos de cemento',
      'Acabados',
    ],
    'Pintura': [
      'Pintura interior',
      'Pintura exterior',
      'Impermeabilizacion',
      'Acabados decorativos',
      'Retoques',
    ],
    'Carpinteria': [
      'Reparacion de puertas',
      'Closets',
      'Muebles a medida',
      'Reparacion de muebles',
      'Instalacion de repisas',
    ],
    'Limpieza': [
      'Limpieza de hogar',
      'Limpieza profunda',
      'Limpieza de oficina',
      'Limpieza post obra',
      'Limpieza de tapiceria',
    ],
  };

  List<String> selectedCategories = [];
  List<String> selectedServices = [];
  List<String> availableDays = ['Lun', 'Mar', 'Mie', 'Jue', 'Vie', 'Sab'];

  String normalizeCategory(String value) {
    final normalized = value
        .toLowerCase()
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u');

    if (normalized.contains('fontan')) return 'Fontaneria';
    if (normalized.contains('cerraj')) return 'Cerrajeria';
    if (normalized.contains('electrodom')) return 'Electrodomesticos';
    if (normalized.contains('albanil')) return 'Albanileria';
    if (normalized.contains('pintur')) return 'Pintura';
    if (normalized.contains('carpint')) return 'Carpinteria';
    if (normalized.contains('limp')) return 'Limpieza';
    return value;
  }

  String normalizeService(String value) {
    return value
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('Á', 'A')
        .replaceAll('É', 'E')
        .replaceAll('Í', 'I')
        .replaceAll('Ó', 'O')
        .replaceAll('Ú', 'U')
        .replaceAll('ñ', 'n')
        .replaceAll('Ñ', 'N');
  }

  @override
  void initState() {
    super.initState();
    loadTechnicianData();
  }

  Future<void> _expireSubscriptionIfNeeded(Map<String, dynamic> data) async {
    if (user == null) return;

    final status = data['subscriptionStatus']?.toString() ?? 'inactive';
    final promotedUntil = data['promotedUntil'] as Timestamp?;

    if (status == 'active' &&
        promotedUntil != null &&
        promotedUntil.toDate().isBefore(DateTime.now())) {
      await FirebaseFirestore.instance.collection('users').doc(user!.uid).set({
        'subscriptionPlan': 'basic',
        'subscriptionTitle': 'Basico',
        'subscriptionPriceLabel': '',
        'subscriptionStatus': 'inactive',
        'subscriptionPriority': 0,
        'subscriptionBenefits': [],
        'promotedUntil': null,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
  }

  String _formatSubscriptionDate(Timestamp? value) {
    if (value == null) return 'Sin vencimiento activo';

    final date = value.toDate().toLocal();
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  String _subscriptionCountdownText() {
    if (subscriptionStatus != 'active' || subscriptionEndsAt == null) {
      return 'Tu cuenta esta en modo basico.';
    }

    final now = DateTime.now();
    final difference = subscriptionEndsAt!.toDate().difference(now);

    if (difference.isNegative) {
      return 'Tu plan ya vencio y volvera a modo basico.';
    }

    if (difference.inDays >= 1) {
      return 'Te quedan ${difference.inDays + 1} dias de visibilidad prioritaria.';
    }

    final hours = difference.inHours.clamp(0, 23);
    return 'Tu plan vence hoy en ${hours + 1} horas aproximadamente.';
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

  bool _isPayoutRequestWindowOpen() {
    final now = DateTime.now();
    final isWeekday =
        now.weekday >= DateTime.monday && now.weekday <= DateTime.friday;
    final isBusinessHour = now.hour >= 10 && now.hour < 16;
    return isWeekday && isBusinessHour;
  }

  String _payoutRequestScheduleText() {
    return 'Las solicitudes de pago se habilitan de lunes a viernes, de 10:00 a.m. a 4:00 p.m.';
  }

  double _technicianPayoutAmount(Map<String, dynamic> data) {
    return ((data['technicianEarningBs'] ??
                data['basePriceBs'] ??
                data['technicianEarning'] ??
                data['basePrice'] ??
                data['finalPrice'] ??
                data['priceFrom'] ??
                0)
            as num)
        .toDouble();
  }

  String _moneyLabel(double amount, Map<String, dynamic>? sampleData) {
    final hasVes = sampleData != null &&
        (sampleData['technicianEarningBs'] != null ||
            sampleData['basePriceBs'] != null);
    return hasVes
        ? 'Bs ${amount.toStringAsFixed(2)}'
        : '\$${amount.toStringAsFixed(2)}';
  }

  Future<void> _requestTechnicianPayout({
    required double totalAmount,
    required int ordersCount,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> orders,
  }) async {
    if (user == null) return;

    if (!_isPayoutRequestWindowOpen()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_payoutRequestScheduleText())),
      );
      return;
    }

    final payoutName = payoutNameController.text.trim();
    final payoutPhone = payoutPhoneController.text.trim();
    final payoutId = payoutIdController.text.trim();
    final payoutBank = payoutBankController.text.trim();

    if (payoutName.isEmpty ||
        payoutPhone.isEmpty ||
        payoutId.isEmpty ||
        payoutBank.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Completa tus datos de pago movil antes de solicitar el pago.',
          ),
        ),
      );
      return;
    }

    final technicianName = nameController.text.trim().isEmpty
        ? 'Tecnico'
        : nameController.text.trim();

    final requestRef = FirebaseFirestore.instance
        .collection('technician_payout_requests')
        .doc(user!.uid);

    await requestRef.set({
      'technicianId': user!.uid,
      'technicianName': technicianName,
      'status': 'requested',
      'totalAmount': totalAmount,
      'currency': orders.isNotEmpty &&
              (orders.first.data()['technicianEarningBs'] != null ||
                  orders.first.data()['basePriceBs'] != null)
          ? 'VES'
          : 'USD',
      'ordersCount': ordersCount,
      'orderIds': orders.map((order) => order.id).toList(),
      'payoutAccountName': payoutName,
      'payoutMobilePhone': payoutPhone,
      'payoutDocumentId': payoutId,
      'payoutBank': payoutBank,
      'requestedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await FirebaseFirestore.instance.collection('owner_alerts').add({
      'title': 'Solicitud de pago tecnico',
      'message':
          '$technicianName solicito el pago retenido de ${_moneyLabel(totalAmount, orders.isNotEmpty ? orders.first.data() : null)}.',
      'type': 'payment',
      'orderId': orders.isNotEmpty ? orders.first.id : '',
      'priority': 'high',
      'isRead': false,
      'createdAt': FieldValue.serverTimestamp(),
      'expiresAt': Timestamp.fromDate(
        DateTime.now().add(const Duration(days: 60)),
      ),
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Solicitud de pago enviada a Panafix.'),
      ),
    );
  }

  Widget buildPayoutSummary() {
    if (user == null) return const SizedBox();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('orders')
          .where('technicianId', isEqualTo: user!.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Center(child: CircularProgressIndicator()),
          );
        }

        final docs = snapshot.data!.docs;
        final releasableOrders = docs.where((doc) {
          final data = doc.data();
          final paymentStatus = (data['paymentStatus'] ?? '').toString();
          final payoutStatus = (data['payoutStatus'] ?? '').toString();
          return paymentStatus == 'released' && payoutStatus != 'paid_out';
        }).toList();

        final waitingReleaseOrders = docs.where((doc) {
          final data = doc.data();
          final status = (data['status'] ?? '').toString();
          final paymentStatus = (data['paymentStatus'] ?? '').toString();
          final payoutStatus = (data['payoutStatus'] ?? '').toString();
          return status == 'completed' &&
              paymentStatus == 'paid' &&
              payoutStatus != 'paid_out';
        }).toList();

        final paidOrders = docs.where((doc) {
          final data = doc.data();
          return (data['payoutStatus'] ?? '').toString() == 'paid_out';
        }).toList();

        final pendingAmount = releasableOrders.fold<double>(0, (sum, doc) {
          return sum + _technicianPayoutAmount(doc.data());
        });

        final waitingReleaseAmount =
            waitingReleaseOrders.fold<double>(0, (sum, doc) {
          return sum + _technicianPayoutAmount(doc.data());
        });

        final paidAmount = paidOrders.fold<double>(0, (sum, doc) {
          return sum + _technicianPayoutAmount(doc.data());
        });

        final sampleData = releasableOrders.isNotEmpty
            ? releasableOrders.first.data()
            : waitingReleaseOrders.isNotEmpty
                ? waitingReleaseOrders.first.data()
                : paidOrders.isNotEmpty
                    ? paidOrders.first.data()
                    : null;

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFE8DDD1)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Cobros del tecnico',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Aqui ves el monto retenido disponible y el historial de pagos procesados por Panafix.',
                style: TextStyle(
                  color: Color(0xFF6D5E4F),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFFFF8A1F),
                      Color(0xFFFFB15A),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Solicita tu pago aqui',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      pendingAmount <= 0
                          ? waitingReleaseAmount > 0
                              ? 'Tienes ${_moneyLabel(waitingReleaseAmount, sampleData)} esperando que el cliente libere el pago.'
                              : 'Todavia no tienes monto retenido disponible para solicitar.'
                          : 'Tienes ${_moneyLabel(pendingAmount, sampleData)} retenidos y listos para solicitar dentro del horario habil.',
                      style: const TextStyle(
                        color: Colors.white,
                        height: 1.4,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _ProfileMetricCard(
                      title: 'Monto retenido',
                      value: _moneyLabel(pendingAmount, sampleData),
                      subtitle: '${releasableOrders.length} trabajos',
                      color: const Color(0xFFFF7A00),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _ProfileMetricCard(
                      title: 'Ya pagado',
                      value: _moneyLabel(paidAmount, sampleData),
                      subtitle: '${paidOrders.length} trabajos',
                      color: const Color(0xFF0F766E),
                    ),
                  ),
                ],
              ),
              if (waitingReleaseAmount > 0) ...[
                const SizedBox(height: 14),
                _ProfileMetricCard(
                  title: 'Esperando liberacion',
                  value: _moneyLabel(waitingReleaseAmount, sampleData),
                  subtitle:
                      '${waitingReleaseOrders.length} trabajos completados',
                  color: const Color(0xFF2563EB),
                ),
              ],
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F4EF),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Text(
                  releasableOrders.isEmpty
                      ? 'Todavia no tienes monto retenido listo para solicitar.'
                      : 'Si quieres cobrar, envia tu solicitud dentro del horario habil y Panafix la revisara.',
                  style: const TextStyle(
                    color: Color(0xFF5D4D40),
                    fontWeight: FontWeight.w700,
                    height: 1.35,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('technician_payout_requests')
                    .doc(user!.uid)
                    .snapshots(),
                builder: (context, requestSnapshot) {
                  final requestData = requestSnapshot.data?.data();
                  final requestStatus =
                      (requestData?['status'] ?? '').toString();
                  final hasOpenRequest = requestStatus == 'requested';

                  if (pendingAmount <= 0) {
                    return Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF7F4EF),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Text(
                        _payoutRequestScheduleText(),
                        style: const TextStyle(
                          color: Color(0xFF5D4D40),
                          fontWeight: FontWeight.w700,
                          height: 1.35,
                        ),
                      ),
                    );
                  }

                  if (hasOpenRequest) {
                    return Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF4E8),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: const Color(0xFFFFD2A8)),
                      ),
                      child: const Text(
                        'Ya enviaste una solicitud de pago. Panafix la revisara y la marcara cuando el pago sea procesado.',
                        style: TextStyle(
                          color: Color(0xFF8A4700),
                          fontWeight: FontWeight.w700,
                          height: 1.35,
                        ),
                      ),
                    );
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF7F4EF),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Text(
                          _payoutRequestScheduleText(),
                          style: const TextStyle(
                            color: Color(0xFF5D4D40),
                            fontWeight: FontWeight.w700,
                            height: 1.35,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _isPayoutRequestWindowOpen()
                              ? () => _requestTechnicianPayout(
                                    totalAmount: pendingAmount,
                                    ordersCount: releasableOrders.length,
                                    orders: releasableOrders,
                                  )
                              : null,
                          icon: const Icon(Icons.request_quote_outlined),
                          label: const Text('Solicitar pago retenido'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFF7A00),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            textStyle: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget buildPayoutHistory() {
    if (user == null) return const SizedBox();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('technician_payouts')
          .where('technicianId', isEqualTo: user!.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Center(child: CircularProgressIndicator()),
          );
        }

        final payouts = [...snapshot.data!.docs]
          ..sort((a, b) {
            final aTime = a.data()['createdAt'] as Timestamp?;
            final bTime = b.data()['createdAt'] as Timestamp?;
            return (bTime?.millisecondsSinceEpoch ?? 0)
                .compareTo(aTime?.millisecondsSinceEpoch ?? 0);
          });

        if (payouts.isEmpty) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFFE8DDD1)),
            ),
            child: const Text(
              'Todavia no tienes pagos procesados. Cuando admin haga un corte, aparecera aqui.',
              style: TextStyle(
                color: Color(0xFF6D5E4F),
                height: 1.4,
              ),
            ),
          );
        }

        return Column(
          children: payouts.take(5).map((doc) {
            final data = doc.data();
            final amount = (data['totalAmount'] as num?)?.toDouble() ?? 0;
            final ordersCount = (data['ordersCount'] as num?)?.toInt() ?? 0;
            final createdAt = data['createdAt'] as Timestamp?;
            final bank = (data['payoutBank'] ?? '').toString();
            final date = createdAt == null
                ? 'Sin fecha'
                : '${createdAt.toDate().day.toString().padLeft(2, '0')}/'
                    '${createdAt.toDate().month.toString().padLeft(2, '0')}/'
                    '${createdAt.toDate().year}';

            return Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFE8DDD1)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Pago procesado',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      Text(
                        '\$${amount.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: Color(0xFF0F766E),
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$ordersCount trabajos  |  $date',
                    style: const TextStyle(
                      color: Color(0xFF6D5E4F),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (bank.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Banco registrado: $bank',
                      style: const TextStyle(color: Color(0xFF6D5E4F)),
                    ),
                  ],
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Future<void> loadTechnicianData() async {
    if (user == null) return;

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .get();

    final data = doc.data();

    if (data != null) {
      await _expireSubscriptionIfNeeded(data);
      final refreshedDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .get();
      final refreshedData = refreshedDoc.data() ?? data;

      nameController.text = refreshedData['name']?.toString() ?? '';
      phoneController.text = refreshedData['phone']?.toString() ?? '';
      bioController.text = refreshedData['bio']?.toString() ?? '';
      payoutNameController.text =
          refreshedData['payoutAccountName']?.toString() ?? '';
      payoutPhoneController.text =
          refreshedData['payoutMobilePhone']?.toString() ?? '';
      payoutIdController.text =
          refreshedData['payoutDocumentId']?.toString() ?? '';
      payoutBankController.text =
          refreshedData['payoutBank']?.toString() ?? '';
      selectedCity = refreshedData['city']?.toString();
      profilePhotoUrl = refreshedData['profilePhotoUrl']?.toString();
      isAvailable = refreshedData['isAvailable'] != false;
      workStart = refreshedData['workStart']?.toString() ?? '08:00';
      workEnd = refreshedData['workEnd']?.toString() ?? '18:00';
      yearsExperience =
          (refreshedData['yearsExperience'] as num?)?.toDouble() ?? 1;
      serviceRadius =
          (refreshedData['serviceRadius'] as num?)?.toDouble() ?? 10;
      subscriptionPlan =
          refreshedData['subscriptionPlan']?.toString() ?? 'basic';
      subscriptionStatus =
          refreshedData['subscriptionStatus']?.toString() ?? 'inactive';
      subscriptionEndsAt = refreshedData['promotedUntil'] as Timestamp?;
      verificationStatus =
          refreshedData['verificationStatus']?.toString() ?? 'not_submitted';
      idDocumentUrl = refreshedData['idDocumentUrl']?.toString();
      credentialDocumentUrl =
          refreshedData['credentialDocumentUrl']?.toString();

      selectedCategories = List<String>.from(refreshedData['categories'] ?? [])
          .map(normalizeCategory)
          .toList();
      selectedServices = List<String>.from(refreshedData['services'] ?? [])
          .map(normalizeService)
          .toList();
      availableDays = List<String>.from(
        refreshedData['availableDays'] ??
            ['Lun', 'Mar', 'Mie', 'Jue', 'Vie', 'Sab'],
      );

      currentRating = (refreshedData['rating'] as num?)?.toDouble() ?? 5.0;
      reviewsCount = (refreshedData['reviewsCount'] as num?)?.toInt() ?? 0;

      profileCompleted = nameController.text.isNotEmpty &&
          selectedCity != null &&
          selectedCity!.isNotEmpty;
    }

    setState(() {
      isLoading = false;
    });

    await _showTechnicianOnboardingIfNeeded();
  }

  Future<void> _showTechnicianOnboardingIfNeeded() async {
    if (user == null || !mounted) return;

    final userRef =
        FirebaseFirestore.instance.collection('users').doc(user!.uid);
    final doc = await userRef.get();
    final data = doc.data() ?? {};
    if (data['showOnboardingGuide'] != true) return;

    await userRef.set({
      'showOnboardingGuide': false,
      'onboardingGuideShownAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    if (!mounted) return;
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          insetPadding: const EdgeInsets.all(18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          child: Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFFF7ED), Colors.white],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF7A00),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(
                        Icons.engineering_outlined,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Bienvenido, tecnico',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const Text(
                  'Mini tour para trabajar sin salir corriendo como si viste un cable pelado.',
                  style: TextStyle(
                    color: Color(0xFF6D5E4F),
                    height: 1.35,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 16),
                const _TechnicianWelcomeStep(
                  icon: Icons.account_circle_outlined,
                  title: 'Completa tu perfil',
                  body: 'Foto, ciudad, servicios, horario y pago movil.',
                ),
                const _TechnicianWelcomeStep(
                  icon: Icons.payments_outlined,
                  title: 'Espera pago aprobado',
                  body: 'No vayas en camino hasta que Panafix apruebe el pago.',
                ),
                const _TechnicianWelcomeStep(
                  icon: Icons.lock_open_outlined,
                  title: 'Pago autorizado',
                  body: 'Al terminar, Panafix autoriza y luego solicitas tu cobro.',
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        child: const Text('Entendido'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(dialogContext);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  const ProcessGuidePage.technician(),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF7A00),
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Ver guia'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  List<String> get availableServices {
    final List<String> result = [];

    for (final category in selectedCategories) {
      final services = servicesByCategory[normalizeCategory(category)] ?? [];
      for (final service in services) {
        if (!result.contains(service)) {
          result.add(normalizeService(service));
        }
      }
    }

    return result;
  }

  void toggleCategory(String category, bool value) {
    setState(() {
      if (value) {
        if (!selectedCategories.contains(category)) {
          selectedCategories.add(category);
        }
      } else {
        selectedCategories.remove(category);
        final remainingServices = availableServices.toSet();
        selectedServices = selectedServices
            .where((service) => remainingServices.contains(service))
            .toList();
      }
    });
  }

  void toggleService(String service, bool value) {
    setState(() {
      if (value) {
        if (!selectedServices.contains(service)) {
          selectedServices.add(service);
        }
      } else {
        selectedServices.remove(service);
      }
    });
  }

  void toggleDay(String day) {
    setState(() {
      if (availableDays.contains(day)) {
        if (availableDays.length > 1) {
          availableDays.remove(day);
        }
      } else {
        availableDays.add(day);
      }
    });
  }

  Future<void> selectTime({
    required bool isStart,
  }) async {
    final rawValue = isStart ? workStart : workEnd;
    final pieces = rawValue.split(':');
    final initialTime = TimeOfDay(
      hour: int.tryParse(pieces.first) ?? 8,
      minute: int.tryParse(pieces.last) ?? 0,
    );

    final selected = await showTimePicker(
      context: context,
      initialTime: initialTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: const Color(0xFFFF7A00),
                ),
          ),
          child: child!,
        );
      },
    );

    if (selected == null) return;

    final formatted =
        '${selected.hour.toString().padLeft(2, '0')}:${selected.minute.toString().padLeft(2, '0')}';

    setState(() {
      if (isStart) {
        workStart = formatted;
      } else {
        workEnd = formatted;
      }
    });
  }

  Future<void> saveProfile() async {
    if (user == null) return;

    if (nameController.text.trim().isEmpty || selectedCity == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Completa nombre y ciudad.')),
      );
      return;
    }

    setState(() {
      isSaving = true;
    });

    await FirebaseFirestore.instance.collection('users').doc(user!.uid).set({
      'name': nameController.text.trim(),
      'phone': phoneController.text.trim(),
      'bio': bioController.text.trim(),
      'payoutAccountName': payoutNameController.text.trim(),
      'payoutMobilePhone': payoutPhoneController.text.trim(),
      'payoutDocumentId': payoutIdController.text.trim(),
      'payoutBank': payoutBankController.text.trim(),
      'profilePhotoUrl': profilePhotoUrl ?? '',
      'verificationStatus': verificationStatus,
      'idDocumentUrl': idDocumentUrl ?? '',
      'credentialDocumentUrl': credentialDocumentUrl ?? '',
      'city': selectedCity,
      'isAvailable': isAvailable,
      'availableDays': availableDays,
      'workStart': workStart,
      'workEnd': workEnd,
      'yearsExperience': yearsExperience.round(),
      'serviceRadius': serviceRadius.round(),
      'subscriptionPlan': subscriptionPlan,
      'subscriptionStatus': subscriptionStatus,
      'role': 'technician',
      'uid': user!.uid,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    setState(() {
      isSaving = false;
      profileCompleted = true;
      selectedTab = 0;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Perfil actualizado correctamente.')),
    );
  }

  Future<void> signOut() async {
    await AuthService().signOut();
  }

  Future<void> uploadProfilePhoto() async {
    if (user == null) return;

    try {
      setState(() {
        isSaving = true;
      });

      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true,
      );

      if (result == null || result.files.isEmpty) {
        return;
      }

      final file = result.files.first;
      final bytes = file.bytes;

      if (bytes == null) {
        throw Exception('No se pudo leer la imagen seleccionada.');
      }

      if (bytes.lengthInBytes > 8 * 1024 * 1024) {
        throw Exception('La imagen debe pesar menos de 8 MB.');
      }

      final extension = file.extension ?? 'jpg';
      final ref = FirebaseStorage.instance
          .ref()
          .child('technician_photos/${user!.uid}/profile.$extension');

      await ref.putData(
        bytes,
        SettableMetadata(contentType: 'image/$extension'),
      );

      final downloadUrl = await ref.getDownloadURL();

      await FirebaseFirestore.instance.collection('users').doc(user!.uid).set({
        'profilePhotoUrl': downloadUrl,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      setState(() {
        profilePhotoUrl = downloadUrl;
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Foto de perfil actualizada.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al subir la foto: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          isSaving = false;
        });
      }
    }
  }

  String _verificationLabel() {
    switch (verificationStatus) {
      case 'approved':
        return 'Verificado por Panafix';
      case 'pending':
        return 'Revision pendiente';
      case 'rejected':
        return 'No verificado';
      default:
        return 'Sin verificar';
    }
  }

  Color _verificationColor() {
    switch (verificationStatus) {
      case 'approved':
        return const Color(0xFF16A34A);
      case 'pending':
        return const Color(0xFFFF7A00);
      case 'rejected':
        return const Color(0xFFDC2626);
      default:
        return const Color(0xFF6B7280);
    }
  }

  String _verificationHelpText() {
    switch (verificationStatus) {
      case 'approved':
        return 'Tu perfil ya fue revisado y aparece como verificado para generar mas confianza.';
      case 'pending':
        return 'Ya enviaste tu solicitud de verificacion. Panafix revisara tus documentos pronto.';
      case 'rejected':
        return 'Tus documentos no fueron aprobados todavia. Puedes actualizarlos y volver a solicitar la verificacion cuando quieras.';
      default:
        return 'Si quieres verificarte, sube tu cedula y un soporte profesional. Panafix los revisara para proteger a clientes y tecnicos durante pagos, reclamos y servicios activos.';
    }
  }

  Future<void> _uploadVerificationDocument({
    required String storageName,
    required String contentField,
    required String successMessage,
  }) async {
    if (user == null) return;

    try {
      setState(() {
        isSaving = true;
      });

      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) {
        return;
      }

      final file = result.files.first;
      final bytes = file.bytes;

      if (bytes == null) {
        throw Exception('No se pudo leer el archivo seleccionado.');
      }

      if (bytes.lengthInBytes > 10 * 1024 * 1024) {
        throw Exception('El archivo debe pesar menos de 10 MB.');
      }

      final extension = (file.extension ?? 'jpg').toLowerCase();
      final contentType =
          extension == 'pdf' ? 'application/pdf' : 'image/$extension';
      final ref = FirebaseStorage.instance.ref().child(
            'technician_verification/${user!.uid}/$storageName.$extension',
          );

      await ref.putData(
        bytes,
        SettableMetadata(contentType: contentType),
      );

      final downloadUrl = await ref.getDownloadURL();

      await FirebaseFirestore.instance.collection('users').doc(user!.uid).set({
        contentField: downloadUrl,
        'verificationStatus': 'pending',
        'verificationSubmittedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await FirebaseFirestore.instance.collection('owner_alerts').add({
        'title': 'Documentos para verificacion',
        'message':
            '${nameController.text.trim().isEmpty ? 'Un tecnico' : nameController.text.trim()} subio documentos para revision.',
        'type': 'verification',
        'priority': 'medium',
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
        'expiresAt': Timestamp.fromDate(
          DateTime.now().add(const Duration(days: 60)),
        ),
      });

      setState(() {
        verificationStatus = 'pending';
        if (contentField == 'idDocumentUrl') {
          idDocumentUrl = downloadUrl;
        } else {
          credentialDocumentUrl = downloadUrl;
        }
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(successMessage)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al subir documento: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          isSaving = false;
        });
      }
    }
  }

  Widget buildVerificationCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE8DDD1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Verificacion opcional',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: _verificationColor().withOpacity(0.10),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  _verificationLabel(),
                  style: TextStyle(
                    color: _verificationColor(),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Puedes subir foto de cedula y un certificado o soporte profesional para que Panafix revise tu perfil. Es opcional, ayuda a generar confianza y protege a cliente y tecnico durante pagos, reclamos y soporte.',
            style: TextStyle(
              color: Color(0xFF6D5E4F),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF7F4EF),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Text(
              _verificationHelpText(),
              style: TextStyle(
                color: _verificationColor(),
                fontWeight: FontWeight.w700,
                height: 1.35,
              ),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: isSaving
                  ? null
                  : () => _uploadVerificationDocument(
                        storageName: 'id_document',
                        contentField: 'idDocumentUrl',
                        successMessage: 'Documento de identidad subido.',
                      ),
              icon: const Icon(Icons.badge_outlined),
              label: Text(
                idDocumentUrl == null || idDocumentUrl!.isEmpty
                    ? 'Subir foto de cedula'
                    : verificationStatus == 'rejected'
                        ? 'Volver a subir foto de cedula'
                        : 'Actualizar foto de cedula',
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: isSaving
                  ? null
                  : () => _uploadVerificationDocument(
                        storageName: 'credential_document',
                        contentField: 'credentialDocumentUrl',
                        successMessage: 'Soporte profesional subido.',
                      ),
              icon: const Icon(Icons.workspace_premium_outlined),
              label: Text(
                credentialDocumentUrl == null ||
                        credentialDocumentUrl!.isEmpty
                    ? 'Subir certificado o soporte'
                    : verificationStatus == 'rejected'
                        ? 'Volver a subir certificado o soporte'
                        : 'Actualizar certificado o soporte',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openSupportUrl(BuildContext context, Uri uri) async {
    final opened = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );

    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo abrir ese medio de contacto.'),
        ),
      );
    }
  }

  Widget buildProfessionalCenter() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF1B130C),
            Color(0xFF5A2E08),
            Color(0xFFFF8A1F),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Centro profesional',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Desde aqui puedes revisar ayuda, soporte y documentos utiles para operar tu perfil con mas confianza.',
            style: TextStyle(
              color: Color(0xFFFCE3CD),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const SupportCenterPage(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.gavel_outlined),
                  label: const Text('Ayuda'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Color(0x40FFFFFF)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _openSupportUrl(
                    context,
                    Uri.parse('https://wa.me/13854637334'),
                  ),
                  icon: const Icon(Icons.support_agent),
                  label: const Text('Soporte'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF1B130C),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.14),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Text(
              'Soporte directo: $_supportPhone',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    nameController.dispose();
    phoneController.dispose();
    bioController.dispose();
    payoutNameController.dispose();
    payoutPhoneController.dispose();
    payoutIdController.dispose();
    payoutBankController.dispose();
    super.dispose();
  }

  Widget buildRecentReviews() {
    if (user == null) return const SizedBox();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('reviews')
          .where('technicianId', isEqualTo: user!.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Text(
              'Todavia no tienes resenas publicadas.',
              style: TextStyle(color: Color(0xFF756B61)),
            ),
          );
        }

        final reviews = [...snapshot.data!.docs]
          ..sort((a, b) {
            final aTime = a.data()['createdAt'] as Timestamp?;
            final bTime = b.data()['createdAt'] as Timestamp?;
            return (bTime?.millisecondsSinceEpoch ?? 0)
                .compareTo(aTime?.millisecondsSinceEpoch ?? 0);
          });
        final recentReviews = reviews.take(5).toList();

        return Column(
          children: recentReviews.map((doc) {
            final review = doc.data();
            final rating = (review['rating'] as num?)?.toDouble() ?? 5.0;
            final reviewText = review['review']?.toString() ?? '';

            return Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Calificacion ${rating.toStringAsFixed(1)}',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    reviewText.isEmpty ? 'Sin comentario.' : reviewText,
                    style: const TextStyle(color: Color(0xFF3B3129)),
                  ),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget buildProfile() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF0F172A),
                  Color(0xFF1E293B),
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
                Row(
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.14),
                            borderRadius: BorderRadius.circular(22),
                            image: profilePhotoUrl != null &&
                                    profilePhotoUrl!.isNotEmpty
                                ? DecorationImage(
                                    image: NetworkImage(profilePhotoUrl!),
                                    fit: BoxFit.cover,
                                  )
                                : null,
                          ),
                          child: profilePhotoUrl == null ||
                                  profilePhotoUrl!.isEmpty
                              ? const Icon(
                                  Icons.person,
                                  color: Colors.white,
                                  size: 38,
                                )
                              : null,
                        ),
                        Positioned(
                          right: -6,
                          bottom: -6,
                          child: Material(
                            color: const Color(0xFFFF7A00),
                            shape: const CircleBorder(),
                            child: IconButton(
                              onPressed: isSaving ? null : uploadProfilePhoto,
                              icon: const Icon(
                                Icons.camera_alt_outlined,
                                color: Colors.white,
                                size: 18,
                              ),
                              constraints: const BoxConstraints(
                                minWidth: 36,
                                minHeight: 36,
                              ),
                              padding: EdgeInsets.zero,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            nameController.text.isEmpty
                                ? 'Tecnico Panafix'
                                : nameController.text,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '$reviewsCount resenas  |  ${currentRating.toStringAsFixed(1)} de calificacion',
                            style: const TextStyle(
                              color: Color(0xFFF8D8B6),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _TechStatChip(
                      label: isAvailable ? 'Visible para clientes' : 'Oculto',
                    ),
                    _TechStatChip(
                      label: selectedCity ?? 'Ciudad pendiente',
                    ),
                    _TechStatChip(
                      label: '$workStart - $workEnd',
                    ),
                    _TechStatChip(
                      label: '${yearsExperience.round()} anos exp.',
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(30),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Perfil profesional',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Configura tu informacion, tu disponibilidad y los servicios que ofreces.',
                  style: TextStyle(
                    color: Color(0xFF756B61),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: isSaving ? null : uploadProfilePhoto,
                    icon: const Icon(Icons.photo_camera_back_outlined),
                    label: Text(
                      profilePhotoUrl == null || profilePhotoUrl!.isEmpty
                          ? 'Subir foto de perfil'
                          : 'Cambiar foto de perfil',
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF4DB),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Impulso para tecnicos',
                          style: TextStyle(
                            fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          subscriptionStatus == 'active'
                              ? 'Plan actual: ${subscriptionPlan.toUpperCase()} hasta el ${_formatSubscriptionDate(subscriptionEndsAt)}'
                              : 'Activa una suscripcion para destacar tu perfil y salir primero.',
                          style: const TextStyle(
                            color: Color(0xFF6D5E4F),
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.6),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Text(
                            _subscriptionCountdownText(),
                            style: const TextStyle(
                              color: Color(0xFF5D4D40),
                              fontWeight: FontWeight.w700,
                              height: 1.35,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const SubscriptionPlansPage(),
                              ),
                            );

                            if (!mounted) return;
                            await loadTechnicianData();
                          },
                          icon: const Icon(Icons.workspace_premium_outlined),
                          label: const Text('Ver planes de suscripcion'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1B130C),
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Nombre visible',
                    prefixIcon: Icon(Icons.badge_outlined),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Telefono de contacto',
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  value: venezuelaCities.contains(selectedCity) ? selectedCity : null,
                  decoration: const InputDecoration(
                    labelText: 'Ciudad',
                    prefixIcon: Icon(Icons.location_city_outlined),
                  ),
                  items: venezuelaCities.map((city) {
                    return DropdownMenuItem<String>(
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
                const SizedBox(height: 14),
                TextField(
                  controller: bioController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Descripcion profesional',
                    prefixIcon: Icon(Icons.edit_note_outlined),
                    hintText:
                        'Cuenta brevemente tu experiencia, tu trato y en que te especializas.',
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7F4EF),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: const Color(0xFFE7DDD3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Datos para pagarte',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Esta informacion es privada y sirve para que Panafix pueda hacerte pagos por pago movil cuando corresponda.',
                        style: TextStyle(
                          color: Color(0xFF6D5E4F),
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: payoutNameController,
                        decoration: const InputDecoration(
                          labelText: 'Nombre del titular',
                          prefixIcon: Icon(Icons.account_circle_outlined),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: payoutPhoneController,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'Telefono de pago movil',
                          prefixIcon: Icon(Icons.phone_android_outlined),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: payoutIdController,
                        decoration: const InputDecoration(
                          labelText: 'Cedula o documento',
                          prefixIcon: Icon(Icons.badge_outlined),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: payoutBankController,
                        decoration: const InputDecoration(
                          labelText: 'Banco',
                          prefixIcon: Icon(Icons.account_balance_outlined),
                          hintText: 'Ejemplo: Banco de Venezuela',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                buildPayoutSummary(),
                const SizedBox(height: 14),
                buildVerificationCard(),
                const SizedBox(height: 14),
                buildProfessionalCenter(),
                const SizedBox(height: 14),
                const Text(
                  'Historial de pagos',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                buildPayoutHistory(),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7F4EF),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SwitchListTile(
                        value: isAvailable,
                        contentPadding: EdgeInsets.zero,
                        activeColor: const Color(0xFFFF7A00),
                        title: const Text(
                          'Disponible para nuevos trabajos',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                        subtitle: Text(
                          isAvailable
                              ? 'Tu perfil aparece para nuevas solicitudes.'
                              : 'No recibiras solicitudes nuevas hasta volver a activarte.',
                        ),
                        onChanged: (value) {
                          setState(() {
                            isAvailable = value;
                          });
                        },
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Dias disponibles',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: weekDays.map((day) {
                          final selected = availableDays.contains(day);
                          return FilterChip(
                            selected: selected,
                            label: Text(day),
                            selectedColor: const Color(0xFFFFE2BF),
                            checkmarkColor: const Color(0xFFFF7A00),
                            onSelected: (_) => toggleDay(day),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: _ScheduleButton(
                              label: 'Inicio',
                              value: workStart,
                              icon: Icons.schedule,
                              onTap: () => selectTime(isStart: true),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _ScheduleButton(
                              label: 'Cierre',
                              value: workEnd,
                              icon: Icons.nightlight_round,
                              onTap: () => selectTime(isStart: false),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Experiencia: ${yearsExperience.round()} anos',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      Slider(
                        value: yearsExperience,
                        min: 1,
                        max: 25,
                        divisions: 24,
                        activeColor: const Color(0xFFFF7A00),
                        label: yearsExperience.round().toString(),
                        onChanged: (value) {
                          setState(() {
                            yearsExperience = value;
                          });
                        },
                      ),
                      Text(
                        'Radio de servicio: ${serviceRadius.round()} km',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      Slider(
                        value: serviceRadius,
                        min: 3,
                        max: 60,
                        divisions: 19,
                        activeColor: const Color(0xFFFF7A00),
                        label: serviceRadius.round().toString(),
                        onChanged: (value) {
                          setState(() {
                            serviceRadius = value;
                          });
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      setState(() {
                        selectedTab = 2;
                      });
                    },
                    icon: const Icon(Icons.design_services_outlined),
                    label: const Text('Configurar categorias y servicios'),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: isSaving ? null : saveProfile,
                    child: Text(
                      isSaving ? 'Guardando...' : 'Guardar perfil',
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Resenas recientes',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          buildRecentReviews(),
        ],
      ),
    );
  }

  String getAppBarTitle() {
    switch (selectedTab) {
      case 0:
        return 'Solicitudes';
      case 1:
        return 'Mis trabajos';
      case 2:
        return 'Mis servicios';
      case 3:
        return 'Perfil';
      default:
        return 'Panel tecnico';
    }
  }

  Widget getSelectedBody() {
    switch (selectedTab) {
      case 0:
        return const TechnicianRequestsPage();
      case 1:
        return const TechnicianMyJobsPage();
      case 2:
        return const TechnicianServicesPage();
      case 3:
        return buildProfile();
      default:
        return buildProfile();
    }
  }

  Widget buildNotificationsButton() {
    if (user == null) {
      return IconButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const NotificationsPage(),
            ),
          );
        },
        icon: const Icon(Icons.notifications_none),
      );
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('notifications')
          .where('userId', isEqualTo: user!.uid)
          .snapshots(),
      builder: (context, snapshot) {
        final unreadCount = snapshot.data?.docs
                .where((doc) => doc.data()['isRead'] != true)
                .length ??
            0;
        final badgeText = unreadCount > 99 ? '99+' : unreadCount.toString();

        return IconButton(
          tooltip: 'Notificaciones',
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const NotificationsPage(),
              ),
            );
          },
          icon: Stack(
            clipBehavior: Clip.none,
            children: [
              const Icon(Icons.notifications_none),
              if (unreadCount > 0)
                Positioned(
                  right: -5,
                  top: -5,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 2,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 18,
                      minHeight: 18,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: Colors.white, width: 1.4),
                    ),
                    child: Text(
                      badgeText,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (!profileCompleted) {
      selectedTab = 3;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(getAppBarTitle()),
        actions: [
          TextButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ProcessGuidePage.technician(),
                ),
              );
            },
            icon: const Icon(Icons.play_circle_outline, size: 18),
            label: const Text('Como usar'),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFFF7A00),
              textStyle: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
          buildNotificationsButton(),
          IconButton(
            tooltip: 'Cerrar sesion',
            onPressed: signOut,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: getSelectedBody(),
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedTab,
        onDestinationSelected: (index) {
          setState(() {
            selectedTab = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.assignment_outlined),
            selectedIcon: Icon(Icons.assignment),
            label: 'Solicitudes',
          ),
          NavigationDestination(
            icon: Icon(Icons.build_outlined),
            selectedIcon: Icon(Icons.build),
            label: 'Trabajos',
          ),
          NavigationDestination(
            icon: Icon(Icons.grid_view_outlined),
            selectedIcon: Icon(Icons.grid_view),
            label: 'Servicios',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Perfil',
          ),
        ],
      ),
    );
  }
}

class _TechStatChip extends StatelessWidget {
  final String label;

  const _TechStatChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ScheduleButton extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final VoidCallback onTap;

  const _ScheduleButton({
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Ink(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE2DBD2)),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: const Color(0xFFFFEDD8),
              child: Icon(icon, color: const Color(0xFFFF7A00), size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: Color(0xFF756B61),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TechnicianWelcomeStep extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;

  const _TechnicianWelcomeStep({
    required this.icon,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 19,
            backgroundColor: const Color(0xFFFFEDD8),
            child: Icon(icon, color: const Color(0xFFFF7A00), size: 21),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 2),
                Text(
                  body,
                  style: const TextStyle(
                    color: Color(0xFF6D5E4F),
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileMetricCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final Color color;

  const _ProfileMetricCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(
              color: Color(0xFF6D5E4F),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
