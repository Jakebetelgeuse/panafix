import 'package:flutter/material.dart';

import 'privacy_policy_page.dart';
import 'support_center_page.dart';
import 'terms_of_service_page.dart';

class LegalHubPage extends StatelessWidget {
  const LegalHubPage({super.key});

  Widget _linkCard({
    required BuildContext context,
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required Widget page,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 18,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 10,
        ),
        leading: CircleAvatar(
          radius: 22,
          backgroundColor: color.withOpacity(0.12),
          child: Icon(icon, color: color),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 17,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(height: 1.4),
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => page),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ayuda y documentos'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Container(
            padding: const EdgeInsets.all(22),
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
              borderRadius: BorderRadius.circular(32),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Centro legal de Panafix',
                  style: TextStyle(
                    color: Color(0xFFFFDDB7),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 10),
                Text(
                  'Aqui reunimos privacidad, terminos y ayuda basica para clientes y tecnicos.',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    height: 1.15,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          _linkCard(
            context: context,
            icon: Icons.support_agent_outlined,
            color: const Color(0xFF16A34A),
            title: 'Centro de ayuda',
            subtitle:
                'Encuentra respuestas sobre pagos, soporte, seguridad y contacto directo.',
            page: const SupportCenterPage(),
          ),
          _linkCard(
            context: context,
            icon: Icons.privacy_tip_outlined,
            color: const Color(0xFF2563EB),
            title: 'Politica de privacidad',
            subtitle:
                'Conoce como Panafix usa, protege y procesa la informacion dentro de la plataforma.',
            page: const PrivacyPolicyPage(),
          ),
          _linkCard(
            context: context,
            icon: Icons.description_outlined,
            color: const Color(0xFFFF7A00),
            title: 'Terminos de uso',
            subtitle:
                'Revisa las reglas basicas para clientes, tecnicos, pagos y uso responsable.',
            page: const TermsOfServicePage(),
          ),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ayuda rapida',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Si tu pago esta en revision, espera la confirmacion del admin antes de que el tecnico avance. Si necesitas canales de contacto, respuestas sobre seguridad o pedir eliminacion de cuenta, entra al Centro de ayuda.',
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
