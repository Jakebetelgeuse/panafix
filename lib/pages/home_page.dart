import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/bcv_rate_service.dart';
import 'auth_service.dart';
import 'notifications_page.dart';
import 'client_profile_page.dart';
import 'my_requests_page.dart';
import 'process_guide_page.dart';
import 'services_page.dart';
import 'support_center_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool checkedOnboardingGuide = false;

  static const String supportPhone = '+13854637334';
  static const String supportEmail = 'ofirbellatrix@gmail.com';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showOnboardingGuideIfNeeded();
    });
  }

  Future<void> _showOnboardingGuideIfNeeded() async {
    if (checkedOnboardingGuide) return;
    checkedOnboardingGuide = true;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null || !mounted) return;

    final userRef =
        FirebaseFirestore.instance.collection('users').doc(user.uid);
    final doc = await userRef.get();
    final data = doc.data() ?? {};
    if (data['showOnboardingGuide'] != true) return;

    await userRef.set({
      'showOnboardingGuide': false,
      'onboardingGuideShownAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    if (!mounted) return;
    _showWelcomeGuideDialog(isTechnician: false);
  }

  void _showWelcomeGuideDialog({required bool isTechnician}) {
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
                        Icons.home_repair_service,
                        color: Colors.white,
                        size: 30,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Bienvenida a Panafix',
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
                  'Mini tour express: menos drama que una tuberia rota y mas util que un primo que "medio sabe".',
                  style: TextStyle(
                    color: Color(0xFF6D5E4F),
                    height: 1.35,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 16),
                const _WelcomeStep(
                  icon: Icons.category_outlined,
                  title: 'Elige el servicio',
                  body: 'Selecciona categoria, tecnico y explica que paso.',
                ),
                const _WelcomeStep(
                  icon: Icons.location_on_outlined,
                  title: 'Confirma ubicacion',
                  body: 'La app pide tu ubicacion y puedes mover el pin.',
                ),
                const _WelcomeStep(
                  icon: Icons.payments_outlined,
                  title: 'Pago protegido',
                  body: 'Panafix revisa el comprobante antes de enviar al tecnico.',
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        child: const Text('Luego lo veo'),
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
                              builder: (_) => const ProcessGuidePage.client(),
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

  Future<void> signOut() async {
    await AuthService().signOut();
  }

  void openCategory(BuildContext context, String category) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ServicesPage(category: category),
      ),
    );
  }

  Future<void> _launchSupportUrl(BuildContext context, Uri uri) async {
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

  void _openSupportSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (sheetContext) {
        final whatsappMessage = Uri.encodeComponent(
          'Hola, necesito ayuda con un problema en la app Panafix.',
        );

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Soporte Panafix',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Si la app falla o un servicio presenta un problema, puedes escribirnos desde aqui.',
                  style: TextStyle(
                    color: Color(0xFF756B61),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 18),
                _SupportTile(
                  color: const Color(0xFFE9FFF3),
                  icon: Icons.chat_bubble_outline,
                  iconColor: Colors.green,
                  title: 'WhatsApp',
                  subtitle: supportPhone,
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _launchSupportUrl(
                      context,
                      Uri.parse(
                        'https://wa.me/${supportPhone.replaceAll('+', '')}?text=$whatsappMessage',
                      ),
                    );
                  },
                ),
                _SupportTile(
                  color: const Color(0xFFFFF0E0),
                  icon: Icons.call_outlined,
                  iconColor: Colors.orange,
                  title: 'Llamar soporte',
                  subtitle: supportPhone,
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _launchSupportUrl(
                      context,
                      Uri(
                        scheme: 'tel',
                        path: supportPhone,
                      ),
                    );
                  },
                ),
                _SupportTile(
                  color: const Color(0xFFEAFBF0),
                  icon: Icons.support_agent_outlined,
                  iconColor: Colors.green,
                  title: 'Centro de ayuda',
                  subtitle: 'Pagos, seguridad, soporte y cuenta',
                  onTap: () {
                    Navigator.pop(sheetContext);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const SupportCenterPage(),
                      ),
                    );
                  },
                ),
                _SupportTile(
                  color: const Color(0xFFEAF3FF),
                  icon: Icons.mail_outline,
                  iconColor: Colors.blue,
                  title: 'Correo',
                  subtitle: supportEmail,
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _launchSupportUrl(
                      context,
                      Uri(
                        scheme: 'mailto',
                        path: supportEmail,
                        query:
                            'subject=Soporte Panafix&body=Hola, necesito ayuda con la app.',
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _categoryCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required List<Color> colors,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(28),
      onTap: () => openCategory(context, title),
      child: Ink(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: colors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(28),
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(
                  icon,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const Spacer(),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: const TextStyle(
                  color: Colors.white70,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _quickAction({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required Color iconColor,
    required Color iconBackground,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 22,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 6,
        ),
        leading: CircleAvatar(
          radius: 24,
          backgroundColor: iconBackground,
          child: Icon(icon, color: iconColor),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.arrow_forward_ios, size: 18),
        onTap: onTap,
      ),
    );
  }

  Widget _heroActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required Color backgroundColor,
    required Color foregroundColor,
  }) {
    return Expanded(
      child: SizedBox(
        height: 52,
        child: ElevatedButton.icon(
          onPressed: onTap,
          icon: Icon(icon, size: 18),
          label: Text(label),
          style: ElevatedButton.styleFrom(
            elevation: 0,
            backgroundColor: backgroundColor,
            foregroundColor: foregroundColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
        ),
      ),
    );
  }

  Widget _notificationsButton(BuildContext context, User? user) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: user == null
          ? null
          : FirebaseFirestore.instance
              .collection('notifications')
              .where('userId', isEqualTo: user.uid)
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

  Widget _profileButton(BuildContext context, User? user) {
    if (user == null) {
      return IconButton(
        tooltip: 'Mi perfil',
        onPressed: null,
        icon: const Icon(Icons.person_outline),
      );
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .snapshots(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data();
        final photoUrl =
            (data?['profilePhotoUrl'] ?? user.photoURL ?? '').toString();
        final name = (data?['name'] ?? user.displayName ?? 'Cliente').toString();

        return IconButton(
          tooltip: 'Mi perfil',
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const ClientProfilePage(),
              ),
            );
          },
          icon: CircleAvatar(
            radius: 16,
            backgroundColor: const Color(0xFFFFEDD8),
            backgroundImage: photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
            child: photoUrl.isEmpty
                ? Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: const TextStyle(
                      color: Color(0xFFFF7A00),
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  )
                : null,
          ),
        );
      },
    );
  }

  Widget _walletBalanceCard(User? user) {
    if (user == null) return const SizedBox();

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .snapshots(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data() ?? {};
        final balanceUsd =
            ((data['appWalletBalanceUsd'] ??
                        data['appWalletBalance'] ??
                        0) as num?)
                    ?.toDouble() ??
                0;

        if (balanceUsd <= 0) return const SizedBox();

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0F766E), Color(0xFF14B8A6)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.account_balance_wallet_outlined,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Saldo Panafix disponible',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      FutureBuilder<BcvRate>(
                        future: BcvRateService.getRate(),
                        builder: (context, rateSnapshot) {
                          final rate = rateSnapshot.data;
                          final equivalentBs =
                              rate?.isAvailable == true
                                  ? rate!.usdToVes(balanceUsd)
                                  : 0.0;

                          return Text(
                            equivalentBs > 0
                                ? '\$${balanceUsd.toStringAsFixed(2)} anclados al BCV. Hoy son aprox. Bs ${equivalentBs.toStringAsFixed(2)}.'
                                : '\$${balanceUsd.toStringAsFixed(2)} anclados al BCV se aplicaran automaticamente en tu proximo pago.',
                            style: const TextStyle(
                              color: Color(0xFFE0FFF8),
                              height: 1.3,
                            ),
                          );
                        },
                      ),
                    ],
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
    final user = FirebaseAuth.instance.currentUser;
    final displayName = user?.displayName?.trim();
    final headerName = (displayName != null && displayName.isNotEmpty)
        ? displayName
        : 'Hola';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Panafix'),
        actions: [
          _profileButton(context, user),
          _notificationsButton(context, user),
          IconButton(
            tooltip: 'Mis solicitudes',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const MyRequestsPage(),
                ),
              );
            },
            icon: const Icon(Icons.receipt_long),
          ),
          IconButton(
            tooltip: 'Cerrar sesion',
            onPressed: signOut,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
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
                  borderRadius: BorderRadius.circular(34),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      headerName,
                      style: const TextStyle(
                        color: Color(0xFFFFDDB7),
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Pide ayuda en minutos y sigue tu servicio como una app moderna de confianza.',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Solicita tecnicos, paga con respaldo, recibe soporte y mira la aproximacion en tiempo real.',
                      style: TextStyle(
                        color: Color(0xFFFCE3CD),
                        fontSize: 15,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: const [
                        _HeroChip(label: 'Pago retenido'),
                        _HeroChip(label: 'Mapa en vivo'),
                        _HeroChip(label: 'Soporte rapido'),
                        _HeroChip(label: 'Tecnicos verificados'),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        _heroActionButton(
                          icon: Icons.receipt_long,
                          label: 'Mis servicios',
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF1B130C),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const MyRequestsPage(),
                              ),
                            );
                          },
                        ),
                        const SizedBox(width: 10),
                        _heroActionButton(
                          icon: Icons.support_agent,
                          label: 'Soporte',
                          backgroundColor: const Color(0x33FFFFFF),
                          foregroundColor: Colors.white,
                          onTap: () => _openSupportSheet(context),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFFEAF3FF),
                      Color(0xFFF6FBFF),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: const Icon(
                        Icons.bolt_rounded,
                        color: Color(0xFF2563EB),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Solicitud agil',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Explora categorias, elige tecnico y deja tu servicio encaminado en pocos pasos.',
                            style: TextStyle(
                              color: Color(0xFF52606D),
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.arrow_forward_rounded,
                      color: Color(0xFF2563EB),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              _walletBalanceCard(user),
              _quickAction(
                icon: Icons.auto_stories_outlined,
                title: 'Como funciona Panafix',
                subtitle: 'Guia rapida, divertida y paso a paso',
                iconColor: const Color(0xFFFF7A00),
                iconBackground: const Color(0xFFFFEDD8),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ProcessGuidePage.client(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              _quickAction(
                icon: Icons.receipt_long,
                title: 'Mis solicitudes',
                subtitle: 'Sigue estados, chat, pago y liberacion',
                iconColor: const Color(0xFFFF7A00),
                iconBackground: const Color(0xFFFFEDD8),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const MyRequestsPage(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              _quickAction(
                icon: Icons.support_agent,
                title: 'Soporte tecnico',
                subtitle: 'Escribenos si la app da un error o un cobro raro',
                iconColor: const Color(0xFF16A34A),
                iconBackground: const Color(0xFFEAFBF0),
                onTap: () => _openSupportSheet(context),
              ),
              const SizedBox(height: 12),
              _quickAction(
                icon: Icons.gavel_outlined,
                title: 'Ayuda y documentos',
                subtitle: 'Privacidad, terminos y reglas basicas',
                iconColor: const Color(0xFF7C3AED),
                iconBackground: const Color(0xFFF3E8FF),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const SupportCenterPage(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),
              const Text(
                'Categorias',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 14),
              GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
                childAspectRatio: 0.92,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _categoryCard(
                    context,
                    title: 'Electricidad',
                    subtitle: 'Cableado, enchufes y lamparas',
                    icon: Icons.bolt_rounded,
                    colors: const [Color(0xFFFF9800), Color(0xFFFFB347)],
                  ),
                  _categoryCard(
                    context,
                    title: 'Fontaneria',
                    subtitle: 'Fugas, tuberias y banos',
                    icon: Icons.plumbing_rounded,
                    colors: const [Color(0xFF1476FF), Color(0xFF69B4FF)],
                  ),
                  _categoryCard(
                    context,
                    title: 'Cerrajeria',
                    subtitle: 'Puertas, llaves y cerraduras',
                    icon: Icons.key_rounded,
                    colors: const [Color(0xFF7C3AED), Color(0xFFB06CFF)],
                  ),
                  _categoryCard(
                    context,
                    title: 'Internet/TV',
                    subtitle: 'Router, wifi e instalacion',
                    icon: Icons.router_rounded,
                    colors: const [Color(0xFF0F766E), Color(0xFF34D399)],
                  ),
                  _categoryCard(
                    context,
                    title: 'Electrodomesticos',
                    subtitle: 'Nevera, lavadora y cocina',
                    icon: Icons.kitchen_rounded,
                    colors: const [Color(0xFF059669), Color(0xFF6EE7B7)],
                  ),
                  _categoryCard(
                    context,
                    title: 'Albanileria',
                    subtitle: 'Paredes, friso, ceramica y cemento',
                    icon: Icons.construction_rounded,
                    colors: const [Color(0xFFB45309), Color(0xFFF59E0B)],
                  ),
                  _categoryCard(
                    context,
                    title: 'Pintura',
                    subtitle: 'Paredes, techos y acabados',
                    icon: Icons.format_paint_rounded,
                    colors: const [Color(0xFFEC4899), Color(0xFFF9A8D4)],
                  ),
                  _categoryCard(
                    context,
                    title: 'Carpinteria',
                    subtitle: 'Muebles, puertas y repisas',
                    icon: Icons.carpenter_rounded,
                    colors: const [Color(0xFF92400E), Color(0xFFD97706)],
                  ),
                  _categoryCard(
                    context,
                    title: 'Limpieza',
                    subtitle: 'Hogar, oficinas y limpieza profunda',
                    icon: Icons.cleaning_services_rounded,
                    colors: const [Color(0xFF0EA5E9), Color(0xFF67E8F9)],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeroChip extends StatelessWidget {
  final String label;

  const _HeroChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: Colors.white.withOpacity(0.14),
        ),
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

class _WelcomeStep extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;

  const _WelcomeStep({
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

class _SupportTile extends StatelessWidget {
  final Color color;
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SupportTile({
    required this.color,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: color,
        child: Icon(icon, color: iconColor),
      ),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      onTap: onTap,
    );
  }
}
