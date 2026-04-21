import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import '../services/owner_alert_service.dart';

class SubscriptionPlansPage extends StatefulWidget {
  const SubscriptionPlansPage({super.key});

  @override
  State<SubscriptionPlansPage> createState() => _SubscriptionPlansPageState();
}

class _SubscriptionPlansPageState extends State<SubscriptionPlansPage> {
  bool isSaving = false;

  String _paymentStatusMessage(Map<String, dynamic>? data) {
    final paymentStatus =
        data?['subscriptionPaymentStatus']?.toString() ?? 'none';
    final requestedTitle =
        data?['subscriptionRequestedTitle']?.toString() ?? 'tu plan';

    if (paymentStatus == 'pending_review') {
      return 'Tu pago movil para $requestedTitle fue enviado y esta pendiente de revision.';
    }

    return '';
  }

  Future<void> _expireSubscriptionIfNeeded(
    String userId,
    Map<String, dynamic>? data,
  ) async {
    if (data == null) return;

    final status = data['subscriptionStatus']?.toString() ?? 'inactive';
    final promotedUntil = data['promotedUntil'] as Timestamp?;

    if (status == 'active' &&
        promotedUntil != null &&
        promotedUntil.toDate().isBefore(DateTime.now())) {
      await FirebaseFirestore.instance.collection('users').doc(userId).set({
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

  String _countdownText(Timestamp? promotedUntil, String status) {
    if (status != 'active' || promotedUntil == null) {
      return 'Tu cuenta esta en modo basico hasta que actives uno de los planes.';
    }

    final difference = promotedUntil.toDate().difference(DateTime.now());
    if (difference.isNegative) {
      return 'Tu promocion ya vencio y tu cuenta volvera al plan basico.';
    }

    if (difference.inDays >= 1) {
      return 'Tu promocion sigue activa por ${difference.inDays + 1} dias.';
    }

    return 'Tu promocion vence hoy. Aprovecha el impulso mientras sigue activa.';
  }

  String _formatDate(Timestamp? value) {
    if (value == null) return 'Sin fecha activa';
    final date = value.toDate().toLocal();
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  Future<String?> _uploadSubscriptionPaymentProof(String userId) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );

    if (result == null || result.files.isEmpty) return null;

    final file = result.files.single;
    final bytes = file.bytes;
    if (bytes == null) {
      throw Exception('No se pudo leer la imagen seleccionada.');
    }

    if (bytes.length > 8 * 1024 * 1024) {
      throw Exception('La imagen no debe superar los 8 MB.');
    }

    final extension = (file.extension ?? 'jpg').toLowerCase();
    final fileName = '${DateTime.now().millisecondsSinceEpoch}.$extension';
    final ref = FirebaseStorage.instance
        .ref()
        .child('subscription_payment_proofs/$userId/$fileName');

    await ref.putData(
      bytes,
      SettableMetadata(contentType: 'image/$extension'),
    );

    return ref.getDownloadURL();
  }

  Future<void> requestPlanActivation({
    required String planId,
    required String title,
    required String monthlyPrice,
    required int priority,
    required int durationDays,
    required List<String> benefits,
    required String payerName,
    required String payerPhone,
    required String payerDocument,
    required String paymentReference,
    required String paymentProofUrl,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      setState(() {
        isSaving = true;
      });

      final retainUntil = DateTime.now().add(const Duration(days: 14));

      await FirebaseFirestore.instance
          .collection('subscription_payment_requests')
          .add({
        'technicianId': user.uid,
        'planId': planId,
        'planTitle': title,
        'monthlyPrice': monthlyPrice,
        'priority': priority,
        'durationDays': durationDays,
        'benefits': benefits,
        'payerName': payerName,
        'payerPhone': payerPhone,
        'payerDocument': payerDocument,
        'paymentReference': paymentReference,
        'paymentProofUrl': paymentProofUrl,
        'paymentRetainUntil': Timestamp.fromDate(retainUntil),
        'paymentRetentionDays': 14,
        'status': 'pending_review',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'subscriptionRequestedPlan': planId,
        'subscriptionRequestedTitle': title,
        'subscriptionRequestedPriceLabel': monthlyPrice,
        'subscriptionPaymentStatus': 'pending_review',
        'subscriptionPriorityRequested': priority,
        'subscriptionRequestedBenefits': benefits,
        'lastPayerName': payerName,
        'lastPayerPhone': payerPhone,
        'lastPayerDocument': payerDocument,
        'subscriptionLastReference': paymentReference,
        'subscriptionLastProofUrl': paymentProofUrl,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await OwnerAlertService.createAlert(
        title: 'Pago movil de suscripcion',
        message:
            'Un tecnico envio el pago movil del plan $title y espera revision.',
        type: 'subscription',
        priority: 'high',
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Pago movil enviado. El plan $title quedo pendiente de revision.',
          ),
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo enviar la solicitud: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          isSaving = false;
        });
      }
    }
  }

  Future<void> _showPaymentMobileSheet({
    required String planId,
    required String title,
    required String monthlyPrice,
    required int priority,
    required int durationDays,
    required List<String> benefits,
    required Map<String, dynamic>? data,
  }) async {
    final payerNameController = TextEditingController(
      text: data?['lastPayerName']?.toString() ?? '',
    );
    final payerPhoneController = TextEditingController(
      text: data?['lastPayerPhone']?.toString() ?? '',
    );
    final payerDocumentController = TextEditingController(
      text: data?['lastPayerDocument']?.toString() ?? '',
    );
    final referenceController = TextEditingController(
      text: data?['subscriptionLastReference']?.toString() ?? '',
    );
    final previousProofUrl =
        data?['subscriptionLastProofUrl']?.toString() ?? '';
    String? paymentProofUrl =
        previousProofUrl.isNotEmpty ? previousProofUrl : null;
    bool isUploadingProof = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setModalState) => Padding(
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
              Text(
                'Pago movil para $title',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Haz el pago movil del plan $monthlyPrice y luego envia aqui la referencia para que Panafix revise y active tu suscripcion.',
                style: const TextStyle(
                  color: Color(0xFF6D5E4F),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: payerNameController,
                decoration: const InputDecoration(
                  labelText: 'Nombre del titular que pago',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: payerPhoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Telefono del pago movil',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: payerDocumentController,
                decoration: const InputDecoration(
                  labelText: 'Cedula o documento',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: referenceController,
                decoration: const InputDecoration(
                  labelText: 'Numero de referencia',
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: isUploadingProof
                    ? null
                    : () async {
                        try {
                          final currentUser = FirebaseAuth.instance.currentUser;
                          if (currentUser == null) return;
                          setModalState(() => isUploadingProof = true);
                          final uploadedUrl =
                              await _uploadSubscriptionPaymentProof(
                            currentUser.uid,
                          );
                          if (uploadedUrl != null) {
                            setModalState(() => paymentProofUrl = uploadedUrl);
                          }
                        } catch (e) {
                          if (!sheetContext.mounted) return;
                          ScaffoldMessenger.of(sheetContext).showSnackBar(
                            SnackBar(content: Text('$e')),
                          );
                        } finally {
                          setModalState(() => isUploadingProof = false);
                        }
                      },
                icon: isUploadingProof
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.receipt_long_outlined),
                label: Text(
                  paymentProofUrl == null
                      ? 'Adjuntar foto del pago'
                      : 'Foto del pago adjunta',
                ),
              ),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3E6),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Text(
                  'Tu plan no se activa al instante. Primero debes enviar el pago movil y esperar la revision de Panafix.',
                  style: TextStyle(
                    color: Color(0xFF6D5E4F),
                    fontWeight: FontWeight.w700,
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: isSaving || isUploadingProof
                      ? null
                      : () async {
                          final payerName = payerNameController.text.trim();
                          final payerPhone = payerPhoneController.text.trim();
                          final payerDocument =
                              payerDocumentController.text.trim();
                          final reference = referenceController.text.trim();

                          if (payerName.isEmpty ||
                              payerPhone.isEmpty ||
                              payerDocument.isEmpty ||
                              reference.isEmpty) {
                            ScaffoldMessenger.of(sheetContext).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Completa los datos del pago movil.',
                                ),
                              ),
                            );
                              return;
                          }

                          if (paymentProofUrl == null ||
                              paymentProofUrl!.isEmpty) {
                            ScaffoldMessenger.of(sheetContext).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Adjunta la foto del pago antes de enviar.',
                                ),
                              ),
                            );
                            return;
                          }

                          Navigator.pop(sheetContext);
                          await requestPlanActivation(
                            planId: planId,
                            title: title,
                            monthlyPrice: monthlyPrice,
                            priority: priority,
                            durationDays: durationDays,
                            benefits: benefits,
                            payerName: payerName,
                            payerPhone: payerPhone,
                            payerDocument: payerDocument,
                            paymentReference: reference,
                            paymentProofUrl: paymentProofUrl!,
                          );
                        },
                  child: Text(isSaving ? 'Enviando...' : 'Enviar pago movil'),
                ),
              ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _benefitTile(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 2),
            width: 22,
            height: 22,
            decoration: const BoxDecoration(
              color: Color(0x1AFFFFFF),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check,
              color: Colors.white,
              size: 14,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _planCard({
    required String title,
    required String price,
    required String subtitle,
    required String recoveryMessage,
    required String paymentHint,
    required List<String> benefits,
    required List<Color> colors,
    required String badge,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: colors.last.withOpacity(0.22),
            blurRadius: 24,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.16),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    badge,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              price,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 36,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: const TextStyle(
                color: Color(0xFFF9E9DB),
                height: 1.45,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.14),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Text(
                recoveryMessage,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              paymentHint,
              style: const TextStyle(
                color: Color(0xFFFFF2E6),
                fontWeight: FontWeight.w700,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 18),
            ...benefits.map(_benefitTile),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isSaving ? null : onTap,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF1B130C),
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                child: Text(isSaving ? 'Enviando...' : 'Pagar con pago movil'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoCard({
    required IconData icon,
    required String title,
    required String text,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE9DED2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: const Color(0xFFFFF1E6),
            child: Icon(icon, color: const Color(0xFFFF7A00)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  text,
                  style: const TextStyle(
                    color: Color(0xFF6D5E4F),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _highlightMetric({
    required String value,
    required String label,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.12),
          borderRadius: BorderRadius.circular(18),
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
                color: Color(0xFFFCE3CD),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F4EF),
      appBar: AppBar(
        title: const Text('Impulsa tu perfil'),
        backgroundColor: const Color(0xFFF8F4EF),
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: user == null
            ? null
            : FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .snapshots(),
        builder: (context, snapshot) {
          final data = snapshot.data?.data();
          if (user != null && data != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _expireSubscriptionIfNeeded(user.uid, data);
            });
          }
          final currentPlan = data?['subscriptionPlan']?.toString() ?? 'basic';
          final currentStatus =
              data?['subscriptionStatus']?.toString() ?? 'inactive';
          final promotedUntil = data?['promotedUntil'] as Timestamp?;
          final paymentStatusMessage = _paymentStatusMessage(data);

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: const Color(0xFF1B130C),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0x26FFFFFF),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Text(
                        'Suscripciones para tecnicos',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Haz que mas clientes te vean primero dentro de Panafix.',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Si apareces mas arriba, tienes mas oportunidades de que te contacten. La meta es simple: invertir poco y recuperar tu plan con uno o dos trabajos.',
                      style: TextStyle(
                        color: Color(0xFFE8DCCF),
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        _highlightMetric(
                          value: '+Visibilidad',
                          label: 'Aparece antes',
                        ),
                        const SizedBox(width: 10),
                        _highlightMetric(
                          value: '+Confianza',
                          label: 'Perfil destacado',
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0x14FFFFFF),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Text(
                        currentStatus == 'active'
                            ? 'Tu plan actual es ${currentPlan.toUpperCase()} y vence el ${_formatDate(promotedUntil)}.'
                            : 'Tu cuenta esta en modo basico. Puedes trabajar igual, pero apareceras por debajo de perfiles destacados.',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          height: 1.4,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _countdownText(promotedUntil, currentStatus),
                      style: const TextStyle(
                        color: Color(0xFFE8DCCF),
                        fontWeight: FontWeight.w700,
                        height: 1.4,
                      ),
                    ),
                    if (paymentStatusMessage.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0x33FFFFFF),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Text(
                          paymentStatusMessage,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 18),
              _planCard(
                title: 'Plan Empresas',
                price: '\$10 / mes',
                subtitle:
                    'Pensado para tecnicos o equipos que trabajan como empresa y necesitan una presencia comercial mas seria dentro de Panafix.',
                recoveryMessage:
                    'Ideal para negocios que quieren verse mas formales y recuperar la inversion con pocos servicios cerrados.',
                paymentHint:
                    'Se activa despues de enviar tu pago movil y la referencia para revision.',
                benefits: const [
                  'Mas oportunidad de que el cliente te vea antes que a otros.',
                  'Subes por encima de cuentas basicas en tu ciudad y categoria.',
                  'Insignia Empresas visible para transmitir mas confianza al cliente.',
                  'Mas presencia cuando el cliente compara servicios de negocio.',
                  'Perfil con apariencia mas profesional para empresas y cuadrillas.',
                ],
                colors: const [
                  Color(0xFF0F766E),
                  Color(0xFF34D399),
                ],
                badge: 'Para empresas',
                onTap: () => _showPaymentMobileSheet(
                  planId: 'pro',
                  title: 'Empresas',
                  monthlyPrice: '\$10 / mes',
                  priority: 1,
                  durationDays: 30,
                  data: data,
                  benefits: const [
                    'Mayor posicion en listados',
                    'Insignia Empresas visible',
                    'Mas prioridad para perfiles de negocio',
                    'Mejor visibilidad comercial en tu categoria',
                  ],
                ),
              ),
              _planCard(
                title: 'Plan Premium',
                price: '\$20 / mes',
                subtitle:
                    'La opcion para tecnicos que quieren dominar su zona y salir arriba como una promocion fuerte y constante.',
                recoveryMessage:
                    'Hecho para quienes quieren mas mensajes, mas oportunidades y una presencia comercial mucho mas fuerte.',
                paymentHint:
                    'Debes reportar tu pago movil para que Panafix valide y active tu plan Premium.',
                benefits: const [
                  'Tu perfil se impulsa mas fuerte frente a la competencia.',
                  'Prioridad maxima en listados y resultados destacados.',
                  'Insignia Premium para elevar confianza y presencia comercial.',
                  'Mas impulso en categorias, ciudad y servicios relacionados.',
                  'Mayor oportunidad de ser visto primero por nuevos clientes.',
                ],
                colors: const [
                  Color(0xFF7C2D12),
                  Color(0xFFF97316),
                ],
                badge: 'Mayor visibilidad',
                onTap: () => _showPaymentMobileSheet(
                  planId: 'premium',
                  title: 'Premium',
                  monthlyPrice: '\$20 / mes',
                  priority: 2,
                  durationDays: 30,
                  data: data,
                  benefits: const [
                    'Prioridad maxima en resultados',
                    'Insignia Premium visible',
                    'Mas impulso en categorias y servicios',
                    'Preferencia comercial frente a otros tecnicos',
                  ],
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Por que te conviene suscribirte',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 12),
              _infoCard(
                icon: Icons.vertical_align_top,
                title: 'Mas clientes te ven primero',
                text:
                    'Cuando un cliente busque en tu categoria, tu perfil tendra prioridad frente a cuentas basicas y ganara mas atencion.',
              ),
              _infoCard(
                icon: Icons.workspace_premium,
                title: 'Tu perfil se ve mas profesional',
                text:
                    'Los clientes veran que tu perfil es destacado, lo que ayuda a diferenciarte, inspirar confianza y cerrar mas rapido.',
              ),
              _infoCard(
                icon: Icons.campaign,
                title: 'Publicidad dentro de Panafix',
                text:
                    'La suscripcion funciona como una promocion interna para que tu perfil tenga mas exposicion sin comprar anuncios externos.',
              ),
              _infoCard(
                icon: Icons.phone_android,
                title: 'Activacion por pago movil',
                text:
                    'Para activar cualquier plan debes hacer el pago movil y luego enviar la referencia desde esta misma pantalla.',
              ),
              _infoCard(
                icon: Icons.savings,
                title: 'Pensado para que recuperes rapido tu inversion',
                text:
                    'Los precios estan pensados para que puedas recuperar el plan con pocos servicios bien cerrados, no con decenas.',
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFFE9DED2)),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Preguntas frecuentes',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Puedo trabajar sin suscripcion?',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Si. La suscripcion no es obligatoria. Solo te ayuda a tener mas visibilidad y prioridad.',
                      style: TextStyle(color: Color(0xFF6D5E4F), height: 1.4),
                    ),
                    SizedBox(height: 12),
                    Text(
                      'La suscripcion me garantiza trabajos?',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'No garantiza trabajos, pero si aumenta tus posibilidades de ser visto primero por los clientes.',
                      style: TextStyle(color: Color(0xFF6D5E4F), height: 1.4),
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Cada cuanto se renueva?',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Cada activacion dura 30 dias. Luego puedes renovarla desde esta misma seccion.',
                      style: TextStyle(color: Color(0xFF6D5E4F), height: 1.4),
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Se activa de inmediato?',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'No. Primero debes enviar tu pago movil y la referencia. Panafix revisa el pago antes de activar tu suscripcion.',
                      style: TextStyle(color: Color(0xFF6D5E4F), height: 1.4),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
