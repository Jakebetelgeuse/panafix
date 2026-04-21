import 'package:flutter/material.dart';

class TermsOfServicePage extends StatelessWidget {
  const TermsOfServicePage({super.key});

  Widget _section(String title, String body) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: const TextStyle(
              color: Color(0xFF5D4D40),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Terminos de uso'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Container(
            padding: const EdgeInsets.all(22),
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
              borderRadius: BorderRadius.circular(30),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Terminos de uso de Panafix',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Estas condiciones resumen las reglas basicas para usar Panafix como cliente, tecnico o personal operativo.',
                  style: TextStyle(
                    color: Color(0xFFFCE3CD),
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          _section(
            'Uso responsable',
            'Los usuarios deben registrarse con informacion real, mantener un trato respetuoso y evitar conductas que pongan en riesgo a otros usuarios o a la operacion de la plataforma.',
          ),
          _section(
            'Responsabilidad del tecnico',
            'El tecnico es responsable de mantener su perfil actualizado, definir correctamente sus servicios, precios, disponibilidad, datos de pago y brindar un servicio acorde a lo ofrecido.',
          ),
          _section(
            'Responsabilidad del cliente',
            'El cliente debe describir correctamente el servicio, respetar los procesos de pago, usar el chat y el soporte de forma adecuada y confirmar la finalizacion del trabajo de buena fe.',
          ),
          _section(
            'Pagos y liberaciones',
            'Panafix puede retener pagos mientras el servicio se revisa, se confirma o se completa. La liberacion del pago y los cortes a tecnicos pueden seguir reglas internas operativas o de seguridad.',
          ),
          _section(
            'Suspension o restriccion de cuentas',
            'Panafix puede suspender o limitar cuentas que incumplan estas reglas, generen fraudes, abusen del sistema, manipulen pagos o comprometan la seguridad de la comunidad.',
          ),
          _section(
            'Soporte y emergencias',
            'La plataforma ofrece canales de ayuda, soporte y reporte urgente. En casos serios, el usuario debe usar de inmediato las herramientas de emergencia disponibles y seguir instrucciones del soporte.',
          ),
        ],
      ),
    );
  }
}
