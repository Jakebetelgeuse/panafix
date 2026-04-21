import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'legal_hub_page.dart';

class SupportCenterPage extends StatelessWidget {
  const SupportCenterPage({super.key});

  static const String supportPhone = '+13854637334';
  static const String supportEmail = 'ofirbellatrix@gmail.com';

  Future<void> _launchUrl(BuildContext context, Uri uri) async {
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

  Widget _sectionTitle(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: const TextStyle(
            color: Color(0xFF6D5E4F),
            height: 1.4,
          ),
        ),
      ],
    );
  }

  Widget _helpCard({
    required IconData icon,
    required Color color,
    required String title,
    required String text,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE7DDD3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: color.withOpacity(0.12),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 6),
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

  Widget _contactTile({
    required BuildContext context,
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.12),
          child: Icon(icon, color: color),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final whatsappMessage = Uri.encodeComponent(
      'Hola, necesito ayuda con Panafix.',
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Centro de ayuda'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 26),
        children: [
          Container(
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
              borderRadius: BorderRadius.circular(32),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Panafix Support',
                  style: TextStyle(
                    color: Color(0xFFFFDDB7),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 10),
                Text(
                  'Ayuda, pagos, seguridad y canales directos para resolver problemas rapido.',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 25,
                    fontWeight: FontWeight.w800,
                    height: 1.15,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _sectionTitle(
            'Preguntas frecuentes',
            'Lo mas importante antes de contactar soporte.',
          ),
          const SizedBox(height: 12),
          _helpCard(
            icon: Icons.payments_outlined,
            color: const Color(0xFFFF7A00),
            title: 'Pagos en revision',
            text:
                'Si subiste un comprobante, el servicio puede esperar aprobacion. El tecnico no deberia avanzar hasta que el pago este validado.',
          ),
          _helpCard(
            icon: Icons.map_outlined,
            color: const Color(0xFF2563EB),
            title: 'Seguimiento y aproximacion',
            text:
                'Cuando el tecnico marca que va en camino, ambos pueden revisar la aproximacion desde el mapa del servicio.',
          ),
          _helpCard(
            icon: Icons.warning_amber_rounded,
            color: const Color(0xFFDC2626),
            title: 'Seguridad y emergencia',
            text:
                'Si ocurre un problema durante un servicio activo, usa el boton de emergencia dentro del tracking o en tus solicitudes.',
          ),
          _helpCard(
            icon: Icons.person_remove_outlined,
            color: const Color(0xFF7C3AED),
            title: 'Eliminacion de cuenta',
            text:
                'Si deseas cerrar tu cuenta o pedir eliminacion de datos, escribenos a soporte@panafix.com desde el correo vinculado a tu cuenta.',
          ),
          const SizedBox(height: 10),
          _sectionTitle(
            'Contactar soporte',
            'Usa el canal que te resulte mas comodo.',
          ),
          const SizedBox(height: 12),
          _contactTile(
            context: context,
            icon: Icons.chat_bubble_outline,
            color: Colors.green,
            title: 'WhatsApp',
            subtitle: supportPhone,
            onTap: () => _launchUrl(
              context,
              Uri.parse(
                'https://wa.me/${supportPhone.replaceAll('+', '')}?text=$whatsappMessage',
              ),
            ),
          ),
          _contactTile(
            context: context,
            icon: Icons.call_outlined,
            color: const Color(0xFFFF7A00),
            title: 'Llamar soporte',
            subtitle: supportPhone,
            onTap: () => _launchUrl(
              context,
              Uri(scheme: 'tel', path: supportPhone),
            ),
          ),
          _contactTile(
            context: context,
            icon: Icons.mail_outline,
            color: const Color(0xFF2563EB),
            title: 'Correo',
            subtitle: supportEmail,
            onTap: () => _launchUrl(
              context,
              Uri(
                scheme: 'mailto',
                path: supportEmail,
                query:
                    'subject=Soporte Panafix&body=Hola, necesito ayuda con mi cuenta o un servicio.',
              ),
            ),
          ),
          _contactTile(
            context: context,
            icon: Icons.gavel_outlined,
            color: const Color(0xFF7C3AED),
            title: 'Privacidad y terminos',
            subtitle: 'Revisa documentos y reglas de uso',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const LegalHubPage(),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFFF7F4EF),
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Cuando escribir a soporte',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Contactanos si un pago no cambia de estado, si el chat no carga, si una orden se queda pegada, si necesitas cerrar tu cuenta o si hubo un inconveniente fuerte con un cliente o tecnico.',
                  style: TextStyle(
                    color: Color(0xFF6D5E4F),
                    height: 1.45,
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
